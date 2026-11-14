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
	autoLootDefault = { "1", "0", false, true },
	nameplateShowEnemies = { "1", "1", false, true }, -- server-stored but at default
	chatStyle = { "classic", "im", false, true },
	gxWindow = { "1", "0", false, false }, -- local (Config.wtf): not part of a setup
	secureThing = { "1", "0", false, true, false, true }, -- secure: never touched
	lockedThing = { "1", "0", false, true, true }, -- locked from user
	showTutorials = { "0", "1", false, true }, -- state by name: never copied or reset
	eventReminders = { "x", "", false, true }, -- state by help text
	nameplateShowNeutral = { "1", "0", false, true }, -- preference despite "shown" in "showneutral"
}
CVarHelp.eventReminders = "Internal cvar for saving event reminders"
AddonOn["Player-1-Kaptain"] = { KroolWorldForever = true, Questie = true, Auctionator = false, BugSack = true }
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
-- The picker path (auto-apply and auto-reload have their own tests at the end).
ns.db.autoDefault, ns.db.autoReload = false, false
ns.Settle(true)
check("picker opens on a new character", KroolWorldForeverSetupsFrame:IsShown(), true)
local F = KroolWorldForeverSetupsFrame
check("picker shows the new-character banner", F.banner.text:find("New character", 1, true) ~= nil, true)
check("picker preselects the default setup", F.name.text, "Main")
check("class mismatch warning", F.warning.text:find("Different class", 1, true) ~= nil, true)
check("Alt got its own auto snapshot", ns.Get(ns.db.chars["Alt-Realm"].auto) ~= nil, true)
-- polish: the window opened with Blizzard's open sound and its intro animation
check("polish: opening the window plays the open sound", HeardSound(839), true)
local intro = AnimationsOn(F)[1]
check("polish: the window's intro animation played", intro ~= nil and intro.plays >= 1, true)
check("polish: the selected row uses Blizzard's selected-row art", F.rows[1].sel.atlas, "PetList-ButtonSelect")

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
local function part(key)
	for _, cb in ipairs(F.checks) do
		if cb.key == key then
			return cb
		end
	end
end
local barsRow = part("bars")
check("after apply the rows show results", F.partsHeader.text, "What Changed")
check("bars row: skipped spells make it a warning", barsRow.result and barsRow.result.level, "warn")
check("bars row: summary without the label", barsRow.count.text:find("^%d+ placed") ~= nil, true)
check("bars row: status icon instead of the checkbox", barsRow.status:IsShown() and not barsRow:IsShown(), true)
check("bars row lists skipped spells", has(barsRow.result.details, "Heroic Strike"), true)
check("bars row lists the unsupported flyout", has(barsRow.result.details, "flyout"), true)
check("hovering the bars row shows the details", has(Hover(barsRow.row), "Heroic Strike"), true)
check("bindings row: ok", part("bindings").result.level, "ok")
check("the banner says what was applied", F.banner.text:find("Applied", 1, true) ~= nil, true)
local toast = __ns.UI.ToastOf(F)
check("polish: a toast says what was applied", toast and toast.text.text, "Applied Main")
check("polish: the toast is showing", toast and toast:IsShown(), true)
local popped = AnimationsOn(barsRow.status)[1]
check("polish: the result icon popped in", popped ~= nil and popped.plays, 1)
ns.Refresh()
check("polish: and only once, not on every refresh", popped and popped.plays, 1)
FinishAnimations()
check("polish: the toast goes away by itself", toast:IsShown(), false)
local pulse = AnimationsOn(F.reloadBar.glow)[1]
check("polish: the reload glow breathes while a reload waits", pulse ~= nil and pulse.playing, true)
check("polish: and it loops", pulse and pulse.looping, "BOUNCE")
check("bindings replaced: F no longer jumps", Bound.F, nil)
check("bindings replaced: SPACE jumps", Bound.SPACE, "JUMP")
check("bindings saved per character", SavedBindingSet, 2)
check("cvar applied", CVars.autoLootDefault[1], "1")
check("state cvar not reset by apply", CVars.showTutorials[1], "0")
check("help-text state cvar not reset by apply", CVars.eventReminders[1], "x")
check("cvar left at default in the setup is reset", CVars.nameplateShowEnemies[1], "1")
check("secure cvar untouched", CVars.secureThing[1], "1")
check("addons: Auctionator turned off for Alt", AddonOn["Player-1-Alt"].Auctionator, false)
check("addons: never disables itself", AddonOn["Player-1-Alt"].KroolWorldForever, true)
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
check("undo: addon restored", AddonOn["Player-1-Alt"].Auctionator, true)
check("undo: edit mode switched back", EditLayouts.activeLayout, 1)
check("undo is one level", ns.db.undo["Alt-Realm"], nil)
check("polish: a toast says the undo finished", __ns.UI.ToastOf(F).text.text, "Undo finished")
check("undo keeps created macros", GetMacroIndexByName("Charge+") > 0, true)

