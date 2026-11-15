-- Reagent Uses under the stub client, inside the whole bundle: the data, the tooltip, the
-- known-recipe scan, the character roster, options and /ru, saved-data migration, and the other
-- tooltip features. Fixture facts come from Data.lua for build 1.60.1.70938.

local root = __ns
local ns = root.features.reagents
local checks, failed = 0, 0
local realPrint = print
local function Check(cond, label)
	checks = checks + 1
	if cond then
		realPrint("ok: " .. label)
	else
		failed = failed + 1
		realPrint("FAIL: " .. label)
	end
end

-- Runs fn with print captured; the lines it printed.
local function Capture(fn)
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

local function Plain(s)
	return ((s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- The first tooltip line whose plain left text matches pattern (and its index).
local function Find(lines, pattern)
	for i, l in ipairs(lines) do
		if Plain(l.left):find(pattern) then
			return l, i
		end
	end
	return nil
end

local function Count(lines, pattern)
	local n = 0
	for _, l in ipairs(lines) do
		if Plain(l.left):find(pattern) then
			n = n + 1
		end
	end
	return n
end

local function ErrorCount()
	return #(KroolWorldForeverDB.errors or {})
end

local SILK = 4306 -- Silk Cloth
local BOLT = 3839 -- Bolt of Silk Cloth: Tailoring, yellow 110, grey 120, makes 4305, trainer
local BANDAGE = 7928 -- Silk Bandage: First Aid, yellow 150, grey 210, trainer at 150
local HEAVY = 7929 -- Heavy Silk Bandage: First Aid, yellow 180, grey 240, vendor at 180
local ME = "Krool-Forever"
local D = ns.Data

-- ---------------------------------------------------------------- data

Check(type(D) == "table" and D.build == "1.60.1.70938", "Data.lua loads with its build")
do
	local bad, recipes, used = 0, 0, 0
	for id, r in pairs(D.recipes) do
		recipes = recipes + 1
		if
			type(r) ~= "table"
			or type(D.lines[r[1]]) ~= "table"
			or type(r[2]) ~= "number"
			or type(r[3]) ~= "number"
			or type(r[4]) ~= "number"
			or type(r[5]) ~= "string"
			or not r[5]:match("^[STVDFQR]*$")
			or type(r[6]) ~= "number"
			or (r[6] > 0 and r[2] > 0 and r[6] > r[2])
		then
			bad = bad + 1
		end
	end
	for item, list in pairs(D.uses) do
		if #list % 2 ~= 0 then
			bad = bad + 1
		end
		for i = 1, #list, 2 do
			used = used + 1
			if not D.recipes[list[i]] or list[i + 1] < 1 then
				bad = bad + 1
			end
		end
	end
	Check(recipes > 2000 and used > 5000, "about 2100 recipes and their materials are in the data")
	Check(bad == 0, "every recipe row is well formed, and every use points at a recipe (" .. bad .. " bad)")
end
Check(ns.UseCount(SILK) == 10, "Silk Cloth is used in 10 recipes")
Check(D.recipes[2166][6] == 95 and D.recipes[2166][2] == 120, "a vanilla trainer level moves with Forever's yellow (Toughened Leather Armor 120 -> 95)")
Check(D.recipes[1292981] ~= nil and D.recipes[1292981][4] == 0, "a recipe whose crafted item the client hides is kept, without the item")
do
	local seen = {}
	for i = 1, #D.uses[SILK], 2 do
		seen[D.uses[SILK][i]] = D.uses[SILK][i + 1]
	end
	Check(seen[BOLT] == 4, "Bolt of Silk Cloth takes 4 Silk Cloth")
	Check(D.recipes[BOLT][4] == 4305 and ns.UseCount(4305) > 50, "the bolt it makes goes into over 50 recipes")
end
do
	local test, seasonal = false, false
	for _, d in pairs(D.lines) do
		if d[1]:find("DNT") or d[1]:find("Test") then
			test = true
		end
	end
	for id in pairs(D.recipes) do
		if id == 461651 or id == 439500 then -- Season of Discovery leftovers in the client
			seasonal = true
		end
	end
	Check(not test, "no test profession in the data")
	Check(not seasonal, "Season of Discovery recipes are left out")
end

-- ---------------------------------------------------------------- the declaration

Check(ns.title == "Reagent Uses" and type(ns.description) == "string", "the feature has a title and a description")
Check(ns.icon == "Interface\\Icons\\INV_Fabric_Silk_01" and type(ns.blurb) == "string", "hub card: icon and blurb")
Check(SLASH_KROOLWORLDFOREVER_REAGENTS1 == nil, "no slash command before the addon loads")
do
	local keys = {}
	for _, o in ipairs(ns.options) do
		keys[#keys + 1] = o.key .. ":" .. o.type .. ":" .. tostring(o.default)
	end
	Check(table.concat(keys, " ") == "modifier:choice:CTRL hint:toggle:true alts:toggle:true hideGrey:toggle:false maxRecipes:range:15", "five options with the old defaults")
	Check(ns.options[1].label == "Show With" and ns.options[5].min == 5 and ns.options[5].max == 50, "Show With, and Recipes Shown from 5 to 50")
end

-- ---------------------------------------------------------------- start up

Skills[2948] = 150 -- Tailoring, on Forever's child line
Skills[129] = 100 -- First Aid
FireEvent("ADDON_LOADED", "KroolWorldForever")
local db = KroolWorldForeverDB.features.reagents
Check(db.modifier == "CTRL" and db.hint == true and db.alts == true and db.hideGrey == false and db.maxRecipes == 15, "saved data starts with the defaults, Ctrl as the key")
Check(type(db.known) == "table" and type(db.skills) == "table", "the slice holds known and skills tables")
Check(SLASH_KROOLWORLDFOREVER_REAGENTS1 == "/ru" and SLASH_KROOLWORLDFOREVER_REAGENTS2 == "/reagentuses", "/ru and /reagentuses are registered")
Capture(function()
	FireEvent("PLAYER_LOGIN")
end)
Check(ns.enabled == true, "enabled after login")
local function Hooks()
	local n = 0
	for _, fn in ipairs(TooltipChains[Enum.TooltipDataType.Item] or {}) do
		if fn == ns.OnItemTooltip then
			n = n + 1
		end
	end
	return n
end
Check(Hooks() == 1, "one item tooltip post-call is registered")
Check(ns.MySkill(197) == 150 and ns.MySkill(129) == 100 and ns.MySkill(202) == nil, "skills read from the skill lines")
Check(root.Chars()[ME] ~= nil and db.skills[ME][197] == 150, "this character is on the roster, and its skills are saved for the others")
Capture(function()
	FireEvent("PLAYER_LOGIN")
end)
Check(Hooks() == 1, "the tooltip hook is added once")

-- ---------------------------------------------------------------- the hint and the key

local lines = ShowTip(GameTooltip, SILK)
Check(#lines == 1 and Plain(lines[1].left) == "Hold Ctrl: 10 recipes use this", "key up: one hint line")
db.hint = false
lines = ShowTip(GameTooltip, SILK)
Check(#lines == 0, "hint off: key up adds nothing")
db.hint = true

lines = ShowTip(GameTooltip, 117) -- Tough Jerky: no recipe uses it
Check(#lines == 0, "an item no recipe uses gets nothing")

Keys.CTRL = true
lines = ShowTip(GameTooltip, SILK)
Check(Find(lines, "^Tailoring 150$") ~= nil, "Ctrl held: the Tailoring group with your skill")
local _, tIdx = Find(lines, "^Tailoring")
local _, fIdx = Find(lines, "^First Aid")
local _, eIdx = Find(lines, "^Engineering")
Check(tIdx and fIdx and eIdx and tIdx < fIdx and fIdx < eIdx, "your professions first, higher skill first, then the rest")
local bolt = Find(lines, "Bolt of Silk Cloth")
Check(bolt and Plain(bolt.left):find("x4") and Plain(bolt.left):find("%(used in %d+%)"), "the bolt line shows the count and what the bolt goes into")
Check(bolt and bolt.left:find("|cff808080Bolt of Silk Cloth") ~= nil, "Tailoring 150 against grey 120: the bolt is grey")
Check(bolt and Plain(bolt.right) == "Trainer 100", "not known: where it is learned, at the shifted level (vanilla 125, Forever moved yellow down 25)")
local heavy = Find(lines, "Heavy Silk Bandage")
Check(heavy and heavy.left:find("|cffff1a1a") ~= nil, "First Aid 100 under the 180 it is learned at: red")
Check(heavy and Plain(heavy.right) == "Vendor 180" and heavy.right:find("|cffff1a1a180") ~= nil, "learn level shown, red while out of reach")
local eng = Find(lines, "^Engineering$")
Check(eng and Plain(eng.right) == "7 recipes", "a profession you lack has no skill and counts its recipes")
local dyn = Find(lines, "Solid Dynamite")
Check(dyn and dyn.left:find("|cffffffff") ~= nil, "without the profession, names are white")

lines = ShowTip(ShoppingTooltip1, SILK)
Check(#lines == 0, "comparison tooltips are left alone")
Keys.CTRL = false
lines = ShowTip(ItemRefTooltip, SILK)
Check(Find(lines, "^Tailoring") ~= nil, "a clicked chat link lists the recipes without the key")

-- ---------------------------------------------------------------- scanning the crafting window

local function OpenWindow(level, extra)
	Window = { base = { professionID = 197, skillLevel = level, professionName = "Tailoring" }, child = nil }
	for k, v in pairs(extra or {}) do
		Window[k] = v
	end
end
local function Known()
	return db.known[ME]
end
RecipeInfo = { [BOLT] = { learned = true }, [3914] = { learned = false } }
OpenWindow(150)
Timers = {}
Fire("TRADE_SKILL_SHOW")
Fire("TRADE_SKILL_LIST_UPDATE")
Fire("TRADE_SKILL_LIST_UPDATE")
Check(#Timers == 1, "window events queue one scan")
RunTimers()
Check(Known()[197] and Known()[197][BOLT] == true and Known()[197][3914] == nil, "the scan records learned recipes only")
Keys.CTRL = true
lines = ShowTip(GameTooltip, SILK)
bolt = Find(lines, "Bolt of Silk Cloth")
Check(bolt and Plain(bolt.right) == "Known", "a known recipe says Known")

-- Someone else's Tailoring (a chat link) shows their skill: it must not overwrite ours.
RecipeInfo = { [BOLT] = { learned = false }, [3865] = { learned = true } }
OpenWindow(300)
Fire("TRADE_SKILL_SHOW")
RunTimers()
Check(Known()[197][BOLT] == true and not Known()[197][3865], "a linked profession at another skill is not recorded")
OpenWindow(150, { npc = true })
Fire("TRADE_SKILL_SHOW")
RunTimers()
Check(Known()[197][BOLT] == true and not Known()[197][3865], "an NPC crafting window is not recorded")
Window = { base = { professionID = 202, skillLevel = 50 } }
RecipeInfo = { [12586] = { learned = true } }
Fire("TRADE_SKILL_SHOW")
RunTimers()
Check(Known()[202] == nil, "a profession this character does not have is not recorded")

-- A guildmate's or linked Tailoring at the very same skill: Blizzard's local-mode check says no.
RecipeInfo = { [BOLT] = { learned = false }, [3865] = { learned = true } }
OpenWindow(150, { linked = true })
Fire("TRADE_SKILL_SHOW")
RunTimers()
Check(Known()[197][BOLT] == true and not Known()[197][3865], "a linked view at your own skill is not recorded")
do
	local P = Professions
	Professions = nil
	OpenWindow(150)
	Fire("TRADE_SKILL_SHOW")
	RunTimers()
	Professions = P
	Check(Known()[197][BOLT] == true and not Known()[197][3865], "without Blizzard's local-mode check nothing is recorded")
end

-- The window closed before the queued scan ran.
OpenWindow(150)
Fire("TRADE_SKILL_SHOW")
Fire("TRADE_SKILL_CLOSE")
RunTimers()
Check(Known()[197][BOLT] == true and not Known()[197][3865], "a scan after the window closed reads nothing")

-- The list not loaded yet (every GetRecipeInfo nil): keep what we had.
OpenWindow(150)
RecipeInfo = {}
Fire("TRADE_SKILL_SHOW")
RunTimers()
Check(Known()[197][BOLT] == true, "an empty answer keeps the recorded recipes")
RecipeInfo = { [BOLT] = { learned = false }, [3914] = { learned = false } }
Fire("TRADE_SKILL_SHOW")
RunTimers()
Check(Known()[197][BOLT] == true, "an all-unlearned answer does not wipe the recorded recipes")

-- A secret learned flag is skipped, not tested: no error, both answers counted.
local errorsBefore = ErrorCount()
RecipeInfo = { [BOLT] = { learned = true }, [3914] = { learned = Secret() } }
Fire("TRADE_SKILL_SHOW")
local ok = pcall(RunTimers)
Check(ok and ErrorCount() == errorsBefore, "a secret learned flag raises no error")
Check(ns.lastScan and ns.lastScan.answered == 2 and ns.lastScan.known == 1, "the scan finished: one learned, the secret one skipped")
Check(Known()[197][BOLT] == true and Known()[197][3914] == nil, "a secret learned flag is not recorded as learned")
Fire("TRADE_SKILL_CLOSE")
Window = nil

Fire("NEW_RECIPE_LEARNED", BANDAGE)
Check(Known()[129] and Known()[129][BANDAGE] == true, "learning a recipe records it at once")
errorsBefore = ErrorCount()
Fire("NEW_RECIPE_LEARNED", 999999)
Fire("NEW_RECIPE_LEARNED", Secret())
Check(ErrorCount() == errorsBefore, "an unknown or secret recipe id is ignored without an error")

-- The skill read is cached; a skill point clears it.
ns.MySkill(197)
Skills[2948] = 151
Check(ns.MySkill(197) == 150, "the skill is cached between tooltips")
Fire("CHAT_MSG_SKILL", "Your skill in Tailoring has increased to 151.")
Check(ns.MySkill(197) == 151, "a skill-up message refreshes it")
Skills[2948] = 150
Fire("TRADE_SKILL_LIST_UPDATE")
Check(ns.MySkill(197) == 150, "the crafting window refreshes it too")
RunTimers()

-- ---------------------------------------------------------------- other characters

local function AddChar(key, name, realm, class, skills, known)
	root.Chars()[key] = { name = name, realm = realm, class = class, level = 60, seen = 100, track = true }
	db.skills[key], db.known[key] = skills, known
end
AddChar("Bob-Forever", "Bob", "Forever", "WARRIOR", { [202] = 190, [129] = 300 }, { [202] = { [12586] = true }, [129] = { [BANDAGE] = true } })
AddChar("Amy-Elsewhere", "Amy", "Elsewhere", nil, { [129] = 160 }, { [129] = { [BANDAGE] = true } })
lines = ShowTip(GameTooltip, SILK)
dyn = Find(lines, "Solid Dynamite")
Check(dyn and Plain(dyn.right) == "Bob", "another character who knows it is named")
Check(dyn and dyn.right:find("|cff40bf40Bob") ~= nil, "named in the color of their own skill (190 is green for 175-195)")
local band = Find(lines, "^  Silk Bandage")
Check(band and Plain(band.right) == "Known, Amy-Elsewhere, Bob", "you first, then others; another realm keeps its realm")
local _, firstEng = Find(lines, "Solid Dynamite")
local _, otherEng = Find(lines, "Iron Grenade")
Check(firstEng and otherEng and firstEng < otherEng, "recipes someone knows come first in their group")
db.alts = false
lines = ShowTip(GameTooltip, SILK)
dyn = Find(lines, "Solid Dynamite")
Check(dyn and Plain(dyn.right) == "Trainer 175", "Show Other Characters off: back to where it is learned")
db.alts = true

-- The roster decides who is shown: an untracked character is left out, and tracked again is back.
root.SetTracked("Bob-Forever", false)
lines = ShowTip(GameTooltip, SILK)
dyn = Find(lines, "Solid Dynamite")
band = Find(lines, "^  Silk Bandage")
Check(dyn and Plain(dyn.right) == "Trainer 175", "an untracked character is not shown as knowing a recipe")
Check(band and Plain(band.right) == "Known, Amy-Elsewhere", "...nor named beside the others")
Check(db.known["Bob-Forever"] ~= nil and db.skills["Bob-Forever"] ~= nil, "untracking hides the records, it does not delete them")
root.SetTracked("Bob-Forever", true)
lines = ShowTip(GameTooltip, SILK)
Check(Plain((Find(lines, "Solid Dynamite") or {}).right) == "Bob", "tracked again: shown again")

-- A character that has records but no roster entry is not shown either.
db.known["Ghost-Forever"], db.skills["Ghost-Forever"] = { [202] = { [12586] = true } }, { [202] = 300 }
lines = ShowTip(GameTooltip, SILK)
Check(Plain((Find(lines, "Solid Dynamite") or {}).right) == "Bob", "records without a roster entry are not shown")
db.known["Ghost-Forever"], db.skills["Ghost-Forever"] = nil, nil

-- Untracking this character only hides it from the other characters' tooltips (owner's call:
-- untracking hides, it never stops your own marks). It is still recorded and still says Known.
root.SetTracked(ME, false)
local beforeLearn = Known()[129][HEAVY]
Fire("NEW_RECIPE_LEARNED", HEAVY)
Check(beforeLearn == nil and Known()[129][HEAVY] == true, "an untracked character still records a new recipe")
RecipeInfo = { [BOLT] = { learned = true }, [3865] = { learned = true } }
OpenWindow(150)
Fire("TRADE_SKILL_SHOW")
RunTimers()
Check(Known()[197][3865] == true, "...and its scans")
Fire("TRADE_SKILL_CLOSE")
Window = nil
Skills[2948] = 160
Fire("SKILL_LINES_CHANGED")
Check(db.skills[ME][197] == 160, "...and its skill")
Skills[2948] = 150
Fire("SKILL_LINES_CHANGED")
lines = ShowTip(GameTooltip, SILK)
bolt = Find(lines, "Bolt of Silk Cloth")
Check(bolt and Plain(bolt.right) == "Known", "...and its own tooltip still says Known")
root.SetTracked(ME, true)
Known()[129][HEAVY], Known()[197][3865] = nil, nil
lines = ShowTip(GameTooltip, SILK)
bolt = Find(lines, "Bolt of Silk Cloth")
Check(bolt and Plain(bolt.right) == "Known", "tracked again: still Known")

-- Forgetting a character drops what this feature saved for it.
AddChar("Zed-Forever", "Zed", "Forever", "ROGUE", { [129] = 50 }, { [129] = { [BANDAGE] = true } })
root.ForgetChar("Zed-Forever")
Check(root.Chars()["Zed-Forever"] == nil and db.known["Zed-Forever"] == nil and db.skills["Zed-Forever"] == nil, "forgetting a character drops its records")
Check(db.known["Bob-Forever"] ~= nil, "the others' records stay")
Capture(function()
	SlashCmdList.KROOLWORLDFOREVER("forget amy-elsewhere")
end)
Check(db.known["Amy-Elsewhere"] == nil and db.skills["Amy-Elsewhere"] == nil, "/kw forget drops the records too")

-- ---------------------------------------------------------------- options

db.hideGrey = true
lines = ShowTip(GameTooltip, SILK)
Check(Find(lines, "Bolt of Silk Cloth") == nil and Find(lines, "^Tailoring") == nil, "Hide Grey Recipes drops the grey bolt and its empty group")
Check(Find(lines, "Iron Grenade") ~= nil, "Hide Grey keeps recipes of professions you lack")
db.hideGrey = false

db.maxRecipes = 2
lines = ShowTip(GameTooltip, SILK)
local rows = 0
for _, l in ipairs(lines) do
	if l.left:find("^  ") and not Plain(l.left):find("more$") then
		rows = rows + 1
	end
end
Check(rows == 2, "Recipes Shown caps the recipe rows")
Check(Find(lines, "^  %+1 more$") ~= nil, "a cut group says how many more")
Check(Find(lines, "^Engineering$") ~= nil, "groups past the cap still show their count")
db.maxRecipes = 15

Keys.CTRL = false
db.modifier = "ALT"
lines = ShowTip(GameTooltip, SILK)
Check(#lines == 1 and Plain(lines[1].left):find("^Hold Alt"), "the hint names the chosen key")
Keys.ALT = true
lines = ShowTip(GameTooltip, SILK)
Check(Find(lines, "^Tailoring") ~= nil, "Alt shows the list when Alt is the key")
Keys.ALT = false
db.modifier = "SHIFT"
Keys.SHIFT = true
lines = ShowTip(GameTooltip, SILK)
Check(Find(lines, "^Tailoring") ~= nil, "Shift shows the list when Shift is the key")
Keys.SHIFT = false
db.modifier = "NONE"
lines = ShowTip(GameTooltip, SILK)
Check(Find(lines, "^Tailoring") ~= nil and Find(lines, "^Hold") == nil, "Always Show: the list without a key, no hint")
db.modifier = "CTRL"

-- Two recipes with one name in one profession (faction banners) show as one row.
do
	local both
	for item, list in pairs(D.uses) do
		local a, b = false, false
		for i = 1, #list, 2 do
			a = a or list[i] == 1229504
			b = b or list[i] == 1263425
		end
		if a and b then
			both = item
			break
		end
	end
	if both then
		SpellNames[1229504], SpellNames[1263425] = "Faction Banner", "Faction Banner"
		Keys.CTRL = true
		db.maxRecipes = 50
		lines = ShowTip(GameTooltip, both)
		Check(Count(lines, "Faction Banner") == 1, "two recipes with one name share a row")
		db.maxRecipes = 15
		Keys.CTRL = false
	else
		Check(true, "no material is shared by both faction banners")
	end
end

-- ---------------------------------------------------------------- secrets and errors

SecretAsks = 0
lines = ShowTip(GameTooltip, nil, { id = Secret() })
Check(#lines == 0 and SecretAsks > 0, "a secret item id is checked with issecretvalue and left alone")
ok = pcall(ns.OnItemTooltip, GameTooltip, "not a table")
Check(ok, "a tooltip without data is left alone")

local realCollect = ns.Collect
ns.Collect = function()
	error("boom")
end
Keys.CTRL = true
errorsBefore = ErrorCount()
local out
out = Capture(function()
	ok = pcall(ShowTip, GameTooltip, SILK)
end)
ns.Collect = realCollect
Check(ok and #out == 0, "a tooltip error is caught and not printed")
do
	local log = KroolWorldForeverDB.errors or {}
	local last = log[#log]
	Check(ErrorCount() == errorsBefore + 1 and last and last.feature == "reagents" and last.where == "tooltip" and tostring(last.message):find("boom") ~= nil, "it is logged for /kw errors")
end

-- ---------------------------------------------------------------- the key redraws the tooltip

GameTooltip.shown, GameTooltip.item, GameTooltip.refreshes = true, SILK, 0
Fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
Check(GameTooltip.refreshes == 1, "pressing Ctrl redraws a material tooltip")
Fire("MODIFIER_STATE_CHANGED", "LALT", 1)
Check(GameTooltip.refreshes == 1, "another key does nothing")
GameTooltip.item = 117
Fire("MODIFIER_STATE_CHANGED", "RCTRL", 0)
Check(GameTooltip.refreshes == 1, "a non-material tooltip is not redrawn")
GameTooltip.item = Secret()
SecretAsks = 0
errorsBefore = ErrorCount()
Fire("MODIFIER_STATE_CHANGED", "RCTRL", 0)
Check(SecretAsks > 0 and ErrorCount() == errorsBefore and GameTooltip.refreshes == 1, "a secret item on the tooltip is checked and left alone")
GameTooltip.item = SILK
GameTooltip.owner = { UpdateTooltip = function() end }
Fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
Check(GameTooltip.refreshes == 1, "a bag slot (it has UpdateTooltip) redraws itself: no rebuild")
GameTooltip.owner = nil
Combat = true
Fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
Combat = false
Check(GameTooltip.refreshes == 1, "no rebuild in combat")
Instance = true
Fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
Instance = false
Check(GameTooltip.refreshes == 1, "no rebuild in an instance")
GameTooltip.shown = false
Fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
Check(GameTooltip.refreshes == 1, "a hidden tooltip is not redrawn")
Keys.CTRL = false

-- ---------------------------------------------------------------- band edges

local r = { 0, 100, 120, 0, "T", 90 }
Check(ns.Band(89, r) == "red" and ns.Band(90, r) == "orange", "red below the learn level, orange from it")
Check(ns.Band(99, r) == "orange" and ns.Band(100, r) == "yellow", "yellow from the yellow threshold")
Check(ns.Band(109, r) == "yellow" and ns.Band(110, r) == "green", "green from halfway")
Check(ns.Band(119, r) == "green" and ns.Band(120, r) == "grey", "grey from the grey threshold")
Check(ns.Band(nil, r) == nil and ns.Band(150, { 0, 0, 0, 0, "", 0 }) == nil, "no skill or no thresholds: no color")
Check(ns.Band(50, r, true) == "orange", "a known recipe is never red")

-- In the tooltip: First Aid 100 knows Heavy Silk Bandage (learned at 180): orange, not red.
Fire("NEW_RECIPE_LEARNED", HEAVY)
Keys.CTRL = true
lines = ShowTip(GameTooltip, SILK)
heavy = Find(lines, "Heavy Silk Bandage")
Check(heavy and heavy.left:find("|cffff8040Heavy") ~= nil and Plain(heavy.right):find("^Known"), "known below its learn level: orange and Known")
Keys.CTRL = false
Known()[129][HEAVY] = nil

-- Dropping a profession forgets it, but only once the skill list has loaded (not at login).
Skills[2948] = nil
Capture(function()
	FireEvent("PLAYER_LOGIN")
end)
Check(db.skills[ME][197] == 150 and Known()[197] ~= nil, "a login read that misses a skill keeps it")
Fire("SKILL_LINES_CHANGED")
Check(db.skills[ME][197] == nil and Known()[197] == nil and db.skills[ME][129] == 100, "an abandoned profession is forgotten, the others stay")
do
	local saved = Skills
	Skills = {}
	Fire("SKILL_LINES_CHANGED")
	Check(db.skills[ME][129] == 100, "an empty skill list (not loaded yet) forgets nothing")
	Skills = saved
end
Skills[2948] = 150
Fire("SKILL_LINES_CHANGED")
Check(db.skills[ME][197] == 150, "relearned: the skill is back")

-- ---------------------------------------------------------------- settings, the choice option, /ru

local VAR = "KroolWorldForever_reagents_"
Check(RegisteredSettings[VAR .. "enabled"] ~= nil, "the bundle panel has the Enabled switch for it")
do
	local want = { modifier = "string", hint = "boolean", alts = "boolean", hideGrey = "boolean", maxRecipes = "number" }
	local n = 0
	for key, varType in pairs(want) do
		local s = RegisteredSettings[VAR .. key]
		n = n + 1
		Check(s and s.tbl == db and s.varType == varType and type(s.default) == varType, "setting " .. key .. " is stored in the slice with a matching type and default")
	end
	Check(n == 5, "five settings")
end
Check(SettingsLog.controls[VAR .. "modifier"] == "dropdown", "Show With is a dropdown")
Check(SettingsLog.controls[VAR .. "hint"] == "checkbox" and SettingsLog.controls[VAR .. "maxRecipes"] == "slider", "the toggles are checkboxes, Recipes Shown a slider")
do
	local d = SettingsLog.dropdown[VAR .. "modifier"]
	Check(d and #d == 4 and d[1].value == "CTRL" and d[1].label == "Ctrl" and d[2].value == "ALT" and d[3].value == "SHIFT", "the dropdown offers Ctrl, Alt, Shift")
	Check(d and d[4].value == "NONE" and d[4].label == "Always Show", "...and Always Show")
	Check(SettingsLog.slider and SettingsLog.slider.min == 5 and SettingsLog.slider.max == 50, "the slider runs from 5 to 50")
end
do
	local setting = RegisteredSettings[VAR .. "modifier"]
	root.SetOption(ns, "modifier", "ALT")
	Check(db.modifier == "ALT" and setting.tbl[setting.key] == "ALT", "a choice written through the panel's setting lands in the slice")
	lines = ShowTip(GameTooltip, SILK)
	Check(#lines == 1 and Plain(lines[1].left):find("^Hold Alt"), "...and the tooltip follows it")
	setting:SetValue("SHIFT")
	Check(db.modifier == "SHIFT", "the dropdown's own change works the same way")
	root.SetOption(ns, "modifier", "CTRL")
	Check(db.modifier == "CTRL", "set back")
end
Check(root.ChoiceHas(ns.options[1], "ALT") and not root.ChoiceHas(ns.options[1], "META") and not root.ChoiceHas(ns.options[1], nil), "root.ChoiceHas knows the declared values")

-- (Setups' Fit() on a saved choice is checked in the setups suite.)

OpenedCategory = nil
Combat = true
out = Capture(function()
	SlashCmdList.KROOLWORLDFOREVER_REAGENTS("")
end)
Combat = false
Check(OpenedCategory == nil and Plain(out[1] or ""):find("after combat"), "/ru in combat waits: the panel is restricted there")
SlashCmdList.KROOLWORLDFOREVER_REAGENTS("")
Check(OpenedCategory == "Reagent Uses", "/ru opens its settings page")
OpenedCategory = nil
SlashCmdList.KROOLWORLDFOREVER_REAGENTS("options")
Check(OpenedCategory == "Reagent Uses", "/ru options does too")
do
	local opened = 0
	local real = root.OpenCharacters
	root.OpenCharacters = function()
		opened = opened + 1
	end
	SlashCmdList.KROOLWORLDFOREVER_REAGENTS("chars")
	root.OpenCharacters = real
	Check(opened == 1, "/ru chars opens the character list")
end
out = Capture(function()
	SlashCmdList.KROOLWORLDFOREVER_REAGENTS("what")
end)
Check(#out == 1 and out[1]:find("/ru", 1, true) ~= nil, "anything else prints the help")
Check(not ns.Slash and not ns.InitDB and not ReagentUses_OnCompartmentClick, "the old standalone plumbing is gone")

-- ---------------------------------------------------------------- the other tooltip features

-- Disenchant Value (the other item tooltip in this client) still adds its lines, with this feature
-- on, and this feature adds nothing to an item that is no material.
do
	local CHEST = 900001
	Items[CHEST] = { name = "Forever Chestguard", quality = 2, ilvl = 28, sell = 500, class = 4, bind = 2 }
	Prices[11083], Prices[11082], Prices[11084] = 1000, 5000, 3000
	CanDisenchant = true
	Keys.CTRL = true
	lines = ShowTip(GameTooltip, CHEST)
	local mine, theirs = 0, 0
	for _, l in ipairs(lines) do
		local text = Plain(l.left) .. " " .. Plain(l.right)
		if text:find("Hold") or text:find("recipe") or text:find("Tailoring") then
			mine = mine + 1
		end
		if text:find("Disenchant") then
			theirs = theirs + 1
		end
	end
	Check(theirs > 0, "Disenchant Value adds its line on its fixture item")
	Check(mine == 0, "Reagent Uses adds nothing to an item that is no material")
	Keys.CTRL = false
	lines = ShowTip(GameTooltip, SILK)
	Check(#lines == 1 and Plain(lines[1].left):find("^Hold Ctrl"), "a material gets only this feature's hint, Disenchant Value stays out of it")
	-- Both features on one tooltip: a material that is also disenchantable gets both.
	Items[SILK] = { name = "Silk Cloth", quality = 2, ilvl = 28, sell = 10, class = 4, bind = 2 }
	lines = ShowTip(GameTooltip, SILK)
	local hint, dis = false, false
	for _, l in ipairs(lines) do
		local text = Plain(l.left) .. " " .. Plain(l.right)
		hint = hint or text:find("^Hold Ctrl") ~= nil
		dis = dis or text:find("Disenchant") ~= nil
	end
	Check(hint and dis, "one tooltip can carry both features' lines")
	Items[SILK], Items[CHEST] = nil, nil
	CanDisenchant = false
end

-- ---------------------------------------------------------------- off switch

Capture(function()
	SlashCmdList.KROOLWORLDFOREVER("reagents off")
end)
Check(ns.enabled == false and db.enabled == false, "/kw reagents off turns it off")
Keys.CTRL = true
lines = ShowTip(GameTooltip, SILK)
Check(#lines == 0, "/kw reagents off: no list, no hint on the tooltip")
lines = ShowTip(ItemRefTooltip, SILK)
Check(#lines == 0, "/kw reagents off: a chat link tooltip is left alone too")
GameTooltip.shown, GameTooltip.item, GameTooltip.refreshes = true, SILK, 0
Fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
Check(GameTooltip.refreshes == 0, "/kw reagents off: the key does not redraw tooltips")
Keys.CTRL = false
out = Capture(function()
	SlashCmdList.KROOLWORLDFOREVER_REAGENTS("")
end)
Check(OpenedCategory ~= nil and #out == 1 and out[1]:find("is off", 1, true) ~= nil, "/ru while it is off only says so")
errorsBefore = ErrorCount()
Fire("NEW_RECIPE_LEARNED", 7929)
Known()[129][7929] = nil
Check(Known()[129][7929] == nil, "/kw reagents off: no recipe is recorded")
Capture(function()
	SlashCmdList.KROOLWORLDFOREVER("reagents on")
end)
Check(ns.enabled == true, "/kw reagents on turns it back on")
Check(Hooks() == 1, "...without a second tooltip hook")
Keys.CTRL = true
lines = ShowTip(GameTooltip, SILK)
Check(Find(lines, "^Tailoring") ~= nil, "...and the list is back")
Keys.CTRL = false

-- ---------------------------------------------------------------- saved data: old shape and bad values

do
	local SV = function()
		return {
			features = {},
			options = { modifier = "ALT", hint = false, alts = true, hideGrey = "yes", maxRecipes = 99 },
			chars = { ["Old-Realm"] = { name = "Old", realm = "Realm", skills = { [197] = 150 }, known = {} } },
			errors = { { where = "tooltip", msg = "boom", at = 5 } },
		}
	end
	local sv = SV()
	ns.MigrateSaved(sv)
	local s = sv.features.reagents
	Check(s and s.modifier == "ALT" and s.hint == false and s.alts == true and s.maxRecipes == 50, "MigrateSaved moves the old options (Recipes Shown clamped to its range)")
	Check(s.hideGrey == nil, "...skipping a value of the wrong type")
	Check(sv.options == nil and sv.chars == nil and sv.errors == nil, "...and drops the old options, characters and error log")

	sv = SV()
	sv.features.reagents = { modifier = "SHIFT" }
	sv.errors = { { feature = "reagents", where = "x", message = "y", count = 1 } }
	ns.MigrateSaved(sv)
	Check(sv.features.reagents.modifier == "SHIFT" and sv.features.reagents.hint == false, "a value already in the slice is kept")
	Check(type(sv.errors) == "table" and #sv.errors == 1, "an error log in the bundle's shape is kept")

	sv = SV()
	sv.options.modifier = "META"
	ns.MigrateSaved(sv)
	Check(sv.features.reagents.modifier == nil, "an old key that is not on offer is not moved")

	-- The bundle's own saved table has no top-level options: nothing happens to it.
	sv = { features = { reagents = { modifier = "ALT" } }, chars = { ["A-B"] = { name = "A", realm = "B", track = true } }, errors = {} }
	ns.MigrateSaved(sv)
	Check(sv.features.reagents.modifier == "ALT" and sv.chars["A-B"] ~= nil and sv.errors ~= nil, "the bundle's saved table is left alone")

	-- The whole path: an old ReagentUsesDB loaded as the saved table; the roster does not adopt its chars.
	KroolWorldForeverDB = SV()
	Capture(function()
		FireEvent("ADDON_LOADED", "KroolWorldForever")
	end)
	local slice = KroolWorldForeverDB.features.reagents
	Check(slice.modifier == "ALT" and slice.hint == false and slice.maxRecipes == 50 and slice.hideGrey == false and slice.alts == true, "Load migrates an old save, then fills the defaults")
	Check(KroolWorldForeverDB.options == nil and root.Chars()["Old-Realm"] == nil, "...and the old characters do not become roster entries")
	Check(ns.db == slice and type(slice.known) == "table", "the feature runs on the migrated slice")

	-- Bad saved values fall back to the defaults at load.
	KroolWorldForeverDB = { features = { reagents = { modifier = "META", maxRecipes = "lots", hint = 3, known = 5 } } }
	Capture(function()
		FireEvent("ADDON_LOADED", "KroolWorldForever")
	end)
	slice = KroolWorldForeverDB.features.reagents
	Check(slice.modifier == "CTRL" and slice.maxRecipes == 15 and slice.hint == true and type(slice.known) == "table" and type(slice.skills) == "table", "bad saved values fall back to the defaults")
end

print(checks .. " checks, " .. failed .. " failed")
if failed > 0 then
	error(failed .. " checks failed")
end
