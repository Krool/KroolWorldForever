-- Character roster checks (Core/Characters.lua, CharactersWindow.lua, the /kw commands, the hub's
-- buttons) and the two features that list characters: Setups and Sayge's Fortune.

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
local function kw(msg)
	return capture(function()
		SlashCmdList.KROOLWORLDFOREVER(msg)
	end)
end
local function count_keys(t)
	local n = 0
	for _ in pairs(t or {}) do
		n = n + 1
	end
	return n
end

local root = __ns
local setups, fortune = root.features.setups, root.features.fortune

-- Only Setups and Fortune run; every other feature is off. Saved roster with some damage in it.
KroolWorldForeverDB = {
	features = {},
	chars = {
		["Old-Realm"] = { name = "Old", realm = "Realm", class = "MAGE", level = "7", seen = 500, track = false },
		["Bad-Realm"] = "not a record",
		["Odd-Realm"] = { name = 5, level = -3, track = "yes" },
	},
}
for _, key in ipairs(root.featureOrder) do
	KroolWorldForeverDB.features[key] = { enabled = key == "setups" or key == "fortune" }
end

-- ---------------------------------------------------------------- the roster

check("the key is Name-Realm", root.CharKey(), "Kaptain-Realm")
Clock = 2000000
capture(function()
	FireEvent("ADDON_LOADED", "KroolWorldForever")
end)
local chars = root.Chars()
check("a record that is not a table is dropped", chars["Bad-Realm"], nil)
check("a saved level is coerced", chars["Old-Realm"].level, 7)
check("an opt-out survives the load", chars["Old-Realm"].track, false)
check("a bad name falls back to the key's", chars["Odd-Realm"].name, "Odd")
check("a negative level becomes 0", chars["Odd-Realm"].level, 0)
check("a non-boolean track means tracked", chars["Odd-Realm"].track, true)
check("nothing recorded before login", chars["Kaptain-Realm"], nil)

capture(function()
	FireEvent("PLAYER_LOGIN")
end)
local me = chars["Kaptain-Realm"]
check("first login records the character", me ~= nil, true)
check("name", me.name, "Kaptain")
check("realm", me.realm, "Realm")
check("class", me.class, "WARRIOR")
check("level", me.level, 10)
check("seen", me.seen, Clock)
check("tracked by default", me.track, true)
check("Tracked says so", root.Tracked("Kaptain-Realm"), true)
check("an unknown key counts as tracked", root.Tracked("Nobody-Nowhere"), true)

-- A level 1 bank alt is tracked too.
Player = { name = "Mule", realm = "Realm", class = "ROGUE", level = 1 }
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("a level 1 alt is recorded", chars["Mule-Realm"] ~= nil, true)
check("and tracked", root.Tracked("Mule-Realm"), true)
check("its level", chars["Mule-Realm"].level, 1)

Player.level = 2
FireEvent("PLAYER_LEVEL_UP", 3) -- the event's level wins over a UnitLevel that lags
check("level-up updates the level", chars["Mule-Realm"].level, 3)
Clock = Clock + 100
FireEvent("PLAYER_LOGOUT")
check("logout refreshes seen", chars["Mule-Realm"].seen, Clock)
local secretLevel = Secret()
FireEvent("PLAYER_LEVEL_UP", secretLevel)
check("a secret level is ignored", chars["Mule-Realm"].level, 2)

-- ---------------------------------------------------------------- track, untrack, find

