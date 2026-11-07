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

-- ---------------------------------------------------------------- data and bands

local r = ns.Recipe(VEST)
check("data build", ns.Data.build, "1.60.1.70862")
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

-- A clean slate: ten crafts at 50, six gave a point.
db.stats = nil
st = ns.Stats()
Skill[197] = 50
local o = ns.Odds(r, 50, "yellow")
check("unmeasured range: no chance", o.chance, nil)
check("unmeasured range has its bin", o.bin, 3)
local out = capture(function()
	for i = 1, 10 do
		Craft(VEST, "Odds-" .. i, i <= 6 and 1 or 0)
		Skill[197] = 50
	end
end)
check("a ready range is announced", has(out, "measured odds now show at 20-30%"), true)
o = ns.Odds(r, 50, "yellow")
check("measured chance", o.chance, 0.6)
check("points a craft", o.perCraft, 0.6)
check("crafts behind it", o.n, 10)
check("orange by the game's rule", ns.Odds(ns.Recipe(BOOTS), 50, "orange").chance, 1)
check("orange marked as the rule", ns.Odds(ns.Recipe(BOOTS), 50, "orange").rule, true)
check("grey never", ns.Odds(r, 70, "grey").chance, 0)

-- ---------------------------------------------------------------- prices

Prices[BOLT], Prices[THREAD] = 1000, 50
Merchant = { { id = THREAD, price = 10 }, { id = 999, price = 500 }, { id = 4470, price = 380, stack = 5, extended = true } }
Items[4470] = { name = "Simple Wood", class = 7 }
FireEvent("MERCHANT_SHOW")
check("vendor price learned", db.vendor[THREAD], 10)
check("not for armor", db.vendor[999], nil)
check("not for extended cost", db.vendor[4470], nil)
local unit, src = ns.UnitCost(THREAD)
check("vendor cheaper than auction", unit, 10)
check("from the vendor", src, "vendor")
check("auction price otherwise", (ns.UnitCost(BOLT)), 1000)
local c = ns.CraftCost(VEST)
check("craft cost: basic reagents only", c.cost, 1010)
check("resale at vendor", c.resale, 300)
check("net", c.net, 710)
root.SetOption(ns, "resaleAH", true)
Prices[VEST_ITEM] = 1000
check("resale at auction after the cut", ns.CraftCost(VEST).resale, 950)
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
check("evaluate: measured chance", e.chance, 0.6)
check("gold a point = net / points a craft", math.floor(e.perPoint + 0.5), math.floor(710 / 0.6 + 0.5))

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
-- Boots: orange, 2 bolts + thread = 2010 - 100 resale = 1910 a point. Vest: 710 / 0.6 = 1183.
check("cheapest point first", list[1].id, VEST)
check("orange next", list[2].id, BOOTS)
check("measuring ranges after the known ones", ids[ROBE] > 2 and ids[CLOAK] > 2, true)
check("measuring recipe still has a cost", list[ids[ROBE]].craft.net ~= nil, true)
check("but no gold a point", list[ids[ROBE]].perPoint, nil)

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
check("measured chance beside the arrow", tostring(vestRow.kwfOdds.text):find("60%", 1, true) ~= nil, true)
check("shown", vestRow.kwfOdds.shown, true)
check("unmeasured shows ?%", tostring(robeRow.kwfOdds.text):find("?%", 1, true) ~= nil, true)
check("unlearned shows nothing", shirtRow.kwfOdds.shown, false)
local box = ProfessionsFrame.CraftingPage.RecipeList.ScrollBox
local lateRow, lateNode = NewRecipeRow(CLOAK)
box:InitRow(lateRow, lateNode)
check("a row set up later is decorated too", lateRow.kwfOdds ~= nil and lateRow.kwfOdds.shown, true)
vestRow.Label.width = 250
box:InitRow(vestRow, vestNode)
check("a long name is kept clear of the odds", vestRow.Label.width < 250, true)

vestRow.kwfHit.scripts.OnEnter(vestRow.kwfHit)
check("hover: tooltip title", tostring(GameTooltip.title):find("60%", 1, true) ~= nil, true)
check("hover: the crafts behind it", has(GameTooltip.lines, "6 of 10 crafts gave a point"), true)
check("hover: the cost", has(GameTooltip.lines, "A craft costs"), true)
check("hover: gold a point", has(GameTooltip.lines, "A point costs"), true)
robeRow.kwfHit.scripts.OnEnter(robeRow.kwfHit)
check("hover unmeasured: says so", has(GameTooltip.lines, "Still measuring"), true)

RunTimers()
local panel = ns.Panel()
check("panel built", panel ~= nil, true)
check("panel shown with the window", panel.shown, true)
check("panel faded in", panel.kwfFade ~= nil and panel.kwfFade.played >= 1, true)
check("panel title", panel.title, "Next Skill Point")
check("panel heading", panel.skill.text, "Tailoring 50 / 75")
check("best row first", panel.rows[1].o.id, VEST)
check("its gold a point", tostring(panel.rows[1].cost.text):find("a point", 1, true) ~= nil, true)
check("measuring rows say so", has({ panel.rows[3].cost.text, panel.rows[4].cost.text }, "measuring"), true)
panel.rows[1]:Click()
check("click selects the recipe", Opened[#Opened], VEST)
panel.rows[1].scripts.OnEnter(panel.rows[1])
check("row hover tooltip", has(GameTooltip.lines, "A point costs"), true)

panel.CloseButton:Click()
check("closing turns the panel option off", db.panel, false)
check("panel hidden", panel.shown, false)
local tab
for _, f in ipairs(CreatedFrames) do
	if f.parent == ProfessionsFrame and f ~= panel then
		tab = f
	end
end
check("reopen tab shown", tab and tab.shown, true)
tab:Click()
check("tab turns it back on", db.panel, true)
check("panel back", panel.shown, true)
check("tab hidden again", tab.shown, false)

FireEvent("TRADE_SKILL_CLOSE")
check("panel goes with the window", panel.shown, false)

SkillMax = 50
ProfessionsFrame:Show()
FireEvent("TRADE_SKILL_SHOW")
RunTimers()
check("at the cap the panel says so", tostring(panel.sub.text):find("At your cap", 1, true) ~= nil, true)
check("and lists nothing", panel.rows[1].shown, false)
SkillMax = 75

-- ---------------------------------------------------------------- slash and hub

out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_SKILLUP("")
end)
check("/kwu lists the ranges", has(out, "20-30%"), true)
check("/kwu shows the counts", has(out, "6 of 10 gave a point"), true)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_SKILLUP("status")
end)
check("/kwu status names the data build", has(out, "1.60.1.70862"), true)
check("/kwu status names the skill source", has(out, "recipe"), true)
check("hub status counts crafts", ns.HubStatus():find("crafts measured", 1, true) ~= nil, true)
check("hub status counts ready ranges", ns.HubStatus():find("1 of 10", 1, true) ~= nil, true)

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
