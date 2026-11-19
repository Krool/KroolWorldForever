-- Reagent Uses: hold a key over a crafting material and its tooltip lists every recipe that uses it.
-- This file: the options, the player's profession skills and the recipes each character knows.
-- Tooltip.lua draws the tooltip. Data.lua is generated (tools/reagents-data/gen-data.js).
--
-- Saved in the feature's slice (ns.db), next to its options:
--   known  = { ["Name-Realm"] = { [line] = { [recipe] = true } } }
--   skills = { ["Name-Realm"] = { [line] = rank } }
-- keyed like the character roster (root.CharKey, Core/Characters.lua). A character's recipes are read
-- when it opens its own profession window, and when it learns one (NEW_RECIPE_LEARNED). Only tracked
-- characters are recorded or shown; forgetting one drops its records. Nothing is ever sent anywhere;
-- the feature only reads and draws tooltip lines.

local _, root = ...
local ns = root.Feature("reagents")

ns.title = "Reagent Uses"
ns.description = "Hold a key over a crafting material and its tooltip lists every recipe that uses it, grouped by profession and colored by your skill, with who knows each one or where it is learned."
ns.icon = "Interface\\Icons\\INV_Fabric_Silk_01"
ns.blurb = "Hold a key over a material to see its recipes"
ns.slash = { "/ru", "/reagentuses" }

ns.MODIFIERS = {
	{ value = "CTRL", label = "Ctrl" },
	{ value = "ALT", label = "Alt" },
	{ value = "SHIFT", label = "Shift" },
	{ value = "NONE", label = "Always Show" },
}

ns.options = {
	{
		key = "modifier",
		type = "choice",
		label = "Show With",
		tooltip = "The key to hold over a crafting material to list the recipes that use it. Always Show lists them on every material's tooltip.",
		default = "CTRL",
		choices = ns.MODIFIERS,
	},
	{
		key = "hint",
		type = "toggle",
		label = "Show Hint",
		tooltip = "While the key is up, one line on the tooltip says how many recipes use the material.",
		default = true,
	},
	{
		key = "alts",
		type = "toggle",
		label = "Show Other Characters",
		tooltip = "Names your other tracked characters who know each recipe. A character is remembered after it opens its own profession window with this on.",
		default = true,
	},
	{
		key = "hideGrey",
		type = "toggle",
		label = "Hide Grey Recipes",
		tooltip = "Leaves out recipes that can no longer give you a skill point.",
		default = false,
	},
	{
		key = "maxRecipes",
		type = "range",
		label = "Recipes Shown",
		tooltip = "How many recipes the tooltip lists. Past that, each profession only shows its count.",
		default = 15,
		min = 5,
		max = 50,
		step = 1,
	},
}

local SCAN_DELAY = 0.3

-- ------------------------------------------------------------------ helpers

local issecret = issecretvalue

-- Secret values (Midnight-era restriction) may not be compared, tested or indexed: check first.
function ns.Secret(v)
	return issecret ~= nil and issecret(v) == true
end
local Secret = ns.Secret

function ns.Num(v)
	if Secret(v) or type(v) ~= "number" then
		return nil
	end
	return v
end
local Num = ns.Num

function ns.Str(v)
	if Secret(v) or type(v) ~= "string" or v == "" then
		return nil
	end
	return v
end

-- Calls an API that may be missing or may error; the first two results, or nil.
function ns.Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b = pcall(fn, ...)
	if ok then
		return a, b
	end
	return nil
end
local Call = ns.Call

-- ------------------------------------------------------------------ saved data

local function Table(parent, key)
	if type(parent[key]) ~= "table" then
		parent[key] = {}
	end
	return parent[key]
end

