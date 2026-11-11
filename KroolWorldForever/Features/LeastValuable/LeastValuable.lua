-- Least Valuable: a copper coin on the bag slot worth the least, so you know what to sell or drop
-- first. A slot is worth its whole stack at the best of three prices: the vendor's, the auction
-- house's and the disenchant value (both after the 5% auction cut, compared the way Disenchant
-- Value does). A bound item has no auction price, and its disenchant counts only when you can
-- disenchant it yourself. Advice only: it marks a slot and never sells, moves or deletes.
--
-- Never marked, since the cheapest slot would otherwise often be something you keep:
--   - anything worth nothing anywhere (Hearthstone, soul shards, conjured food and water)
--   - quest items and items that start a quest, keys, ammunition
--   - class reagents (item class 5: Ankhs, candles, runes, seeds, powders; and Light Feathers)
--   - profession tools: weapon subclass 14 (Mining Pick, Skinning Knife, Blacksmith Hammer,
--     Arclight Spanner), fishing poles (subclass 20), and the ids in KEEP (enchanting rods...)
--   - unopened containers (clams, lockboxes): what they are worth is inside
--   - gear in an equipment set, and anything you ignore (/kwl ignore)
--   - an uncommon or better item that could be auctioned but has neither an auction price nor a
--     disenchant value: its vendor price says nothing about what it is worth
-- Classes and ids are from the 1.12 item data (tools/killvalue-data, checked 2026-11-10).
--
-- Each slot counts on its own, so of two part stacks of one item the smaller is the cheaper.
-- Equal values go to the first slot in bag order. The coin is one frame of ours, moved onto the
-- marked slot's button after every redraw of a default bag frame (combined or separate bags).
-- Bag addons that replace those frames get the tooltip line and the hub card, but no coin.

local _, root = ...
local ns = root.Feature("leastvaluable")

local WEAPON = 2
local UNCOMMON = 2
local SKIP_CLASS = { [5] = "reagent", [6] = "ammo", [12] = "quest", [13] = "key" }
local SKIP_WEAPON = { [14] = "tool", [20] = "tool" } -- misc weapons are the tools; 20 fishing poles
local KEEP = {
	[6948] = "nosale", -- Hearthstone (it has no price anyway)
	[6218] = "tool", -- Runed Copper Rod
	[6339] = "tool", -- Runed Silver Rod
	[11130] = "tool", -- Runed Golden Rod
	[11145] = "tool", -- Runed Truesilver Rod
	[16207] = "tool", -- Runed Arcanite Rod
	[9149] = "tool", -- Philosopher's Stone
	[10498] = "tool", -- Gyromatic Micro-Adjustor
	[15846] = "tool", -- Salt Shaker
	[17056] = "reagent", -- Light Feather (class 15, not 5)
}

-- What /kwl says it left out (slots, one and many), in this order. "nosale" and empty slots go
-- unsaid.
local SKIPPED = {
	{ "unpriced", "uncommon or better item with no auction price", "uncommon or better items with no auction price" },
	{ "ignored", "ignored item", "ignored items" },
	{ "set", "equipment-set item", "equipment-set items" },
	{ "tool", "profession tool", "profession tools" },
	{ "reagent", "class reagent", "class reagents" },
	{ "ammo", "stack of ammunition", "stacks of ammunition" },
	{ "openable", "unopened container", "unopened containers" },
	{ "quest", "quest item", "quest items" },
	{ "key", "key", "keys" },
	{ "pending", "item still loading", "items still loading" },
}

-- The mark: a still copper coin in the slot's top-right corner. Blizzard's own coin art (the
-- "coin-copper" atlas beside the money under your backpack: Mainline MoneyFrame.xml, forever
-- branch; in the forever atlas list). Top-left is Blizzard's (junk coin, upgrade arrow) and
-- bottom-right the stack count; top-right is free.
local MARK_ATLAS = "coin-copper"
local MARK_SIZE = 15
local GREY, OLD = "|cffaaaaaa", "|cffff9955"
local HOW = { vendor = "at a vendor", auction = "at auction after the 5% cut", disenchant = "disenchanted, after the 5% cut" }

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

