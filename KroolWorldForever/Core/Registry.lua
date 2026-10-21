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
--   ns.OnOpen()                       optional: the feature's own window; /kwf <key> opens it, and
--                                     the settings page gets an "Open" button
--
-- File scope must stay free of game calls so tools/settings-doc.js can load the definitions
-- outside the client. Do game work in OnLoad/OnEnable.

local addonName, root = ...

root.features = {}
root.featureOrder = {}
root.public = {}
KroolWorldForever = root.public -- public API: KroolWorldForever.QuestTrash, .KillValue, ...

local function Print(self, msg)
	print("|cff33ffccKrool|cffffffffWorld|r " .. (self.title or self.key) .. ": " .. msg)
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
	print("|cff33ffccKrool|cffffffffWorld|r: " .. msg)
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
			local ok, err = pcall(fn, event, ...)
			if not ok then
				F:Print("|cffff5555error|r in " .. event .. ": " .. tostring(err))
			end
		end
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
		local ok, err = pcall(hook)
		if not ok then
			F:Print("|cffff5555error|r turning " .. (on and "on" or "off") .. ": " .. tostring(err))
		end
	end
end