-- Old standalone saves (ReagentUsesDB) kept { options = {...}, chars = {...}, errors = {...} } at the
-- top. Called before the roster and the slices read the saved table: carries the recognizable options
-- over (never over one already set here), then drops the old top-level tables. Recipe records are not
-- carried; each character writes them again when it opens its profession window. The bundle's own
-- saved table has no top-level `options`, so there this finds nothing.
function ns.MigrateSaved(sv)
	local old = sv.options
	if type(old) ~= "table" then
		return
	end
	local slice = Table(sv.features, "reagents")
	for _, opt in ipairs(ns.options) do
		local v = old[opt.key]
		local fits = false
		if opt.type == "choice" then
			fits = root.ChoiceHas(opt, v)
		elseif opt.type == "toggle" then
			fits = type(v) == "boolean"
		elseif opt.type == "range" then
			fits = type(v) == "number" and v == v
			v = fits and math.min(opt.max, math.max(opt.min, math.floor(v))) or nil
		end
		if fits and slice[opt.key] == nil then
			slice[opt.key] = v
		end
	end
	sv.options, sv.chars = nil, nil
	-- Core/Registry.lua logs { feature, where, message, count, ... }; the old log was { where, msg, at }.
	if type(sv.errors) == "table" then
		for _, e in ipairs(sv.errors) do
			if type(e) ~= "table" or type(e.feature) ~= "string" or type(e.message) ~= "string" then
				sv.errors = nil
				break
			end
		end
	end
end

function ns.OnLoad()
	local db = ns.db
	for _, opt in ipairs(ns.options) do
		if opt.type ~= "choice" and type(db[opt.key]) ~= type(opt.default) then
			db[opt.key] = opt.default
		end
	end
	Table(db, "known")
	Table(db, "skills")
	if not ns.forgetHooked then
		ns.forgetHooked = true -- OnLoad can run again (tests); one listener is enough
		root.OnForgetChar(function(key)
			ns.db.known[key], ns.db.skills[key] = nil, nil
		end)
	end
end

-- "Name-Realm" of the logged-in character, or nil while the client does not say who that is.
function ns.MyKey()
	local key = root.CharKey()
	return key:sub(1, 2) ~= "?-" and key or nil
end

-- The key to record this character under: nil until it is on the roster. An untracked character
-- is still recorded (untracking hides it from the other characters' tooltips, it never stops your
-- own "Known" marks).
function ns.Recording()
	local key = ns.MyKey()
	if key and root.Chars()[key] then
		return key
	end
	return nil
end

-- A character's saved skills and known recipes (created on first use).
local function Skills(key)
	return Table(ns.db.skills, key)
end
local function Known(key)
	return Table(ns.db.known, key)
end

-- This character's known recipes as the tooltip reads them, tracked or not.
function ns.MyRecords()
	local key = ns.MyKey()
	if key then
		local known = ns.db.known[key]
		return type(known) == "table" and known or nil
	end
	return nil
end

-- ------------------------------------------------------------------ skills

local function RankOf(id)
	local S = C_SkillInfo
	local info = S and Call(S.GetSkillLineInfoByID, id)
	if type(info) ~= "table" then
		return nil
	end
	local rank = Num(info.rank)
	return rank and rank > 0 and rank or nil
end

local function LevelOf(info)
	if type(info) ~= "table" then
		return nil
	end
	local lvl = Num(info.skillLevel)
	return lvl and lvl > 0 and lvl or nil
end

-- The player's skill in a profession (its base skill line), or nil without the profession. Forever
-- keeps the skill on a child line ("Classic Tailoring"); both are asked and the higher wins.
function ns.ReadSkill(line)
	local d = ns.Data.lines[line]
	local child = d and d[2] or 0
	local best
	local function Take(r)
		if r and (not best or r > best) then
			best = r
		end
	end
	Take(RankOf(line))
	if child > 0 then
		Take(RankOf(child))
		local T = C_TradeSkillUI
		if T then
			Take(LevelOf(Call(T.GetProfessionInfoBySkillLineID, child)))
		end
	end
	return best
end

local skillCache = {}

-- ReadSkill, remembered until the skills change.
function ns.MySkill(line)
	local v = skillCache[line]
	if v == nil then
		v = ns.ReadSkill(line) or false
		skillCache[line] = v
	end
	return v or nil
end

function ns.ForgetSkillCache()
	for k in pairs(skillCache) do
		skillCache[k] = nil
	end
end

