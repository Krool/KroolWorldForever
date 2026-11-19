-- Least Valuable behavior checks. Runs after stubs.lua and the whole bundle.

local failures, count = 0, 0
local realPrint = print
local function check(label, got, want)
	count = count + 1
	if got ~= want then
		failures = failures + 1
		realPrint("FAIL: " .. label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
	else
		realPrint("ok:   " .. label)
	end
end
local function has(list, needle)
	for _, l in ipairs(list) do
		if tostring(l):find(needle, 1, true) then
			return true
		end
	end
	return false
end
local function capture(fn)
	local out = {}
	print = function(...)
		local t = {}
		for i = 1, select("#", ...) do
			t[#t + 1] = tostring((select(i, ...)))
		end
		out[#out + 1] = table.concat(t, " ")
	end
	local ok, err = pcall(fn)
	print = realPrint
	if not ok then
		error(err)
	end
	return out
end

local root = __ns
local ns = root.features.leastvaluable

-- ---------------------------------------------------------------- fixtures

-- Greys and whites.
local FANG, SCALE, CLOTH, WATER = 900101, 900102, 900103, 900104
Items[FANG] = { name = "Broken Fang", quality = 0, sell = 3, class = 15 }
Items[SCALE] = { name = "Dull Scale", quality = 0, sell = 5, class = 15 }
Items[CLOTH] = { name = "Linen Cloth", quality = 1, sell = 13, class = 7 }
Items[WATER] = { name = "Refreshing Spring Water", quality = 1, sell = 1, class = 0 }
-- Things never marked (ids and classes from the 1.12 data).
local HEARTH, PICK, POLE, ROD, FEATHER, ANKH, ARROW, KEY, QUESTITEM =
	6948, 2901, 6256, 6218, 17056, 17030, 2512, 900110, 900111
Items[HEARTH] = { name = "Hearthstone", quality = 1, sell = 0, class = 15 }
Items[PICK] = { name = "Mining Pick", quality = 1, sell = 16, class = 2, sub = 14 }
Items[POLE] = { name = "Fishing Pole", quality = 1, sell = 4, class = 2, sub = 20 }
Items[ROD] = { name = "Runed Copper Rod", quality = 1, sell = 24, class = 7 }
Items[FEATHER] = { name = "Light Feather", quality = 1, sell = 7, class = 15 }
Items[ANKH] = { name = "Ankh", quality = 1, sell = 500, class = 5 }
Items[ARROW] = { name = "Rough Arrow", quality = 1, sell = 1, class = 6, sub = 2 }
Items[KEY] = { name = "Old Key", quality = 1, sell = 1, class = 13 }
Items[QUESTITEM] = { name = "Gnoll Paw", quality = 1, sell = 1, class = 12 }
local CLAM, LETTER, SETGEAR = 900112, 900113, 900114
Items[CLAM] = { name = "Small Barnacled Clam", quality = 1, sell = 2, class = 15 }
Items[LETTER] = { name = "A Sealed Letter", quality = 1, sell = 2, class = 15 } -- starts a quest
Items[SETGEAR] = { name = "Worn Belt", quality = 1, sell = 2, class = 4, ilvl = 10 }
-- Greens: one known to the disenchant tables by level (armor 28 -> table 4), one not gear.
local CHEST, TRINKET = 900120, 900121
Items[CHEST] = { name = "Forever Chestguard", quality = 2, ilvl = 28, sell = 500, class = 4 }
Items[TRINKET] = { name = "Shiny Bauble", quality = 2, sell = 40, class = 15 }
-- Table 4's materials (see the disenchant suite): 0.75*1.5*1000 + 0.2*1.5*5000 + 0.05*3000.
local SOUL, ASTRAL, GLIMMER = 11083, 11082, 11084
local DE_VALUE = 2775
local function MatPrices()
	Prices[SOUL], Prices[ASTRAL], Prices[GLIMMER] = 1000, 5000, 3000
end

local function Mark()
	ns.Refresh()
	local m = ns.mark
	return m and Items[m.id].name or nil
end
local function Why(bag, slot)
	local e, why = ns.SlotValue(bag, slot)
	return e and "counted" or why
end

-- ---------------------------------------------------------------- lifecycle

FireEvent("ADDON_LOADED", "KroolWorldForever")
local db = KroolWorldForeverDB.features.leastvaluable
check("feature slice created", type(db), "table")
check("on by default", db.enabled, true)
check("coin on by default", db.glow, true)
check("tooltip on by default", db.tooltip, true)
check("ignore list made", type(db.ignore), "table")
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("enabled after login", ns.enabled, true)
check("item tooltip hooked", has(TooltipChains[Enum.TooltipDataType.Item] or {}, tostring(ns.OnItemTooltip)), true)
local hooks = #TooltipChains[Enum.TooltipDataType.Item]
local drawn = ContainerFrameCombinedBags.UpdateItems
ns.OnEnable()
check("tooltip hooked once only", #TooltipChains[Enum.TooltipDataType.Item], hooks)
check("bag redraw hooked once only", ContainerFrameCombinedBags.UpdateItems, drawn)
check("close callbacks registered", #(Callbacks["ContainerFrame.CloseBag"] or {}), 1)
check("/kwl registered", SLASH_KROOLWORLDFOREVER_LEASTVALUABLE1, "/kwl")
check("hub icon", ns.icon, "Interface\\Icons\\INV_Misc_Coin_01")
check("hub blurb", type(ns.blurb), "string")

-- ---------------------------------------------------------------- value

EmptyBags()
check("empty bags: nothing marked", Mark(), nil)
check("empty bags: hub says so", ns.HubStatus():find("Nothing to mark", 1, true) ~= nil, true)

-- Stack size counts: ten 3c fangs (30c) are worth more than one 5c scale.
Put(0, 1, { id = FANG, count = 10 })
Put(0, 2, { id = SCALE, count = 1 })
check("the whole stack counts", Mark(), "Dull Scale")
check("value is the stack's", ns.mark.value, 5)
Put(0, 2, { id = SCALE, count = 7 }) -- 35c
check("a bigger stack is worth more", Mark(), "Broken Fang")
check("unit and count kept", ns.mark.unit .. "x" .. ns.mark.count, "3x10")
check("how: vendor", ns.mark.how, "vendor")

-- Equal values: the first slot in bag order.
EmptyBags()
Put(0, 3, { id = SCALE })
Put(0, 1, { id = SCALE })
Mark()
check("ties go to the first slot", ns.mark.slot, 1)

-- Two part stacks of one item: each slot on its own, the smaller is the cheaper.
EmptyBags()
Put(0, 1, { id = FANG, count = 4 })
Put(0, 2, { id = FANG, count = 2 })
Mark()
check("part stacks count apart", ns.mark.slot .. ":" .. ns.mark.value, "2:6")

-- An auction price beats the vendor's after the 5% cut.
EmptyBags()
Put(0, 1, { id = CLOTH, count = 2 }) -- vendor 26c
Put(0, 2, { id = FANG, count = 10 }) -- vendor 30c
Prices[CLOTH] = 100 -- 95c net each
check("auction price counted", Mark(), "Broken Fang")
local e = ns.SlotValue(0, 1)
check("auction after the cut", e.value, 190)
check("how: auction", e.how, "auction")
Prices[CLOTH] = 10 -- 9.5c net: the vendor's 13c wins
e = ns.SlotValue(0, 1)
check("vendor wins when it pays more", e.how .. ":" .. e.value, "vendor:26")
Prices[CLOTH] = nil
e = ns.SlotValue(0, 1)
check("a white with no auction price: vendor, said so", e.noAuction, true)
check("detail says no auction price", ns.Detail(e):find("no auction price", 1, true) ~= nil, true)
e = ns.SlotValue(0, 2)
check("a grey with no auction price: nothing said", e.noAuction, nil)

-- Old auction prices still count, and say how old.
Prices[CLOTH], Ages[CLOTH] = 100, 5
e = ns.SlotValue(0, 1)
check("old price kept", e.stale, 5)
check("old price dated", ns.Detail(e):find("seen 5 days ago", 1, true) ~= nil, true)
Prices[CLOTH], Ages[CLOTH] = nil, nil

-- Greens: disenchant counts for an unbound one; a bound one only if you can disenchant it.
EmptyBags()
MatPrices()
Put(0, 1, { id = CHEST })
e = ns.SlotValue(0, 1)
check("unbound green: disenchant value", e.how .. ":" .. e.value, "disenchant:" .. DE_VALUE * 0.95)
Put(0, 1, { id = CHEST, bound = true })
CanDisenchant = false
e = ns.SlotValue(0, 1)
check("bound green, no enchanter: vendor", e.how .. ":" .. e.value, "vendor:500")
CanDisenchant = true
e = ns.SlotValue(0, 1)
check("bound green, enchanter: disenchant", e.how, "disenchant")
check("a classic green's disenchant is not marked unconfirmed", e.unsure, nil)
check("its detail does not say unconfirmed", ns.Detail(e):find("unconfirmed", 1, true), nil)
-- A low blue (item level 20 or less): Forever's disenchant brackets for it are unmeasured.
local LOWBLUE = 900077
Items[LOWBLUE] = { name = "Forever Shoulders", quality = 3, ilvl = 18, sell = 400, class = 4 }
Prices[10978] = 3000 -- Small Glimmering Shard, the low blue bracket
Put(0, 1, { id = LOWBLUE })
e = ns.SlotValue(0, 1)
check("low blue: priced by disenchant", e.how, "disenchant")
check("low blue: unsure carried", e.unsure, true)
check("low blue: detail says unconfirmed", ns.Detail(e):find("(unconfirmed)", 1, true) ~= nil, true)
Put(0, 1, { id = LOWBLUE, bound = true })
CanDisenchant = false
check("low blue priced at the vendor: not unsure", (ns.SlotValue(0, 1)).unsure, nil)
Prices[10978] = nil
CanDisenchant = true
Put(0, 1, { id = CHEST, bound = true })
CanDisenchant = false
wipe(Prices)
Put(0, 1, { id = CHEST })
check("unbound green, nothing priced: left out", Why(0, 1), "unpriced")
Put(0, 1, { id = TRINKET })
check("unbound green, not gear, no price: left out", Why(0, 1), "unpriced")
Prices[TRINKET] = 2000
check("unbound green with an auction price: counted", Why(0, 1), "counted")
Prices[TRINKET] = nil
Put(0, 1, { id = TRINKET, bound = true })
check("bound green: its vendor price is all there is", Why(0, 1), "counted")

-- What never counts.
local never = {
	{ HEARTH, {}, "nosale", "Hearthstone" },
	{ PICK, {}, "tool", "Mining Pick (weapon subclass 14)" },
	{ POLE, {}, "tool", "fishing pole (subclass 20)" },
	{ ROD, { bound = true }, "tool", "enchanting rod (by id)" },
	{ FEATHER, {}, "reagent", "Light Feather (class 15, by id)" },
	{ ANKH, {}, "reagent", "Ankh (class 5)" },
	{ ARROW, { count = 200 }, "ammo", "arrows" },
	{ KEY, {}, "key", "keys" },
	{ QUESTITEM, {}, "quest", "quest item (class 12)" },
	{ LETTER, { questID = 123 }, "quest", "item that starts a quest" },
	{ WATER, { quest = true }, "quest", "item the quest log wants" },
	{ CLAM, { loot = true }, "openable", "unopened clam" },
	{ SETGEAR, { set = true }, "set", "equipment-set gear" },
	{ SCALE, { noValue = true }, "nosale", "no sell value and no other price" },
	{ FANG, { secret = true }, "empty", "a secret item id" },
}
for _, n in ipairs(never) do
	EmptyBags()
	local s = n[2]
	s.id = n[1]
	Put(0, 1, s)
	check("never: " .. n[4], Why(0, 1), n[3])
end

-- Item info not loaded yet: left out, then counted once it arrives.
EmptyBags()
local LATE = 900130
Put(0, 1, { id = LATE })
check("not loaded: left out", Mark(), nil)
Items[LATE] = { name = "Late Pebble", quality = 0, sell = 1, class = 15 }
ContainerFrameCombinedBags:Open()
FireEvent("GET_ITEM_INFO_RECEIVED", LATE, true)
check("loaded: counted", ns.mark and ns.mark.id, LATE)
FireEvent("GET_ITEM_INFO_RECEIVED", Secret(), true) -- a secret id is not tested
-- only the ids still loading start a rescan
local LATE2 = 900131
Put(0, 2, { id = LATE2 })
ns.Refresh()
local scans, realScan = 0, ns.Scan
ns.Scan = function(...)
	scans = scans + 1
	return realScan(...)
end
FireEvent("GET_ITEM_INFO_RECEIVED", 12345, true)
check("another item's info: no rescan", scans, 0)
FireEvent("GET_ITEM_INFO_RECEIVED", LATE2, true)
check("the loading item's info: a rescan", scans, 1)
ns.Scan = realScan
ContainerFrameCombinedBags:Close()

-- the reagent bag (bag 5) is kept for crafting: never counted
EmptyBags()
NUM_TOTAL_EQUIPPED_BAG_SLOTS, BagSizes[5] = 5, 4
Put(0, 1, { id = FANG, count = 10 })
Put(5, 1, { id = SCALE, count = 1 })
ns.Refresh()
check("reagent bag: not counted", ns.mark and ns.mark.bag, 0)
NUM_TOTAL_EQUIPPED_BAG_SLOTS, BagSizes[5] = 4, nil
EmptyBags()

-- a bag change refreshes an open hub card
local hubRefreshes, realHub = 0, root.RefreshHub
root.RefreshHub = function()
	hubRefreshes = hubRefreshes + 1
end
Put(0, 1, { id = FANG, count = 10 })
FireEvent("BAG_UPDATE_DELAYED")
check("bag change: hub refreshed", hubRefreshes > 0, true)
root.RefreshHub = realHub
EmptyBags()

-- ---------------------------------------------------------------- coin

EmptyBags()
Put(0, 1, { id = FANG, count = 10 })
Put(0, 2, { id = SCALE, count = 1 })
FireEvent("BAG_UPDATE_DELAYED")
check("bags closed: no coin", ns.Coin() and ns.Coin():IsVisible() or false, false)
ContainerFrameCombinedBags:Open()
local coin = ns.Coin()
check("coin made", type(coin), "table")
check("coin on the marked slot's button", coin and coin:GetParent(), ButtonFor(0, 2))
check("coin shown", coin and coin:IsVisible(), true)
check("coin texture is Blizzard's copper coin", coin and coin.textures[1].atlas, "coin-copper")
check("coin in the top-right corner", coin and coin.textures[1].point, "TOPRIGHT")
check("coin is still: no animation", coin and (rawget(coin, "animated") or rawget(coin.textures[1], "animated")) or false, false)
check("coin size", coin and coin.textures[1].width, 15)
check("coin above the button", coin and coin.level, 12)

-- Selling the marked item moves the coin on.
Put(0, 2, nil)
FireEvent("BAG_UPDATE_DELAYED")
check("sold: coin moves to the next cheapest", coin:GetParent(), ButtonFor(0, 1))
-- A redraw that hands the slot another button: the coin follows the slot.
local before = ButtonFor(0, 1)
ContainerFrameCombinedBags:Layout()
ContainerFrameCombinedBags:UpdateItems()
check("redraw gave the slot a new button", ButtonFor(0, 1) ~= before, true)
check("coin follows the slot", coin:GetParent(), ButtonFor(0, 1))
ContainerFrameCombinedBags:Close()
check("bags closed: coin goes", coin:IsVisible(), false)

-- Separate bags: the slot is on its own bag's frame.
Put(1, 3, { id = SCALE })
BagSizes[1] = 8
ContainerFrame1:Open()
ContainerFrame2:Open()
FireEvent("BAG_UPDATE_DELAYED")
check("separate bags: coin in the right bag", coin:GetParent(), ButtonFor(1, 3))
check("separate bags: on bag 1's frame", coin:GetParent().parent, ContainerFrame2)
ContainerFrame1:Close()
check("closing another bag keeps it", coin:IsVisible(), true)
ContainerFrame2:Close()
check("closing its bag hides it", coin:IsVisible(), false)
Put(1, 3, nil)
BagSizes[1] = nil
FireEvent("BAG_UPDATE_DELAYED") -- bags closed: rescanned on the next look

-- Option: no coin, the tooltip still says it.
ContainerFrameCombinedBags:Open()
root.SetOption(ns, "glow", false)
check("coin off: hidden", coin:IsVisible(), false)
root.SetOption(ns, "glow", true)
check("coin on: back", coin:IsVisible(), true)

-- ---------------------------------------------------------------- tooltip

local function Tip(bag, slot)
	TooltipOwner = ButtonFor(bag, slot)
	local s = Bag[bag][slot]
	local tt = ShowItem(s.id)
	TooltipOwner = nil
	return tt
end
local function Said(tt)
	return has(tt.left, "Least valuable in your bags")
end
Mark()
check("tooltip on the marked slot", Said(Tip(0, 1)), true)
local tt = Tip(0, 1)
check("tooltip value is the stack's", has(tt.right, "30c"), true)
check("tooltip says how", has(tt.lines, "10 x"), true)
Put(0, 3, { id = FANG, count = 20 })
FireEvent("BAG_UPDATE_DELAYED")
check("same item, other slot: nothing said", Said(Tip(0, 3)), false)
root.SetOption(ns, "glow", false)
check("coin off: tooltip still says it", Said(Tip(0, 1)), true)
root.SetOption(ns, "glow", true)
root.SetOption(ns, "tooltip", false)
check("tooltip off: nothing said", Said(Tip(0, 1)), false)
root.SetOption(ns, "tooltip", true)
TooltipOwner = UIParent
check("a tooltip not on a bag slot: nothing said", Said(ShowItem(FANG)), false)
TooltipOwner = nil

-- ---------------------------------------------------------------- ignore

Put(0, 2, { id = SCALE })
FireEvent("BAG_UPDATE_DELAYED")
check("scale marked", Mark(), "Dull Scale")
local out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_LEASTVALUABLE("ignore")
end)
check("/kwl ignore: says so", has(out, "not marking Dull Scale"), true)
check("/kwl ignore: next one marked", Mark(), "Broken Fang")
check("/kwl ignore: coin moved", coin:GetParent(), ButtonFor(0, 1))
check("ignored slot says why", Why(0, 2), "ignored")
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_LEASTVALUABLE("ignored")
end)
check("/kwl ignored lists it", has(out, "Dull Scale (" .. SCALE .. ")"), true)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER_LEASTVALUABLE("unignore dull scale")
end)
check("/kwl unignore by name", Mark(), "Dull Scale")
capture(function()
	SlashCmdList.KROOLWORLDFOREVER_LEASTVALUABLE("ignore |cff9d9d9d|Hitem:" .. FANG .. "::::::::1:::::::|h[Broken Fang]|h|r")
end)
check("/kwl ignore <link>", db.ignore[FANG], "Broken Fang")
capture(function()
	SlashCmdList.KROOLWORLDFOREVER_LEASTVALUABLE("unignore " .. FANG)
end)
check("/kwl unignore <id>", db.ignore[FANG], nil)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_LEASTVALUABLE("unignore nothing here")
end)
check("/kwl unignore unknown says so", has(out, "not on the ignore list"), true)

-- ---------------------------------------------------------------- /kwl and the hub

Put(0, 4, { id = PICK })
Put(0, 5, { id = CHEST }) -- unpriced green
Put(0, 6, { id = QUESTITEM })
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_LEASTVALUABLE("")
end)
check("/kwl lists the cheapest first", out[2] and out[2]:find("1. ", 1, true) ~= nil and out[2]:find("Dull Scale", 1, true) ~= nil, true)
check("/kwl says what it left out", has(out, "1 profession tool,") and has(out, "1 quest item") and has(out, "1 uncommon or better item with no auction price"), true)
check("/kwl says how to price them", has(out, "scan the auction house"), true)
check("hub names the item", ns.HubStatus():find("Dull Scale", 1, true) ~= nil, true)
AuctionatorOn(false)
check("hub without Auctionator says vendor only", ns.HubStatus():find("vendor prices only", 1, true) ~= nil, true)
AuctionatorOn(true)

