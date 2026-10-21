-- Setups: save a character's setup (action bars, keybindings, macros, Edit Mode layout, server-stored
-- interface settings, addon list) and apply it to another character. Storage is account-wide
-- (ns.db.setups), so every character on this PC sees every saved setup.
--
-- Apply is the one feature that changes the player's UI; the owner asked for it explicitly. It only
-- runs out of combat, on a click, keeps an undo snapshot of the target first, and reports every slot
-- or binding it could not restore instead of failing.

local _, root = ...
local ns = root.Feature("setups")

ns.PARTS = {
	{ key = "bars", label = "Action Bars" },
	{ key = "bindings", label = "Keybindings" },
	{ key = "macros", label = "Macros" },
	{ key = "editmode", label = "Edit Mode Layout" },
	{ key = "cvars", label = "Interface Settings" },
	{ key = "addons", label = "Addon List" },
}
ns.RELOAD_PARTS = { editmode = true, addons = true } -- take effect after /reload

local MAX_SLOTS = 180
local ACCOUNT_BINDINGS, CHARACTER_BINDINGS = 1, 2
local SELF = "KroolWorldForever"

-- -------------------------------------------------------------------- identity

function ns.CharKey()
	local name, realm = UnitFullName("player")
	realm = (realm and realm ~= "") and realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or "?"
	return (name or "?") .. "-" .. realm
end

local function Now()
	return time()
end

local function PlayerGUID()
	local guid = UnitGUID("player")
	if guid == nil or (issecretvalue and issecretvalue(guid)) then
		return nil
	end
	return guid
end

