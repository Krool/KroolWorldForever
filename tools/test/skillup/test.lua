-- Skill-Up Odds behavior checks. Runs after stubs.lua and the whole bundle.

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
local ns = root.features.skillup

local VEST, BOOTS, ROBE, CLOAK, SHIRT, BANDAGE = 2385, 2386, 2389, 2387, 2393, 3275
local BOLT, THREAD, VEST_ITEM, BOOTS_ITEM = 2996, 2320, 2568, 2569
Recipes[VEST] = { name = "Brown Linen Vest", line = 197, y = 45, g = 70 }
Recipes[BOOTS] = { name = "Linen Boots", line = 197, y = 65, g = 100 }
Recipes[ROBE] = { name = "Red Linen Robe", line = 197, y = 50, g = 85 }
Recipes[CLOAK] = { name = "Linen Cloak", line = 197, y = 35, g = 60 }
Recipes[SHIRT] = { name = "Brown Linen Shirt", line = 197, y = 35, g = 60, learned = false }
Recipes[BANDAGE] = { name = "Linen Bandage", line = 129, y = 30, g = 60 }
Items[BOLT] = { name = "Bolt of Linen Cloth", class = 7 }
Items[THREAD] = { name = "Coarse Thread", class = 7 }
Items[VEST_ITEM] = { name = "Brown Linen Vest", sell = 300, class = 4 }
Items[BOOTS_ITEM] = { name = "Linen Boots", sell = 100, class = 4 }
Items[999] = { name = "Some Armor", class = 4 }
Schematics[VEST] = { out = VEST_ITEM, reagents = { { BOLT, 1 }, { THREAD, 1 }, { 5000, 1, Enum.CraftingReagentType.Modifying } } }
Schematics[BOOTS] = { out = BOOTS_ITEM, reagents = { { BOLT, 2 }, { THREAD, 1 } } }
Schematics[ROBE] = { out = 2572, reagents = { { BOLT, 2 } } }
Schematics[CLOAK] = { out = 2570, reagents = { { BOLT, 1 } } }
Skill[197], Skill[129] = 50, 40

local function Craft(id, guid, gain, opts)
	opts = opts or {}
	local line = Recipes[id].line
	FireEvent("UNIT_SPELLCAST_START", "player", guid, id)
	FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", guid, id)
	Skill[line] = Skill[line] + gain
	if not opts.wait then
		RunTimers()
	end
end

-- ---------------------------------------------------------------- lifecycle