-- ---------------------------------------------------------------- on/off

capture(function()
	SlashCmdList.KROOLWORLDFOREVER("leastvaluable off")
end)
check("/kwf leastvaluable off", ns.enabled, false)
check("off: coin gone", coin:IsVisible(), false)
check("off: tooltip silent", Said(Tip(0, 2)), false)
FireEvent("BAG_UPDATE_DELAYED")
ContainerFrameCombinedBags:UpdateItems()
check("off: a redraw brings nothing back", coin:IsVisible(), false)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_LEASTVALUABLE("")
end)
check("off: /kwl says it is off", has(out, "is off"), true)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("leastvaluable on")
end)
check("/kwf leastvaluable on", ns.enabled, true)
check("on: coin back", coin:IsVisible(), true)
check("on: tooltip back", Said(Tip(0, 2)), true)
ContainerFrameCombinedBags:Close()

-- ---------------------------------------------------------------- Bags Full card

EmptyBags()
wipe(Prices)
AuctionatorOn(true)
db.ignore = {}
local GEM, LOWLOOT, QLOOT, GREENLOOT, LATE = 900130, 900131, 900132, 900133, 900140
Items[GEM] = { name = "Moss Agate", quality = 1, sell = 50, class = 7 }
Items[LOWLOOT] = { name = "Worn Rag", quality = 0, sell = 2, class = 15 }
Items[QLOOT] = { name = "Quest Gizmo", quality = 1, sell = 1, class = 12 }
Items[GREENLOOT] = { name = "Odd Charm", quality = 2, sell = 40, class = 15 }
local function LootLink(id)
	return "|cffffffff|Hitem:" .. id .. "::::::::|h[loot " .. id .. "]|h|r"
