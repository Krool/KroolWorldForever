local addonName, ns = ...

local DEFAULTS = {
	greet = true,
}

-- Forever is a Mainline game type; detect it explicitly, not via WOW_PROJECT_MAINLINE.
ns.IS_FOREVER = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT

local function ApplyDefaults(db, defaults)
	for k, v in pairs(defaults) do
		if db[k] == nil then
			db[k] = v
		end
	end
	return db
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		-- SavedVariables are available from here on, never at file scope.
		HelloForeverDB = ApplyDefaults(HelloForeverDB or {}, DEFAULTS)
		ns.db = HelloForeverDB
		ns.RegisterOptions()
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		-- Unit/world data is reliable from here (beta returned "Unknown" for UnitName earlier).
		if ns.db.greet then
			local _, build, _, iface = GetBuildInfo()
			print(("|cff33ff99%s|r loaded. Forever=%s build=%s interface=%s project=%s"):format(
				addonName, tostring(ns.IS_FOREVER), build, iface, tostring(WOW_PROJECT_ID)))
		end
	end
end)

SLASH_HELLOFOREVER1 = "/hello"
SlashCmdList.HELLOFOREVER = function(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "info" then
		print(addonName, "Interface:", (select(4, GetBuildInfo())), "Project:", WOW_PROJECT_ID)
	else
		ns.OpenOptions()
	end
end

function HelloForever_OnCompartmentClick()
	ns.OpenOptions()
end