FireEvent("ADDON_LOADED", "KroolWorldForever")
local db = KroolWorldForeverDB.features.skillup
check("feature slice created", type(db), "table")
check("on by default", db.enabled, true)
check("list odds on by default", db.list, true)
check("panel on by default", db.panel, true)
check("resale on by default", db.resale, true)
check("auction resale off by default", db.resaleAH, false)
check("measuring on by default", db.learn, true)
check("stats are not an option", ns.options[6], nil)
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("enabled after login", ns.enabled, true)
check("/kwu registered", SLASH_KROOLWORLDFOREVER_SKILLUP1, "/kwu")
check("hub icon", ns.icon, "Interface\\Icons\\Trade_BlackSmithing")
check("hub blurb", type(ns.blurb), "string")
check("hub status before any craft", ns.HubStatus():find("No crafts measured", 1, true) ~= nil, true)
check("hooked Auctionator's scans", #AuctionatorCallbacks, 1)
check("and knows it", ns.auctionHooked, true)

-- ---------------------------------------------------------------- data and bands

local r = ns.Recipe(VEST)
check("data build", ns.Data.build, "1.60.1.70888")
check("vest yellow", r.y, 45)
check("vest grey", r.g, 70)
check("vest profession", r.line, 197)
check("vest child line", r.child, 2948)
check("bandage is first aid", ns.Recipe(BANDAGE).line, 129)
local total = 0
for _, L in pairs(ns.Data.lines) do
	for _ in pairs(L.recipes) do
		total = total + 1
	end
end
check("every recipe is in the data", total, 2544)
check("unknown recipe", ns.Recipe(123456789), nil)
check("secret recipe id", ns.Recipe(Secret()), nil)
check("green halfway", ns.Green(r), 57)
check("44 orange", ns.Band(44, r), "orange")
check("45 yellow", ns.Band(45, r), "yellow")
check("56 yellow", ns.Band(56, r), "yellow")
check("57 green", ns.Band(57, r), "green")
check("69 green", ns.Band(69, r), "green")
check("70 grey", ns.Band(70, r), "grey")
check("bin at yellow", ns.Bin(45, r), 1)
check("bin 50", ns.Bin(50, r), 3)
check("bin 57", ns.Bin(57, r), 5)
check("bin 69", ns.Bin(69, r), 10)
check("no bin at grey", ns.Bin(70, r), nil)
check("no bin when orange", ns.Bin(44, r), nil)
check("bin range text", ns.BinRange(3), "20-30%")
check("the line: 100% at yellow", ns.Line(45, r), 1)
check("the line at 50", ns.Line(50, r), 0.8)
check("the line on the last point before grey", ns.Line(69, r), 1 / 25)
check("no line at grey", ns.Line(70, r), nil)
check("no line when orange", ns.Line(44, r), nil)
check("arrow optimal is orange", ns.BandOf(Enum.TradeskillRelativeDifficulty.Optimal), "orange")
check("arrow easy is green", ns.BandOf(Enum.TradeskillRelativeDifficulty.Easy), "green")
check("secret arrow", ns.BandOf(Secret()), nil)
check("base skill matches the arrow", ns.EffectiveSkill(r, 50, 0, "yellow"), 50)
check("arrow disagrees: not counted", ns.EffectiveSkill(r, 50, 0, "green"), nil)
check("bonus explains the arrow", ns.EffectiveSkill(r, 50, 10, "green"), 60)
check("no arrow, no bonus: base", ns.EffectiveSkill(r, 50, 0, nil), 50)
check("no arrow, a bonus: unsure", ns.EffectiveSkill(r, 50, 10, nil), nil)
local lo, hi = ns.Wilson(5, 10)
check("wilson brackets the rate", lo < 0.5 and hi > 0.5, true)
check("wilson of nothing", select(2, ns.Wilson(0, 0)), 1)

-- ---------------------------------------------------------------- following crafts

local st = ns.Stats()
Craft(VEST, "Cast-1", 1)
check("a point counted in its range", st.bins[3].n, 1)
check("as a success", st.bins[3].up, 1)
check("with the point the line expected", st.bins[3].exp, 0.8)
check("recipe counter", st.recipes[VEST].n, 1)
check("raw log kept", st.log[1], "2385:50:0:1:y:" .. Now)
check("last craft", ns.last.gain, 1)
check("skill read through the recipe api", ns.source, "recipe")

Craft(VEST, "Cast-2", 0)
check("no point counted too", st.bins[3].n, 2)
check("not a success", st.bins[3].up, 1)

FireEvent("UNIT_SPELLCAST_START", "player", "Cast-3", VEST)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", VEST)
check("waiting for the result", ns.Pending() ~= nil, true)
Skill[197] = 52
FireEvent("SKILL_LINES_CHANGED")
check("a skill change counts it at once", ns.Pending(), nil)
check("counted before the timer", st.bins[3].up, 2)
RunTimers()
check("the timer does not count it twice", st.bins[3].n, 3)

FireEvent("UNIT_SPELLCAST_START", "player", "Cast-4", VEST)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", VEST)
FireEvent("UNIT_SPELLCAST_START", "player", "Cast-5", VEST)
check("the next cast counts the last one", st.bins[3].n, 4)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-5", VEST)
RunTimers()
check("and then itself", st.bins[3].n, 5)

local orange = st.orange.n
Craft(BOOTS, "Cast-6", 1)
check("orange counted apart", st.orange.n, orange + 1)
check("orange success", st.orange.up, 1)
check("orange not in a range", st.bins[1].n, 0)

local skipped = st.skipped
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-7", VEST)
check("instant craft without a reading: skipped", st.skipped, skipped + 1)
check("and not waiting", ns.Pending(), nil)

FireEvent("UNIT_SPELLCAST_START", "party1", "Cast-8", VEST)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast-8", VEST)
check("someone else's craft is ignored", ns.Pending(), nil)
FireEvent("UNIT_SPELLCAST_START", "player", "Cast-9", Secret())
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-9", Secret())
check("a secret spell is ignored", ns.Pending(), nil)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-10", 6603)
check("a spell that is no recipe is ignored", ns.Pending(), nil)

local binTotal = st.bins[3].n + st.bins[4].n
SkillMax = Skill[197]
skipped = st.skipped
Craft(VEST, "Cast-11", 0)
check("at the cap: skipped", st.skipped, skipped + 1)
check("at the cap: not counted", st.bins[3].n + st.bins[4].n, binTotal)
SkillMax = 75

ForceBand[VEST] = Enum.TradeskillRelativeDifficulty.Easy
local mismatch = st.mismatch
Craft(VEST, "Cast-12", 0)
check("arrow disagrees: counted as a mismatch", st.mismatch, mismatch + 1)
SkillMod = 10
Craft(VEST, "Cast-13", 1)
check("a bonus that explains the arrow counts", st.bins[ns.Bin(Skill[197] - 1 + 10, r)].n >= 1, true)
SkillMod = 0
ForceBand[VEST] = nil

root.SetOption(ns, "learn", false)
local logged = #st.log
Craft(VEST, "Cast-14", 1)
check("measuring off: nothing recorded", #st.log, logged)
root.SetOption(ns, "learn", true)

-- ---------------------------------------------------------------- odds

local function Milli(x)
	return math.floor(x * 1000 + 0.5)
end

-- Stats from before 0.13.0 have no expected points: they are rebuilt once from the raw log, and a
-- range with crafts older than the log takes the line at its middle.
db.stats = { orange = { n = 0, up = 0, pts = 0 }, grey = { n = 0, up = 0, pts = 0 }, bins = {}, recipes = {}, skipped = 0, mismatch = 0 }
for i = 1, 10 do
	db.stats.bins[i] = { n = 0, up = 0, pts = 0 }
end
db.stats.bins[3] = { n = 2, up = 1, pts = 1 } -- Brown Linen Vest at 50
db.stats.bins[7] = { n = 1, up = 0, pts = 0 } -- and at 60
db.stats.bins[5] = { n = 4, up = 2, pts = 2 } -- older than the log
db.stats.log = { "2385:50:0:1:y:1", "2385:50:0:0:y:1", "2385:60:0:0:g:1", "2385:44:0:1:o:1" }
st = ns.Stats()
check("old stats: rebuilt from the log", Milli(st.bins[3].exp), 1600)
check("old stats: each craft at its own skill", Milli(st.bins[7].exp), 400)
check("old stats: crafts before the log at the range's middle", Milli(st.bins[5].exp), Milli(4 * 0.55))
check("old stats: marked rebuilt", st.v, 2)
st.bins[3].exp = 99
check("rebuilt only once", ns.Stats().bins[3].exp, 99)

-- A clean slate: before any craft the odds are the line as it stands.
db.stats = nil
st = ns.Stats()
Skill[197] = 50
local o = ns.Odds(r, 50, "yellow")
check("no crafts yet: the line", o.chance, 0.8)
check("the line's own value", o.line, 0.8)
check("scaled by nothing", o.scale.k, 1)
check("its range", o.bin, 3)
-- Ten crafts at 50, six gave a point: the line expected 8, so the odds come down by (6 + 10) / (8 + 10).
capture(function()
	for i = 1, 10 do
		Craft(VEST, "Odds-" .. i, i <= 6 and 1 or 0)
		Skill[197] = 50
	end
end)
o = ns.Odds(r, 50, "yellow")
check("tuned by the crafts", Milli(o.chance), Milli(0.8 * 16 / 18))
check("points a craft", Milli(o.perCraft), Milli(0.8 * 16 / 18))
check("crafts behind the scale", o.scale.n, 10)
check("got against expected", o.scale.up .. "/" .. Milli(o.scale.exp), "6/8000")
check("this range's own count", o.here.n .. "/" .. o.here.up, "10/6")
check("the scale reaches every recipe", Milli(ns.Odds(ns.Recipe(CLOAK), 50, "green").chance), Milli(0.4 * 16 / 18))
check("orange by the game's rule", ns.Odds(ns.Recipe(BOOTS), 50, "orange").chance, 1)
check("orange marked as the rule", ns.Odds(ns.Recipe(BOOTS), 50, "orange").rule, true)
check("grey never", ns.Odds(r, 70, "grey").chance, 0)
check("unknown skill: no odds", ns.Odds(r, nil, "yellow").chance, nil)
local saved = db.stats
db.stats = nil
st = ns.Stats()
st.bins[1] = { n = 20, up = 20, pts = 20, exp = 18 }
check("crafts above the line lift it", ns.Scale().k > 1, true)
check("but never past 100%", ns.Odds(r, 45, "yellow").chance, 1)
st.bins[1].pts = 30
check("double points count in points a craft", Milli(ns.Odds(r, 50, "yellow").perCraft), Milli(math.min(1, 0.8 * 30 / 28) * 1.5))
db.stats = saved
st = ns.Stats()

-- ---------------------------------------------------------------- a steady ranking

local function P(id, perPoint)
	return { id = id, perPoint = perPoint, name = "r" .. id }
end
local fresh = { P(2, 95), P(1, 100), P(3, 300) }
local steady, place = ns.Steady(fresh, { [1] = 1, [2] = 2, [3] = 3 })
check("a small edge keeps the order", steady[1].id, 1)
check("the order's places", place[1] .. place[2] .. place[3], "123")
check("a clear edge swaps", ns.Steady({ P(2, 80), P(1, 100), P(3, 300) }, { [1] = 1, [2] = 2, [3] = 3 })[1].id, 2)
check("a new recipe that is clearly best goes to the top", ns.Steady({ P(4, 50), P(1, 100), P(3, 300) }, { [1] = 1, [3] = 2 })[1].id, 4)
check("a new recipe that is not clearly better waits below", ns.Steady({ P(1, 100), P(5, 290), P(3, 300) }, { [1] = 1, [3] = 2 })[3].id, 5)
check("no previous order: the fresh ranking", ns.Steady(fresh)[1].id, 2)
check("a gone recipe leaves no gap", #ns.Steady({ P(1, 100) }, { [1] = 1, [9] = 2 }), 1)
check("odds and cost beat cost alone", ns.Clearly(P(1, 900), { id = 2, craft = { net = 1 } }), true)
check("a bigger profit is cheaper", ns.Clearly(P(1, -50), P(2, -10)), true)
check("never clearly better than itself", ns.Clearly(P(1, 100), P(1, 100)), false)

-- ---------------------------------------------------------------- prices

Prices[BOLT], Prices[THREAD] = 1000, 50
Merchant = { { id = THREAD, price = 10 }, { id = 999, price = 500 }, { id = 4470, price = 380, stack = 5, extended = true } }
Items[4470] = { name = "Simple Wood", class = 7 }
FireEvent("MERCHANT_SHOW")
check("vendor price learned", db.vendor[THREAD], 10)
check("not for armor", db.vendor[999], nil)
check("not for extended cost", db.vendor[4470], nil)
local unit, src, age = ns.UnitCost(THREAD)
check("vendor cheaper than auction", unit, 10)
check("from the vendor", src, "vendor")
check("a vendor price has no age", age, nil)
check("auction price otherwise", (ns.UnitCost(BOLT)), 1000)
Ages[BOLT] = 2
check("with its age", select(3, ns.UnitCost(BOLT)), 2)
db.vendor[BOLT] = 1200
check("a fresh auction price beats a dearer vendor", (ns.UnitCost(BOLT)), 1000)
Ages[BOLT] = 5
check("a stale one does not", (ns.UnitCost(BOLT)), 1200)
db.vendor[BOLT] = nil
check("a stale price is still a price", (ns.UnitCost(BOLT)), 1000)
check("and the craft says how old", ns.CraftCost(VEST).stale, 5)
Ages[BOLT] = 0
check("a fresh craft is not stale", ns.CraftCost(VEST).stale, nil)
local c = ns.CraftCost(VEST)
check("craft cost: basic reagents only", c.cost, 1010)
check("resale at vendor", c.resale, 300)
check("net", c.net, 710)
root.SetOption(ns, "resaleAH", true)
Prices[VEST_ITEM] = 1000
check("resale at auction after the cut", ns.CraftCost(VEST).resale, 950)
Ages[VEST_ITEM] = 10
check("not at a stale auction price", ns.CraftCost(VEST).resale, 300)
Ages[VEST_ITEM] = nil
root.SetOption(ns, "resaleAH", false)
root.SetOption(ns, "resale", false)
check("resale off", ns.CraftCost(VEST).net, 1010)
root.SetOption(ns, "resale", true)
Prices[BOLT] = nil
c = ns.CraftCost(VEST)
check("a reagent without a price: no cost", c.cost, nil)
check("and it is named", c.missing, "Bolt of Linen Cloth")
Prices[BOLT] = 1000

local e = ns.Evaluate(VEST, nil, nil, true)
check("evaluate: band from the arrow", e.band, "yellow")
check("evaluate: the tuned line", Milli(e.chance), Milli(0.8 * 16 / 18))
check("gold a point = net / points a craft", math.floor(e.perPoint + 0.5), math.floor(710 / (0.8 * 16 / 18) + 0.5))

-- ---------------------------------------------------------------- ranking

local list, prof = ns.Rank()
check("open profession", prof.line, 197)
check("profession name", prof.name, "Tailoring")
local ids = {}
for i, x in ipairs(list) do
	ids[x.id] = i
end
check("unlearned recipe left out", ids[SHIRT], nil)
check("other profession left out", ids[BANDAGE], nil)
-- Vest: 710 / 0.711 = 998 a point. Boots: orange, 2 bolts + thread = 2010 - 100 resale = 1910.
-- Robe: 2 bolts / 0.889 = 2250 (no crafts of its own: the tuned line). Cloak: 1 bolt / 0.356 = 2813.
check("cheapest point first", list[1].id, VEST)
check("orange next", list[2].id, BOOTS)
check("a recipe never crafted is ranked too", list[3].id, ROBE)
check("by its gold a point", Milli(list[3].perPoint), Milli(2000 / (16 / 18)))
check("dearest last", list[4].id, CLOAK)

-- ---------------------------------------------------------------- the crafting window

MakeProfessionsFrame()
local vestRow, vestNode = NewRecipeRow(VEST)
local robeRow, robeNode = NewRecipeRow(ROBE)
local shirtRow, shirtNode = NewRecipeRow(SHIRT)
RecipeRows = { { row = vestRow, node = vestNode }, { row = robeRow, node = robeNode }, { row = shirtRow, node = shirtNode } }
ProfessionsFrame:Show()
FireEvent("TRADE_SKILL_SHOW")
check("hooked the recipe list", #ProfessionsFrame.CraftingPage.RecipeList.ScrollBox.callbacks, 1)
check("rows on screen decorated", vestRow.kwfOdds ~= nil, true)
check("the chance beside the arrow", tostring(vestRow.kwfOdds.text):find("71%", 1, true) ~= nil, true)
check("shown", vestRow.kwfOdds.shown, true)
check("a recipe never crafted has odds too", tostring(robeRow.kwfOdds.text):find("89%", 1, true) ~= nil, true)
check("unlearned shows nothing", shirtRow.kwfOdds.shown, false)
local box = ProfessionsFrame.CraftingPage.RecipeList.ScrollBox
local lateRow, lateNode = NewRecipeRow(CLOAK)
box:InitRow(lateRow, lateNode)
check("a row set up later is decorated too", lateRow.kwfOdds ~= nil and lateRow.kwfOdds.shown, true)
vestRow.Label.width = 250
box:InitRow(vestRow, vestNode)
check("a long name is kept clear of the odds", vestRow.Label.width < 250, true)

vestRow.kwfHit.scripts.OnEnter(vestRow.kwfHit)
check("hover: tooltip title", tostring(GameTooltip.title):find("71%", 1, true) ~= nil, true)
check("hover: the line at your skill", has(GameTooltip.lines, "gives 80% at your skill"), true)
check("hover: how your crafts move it", has(GameTooltip.lines, "11% below the line"), true)
check("hover: got against expected", has(GameTooltip.lines, "gave a point 6 times where the line expected 8"), true)
check("hover: this part of the range", has(GameTooltip.lines, "6 of 10 crafts gave a point; the line expected 8"), true)
check("hover: the cost", has(GameTooltip.lines, "A craft costs"), true)
check("hover: where each price is from", has(GameTooltip.lines, "auction, today"), true)
check("hover: gold a point", has(GameTooltip.lines, "A point costs"), true)
check("hover: fresh prices raise no flag", has(GameTooltip.lines, "days old."), false)
Ages[BOLT] = 4
vestRow.kwfHit.scripts.OnEnter(vestRow.kwfHit)
check("hover: an old auction price is flagged", has(GameTooltip.lines, "Auction prices up to 4 days old"), true)
Ages[BOLT] = 0
robeRow.kwfHit.scripts.OnEnter(robeRow.kwfHit)
check("hover, never crafted: the line", has(GameTooltip.lines, "The line from yellow"), true)
check("hover, never crafted: no range count", has(GameTooltip.lines, "Here ("), false)

RunTimers()
local panel = ns.Panel()
check("panel built", panel ~= nil, true)
check("panel shown with the window", panel.shown, true)
check("panel title", panel.title, "Next Skill Point")
check("the cheapest point is highlighted", panel.rows[1].best.shown, true)
check("only that one", panel.rows[2].best.shown, false)
check("no message over a full list", panel.message.shown, false)
check("no heading, explainer or price footer", panel.skill == nil and panel.sub == nil and panel.note == nil, true)
local rowsShown = 0
for _, r in ipairs(panel.rows) do
	rowsShown = rowsShown + (r.shown and 1 or 0)
end
check("panel is as tall as its rows", panel.height, 30 + rowsShown * 42 - 2 + 8)
check("best row first", panel.rows[1].o.id, VEST)
check("its gold a point", tostring(panel.rows[1].cost.text):find("a point", 1, true) ~= nil, true)
check("every row has its gold a point", has({ panel.rows[3].cost.text }, "a point") and has({ panel.rows[4].cost.text }, "a point"), true)
check("the panel's order", panel.rows[2].o.id .. "," .. panel.rows[3].o.id .. "," .. panel.rows[4].o.id, BOOTS .. "," .. ROBE .. "," .. CLOAK)
check("no old-price flag on fresh prices", has({ panel.rows[1].detail.text }, "old prices"), false)
panel.rows[1]:Click()
check("click selects the recipe", Opened[#Opened], VEST)
panel.rows[1].scripts.OnEnter(panel.rows[1])
check("row hover tooltip", has(GameTooltip.lines, "A point costs"), true)

-- Prices move while the panel is open. Thread at auction only: Boots 2300 a point, Robe 2250, so
-- Robe is a little cheaper and the list stays put.
db.vendor[THREAD], Prices[THREAD] = nil, 400
Clock = Clock + 1
FireEvent("BAG_UPDATE_DELAYED")
RunTimers()
check("a small edge does not reorder the panel", panel.rows[2].o.id .. "," .. panel.rows[3].o.id, BOOTS .. "," .. ROBE)
-- An Auctionator scan lands: Boots 2700 a point, Robe still 2250, clearly cheaper now.
Prices[THREAD] = 800
AuctionatorScan()
RunTimers()
check("a scan re-prices the panel, and a clear edge moves up", panel.rows[2].o.id .. "," .. panel.rows[3].o.id, ROBE .. "," .. BOOTS)
Ages[BOLT] = 5
AuctionatorScan()
RunTimers()
check("rows priced from old auctions say so", has({ panel.rows[1].detail.text }, "old prices"), true)
Ages[BOLT], db.vendor[THREAD], Prices[THREAD] = 0, 10, 50
Skill[197] = 50
Clock = Clock + 1
FireEvent("TRADE_SKILL_LIST_UPDATE")
RunTimers()
check("prices back: Boots earns its place again", panel.rows[2].o.id, BOOTS)
local beforeCraft = panel.rows[1].o
Craft(VEST, "Steady-1", 0)
Skill[197] = 50
check("a craft re-ranks without reshuffling", panel.rows[1].o.id, VEST)
check("with fresh numbers", panel.rows[1].o ~= beforeCraft, true)

-- Forever's window has a column of profession tabs on its right edge: the panel docks past it, and
-- its own tab joins the bottom of that column.
local dock = panel.points and panel.points[#panel.points]
check("panel docks to the window's right edge", dock and dock.rel == ProfessionsFrame and dock.relPoint == "TOPRIGHT", true)
check("past the profession tabs", dock and dock.x, 60)
local tab
for _, f in ipairs(CreatedFrames) do
	if f.parent == ProfessionsFrame and f ~= panel then
		tab = f
	end
end
check("the toggle is a Blizzard side tab", tab and tab.template, "LargeSideTabButtonTemplate")
check("with the feature's icon", tab.Icon.texture, ns.icon)
check("filling the tab like the profession icons", tab.fillToInterior, true)
check("not drawn as the selected profession", tab.SelectedTexture.shown, false)
local at = tab.points and tab.points[#tab.points]
check("below the last profession tab", at and at.rel == ProfessionsFrame.rightProfessionTabs[2] and at.relPoint == "BOTTOMLEFT", true)
check("tab shown beside the open panel", tab.shown, true)
GameTooltip:SetOwner(tab)
check("tab tooltip handled", tab:GetTooltipTextSetupFunction()(GameTooltip), true)
check("tab tooltip says what a click does", has(GameTooltip.lines, "Click to hide"), true)
check("and how the odds are made", has(GameTooltip.lines, "tuned by 11 crafts on this account"), true)
ProfessionsFrame.rightProfessionTabs[3].shown = true -- a profession learned
ProfessionsFrame:RefreshRightTabs()
at = tab.points[#tab.points]
check("the tab follows the column down", at.rel, ProfessionsFrame.rightProfessionTabs[3])
ProfessionsFrame.rightProfessionTabs[3].shown = false
ProfessionsFrame:RefreshRightTabs()

tab:MouseUp("LeftButton", false)
check("a release off the tab does nothing", db.panel, true)
tab:MouseUp("LeftButton", true)
check("the tab hides the panel", db.panel, false)
check("panel hidden by the tab", panel.shown, false)
check("the tab stays", tab.shown, true)
tab:MouseUp("LeftButton", true)
check("and brings it back", db.panel, true)
check("panel back", panel.shown, true)

panel.CloseButton:Click()
check("closing turns the panel option off", db.panel, false)
check("panel hidden", panel.shown, false)
check("reopen tab shown", tab.shown, true)
tab:MouseUp("LeftButton", true)
check("tab turns it back on", db.panel, true)
check("panel back again", panel.shown, true)

FireEvent("TRADE_SKILL_CLOSE")
check("panel goes with the window", panel.shown, false)

SkillMax = 50
ProfessionsFrame:Show()
FireEvent("TRADE_SKILL_SHOW")
RunTimers()
check("at the cap the panel says so", tostring(panel.message.text):find("At your cap", 1, true) ~= nil and panel.message.shown, true)
check("in one row's height", panel.height, 30 + 42 - 2 + 8)
check("and lists nothing", panel.rows[1].shown, false)
SkillMax = 75

-- ---------------------------------------------------------------- slash and hub

out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_SKILLUP("")
end)
check("/kwu says how the odds are made", has(out, "tuned by 11 crafts"), true)
check("/kwu lists the ranges", has(out, "20-30%"), true)
check("/kwu shows the counts", has(out, "6 of 11 gave a point"), true)
check("/kwu sets each range against the line", has(out, "the line expected 9"), true)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_SKILLUP("status")
end)
check("/kwu status names the data build", has(out, "1.60.1.70888"), true)
check("/kwu status names the skill source", has(out, "recipe"), true)
check("/kwu status: refreshed by Auctionator's scans", has(out, "refreshes after its scans"), true)
check("hub status counts crafts", ns.HubStatus():find("11 crafts measured", 1, true) ~= nil, true)
check("hub status says how the crafts sit against the line", ns.HubStatus():find("% below the line", 1, true) ~= nil, true)

-- ---------------------------------------------------------------- off means off

capture(function()
	SlashCmdList.KROOLWORLDFOREVER("skillup off")
end)
check("/kw skillup off turns it off", ns.enabled, false)
logged = #st.log
Craft(VEST, "Off-1", 1)
check("off: crafts not recorded", #st.log, logged)
box:InitRow(vestRow, vestNode)
check("off: no odds in the list", vestRow.kwfOdds.shown, false)
ProfessionsFrame:Show()
FireEvent("TRADE_SKILL_SHOW")
check("off: no panel", panel.shown, false)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_SKILLUP("")
end)
check("off: its slash says so", has(out, "is off"), true)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("skillup on")
end)
check("back on", ns.enabled, true)
Clock = Clock + 1 -- a new frame: the profession is read again
box:InitRow(vestRow, vestNode)
check("on: odds return", vestRow.kwfOdds.shown, true)

-- ---------------------------------------------------------------- failures stay inside

local realSchematic = C_TradeSkillUI.GetRecipeSchematic
C_TradeSkillUI.GetRecipeSchematic = function()
	error("kaput")
end
check("schematic error: no cost, no raise", ns.CraftCost(VEST), nil)
C_TradeSkillUI.GetRecipeSchematic = realSchematic
local realInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID
C_TradeSkillUI.GetProfessionInfoByRecipeID = function()
	error("kaput")
end
check("skill read falls back to the child line", select(4, ns.ReadSkill(VEST)), "line")
C_TradeSkillUI.GetProfessionInfoByRecipeID = realInfo
local badNode = {
	GetData = function()
		error("bad node")
	end,
}
local ok
out = capture(function()
	ok = pcall(box.InitRow, box, vestRow, badNode)
end)
check("a broken row never reaches the client", ok, true)
check("it prints a line instead", has(out, "bad node"), true)

realPrint(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error("skillup tests failed")
end