end
local function FillBags()
	EmptyBags()
	Put(0, 1, { id = FANG, count = 10 }) -- 30c
	Put(0, 2, { id = SCALE }) -- 5c: the cheapest
	Put(0, 3, { id = FANG, count = 2 }) -- 6c
	for slot = 4, 16 do
		Put(0, slot, { id = CLOTH }) -- 13c each
	end
end
local function Err(message)
	FireEvent("UI_ERROR_MESSAGE", 0, message)
end
local function Card()
	return ns.BagsFullShown()
end
local function OpenLoot(slots)
	LootSlots = slots
	FireEvent("LOOT_OPENED")
end
local function CloseLoot()
	FireEvent("LOOT_CLOSED")
	LootSlots = {}
end

check("bags full card on by default", db.bagsfull, true)
check("card absent before any error", Card(), false)

FillBags()
Err("Out of range.")
check("another error message: no card", Card(), false)
Put(0, 16, nil)
Err(ERR_INV_FULL)
check("full error with a free slot: no card", Card(), false)
FillBags()
FreeSlotsSecret = true
Err(ERR_INV_FULL)
check("free slots unreadable: no card", Card(), false)
FreeSlotsSecret = false
FireEvent("UI_ERROR_MESSAGE", 0, Secret())
check("secret message ignored", Card(), false)
FireEvent("UI_ERROR_MESSAGE", Secret(), ERR_INV_FULL)
check("secret error type ignored", Card(), false)
db.bagsfull = false
Err(ERR_INV_FULL)
check("option off: no card", Card(), false)
db.bagsfull = true