-- Re-reads every profession skill into this character's record, so other characters see it. With
-- prune (on SKILL_LINES_CHANGED, once the skill list has loaded), a profession that no longer reads
-- was abandoned: its skill and known recipes go too.
function ns.RefreshSkills(prune)
	ns.ForgetSkillCache()
	local key = ns.Recording()
	if not key then
		return
	end
	local skills, known = Skills(key), Known(key)
	local S = C_SkillInfo
	local loaded = Num(S and Call(S.GetNumSkillLines))
	prune = prune and loaded and loaded > 0
	for line in pairs(ns.Data.lines) do
		local r = ns.MySkill(line)
		if r then
			skills[line] = r
		elseif prune then
			skills[line] = nil
			known[line] = nil
		end
	end
end

-- ------------------------------------------------------------------ known recipes

local byLine -- line -> { recipe ids }, built on first use

function ns.RecipesOf(line)
	if not byLine then
		byLine = {}
		for id, r in pairs(ns.Data.recipes) do
			local l = r[1]
			byLine[l] = byLine[l] or {}
			table.insert(byLine[l], id)
		end
	end
	return byLine[line] or {}
end

-- The profession the crafting window shows, as a base line in the data; plus the window's skill.
function ns.OpenLine()
	local T = C_TradeSkillUI
	if not T then
		return nil
	end
	local base, child = Call(T.GetBaseProfessionInfo), Call(T.GetChildProfessionInfo)
	local bid = type(base) == "table" and Num(base.professionID) or nil
	local cid = type(child) == "table" and Num(child.professionID) or nil
	local shown = LevelOf(child) or LevelOf(base)
	if bid and ns.Data.lines[bid] then
		return bid, shown
	end
	for line, d in pairs(ns.Data.lines) do
		if (cid and (d[2] == cid or line == cid)) or (bid and d[2] == bid) then
			return line, shown
		end
	end
	return nil
end

-- True when the window shows the player's own profession: not a chat link, a guild view or an NPC.
-- Blizzard's Professions.InLocalCraftingMode (Blizzard_ProfessionsTemplates, loaded with the window)
-- checks NPC, guild, guild member and linked views; without it nothing is recorded.
local function LocalCrafting(line, shown)
	local T = C_TradeSkillUI
	if T and Call(T.IsNPCCrafting) == true then
		return false
	end
	local P = Professions
	if not (type(P) == "table" and type(P.InLocalCraftingMode) == "function") then
		return false
	end
	local ok, isLocal = pcall(P.InLocalCraftingMode)
	if not ok or Secret(isLocal) or isLocal ~= true then
		return false
	end
	local mine = ns.ReadSkill(line)
	if not mine then
		return false -- someone else's profession: this character does not have it
	end
	return shown == nil or shown == mine
end

-- Records which recipes of the open profession this character knows.
function ns.ScanOpen()
	local T = C_TradeSkillUI
	local key = ns.Recording()
	if not (T and key and ns.enabled and ns.windowOpen) then
		return -- a scan that fires after the window closed reads nothing trustworthy
	end
	ns.ForgetSkillCache()
	local line, shown = ns.OpenLine()
	if not line or not LocalCrafting(line, shown) then
		return
	end
	local set, answered, count = {}, 0, 0
	for _, id in ipairs(ns.RecipesOf(line)) do
		local info = Call(T.GetRecipeInfo, id)
		if type(info) == "table" then
			answered = answered + 1
			local learned = info.learned
			if not Secret(learned) and learned == true then
				set[id] = true
				count = count + 1
			end
		end
	end
	if answered == 0 then
		return -- the list has not loaded yet; keep what we had
	end
	local known = Known(key)
	local had = known[line]
	if count == 0 and type(had) == "table" and next(had) then
		return -- every profession starts with recipes: an all-unlearned answer is a bad read
	end
	known[line] = set
	Skills(key)[line] = ns.ReadSkill(line)
	ns.lastScan = { line = line, known = count, answered = answered }
end

local scanPending = false
function ns.QueueScan()
	if scanPending then
		return
	end
	scanPending = true
	local after = C_Timer and C_Timer.After
	local function Run()
		scanPending = false
		root.Try(ns, "scan", ns.ScanOpen)
	end
	if after then
		after(SCAN_DELAY, Run)
	else
		Run()
	end
end

function ns.OnRecipeLearned(id)
	id = Num(id)
	local r = id and ns.Data.recipes[id]
	local key = ns.Recording()
	if not (r and key) then
		return
	end
	local line = r[1]
	local known = Known(key)
	known[line] = type(known[line]) == "table" and known[line] or {}
	known[line][id] = true