-- Registers this character and says whether it is new. A name can come back as a different
-- character (deleted and remade, or the stress test's characters reused at launch): the GUID tells
-- them apart. The earlier character's auto snapshot is kept as a named setup, so it can be applied.
function ns.Identify()
	local key, guid = ns.CharKey(), PlayerGUID()
	local c = ns.db.chars[key]
	if c and guid and c.guid and c.guid ~= guid then
		local old = ns.Get(c.auto)
		if old then
			old.auto = nil
			old.name = ("%s (earlier character)"):format(key)
		end
		if ns.db.undo then
			ns.db.undo[key] = nil
		end
		c = nil
	end
	local isNew = c == nil
	if not c then
		c = { first = Now() }
		ns.db.chars[key] = c
	end
	c.guid = c.guid or guid
	return isNew, c
end

-- -------------------------------------------------------------------- capture

local capture = {}

function capture.bars()
	local out, n = {}, 0
	for slot = 1, MAX_SLOTS do
		local kind, id = GetActionInfo(slot)
		local e
		if kind == "spell" then
			e = { t = "spell", id = id, name = C_Spell.GetSpellName(id) }
		elseif kind == "item" then
			e = { t = "item", id = id }
		elseif kind == "macro" then
			local name = C_ActionBar.GetActionText(slot)
			if name and name ~= "" then
				e = { t = "macro", name = name }
			end
		elseif kind == "summonmount" then
			e = { t = "mount", id = id }
		elseif kind then
			e = { t = kind, id = id } -- kept for the report; not restorable
		end
		if e then
			out[slot] = e
			n = n + 1
		end
	end
	return out, n
end

function capture.bindings()
	local out = {}
	for i = 1, GetNumBindings() do
		local command, _, key1, key2 = GetBinding(i)
		if command and key1 then
			out[#out + 1] = { command, key1, key2 }
		end
	end
	return out, #out
end

function capture.macros()
	local out = {}
	local numAccount, numChar = GetNumMacros()
	local function add(index, perChar)
		local name, icon, body = GetMacroInfo(index)
		if name then
			out[#out + 1] = { name = name, icon = icon, body = body or "", char = perChar }
		end
	end
	for i = 1, numAccount or 0 do
		add(i, false)
	end
	local charStart = (MAX_ACCOUNT_MACROS or 120) + 1
	for i = charStart, charStart + (numChar or 0) - 1 do
		add(i, true)
	end
	return out, #out
end

-- Blizzard's built-in layouts. C_EditMode.GetLayouts() returns only saved layouts, but its
-- activeLayout index and SaveLayouts() count the built-in ones first (EditModeManager does the same).
local function Presets()
	local mgr = EditModePresetLayoutManager
	if mgr and mgr.GetCopyOfPresetLayouts then
		local ok, presets = pcall(mgr.GetCopyOfPresetLayouts, mgr)
		if ok and type(presets) == "table" then
			return presets
		end
	end
end

local function PresetCount()
	local presets = Presets()
	if presets then
		return #presets
	end
	local n = 0
	for _ in pairs(Enum.EditModePresetLayouts or {}) do
		n = n + 1
	end
	return n > 0 and n or 2
end

function capture.editmode()
	local info = C_EditMode.GetLayouts()
	if not info or not info.activeLayout then
		return nil, 0
	end
	local presets = PresetCount()
	if info.activeLayout <= presets then
		return { preset = info.activeLayout }, 1
	end
	local layout = info.layouts[info.activeLayout - presets]
	if not layout then
		return nil, 0
	end
	return { name = layout.layoutName, str = C_EditMode.ConvertLayoutInfoToString(layout) }, 1
end

-- Server-stored CVars that are game state, not preferences: copying them would carry tutorial
-- progress, "seen" flags or collapsed lists between characters, and resetting them would replay
-- tutorials. Lua patterns, matched against the lowercased name. Not "shown": it would also match
-- preferences like nameplateShowNeutral ("showneutral").
local STATE_CVARS = {
	"tutorial", "seen", "collapsed", "closedinfoframes", "needs", "flagged", "^cache", "^last", "^latest",
	"^highest", "acknowledged", "actioned", "tracked", "alreadyshown",
}
-- The same, recognized by the CVar's help text (ConsoleGetAllCommands gives it at runtime).
-- Not a bare "^stores": "Stores whether to ..." also describes real preferences (showQuestLevel).
-- Checked against Forever's full CVar list (Ketho dump, build 70338): excludes ~90 state CVars and
-- keeps preferences such as the cast-audio options ("Stores the voice to use ...").
local STATE_HELP = {
	"^internal", "^%(internal", "serialized", "already shown", "has been shown", "^stores the last",
	"^stores the number", "^saves current", "pending completion",
}

local function IsStateCVar(name, help)
	local lower = name:lower()
	for _, pattern in ipairs(STATE_CVARS) do
		if lower:find(pattern) then
			return true
		end
	end
	help = (help or ""):lower()
	for _, pattern in ipairs(STATE_HELP) do
		if help:find(pattern) then
			return true
		end
	end
	return false
end
ns.IsStateCVar = IsStateCVar

-- Only settings Blizzard stores on its servers: those are the interface choices that follow a
-- character, and the ones a wipe or a new character loses. Graphics and sound live in Config.wtf.
local function ServerCVars()
	local list = {}
	local cvarType = Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar or 0
	for _, cmd in ipairs(ConsoleGetAllCommands() or {}) do
		if cmd.commandType == cvarType and not IsStateCVar(cmd.command, cmd.help) then
			local value, default, account, character, locked, secure, readOnly = C_CVar.GetCVarInfo(cmd.command)
			if value ~= nil and (account or character) and not (locked or secure or readOnly) then
				list[#list + 1] = { name = cmd.command, value = value, default = default }
			end
		end
	end
	return list
end
ns.ServerCVars = ServerCVars

function capture.cvars()
	local out, n = {}, 0
	for _, c in ipairs(ServerCVars()) do
		if c.value ~= c.default then
			out[c.name] = c.value
			n = n + 1
		end
	end
	return out, n
end

function capture.addons()
	local out, n = {}, 0
	local me = UnitName("player")
	for i = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(i)
		if name then
			out[name] = (C_AddOns.GetAddOnEnableState(name, me) or 0) > 0
			n = n + 1
		end
	end
	return out, n
end

-- Captures the given parts (all when nil). Returns parts, counts.
function ns.Capture(which)
	local parts, counts = {}, {}
	for _, p in ipairs(ns.PARTS) do
		if not which or which[p.key] then
			local ok, data, n = pcall(capture[p.key])
			if ok then
				parts[p.key], counts[p.key] = data, n or 0
			else
				counts[p.key] = 0
				ns.lastCaptureError = tostring(data)
			end
		end
	end
	return parts, counts
end

-- -------------------------------------------------------------------- apply

local apply = {}

local function Same(slot, want)
	local kind, id = GetActionInfo(slot)
	if not want then
		return kind == nil
	end
	if want.t == "macro" then
		return kind == "macro" and C_ActionBar.GetActionText(slot) == want.name
	end
	local map = { spell = "spell", item = "item", mount = "summonmount" }
	return kind == map[want.t] and id == want.id
end

local function MountIndex(mountID)
	for i = 1, C_MountJournal.GetNumDisplayedMounts() do
		if C_MountJournal.GetDisplayedMountID(i) == mountID then
			return i
		end
	end
end

-- Puts the action on the cursor. Returns true when something is on it.
local function Pickup(want)
	ClearCursor()
	if want.t == "spell" then
		C_Spell.PickupSpell(want.id)
		if not GetCursorInfo() and want.name then
			C_Spell.PickupSpell(want.name) -- another rank, or a renamed id
		end
	elseif want.t == "item" then
		C_Item.PickupItem(want.id)
	elseif want.t == "macro" then
		local index = GetMacroIndexByName(want.name)
		if index and index > 0 then
			PickupMacro(index)
		end
	elseif want.t == "mount" then
		local index = MountIndex(want.id)
		if index then
			C_MountJournal.Pickup(index)
		end
	end
	return GetCursorInfo() ~= nil
end

local function Describe(want)
	if want.t == "spell" then
		return want.name or ("spell " .. tostring(want.id))
	elseif want.t == "macro" then
		return "macro " .. tostring(want.name)
	end
	return want.t .. " " .. tostring(want.id)
end

-- A slot whose action this character cannot use (unknown spell, item not owned) keeps whatever
-- the character already has there; only slots the setup leaves empty are cleared (clearEmpty).
function apply.bars(data, opts, report)
	if next(data) == nil and not opts.isUndo then
		-- Clearing every slot from an empty capture is never what anyone wants. (Undo may: it puts
		-- back bars that really were empty.)
		report.lines[#report.lines + 1] = "Action Bars: the setup has no bar slots saved; left your bars alone"
		return
	end
	local placed, cleared, skipped = 0, 0, {}
	for slot = 1, MAX_SLOTS do
		local want = data[slot]
		if want and not Same(slot, want) then
			if Pickup(want) then
				PlaceAction(slot)
				placed = placed + 1
			else
				skipped[#skipped + 1] = ("slot %d: %s"):format(slot, Describe(want))
			end
			ClearCursor()
		elseif not want and opts.clearEmpty and C_ActionBar.HasAction(slot) then
			ClearCursor()
			PickupAction(slot)
			ClearCursor()
			cleared = cleared + 1
		end
	end
	report.lines[#report.lines + 1] = ("Action Bars: %d placed, %d cleared, %d not available"):format(placed, cleared, #skipped)
	for i = 1, math.min(#skipped, 12) do
		report.lines[#report.lines + 1] = "  - " .. skipped[i]
	end
	if #skipped > 12 then
		report.lines[#report.lines + 1] = ("  - and %d more"):format(#skipped - 12)
	end
end

function apply.bindings(data, opts, report)
	if #data == 0 and not opts.isUndo then
		report.lines[#report.lines + 1] = "Keybindings: the setup has no keybindings saved; left yours alone"
		return
	end
	-- Full replace: clear every current key, then bind the setup's. The undo snapshot has the old set.
	for i = 1, GetNumBindings() do
		local _, _, key1, key2 = GetBinding(i)
		if key1 then
			SetBinding(key1)
		end
		if key2 then
			SetBinding(key2)
		end
	end
	local bound, failed = 0, 0
	for _, b in ipairs(data) do
		for k = 2, 3 do
			local key = b[k]
			if key then
				if SetBinding(key, b[1]) then
					bound = bound + 1
				else
					failed = failed + 1
				end
			end
		end
	end
	SaveBindings(opts.perCharBinds and CHARACTER_BINDINGS or ACCOUNT_BINDINGS)
	report.lines[#report.lines + 1] = ("Keybindings: %d keys bound%s, saved %s"):format(
		bound,
		failed > 0 and (", " .. failed .. " for commands not available (an addon not loaded?)") or "",
		opts.perCharBinds and "for this character" or "for the account"
	)
end

function apply.macros(data, _, report)
	local created, kept, failed = 0, {}, {}
	for _, m in ipairs(data) do
		local index = GetMacroIndexByName(m.name)
		if index and index > 0 then
			local _, _, body = GetMacroInfo(index)
			if (body or "") ~= m.body then
				kept[#kept + 1] = m.name
			end
		else
			local ok = pcall(CreateMacro, m.name, m.icon or "INV_MISC_QUESTIONMARK", m.body, m.char)
			if ok and (GetMacroIndexByName(m.name) or 0) > 0 then
				created = created + 1
			else
				failed[#failed + 1] = m.name
			end
		end
	end
	report.lines[#report.lines + 1] = ("Macros: %d created"):format(created)
	if #kept > 0 then
		report.lines[#report.lines + 1] = "  - kept your existing macro with the same name: " .. table.concat(kept, ", ")
	end
	if #failed > 0 then
		report.lines[#report.lines + 1] = "  - could not create (macro slots full?): " .. table.concat(failed, ", ")
	end
end

local function UniqueLayoutName(layouts, name)
	local taken = {}
	for _, l in ipairs(layouts) do
		taken[l.layoutName] = true
	end
	local candidate, n = name, 2
	while taken[candidate] do
		candidate = name .. " " .. n
		n = n + 1
	end
	return candidate
end

function apply.editmode(data, _, report)
	if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
		-- Its in-memory layouts (and any unsaved changes) would fight ours.
		report.lines[#report.lines + 1] = "Edit Mode: close Edit Mode first, then apply again"
		return
	end
	if data.preset or data.restore then
		C_EditMode.SetActiveLayout(data.preset or data.restore)
		report.lines[#report.lines + 1] = data.preset and "Edit Mode: switched to a built-in layout"
			or "Edit Mode: switched back to the previous layout"
		return
	end
	local layout = data.str and C_EditMode.ConvertStringToLayoutInfo(data.str)
	if not layout then
		report.lines[#report.lines + 1] = "Edit Mode: the saved layout could not be read"
		return
	end
	local presets = Presets()
	if not presets then
		report.lines[#report.lines + 1] = "Edit Mode: Blizzard's layout list is not loaded; open Edit Mode once and apply again"
		return
	end
	local info = C_EditMode.GetLayouts()
	local saved = info.layouts or {}
	-- The same layout already saved here (e.g. a character re-applying its own setup): switch to it.
	for i, l in ipairs(saved) do
		local ok, str = pcall(C_EditMode.ConvertLayoutInfoToString, l)
		if ok and str == data.str then
			C_EditMode.SetActiveLayout(#presets + i)
			report.lines[#report.lines + 1] = ('Edit Mode: switched to your existing layout "%s"'):format(l.layoutName)
			return
		end
	end
	local count = 0
	for _, l in ipairs(saved) do
		if l.layoutType == Enum.EditModeLayoutType.Character then
			count = count + 1
		end
	end
	local max = Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType or 5
	if count >= max then
		report.lines[#report.lines + 1] = ("Edit Mode: this character already has %d layouts; delete one in Edit Mode and apply again"):format(max)
		return
	end
	layout.layoutType = Enum.EditModeLayoutType.Character
	layout.layoutName = UniqueLayoutName(saved, data.name or "Setup")
	if not C_EditMode.IsValidLayoutName(layout.layoutName) then
		layout.layoutName = UniqueLayoutName(saved, "Setup")
	end
	-- Same shape EditModeManagerFrameMixin:MakeNewLayout saves: built-in layouts first, then saved ones.
	local all = presets
	for _, l in ipairs(saved) do
		all[#all + 1] = l
	end
	all[#all + 1] = layout
	C_EditMode.SaveLayouts({ layouts = all, activeLayout = info.activeLayout })
	C_EditMode.OnLayoutAdded(#all, true, true)
	report.lines[#report.lines + 1] = ('Edit Mode: added layout "%s" for this character'):format(layout.layoutName)
end

function apply.cvars(data, _, report)
	local set, failed = 0, 0
	for _, c in ipairs(ServerCVars()) do
		local want = data[c.name]
		if want == nil then
			want = c.default -- copying a setup also resets what it left at default
		end
		if c.value ~= want then
			if pcall(C_CVar.SetCVar, c.name, want) then
				set = set + 1
			else
				failed = failed + 1
			end
		end
	end
	report.lines[#report.lines + 1] = ("Interface Settings: %d changed%s"):format(set, failed > 0 and (", " .. failed .. " refused") or "")
end

function apply.addons(data, _, report)
	local me = UnitName("player")
	local changed, missing = 0, {}
	local installed = {}
	for i = 1, C_AddOns.GetNumAddOns() do
		installed[(C_AddOns.GetAddOnInfo(i))] = true
	end
	for name, on in pairs(data) do
		if not installed[name] then
			if on then
				missing[#missing + 1] = name
			end
		elseif name ~= SELF then
			local now = (C_AddOns.GetAddOnEnableState(name, me) or 0) > 0
			if now ~= on then
				if on then
					C_AddOns.EnableAddOn(name, me)
				else
					C_AddOns.DisableAddOn(name, me)
				end
				changed = changed + 1
			end
		end
	end
	table.sort(missing)
	report.lines[#report.lines + 1] = ("Addon List: %d changed"):format(changed)
	if #missing > 0 then
		report.lines[#report.lines + 1] = "  - not installed here: " .. table.concat(missing, ", ")
	end
end

-- Applies the chosen parts of a setup to the current character.
-- Returns report { ok, lines, reload } where reload means a /reload finishes the job.
function ns.Apply(setup, which, opts)
	local report = { ok = false, lines = {}, reload = false }
	if InCombatLockdown() then
		report.lines[1] = "Not in combat. Try again when combat ends."
		return report
	end
	if GetCursorInfo() then
		report.lines[1] = "Your cursor is holding something. Drop it and try again."
		return report
	end
	opts = opts or {}
	-- Undo first: everything this apply may touch, as it is now. Macros are never changed (only
	-- created), and Edit Mode is undone by switching back, not by re-adding the old layout.
	if not opts.isUndo then
		local undoParts = ns.Capture(which)
		undoParts.macros = nil
		if undoParts.editmode then
			local info = C_EditMode.GetLayouts()
			undoParts.editmode = info and info.activeLayout and { restore = info.activeLayout } or nil
		end
		ns.db.undo = ns.db.undo or {}
		ns.db.undo[ns.CharKey()] = {
			at = Now(),
			from = setup.name,
			parts = undoParts,
			charBinds = GetCurrentBindingSet() == CHARACTER_BINDINGS,
		}
	end

	-- Macros before bars, so macro buttons find their macro.
	for _, key in ipairs({ "macros", "bars", "bindings", "cvars", "addons", "editmode" }) do
		local data = setup.parts and setup.parts[key]
		if which[key] and data then
			local ok, err = pcall(apply[key], data, opts, report)
			if not ok then
				report.lines[#report.lines + 1] = ("%s: failed (%s)"):format(key, tostring(err))
			elseif ns.RELOAD_PARTS[key] then
				report.reload = true
			end
		end
	end
	ClearCursor()
	report.ok = true
	return report
end

-- -------------------------------------------------------------------- storage

function ns.List()
	local list = {}
	for _, s in pairs(ns.db.setups) do
		list[#list + 1] = s
	end
	table.sort(list, function(a, b)
		if (a.auto and true or false) ~= (b.auto and true or false) then
			return not a.auto -- named setups first
		end
		return (a.updated or 0) > (b.updated or 0)
	end)
	return list
end

function ns.Get(id)
	return id and ns.db.setups[id]
end

local function Stamp(s, parts, counts)
	local _, classFile = UnitClass("player")
	s.parts, s.counts = parts, counts
	s.source, s.class, s.level, s.updated = ns.CharKey(), classFile, UnitLevel("player"), Now()
end

-- Saves the current character as a new named setup. Returns it.
function ns.SaveNew(name)
	ns.db.nextId = (ns.db.nextId or 0) + 1
	local s = { id = ns.db.nextId, name = name, created = Now() }
	Stamp(s, ns.Capture())
	ns.db.setups[s.id] = s
	return s
end

-- Overwrites a setup with the current character.
function ns.Update(id)
	local s = ns.Get(id)
	if s then
		Stamp(s, ns.Capture())
	end
	return s
end

function ns.Rename(id, name)
	local s = ns.Get(id)
	if s and name and name ~= "" then
		s.name = name
	end
end

function ns.Delete(id)
	ns.db.setups[id] = nil
	if ns.db.default == id then
		ns.db.default = nil
	end
	for _, c in pairs(ns.db.chars) do
		if c.auto == id then
			c.auto = nil
		end
	end
end

function ns.SetDefault(id)
	ns.db.default = (ns.db.default ~= id) and id or nil -- clicking the default again clears it
end

-- The per-character auto snapshot: one entry per character, refreshed after login and after changes.
function ns.AutoSnapshot()
	local key = ns.CharKey()
	local c = ns.db.chars[key] or {}
	ns.db.chars[key] = c
	local s = ns.Get(c.auto)
	if not s then
		ns.db.nextId = (ns.db.nextId or 0) + 1
		s = { id = ns.db.nextId, auto = true, created = Now() }
		ns.db.setups[s.id] = s
		c.auto = s.id
	end
	s.name = key .. " (auto)"
	local parts, counts = ns.Capture()
	-- An empty bar read while the old snapshot had slots means the client was not ready (or was
	-- tearing down): keep the old bars rather than saving an empty setup over a real one.
	if (counts.bars or 0) == 0 and s.counts and (s.counts.bars or 0) > 0 then
		parts.bars, counts.bars = s.parts.bars, s.counts.bars
	end
	Stamp(s, parts, counts)
	return s
end

function ns.Undo()
	local u = ns.db.undo and ns.db.undo[ns.CharKey()]
	if not u then
		return nil
	end
	local which = {}
	for k in pairs(u.parts) do
		which[k] = true
	end
	-- Restore exactly: empty slots stay empty, bindings go back to the set they were saved in.
	local report = ns.Apply({ name = "undo", parts = u.parts }, which, {
		isUndo = true,
		clearEmpty = true,
		perCharBinds = u.charBinds,
	})
	if report.ok then
		ns.db.undo[ns.CharKey()] = nil -- one level of undo
	end
	return report
end

-- Setups worth offering on this character: everything except its own auto snapshot.
function ns.Offers()
	local key, out = ns.CharKey(), {}
	for _, s in ipairs(ns.List()) do
		if not (s.auto and s.source == key) then
			out[#out + 1] = s
		end
	end
	return out
end

function ns.OnLoad()
	ns.db.setups = ns.db.setups or {}
	ns.db.chars = ns.db.chars or {}
	ns.db.version = ns.db.version or 1
end