-- A slot holding something Undo could not put back (an equipment set) is left alone, whether the
-- setup wants another action there or wants it empty.
Actions[30] = { "equipmentset", 2 }
Actions[31] = { "equipmentset", 3 }
local fire = { t = "spell", id = 133, name = "Fireball" }
r = ns.Apply({ name = "keep", parts = { bars = { [1] = fire, [31] = fire } } }, { bars = true }, ns.db)
check("apply leaves an equipment set button the setup would clear", Actions[30] and Actions[30][1], "equipmentset")
check("and one the setup would replace", Actions[31] and Actions[31][1], "equipmentset")
check("and says so", has(r.lines, "2 slots left alone"), true)
-- A refused undo (the cursor holds something) must not toast success.
ns.Refresh()
Cursor = { "item", 5 }
F.undo:Click()
AcceptPopup()
check("a refused undo does not say it finished", __ns.UI.ToastOf(F).text.text, "Nothing undone")
check("and the undo is still there", ns.db.undo["Alt-Realm"] ~= nil, true)
Cursor = nil
r = ns.Undo()
check("undo with an equipment set in the snapshot: ok", r and r.ok, true)
check("and nothing reported as not available", has(r.lines, "equipmentset"), false)
check("the equipment set buttons are still there", Actions[30][1] .. Actions[31][1], "equipmentsetequipmentset")
Actions[30], Actions[31] = nil, nil

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
BindingSet = 2 -- this character is on its own set
r = ns.Apply({ name = "b", parts = { bindings = { { "JUMP", "SPACE" } } } }, { bindings = true }, ns.db)
check("a character on its own set keeps it even with the option off", SavedBindingSet, 2)
check("and the report says where it saved", has(r.lines, "saved for this character"), true)
BindingSet, SavedBindingSet = 1, nil
r = ns.Apply({ name = "b", parts = { bindings = { { "JUMP", "SPACE" } } } }, { bindings = true }, ns.db)
check("account keybinding option takes effect", SavedBindingSet, 1)
check("and the report says it saved for the account", has(r.lines, "saved for the account"), true)

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

-- ---------------------------------------------------------------- Action Bars 2-8 on/off

BarToggles = { true, true, false, true, false, false, false }
local barsOn = ns.SaveNew("Bars on")
check("bar toggles captured", barsOn.parts.bars.toggles[2], true)
check("bar toggles do not count as slots", barsOn.counts.bars, (function()
	local n = 0
	for _ in pairs(Actions) do
		n = n + 1
	end
	return n
end)())
BarToggles = { false, false, false, false, false, false, false }
r = ns.Apply(barsOn, { bars = true }, ns.db)
check("bar 2 switched on", BarToggles[1], true)
check("bar 5 switched on", BarToggles[4], true)
check("bar 4 stays off", BarToggles[3], false)
check("bar toggles reported", has(r.lines, "3 extra bars switched on"), true)
ns.Undo()
check("undo switches the bars back off", BarToggles[1], false)
-- A setup holding only the toggles (no slots) still applies them, and leaves the slots alone.
local before = 0
for _ in pairs(Actions) do
	before = before + 1
end
r = ns.Apply({ name = "t", parts = { bars = { toggles = { true, false, false, false, false, false, false } } } }, { bars = true }, ns.db)
check("toggles-only setup switches bar 2 on", BarToggles[1], true)
check("toggles-only setup keeps the slots", (function()
	local n = 0
	for _ in pairs(Actions) do
		n = n + 1
	end
	return n
end)(), before)
-- Forever can force bar visibility: then leave the toggles alone.
ForcedBars = true
BarToggles = { false, false, false, false, false, false, false }
ns.Apply(barsOn, { bars = true }, ns.db)
check("forced visibility: toggles untouched", BarToggles[1], false)
ForcedBars = false

-- ---------------------------------------------------------------- Edit Mode account options