end

-- The other tracked characters with records here, built once per tooltip:
-- { { key, name, realm, class, known, skills }, ... }, sorted by name.
function ns.OtherChars()
	local list, me = {}, ns.MyKey()
	for key, rec in pairs(root.Chars()) do
		if key ~= me and root.Tracked(key) then
			local known, skills = ns.db.known[key], ns.db.skills[key]
			if type(known) == "table" or type(skills) == "table" then
				list[#list + 1] = {
					key = key,
					name = rec.name or key,
					realm = rec.realm,
					class = rec.class,
					known = type(known) == "table" and known or {},
					skills = type(skills) == "table" and skills or {},
				}
			end
		end
	end
	table.sort(list, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.key < b.key
	end)
	return list
end

-- Others (from OtherChars) who know a recipe: { { name, realm, class, rank }, ... } or nil.
function ns.AltsKnowing(others, line, id)
	local list
	for _, c in ipairs(others) do
		local set = c.known[line]
		if type(set) == "table" and set[id] then
			list = list or {}
			list[#list + 1] = { name = c.name, realm = c.realm, class = c.class, rank = c.skills[line] }
		end
	end
	return list
end

-- True when one of the others has this profession (or knows any of its recipes).
function ns.AltHasLine(others, line)
	for _, c in ipairs(others) do
		if c.skills[line] or c.known[line] then
			return true
		end
	end
	return false
end

-- ------------------------------------------------------------------ events

ns:RegisterEvent("SKILL_LINES_CHANGED", function()
	ns.RefreshSkills(true)
end)

-- A skill point; the skill lines event may not come for every point.
ns:RegisterEvent("CHAT_MSG_SKILL", function()
	ns.ForgetSkillCache()
end)

ns:RegisterEvent("TRADE_SKILL_SHOW", function()
	ns.windowOpen = true
	ns.QueueScan()
end)

ns:RegisterEvent("TRADE_SKILL_LIST_UPDATE", function()
	ns.ForgetSkillCache()
	ns.QueueScan()
end)

ns:RegisterEvent("TRADE_SKILL_CLOSE", function()
	ns.windowOpen = false
end)

ns:RegisterEvent("NEW_RECIPE_LEARNED", function(_, id)
	ns.OnRecipeLearned(id)
end)

ns:RegisterEvent("MODIFIER_STATE_CHANGED", function(_, key, down)
	root.TryQuiet(ns, "modifier", ns.OnModifier, key, down)
end)

-- The first read of this character's skills (the roster has noted the character by now), and the
-- tooltip hook. Also runs when the feature is switched on in the middle of a session.
function ns.OnEnable()
	ns.RefreshSkills(false)
	ns.HookTooltips()
end

function ns.OnDisable()
	ns.windowOpen = false
end

-- ------------------------------------------------------------------ slash, hub

function ns.OnSlash(msg)
	msg = type(msg) == "string" and strtrim(msg):lower() or ""
	if msg == "" or msg == "options" or msg == "settings" then
		-- Opening the panel is restricted in combat (C_SettingsUtil.OpenSettingsPanel, HasRestrictions).
		if InCombatLockdown and InCombatLockdown() then
			ns:Print("the settings open after combat.")
			return
		end
		root.OpenSettings(ns)
	elseif msg == "chars" or msg == "characters" then
		root.OpenCharacters()
	else
		ns:Print(("/ru opens the settings; /ru chars lists your characters (%s track, untrack and forget)."):format(root.cmd or "/ru"))
	end
end

-- Your best profession and its skill, else what the key does.
function ns.HubStatus()
	local bestLine, best
	for line in pairs(ns.Data.lines) do
		local r = ns.MySkill(line)
		if r and (not best or r > best) then
			bestLine, best = line, r
		end
	end
	if bestLine then
		return ns.LineName(bestLine) .. " " .. best
	end
	local want = ns.db and ns.db.modifier
	for _, c in ipairs(ns.MODIFIERS) do
		if c.value == want and want ~= "NONE" then
			return "Hold " .. c.label .. " over a material"
		end
	end
	return "On every material's tooltip"
end
