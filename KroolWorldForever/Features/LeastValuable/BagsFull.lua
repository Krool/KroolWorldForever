-- Bags Full card for Least Valuable. When a full bag stops a pickup ("Inventory is full", "No room
-- to loot") a small card shows your least valuable item, priced exactly as the bag mark prices it
-- (ns.Scan), and what the loot is worth, so you can decide what is worth making room for.
--
-- Text and a mark only. This file never picks up, drops, deletes, sells or loots anything: the
-- player does that by hand. (Owner, 2026-11-12: "i definitely dont want auto delete anywhere".)
--
-- The card docks beside the loot window when there is one, else it sits near the top of the screen
-- (herbs, quest objects and mail have no loot window). It hides when the loot window closes, when a
-- bag slot frees up, and when the feature or the option is turned off.

local _, root = ...
local ns = root.Feature("leastvaluable")
local UI = root.UI

local W, H = 300, 262
local GREEN, RED, GREY, GOLD = "|cff55ff55", "|cffff7755", "|cffaaaaaa", "|cffffd27f"
local UNCOMMON = 2
local BIND_ON_PICKUP = 1
-- The same coin the bag mark uses (LeastValuable.lua, MARK_ATLAS).
local MARK_ATLAS, MARK_SIZE = "coin-copper", 15

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- pcall for a function that may be missing: false when it is.
local function Call(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, ...)
end

local state = { list = {}, idx = 1 } -- list: the bag candidates, cheapest first
local ui -- the card and its parts, nil until built
local lootOpen = false
local waiting = {} -- item ids the card waits on for GET_ITEM_INFO_RECEIVED

-- -------------------------------------------------------------------- reading

-- Free slots in the normal bags (not the reagent bag, not specialty bags), or nil when the client
-- will not say.
local function FreeSlots()
	local C = C_Container
	if not (C and C.GetContainerNumFreeSlots) then
		return nil
	end
	local total = 0
	for _, bag in ipairs(ns.Bags()) do
		local ok, free, family = Call(C.GetContainerNumFreeSlots, bag)
		if not ok or Secret(free) or Secret(family) or type(free) ~= "number" then
			return nil
		end
		if family == nil or family == 0 then
			total = total + free
		end
	end
	return total
end

-- Every bag candidate in the order /kwl lists them: cheapest first, ties in bag order.
local function Candidates()
	local list, _, _, pending = ns.Scan()
	local order = {}
	for i, e in ipairs(list) do
		order[e] = i
	end
	table.sort(list, function(a, b)
		if a.value ~= b.value then
			return a.value < b.value
		end
		return order[a] < order[b]
	end)
	for id in pairs(pending or {}) do
		waiting[id] = true
	end
	return list
end

-- One loot slot priced like a bag slot: { link, id, count, how, unit, value } with a value, or
-- { link, id, count, take = true, label = } for loot worth taking whatever the bags hold (quest
-- items, kept items) and for loot with no price we can know.
local function LootEntry(ctx, link, id, count, isQuest)
	local e = { link = link, id = id, count = count }
	local f = ns.Facts(ctx, link, id)
	if f.pending then
		waiting[id] = true
		e.take, e.label = true, "value unknown"
		return e
	end
	e.name = f.name
	if isQuest or f.skip == "quest" then
		e.take, e.label = true, "quest item"
		return e
	end
	if f.skip then
		e.take, e.label = true, "value unknown"
		return e
	end
	local bound = f.bind == BIND_ON_PICKUP
	local vendor = f.sell
	local auction = not bound and f.auction or nil
	local de = (not bound or ctx.canDE) and f.de or nil
	if not bound and f.quality >= UNCOMMON and not auction and not de then
		e.take, e.label = true, "value unknown" -- the same items the bag mark leaves out
		return e
	end
	local how, unit = ns.Best(ctx, de, auction, vendor)
	if not how then
		e.take, e.label = true, "value unknown"
		return e
	end
	e.how, e.unit, e.value = how, unit, unit * count
	return e
end

-- The item slots of the open loot window, priced. Money and currency are ignored.
local function Loot()
	local out = {}
	local ok, n = Call(GetNumLootItems)
	if not ok or Secret(n) or type(n) ~= "number" or n < 1 then
		return out
	end
	local ctx = ns.Context()
	for slot = 1, n do
		local okT, kind = Call(GetLootSlotType, slot)
		local isItem = true -- money and currency slots have no item to price
		local slotTypes = Enum and Enum.LootSlotType
		if okT and not Secret(kind) and kind ~= nil and type(slotTypes) == "table" and slotTypes.Item ~= nil then
			isItem = kind == slotTypes.Item
		end
		local okL, link = Call(GetLootSlotLink, slot)
		if isItem and okL and not Secret(link) and type(link) == "string" then
			local id = tonumber(link:match("item:(%d+)"))
			local okI, _, _, quantity, _, _, _, isQuest = Call(GetLootSlotInfo, slot)
			if okI and (Secret(quantity) or Secret(isQuest)) then
				id = nil -- unreadable: leave the slot out
			end
			if id then
				quantity = type(quantity) == "number" and quantity > 0 and quantity or 1
				out[#out + 1] = LootEntry(ctx, link, id, quantity, okI and isQuest == true)
			end
		end
	end
	return out
end

-- The verdict. least: the cheapest bag candidate (or nil). loot: LootEntry list. Returns
-- "worth" or "notworth" (or nil when there is nothing to judge), and the loot entry to show.
function ns.BagsFullVerdict(least, loot)
	if #loot == 0 then
		return nil, nil
	end
	local best, take
	for _, e in ipairs(loot) do
		if e.take then
			take = take or e
		elseif not best or e.value > best.value then
			best = e
		end
	end
	if take then
		-- worth taking whatever the bags hold; still show a known item when it is the better sight
		return "worth", (best and least and best.value > least.value) and best or take
	end
	if not least then
		return nil, best -- nothing in the bags to make room with
	end
	return best.value > least.value and "worth" or "notworth", best
end

-- -------------------------------------------------------------------- the card

local function ItemText(e)
	return UI.ItemIcon(e.id, 16) .. (e.link or e.name or ("item " .. e.id)) .. (e.count > 1 and (" x" .. e.count) or "")
end

local function FindButton(bag, slot)
	local ok, button = Call(ContainerFrameUtil_GetItemButtonAndContainer, bag, slot)
	return ok and type(button) == "table" and button or nil
end

-- Marks the browsed bag slot with the coin, when the default bags are open. Our own frame: the
-- bag mark itself stays on the cheapest slot.
local function Highlight(c)
	if not ui then
		return
	end
	local button = c and FindButton(c.bag, c.slot) or nil
	if not button then
		ui.mark:Hide()
		return
	end
	if ui.markButton ~= button then
		ui.mark:SetParent(button)
		ui.mark:ClearAllPoints()
		ui.mark:SetAllPoints(button)
		ui.markButton = button
	end
	local ok, level = Call(button.GetFrameLevel, button)
	if ok and type(level) == "number" then
		ui.mark:SetFrameLevel(level + 3)
	end
	ui.mark:Show()
	UI.Flash(ui.mark)
end

local function Dock()
	ui.card:ClearAllPoints()
	local docked = false
	if lootOpen and type(LootFrame) == "table" then
		local ok, shown = Call(LootFrame.IsShown, LootFrame)
		if ok and shown == true then
			ui.card:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", 4, 0)
			docked = true
		end
	end
	if not docked then
		ui.card:SetPoint("TOP", UIParent, "TOP", 0, -140)
	end
end

local function Build()
	local card = UI.Window("KroolWorldForeverBagsFullCard", "Bags Full", W, H, ns.icon)
	ui = { card = card }
	card:SetFrameStrata("DIALOG")

	ui.head = UI.Text(card, "GameFontNormalSmall")
	ui.head:SetPoint("TOPLEFT", 16, -62)
	ui.head:SetText(GOLD .. "Least valuable:|r")

	ui.least = UI.Text(card, "GameFontHighlight")
	ui.least:SetPoint("TOPLEFT", 16, -78)
	ui.least:SetWidth(W - 32)
	ui.least:SetWordWrap(true)

	ui.prev = UI.Button(card, "<", 28, function()
		ns.BagsFullBrowse(-1)
	end)
	ui.prev:SetPoint("TOPLEFT", 16, -122)
	ui.next = UI.Button(card, ">", 28, function()
		ns.BagsFullBrowse(1)
	end)
	ui.next:SetPoint("LEFT", ui.prev, "RIGHT", 4, 0)
	ui.pos = UI.Text(card, "GameFontDisableSmall")
	ui.pos:SetPoint("LEFT", ui.next, "RIGHT", 8, 0)
	ui.never = UI.Button(card, "Never Mark", 96, function()
		ns.BagsFullNeverMark()
	end)
	ui.never:SetPoint("TOPRIGHT", -16, -122)
	UI.Tip(ui.never, function()
		return "Never Mark", { "Stops this item from being marked as least valuable. /kwl unignore brings it back." }
	end)
	UI.Tip(ui.prev, function()
		return "Previous", { "A less valuable candidate." }
	end)
	UI.Tip(ui.next, function()
		return "Next", { "The next most valuable candidate." }
	end)

	UI.Divider(card, W - 32)
	ui.lootHead = UI.Text(card, "GameFontNormalSmall")
	ui.lootHead:SetPoint("TOPLEFT", 16, -158)
	ui.lootHead:SetText(GOLD .. "Best loot:|r")
	ui.loot = UI.Text(card, "GameFontHighlight")
	ui.loot:SetPoint("TOPLEFT", 16, -174)
	ui.loot:SetWidth(W - 32)
	ui.loot:SetWordWrap(true)
	ui.verdict = UI.Text(card, "GameFontNormalLarge")
	ui.verdict:SetPoint("BOTTOMLEFT", 16, 14)
	ui.verdict:SetWidth(W - 32)

	ui.mark = CreateFrame("Frame")
	ui.mark:Hide()
	local tex = ui.mark:CreateTexture(nil, "OVERLAY")
	tex:SetAtlas(MARK_ATLAS)
	tex:SetSize(MARK_SIZE, MARK_SIZE)
	tex:SetPoint("TOPRIGHT", -1, -1)

	card:HookScript("OnHide", function()
		ui.mark:Hide()
	end)
end

-- Draws the state into the card.
local function Render()
	local c = state.list[state.idx]
	if c then
		ui.least:SetText(ItemText(c) .. "\n" .. root.Money(c.value) .. "  " .. ns.Detail(c))
		ui.pos:SetText(state.idx .. " of " .. #state.list)
	else
		ui.least:SetText(GREY .. "Nothing in your bags can be marked.|r")
		ui.pos:SetText("")
	end
	UI.Enable(ui.prev, c ~= nil and state.idx > 1)
	UI.Enable(ui.next, c ~= nil and state.idx < #state.list)
	UI.Enable(ui.never, c ~= nil)
	Highlight(c)

	if #state.loot == 0 then
		ui.loot:SetText(GREY .. "Nothing to loot here. Make room, then try again.|r")
		ui.verdict:SetText("")
	else
		local e = state.shown
		if e then
			local worth = e.take and (GREY .. e.label .. "|r") or (root.Money(e.value) .. "  " .. ns.Detail(e))
			ui.loot:SetText(ItemText(e) .. "\n" .. worth)
		else
			ui.loot:SetText("")
		end
		if state.verdict == "worth" then
			ui.verdict:SetText(GREEN .. "Worth making room|r")
		elseif state.verdict == "notworth" then
			ui.verdict:SetText(RED .. "Not worth picking up|r")
		else
			ui.verdict:SetText(GREY .. "No bag item to make room with|r")
		end
	end
end

-- Reads the bags and the loot again. keep: keep the browsed position.
local function Gather(keep)
	local was = state.list[state.idx]
	wipe(waiting)
	state.list = Candidates()
	state.idx = 1
	if keep and was then
		for i, e in ipairs(state.list) do
			if e.bag == was.bag and e.slot == was.slot and e.id == was.id then
				state.idx = i
				break
			end
		end
	end
	state.loot = lootOpen and Loot() or {}
	state.verdict, state.shown = ns.BagsFullVerdict(state.list[1], state.loot)
end

local function Update(keep)
	Gather(keep)
	Dock()
	Render()
end

function ns.BagsFullShown()
	return ui ~= nil and ui.card:IsShown() == true
end

function ns.BagsFullHide()
	if ui and ui.card:IsShown() then
		ui.card:Hide()
	end
end

-- Shows the card (or refreshes it, with a flash, when it is up already).
local function Open()
	local fresh = not ns.BagsFullShown()
	if not ui then
		Build()
	end
	Update(not fresh)
	if fresh then
		ui.card:Show()
	else
		UI.Flash(ui.card)
	end
end

function ns.BagsFullBrowse(step)
	if not ui then
		return
	end
	local idx = state.idx + step
	if idx >= 1 and idx <= #state.list then
		state.idx = idx
		Render()
	end
end

function ns.BagsFullNeverMark()
	local c = state.list[state.idx]
	if not (ui and c) then
		return
	end
	ns.Ignore(c.id, c.name)
	Gather(false)
	state.idx = math.min(state.idx, math.max(#state.list, 1))
	Render()
end

-- Test seams.
function ns.BagsFullUI()
	return ui
end
function ns.BagsFullState()
	return state
end

-- -------------------------------------------------------------------- events

-- Runs ours inside root.Try, then the handler LeastValuable.lua registered for the same event
-- (an event holds one handler).
local function Chain(event, fn)
	local prev = ns.events[event]
	return function(...)
		root.Try(ns, "bags full", fn, ...)
		if prev then
			return prev(...)
		end
	end
end

local function IsFullMessage(message)
	return type(message) == "string"
		and ((ERR_INV_FULL ~= nil and message == ERR_INV_FULL) or (ERR_LOOT_NO_SPACE ~= nil and message == ERR_LOOT_NO_SPACE))
end

-- The secret checks come first: nothing else may touch an argument before them.
ns:RegisterEvent("UI_ERROR_MESSAGE", function(_, errorType, message)
	if Secret(errorType) or Secret(message) then
		return
	end
	if not (ns.enabled and ns.db and ns.db.bagsfull) or not IsFullMessage(message) then
		return
	end
	if FreeSlots() ~= 0 then
		return -- free slots (or unknown): the error was about something else
	end
	Open()
end)
ns:RegisterEvent("LOOT_OPENED", function()
	lootOpen = true
end)
ns:RegisterEvent("LOOT_CLOSED", function()
	lootOpen = false
	ns.BagsFullHide()
end)
ns:RegisterEvent(
	"BAG_UPDATE_DELAYED",
	Chain("BAG_UPDATE_DELAYED", function()
		if not ns.BagsFullShown() then
			return
		end
		local free = FreeSlots()
		if free == nil or free > 0 then
			ns.BagsFullHide() -- a slot freed up
		else
			Update(true)
		end
	end)
)
ns:RegisterEvent(
	"GET_ITEM_INFO_RECEIVED",
	Chain("GET_ITEM_INFO_RECEIVED", function(_, itemId)
		if not Secret(itemId) and waiting[itemId] and ns.BagsFullShown() then
			Update(true)
		end
	end)
)

-- Off and option-off take the card away.
local onDisable, onOption = ns.OnDisable, ns.OnOptionChanged
function ns.OnDisable()
	ns.BagsFullHide()
	lootOpen = false
	if onDisable then
		onDisable()
	end
end
function ns.OnOptionChanged(...)
	if not (ns.db and ns.db.bagsfull) then
		ns.BagsFullHide()
	end
	if onOption then
		return onOption(...)
	end
end