local changed, forgot = 0, {}
root.OnCharsChanged(function()
	changed = changed + 1
end)
root.OnForgetChar(function(key)
	forgot[#forgot + 1] = key
end)
check("SetTracked(false)", root.SetTracked("Mule-Realm", false), true)
check("an untracked character is not tracked", root.Tracked("Mule-Realm"), false)
check("the change listener ran", changed, 1)
root.SetTracked("Mule-Realm", true)
check("tracked again", root.Tracked("Mule-Realm"), true)
check("SetTracked on an unknown key does nothing", root.SetTracked("Nobody-Nowhere", false), false)
check("and does not notify", changed, 2)

local list = root.CharList()
check("the list holds every character", #list, 4)
check("tracked first, newest seen first", list[1].key, "Mule-Realm")
check("the opted-out character is last", list[#list].key, "Old-Realm")

chars["Mule-Other"] = { name = "Mule", realm = "Other", class = "ROGUE", level = 5, seen = 1, track = true }
check("FindChar: an exact key", (root.FindChar("Mule-Realm")), "Mule-Realm")
check("FindChar: a key in any case", (root.FindChar("mule-other")), "Mule-Other")
check("FindChar: a unique name", (root.FindChar("kaptain")), "Kaptain-Realm")
local key, found = root.FindChar("mule")
check("FindChar: an ambiguous name finds nothing", key, nil)
check("FindChar: and lists the candidates", table.concat(found, ","), "Mule-Other,Mule-Realm")
key, found = root.FindChar("ghost")
check("FindChar: an unknown name", key == nil and #found == 0, true)

-- ---------------------------------------------------------------- slash commands

local out = kw("untrack mule-realm")
check("/kw untrack <name>", root.Tracked("Mule-Realm"), false)
check("it says so", has(out, "Mule-Realm"), true)
kw("track mule-realm")
check("/kw track <name>", root.Tracked("Mule-Realm"), true)
kw("untrack")
check("/kw untrack with no name: this character", root.Tracked("Mule-Realm"), false)
kw("track")
check("/kw track with no name", root.Tracked("Mule-Realm"), true)
out = kw("untrack mule")
check("an ambiguous name changes nothing", root.Tracked("Mule-Realm") and root.Tracked("Mule-Other"), true)
check("and lists the matches", has(out, "Mule-Other") and has(out, "Mule-Realm"), true)
check("and asks for Name-Realm", has(out, "Name-Realm"), true)

out = kw("forget mule-realm")
check("forget refuses the current character", chars["Mule-Realm"] ~= nil, true)
check("and says why", has(out, "playing"), true)
out = kw("forget mule")
check("forget with an ambiguous name keeps both", chars["Mule-Realm"] ~= nil and chars["Mule-Other"] ~= nil, true)
out = kw("forget")
check("forget needs a name", has(out, "<name>"), true)
out = kw("forget nobody")
check("forget of an unknown name says so", has(out, "no character"), true)

-- A fortune record for that character goes with it; saved setups do not.
fortune.db.chars = { ["Mule-Other"] = { got = Clock - 600 } }
setups.db.setups[7] = { id = 7, name = "Mule-Other (auto)", auto = true, source = "Mule-Other", updated = Clock, parts = {}, counts = {} }
changed = 0
out = kw("forget mule-other")
check("forget removes the roster record", chars["Mule-Other"], nil)
check("the forget listeners hear the key", forgot[#forgot], "Mule-Other")
check("the change listener ran too", changed >= 1, true)
check("Sayge's record is dropped", fortune.db.chars["Mule-Other"], nil)
check("a saved snapshot is kept", setups.db.setups[7] ~= nil, true)
setups.db.setups[7] = nil
out = kw("help")
check("/kw list names the new commands", has(out, "/kw chars") and has(out, "forget"), true)

-- ---------------------------------------------------------------- Setups

Player = { name = "Kaptain", realm = "Realm", class = "WARRIOR", level = 10 }
check("Setups uses the roster's key", setups.CharKey(), root.CharKey())
Actions = { [1] = { "spell", 78 } }
KnownSpells = { [78] = "Heroic Strike" }
root.SetTracked("Kaptain-Realm", false)
RunTimers() -- the login delay
check("an untracked character gets no auto snapshot", count_keys(setups.db.setups), 0)
check("AutoSnapshot says no", setups.AutoSnapshot(), nil)
check("and a change does not start one", count_keys(setups.db.setups), 0)
root.SetTracked("Kaptain-Realm", true)
local snap = setups.AutoSnapshot()
check("tracked again: a snapshot is taken", snap ~= nil and count_keys(setups.db.setups), 1)
check("it is listed", #setups.List(), 1)
local status = setups.HubStatus()
check("the hub card counts it", status:find("1 setup", 1, true) ~= nil, true)
root.SetTracked("Kaptain-Realm", false)
check("untracked: the snapshot stays saved", count_keys(setups.db.setups), 1)
check("but is not listed", #setups.List(), 0)
check("nor offered", #setups.Offers(), 0)
check("nor counted on the hub card", setups.HubStatus():find("0 setups", 1, true) ~= nil, true)
out = capture(function()
	setups.OnSlash("list")
end)
check("/kws list leaves it out", #out, 0)
setups.OnOpen()
local sf = KroolWorldForeverSetupsFrame
check("the Setups window opens", sf:IsShown(), true)
local shown = 0
for _, row in ipairs(sf.rows) do
	shown = shown + (row:IsShown() and 1 or 0)
end
check("its Characters list leaves the character out", shown, 0)
root.SetTracked("Kaptain-Realm", true)
shown = 0
for _, row in ipairs(sf.rows) do
	shown = shown + (row:IsShown() and 1 or 0)
end
check("tracking again refreshes the window: the row is back", shown, 1)
check("and the list", #setups.List(), 1)
sf:Hide()
-- A named setup is never hidden.
local named = setups.SaveNew("Mine")
root.SetTracked("Kaptain-Realm", false)
check("a named setup stays listed", #setups.List(), 1)
check("and is the one that stays", setups.List()[1].id, named.id)
root.SetTracked("Kaptain-Realm", true)

-- ---------------------------------------------------------------- Sayge's Fortune

-- A realm whose display name has a space: the old key kept it, the roster's does not.
Player = { name = "Spacey", realm = "MirageRaceway", realmName = "Mirage Raceway", class = "MAGE", level = 20 }
check("the roster key drops the realm's spaces", root.CharKey(), "Spacey-MirageRaceway")
chars["Pal-MirageRaceway"] = { name = "Pal", realm = "MirageRaceway", class = "MAGE", level = 9, seen = 5, track = true }
fortune.db.chars = {
	["Spacey-Mirage Raceway"] = { got = Clock - 100, kind = "Armor", left = 100, at = Clock },
	["Pal-Mirage Raceway"] = { got = Clock - 200, kind = "Damage", left = 100, at = Clock },
	["Stranger-Mirage Raceway"] = { got = Clock - 300, kind = "Spirit", left = 100, at = Clock },
}
fortune.keysMigrated = nil -- a new session
local rec, mineKey = fortune.Mine()
check("Mine finds the old record under the new key", mineKey, "Spacey-MirageRaceway")
check("and it is the same record", rec and rec.kind, "Armor")
check("the old key is gone", fortune.db.chars["Spacey-Mirage Raceway"], nil)
check("a roster character's record moves too", fortune.db.chars["Pal-MirageRaceway"] ~= nil and fortune.db.chars["Pal-Mirage Raceway"] == nil, true)
check("an unknown character's record waits for its login", fortune.db.chars["Stranger-Mirage Raceway"] ~= nil, true)

fortune.db.chars = {
	["Spacey-Mirage Raceway"] = { got = Clock - 50, kind = "New" },
	["Spacey-MirageRaceway"] = { got = Clock - 500, kind = "Old" },
}
fortune.MigrateKeys()
check("both keys: the newer fortune is kept", fortune.db.chars["Spacey-MirageRaceway"].kind, "New")
check("both keys: one record left", count_keys(fortune.db.chars), 1)
fortune.db.chars = {
	["Spacey-Mirage Raceway"] = { got = Clock - 500, kind = "Older" },
	["Spacey-MirageRaceway"] = { got = Clock - 50, kind = "Newer" },
}
fortune.MigrateKeys()
check("both keys: the existing one wins when it is newer", fortune.db.chars["Spacey-MirageRaceway"].kind, "Newer")

-- The other-characters list shows tracked characters only.
chars["Tracked-MirageRaceway"] = { name = "Tracked", realm = "MirageRaceway", class = "MAGE", level = 9, seen = 5, track = true }
chars["Hidden-MirageRaceway"] = { name = "Hidden", realm = "MirageRaceway", class = "MAGE", level = 9, seen = 5, track = false }
fortune.db.chars = {
	["Spacey-MirageRaceway"] = { got = Clock - 100, kind = "Armor", left = 100, at = Clock },
	["Tracked-MirageRaceway"] = { got = Clock - 200, kind = "Damage", left = 100, at = Clock },
	["Hidden-MirageRaceway"] = { got = Clock - 300, kind = "Spirit", left = 100, at = Clock },
}
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_FORTUNE("")
end)
check("Sayge lists a tracked character", has(out, "Tracked-MirageRaceway"), true)
check("and leaves an untracked one out", has(out, "Hidden-MirageRaceway"), false)
check("it still reports on this character", has(out, "Other characters"), true)
root.SetTracked("Hidden-MirageRaceway", true)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_FORTUNE("")
end)
check("tracked again: back in the list", has(out, "Hidden-MirageRaceway"), true)
kw("fortune off")
check("fortune off: Sayge's tooltip hook and slash go quiet", fortune.enabled, false)

-- ---------------------------------------------------------------- the window

Player = { name = "Kaptain", realm = "Realm", class = "WARRIOR", level = 10 }
root.SetTracked("Hidden-MirageRaceway", false)
out = kw("chars")
local win = KroolWorldForeverCharacters
check("/kw chars opens the window", win ~= nil and win:IsShown(), true)
check("one row per character", #win.rows >= 1, true)
local shownRows = 0
for _, row in ipairs(win.rows) do
	shownRows = shownRows + (row:IsShown() and 1 or 0)
end
check("every character has a row", shownRows, #root.CharList())
local first = win.rows[1]
check("tracked characters come first", chars[first.key].track, true)
local lastRow = win.rows[shownRows]
check("untracked ones come last", chars[lastRow.key].track, false)
check("the intro explains it", win.intro.text:find("left out of Reagent Uses, Sayge's Fortune", 1, true) ~= nil, true)
check("the Track box mirrors the state", first.check.checked, true)
check("and the opted-out one is unchecked", lastRow.check.checked, false)
check("last seen reads today for the current character", has({ first.seen.text, win.rows[2].seen.text }, "today") or has({ first.seen.text }, "today"), true)
check("days ago", root.CharsAgo(Clock - 3 * 86400, Clock), "3d ago")
check("today", root.CharsAgo(Clock - 60, Clock), "today")
check("never seen", root.CharsAgo(0, Clock), "?")

local key1 = first.key
first.check:SetChecked(false)
first.check:Click()
check("unchecking Track untracks", root.Tracked(key1), false)
check("the list re-sorts", win.rows[1].key ~= key1 or root.Tracked(win.rows[1].key), true)
local row2
for _, row in ipairs(win.rows) do
	if row.key == key1 then
		row2 = row
	end
end
row2.check:SetChecked(true)
row2.check:Click()
check("checking Track tracks again", root.Tracked(key1), true)
kw("chars")
check("/kw chars again closes it", win:IsShown(), false)

-- ---------------------------------------------------------------- the hub

root.OpenHub()
local hub = root.HubFrame()
check("the hub opens", hub:IsShown(), true)
check("the hub has a Characters button", hub.chars.text, "Characters")
check("and the current character's switch", hub.track.text, "Stop Tracking This Character")
hub.track:Click()
check("the button untracks this character", root.Tracked("Kaptain-Realm"), false)
check("and says how to undo it", hub.track.text, "Track This Character")
hub.track:Click()
check("clicking again tracks it", root.Tracked("Kaptain-Realm"), true)
check("the label goes back", hub.track.text, "Stop Tracking This Character")
kw("untrack")
check("a slash command updates the open hub", hub.track.text, "Track This Character")
kw("track")
hub.chars:Click()
check("the Characters button opens the window", win:IsShown(), true)
check("and the hub steps aside", hub:IsShown(), false)
win:Hide()

-- Logging in as someone new adds a row and the hub offers the switch.
Player = { name = "Newbie", realm = "Realm", class = "PRIEST", level = 1 }
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("a new character is recorded at login", chars["Newbie-Realm"] ~= nil and chars["Newbie-Realm"].track, true)

print(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error("characters tests failed")
end
