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
check("glow on by default", db.glow, true)
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
ContainerFrameCombinedBags:Close()

-- ---------------------------------------------------------------- glow

EmptyBags()
Put(0, 1, { id = FANG, count = 10 })
Put(0, 2, { id = SCALE, count = 1 })
FireEvent("BAG_UPDATE_DELAYED")
check("bags closed: no glow", ns.Glow() and ns.Glow():IsVisible() or false, false)
ContainerFrameCombinedBags:Open()
local glow = ns.Glow()
check("glow made", type(glow), "table")
check("glow on the marked slot's button", glow and glow:GetParent(), ButtonFor(0, 2))
check("glow shown", glow and glow:IsVisible(), true)
check("glow texture is the bag glow", glow and glow.textures[1].atlas, "bags-glow-white")
check("glow above the button", glow and glow.level, 12)

-- Selling the marked item moves the glow on.
Put(0, 2, nil)
FireEvent("BAG_UPDATE_DELAYED")
check("sold: glow moves to the next cheapest", glow:GetParent(), ButtonFor(0, 1))
-- A redraw that hands the slot another button: the glow follows the slot.
local before = ButtonFor(0, 1)
ContainerFrameCombinedBags:Layout()
ContainerFrameCombinedBags:UpdateItems()
check("redraw gave the slot a new button", ButtonFor(0, 1) ~= before, true)
check("glow follows the slot", glow:GetParent(), ButtonFor(0, 1))
ContainerFrameCombinedBags:Close()
check("bags closed: glow goes", glow:IsVisible(), false)

-- Separate bags: the slot is on its own bag's frame.
Put(1, 3, { id = SCALE })
BagSizes[1] = 8
ContainerFrame1:Open()
ContainerFrame2:Open()
FireEvent("BAG_UPDATE_DELAYED")
check("separate bags: glow in the right bag", glow:GetParent(), ButtonFor(1, 3))
check("separate bags: on bag 1's frame", glow:GetParent().parent, ContainerFrame2)
ContainerFrame1:Close()
check("closing another bag keeps it", glow:IsVisible(), true)
ContainerFrame2:Close()
check("closing its bag hides it", glow:IsVisible(), false)
Put(1, 3, nil)
BagSizes[1] = nil
FireEvent("BAG_UPDATE_DELAYED") -- bags closed: rescanned on the next look

-- Option: no glow, the tooltip still says it.
ContainerFrameCombinedBags:Open()
root.SetOption(ns, "glow", false)
check("glow off: hidden", glow:IsVisible(), false)
root.SetOption(ns, "glow", true)
check("glow on: back", glow:IsVisible(), true)

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
check("glow off: tooltip still says it", Said(Tip(0, 1)), true)
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
check("/kwl ignore: glow moved", glow:GetParent(), ButtonFor(0, 1))
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
check("off: glow gone", glow:IsVisible(), false)
check("off: tooltip silent", Said(Tip(0, 2)), false)
FireEvent("BAG_UPDATE_DELAYED")
ContainerFrameCombinedBags:UpdateItems()
check("off: a redraw brings nothing back", glow:IsVisible(), false)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_LEASTVALUABLE("")
end)
check("off: /kwl says it is off", has(out, "is off"), true)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("leastvaluable on")
end)
check("/kwf leastvaluable on", ns.enabled, true)
check("on: glow back", glow:IsVisible(), true)
check("on: tooltip back", Said(Tip(0, 2)), true)
ContainerFrameCombinedBags:Close()

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
