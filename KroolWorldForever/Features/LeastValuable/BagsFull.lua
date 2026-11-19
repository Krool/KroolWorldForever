-- Bags Full card for Least Valuable. When a full bag stops a pickup ("Inventory is full", "No room
-- to loot") a small card shows your least valuable item, priced exactly as the bag mark prices it
-- (ns.Scan), and what the loot is worth, so you can decide what is worth making room for.
--
-- Nothing here acts by itself: no event, timer or scan ever picks up, drops, deletes, sells or
-- loots. (Owner, 2026-11-12: "i definitely dont want auto delete anywhere".)
--
-- The one action is the Delete button (owner's request, 2026-11-18): it deletes the item the card
-- shows, and only from the player's own click on the card. DeleteNow is the only place that calls
-- PickupContainerItem, DeleteCursorItem or ClearCursor, and only the two click handlers reach it.
-- It asks first (option Confirm Before Deleting; a rare or better item always asks), reads the
-- slot again before it touches it, and never deletes what the cursor already held. Option Delete
-- Button On The Card takes the button away.
--
-- The card docks beside the loot window when there is one, else it sits near the top of the screen
-- (herbs, quest objects and mail have no loot window). It keeps off the open default bags: when
-- its place would cover one, it goes beside them. A card the player drags stays put until it
-- closes. It hides when the loot window closes, when a bag slot frees up, and when the feature or
-- the option is turned off.

local _, root = ...
local ns = root.Feature("leastvaluable")
local UI = root.UI

local W, H = 330, 262
local GREEN, RED, GREY, GOLD = "|cff55ff55", "|cffff7755", "|cffaaaaaa", "|cffffd27f"
local UNCOMMON = 2
local RARE = 3 -- a rare or better item always asks before it is deleted
local GAP = 8 -- between the card and the bags it keeps off
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

-- The general bags (bag family 0), by bag id: loot can only go into those. A herb, enchanting or
-- soul bag takes only its own kind, so what it holds frees nothing for loot. A bag whose family
-- the client will not say is left out.
local function GeneralBags()
	local general = {}
	local C = C_Container
	if not (C and C.GetContainerNumFreeSlots) then
		return general
	end
	for _, bag in ipairs(ns.Bags()) do
		local ok, free, family = Call(C.GetContainerNumFreeSlots, bag)
		if ok and not Secret(free) and not Secret(family) and (family == nil or family == 0) then
			general[bag] = true
		end
	end
	return general
end

-- Every bag candidate in the order /kwl lists them: cheapest first, ties in bag order. Only items
-- in general bags: the loot could take no other slot (FreeSlots counts the same bags).
local function Candidates()
	local scanned, _, _, pending = ns.Scan()
	local general = GeneralBags()
	local list = {}
	for _, e in ipairs(scanned) do
		if general[e.bag] then
			list[#list + 1] = e
		end
	end
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
	e.unsure = how == "disenchant" and f.deUnsure or nil
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
	local moved = ui.markButton ~= button or ui.mark:IsShown() ~= true
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
	if moved then
		UI.Flash(ui.mark) -- not on every redraw of the bags
	end
end

-- A shown frame's rectangle in screen pixels { l, b, r, t }, or nil when it is hidden or the
-- client will not say.
local function Rect(f)
	if type(f) ~= "table" then
		return nil
	end
	local okS, shown = Call(f.IsShown, f)
	if not okS or Secret(shown) or shown ~= true then
		return nil
	end
	local ok, l, b, w, h = Call(f.GetScaledRect, f)
	if not ok or Secret(l) or Secret(b) or Secret(w) or Secret(h) then
		return nil
	end
	if type(l) ~= "number" or type(b) ~= "number" or type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then
		return nil
	end
	return { l = l, b = b, r = l + w, t = b + h }
end

local function Overlaps(a, b)
	return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t
end

-- Moves the card off the open default bags, when the place it was just given would cover one (or
-- would not fit the screen beside the loot window). A place it cannot work out leaves the card
-- where it is. lootShown: the card is docked to the loot window.
local function KeepOffBags(lootShown)
	local screen = Rect(UIParent)
	local okC, scale = Call(ui.card.GetEffectiveScale, ui.card)
	if not screen or not okC or Secret(scale) or type(scale) ~= "number" or scale <= 0 then
		return
	end
	local bags, all = {}, nil -- all: one rectangle around every open bag
	for _, f in ipairs(ns.BagFrames()) do
		local r = Rect(f)
		if r then
			bags[#bags + 1] = r
			all = all or { l = r.l, b = r.b, r = r.r, t = r.t }
			all.l, all.b = math.min(all.l, r.l), math.min(all.b, r.b)
			all.r, all.t = math.max(all.r, r.r), math.max(all.t, r.t)
		end
	end
	if not all then
		return
	end
	local loot = lootShown and Rect(LootFrame) or nil
	if lootShown and not loot then
		return -- docked to a window we cannot measure
	end
	local w, h, gap = W * scale, H * scale, GAP * scale
	local function At(l, t)
		return { l = l, b = t - h, r = l + w, t = t }
	end
	local function Free(r, awayFromLoot)
		if r.l < screen.l or r.r > screen.r or r.b < screen.b or r.t > screen.t then
			return false
		end
		for _, bag in ipairs(bags) do
			if Overlaps(r, bag) then
				return false
			end
		end
		return not (awayFromLoot and loot and Overlaps(r, loot))
	end
	local now = loot and At(loot.r + 4 * scale, loot.t) or At((screen.l + screen.r - w) / 2, screen.t - 140 * scale)
	if Free(now) then
		return
	end
	local top = math.max(math.min(now.t, screen.t), screen.b + h) -- the same height, kept on the screen
	local tries = {
		loot and At(loot.l - 4 * scale - w, loot.t) or false, -- the loot window's other side
		At(all.l - gap - w, top), -- left of the bags
		At(all.l - gap - w, math.min(all.t, screen.t)), -- left of the bags, level with their top
		At(all.r - w, all.t + gap + h), -- above the bags
		At(all.r + gap, top), -- right of the bags
	}
	for i, r in ipairs(tries) do
		if r and Free(r, i > 1) then
			ui.card:ClearAllPoints()
			ui.card:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (r.l - screen.l) / scale, (r.t - screen.b) / scale)
			ui.avoiding = true
			return
		end
	end
end

local function Dock()
	if state.moved then
		return -- the player dragged it: it stays there until it closes
	end
	ui.card:ClearAllPoints()
	ui.avoiding = false
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
	KeepOffBags(docked)
end

local function Build()
	local card = UI.Window(root.ID.prefix .. "BagsFullCard", "Bags Full", W, H, ns.icon)
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
	ui.delete = UI.Button(card, "Delete", 64, function()
		ns.BagsFullDelete()
	end)
	ui.delete:SetPoint("RIGHT", ui.never, "LEFT", -4, 0)
	UI.Tip(ui.delete, function()
		local c = state.list[state.idx]
		local asks = c == nil or ns.BagsFullAsks(c)
		return "Delete",
			{
				"Deletes this item from your bags to make room. It cannot be brought back.",
				asks and "It asks first." or "One click: Confirm Before Deleting is off.",
			}
	end)
	-- The question takes the row's place. Yes, Delete sits away from where Delete was, so a double
	-- click on Delete cannot land on it.
	ui.yes = UI.Button(card, "Yes, Delete", 110, function()
		ns.BagsFullConfirm(true)
	end)
	ui.yes:SetPoint("TOPLEFT", 16, -122)
	ui.cancel = UI.Button(card, "Cancel", 80, function()
		ns.BagsFullConfirm(false)
	end)
	ui.cancel:SetPoint("TOPRIGHT", -16, -122)
	ui.yes:Hide()
	ui.cancel:Hide()
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
		state.moved, state.confirm = nil, nil
	end)
	card:HookScript("OnDragStop", function()
		state.moved = true
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
	UI.Enable(ui.delete, c ~= nil and not state.busy)
	-- Asking "delete this?": the question and its two buttons take the row's place.
	local asking = c ~= nil and state.confirm == c
	ui.head:SetText(asking and (RED .. "Delete this? It cannot be brought back.|r") or (GOLD .. "Least valuable:|r"))
	ui.prev:SetShown(not asking)
	ui.next:SetShown(not asking)
	ui.pos:SetShown(not asking)
	ui.never:SetShown(not asking)
	ui.delete:SetShown(not asking and ns.db.bagsfulldelete == true)
	ui.yes:SetShown(asking)
	ui.cancel:SetShown(asking)
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
	local asked = was ~= nil and state.confirm == was
	state.confirm, state.busy = nil, nil
	wipe(waiting)
	state.list = Candidates()
	state.idx = 1
	if keep and was then
		for i, e in ipairs(state.list) do
			if e.bag == was.bag and e.slot == was.slot and e.id == was.id then
				state.idx = i
				if asked and e.count == was.count then
					state.confirm = e -- the same stack: the question stands
				end
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
	state.moved, state.confirm = nil, nil
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
		state.confirm = nil
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

-- -------------------------------------------------------------------- delete

-- Whether deleting c asks first: the option, and always for a rare or better item.
function ns.BagsFullAsks(c)
	return ns.db.bagsfullconfirm ~= false or (type(c.quality) == "number" and c.quality or RARE) >= RARE
end

local function Refuse(text)
	ns:Print(text)
	Update(true)
	return false
end

-- What the cursor holds: nil for nothing, else its kind and id ("?" when the client will not say).
local function CursorHolds()
	local ok, kind, id = Call(GetCursorInfo)
	if not ok or Secret(kind) or Secret(id) then
		return "?"
	end
	return kind, id
end

-- Deletes the stack in c's slot. Reached only from the player's click on Delete or on Yes, Delete:
-- the game itself refuses DeleteCursorItem outside a click. Every step is checked, and a step that
-- fails puts the item back and says so.
local function DeleteNow(c)
	if not (ns.enabled and ns.db and ns.db.bagsfull and ns.db.bagsfulldelete == true) then
		return false
	end
	local C = C_Container
	if not (C and C.PickupContainerItem and C.GetContainerItemInfo) or type(DeleteCursorItem) ~= "function" then
		return Refuse("this client has no way to delete it for you.")
	end
	if CursorHolds() ~= nil then
		return Refuse("put down what your cursor holds first.")
	end
	-- The slot as it is now: still the same stack, and still one that can be marked.
	local e = ns.SlotValue(c.bag, c.slot)
	if not e or e.id ~= c.id or e.count ~= c.count then
		return Refuse("that slot changed. Look again.")
	end
	local okI, info = Call(C.GetContainerItemInfo, c.bag, c.slot)
	if not (okI and type(info) == "table") or Secret(info.isLocked) or info.isLocked == true then
		return Refuse("that item is locked (in a trade, or being moved).")
	end
	if not Call(C.PickupContainerItem, c.bag, c.slot) then
		return Refuse("could not pick that item up.")
	end
	local kind, id = CursorHolds()
	if kind ~= "item" or id ~= c.id then
		Call(ClearCursor) -- whatever it is goes back where it was
		return Refuse("could not pick that item up.")
	end
	local okD = Call(DeleteCursorItem)
	if not okD or CursorHolds() ~= nil then
		Call(ClearCursor)
		return Refuse("the game did not delete it. It is back in its slot.")
	end
	state.confirm, state.busy = nil, true -- until the bags report the change
	ns:Print("deleted " .. ItemText(c) .. " (" .. root.Money(c.value) .. " " .. ns.Detail(c) .. ")")
	Render()
	return true
end

-- The Delete button: asks, or deletes at once when asking is switched off.
function ns.BagsFullDelete()
	local c = state.list[state.idx]
	if not (ui and c) or state.busy or ns.db.bagsfulldelete ~= true then
		return
	end
	if ns.BagsFullAsks(c) then
		state.confirm = c
		Render()
		return
	end
	return DeleteNow(c)
end

-- Yes, Delete and Cancel.
function ns.BagsFullConfirm(yes)
	local c = state.list[state.idx]
	local asked = ui ~= nil and c ~= nil and state.confirm == c
	state.confirm = nil
	if asked and yes then
		return DeleteNow(c)
	end
	if ui then
		Render()
	end
end

-- The default bags opened, closed or were redrawn: the card moves off them and the coin goes on
-- the browsed slot. Once more on the next frame, when the bags have their place.
local again = false
function ns.BagsFullBagsChanged()
	if not ns.BagsFullShown() then
		return
	end
	Dock()
	Highlight(state.list[state.idx])
	if again or not (C_Timer and C_Timer.After) then
		return
	end
	again = true
	C_Timer.After(0, function()
		again = false
		root.Try(ns, "bags full", function()
			if ns.BagsFullShown() then
				Dock()
			end
		end)
	end)
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
	elseif ns.BagsFullShown() then
		if ns.db.bagsfulldelete ~= true then
			state.confirm = nil
		end
		Render() -- the Delete button comes or goes
	end
	if onOption then
		return onOption(...)
	end
end
