-- Builds the settings panel generically from each feature's declared options: one
-- subcategory per feature, an Enabled checkbox first, then its toggles and sliders. A new
-- feature only declares ns.options; nothing here changes.

local _, root = ...

local function OnChange(setting, fn)
	-- Retail settings expose the callback on the setting object; fall back to the registry.
	if setting and setting.SetValueChangedCallback then
		setting:SetValueChangedCallback(function(_, value)
			fn(value)
		end)
	elseif Settings.SetOnValueChangedCallback then
		Settings.SetOnValueChangedCallback(setting:GetVariable(), function(_, _, value)
			fn(value)
		end)
	end
end

local function AddOption(category, F, opt)
	local variable = "KroolWorldForever_" .. F.key .. "_" .. opt.key
	if opt.type == "toggle" then
		local setting = Settings.RegisterAddOnSetting(
			category,
			variable,
			opt.key,
			F.db,
			Settings.VarType.Boolean,
			opt.label,
			opt.default
		)
		Settings.CreateCheckbox(category, setting, opt.tooltip)
		return setting
	elseif opt.type == "range" then
		local setting = Settings.RegisterAddOnSetting(
			category,
			variable,
			opt.key,
			F.db,
			Settings.VarType.Number,
			opt.label,
			opt.default
		)
		local options = Settings.CreateSliderOptions(opt.min, opt.max, opt.step or 1)
		if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end
		Settings.CreateSlider(category, setting, options, opt.tooltip)
		return setting
	end
end

function root.BuildSettings()
	local parent = Settings.RegisterVerticalLayoutCategory("Krool World Forever")
	root.category = parent
	for _, key in ipairs(root.featureOrder) do
		local F = root.features[key]
		local ok, err = pcall(function()
			local category = Settings.RegisterVerticalLayoutSubcategory(parent, F.title or key)
			F.category = category
			local enabled = Settings.RegisterAddOnSetting(
				category,
				"KroolWorldForever_" .. key .. "_enabled",
				"enabled",
				F.db,
				Settings.VarType.Boolean,
				"Enabled",
				F.defaultEnabled ~= false
			)
			Settings.CreateCheckbox(category, enabled, F.description)
			OnChange(enabled, function(value)
				root.SetEnabled(F, value)
			end)
			F.settingObjects = { enabled = enabled } -- root.SetOption goes through these
			if F.OnOpen and CreateSettingsButtonInitializer and SettingsPanel then
				local layout = SettingsPanel:GetLayout(category)
				layout:AddInitializer(CreateSettingsButtonInitializer("", "Open " .. (F.title or key), function()
					if F.enabled then
						SettingsPanel:Hide()
						F.OnOpen()
					end
				end, F.description, true))
			end
			for _, opt in ipairs(F.options) do
				local setting = AddOption(category, F, opt)
				F.settingObjects[opt.key] = setting
				if setting and F.OnOptionChanged then
					OnChange(setting, function(value)
						F.OnOptionChanged(opt.key, value)
					end)
				end
			end
		end)
		if not ok then
			root.Print("|cffff5555settings for " .. key .. " failed|r: " .. tostring(err))
		end
	end
	Settings.RegisterAddOnCategory(parent)
end

function root.OpenSettings(F)
	local category = (F and F.category) or root.category
	if category then
		Settings.OpenToCategory(category:GetID())
	end
end
