-- Disenchant Value behavior checks. Runs after stubs.lua and the whole bundle.

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
local ns = root.features.disenchant

-- Materials of table 4 (green armor, item level 26-30): Soul Dust 75% 1-2, Greater Astral
-- Essence 20% 1-2, Large Glimmering Shard 5%.
local SOUL, ASTRAL, GLIMMER = 11083, 11082, 11084
local function SetPrices()
	wipe(Prices)
	wipe(LinkPrices)
	Prices[SOUL], Prices[ASTRAL], Prices[GLIMMER] = 1000, 5000, 3000
end
local EXPECTED = 0.75 * 1.5 * 1000 + 0.2 * 1.5 * 5000 + 0.05 * 3000 -- 2775

-- Items new to Forever (not in the 1.12 data) and one classic exception.
local CHEST, SWORD, RING = 900001, 900002, 1189
Items[CHEST] = { name = "Forever Chestguard", quality = 2, ilvl = 28, sell = 500, class = 4, bind = 2 }
Items[SWORD] = { name = "Forever Blade", quality = 2, ilvl = 28, sell = 600, class = 2, bind = 2 }
Items[RING] = { name = "Overseer's Ring", quality = 2, ilvl = 20, sell = 300, class = 4, bind = 2 }
Items[900003] = { name = "Plain Shirt", quality = 1, ilvl = 28, sell = 10, class = 4, bind = 0 }
Items[900004] = { name = "Strange Dust", quality = 1, ilvl = 10, sell = 0, class = 7, bind = 0 }

