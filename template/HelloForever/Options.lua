local addonName, ns = ...

-- Native Settings API (retail 11.x+ signatures; Forever shares them). Verify with /api if this errors.
function ns.RegisterOptions()
	local category = Settings.RegisterVerticalLayoutCategory(addonName)

	local setting = Settings.RegisterAddOnSetting(
		category,
		"HelloForever_Greet", -- unique variable name
		"greet", -- key in the db table
		ns.db,
		Settings.VarType.Boolean,
		"Greet on login",
		true
	)
	Settings.CreateCheckbox(category, setting, "Print build info to chat when you log in.")

	Settings.RegisterAddOnCategory(category)
	ns.category = category
end

function ns.OpenOptions()
	if ns.category then
		Settings.OpenToCategory(ns.category:GetID())
	end
end
