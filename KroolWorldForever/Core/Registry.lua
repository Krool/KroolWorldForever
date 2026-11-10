-- Feature registry. Every feature lives in Features/<Name>/ and gets one private table from
-- root.Feature(key), shared by that feature's files:
--
--   local _, root = ...
--   local ns = root.Feature("questtrash")
--   ns.title, ns.description          shown in the settings panel
--   ns.defaultEnabled                 default on/off (true when nil)
--   ns.options = { {key=, type="toggle"|"range", label=, tooltip=, default=, min=, max=, step=}, ... }
--   ns.slash = { "/fqt", "/questtrash" }; ns.OnSlash(msg)
--   ns.OnLoad()                       saved variables ready (ns.db is the feature's slice)
--   ns.OnEnable() / ns.OnDisable()    after login, whenever the feature turns on/off
--   ns.OnOptionChanged(key, value)
--   ns:RegisterEvent(event, fn)       fn(event, ...) runs only while the feature is enabled
--   ns.OnOpen()                       optional: the feature's own window; /kw <key> opens it, the
--                                     hub card gets an Open button, and so does the settings page
--   ns.icon, ns.blurb                 the hub card: an icon file and one short line
--   ns.HubStatus()                    optional: one short line on the hub card, what it is doing now
--   ns.HubAction()                    optional: { label, tip, fn } for a button on the hub card, or nil
--                                     (features without their own window only)
--   ns.actions = { {label=, tooltip=, fn=}, ... }   optional buttons on the feature's settings page
--
-- File scope must stay free of game calls so tools/settings-doc.js can load the definitions
-- outside the client. Do game work in OnLoad/OnEnable.

local addonName, root = ...

root.features = {}
root.featureOrder = {}
root.public = {}
KroolWorldForever = root.public -- public API: KroolWorldForever.QuestTrash, .KillValue, ...

-- Chat lines start with the addon's bag icon (border trimmed, sized to the chat font) and its name.
local PREFIX = "|TInterface\\Icons\\INV_Misc_Bag_10:0:0:0:0:64:64:5:59:5:59|t |cff33ffccKrool|cffffffffWorld|r"

local function Print(self, msg)
	print(PREFIX .. " " .. (self.title or self.key) .. ": " .. msg)
end

local function RegisterEvent(self, event, fn)
	self.events[event] = fn
	root.WatchEvent(event)
end

function root.Feature(key)
	local F = root.features[key]
	if not F then
		F = { key = key, options = {}, events = {}, enabled = false, Print = Print, RegisterEvent = RegisterEvent }
		root.features[key] = F
		root.featureOrder[#root.featureOrder + 1] = key
	end
	return F
end

function root.Print(msg)
	print(PREFIX .. ": " .. msg)
end

function root.Version()
	if not (C_AddOns and C_AddOns.GetAddOnMetadata) then
		return nil
	end
	local ok, v = pcall(C_AddOns.GetAddOnMetadata, addonName, "Version")
	return ok and type(v) == "string" and v or nil
end

-- -------------------------------------------------------------------- caught errors
-- The bundle never lets an error reach the client, so BugSack never sees one. root.Report prints
-- each distinct error once per session and logs it, with its stack and a count, to
-- KroolWorldForeverDB.errors (newest last): /kw errors in game, tools/bugs.js outside it.

root.ERRORS_MAX = 20
local printed = {} -- errors already in chat this session
local caught -- the stack of the error Catch saw last

local function Catch(err)
	caught = nil
	if type(debugstack) == "function" then
		local ok, s = pcall(debugstack, 2)
		caught = ok and type(s) == "string" and s or nil
	end
	return err
end

local function Text(v, max)
	local ok, s = pcall(tostring, v)
	s = ok and type(s) == "string" and s or "?"
	return #s > max and s:sub(1, max) or s
end

-- Records an error caught in F (nil: the core) while doing `where` ("UNIT_AURA", "tooltip", ...).
-- quiet: log only, no chat line (tooltips and hub lines, where a failure just shows nothing).
function root.Report(F, where, err, quiet)
	local stack = caught
	caught = nil
	local key, msg = F and F.key or "core", Text(err, 500)
	where = Text(where, 60)
	local sv = KroolWorldForeverDB
	if type(sv) == "table" then
		local log = type(sv.errors) == "table" and sv.errors or {}
		sv.errors = log
		local okT, now = pcall(time)
		local entry
		for i, e in ipairs(log) do
			if type(e) == "table" and e.feature == key and e.where == where and e.message == msg then
				entry = table.remove(log, i)
				break
			end
		end
		entry = entry or { feature = key, where = where, message = msg, count = 0, first = okT and now or nil }
		entry.count = (tonumber(entry.count) or 0) + 1
		entry.last, entry.session, entry.version = okT and now or nil, root.session, root.Version()
		entry.stack = stack and Text(stack, 2000) or entry.stack
		log[#log + 1] = entry
		while #log > root.ERRORS_MAX do
			table.remove(log, 1)
		end
	end
	local id = key .. "\31" .. where .. "\31" .. msg
	if quiet or printed[id] then
		return
	end
	printed[id] = true
	local line = "|cffff5555error|r in " .. where .. ": " .. msg .. " |cffaaaaaa(shown once; /kw errors)|r"
	if F and F.Print then
		F:Print(line)
	else
		root.Print(line)
	end
end

local function Settle(F, where, quiet, ok, ...)
	if not ok then
		root.Report(F, where, (...), quiet)
	end
	return ok, ...
end

-- pcall(fn, ...) that reports a failure (with its stack): root.Try prints it once, root.TryQuiet
-- only logs it. Both return what pcall would.
function root.Try(F, where, fn, ...)
	return Settle(F, where, false, xpcall(fn, Catch, ...))
end
function root.TryQuiet(F, where, fn, ...)
	return Settle(F, where, true, xpcall(fn, Catch, ...))
end

-- /kw errors: the log, newest first. arg "clear" empties it.
function root.PrintErrors(arg)
	local sv = KroolWorldForeverDB
	local log = type(sv) == "table" and type(sv.errors) == "table" and sv.errors or {}
	if arg == "clear" then
		if type(sv) == "table" then
			sv.errors = {}
		end
		for k in pairs(printed) do
			printed[k] = nil
		end
		root.Print("error log cleared")
		return
	end
	if #log == 0 then
		root.Print("no errors caught")
		return
	end
	root.Print(("%d error(s) caught, newest first (/kw errors clear empties the list):"):format(#log))
	for i = #log, 1, -1 do
		local e = log[i]
		if type(e) == "table" then
			local F = root.features[e.feature]
			local when = type(e.last) == "number" and type(date) == "function" and date("%b %d %H:%M", e.last) or "?"
			print(("  |cffff5555%s|r %s, %s, x%d (%s): %s"):format(F and F.title or tostring(e.feature), tostring(e.where), when, tonumber(e.count) or 1, tostring(e.version or "?"), tostring(e.message)))
		end
	end
end

-- True while the game hides aura data from addons (instances, Midnight's rules). Reading auras then
-- errors ("Auras cannot be accessed when secret while tainted") and the fields come back secret,
-- so features skip aura reads entirely. Unknown counts as hidden.
function root.AurasSecret()
	local S = C_Secrets
	if not (S and S.ShouldAurasBeSecret) then
		return false -- a client without the predicate has no secret auras
	end
	local ok, secret = pcall(S.ShouldAurasBeSecret)
	if not ok or (issecretvalue and issecretvalue(secret)) then
		return true
	end
	return secret == true
end

-- Events: one frame for the whole bundle, dispatched to enabled features.
local watched = {}
function root.WatchEvent(event)
	if root.frame and not watched[event] then
		watched[event] = true
		root.frame:RegisterEvent(event)
	end
end

function root.Dispatch(event, ...)
	for _, key in ipairs(root.featureOrder) do
		local F = root.features[key]
		local fn = F.events[event]
		if fn and F.enabled then
			root.Try(F, event, fn, event, ...)
		end
	end
end

-- Sets one declared option (or "enabled") the way the settings panel would: through the panel's
-- own setting object when it exists, so the panel shows the new value and its change callbacks run.
function root.SetOption(F, key, value)
	local setting = F.settingObjects and F.settingObjects[key]
	if setting and setting.SetValue then
		setting:SetValue(value, true) -- immediate: write now, not on the panel's Apply step
		return
	end
	if key == "enabled" then
		root.SetEnabled(F, value)
		return
	end
	F.db[key] = value
	if F.OnOptionChanged then
		F.OnOptionChanged(key, value)
	end
end

-- Turns a feature on or off after login. Persisted in its slice.
function root.SetEnabled(F, on)
	on = on and true or false
	F.db.enabled = on
	if F.enabled == on or not root.loggedIn then
		F.enabled = on and root.loggedIn or false
		return
	end
	F.enabled = on
	local hook = on and F.OnEnable or F.OnDisable
	if hook then
		root.Try(F, on and "turning on" or "turning off", hook)
	end
	if root.RefreshHub then
		pcall(root.RefreshHub) -- an open hub shows the new state
	end
end
