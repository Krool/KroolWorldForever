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
	showTutorials = { "0", "1", true, false }, -- state by name: never copied or reset
	eventReminders = { "x", "", true, false }, -- state by help text
	nameplateShowNeutral = { "1", "0", true, false }, -- preference despite "shown" in "showneutral"
}
CVarHelp.eventReminders = "Internal cvar for saving event reminders"
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
check("auto snapshot has the bars", auto.counts.bars, 8)

-- Regression (stress test 2026-10-21): at logout the client has emptied the bars and reset Edit Mode.
local savedActions, savedLayouts = Actions, EditLayouts
Actions, EditLayouts = {}, { layouts = savedLayouts.layouts, activeLayout = 1 }
Clock = Clock + 30
FireEvent("PLAYER_LOGOUT")
RunTimers()
check("logout does not touch the snapshot", auto.updated, 1000000)
check("logout keeps the custom layout", auto.parts.editmode.str, "LAYOUT:Krool")
ns.AutoSnapshot() -- a refresh that reads empty bars anyway
check("an empty bar read keeps the old bars", auto.counts.bars, 8)
Actions, EditLayouts = savedActions, savedLayouts

-- Changes while playing refresh the snapshot a few seconds later (debounced).
Clock = Clock + 30
Bound.Q = "TOGGLEBAG"
FireEvent("UPDATE_BINDINGS")
FireEvent("ACTIONBAR_SLOT_CHANGED", 1)
check("one refresh queued for a burst of changes", #Timers, 1)
RunTimers()
check("change refreshed the snapshot", auto.updated, Clock)
Bound.Q = nil

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
check("cvars: only server-stored, user-settable, non-default preferences", main.counts.cvars, 3)
check("cvars: tutorial state not captured", p.cvars.showTutorials, nil)
check("cvars: state recognized by help text not captured", p.cvars.eventReminders, nil)
check("cvars: a real preference containing 'shown' is kept", p.cvars.nameplateShowNeutral, "1")
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
check("state cvar not reset by apply", CVars.showTutorials[1], "0")
check("help-text state cvar not reset by apply", CVars.eventReminders[1], "x")
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

-- Edit Mode: the identical layout already exists (re-applying your own setup) -> just switch to it.
EditLayouts = { layouts = { { layoutName = "Other", layoutType = 2 }, { layoutName = "Krool", layoutType = 2 } }, activeLayout = 3 }
SaveLayoutsCalls = {}
r = ns.Apply(main, { editmode = true }, ns.db)
check("identical layout: no copy saved", #SaveLayoutsCalls, 0)
check("identical layout: switched to it", EditLayouts.activeLayout, 4)
check("identical layout: reported", has(r.lines, "existing layout"), true)

-- Edit Mode: same name, different layout -> a uniquely named copy.
C_EditMode.ConvertLayoutInfoToString = function(layout)
	return "LAYOUT:" .. layout.layoutName .. (layout.changed and "*" or "")
end
EditLayouts = { layouts = { { layoutName = "Krool", layoutType = 2, changed = true } }, activeLayout = 3 }
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
FireEvent("ACTIONBAR_SLOT_CHANGED", 1)
RunTimers()
check("the next change recreates the auto snapshot", ns.Get(ns.db.chars["Alt-Realm"].auto) ~= nil, true)

-- Applying a setup whose bars are empty must not wipe the target's bars.
local filled = 0
for _ in pairs(Actions) do
	filled = filled + 1
end
r = ns.Apply({ name = "empty", parts = { bars = {} } }, { bars = true }, { clearEmpty = true })
local after = 0
for _ in pairs(Actions) do
	after = after + 1
end
check("empty bar setup leaves the bars alone", after, filled)
check("empty bar setup says so", has(r.lines, "left your bars alone"), true)

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
FireEvent("ACTIONBAR_SLOT_CHANGED", 1)
RunTimers()
check("disabled feature does not snapshot", ns.Get(ns.db.chars["Alt-Realm"].auto).updated, autoBefore)
check("disabled feature adds no setups", count_keys(ns.db.setups), before)
SlashCmdList.KROOLWORLDFOREVER_SETUPS("save Nope")
check("feature slash says it is off", count_keys(ns.db.setups), before)
SettingsSet("KroolWorldForever_setups_enabled", true)
check("settings checkbox turns it back on", ns.enabled, true)
SettingsSet("KroolWorldForever_setups_perCharBinds", false)
r = ns.Apply({ name = "b", parts = { bindings = { { "JUMP", "SPACE" } } } }, { bindings = true }, ns.db)
check("account keybinding option takes effect", SavedBindingSet, 1)

-- ---------------------------------------------------------------- review fixes (0.2.3)

-- Opening the window refreshes this character's snapshot (the "ready" upvalue must be the real one).
F:Hide()
local altSnap = ns.Get(ns.db.chars["Alt-Realm"].auto)
Clock = Clock + 60
ns.Open(false)
check("opening the window refreshes the snapshot", altSnap.updated, Clock)

-- Undo puts back bars that really were empty.
Actions = {}
ns.Apply({ name = "fill", parts = { bars = { [1] = { t = "spell", id = 133, name = "Fireball" } } } }, { bars = true }, { clearEmpty = true })
check("apply filled slot 1", Actions[1] ~= nil, true)
ns.Undo()
check("undo empties bars that were empty", next(Actions), nil)

-- A setup with no keybindings leaves yours alone.
Bound = { W = "MOVEFORWARD" }
r = ns.Apply({ name = "nobinds", parts = { bindings = {} } }, { bindings = true }, ns.db)
check("empty keybinding setup keeps bindings", Bound.W, "MOVEFORWARD")
check("empty keybinding setup says so", has(r.lines, "left yours alone"), true)

-- Edit Mode open: refuse instead of fighting its unsaved state.
EditModeManagerFrame:Show()
SaveLayoutsCalls = {}
EditLayouts = { layouts = {}, activeLayout = 1 }
r = ns.Apply({ name = "em", parts = { editmode = { name = "X", str = "LAYOUT:X" } } }, { editmode = true }, ns.db)
check("edit mode open: nothing saved", #SaveLayoutsCalls, 0)
check("edit mode open: told to close it", has(r.lines, "close Edit Mode"), true)
EditModeManagerFrame:Hide()

-- A layout name the client rejects falls back to "Setup".
local long = string.rep("L", 40)
r = ns.Apply({ name = "em", parts = { editmode = { name = long, str = "LAYOUT:" .. long } } }, { editmode = true }, ns.db)
check("invalid layout name falls back", SaveLayoutsCalls[1] and SaveLayoutsCalls[1].layouts[3].layoutName, "Setup")

-- Closing the new-character picker with X or Escape asks again next login.
ns.db.chars["Alt-Realm"].onboarded = nil
ns.db.chars["Alt-Realm"].askAgain = nil
ns.Settle(true)
check("picker open again", F:IsShown(), true)
F:Hide()
check("closing the picker means ask again", ns.db.chars["Alt-Realm"].askAgain, true)
ns.db.chars["Alt-Realm"].askAgain = nil
InCombat = true
ns.Settle(true)
check("in combat at login: no picker", F:IsShown(), false)
check("in combat at login: asks next time", ns.db.chars["Alt-Realm"].askAgain, true)
InCombat = false

-- Same name, different character (stress test character reused at launch).
Player = { name = "Kaptain", realm = "Realm", class = "WARRIOR", level = 1, guid = "Player-1-NEW" }
ns.db.chars["Kaptain-Realm"].guid = "Player-1-OLD"
local oldAutoId = ns.db.chars["Kaptain-Realm"].auto
ns.db.undo["Kaptain-Realm"] = { at = 1, parts = {} }
local isNew = ns.Identify()
check("same name, new GUID: treated as a new character", isNew, true)
check("the earlier character's snapshot is kept", ns.Get(oldAutoId) ~= nil, true)
check("and is now a named setup", ns.Get(oldAutoId).auto, nil)
check("named after the earlier character", ns.Get(oldAutoId).name, "Kaptain-Realm (earlier character)")
check("the old undo is dropped", ns.db.undo["Kaptain-Realm"], nil)
check("the new character records its GUID", ns.db.chars["Kaptain-Realm"].guid, "Player-1-NEW")
check("the new character is offered the earlier setup", (function()
	for _, s in ipairs(ns.Offers()) do
		if s.id == oldAutoId then
			return true
		end
	end
	return false
end)(), true)
check("same GUID again: not new", ns.Identify(), false)
ns.db.chars["Legacy-Realm"] = { first = 1 }
Player = { name = "Legacy", realm = "Realm", class = "MAGE", level = 5 }
check("entry saved before GUIDs existed: not new", ns.Identify(), false)
check("and gets its GUID", ns.db.chars["Legacy-Realm"].guid, "Player-1-Legacy")

-- ---------------------------------------------------------------- Krool World Settings part

local KV, QT = __ns.features.killvalue, __ns.features.questtrash
KV.db.cut, QT.db.tooltip, QT.db.enabled = 15, false, true
KV.db.learned = { [299] = { n = 5 } }
local kwfSetup = ns.SaveNew("Bundle settings")
local kp = kwfSetup.parts.kwf
check("kwf: every feature captured", kwfSetup.counts.kwf, #__ns.featureOrder)
check("kwf: a range option captured", kp.killvalue.cut, 15)
check("kwf: a false toggle captured", kp.questtrash.tooltip, false)
check("kwf: learned data is not an option", kp.killvalue.learned, nil)
check("kwf: enabled captured", kp.questtrash.enabled, true)

KV.db.cut, QT.db.tooltip, QT.db.enabled = 5, true, false
SetValueCalls = 0
r = ns.Apply(kwfSetup, { kwf = true }, ns.db)
check("kwf: range option restored", KV.db.cut, 15)
check("kwf: false toggle restored", QT.db.tooltip, false)
check("kwf: enabled restored", QT.db.enabled, true)
check("kwf: goes through the panel's setting objects", SetValueCalls >= 3, true)
check("kwf: written immediately, not on the panel's Apply step", RegisteredSettings.KroolWorldForever_killvalue_cut.immediate, true)
check("kwf: reported", has(r.lines, "Krool World Settings: 3 changed"), true)
check("kwf: no reload needed", r.reload, false)

-- Undo restores the previous values.
ns.Undo()
check("kwf undo: range option back", KV.db.cut, 5)
check("kwf undo: toggle back", QT.db.tooltip, true)

-- Saved data from another version: clamped ranges, wrong types, unknown features, Setups stays on.
local odd = {
	name = "odd",
	parts = {
		kwf = {
			killvalue = { cut = 500, learn = "yes" },
			gone = { enabled = true },
			setups = { enabled = false },
		},
	},
}
r = ns.Apply(odd, { kwf = true }, ns.db)
check("kwf: range clamped to the slider", KV.db.cut, 100)
check("kwf: wrong type skipped", KV.db.learn ~= "yes", true)
check("kwf: unknown feature and bad value reported", has(r.lines, "2 not in this version"), true)
check("kwf: never turns Setups off", ns.db.enabled, true)

print(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error("setups tests failed")
end
