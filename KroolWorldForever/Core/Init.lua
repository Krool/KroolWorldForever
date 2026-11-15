-- Lifecycle: saved variables, login, slash commands. Loaded last so every feature has
-- declared itself before ADDON_LOADED.

local addonName, root = ...
local ID = root.ID

local function ApplyDefaults(F)
	local db = F.db
	if db.enabled == nil then
		db.enabled = F.defaultEnabled ~= false
	end
	for _, opt in ipairs(F.options) do
		if db[opt.key] == nil then
			db[opt.key] = opt.default
		end
	end
end

local function Load()
	_G[ID.db] = _G[ID.db] or {}
	local sv = _G[ID.db]
	sv.features = sv.features or {}
	sv.session = (tonumber(sv.session) or 0) + 1 -- one per load, to tell this session's errors apart
	root.session = sv.session
	for _, key in ipairs(root.featureOrder) do
		local F = root.features[key]
		sv.features[key] = sv.features[key] or {}
		F.db = sv.features[key]
		ApplyDefaults(F)
		if F.OnLoad then
			root.Try(F, "load", F.OnLoad)
		end
	end
	root.Try(nil, "settings panel", root.BuildSettings)
end

local function Login()
	root.loggedIn = true
	for _, key in ipairs(root.featureOrder) do
		local F = root.features[key]
		F.enabled = false
		if not F.embedded then
			root.SetEnabled(F, F.db.enabled)
		end
	end
end

-- -------------------------------------------------------------------- slash

local function FeatureState(F)
	return F.db.enabled and "|cff33ff99on|r" or "|cffff5555off|r"
end

-- How to turn a feature on again, for the "is off" line.
local function HowOn(F)
	if ID.standalone then
		return "Turn it on in Options > AddOns > " .. ID.title .. "."
	end
	return "Turn it on with /kw " .. F.key .. " on"
end

local function MainSlash(msg)
	local key, arg = strtrim(msg or ""):lower():match("^(%S*)%s*(.-)$")
	local F = root.features[key]
	if key == "" then
		root.OpenHub()
	elseif key == "settings" or key == "options" then
		root.OpenSettings()
	elseif key == "errors" then
		root.PrintErrors(arg)
	elseif key == "list" or key == "help" then
		root.Print("/kw opens the hub; /kw settings; /kw errors; /kw <feature> [on|off]:")
		for _, k in ipairs(root.featureOrder) do
			local f = root.features[k]
			print(("  %s - %s %s"):format(k, f.title or k, FeatureState(f)))
		end
	elseif F and (arg == "on" or arg == "off") then
		root.SetEnabled(F, arg == "on")
		F:Print(FeatureState(F))
	elseif F and F.OnOpen and F.enabled then
		root.Try(F, "opening", F.OnOpen) -- features with their own window open it
	elseif F then
		root.OpenSettings(F)
	else
		root.Print("unknown feature '" .. key .. "'. /kw list")
	end
end

-- A standalone's one command (the feature's own words): settings, errors and chars are answered
-- here, whether the feature is on or not; everything else is the feature's.
local function StandaloneSlash(F)
	return function(msg)
		local word, arg = strtrim(msg or ""):lower():match("^(%S*)%s*(.-)$")
		if word == "settings" then
			root.OpenSettings(F)
		elseif word == "errors" then
			root.PrintErrors(arg)
		elseif word == "chars" then
			if root.OpenChars then
				root.Try(nil, "characters", root.OpenChars)
			else
				root.Print("the character list is not available in this addon.")
			end
		elseif not F.enabled then
			F:Print("is off. " .. HowOn(F))
		elseif F.OnSlash then
			root.Try(F, "slash command", F.OnSlash, msg)
		elseif F.OnOpen then
			root.Try(F, "opening", F.OnOpen)
		else
			root.OpenSettings(F)
		end
	end
end

local function RegisterSlash()
	if ID.standalone then
		for _, key in ipairs(root.featureOrder) do
			local F = root.features[key]
			if not F.embedded then
				local words = F.slash or ID.slash
				for i, cmd in ipairs(words) do
					_G["SLASH_" .. ID.slashId .. i] = cmd
				end
				root.cmd = words[1]
				SlashCmdList[ID.slashId] = StandaloneSlash(F)
				return
			end
		end
		return
	end
	for i, cmd in ipairs(ID.mainSlash) do
		_G["SLASH_" .. ID.slashId .. i] = cmd
	end
	SlashCmdList[ID.slashId] = MainSlash
	for _, key in ipairs(root.featureOrder) do
		local F = root.features[key]
		if F.slash and F.OnSlash and not F.embedded then
			local id = ID.slashId .. "_" .. key:upper()
			for i, cmd in ipairs(F.slash) do
				_G["SLASH_" .. id .. i] = cmd
			end
			SlashCmdList[id] = function(msg)
				if not F.enabled then
					F:Print("is off. " .. HowOn(F))
					return
				end
				root.Try(F, "slash command", F.OnSlash, msg)
			end
		end
	end
end

_G[ID.addon .. "_OnCompartmentClick"] = function()
	if not root.yielded then
		root.OpenHub()
	end
end

-- -------------------------------------------------------------------- frame

-- A standalone next to the bundle: the bundle already has this feature, so stay fully off (no
-- settings, slash, hooks or frames) and say why once.
local function Yield()
	root.yielded = true
	root.frame:UnregisterAllEvents()
	print(ID.chat .. " is off: Krool World Forever already includes it. Disable one of them in the AddOns list.")
end

local frame = CreateFrame("Frame")
root.frame = frame
for _, key in ipairs(root.featureOrder) do
	for event in pairs(root.features[key].events) do
		root.WatchEvent(event)
	end
end
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		-- The bundle starts now; a standalone waits for login, when it can tell whether the bundle is loaded.
		if ... == addonName and not ID.standalone then
			root.Try(nil, "startup", Load)
			RegisterSlash()
		end
	elseif event == "PLAYER_LOGIN" then
		if ID.standalone then
			local ok, bundleLoaded = pcall(C_AddOns.IsAddOnLoaded, ID.bundle)
			if ok and bundleLoaded then
				Yield()
				return
			end
			root.Try(nil, "startup", Load)
			RegisterSlash()
		end
		Login()
	end
	root.Dispatch(event, ...)
end)