-- -------------------------------------------------------------------- value

-- The backpack and the equipped bags, but not the reagent bag (bag 5: ContainerFrame_IsReagentBag,
-- Mainline ContainerFrame.lua, forever branch): what is kept there is kept for crafting.
local REAGENT_BAG = 5
local function Bags()
	local bags = {}
	for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
		if bag ~= REAGENT_BAG then
			bags[#bags + 1] = bag
		end
	end
	return bags
end

-- One scan's shared facts: prices and disenchant values are looked up once per item.
local function Context()
	local DE = root.features.disenchant
	return {
		hasAH = root.HasAuctionator(),
		canDE = DE and DE.CanDisenchant and DE.CanDisenchant() or false,
		DE = DE,
		items = {},
		pending = {}, -- item ids whose info has not loaded yet
	}
end

-- What an item is, and its prices, from its link (which tells apart suffixes and item levels).
local function Facts(ctx, link, id)
	local key = link or id
	local f = ctx.items[key]
	if f then
		return f
	end
	local ok, name, _, quality, itemLevel, _, _, _, _, _, _, sellPrice, classID, subclassID =
		Call(C_Item and C_Item.GetItemInfo, link or id)
	if not (ok and type(name) == "string") then
		f = { pending = true } -- not cached yet: GET_ITEM_INFO_RECEIVED rescans
	else
		f = {
			name = name,
			quality = type(quality) == "number" and quality or 1,
			sell = type(sellPrice) == "number" and sellPrice > 0 and sellPrice or nil,
		}
		f.skip = KEEP[id] or SKIP_CLASS[classID] or (classID == WEAPON and SKIP_WEAPON[subclassID]) or nil
		if not f.skip then
			f.auction = root.AuctionPrice(link or id)
			f.auctionAge = f.auction and root.AuctionAge(link or id) or nil
			local e = ctx.DE and ctx.DE.Evaluate and ctx.DE.Evaluate(id, quality, classID, itemLevel)
			f.de = e and e.value or nil
			f.deStale = e and e.stale or nil
		end
	end
	ctx.items[key] = f
	return f
end

-- The best of the three after the cut: how ("vendor", "auction", "disenchant") and the copper.
local function Best(ctx, de, auction, vendor)
	if ctx.DE and ctx.DE.Best then
		return ctx.DE.Best(de, auction, vendor)
	end
	if vendor then
		return "vendor", vendor
	end
	return nil
end

-- One bag slot: { bag, slot, id, link, name, quality, count, unit, value, how, stale, noAuction },
-- or nil and why it does not count: "empty", "nosale" or a SKIPPED key.
function ns.SlotValue(bag, slot, ctx)
	ctx = ctx or Context()
	local C = C_Container
	local ok, info = Call(C and C.GetContainerItemInfo, bag, slot)
	if not (ok and type(info) == "table") then
		return nil, "empty"
	end
	local id, link, count = info.itemID, info.hyperlink, info.stackCount
	if Secret(id) or Secret(link) or Secret(count) or type(id) ~= "number" then
		return nil, "empty"
	end
	link = type(link) == "string" and link or nil
	count = type(count) == "number" and count > 0 and count or 1
	if ns.db.ignore[id] then
		return nil, "ignored"
	end
	if info.hasLoot == true then
		return nil, "openable"
	end
	local okQ, quest = Call(C.GetContainerItemQuestInfo, bag, slot)
	if okQ and type(quest) == "table" and (quest.isQuestItem == true or type(quest.questID) == "number") then
		return nil, "quest"
	end
	local okS, inSet = Call(C.GetContainerItemEquipmentSetInfo, bag, slot)
	if okS and inSet == true then
		return nil, "set"
	end
	local f = Facts(ctx, link, id)
	if f.pending then
		ctx.pending[id] = true
		return nil, "pending"
	end
	if f.skip then
		return nil, f.skip
	end
	local bound = info.isBound == true
	local vendor = info.hasNoValue ~= true and f.sell or nil
	local auction = not bound and f.auction or nil
	local de = (not bound or ctx.canDE) and f.de or nil
	if not bound and f.quality >= UNCOMMON and not auction and not de then
		return nil, "unpriced"
	end
	local how, unit = Best(ctx, de, auction, vendor)
	if not how then
		return nil, "nosale"
	end
	local stale
	if how == "auction" and root.AuctionStale(f.auctionAge) then
		stale = f.auctionAge
	elseif how == "disenchant" then
		stale = f.deStale
	end
	return {
		bag = bag,
		slot = slot,
		id = id,
		link = link,
		name = f.name,
		quality = f.quality,
		count = count,
		unit = unit,
		value = unit * count,
		how = how,
		stale = stale,
		-- a tradeable item valued at the vendor only because the auction house has no price yet
		noAuction = ctx.hasAH and not bound and not auction and f.quality >= 1 or nil,
	}
end

-- Every slot that counts, in bag order; the cheapest (the first of equals); how many slots each
-- reason left out; and the ids still loading.
function ns.Scan()
	local list, skipped, cheapest = {}, {}, nil
	if not (C_Container and C_Container.GetContainerNumSlots) then
		return list, nil, skipped, {}
	end
	local ctx = Context()
	for _, bag in ipairs(Bags()) do
		local ok, n = Call(C_Container.GetContainerNumSlots, bag)
		n = ok and not Secret(n) and type(n) == "number" and n or 0
		for slot = 1, n do
			local e, why = ns.SlotValue(bag, slot, ctx)
			if e then
				list[#list + 1] = e
				if not cheapest or e.value < cheapest.value then
					cheapest = e
				end
			elseif why ~= "empty" then
				skipped[why] = (skipped[why] or 0) + 1
			end
		end
	end
	return list, cheapest, skipped, ctx.pending
end

-- "2 x 3c at a vendor, no auction price"
function ns.Detail(m)
	local text = GREY .. HOW[m.how] .. "|r"
	if m.count > 1 then
		text = GREY .. m.count .. " x|r " .. root.Money(m.unit) .. GREY .. " " .. HOW[m.how] .. "|r"
	end
	if m.stale then
		text = text .. " " .. OLD .. "(price " .. root.SeenText(m.stale) .. ")|r"
	end
	if m.noAuction then
		text = text .. GREY .. ", no auction price|r"
	end
	return text
end

-- -------------------------------------------------------------------- bag frames and the coin

-- The default bag frames: the combined one and every separate one.
local function BagFrames()
	local out = {}
	if type(ContainerFrameCombinedBags) == "table" then
		out[#out + 1] = ContainerFrameCombinedBags
	end
	local list = type(ContainerFrameContainer) == "table" and ContainerFrameContainer.ContainerFrames
	if type(list) == "table" then
		for _, f in ipairs(list) do
			out[#out + 1] = f
		end
	end
	return out
end

local function BagsShown()
	for _, f in ipairs(BagFrames()) do
		local ok, shown = Call(f.IsShown, f)
		if ok and shown == true then
			return true
		end
	end
	return false
end

-- The button showing a bag slot, in whichever default bag frame is open (nil when none is).
local function FindButton(bag, slot)
	local ok, button = Call(ContainerFrameUtil_GetItemButtonAndContainer, bag, slot)
	return ok and type(button) == "table" and button or nil
end

local coin -- our frame, false when it could not be made
local function Coin()
	if coin == nil then
		coin = false
		local f = CreateFrame("Frame")
		f:Hide()
		local tex = f:CreateTexture(nil, "OVERLAY")
		tex:SetAtlas(MARK_ATLAS)
		tex:SetSize(MARK_SIZE, MARK_SIZE)
		tex:SetPoint("TOPRIGHT", -1, -1)
		coin = f
	end
	return coin or nil
end

-- Puts the coin on the marked slot's button, or takes it away. Our frame takes no mouse, so the
-- button underneath works as before.
function ns.Place()
	local m = ns.enabled and ns.db.glow and ns.mark or nil -- "glow": the option's first name, kept for saved settings
	local button = m and FindButton(m.bag, m.slot) or nil
	if not button then
		if coin then
			coin:Hide()
		end
		ns.markButton = nil
		return
	end
	local c = Coin()
	if not c then
		return
	end
	if ns.markButton ~= button then
		c:SetParent(button)
		c:ClearAllPoints()
		c:SetAllPoints(button)
		ns.markButton = button
	end
	local ok, level = Call(button.GetFrameLevel, button)
	if ok and type(level) == "number" then
		c:SetFrameLevel(level + 2) -- above the cooldown swipe
	end
	c:Show()
end
ns.Coin = function()
	return coin or nil
end -- test seam

local dirty, pending = true, {} -- pending: item ids a rescan waits on

-- Scans the bags, marks the cheapest slot and moves the coin. Returns the scan.
local function Refresh()
	dirty = false
	local list, cheapest, skipped, waiting = ns.Scan()
	ns.mark, pending = cheapest, waiting or {}
	ns.Place()
	return list, cheapest, skipped
end
ns.Refresh = Refresh

-- An open hub card shows the new mark (it rescans, when dirty, as it draws).
local function HubChanged()
	if root.RefreshHub then
		pcall(root.RefreshHub)
	end
end

-- The bags changed: rescan now when they are on screen, else on the next look.
local function Changed()
	dirty = true
	if ns.enabled and BagsShown() then
		Refresh()
	end
	if ns.enabled then
		HubChanged()
	end
end

local soon = false
local function RefreshSoon()
	if not (C_Timer and C_Timer.After) then
		Changed()
		return
	end
	if soon then
		return
	end
	soon = true
	C_Timer.After(0.2, function()
		soon = false
		root.Try(ns, "item info", Changed)
	end)
end

-- After a default bag frame redraws its buttons (opening, sorting, a bag swapped): the coin
-- follows the slot onto whatever button shows it now.
local function OnBagsDrawn()
	if not ns.enabled then
		return
	end
	root.Try(ns, "bags", function()
		if dirty then
			Refresh()
		else
			ns.Place()
		end
	end)
end

local function OnBagsClosed()
	if ns.enabled then
		root.Try(ns, "bags", ns.Place)
	end
end

local hookedFrames = {}
local function HookBags()
	if type(hooksecurefunc) ~= "function" then
		return
	end
	for _, f in ipairs(BagFrames()) do
		if not hookedFrames[f] and type(f.UpdateItems) == "function" then
			hookedFrames[f] = true
			hooksecurefunc(f, "UpdateItems", OnBagsDrawn)
		end
	end
	local ER = EventRegistry
	if not ns.closeHooked and type(ER) == "table" and type(ER.RegisterCallback) == "function" then
		ns.closeHooked = true
		pcall(ER.RegisterCallback, ER, "ContainerFrame.CloseBag", OnBagsClosed, ns)
		pcall(ER.RegisterCallback, ER, "ContainerFrame.CloseAllBags", OnBagsClosed, ns)
	end
end

-- -------------------------------------------------------------------- tooltip

-- Only on the marked slot itself: the tooltip's owner is that slot's bag button.
local function Annotate(tooltip, data)
	local owner = tooltip.GetOwner and tooltip:GetOwner()
	if type(owner) ~= "table" or type(owner.GetBagID) ~= "function" or type(owner.GetID) ~= "function" then
		return
	end
	if dirty then
		Refresh() -- a bag addon's frames: nothing rescanned when the bags changed
	end
	local m = ns.mark
	local okB, bag = pcall(owner.GetBagID, owner)
	local okS, slot = pcall(owner.GetID, owner)
	if not (m and okB and okS) or Secret(bag) or Secret(slot) or bag ~= m.bag or slot ~= m.slot or data.id ~= m.id then
		return
	end
	tooltip:AddDoubleLine(root.UI.InlineIcon(ns.icon, 14) .. " |cffffd27fLeast valuable in your bags|r", root.Money(m.value))
	tooltip:AddLine(ns.Detail(m))
end

local function OnItemTooltip(tooltip, data)
	if tooltip ~= GameTooltip or not (ns.enabled and ns.db and ns.db.tooltip) then
		return
	end
	-- Secret first: even a truth test on a secret value errors, and this runs outside TryQuiet.
	local id
	if type(data) == "table" then
		id = data.id
	end
	if Secret(id) or id == nil then
		return
	end
	root.TryQuiet(ns, "tooltip", Annotate, tooltip, data)
end
ns.OnItemTooltip = OnItemTooltip -- test seam

-- -------------------------------------------------------------------- ignore list

local function NameOf(id)
	local ok, name = Call(C_Item and C_Item.GetItemNameByID, id)
	return ok and type(name) == "string" and name or ("item " .. id)
end

-- An item id from a shift-clicked link or a number.
local function ItemArg(arg)
	return tonumber(arg:match("item:(%d+)") or arg:match("^%s*(%d+)%s*$") or "")
end

function ns.Ignore(id, name)
	ns.db.ignore[id] = name or ns.db.ignore[id] or NameOf(id)
	ns:Print("not marking " .. ns.db.ignore[id] .. " any more (/kwl unignore " .. id .. " to undo)")
	Refresh()
	HubChanged()
end

function ns.Unignore(arg)
	local id = ItemArg(arg)
	for itemId, name in pairs(ns.db.ignore) do
		if itemId == id or name:lower() == strtrim(arg):lower() then
			ns.db.ignore[itemId] = nil
			ns:Print("marking " .. name .. " again")
			Refresh()
			HubChanged()
			return true
		end
	end
	ns:Print("not on the ignore list: " .. arg .. " (/kwl ignored)")
	return false
end

-- -------------------------------------------------------------------- definition

ns.title = "Least Valuable"
ns.description = "Marks the bag slot worth the least, so you know what to sell or drop first: its whole stack "
	.. "at the best of its vendor price, auction price and disenchant value. It never marks quest items, keys, "
	.. "ammunition, class reagents, profession tools, unopened containers, equipment-set gear, items worth nothing "
	.. "(the Hearthstone), or anything you /kwl ignore."
ns.icon = "Interface\\Icons\\INV_Misc_Coin_01"
ns.blurb = "Marks the bag slot worth the least"
ns.options = {
	{
		key = "glow",
		type = "toggle",
		label = "Mark It In Your Bags",
		tooltip = "A copper coin in the top-right corner of the slot worth the least, in the default bags. "
			.. "Its value counts the whole stack. /kwl ignore <item> stops an item from being marked.",
		default = true,
	},
	{
		key = "tooltip",
		type = "toggle",
		label = "Say It On The Tooltip",
		tooltip = "Adds what the marked slot is worth, and at which price, to its tooltip.",
		default = true,
	},
}
ns.slash = { "/kwl", "/leastvaluable" }

local function SkippedText(skipped)
	local parts = {}
	for _, s in ipairs(SKIPPED) do
		local n = skipped[s[1]]
		if n and n > 0 then
			parts[#parts + 1] = n .. " " .. (n == 1 and s[2] or s[3])
		end
	end
	return #parts > 0 and table.concat(parts, ", ") or nil
end

local SHOW = 5
local function PrintList()
	local list, _, skipped = Refresh()
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
	if #list == 0 then
		ns:Print("nothing in your bags to mark.")
	else
		ns:Print("least valuable in your bags:")
		for i = 1, math.min(SHOW, #list) do
			local e = list[i]
			print(("  %d. %s%s%s: %s %s"):format(i, root.UI.ItemIcon(e.id), e.link or e.name, e.count > 1 and (" x" .. e.count) or "", root.Money(e.value), ns.Detail(e)))
		end
	end
	if ns.mark and ns.db.glow and BagsShown() and not ns.markButton then
		print(OLD .. "  the coin found no button for that slot in your open bags|r")
	end
	local left = SkippedText(skipped)
	if left then
		print(GREY .. "  not counted: " .. left .. "|r")
	end
	if (skipped.unpriced or 0) > 0 then
		print(GREY .. "  " .. (root.HasAuctionator() and "scan the auction house to price those" or "Auctionator prices them") .. "|r")
	end
	if not root.HasAuctionator() then
		print(OLD .. "  vendor prices only: Auctionator is not installed|r")
	end
end

local function PrintIgnored()
	local names = {}
	for id, name in pairs(ns.db.ignore) do
		names[#names + 1] = name .. " (" .. id .. ")"
	end
	table.sort(names)
	ns:Print(#names == 0 and "ignoring nothing" or ("never marked: " .. table.concat(names, ", ")))
end

function ns.OnSlash(msg)
	msg = strtrim(msg or "")
	local cmd, arg = msg:match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()
	if cmd == "" or cmd == "list" then
		PrintList()
	elseif cmd == "ignore" then
		local id = arg ~= "" and ItemArg(arg) or nil
		if id then
			ns.Ignore(id)
		elseif arg == "" and ns.mark then
			ns.Ignore(ns.mark.id, ns.mark.name)
		else
			ns:Print(arg == "" and "nothing is marked. /kwl ignore <shift-click an item>" or "no item in that. /kwl ignore <shift-click an item>")
		end
	elseif cmd == "unignore" and arg ~= "" then
		ns.Unignore(arg)
	elseif cmd == "ignored" then
		PrintIgnored()
	elseif cmd == "options" or cmd == "config" then
		root.OpenSettings(ns)
	else
		ns:Print("commands:")
		print("  /kwl                  the five least valuable slots, and what was not counted")
		print("  /kwl ignore           never mark the marked item again")
		print("  /kwl ignore <item>    never mark that item (shift-click it into the chat line)")
		print("  /kwl unignore <item>  mark it again (item, id or name)")
		print("  /kwl ignored          the ignore list")
		print("  /kwl options")
	end
end

function ns.HubStatus()
	if dirty then
		Refresh()
	end
	local m = ns.mark
	local text
	if m then
		text = "Least valuable: " .. root.UI.ItemIcon(m.id, 0) .. m.name .. (m.count > 1 and (" x" .. m.count) or "") .. ", " .. root.Money(m.value)
	else
		text = GREY .. "Nothing to mark in your bags|r"
	end
	if not root.HasAuctionator() then
		text = text .. " " .. OLD .. "(vendor prices only)|r"
	end
	return text
end

-- -------------------------------------------------------------------- lifecycle

function ns.OnLoad()
	ns.db.ignore = type(ns.db.ignore) == "table" and ns.db.ignore or {}
	root.OnAuctionPrices(function()
		root.Try(ns, "auction prices", Changed) -- a scan reprices the bags
	end)
end

-- Tooltip and bag hooks cannot be removed, so they are added once and check ns.enabled.
function ns.OnEnable()
	if not ns.tooltipHooked and TooltipDataProcessor and Enum and Enum.TooltipDataType then
		ns.tooltipHooked = true
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
	end
	HookBags()
	Changed()
end

function ns.OnDisable()
	ns.Place() -- off: the coin goes
end

function ns.OnOptionChanged()
	ns.Place()
end

ns:RegisterEvent("BAG_UPDATE_DELAYED", Changed)
ns:RegisterEvent("EQUIPMENT_SETS_CHANGED", Changed)
ns:RegisterEvent("SPELLS_CHANGED", function()
	dirty = true -- learning to disenchant reprices bound gear; the next look rescans
end)
ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemId)
	if not Secret(itemId) and pending[itemId] then -- the secret check first: testing a secret errors
		RefreshSoon()
	end
end)
