-- Rare Alert behavior checks. Runs after stubs.lua and the whole bundle.

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
local Printed = {}
local function capture(fn)
	Printed = {}
	print = function(...)
		local t = {}
		for i = 1, select("#", ...) do
			t[#t + 1] = tostring((select(i, ...)))
		end
		Printed[#Printed + 1] = table.concat(t, " ")
	end
	local ok, err = pcall(fn)
	print = realPrint
	if not ok then
		error(err)
	end
	return Printed
end

local ns = __ns.features.rares
local SV = "KroolWorldForever_rares_"
local function G(id, spawn)
	return "Creature-0-4170-0-12-" .. id .. "-" .. (spawn or "00ABCDEF12")
end
local function Rare(token, id, name, extra)
	local u = { guid = G(id), name = name, level = 30, class = "rare" }
	for k, v in pairs(extra or {}) do
		u[k] = v
	end
	Units[token] = u
	return u
end
local function Button()
	return _G.KroolWorldForeverRareButton
end
local function reset()
	Units, Sounds, ScreenMessages, RanMacros, BlockedCalls = {}, {}, {}, {}, {}
	InCombat, InInstance, BoundKey = false, false, nil
	Clock = Clock + 1000 -- past every alert cooldown and button timeout
	RunTimers()
end

-- ---------------------------------------------------------------- lifecycle

FireEvent("ADDON_LOADED", "KroolWorldForever")
local db = KroolWorldForeverDB.features.rares
check("feature slice created", type(db), "table")
check("on by default", db.enabled, true)
check("skull by default", db.marker, 8)
check("Sewer Beast ignored out of the box", db.ignore[3581], "Sewer Beast")
local loginOut = capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("enabled after login", ns.enabled, true)
check("login tip when enemy nameplates are off", has(loginOut, "enemy nameplates are off"), true)
check("tip remembered", db.plateTip, true)
check("no button before a rare shows up", Button(), nil)
check("/kwr registered", SLASH_KROOLWORLDFOREVER_RARES1, "/kwr")
check("key binding named", _G["BINDING_NAME_CLICK KroolWorldForeverRareButton:LeftButton"], "Target And Mark Rare")
check("binding header", BINDING_HEADER_KROOLWORLDFOREVER, "Krool World")
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED" }) do
	local found = false
	for _, f in ipairs(CreatedFrames) do
		found = found or f.events[e] == true
	end
	check("registered for " .. e, found, true)
end
check("guid parse", ns.NpcId(G(462)), 462)
check("guid parse: player", ns.NpcId("Player-4170-0001ABCD"), nil)

-- ---------------------------------------------------------------- nameplates

check("plates off: read", ns.EnemyPlatesOn(), false)
check("plates off: hub warns", ns.HubStatus():find("Enemy nameplates are off", 1, true) ~= nil, true)
check("plates off: hub offers the fix", ns.HubAction() and ns.HubAction().label, "Plates On")
check("settings page has the button", SettingsButtons["Turn On Enemy Nameplates"] ~= nil, true)
InCombat = true
local out = capture(function()
	ns.OnSlash("nameplates")
end)
check("in combat: refuses", has(out, "leave combat first"), true)
check("in combat: unchanged", CVars.nameplateShowEnemies, "0")
InCombat = false
out = capture(function()
	SettingsButtons["Turn On Enemy Nameplates"].onClick()
end)
check("the settings button turns enemy plates on", CVars.nameplateShowEnemies, "1")
check("and asks for the longest range", CVars.nameplateMaxDistance, "60")
check("says the range the client kept", has(out, "range 60 yards"), true)
check("plates on: no fix offered", ns.HubAction(), nil)
check("plates on: no warning", ns.HubStatus():find("nameplates", 1, true), nil)
CVars.nameplateShowEnemies = "0"
capture(function()
	ns.OnSlash("plates")
end)
check("/kwr nameplates does the same", CVars.nameplateShowEnemies, "1")
local savedCVar = C_CVar
C_CVar = nil
check("no CVar API: unknown, no warning", ns.EnemyPlatesOn(), nil)
C_CVar = savedCVar

-- ---------------------------------------------------------------- a rare on a nameplate

reset()
Rare("nameplate3", 462, "Vultros")
out = capture(function()
	FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate3")
end)
check("chat line names the rare", has(out, "Vultros (30)"), true)
check("chat says how to mark it", has(out, "click the skull"), true)
check("chat says what it is worth (Kill Value's numbers)", has(out, "worth about"), true)
check("raid warning sound", Sounds[1], 8959)
check("screen message", ScreenMessages[1], "Rare: Vultros (30)")
local b = Button()
check("button built on the first sighting", b ~= nil, true)
check("secure button", b.template, "SecureActionButtonTemplate")
check("button shown", b.shown, true)
check("button names the rare", b.label.text, "Vultros")
check("left click runs a macro", b.attrs.type1, "macro")
check("macro targets it and marks it with the skull", b.attrs.macrotext1, "/cleartarget\n/targetexact Vultros\n/tm [exists] !8")
check("skull icon", b.icon.texture, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
b:Click("LeftButton")
check("a click runs the mark macro once", #RanMacros, 1)
b.scripts.OnEnter(b)
check("button tooltip: kill value", has(GameTooltip.lines, "Kill value"), true)
check("button tooltip: its drops", #GameTooltip.lines >= 4, true)
local best = KroolWorldForever.KillValue.Compute(462).top[1].id
ItemNames[best] = "Named Drop"
check("drops named once the client knows the item", ns.WorthLine(462):find("Named Drop", 1, true) ~= nil, true)
__ns.features.killvalue.enabled = false
check("Kill Value off: no worth line", ns.WorthLine(462), nil)
__ns.features.killvalue.enabled = true
check("creature Kill Value knows nothing about", ns.WorthLine(9999999), nil)

out = capture(function()
	FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate3")
	FireEvent("UPDATE_MOUSEOVER_UNIT")
end)
check("seen again soon: no second alert", #Sounds, 1)
check("and no second chat line", #out, 0)
Units.mouseover = Units.nameplate3
Clock = Clock + 301
capture(function()
	FireEvent("UPDATE_MOUSEOVER_UNIT")
end)
check("five minutes later it alerts again", #Sounds, 2)

-- the button goes away two minutes after the last sighting
Clock = Clock + 121
RunTimers()
check("button hides after two minutes", b.shown, false)
check("and the key does nothing", b.attrs.macrotext1, "")

-- ---------------------------------------------------------------- what does not alert

reset()
Rare("target", 100, "Elite One", { class = "rareelite" })
capture(function()
	FireEvent("PLAYER_TARGET_CHANGED")
end)
check("rare elites count", Button().label.text, "Elite One")
local function quiet(label, extra, setup)
	reset()
	Rare("nameplate1", 101, "Quiet", extra)
	if setup then
		setup()
	end
	capture(function()
		FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
	end)
	check(label, #Sounds, 0)
end
quiet("normal creatures", { class = "normal" })
quiet("elites that are not rare", { class = "elite" })
quiet("dead rares", { dead = true })
quiet("friendly rares", { canAttack = false })
quiet("secret classification", { class = Secret() })
quiet("secret guid", { guid = Secret() })
quiet("pets and players", { guid = "Pet-0-4170-0-12-101-00AB" })
quiet("inside an instance", nil, function()
	InInstance = true
end)
quiet("ignored rares", nil, function()
	db.ignore[101] = "Quiet"
end)
db.ignore[101] = nil
reset()
Rare("nameplate1", 3581, "Sewer Beast")
capture(function()
	FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
end)
check("the Stormwind canal crocolisk stays quiet", #Sounds, 0)
reset()
local ok = pcall(FireEvent, "NAME_PLATE_UNIT_ADDED", Secret())
check("a secret unit token is ignored", ok and #Sounds == 0, true)

-- ---------------------------------------------------------------- options

reset()
SettingsSet(SV .. "sound", false)
SettingsSet(SV .. "screen", false)
Rare("nameplate1", 102, "Silent")
out = capture(function()
	FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
end)
check("sound off", #Sounds, 0)
check("screen message off", #ScreenMessages, 0)
check("chat still on", has(out, "Silent"), true)
SettingsSet(SV .. "sound", true)
SettingsSet(SV .. "screen", true)
SettingsSet(SV .. "marker", 7)
check("marker option changes the macro", Button().attrs.macrotext1, "/cleartarget\n/targetexact Silent\n/tm [exists] !7")
check("and the icon", Button().icon.texture, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7")
SettingsSet(SV .. "marker", 8)
SettingsSet(SV .. "button", false)
check("button option off hides it", Button().shown, false)
check("but the key still marks", Button().attrs.macrotext1:find("Silent", 1, true) ~= nil, true)
SettingsSet(SV .. "button", true)
check("button back", Button().shown, true)

reset()
BoundKey = "F"
Rare("nameplate1", 103, "Keyed")
out = capture(function()
	FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
end)
check("chat names the bound key", has(out, "press F to target and mark it"), true)
check("the key is the button's click binding", BindingAsked, "CLICK KroolWorldForeverRareButton:LeftButton")
check("button hint names the key", Button().hint.text, "Click or F")

-- ---------------------------------------------------------------- combat

reset()
InCombat = true
Rare("nameplate1", 104, "Fighter")
out = capture(function()
	FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
end)
check("in combat: still alerts", #Sounds, 1)
check("in combat: no protected call blocked", #BlockedCalls, 0)
check("in combat: the button keeps its old macro", Button().attrs.macrotext1, "")
InCombat = false
FireEvent("PLAYER_REGEN_ENABLED")
check("after combat: the button points at the rare", Button().attrs.macrotext1:find("Fighter", 1, true) ~= nil, true)
check("after combat: shown", Button().shown, true)

-- ---------------------------------------------------------------- ignore

reset()
Rare("nameplate1", 105, "Pest")
capture(function()
	FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
end)
out = capture(function()
	Button():Click("RightButton")
end)
check("right-click ignores the rare", db.ignore[105], "Pest")
check("right-click runs no macro", #RanMacros, 0)
check("and says how to undo it", has(out, "/kwr unignore 105"), true)
check("the button goes away", Button().shown, false)
Clock = Clock + 400
capture(function()
	FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
end)
check("an ignored rare stays quiet", #Sounds, 1)
out = capture(function()
	ns.OnSlash("list")
end)
check("/kwr list shows it", has(out, "Pest (105)"), true)
capture(function()
	ns.OnSlash("unignore pest")
end)
check("/kwr unignore by name", db.ignore[105], nil)

reset()
Rare("target", 106, "Targeted")
capture(function()
	ns.OnSlash("ignore")
end)
check("/kwr ignore takes your target", db.ignore[106], "Targeted")
capture(function()
	ns.OnSlash("unignore 106")
end)
check("/kwr unignore by id", db.ignore[106], nil)

reset()
out = capture(function()
	ns.OnSlash("test")
end)
check("/kwr test shows the button", Button().shown, true)
check("with a test entry", Button().label.text, "Rare Alert Test")
Button():Click("RightButton")
check("right-click on the test entry ignores nothing", db.ignore[0], nil)
out = capture(function()
	ns.OnSlash("")
end)
check("/kwr alone prints help", has(out, "/kwr ignore"), true)

-- ---------------------------------------------------------------- hub and switch

check("hub status", ns.HubStatus():find("ignored", 1, true) ~= nil, true)
BoundKey = nil
check("hub status says when no key is bound", ns.HubStatus():find("no key bound", 1, true) ~= nil, true)

reset()
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("rares off")
end)
check("/kw rares off disables", ns.enabled, false)
Rare("nameplate1", 107, "Unseen")
capture(function()
	FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
end)
check("off: no alert", #Sounds, 0)
check("off: button hidden", Button().shown, false)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("rares on")
end)
capture(function()
	FireEvent("NAME_PLATE_UNIT_ADDED", "nameplate1")
end)
check("on again: alerts", #Sounds, 1)

-- an error inside an event never escapes
local saved = UnitClassification
UnitClassification = function()
	error("api gone")
end
Clock = Clock + 400
ok = pcall(FireEvent, "NAME_PLATE_UNIT_ADDED", "nameplate1")
UnitClassification = saved
check("errors stay inside", ok, true)

realPrint(("\n%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