-- No loot window: the card sits at the top of the screen.
Err(ERR_INV_FULL)
check("ERR_INV_FULL with zero free slots: card", Card(), true)
local ui = ns.BagsFullUI()
local st = ns.BagsFullState()
check("no loot window: top of the screen", ui.card.point, "TOP")
check("no loot window: no verdict", st.verdict, nil)
check("no loot window: says nothing to loot", ui.loot.text:find("Nothing to loot", 1, true) ~= nil, true)
CloseLoot()
check("loot closed hides the card", Card(), false)
Err(ERR_LOOT_NO_SPACE)
check("ERR_LOOT_NO_SPACE with zero free slots: card", Card(), true)

-- The browse order is the scan's: cheapest first, ties in bag order.
ns.Refresh()
check("first candidate is the bag mark", st.list[1].slot, ns.mark.slot)
local order = {}
for _, e in ipairs(st.list) do
	order[#order + 1] = e.slot
end
check("browse order", table.concat(order, ","), "2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,1")
check("card shows the cheapest", ui.least.text:find("5c", 1, true) ~= nil, true)
check("card names how it was priced", ui.least.text:find("at a vendor", 1, true) ~= nil, true)
ns.BagsFullBrowse(1)
check("next: second candidate", st.idx, 2)
check("next: shows its value", ui.least.text:find("6c", 1, true) ~= nil, true)
ns.BagsFullBrowse(-1)
ns.BagsFullBrowse(-1)
check("previous stops at the first", st.idx, 1)
ui.next.scripts.OnClick(ui.next)
check("the > button browses", st.idx, 2)
ui.prev.scripts.OnClick(ui.prev)
check("the < button browses", st.idx, 1)
for _ = 1, 30 do
	ns.BagsFullBrowse(1)
end
check("next stops at the last", st.idx, #st.list)
while st.idx > 1 do
	ns.BagsFullBrowse(-1)
end

-- A herb bag (family 32) holding the cheapest item: the bag mark may pick it, but loot cannot use
-- its slots, so the card never offers it and its free slots do not count.
BagSizes[1], BagFamily[1] = 4, 32
Put(1, 1, { id = LOWLOOT }) -- 2c, cheaper than the 5c scale
ns.Refresh()
check("herb bag: the bag mark still takes the cheapest", ns.mark.bag .. ":" .. ns.mark.slot, "1:1")
Err(ERR_INV_FULL)
check("herb bag with free slots: card still opens (general bags are full)", Card(), true)
local inHerb = false
for _, e in ipairs(st.list) do
	if e.bag == 1 then
		inHerb = true
	end
end
check("herb bag: no candidate from it", inHerb, false)
check("herb bag: the card's first candidate is the cheapest general slot", st.list[1].bag .. ":" .. st.list[1].slot, "0:2")
check("herb bag: candidate count is the general bags' slots", #st.list, 16)
BagFamily[1] = 0 -- the same bag as a general one
FireEvent("BAG_UPDATE_DELAYED") -- its free slots now count: the card goes
check("general bag with free slots: no card", Card(), false)
Put(1, 2, { id = FANG })
Put(1, 3, { id = FANG })
Put(1, 4, { id = FANG })
Err(ERR_INV_FULL)
check("general bag, full: its items are candidates", st.list[1].bag .. ":" .. st.list[1].slot, "1:1")
BagFamily[1], BagSizes[1] = nil, nil
EmptyBags()
FillBags()
FireEvent("BAG_UPDATE_DELAYED")
Err(ERR_INV_FULL)
check("card back up on the general bag only", Card(), true)

-- Verdicts, with a loot window open.
OpenLoot({ { link = LootLink(GEM), qty = 1 } })
Err(ERR_INV_FULL)
check("loot beating the least valuable: worth", st.verdict, "worth")
check("worth: card says it", ui.verdict.text:find("Worth making room", 1, true) ~= nil, true)
check("worth: shows the loot value", ui.loot.text:find("50c", 1, true) ~= nil, true)
CloseLoot()
OpenLoot({ { link = LootLink(LOWLOOT), qty = 1 } })
Err(ERR_INV_FULL)
check("loot below the least valuable: not worth", st.verdict, "notworth")
check("not worth: card says it", ui.verdict.text:find("Not worth picking up", 1, true) ~= nil, true)
CloseLoot()
OpenLoot({ { link = LootLink(LOWLOOT), qty = 3 } })
Err(ERR_INV_FULL)
check("a stack counts whole: 3 x 2c beats 5c", st.verdict, "worth")
CloseLoot()
OpenLoot({ { link = LootLink(LOWLOOT), qty = 2 } })
Err(ERR_INV_FULL)
check("4c against 5c: not worth", st.verdict, "notworth")
check("loot window without LootFrame shown: top", ui.card.point, "TOP")
LootFrame.shown = true
Err(ERR_INV_FULL)
check("docked beside the loot window", ui.card.point, "TOPLEFT")
LootFrame.shown = false
CloseLoot()

OpenLoot({ { kind = Enum.LootSlotType.Money }, { link = LootLink(LOWLOOT), qty = 1 } })
Err(ERR_INV_FULL)
check("money slots are ignored", #st.loot, 1)
CloseLoot()

OpenLoot({ { link = LootLink(QLOOT), qty = 1, quest = true } })
Err(ERR_INV_FULL)
check("quest loot: worth taking", st.verdict, "worth")
check("quest loot: labeled", ui.loot.text:find("quest item", 1, true) ~= nil, true)
CloseLoot()
OpenLoot({ { link = LootLink(GREENLOOT), qty = 1 } })
Err(ERR_INV_FULL)
check("unknown value (unpriced green): worth taking", st.verdict, "worth")
check("unknown value: labeled", ui.loot.text:find("value unknown", 1, true) ~= nil, true)
CloseLoot()
Items[LATE] = nil
OpenLoot({ { link = LootLink(LATE), qty = 1 } })
Err(ERR_INV_FULL)
check("uncached loot: worth taking, value unknown", st.verdict .. ":" .. tostring(st.shown.label), "worth:value unknown")
Items[LATE] = { name = "Late Gem", quality = 1, sell = 900, class = 7 }
FireEvent("GET_ITEM_INFO_RECEIVED", Secret())
FireEvent("GET_ITEM_INFO_RECEIVED", LATE)
check("item info arrives: the card prices it", st.shown.value, 900)
CloseLoot()
Items[LATE] = nil
OpenLoot({ { link = LootLink(QLOOT), secret = true } })
Err(ERR_INV_FULL)
check("unreadable loot slot left out", #st.loot, 0)
CloseLoot()

-- Auctionator prices the loot too; without it, vendor only and no error.
Prices[LOWLOOT] = 100 -- 95c net beats the 5c scale
OpenLoot({ { link = LootLink(LOWLOOT), qty = 1 } })
Err(ERR_INV_FULL)
check("loot priced at auction", st.shown.how .. ":" .. math.floor(st.shown.value), "auction:95")
AuctionatorOn(false)
Err(ERR_INV_FULL)
check("no Auctionator: vendor price", st.shown.how, "vendor")
AuctionatorOn(true)
Prices[LOWLOOT] = nil
CloseLoot()

-- A low blue as loot: its disenchant value is unconfirmed, and the card says so.
Prices[10978] = 3000
OpenLoot({ { link = LootLink(LOWBLUE), qty = 1 } })
Err(ERR_INV_FULL)
check("low blue loot: priced by disenchant", st.shown.how, "disenchant")
check("low blue loot: the card says unconfirmed", ui.loot.text:find("(unconfirmed)", 1, true) ~= nil, true)
Prices[10978] = nil
CloseLoot()

-- Highlight: with the bags open the browsed slot gets the coin.
ContainerFrameCombinedBags:Open()
Err(ERR_INV_FULL)
check("bags open: mark on the browsed slot", ui.mark.parent == ButtonFor(0, 2) and ui.mark:IsVisible(), true)
ns.BagsFullBrowse(1)
check("browsing moves the mark", ui.mark.parent == ButtonFor(0, 3), true)
ContainerFrameCombinedBags:Close()
ns.BagsFullBrowse(-1)
check("bags closed: no mark", ui.mark:IsVisible(), false)

-- Never Mark.
local ignored
local realIgnore = ns.Ignore
ns.Ignore = function(id, name)
	ignored = id
	return realIgnore(id, name)
end
ui.never.scripts.OnClick(ui.never)
ns.Ignore = realIgnore
check("Never Mark calls ns.Ignore with the item", ignored, SCALE)
check("Never Mark: the item is on the ignore list", db.ignore[SCALE] ~= nil, true)
check("Never Mark: next candidate shown", st.list[1].slot, 3)
check("Never Mark: card still up", Card(), true)
db.ignore[SCALE] = nil

-- A slot frees up: the card goes.
Put(0, 9, nil)
FireEvent("BAG_UPDATE_DELAYED")
check("a freed slot hides the card", Card(), false)
FillBags()
Err(ERR_INV_FULL)
check("shown again", Card(), true)
FireEvent("BAG_UPDATE_DELAYED")
check("still full: card stays", Card(), true)
Put(0, 2, nil)
Put(0, 3, nil)
FireEvent("BAG_UPDATE_DELAYED")
check("freed slots: gone", Card(), false)
FillBags()

-- Off switches.
Err(ERR_INV_FULL)
root.SetOption(ns, "bagsfull", false)
check("option off hides the card", Card(), false)
Err(ERR_INV_FULL)
check("option off keeps it silent", Card(), false)
root.SetOption(ns, "bagsfull", true)
Err(ERR_INV_FULL)
check("option on again", Card(), true)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("leastvaluable off")
end)
check("/kwf leastvaluable off hides the card", Card(), false)
Err(ERR_INV_FULL)
check("/kwf leastvaluable off keeps it silent", Card(), false)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("leastvaluable on")
end)
Err(ERR_INV_FULL)
check("on again", Card(), true)
CloseLoot()

check("no item or loot action was ever called", table.concat(ForbiddenCalls, ","), "")
check("nothing was picked up or deleted without a Delete click", table.concat(ItemCalls, ","), "")

-- ---------------------------------------------------------------- Bags Full card: Delete

local function Calls()
	return table.concat(ItemCalls, ",")
end
local function Reset()
	wipe(ItemCalls)
	wipe(Deleted)
	wipe(BlockedCalls)
	Cursor, PickupFails, DeleteFails = nil, false, false
	ns.BagsFullHide() -- a fresh card: it opens on the cheapest slot
	FillBags()
	FireEvent("BAG_UPDATE_DELAYED")
	Err(ERR_INV_FULL)
end
local function Asking()
	return ui.yes:IsShown() and ui.cancel:IsShown()
end

check("delete button on by default", db.bagsfulldelete, true)
check("confirm before deleting on by default", db.bagsfullconfirm, true)
Reset()
check("card has the Delete button", ui.delete:IsShown(), true)
check("no question before a click", Asking(), false)

-- It asks first.
Click(ui.delete)
check("Delete asks first", Asking(), true)
check("asking: the row gives way", ui.delete:IsShown() or ui.never:IsShown() or ui.prev:IsShown() or ui.next:IsShown(), false)
check("asking: the card says so", ui.head.text:find("Delete this?", 1, true) ~= nil, true)
check("asking deletes nothing", Calls(), "")
Click(ui.cancel)
check("Cancel: the row is back", ui.delete:IsShown() and ui.never:IsShown() and not Asking(), true)
check("Cancel: the head is back", ui.head.text:find("Least valuable", 1, true) ~= nil, true)
check("Cancel deletes nothing", Calls() .. tostring(Bag[0][2].id), tostring(SCALE))

-- The question is about one stack: browsing drops it, a bag update keeps it only for that stack.
Click(ui.delete)
ns.BagsFullBrowse(1)
check("browsing drops the question", Asking(), false)
ns.BagsFullBrowse(-1)
check("browsing back does not bring it back", Asking(), false)
Click(ui.delete)
FireEvent("BAG_UPDATE_DELAYED")
check("bag update, same stack: still asking", Asking(), true)
Put(0, 2, { id = SCALE, count = 2 })
FireEvent("BAG_UPDATE_DELAYED")
check("bag update, the stack changed: question dropped", Asking(), false)
Reset()
Click(ui.delete)
CloseLoot()
check("closing the card drops the question", st.confirm, nil)
check("still nothing deleted", Calls(), "")

-- Yes, Delete.
Reset()
Click(ui.delete)
local said = capture(function()
	Click(ui.yes)
end)
check("Yes, Delete: picks the slot up, then deletes it", Calls(), "Pickup 0:2,Delete")
check("Yes, Delete: the stack is gone", Bag[0][2], nil)
check("Yes, Delete: exactly that stack", table.concat(Deleted, ","), SCALE .. "x1")
check("Yes, Delete: says what it deleted", has(said, "deleted"), true)
check("Yes, Delete: nothing left on the cursor", Cursor, nil)
check("Yes, Delete: the button waits for the bags", st.busy, true)
ns.BagsFullDelete()
check("a second press before the bags answer does nothing", Calls(), "Pickup 0:2,Delete")
FireEvent("BAG_UPDATE_DELAYED")
check("the freed slot hides the card", Card(), false)

-- Confirm Before Deleting off: one click.
Reset()
root.SetOption(ns, "bagsfullconfirm", false)
capture(function()
	Click(ui.delete)
end)
check("confirm off: one click deletes", table.concat(Deleted, ","), SCALE .. "x1")
check("confirm off: never asked", Asking(), false)

-- A rare or better item always asks.
local HEIRLOOM = 900150
Items[HEIRLOOM] = { name = "Chipped Heirloom", quality = 3, sell = 1, class = 15 }
Reset()
Put(0, 2, { id = HEIRLOOM, bound = true })
FireEvent("BAG_UPDATE_DELAYED")
check("a bound blue is the cheapest", st.list[st.idx].id, HEIRLOOM)
Click(ui.delete)
check("confirm off: a rare still asks", Asking(), true)
check("confirm off: a rare is not deleted by one click", Calls(), "")
capture(function()
	Click(ui.yes)
end)
check("a rare goes after Yes, Delete", table.concat(Deleted, ","), HEIRLOOM .. "x1")

-- Outside a click the client refuses, and the item goes back.
Reset()
said = capture(function()
	ns.BagsFullDelete()
end)
check("outside a click: the client blocks the delete", table.concat(BlockedCalls, ","), "DeleteCursorItem")
check("blocked: nothing deleted", #Deleted, 0)
check("blocked: the item is put back", Calls(), "Pickup 0:2,Delete,ClearCursor")
check("blocked: slot whole and unlocked, cursor empty", Cursor == nil and Bag[0][2].id == SCALE and Bag[0][2].locked == nil, true)
check("blocked: says so", has(said, "did not delete"), true)

-- The server refuses inside a click: the same.
Reset()
DeleteFails = true
said = capture(function()
	Click(ui.delete)
end)
check("refused by the game: item back, nothing deleted", Calls() .. ":" .. #Deleted .. ":" .. tostring(Cursor), "Pickup 0:2,Delete,ClearCursor:0:nil")
check("refused by the game: says so", has(said, "did not delete"), true)

-- The pickup does not take.
Reset()
PickupFails = true
said = capture(function()
	Click(ui.delete)
end)
check("pickup failed: never deletes", Calls(), "Pickup 0:2,ClearCursor")
check("pickup failed: says so", has(said, "could not pick"), true)

-- The cursor already holds something: it is never touched.
Reset()
Cursor = { kind = "spell", id = 133 }
said = capture(function()
	Click(ui.delete)
end)
check("cursor busy: nothing picked up or deleted", Calls(), "")
check("cursor busy: it keeps what it held", Cursor.kind, "spell")
check("cursor busy: says so", has(said, "put down"), true)

-- The slot is read again at the click: a changed, unmarkable or locked slot is left alone.
Reset()
Bag[0][2] = { id = FANG, count = 1 } -- changed, and no bag event told the card
said = capture(function()
	Click(ui.delete)
end)
check("slot changed: left alone", Calls(), "")
check("slot changed: says so", has(said, "slot changed"), true)
Reset()
Bag[0][2] = { id = SCALE, quest = true }
said = capture(function()
	Click(ui.delete)
end)
check("slot now a quest item: left alone", Calls(), "")
Reset()
Bag[0][2].locked = true
said = capture(function()
	Click(ui.delete)
end)
check("locked slot: left alone", Calls(), "")
check("locked slot: says so", has(said, "locked"), true)

-- Delete Button On The Card off.
Reset()
root.SetOption(ns, "bagsfullconfirm", true)
Click(ui.delete)
root.SetOption(ns, "bagsfulldelete", false)
check("button option off: no button, no question", ui.delete:IsShown() or Asking(), false)
check("button option off: the rest of the row stays", ui.never:IsShown() and ui.prev:IsShown(), true)
Click(ui.delete)
Click(ui.yes)
check("button option off: a stray click does nothing", Calls(), "")
root.SetOption(ns, "bagsfullconfirm", false)
Click(ui.delete)
check("button option off, confirm off: still nothing", Calls(), "")
root.SetOption(ns, "bagsfullconfirm", true)
root.SetOption(ns, "bagsfulldelete", true)
check("button option on: the button is back", ui.delete:IsShown(), true)
check("loot calls still never made", table.concat(ForbiddenCalls, ","), "")

-- ---------------------------------------------------------------- Bags Full card: keeps off the bags

local function Where()
	local a = ui.card.anchor
	return ("%s %g,%g"):format(a[1], a[4], a[5]) .. (ui.avoiding and " moved" or "")
end
Reset()
UIParent.rect = { 0, 0, 1600, 900 }
Err(ERR_INV_FULL)
check("bags closed: near the top of the screen", Where(), "TOP 0,-140")

-- The bags open under the card (it spans 635-965 across, 498-760 up).
ContainerFrameCombinedBags.rect = { 500, 300, 700, 500 }
ContainerFrameCombinedBags:Open()
check("bags opened under the card: it goes left of them", Where(), "TOPLEFT 162,760 moved")
check("bags opened: the coin goes on the browsed slot", ui.mark.parent == ButtonFor(0, 2) and ui.mark:IsVisible(), true)
ContainerFrameCombinedBags:Close()
check("bags closed again: back near the top", Where(), "TOP 0,-140")

-- Bags that the card does not cover leave it alone.
ContainerFrameCombinedBags.rect = { 1300, 50, 280, 300 }
ContainerFrameCombinedBags:Open()
check("bags elsewhere: the card stays", Where(), "TOP 0,-140")

-- Bags over the whole screen: nowhere to go, so it stays.
ContainerFrameCombinedBags.rect = { 0, 0, 1600, 900 }
Err(ERR_INV_FULL)
check("no free place: the card stays", Where(), "TOP 0,-140")

-- A rectangle the client will not give: the card stays.
ContainerFrameCombinedBags.rect = { Secret(), 300, 700, 500 }
Err(ERR_INV_FULL)
check("secret bag rectangle: the card stays", Where(), "TOP 0,-140")

-- The card's own scale counts.
ContainerFrameCombinedBags.rect = { 500, 300, 700, 500 }
ui.card.scale = 0.5
Err(ERR_INV_FULL)
check("half-size card: placed in its own units", Where(), "TOPLEFT 662,1660 moved")
ui.card.scale = nil

-- Docked to the loot window, with the bags where the card would go: the window's other side.
LootFrame.shown, LootFrame.rect = true, { 900, 400, 200, 300 }
ContainerFrameCombinedBags.rect = { 1200, 100, 380, 500 }
OpenLoot({ { link = LootLink(GEM), qty = 1 } })
Err(ERR_INV_FULL)
check("beside the loot window over the bags: its other side", Where(), "TOPLEFT 566,700 moved")
-- No room on that side either: past the bags, clear of the loot window.
LootFrame.rect = { 100, 400, 200, 300 }
ContainerFrameCombinedBags.rect = { 500, 300, 700, 500 }
Err(ERR_INV_FULL)
check("loot window at the left edge: right of the bags", Where(), "TOPLEFT 1208,700 moved")
-- Bags clear of it: plainly docked.
ContainerFrameCombinedBags.rect = { 1300, 50, 280, 300 }
Err(ERR_INV_FULL)
check("docked with the bags clear", Where(), "TOPLEFT 4,0")
-- A loot window that cannot be measured: plainly docked.
LootFrame.rect = nil
ContainerFrameCombinedBags.rect = { 500, 300, 700, 500 }
Err(ERR_INV_FULL)
check("loot window unmeasured: docked as before", Where(), "TOPLEFT 4,0")
LootFrame.shown = false
CloseLoot()

-- Dragged by the player: it stays there until it closes.
Reset()
check("before the drag: moved off the bags", Where(), "TOPLEFT 162,760 moved")
ui.card.anchor = { "CENTER", nil, nil, 11, 22 }
ui.card.hooks.OnDragStop(ui.card)
Err(ERR_INV_FULL)
FireEvent("BAG_UPDATE_DELAYED")
ContainerFrameCombinedBags:Close()
check("dragged: left where the player put it", Where():find("CENTER 11,22", 1, true) ~= nil, true)
CloseLoot()
Err(ERR_INV_FULL)
check("opened again: placed afresh", Where(), "TOP 0,-140")
CloseLoot()
ContainerFrameCombinedBags.rect, UIParent.rect = nil, nil
check("placing the card touched no item", Calls(), "")

-- ---------------------------------------------------------------- other features untouched

local de = root.features.disenchant
local best, net = de.Best(1000, nil, 900)
check("Disenchant Value's Best also returns what it pays", best == "disenchant" and net == 950, true)
local mine = 0
for _, err in ipairs(KroolWorldForeverDB.errors or {}) do
	if err.feature == "leastvaluable" then
		mine = mine + 1
		realPrint("  caught: " .. tostring(err.where) .. ": " .. tostring(err.message))
	end
end
check("no errors caught in Least Valuable", mine, 0)

realPrint(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