local function Lines(tt)
	local all = {}
	for _, l in ipairs(tt.left) do
		all[#all + 1] = l
	end
	for _, l in ipairs(tt.right) do
		all[#all + 1] = l
	end
	for _, l in ipairs(tt.lines) do
		all[#all + 1] = l
	end
	return all
end
local function RightOf(tt, label)
	for i, l in ipairs(tt.left) do
		if tostring(l):find(label, 1, true) then
			return tt.right[i]
		end
	end
	return nil
end
local function BestLine(tt)
	for _, l in ipairs(tt.lines) do
		if tostring(l):find("Best:", 1, true) then
			return l
		end
	end
	return nil
end

-- ---------------------------------------------------------------- lifecycle

FireEvent("ADDON_LOADED", "KroolWorldForever")
local db = KroolWorldForeverDB.features.disenchant
check("feature slice created", type(db), "table")
check("on by default", db.enabled, true)
check("tooltip on by default", db.tooltip, true)
check("best on by default", db.best, true)
check("materials on Shift by default", db.mats, false)
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("enabled after login", ns.enabled, true)
check("item tooltip hooked", has(TooltipChains[Enum.TooltipDataType.Item] or {}, tostring(ns.OnItemTooltip)), true)
local hooks = #TooltipChains[Enum.TooltipDataType.Item]
ns.OnEnable()
check("hooked once only", #TooltipChains[Enum.TooltipDataType.Item], hooks)
check("/kwd registered", SLASH_KROOLWORLDFOREVER_DISENCHANT1, "/kwd")
check("hub icon", ns.icon, "Interface\\Icons\\INV_Enchant_Disenchant")
check("hub blurb", type(ns.blurb), "string")

-- ---------------------------------------------------------------- tables

check("green armor 28 -> table 4", ns.TableFor(CHEST, 2, 4, 28), 4)
check("green weapon 28 -> table 24", ns.TableFor(SWORD, 2, 2, 28), 24)
check("green armor 23 -> table 3", ns.TableFor(0, 2, 4, 23), 3)
check("green armor 5 -> table 1", ns.TableFor(0, 2, 4, 5), 1)
check("below the first band uses it", ns.TableFor(0, 2, 4, 2), 1)
check("green armor 80 -> top band", ns.TableFor(0, 2, 4, 80), 11)
check("blue armor 60 -> table 48", ns.TableFor(0, 3, 4, 60), 48)
check("blue weapon 66 -> table 49", ns.TableFor(0, 3, 2, 66), 49)
check("epic weapon 70 -> table 65", ns.TableFor(0, 4, 2, 70), 65)
check("white item: none", ns.TableFor(0, 1, 4, 28), nil)
check("legendary: none", ns.TableFor(0, 5, 2, 70), nil)
check("trade goods: none", ns.TableFor(0, 2, 7, 28), nil)
check("classic item that cannot be disenchanted", ns.TableFor(RING, 2, 4, 20), nil)
check("Lesser Magic Wand cannot either", ns.TableFor(11287, 2, 2, 15), nil)
local exId, exEntry
for id, entry in pairs(ns.Data.items) do
	if entry > 0 then
		exId, exEntry = id, entry
		break
	end
end
check("a classic exception keeps its own table", exId and ns.TableFor(exId, 2, 4, 1), exEntry)
local bandId
for id, entry in pairs(ns.Data.items) do
	if entry == 4 then
		bandId = id
		break
	end
end
check("a classic item ignores the item level the client reports", bandId and ns.TableFor(bandId, 2, 4, 60), 4)
local listed = 0
for _ in pairs(ns.Data.items) do
	listed = listed + 1
end
check("every classic weapon and armor piece is listed", listed, 7994)
check("blue 69+ table has the Large Brilliant Shard", ns.Data.tables[50][1][1], 14344)
for entry, rows in pairs(ns.Data.tables) do
	local sum = 0
	for _, r in ipairs(rows) do
		sum = sum + r[2]
	end
	if sum > 1.0001 then
		check("table " .. entry .. " sums to at most 100%", sum, 1)
	end
end
check("every material has a name", ns.Data.mats[SOUL], "Soul Dust")

-- ---------------------------------------------------------------- value

SetPrices()
local e = ns.Evaluate(CHEST, 2, 4, 28)
check("value: expected worth", math.floor(e.value + 0.5), EXPECTED)
check("value: three materials", #e.rows, 3)
check("value: rows by chance", e.rows[1].id, SOUL)
Prices[GLIMMER] = nil
check("rare material without a price counts as 0", math.floor(ns.Evaluate(CHEST, 2, 4, 28).value + 0.5), EXPECTED - 150)
SetPrices()
Prices[SOUL] = nil
e = ns.Evaluate(CHEST, 2, 4, 28)
check("main material without a price: no value", e.value, nil)
check("and it is named", e.missing, "Soul Dust")
ItemNames[SOUL] = "Seelenstaub"
check("names come from the client when loaded", ns.Evaluate(CHEST, 2, 4, 28).missing, "Seelenstaub")
ItemNames[SOUL] = nil
AuctionatorOn(false)
e = ns.Evaluate(CHEST, 2, 4, 28)
check("no Auctionator: no value", e.value, nil)
check("no Auctionator: known", e.hasAH, false)
AuctionatorOn(true)
SetPrices()

check("best: disenchant", ns.Best(2775, 2000, 500), "disenchant")
check("best: auction", ns.Best(2775, 4000, 500), "auction")
check("best: vendor beats the cut", ns.Best(1000, nil, 1000), "vendor")
check("best: tie goes to less work", ns.Best(1000, 1000, nil), "auction")
check("best: nothing known", ns.Best(nil, nil, nil), nil)

-- ---------------------------------------------------------------- tooltip

SetPrices()
LinkPrices["item:" .. CHEST] = 2000
local tt = ShowItem(CHEST)
check("tooltip: disenchant line", RightOf(tt, "Disenchant") ~= nil, true)
check("tooltip: worth", tostring(RightOf(tt, "Disenchant")):find("27s", 1, true) ~= nil, true)
local best = BestLine(tt)
check("tooltip: best is disenchant", best and best:find("disenchant it", 1, true) ~= nil, true)
check("tooltip: names the auction price", best and best:find("auction", 1, true) ~= nil, true)
check("tooltip: names the vendor price", best and best:find("vendor", 1, true) ~= nil, true)
check("tooltip: materials hidden without Shift", has(tt.left, "Soul Dust"), false)

LinkPrices["item:" .. CHEST] = 9000
best = BestLine(ShowItem(CHEST))
check("tooltip: a pricey green says auction", best and best:find("sell it at auction", 1, true) ~= nil, true)
LinkPrices["item:" .. CHEST] = nil
best = BestLine(ShowItem(CHEST))
check("tooltip: no auction price for the item says so", best and best:find("no auction price", 1, true) ~= nil, true)
LinkPrices["item:" .. CHEST] = 2000

ShiftDown = true
tt = ShowItem(CHEST)
ShiftDown = false
check("Shift lists the materials", has(tt.left, "Soul Dust 1-2, 75%"), true)
check("with each price", has(tt.right, "each"), true)
check("and the shard chance", has(tt.left, "Large Glimmering Shard, 5%"), true)

root.SetOption(ns, "mats", true)
check("option: materials always", has(ShowItem(CHEST).left, "Soul Dust"), true)
root.SetOption(ns, "mats", false)
root.SetOption(ns, "best", false)
check("option: no best line", BestLine(ShowItem(CHEST)), nil)
check("option: value still shown", RightOf(ShowItem(CHEST), "Disenchant") ~= nil, true)
root.SetOption(ns, "best", true)
root.SetOption(ns, "tooltip", false)
check("option: tooltip off", #Lines(ShowItem(CHEST)), 0)
root.SetOption(ns, "tooltip", true)

-- weapons lean to essences
tt = ShowItem(SWORD)
check("weapon: worth uses table 24", RightOf(tt, "Disenchant") ~= nil, true)

-- bound items
Items[CHEST].bind = 1
CanDisenchant = false
tt = ShowItem(CHEST)
check("bind on pickup: value shown", RightOf(tt, "Disenchant") ~= nil, true)
check("bind on pickup, no enchanting: no best line", BestLine(tt), nil)
CanDisenchant = true
best = BestLine(ShowItem(CHEST))
check("bound, you enchant: best line", best ~= nil, true)
check("bound: no auction in the compare", best and best:find("auction", 1, true) == nil, true)
CanDisenchant = false
Items[CHEST].bind = 2
check("soulbound line counts as bound", BestLine(ShowItem(CHEST, { lines = { { leftText = "Soulbound" } } })), nil)
check("account bound too", BestLine(ShowItem(CHEST, { lines = { { leftText = "Account Bound" } } })), nil)
check("a secret line is skipped", BestLine(ShowItem(CHEST, { lines = { { leftText = Secret() } } })) ~= nil, true)

-- unknown and missing data
Prices[SOUL] = nil
tt = ShowItem(CHEST)
check("missing main price: says which", tostring(RightOf(tt, "Disenchant")):find("no price for Soul Dust", 1, true) ~= nil, true)
check("missing main price: no best line", BestLine(tt), nil)
SetPrices()
AuctionatorOn(false)
tt = ShowItem(CHEST)
check("no Auctionator: says so", tostring(RightOf(tt, "Disenchant")):find("needs Auctionator", 1, true) ~= nil, true)
check("no Auctionator: no best line", BestLine(tt), nil)
ShiftDown = true
check("no Auctionator: Shift still lists materials", has(ShowItem(CHEST).left, "Soul Dust"), true)
ShiftDown = false
AuctionatorOn(true)

check("classic item that cannot be disenchanted: nothing", #Lines(ShowItem(RING)), 0)
check("white item: nothing", #Lines(ShowItem(900003)), 0)
check("trade goods: nothing", #Lines(ShowItem(900004)), 0)
check("uncached item: nothing", #Lines(ShowItem(123456)), 0)
check("secret id: nothing", #Lines(ShowItem(Secret())), 0)
check("other tooltips: nothing", #Lines(ShowItem(CHEST, nil, {})), 0)
ItemInfoErrors = true
local okErr = pcall(ShowItem, CHEST)
ItemInfoErrors = false
check("item info error stays inside", okErr, true)
Auctionator.API.v1.GetAuctionPriceByItemID = function()
	error("auctionator broke")
end
okErr = pcall(ShowItem, CHEST)
check("Auctionator error stays inside", okErr, true)
AuctionatorOn(true)
SetPrices()
LinkPrices["item:" .. CHEST] = 2000

-- ---------------------------------------------------------------- price age

check("shared: 3 days is not old", root.AuctionStale(3), false)
check("shared: 4 days is old", root.AuctionStale(4), true)
check("shared: unknown age is not old", root.AuctionStale(nil), false)
check("seen today", root.SeenText(0), "seen today")
check("seen yesterday", root.SeenText(1), "seen yesterday")
check("seen days ago", root.SeenText(6), "seen 6 days ago")
check("unknown age: no text", root.SeenText(nil), nil)

SetPrices()
LinkPrices["item:" .. CHEST] = 2000
Ages[SOUL], Ages[ASTRAL], Ages[GLIMMER] = 0, 1, 0
e = ns.Evaluate(CHEST, 2, 4, 28)
check("age: fresh materials are not old", e.stale, nil)
check("age: each row carries its age", e.rows[2].age, 1)
tt = ShowItem(CHEST)
check("age: fresh value line unmarked", tostring(RightOf(tt, "Disenchant")):find("old prices", 1, true), nil)
Ages[GLIMMER] = 9
check("age: an old rare shard does not mark the value", ns.Evaluate(CHEST, 2, 4, 28).stale, nil)
Ages[ASTRAL] = 5
e = ns.Evaluate(CHEST, 2, 4, 28)
check("age: an old main material marks the value", e.stale, 5)
check("age: the value is still counted", math.floor(e.value + 0.5), EXPECTED)
tt = ShowItem(CHEST)
check("age: value line says old prices", tostring(RightOf(tt, "Disenchant")):find("(old prices)", 1, true) ~= nil, true)
ShiftDown = true
tt = ShowItem(CHEST)
ShiftDown = false
check("age: Shift list dates the old material", has(tt.right, "seen 5 days ago"), true)
check("age: and only old ones", has(tt.right, "seen today"), false)
Ages[SOUL], Ages[ASTRAL], Ages[GLIMMER] = 0, 0, 0

-- the item's own auction price
LinkAges["item:" .. CHEST] = 6
best = BestLine(ShowItem(CHEST))
check("old item price: disenchant still best", best and best:find("disenchant it", 1, true) ~= nil, true)
check("old item price: the auction price is dated", best and best:find("seen 6 days ago", 1, true) ~= nil, true)
LinkPrices["item:" .. CHEST] = 9000
best = BestLine(ShowItem(CHEST))
check("old item price still wins when higher", best and best:find("sell it at auction", 1, true) ~= nil, true)
check("and the call says how old", best and best:find("(price seen 6 days ago)", 1, true) ~= nil, true)
LinkAges["item:" .. CHEST] = 2
best = BestLine(ShowItem(CHEST))
check("a recent item price is not dated", best and best:find("seen", 1, true), nil)
LinkAges["item:" .. CHEST] = nil
LinkPrices["item:" .. CHEST] = 2000

-- /kwd and the hub
Ages[ASTRAL] = 5
local outAge = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_DISENCHANT("")
end)
check("/kwd dates every priced material", has(outAge, "Soul Dust: ") and has(outAge, "seen today"), true)
check("/kwd shows the old one", has(outAge, "seen 5 days ago"), true)
check("hub: counts old prices", ns.HubStatus():find("1 over 3 days old", 1, true) ~= nil, true)
Ages[ASTRAL] = 0
check("hub: nothing old, nothing said", ns.HubStatus(), "Prices for 3 of 24 materials")
wipe(Ages)

-- ---------------------------------------------------------------- on/off

capture(function()
	SlashCmdList.KROOLWORLDFOREVER("disenchant off")
end)
check("/kw disenchant off", ns.enabled, false)
check("off: silent", #Lines(ShowItem(CHEST)), 0)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("disenchant on")
end)
check("/kw disenchant on", ns.enabled, true)
check("on: back", RightOf(ShowItem(CHEST), "Disenchant") ~= nil, true)

-- ---------------------------------------------------------------- hub and slash

check("hub: priced count", ns.HubStatus(), "Prices for 3 of 24 materials")
wipe(Prices)
check("hub: no prices yet", ns.HubStatus():find("scan the auction house", 1, true) ~= nil, true)
AuctionatorOn(false)
check("hub: needs Auctionator", ns.HubStatus():find("Needs Auctionator", 1, true) ~= nil, true)
local out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_DISENCHANT("")
end)
check("/kwd without Auctionator says so", has(out, "not installed"), true)
AuctionatorOn(true)
SetPrices()
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_DISENCHANT("")
end)
check("/kwd lists material prices", has(out, "Soul Dust: "), true)
check("/kwd marks unpriced ones", has(out, "no price"), true)
OpenedCategory = nil
capture(function()
	SlashCmdList.KROOLWORLDFOREVER_DISENCHANT("options")
end)
check("/kwd options opens settings", OpenedCategory, "Disenchant Value")

-- ---------------------------------------------------------------- shared prices

check("money format", root.Money(2775), "|cffc7c7cf27s|r |cffeda55f75c|r")
check("Kill Value uses the shared money format", root.public.KillValue.Money, root.Money)
check("Kill Value uses the shared Auctionator lookup", root.public.KillValue.AuctionPrice(SOUL), 1000)
LinkPrices["item:" .. CHEST] = 2000
check("link lookup", root.AuctionPrice("item:" .. CHEST), 2000)
AuctionatorOn(false)
check("no Auctionator: no price", root.AuctionPrice(SOUL), nil)
AuctionatorOn(true)

realPrint(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