EditModeManagerFrame:Hide()
EditLayouts = { layouts = {}, activeLayout = 2 } -- built-in Classic
EditAccount = { [3] = 1, [7] = 1, [24] = 1 }
local classic = ns.SaveNew("Classic look")
check("em: built-in Classic captured as preset 2", classic.parts.editmode.preset, 2)
check("em: account options captured", classic.parts.editmode.account[24], 1)
EditLayouts = { layouts = {}, activeLayout = 1 }
EditAccount = { [3] = 0, [7] = 1, [24] = 0 }
r = ns.Apply(classic, { editmode = true }, ns.db)
check("em: switched to Classic", EditLayouts.activeLayout, 2)
check("em: account options are shared, so apply leaves them", EditAccount[3], 0)
check("em: pet frame left alone too", EditAccount[24], 0)
check("em: no options reported", has(r.lines, "options changed"), false)
EditAccount = { [3] = 1, [7] = 1, [24] = 1 } -- as an older version's apply would have left them
ns.Undo()
check("em undo: back to Modern", EditLayouts.activeLayout, 1)
check("em undo: account options put back", EditAccount[3], 0)
check("em undo: pet frame put back", EditAccount[24], 0)
ns.Open(false)
for _, s in ipairs(ns.List()) do
	if s.id == classic.id then
		F.rows[1].scripts.OnClick({ id = s.id })
	end
end
local emLabel
for _, cb in ipairs(F.checks) do
	if cb.key == "editmode" then
		emLabel = cb.count.text
	end
end
check("window names the built-in layout", emLabel and emLabel:find("built-in Classic", 1, true) ~= nil, true)
check("window counts the Edit Mode options", emLabel and emLabel:find("3 options", 1, true) ~= nil, true)

-- ---------------------------------------------------------------- auto reload and auto default

-- Manual apply that needs a reload: reloads by itself, and the report survives the reload.
ns.db.autoReload = true
Reloaded = false
EditLayouts = { layouts = {}, activeLayout = 1 }
ns.Open(false)
for i, row in ipairs(F.rows) do
	if row.id == classic.id then
		row.scripts.OnClick(row)
	end
end
F.apply:Click()
AcceptPopup()
check("apply reloads by itself when Edit Mode changed", Reloaded, true)
check("the report is kept for after the reload", ns.db.pendingReport and ns.db.pendingReport.name, "Classic look")
ns.Settle(false)
check("the kept report is printed after the reload", ns.db.pendingReport, nil)
-- Nothing that needs a reload: no reload.
Reloaded = false
ns.Apply({ name = "b", parts = { bindings = { { "JUMP", "SPACE" } } } }, { bindings = true }, ns.db)
check("no reload when nothing needs one", ns.ReloadIfNeeded({ name = "b" }, { reload = false }), false)
check("and the client was not reloaded", Reloaded, false)

