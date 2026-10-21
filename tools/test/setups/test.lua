-- Setups behavior checks. Runs after stubs.lua and the whole bundle.

local failures, count = 0, 0
local function check(label, got, want)
	count = count + 1
	if got ~= want then
		failures = failures + 1
		print("FAIL: " .. label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
	else
		print("ok:   " .. label)
	end
end
local function has(lines, needle)
	for _, l in ipairs(lines or {}) do
		if tostring(l):find(needle, 1, true) then
			return true
		end
	end
	return false
end
local function count_keys(t)
	local n = 0
	for _ in pairs(t or {}) do
		n = n + 1
	end
	return n
end

local ns = __ns.features.setups
local ALL = { bars = true, bindings = true, macros = true, editmode = true, cvars = true, addons = true }

-- ---------------------------------------------------------------- Kaptain's setup (the source)

KnownSpells = { [78] = "Heroic Strike", [100] = "Charge", [6673] = "Battle Shout" }
SpellNameOf = {}
OwnedItems = { [117] = true }
MountList = { 501, 502 }
AccountMacros = { { name = "Shout", icon = 1, body = "/cast Battle Shout" } }
CharMacros = { { name = "Charge+", icon = 2, body = "/cast Charge\n/startattack" } }
Actions = {
	[1] = { "spell", 78 },
	[2] = { "spell", 100 },
	[3] = { "macro", 1 }, -- Shout (account)
	[4] = { "macro", 121 }, -- Charge+ (character)
	[5] = { "item", 117 },
	[6] = { "summonmount", 502 },
	[7] = { "flyout", 9 }, -- not restorable
	[13] = { "spell", 6673 },
}
Bound = { W = "MOVEFORWARD", S = "MOVEBACKWARD", SPACE = "JUMP", ["1"] = "ACTIONBUTTON1", ["2"] = "ACTIONBUTTON2", B = "TOGGLEBAG" }
CVars = {
	autoLootDefault = { "1", "0", true, false },
	nameplateShowEnemies = { "1", "1", false, true }, -- server-stored but at default
	chatStyle = { "classic", "im", true, false },
	gxWindow = { "1", "0", false, false }, -- local (Config.wtf): not part of a setup
	secureThing = { "1", "0", true, false, false, true }, -- secure: never touched
	lockedThing = { "1", "0", true, false, true }, -- locked from user
}
AddonOn.Kaptain = { KroolWorldForever = true, Questie = true, Auctionator = false, BugSack = true }
EditLayouts = { layouts = { { layoutName = "Krool", layoutType = 1 } }, activeLayout = 3 }

-- Other features stay off in this suite.
KroolWorldForeverDB = { features = { questtrash = { enabled = false }, killvalue = { enabled = false } } }

-- ---------------------------------------------------------------- boot

FireEvent("ADDON_LOADED", "KroolWorldForever")
FireEvent("PLAYER_LOGIN")
check("feature enabled at login", ns.enabled, true)
check("this character is registered", ns.db.chars["Kaptain-Realm"] ~= nil, true)
check("nothing captured before the login delay", count_keys(ns.db.setups), 0)
FireEvent("PLAYER_LOGOUT")
check("logout before the delay does not snapshot (bars may not be loaded)", count_keys(ns.db.setups), 0)
RunTimers()
check("auto snapshot after the login delay", count_keys(ns.db.setups), 1)
local auto = ns.Get(ns.db.chars["Kaptain-Realm"].auto)
check("auto snapshot is marked auto", auto and auto.auto, true)
check("auto snapshot name", auto and auto.name, "Kaptain-Realm (auto)")
check("no picker: nothing else to offer", KroolWorldForeverSetupsFrame == nil or not KroolWorldForeverSetupsFrame:IsShown(), true)

-- ---------------------------------------------------------------- capture

local main = ns.SaveNew("Main")
local p = main.parts
check("bars: 8 filled slots captured", main.counts.bars, 8)
check("bars: spell keeps its name", p.bars[1].name, "Heroic Strike")
check("bars: macro stored by name", p.bars[4].name, "Charge+")
check("bars: mount stored", p.bars[6].t, "mount")
check("bars: empty slot not stored", p.bars[8], nil)
check("bindings: 6 commands", main.counts.bindings, 6)
check("macros: account and character", main.counts.macros, 2)
check("macros: character flag", p.macros[2].char, true)
check("editmode: active saved layout captured", p.editmode.str, "LAYOUT:Krool")
check("cvars: only server-stored, user-settable, non-default", main.counts.cvars, 2)
check("cvars: local graphics cvar not captured", p.cvars.gxWindow, nil)
check("cvars: secure cvar not captured", p.cvars.secureThing, nil)
check("addons: off addon recorded off", p.addons.Auctionator, false)
check("named setups list before auto ones", ns.List()[1].id, main.id)

-- ---------------------------------------------------------------- switch to a new character

Player = { name = "Alt", realm = "Realm", class = "MAGE", level = 1 }
KnownSpells = { [133] = "Fireball" }
SpellNameOf = { [78] = "Heroic Strike" }
OwnedItems = {}
CharMacros = {}
Actions = { [1] = { "spell", 133 }, [20] = { "spell", 133 } }
Bound = { W = "MOVEFORWARD", F = "JUMP" }
CVars.autoLootDefault[1] = "0"
CVars.chatStyle[1] = "im"
CVars.nameplateShowEnemies[1] = "0" -- default is 1: apply should reset it
EditLayouts = { layouts = {}, activeLayout = 1 }
SaveLayoutsCalls = {}

local offers = ns.Offers()
check("offers exclude nothing of Alt's yet", #offers, 2)
check("default for new characters", (ns.SetDefault(main.id) or ns.db.default), main.id)
ns.db.chars["Alt-Realm"] = { first = Clock }
ns.Settle(true)
check("picker opens on a new character", KroolWorldForeverSetupsFrame:IsShown(), true)
local F = KroolWorldForeverSetupsFrame
check("picker shows the new-character banner", F.banner.text:find("New character", 1, true) ~= nil, true)
check("picker preselects the default setup", F.name.text, "Main")
check("class mismatch warning", F.warning.text:find("Different class", 1, true) ~= nil, true)
check("Alt got its own auto snapshot", ns.Get(ns.db.chars["Alt-Realm"].auto) ~= nil, true)

-- ---------------------------------------------------------------- refusals

InCombat = true
local r = ns.Apply(main, ALL, ns.db)
check("refused in combat", r.ok, false)
check("combat message", has(r.lines, "Not in combat"), true)
check("nothing changed in combat", Actions[1][2], 133)
InCombat = false
Cursor = { "item", 5 }
r = ns.Apply(main, ALL, ns.db)
check("refused while the cursor holds something", r.ok, false)
Cursor = nil

-- ---------------------------------------------------------------- apply through the window

F.apply:Click()
check("apply asks for confirmation", LastPopup and LastPopup.which, "KWF_SETUPS_CONFIRM")
AcceptPopup()
check("macros created first", GetMacroIndexByName("Charge+") > 0, true)
check("account macro exists (already account-wide)", GetMacroIndexByName("Shout"), 1)
check("bars: macro placed by name", Actions[4] and Actions[4][1], "macro")
check("bars: unknown warrior spell skipped, the mage's own spell stays", Actions[1] and Actions[1][2], 133)
check("bars: mount placed", Actions[6] and Actions[6][2], 502)
check("bars: item not owned is skipped", Actions[5], nil)
check("bars: slot empty in the setup is cleared", Actions[20], nil)
check("report lists skipped spells", has(F.report.text and { F.report.text }, "Heroic Strike"), true)
check("report lists the unsupported flyout", has({ F.report.text }, "flyout"), true)
check("bindings replaced: F no longer jumps", Bound.F, nil)
check("bindings replaced: SPACE jumps", Bound.SPACE, "JUMP")
check("bindings saved per character", SavedBindingSet, 2)
check("cvar applied", CVars.autoLootDefault[1], "1")
check("cvar left at default in the setup is reset", CVars.nameplateShowEnemies[1], "1")
check("secure cvar untouched", CVars.secureThing[1], "1")
check("addons: Auctionator turned off for Alt", AddonOn.Alt.Auctionator, false)
check("addons: never disables itself", AddonOn.Alt.KroolWorldForever, true)
local saved = SaveLayoutsCalls[1]
check("edit mode saved once", #SaveLayoutsCalls, 1)
check("edit mode save keeps built-in layouts first", saved and saved.layouts[1].layoutName, "Modern")
check("edit mode layout added as a character layout", saved and saved.layouts[3].layoutType, 2)
check("edit mode new layout is active", EditLayouts.activeLayout, 3)
check("reload offered", F.reload:IsShown(), true)
F.reload:Click()
check("reload button reloads", Reloaded, true)
check("applying onboards the character", ns.db.chars["Alt-Realm"].onboarded, true)

-- ---------------------------------------------------------------- undo

check("undo available", ns.db.undo["Alt-Realm"] ~= nil, true)
F.undo:Click()
AcceptPopup()
check("undo: fireball back in slot 1", Actions[1] and Actions[1][2], 133)
check("undo: slot 20 restored", Actions[20] and Actions[20][2], 133)
check("undo: macro slot cleared again", Actions[4], nil)
check("undo: F jumps again", Bound.F, "JUMP")
check("undo: account binding set restored", SavedBindingSet, 1)
check("undo: cvar restored", CVars.autoLootDefault[1], "0")
check("undo: addon restored", AddonOn.Alt.Auctionator, true)
check("undo: edit mode switched back", EditLayouts.activeLayout, 1)
check("undo is one level", ns.db.undo["Alt-Realm"], nil)
check("undo keeps created macros", GetMacroIndexByName("Charge+") > 0, true)

-- ---------------------------------------------------------------- edge cases

-- Rank fallback: setup has an id the player does not know, but knows the spell by name.
KnownSpells = { [133] = "Fireball", [143] = "Fireball" }
SpellByName = { Fireball = 143 }
local rankSetup = { name = "ranks", parts = { bars = { [9] = { t = "spell", id = 133000, name = "Fireball" } } } }
ns.Apply(rankSetup, { bars = true }, { clearEmpty = false })
check("spell placed by name when the id is unknown", Actions[9] and Actions[9][2], 143)
check("clearEmpty off keeps other slots", Actions[1] ~= nil, true)

-- Macro with the same name and a different body: keep the player's.
CharMacros = { { name = "Charge+", icon = 3, body = "/say mine" } }
r = ns.Apply(main, { macros = true }, ns.db)
check("conflicting macro kept", CharMacros[1].body, "/say mine")
check("conflict reported", has(r.lines, "kept your existing macro"), true)

-- Macro slots full.
MacroLimits.char = 0
CharMacros = {}
r = ns.Apply(main, { macros = true }, ns.db)
check("full macro slots reported", has(r.lines, "could not create"), true)
MacroLimits.char = 18

-- Edit Mode: name collision and full layouts.
EditLayouts = { layouts = { { layoutName = "Krool", layoutType = 2 } }, activeLayout = 3 }
SaveLayoutsCalls = {}
ns.Apply(main, { editmode = true }, ns.db)
check("layout name made unique", SaveLayoutsCalls[1] and SaveLayoutsCalls[1].layouts[4].layoutName, "Krool 2")
local five = {}
for i = 1, 5 do
	five[i] = { layoutName = "L" .. i, layoutType = 2 }
end
EditLayouts = { layouts = five, activeLayout = 3 }
SaveLayoutsCalls = {}
r = ns.Apply(main, { editmode = true }, ns.db)
check("full layouts: nothing saved", #SaveLayoutsCalls, 0)
check("full layouts reported", has(r.lines, "already has 5 layouts"), true)

-- A built-in layout setup just switches.
local presetSetup = { name = "p", parts = { editmode = { preset = 2 } } }
ns.Apply(presetSetup, { editmode = true }, ns.db)
check("built-in layout switched", EditLayouts.activeLayout, 2)

-- Addon in the setup that is not installed here.
local addonSetup = { name = "a", parts = { addons = { WeakAuras = true } } }
r = ns.Apply(addonSetup, { addons = true }, ns.db)
check("missing addon reported", has(r.lines, "WeakAuras"), true)

-- ---------------------------------------------------------------- management

ns.Rename(main.id, "Warrior Main")
check("rename", main.name, "Warrior Main")
Clock = Clock + 60
ns.Update(main.id)
check("overwrite stamps the current character", main.source, "Alt-Realm")
check("overwrite refreshes the time", main.updated, Clock)
ns.SetDefault(main.id)
check("clicking default again clears it", ns.db.default, nil)
ns.SetDefault(main.id)
ns.Delete(main.id)
check("delete removes it", ns.Get(main.id), nil)
check("delete clears the default", ns.db.default, nil)
local altAuto = ns.db.chars["Alt-Realm"].auto
ns.Delete(altAuto)
check("deleting an auto snapshot unlinks it", ns.db.chars["Alt-Realm"].auto, nil)
Clock = Clock + 60
FireEvent("PLAYER_LOGOUT")
check("logout recreates the auto snapshot", ns.Get(ns.db.chars["Alt-Realm"].auto) ~= nil, true)

-- Window: save through the name prompt.
F.saveNew:Click()
check("save asks for a name", LastPopup and LastPopup.which, "KWF_SETUPS_NAME")
AcceptPopup("Mage Start")
local found
for _, s in ipairs(ns.List()) do
	if s.name == "Mage Start" then
		found = s
	end
end
check("saved from the window", found ~= nil, true)
check("auto setups cannot be renamed", (function()
	ns.Open(false)
	for _, s in ipairs(ns.List()) do
		if s.auto then
			F.rows[1].scripts.OnClick({ id = s.id })
			return F.rename:IsEnabled()
		end
	end
end)(), false)

-- Slash.
SlashCmdList.KROOLWORLDFOREVER_SETUPS("save Quick")
local quick
for _, s in ipairs(ns.List()) do
	if s.name == "Quick" then
		quick = s
	end
end
check("/kws save names a setup", quick ~= nil, true)
F:Hide()
SlashCmdList.KROOLWORLDFOREVER_SETUPS("")
check("/kws toggles the window open", F:IsShown(), true)
SlashCmdList.KROOLWORLDFOREVER("setups")
check("/kwf setups opens the window too", F:IsShown(), true)
check("settings page has an Open button", SettingsButtons.Setups and SettingsButtons.Setups.text, "Open Setups")

-- ---------------------------------------------------------------- on/off

SlashCmdList.KROOLWORLDFOREVER("setups off")
check("off state is saved", ns.db.enabled, false)
local before = count_keys(ns.db.setups)
local autoBefore = ns.Get(ns.db.chars["Alt-Realm"].auto).updated
Clock = Clock + 60
FireEvent("PLAYER_LOGOUT")
check("disabled feature does not snapshot on logout", ns.Get(ns.db.chars["Alt-Realm"].auto).updated, autoBefore)
check("disabled feature adds no setups", count_keys(ns.db.setups), before)
SlashCmdList.KROOLWORLDFOREVER_SETUPS("save Nope")
check("feature slash says it is off", count_keys(ns.db.setups), before)
SettingsSet("KroolWorldForever_setups_enabled", true)
check("settings checkbox turns it back on", ns.enabled, true)
SettingsSet("KroolWorldForever_setups_perCharBinds", false)
r = ns.Apply({ name = "b", parts = { bindings = { { "JUMP", "SPACE" } } } }, { bindings = true }, ns.db)
check("account keybinding option takes effect", SavedBindingSet, 1)

print(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error("setups tests failed")
end
