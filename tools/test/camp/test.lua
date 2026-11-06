-- Camp Guide behavior checks. Runs after stubs.lua and the whole bundle.

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
local function Lines(tt)
	local all = {}
	for _, l in ipairs(tt.lines) do
		all[#all + 1] = l
	end
	for i, l in ipairs(tt.left) do
		all[#all + 1] = tostring(l) .. " = " .. tostring(tt.right[i])
	end
	return all
end
local function Count(tt)
	return #tt.lines + #tt.left
end

local root = __ns
local ns = root.features.camp
local D = ns.Data

local NEARBY, BENEFITS, BOOSTED = D.NEARBY, D.CAMP_BENEFITS, D.BOOSTED_REST
local function AtCamp(on)
	PlayerAuras[NEARBY] = on and { expirationTime = 0 } or nil
end
local function Reset()
	wipe(PlayerAuras)
	wipe(Buffs)
	AuraErrors = false
	PlayerLevel = 35
	Rested, XPMax = nil, 10000
	ns.Forget()
end

-- ---------------------------------------------------------------- lifecycle

FireEvent("ADDON_LOADED", "KroolWorldForever")
local db = KroolWorldForeverDB.features.camp
check("feature slice created", type(db), "table")
check("on by default", db.enabled, true)
check("object tooltips on by default", db.tooltip, true)
check("Camp Benefits notes on by default", db.benefits, true)
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("enabled after login", ns.enabled, true)
check("object tooltip hooked", has(TooltipChains[Enum.TooltipDataType.Object] or {}, tostring(ns.OnObjectTooltip)), true)
check("aura tooltip hooked", has(TooltipChains[Enum.TooltipDataType.UnitAura] or {}, tostring(ns.OnAuraTooltip)), true)
local hooks = #TooltipChains[Enum.TooltipDataType.Object]
ns.OnEnable()
check("hooked once only", #TooltipChains[Enum.TooltipDataType.Object], hooks)
check("/kwc registered", SLASH_KROOLWORLDFOREVER_CAMP1, "/kwc")
check("hub icon", ns.icon, "Interface\\Icons\\Spell_Fire_Fire")
check("hub blurb", type(ns.blurb), "string")

-- ---------------------------------------------------------------- data

local orderOk, inOrder = true, {}
for _, key in ipairs(D.ORDER) do
	inOrder[key] = true
	orderOk = orderOk and D.BONUSES[key] ~= nil
end
for key in pairs(D.BONUSES) do
	orderOk = orderOk and inOrder[key] == true
end
check("ORDER lists every bonus once", orderOk, true)
local objectsOk = true
for name, obj in pairs(D.OBJECTS) do
	if obj.bonus and not D.BONUSES[obj.bonus] then
		objectsOk = false
		realPrint("  unknown bonus on " .. name)
	end
	if not obj.bonus and not obj.also then
		objectsOk = false
	end
end
check("every object names a real bonus or says what it does", objectsOk, true)
local firstObjects = true
for key, b in pairs(D.BONUSES) do
	firstObjects = firstObjects and D.OBJECTS[b.object] ~= nil and D.OBJECTS[b.object].bonus == key
end
check("each bonus's first object is listed", firstObjects, true)
local bandsOk = true
for _, b in pairs(D.BONUSES) do
	if b.bands then
		bandsOk = bandsOk and b.bands[1][1] == 1
		for i = 2, #b.bands do
			bandsOk = bandsOk and b.bands[i][1] > b.bands[i - 1][1]
		end
	end
	if not b.tent then
		bandsOk = bandsOk and type(b.spell) == "number" and (b.fixed ~= nil or b.bands ~= nil) and #b.notWith > 0
	end
end
check("bands start at 1 and rise; every buff has a spell and a class buff", bandsOk, true)

-- ---------------------------------------------------------------- values

local lode = D.BONUSES.lodestone.bands
check("Lodestone at 11: 12", ns.Band(lode, 11)[2], 12)
check("Lodestone at 12: 20", ns.Band(lode, 12)[2], 20)
check("Lodestone at 35: 49", ns.Band(lode, 35)[2], 49)
check("Lodestone at 52: 90", ns.Band(lode, 52)[2], 90)
check("Lodestone at 60: 90", ns.Band(lode, 60)[2], 90)
check("Lodestone at 1: 12", ns.Band(lode, 1)[2], 12)
check("no level: the top band", ns.Band(lode, nil)[2], 90)
check("Lodestone text", ns.BonusText("lodestone", 35), "+49 melee attack power")
check("text without a level says up to", ns.BonusText("lodestone", nil), "up to +90 melee attack power")
check("First Aid Kit at 59", ns.BonusText("kit", 59), "+45 Stamina")
check("First Aid Kit at 60", ns.BonusText("kit", 60), "+56 Stamina")
check("Mana Well at 54", ns.BonusText("well", 54), "+29 mana every 5 seconds")
check("Lute at 5: armor only", ns.BonusText("lute", 5), "+28 armor")
check("Lute at 15: armor and stats", ns.BonusText("lute", 15), "+71 armor, +2 all stats")
check("Lute at 60: all three", ns.BonusText("lute", 60), "+308 armor, +13 all stats, +22 all resistances")
check("Faction Banner says own faction", ns.BonusText("banner", 50), "+27 Spirit, your faction only")
check("Fish Bowl is the same at every level", ns.BonusText("bowl", 10), "+8% all stats")
check("Camp Chair", ns.BonusText("chair", 10), "+2% critical strike, attacks and spells")
check("Camp Tent", ns.BonusText("tent", 10), "Rested experience, up to 5% of a level")

-- ---------------------------------------------------------------- object tooltips

Reset()
local tt = ShowObject("Lodestone")
check("away from a campfire: nothing", Count(tt), 0)

AtCamp(true)
tt = ShowObject("Lodestone")
check("Lodestone: its buff at your level", has(tt.lines, "Camp:|r +49 melee attack power"), true)
check("Lodestone: which class buff it does not stack with", has(tt.lines, "Does not stack with Blessing of Might"), true)
check("Lodestone: not in your Camp Benefits yet", has(tt.lines, "In your Camp Benefits"), false)

Buffs["Blessing of Might"] = {}
tt = ShowObject("Lodestone")
check("with Blessing of Might: says you have it", has(tt.lines, "Does not stack with your Blessing of Might"), true)
Buffs["Blessing of Might"] = nil
Buffs["Greater Blessing of Might"] = {}
tt = ShowObject("Lodestone")
check("the greater blessing counts too", has(tt.lines, "your Greater Blessing of Might"), true)
Buffs["Greater Blessing of Might"] = nil
Buffs["Blessing of Might"] = Secret()
tt = ShowObject("Lodestone")
check("a secret aura is not read as yours", has(tt.lines, "your Blessing of Might"), false)
Buffs["Blessing of Might"] = nil

PlayerAuras[D.BONUSES.lodestone.spell] = { expirationTime = Clock + 600 }
tt = ShowObject("Lodestone")
check("Lodestone: in your Camp Benefits", has(tt.lines, "In your Camp Benefits now"), true)
PlayerAuras[D.BONUSES.lodestone.spell] = nil

tt = ShowObject("Rock Garden")
check("Rock Garden keeps the Lodestone's buff", has(tt.lines, "+49 melee attack power"), true)
check("Rock Garden: and what else it does", has(tt.lines, "mining node"), true)

tt = ShowObject("Chair")
check("Chair: crit", has(tt.lines, "+2% critical strike"), true)
check("Chair: both class buffs named", has(tt.lines, "Moonkin Aura or Leader of the Pack"), true)
check("Chair: you can sit on it", has(tt.lines, "You can sit on it"), true)
Buffs["Leader of the Pack"] = {}
tt = ShowObject("Camp Chair")
check("Camp Chair with Leader of the Pack", has(tt.lines, "your Leader of the Pack"), true)
Buffs["Leader of the Pack"] = nil

tt = ShowObject("|cffffffffLodestone|r")
check("a coloured name is still known", has(tt.lines, "+49 melee attack power"), true)
tt = ShowObject("Mailbox")
check("other objects: nothing", Count(tt), 0)
tt = ShowObject(Secret())
check("a secret name: nothing", Count(tt), 0)
tt = ShowObject("Repair Bot")
check("a service object says what it does", has(tt.lines, "repairs"), true)
check("a service object has no buff line", has(tt.lines, "Camp:|r"), false)

PlayerLevel = 60
tt = ShowObject("First Aid Kit")
check("level 60 value", has(tt.lines, "+56 Stamina"), true)
PlayerLevel = Secret()
tt = ShowObject("First Aid Kit")
check("a secret level shows the top value", has(tt.lines, "up to +56 Stamina"), true)
PlayerLevel = 35

-- The tent
tt = ShowObject("Camp Tent")
check("tent: rested experience", has(tt.lines, "Rested experience"), true)
check("tent: no class buff line", has(tt.lines, "Does not stack"), false)
check("tent with no rested XP: no warning", #tt.lines, 1)
Rested = 600
tt = ShowObject("Tent")
check("tent with 6% rested: adds none", has(tt.lines, "already have 5% of a level rested"), true)
Rested = 100
tt = ShowObject("Tent")
check("tent with 1% rested: no warning", has(tt.lines, "already have"), false)
PlayerAuras[BOOSTED] = { expirationTime = Clock + 20 * 60 }
tt = ShowObject("Tanning Rack")
check("Boosted Rest: no more for its time", has(tt.lines, "You have Boosted Rest: no more from a tent for 20 min"), true)
check("Tanning Rack: and its workstation", has(tt.lines, "Leatherworking materials"), true)
PlayerAuras[BOOSTED] = nil
Rested = nil

-- ---------------------------------------------------------------- the campfire

Reset()
AtCamp(true)
tt = ShowObject("Basic Campfire")
check("fire: slots", has(tt.lines, "holds 3 camp objects"), true)
check("fire: how the buffs come", has(tt.lines, "Sit near it for 1 minute"), true)
check("fire: objects placed later", has(tt.lines, "count when you sit again"), true)
check("fire: nothing hovered yet", has(tt.lines, "Hover the objects around it"), true)
check("fire: no Camp Benefits line without it", has(tt.lines, "Your Camp Benefits"), false)

ShowObject("Lodestone")
ShowObject("Chair")
ShowObject("Reagent Bot")
Buffs["Blessing of Might"] = {}
tt = ShowObject("Expert Campfire")
local all = Lines(tt)
check("fire: Expert holds 10", has(tt.lines, "holds 10 camp objects"), true)
check("fire: lists what was hovered", has(tt.lines, "objects you have hovered here"), true)
check("fire: the Lodestone with its value", has(all, "  Lodestone = +49 melee attack power"), true)
check("fire: and the clash with your blessing", has(all, "(not with your Blessing of Might)"), true)
check("fire: the chair as the world names it", has(all, "  Chair = +2% critical strike"), true)
check("fire: a service object by what it does", has(all, "  Reagent Bot = "), true)
check("fire: three objects", #tt.left, 3)
check("fire: listed by name", tostring(tt.left[1]), "  Chair")
Buffs["Blessing of Might"] = nil

ShowObject("Rock Garden")
tt = ShowObject("Basic Campfire")
check("fire: one entry per buff (the Rock Garden replaced the Lodestone)", #tt.left, 3)
check("fire: under its new name", has(Lines(tt), "  Rock Garden = +49"), true)

tt = ShowObject("Campfire")
check("fire: the plain name has no slot count", has(tt.lines, "holds"), false)
check("fire: but explains itself", has(tt.lines, "Sit near it"), true)

PlayerAuras[BENEFITS] = { expirationTime = Clock + 43 * 60 }
tt = ShowObject("Basic Campfire")
check("fire: your Camp Benefits time", has(tt.lines, "Your Camp Benefits: 43 min left"), true)
PlayerAuras[BENEFITS] = nil

Clock = Clock + 16 * 60
tt = ShowObject("Basic Campfire")
check("fire: an old visit is forgotten", has(tt.lines, "Hover the objects around it"), true)

ShowObject("Lodestone")
AtCamp(false)
tt = ShowObject("Lodestone")
check("away from the camp: nothing", Count(tt), 0)
AtCamp(true)
tt = ShowObject("Basic Campfire")
check("leaving the camp forgets it", has(tt.lines, "Hover the objects around it"), true)

-- ---------------------------------------------------------------- the Camp Benefits buff

Reset()
AtCamp(true)
Buffs["Blessing of Might"] = {}
tt = ShowAura(BENEFITS, { "Gained the following camp benefits:", "Lodestone: +49 Melee Attack Power" })
check("Camp Benefits: the clash, read from its lines", has(tt.lines, "Lodestone: does not stack with your Blessing of Might"), true)
Buffs["Blessing of Might"] = nil
tt = ShowAura(BENEFITS, { "Lodestone: +49 Melee Attack Power" })
check("Camp Benefits: no clash says so", has(tt.lines, "None of these overlap a class buff you have"), true)
PlayerAuras[D.BONUSES.chair.spell] = { expirationTime = Clock + 600 }
Buffs["Moonkin Aura"] = {}
tt = ShowAura(BENEFITS, {})
check("Camp Benefits: a bonus found by its own aura", has(tt.lines, "Camp Chair: does not stack with your Moonkin Aura"), true)
Buffs["Moonkin Aura"] = nil
PlayerAuras[D.BONUSES.chair.spell] = nil
tt = ShowAura(BENEFITS, { "Something new: +3 Luck" })
check("Camp Benefits: nothing known, nothing added", Count(tt), 0)
tt = ShowAura(12345, { "Lodestone: +49 Melee Attack Power" })
check("other buffs: nothing", Count(tt), 0)
tt = ShowAura(Secret(), { "Lodestone: +49 Melee Attack Power" })
check("a secret aura id: nothing", Count(tt), 0)

-- ---------------------------------------------------------------- options, errors, other tooltips

Reset()
AtCamp(true)
tt = ShowObject("Lodestone", ItemRefTooltip)
check("only the game tooltip", Count(GameTooltip), 0)
root.SetOption(ns, "tooltip", false)
tt = ShowObject("Lodestone")
check("Show On Camp Objects off", Count(tt), 0)
root.SetOption(ns, "tooltip", true)
root.SetOption(ns, "benefits", false)
Buffs["Blessing of Might"] = {}
tt = ShowAura(BENEFITS, { "Lodestone: +49 Melee Attack Power" })
check("Notes On Camp Benefits off", Count(tt), 0)
root.SetOption(ns, "benefits", true)
Buffs["Blessing of Might"] = nil

AuraErrors = true
local ok = pcall(ShowObject, "Lodestone")
check("aura errors stay inside", ok, true)
ok = pcall(ShowAura, BENEFITS, { "Lodestone: +49" })
check("aura errors stay inside the buff tooltip", ok, true)
AuraErrors = false
local realLevel = UnitLevel
UnitLevel = function()
	error("level failed")
end
tt = ShowObject("Lodestone")
check("a failing level shows the top value", has(tt.lines, "up to +90"), true)
UnitLevel = realLevel
ok = pcall(ShowObject, "Lodestone", nil, Enum.TooltipDataType.Item)
check("camp names on item tooltips do not trip other features", ok, true)

-- ---------------------------------------------------------------- slash and hub

Reset()
local out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_CAMP("")
end)
check("/kwc: the level", has(out, "camp buffs at level 35"), true)
check("/kwc: each object with its profession", has(out, "Lodestone |cffaaaaaa(Mining)|r: +49 melee attack power"), true)
check("/kwc: ten objects and a status", #out, 12)
check("/kwc: status", has(out, "No camp buffs"), true)
Buffs["Blessing of Might"] = {}
PlayerAuras[D.BONUSES.kit.spell] = { expirationTime = Clock + 600 }
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_CAMP("")
end)
check("/kwc: the clash", has(out, "(not with your Blessing of Might)"), true)
check("/kwc: what you have now", has(out, "First Aid Kit |cffaaaaaa(First Aid)|r: +21 Stamina |cff33ff99(yours now)"), true)
Reset()
OpenedCategory = nil
capture(function()
	SlashCmdList.KROOLWORLDFOREVER_CAMP("options")
end)
check("/kwc options opens settings", OpenedCategory, "Camp Guide")
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_CAMP("help")
end)
check("/kwc help", has(out, "/kwc options"), true)

check("hub: nothing", ns.HubStatus():find("No camp buffs", 1, true) ~= nil, true)
AtCamp(true)
check("hub: a campfire nearby", ns.HubStatus():find("campfire is nearby", 1, true) ~= nil, true)
PlayerAuras[D.WELCOMING[2]] = { expirationTime = Clock + 40 }
check("hub: sitting", ns.HubStatus():find("Sitting by a campfire", 1, true) ~= nil, true)
PlayerAuras[BENEFITS] = { expirationTime = Clock + 43 * 60 }
check("hub: Camp Benefits time", ns.HubStatus():find("Camp Benefits: 43 min left", 1, true) ~= nil, true)
PlayerAuras[BENEFITS] = { expirationTime = 0 }
check("hub: Camp Benefits without a time", ns.HubStatus():find("Camp Benefits: on", 1, true) ~= nil, true)

Reset()
AtCamp(true)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("camp off")
end)
check("/kw camp off", ns.enabled, false)
tt = ShowObject("Lodestone")
check("off: no object lines", Count(tt), 0)
Buffs["Blessing of Might"] = {}
tt = ShowAura(BENEFITS, { "Lodestone: +49" })
check("off: no Camp Benefits lines", Count(tt), 0)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("camp on")
end)
check("/kw camp on", ns.enabled, true)
tt = ShowObject("Lodestone")
check("on again: lines back", has(tt.lines, "+49 melee attack power"), true)

realPrint(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