-- A brand-new character with a default set: applied at login with no picker. The apply runs from a
-- timer, where the client blocks C_UI.Reload (live 2026-11-04), so the window opens on the result
-- with a Reload Now button instead of reloading by itself.
check("no protected call blocked so far", #BlockedCalls, 0)
ns.db.autoDefault = true
ns.SetDefault(classic.id)
Player = { name = "Fresh", realm = "Realm", class = "WARRIOR", level = 1 }
EditLayouts = { layouts = {}, activeLayout = 1 }
F:Hide()
Reloaded = false
local isNewFresh = ns.Identify()
ns.Settle(isNewFresh)
check("default applied to the new character", EditLayouts.activeLayout, 2)
check("the new character counts as onboarded", ns.db.chars["Fresh-Realm"].onboarded, true)
check("auto apply makes no blocked protected call", #BlockedCalls, 0)
check("auto apply does not reload by itself", Reloaded, false)
check("the window opens on what was applied", F:IsShown(), true)
check("not in picker mode", F.notNow:IsShown(), false)
check("the applied setup is selected", F.name.text, "Classic look")
check("the banner says it was applied", F.banner.text:find("applied", 1, true) ~= nil, true)
check("Reload Now is offered", F.reload:IsShown(), true)
F.reload:Click()
check("clicking Reload Now reloads", Reloaded, true)
check("undo is available for the auto apply", ns.db.undo["Fresh-Realm"] ~= nil, true)
F:Hide()
-- A character this addon has not seen, but not new to the game (installed later, or a default
-- picked later): never applied by itself. The picker opens instead.
Player = { name = "Veteran", realm = "Realm", class = "WARRIOR", level = 30 }
EditLayouts = { layouts = {}, activeLayout = 1 }
ns.Settle(ns.Identify())
check("established character: default not applied", EditLayouts.activeLayout, 1)
check("established character: nothing to undo", ns.db.undo["Veteran-Realm"], nil)
check("established character: the picker opens instead", F:IsShown() and F.notNow:IsShown(), true)
check("established character: the default is preselected", F.name.text, "Classic look")
F:Hide()
-- Level 1 with experience already earned (logged out and back before the first ding): not new.
Player = { name = "Started", realm = "Realm", class = "WARRIOR", level = 1, xp = 40 }
ns.Settle(ns.Identify())
check("level 1 with xp: default not applied", ns.db.undo["Started-Realm"], nil)
F:Hide()
-- Logging in again does not apply it a second time.
EditLayouts.activeLayout = 1
Reloaded = false
ns.Settle(ns.Identify())
check("not applied again on the next login", EditLayouts.activeLayout, 1)
-- With the option off, the picker opens instead.
ns.db.autoDefault = false
Player = { name = "Picky", realm = "Realm", class = "MAGE", level = 1 }
ns.Settle(ns.Identify())
check("option off: the picker opens instead", F:IsShown(), true)
check("option off: nothing applied", ns.db.chars["Picky-Realm"].onboarded, nil)
F:Hide()
ns.db.autoDefault, ns.db.autoReload = true, true

-- ---------------------------------------------------------------- Krool World Settings part

local KV, QT = __ns.features.killvalue, __ns.features.questtrash
KV.db.cut, QT.db.tooltip, QT.db.enabled = 15, false, true
KV.db.learned = { [299] = { n = 5 } }
local kwfSetup = ns.SaveNew("Bundle settings")
local kp = kwfSetup.parts.kwf
check("kwf: every feature but Setups captured", kwfSetup.counts.kwf, #__ns.featureOrder - 1)
check("kwf: Setups' own options are not part of a setup", kp.setups, nil)
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
-- A 0.3.0 setup that still holds Setups' options does not switch them back.
ns.db.autoReload = true
ns.Apply({ name = "old", parts = { kwf = { setups = { autoReload = false, picker = false } } } }, { kwf = true }, ns.db)
check("kwf: Setups' own options never applied", ns.db.autoReload, true)

-- ---------------------------------------------------------------- the hub (/kw)

local root = __ns
check("/kw is the main command", SLASH_KROOLWORLDFOREVER1, "/kw")
check("/kwf still works", SLASH_KROOLWORLDFOREVER2, "/kwf")
local setupsWin = _G.KroolWorldForeverSetupsFrame
if setupsWin then
	setupsWin:Hide()
end
wipe(Sounds)
SlashCmdList.KROOLWORLDFOREVER("")
local hub = root.HubFrame()
check("/kw opens the hub", hub ~= nil and hub:IsShown(), true)
check("one card per feature", #hub.cards, #root.featureOrder)
check("polish: the hub opens with the open sound", HeardSound(839), true)
local cardFade = AnimationsOn(hub.cards[3])[1]
check("polish: the cards fade in one after another", cardFade ~= nil and cardFade.plays >= 1, true)
check("polish: each card has its on/off bar", hub.cards[1].accent ~= nil, true)
local cards = {}
for _, c in ipairs(hub.cards) do
	cards[c.feature.key] = c
end
check("cards in TOC order", hub.cards[1].feature.key, "questtrash")
check("a card for Rare Alert", cards.rares ~= nil, true)
check("a card for Disenchant Value", cards.disenchant ~= nil, true)
check("Disenchant Value without Auctionator says so", cards.disenchant.status.text:find("Needs Auctionator", 1, true) ~= nil, true)
check("Disenchant Value has no window: no Open", cards.disenchant.open, false)
check("a card for Camp Guide", cards.camp ~= nil, true)
check("Camp Guide away from a fire says so", cards.camp.status.text:find("No camp buffs", 1, true) ~= nil, true)
check("Camp Guide has no window: no Open", cards.camp.open, false)
check("card title", cards.setups.title.text, "Setups")
check("card blurb", cards.setups.blurb.text, "Copy bars, keys and layouts between characters")
check("Setups status counts setups", cards.setups.status.text:find("setups", 1, true) ~= nil, true)
check("Setups status names the default", cards.setups.status.text:find("new characters get", 1, true) ~= nil, true)
-- (earlier sections switched Quest Trash and Kill Value off through the kwf part)
check("an off feature's card says Off", cards.killvalue.status.text, "|cff888888Off|r")
check("off: icon greyed", cards.killvalue.toggle.checked, false)
check("Quest Trash without QuestieDB says so", root.features.questtrash.HubStatus():find("QuestieDB", 1, true) ~= nil, true)
check("Kill Value status", root.features.killvalue.HubStatus():find("creatures learned", 1, true) ~= nil, true)
check("on features are checked", cards.setups.toggle.checked, true)
check("a feature with a window gets Open", cards.setups.open ~= false, true)
check("a feature without one does not", cards.killvalue.open, false)
check("every card has a settings button", cards.killvalue.gear ~= nil, true)
check("card tooltip names the command", has(Hover(cards.setups), "/kws"), true)

-- the Rare Alert card offers to turn enemy nameplates on while they are off
check("plates state unknown: no button", cards.rares.action.shown, false)
CVars.nameplateShowEnemies = { "0" }
CVars.nameplateMaxDistance = { "45" }
C_CVar.GetCVar = function(name)
	return CVars[name] and CVars[name][1]
end
root.RefreshHub()
check("plates off: the Rare Alert card shows a button", cards.rares.action.shown, true)
check("labelled Plates On", cards.rares.action.text, "Plates On")
check("and its status says why", cards.rares.status.text:find("nameplates", 1, true) ~= nil, true)
cards.rares.action:Click()
check("Plates On turns enemy nameplates on", CVars.nameplateShowEnemies[1], "1")
check("and the button goes away", cards.rares.action.shown, false)
check("cards with a window get no fix-it button", cards.setups.action, false)
CVars.nameplateShowEnemies, CVars.nameplateMaxDistance, C_CVar.GetCVar = nil, nil, nil

-- on/off from the card
Hardware(cards.rares.toggle.scripts.OnClick, cards.rares.toggle)
check("card switch turns the feature off", root.features.rares.enabled, false)
check("and saves it", root.features.rares.db.enabled, false)
check("card shows Off", cards.rares.status.text:find("Off", 1, true) ~= nil, true)
check("switch unchecked", cards.rares.toggle.checked, false)
check("polish: a toast confirms the switch", root.UI.ToastOf(hub).text.text, "Rare Alert off")
check("polish: and the switch made a checkbox sound", HeardSound(856) or HeardSound(857), true)
SlashCmdList.KROOLWORLDFOREVER("rares on")
check("turning it on elsewhere refreshes the open hub", cards.rares.toggle.checked, true)

-- the way in
wipe(Sounds)
cards.setups.open:Click()
check("Open leaves the hub", hub:IsShown(), false)
check("and opens the feature's window", _G.KroolWorldForeverSetupsFrame:IsShown(), true)
check("polish: the hub steps aside without its close sound", HeardSound(840), false)
check("polish: the window that opens makes the open sound", HeardSound(839), true)
check("polish: the Open button clicks", HeardSound(852), true)
_G.KroolWorldForeverSetupsFrame:Hide()
SlashCmdList.KROOLWORLDFOREVER("")
cards.killvalue:Click()
check("a card without a window opens its settings", OpenedCategory, "Kill Value")
SlashCmdList.KROOLWORLDFOREVER("")
cards.setups.gear:Click()
check("the gear opens settings", OpenedCategory, "Setups")
SlashCmdList.KROOLWORLDFOREVER("")
hub.settings:Click()
check("All Settings opens the bundle page", OpenedCategory, "Krool World Forever")
SlashCmdList.KROOLWORLDFOREVER("")
SlashCmdList.KROOLWORLDFOREVER("")
check("/kw again closes it", hub:IsShown(), false)
KroolWorldForever_OnCompartmentClick()
check("the minimap button opens the hub", hub:IsShown(), true)
hub:Hide()

-- ---------------------------------------------------------------- review fixes (account state)

-- Account-wide CVars are shared already: never captured, never applied (even from an older setup).
CVars.acctPref = { "2", "1", true, false }
local capParts = ns.Capture({ cvars = true })
check("account cvar not captured", capParts.cvars.acctPref, nil)
check("per-character cvar still captured", capParts.cvars.nameplateShowNeutral, "1")
r = ns.Apply({ name = "old", parts = { cvars = { acctPref = "9" } } }, { cvars = true }, ns.db)
check("account cvar in an old setup is ignored on apply", CVars.acctPref[1], "2")
CVars.acctPref = nil

-- A refused SetCVar (false) is counted as refused, not changed.
CVars.autoLootDefault[1] = "0"
RefusedCVars = { autoLootDefault = true }
r = ns.Apply({ name = "ref", parts = { cvars = { autoLootDefault = "1" } } }, { cvars = true }, ns.db)
check("refused cvar left as it was", CVars.autoLootDefault[1], "0")
check("refused cvar reported as refused", has(r.lines, "1 refused"), true)
RefusedCVars = nil

-- The soft-interact CVars One-Button Fishing holds are captured at their originals.
local Fishing = __ns.features.fishing
local realHeld = Fishing.HeldCVars
CVars.nameplateShowNeutral[1] = "7" -- Fishing's temporary value
Fishing.HeldCVars = function()
	return { nameplateShowNeutral = "0", autoLootDefault = "5" }
end
capParts = ns.Capture({ cvars = true })
check("held cvar at its default original is not recorded", capParts.cvars.nameplateShowNeutral, nil)
check("held cvar recorded at its original", capParts.cvars.autoLootDefault, "5")
Fishing.HeldCVars = function()
	return nil
end
capParts = ns.Capture({ cvars = true })
check("nothing held: the current value is captured", capParts.cvars.nameplateShowNeutral, "7")
Fishing.HeldCVars = realHeld
CVars.nameplateShowNeutral[1] = "1"

-- Cross-class apply leaves the class bars (73-144) alone; the same class clears them as before.
KnownSpells[133] = "Fireball"
Player = { name = "Kaptain", realm = "Realm", class = "WARRIOR", level = 10 }
local barSetup = {
	name = "bars",
	class = "MAGE",
	parts = { bars = { [1] = { t = "spell", id = 133, name = "Fireball" }, [80] = { t = "spell", id = 133, name = "Fireball" } } },
}
Actions = { [85] = { "spell", 78 }, [5] = { "spell", 78 } }
r = ns.Apply(barSetup, { bars = true }, { clearEmpty = true })
check("other class: normal slot placed", Actions[1] ~= nil, true)
check("other class: normal slot cleared as before", Actions[5], nil)
check("other class: class bar slot not placed", Actions[80], nil)
check("other class: class bar slot not cleared", Actions[85] ~= nil, true)
check("other class: reported", has(r.lines, "class bars (slots 73-144) left alone"), true)
Actions = { [85] = { "spell", 78 } }
barSetup.class = "WARRIOR"
r = ns.Apply(barSetup, { bars = true }, { clearEmpty = true })
check("same class: class bar slot placed", Actions[80] ~= nil, true)
check("same class: class bar slot cleared", Actions[85], nil)
check("same class: no class bar note", has(r.lines, "class bars"), false)
Actions = { [85] = { "spell", 78 } }
barSetup.class = nil
ns.Apply(barSetup, { bars = true }, { clearEmpty = true })
check("class unknown: restores everything", Actions[85], nil)

-- The automatic new-character apply skips the bundle's own settings (account-wide) and needs no money.
local autoSetup = { id = ns.db.nextId + 1, name = "Auto kwf", parts = { kwf = { killvalue = { cut = 77 } }, editmode = { preset = 2 } } }
ns.db.nextId = autoSetup.id
ns.db.setups[autoSetup.id] = autoSetup
ns.db.default, ns.db.autoDefault = autoSetup.id, true
KV.db.cut = 15
Player = { name = "Rich", realm = "Realm", class = "WARRIOR", level = 1, money = 500 }
EditLayouts = { layouts = {}, activeLayout = 1 }
ns.Settle(ns.Identify())
check("level 1 with money: not a first login, default not applied", EditLayouts.activeLayout, 1)
F:Hide()
Player = { name = "Penniless", realm = "Realm", class = "WARRIOR", level = 1 }
ns.Settle(ns.Identify())
check("auto apply still applies the rest", EditLayouts.activeLayout, 2)
check("auto apply skips the kwf part", KV.db.cut, 15)
F:Hide()
r = ns.Apply(autoSetup, { kwf = true }, ns.db)
check("a manual apply still takes the kwf part", KV.db.cut, 77)
KV.db.cut = 15

check("no protected call was ever blocked", #BlockedCalls, 0)

print(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error("setups tests failed")
end
