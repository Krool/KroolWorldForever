-- Lifecycle: saved variables, login, slash commands. Loaded last so every feature has
-- declared itself before ADDON_LOADED.

local addonName, root = ...

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
	KroolWorldForeverDB = KroolWorldForeverDB or {}
	local sv = KroolWorldForeverDB
	sv.features = sv.features or {}
	for _, key in ipairs(root.featureOrder) do
		local F = root.features[key]
		sv.features[key] = sv.features[key] or {}
		F.db = sv.features[key]
		ApplyDefaults(F)
		if F.OnLoad then
			local ok, err = pcall(F.OnLoad)
			if not ok then
				F:Print("|cffff5555load failed|r: " .. tostring(err))
			end
		end
	end
	root.BuildSettings()
end

local function Login()
	root.loggedIn = true
	for _, key in ipairs(root.featureOrder) do
		local F = root.features[key]
		F.enabled = false
		root.SetEnabled(F, F.db.enabled)
	end
end

-- -------------------------------------------------------------------- slash

local function FeatureState(F)
	return F.db.enabled and "|cff33ff99on|r" or "|cffff5555off|r"
end

local function MainSlash(msg)
	local key, arg = strtrim(msg or ""):lower():match("^(%S*)%s*(.-)$")
	local F = root.features[key]
	if key == "" then
		root.OpenSettings()
	elseif key == "list" or key == "help" then
		root.Print("features (/kwf <feature> on|off):")
		for _, k in ipairs(root.featureOrder) do
			local f = root.features[k]
			print(("  %s - %s %s"):format(k, f.title or k, FeatureState(f)))
		end
	elseif F and (arg == "on" or arg == "off") then
		root.SetEnabled(F, arg == "on")
		F:Print(FeatureState(F))
	elseif F and F.OnOpen and F.enabled then
		F.OnOpen() -- features with their own window open it
	elseif F then
		root.OpenSettings(F)
	else
		root.Print("unknown feature '" .. key .. "'. /kwf list")
	end
end

local function RegisterSlash()
	SLASH_KROOLWORLDFOREVER1 = "/kwf"
	SLASH_KROOLWORLDFOREVER2 = "/kroolworld"
	SlashCmdList.KROOLWORLDFOREVER = MainSlash
	for _, key in ipairs(root.featureOrder) do
		local F = root.features[key]
		if F.slash and F.OnSlash then
			local id = "KROOLWORLDFOREVER_" .. key:upper()
			for i, cmd in ipairs(F.slash) do
				_G["SLASH_" .. id .. i] = cmd
			end
			SlashCmdList[id] = function(msg)
				if not F.enabled then
					F:Print("is off. Turn it on with /kwf " .. key .. " on")
					return
				end
				local ok, err = pcall(F.OnSlash, msg)
				if not ok then
					F:Print("|cffff5555failed|r: " .. tostring(err))
				end
			end
		end
	end
end

function KroolWorldForever_OnCompartmentClick()
	root.OpenSettings()
end

-- -------------------------------------------------------------------- frame

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
		if ... == addonName then
			Load()
			RegisterSlash()
		end
	elseif event == "PLAYER_LOGIN" then
		Login()
	end
	root.Dispatch(event, ...)
end)
