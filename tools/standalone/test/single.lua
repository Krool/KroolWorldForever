-- One generated standalone, loaded alone (the bundle is not loaded). Globals set by run.js:
-- FOLDER (addon folder), KEY (the feature's registry key), __ns (the addon's private root).

local failures, count = 0, 0
local realPrint = print
local function check(label, got, want)
	count = count + 1
	if got ~= want then
		failures = failures + 1
		realPrint("FAIL: " .. FOLDER .. ": " .. label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
	else
		realPrint("ok:   " .. FOLDER .. ": " .. label)
	end
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
local function has(lines, needle)
	for _, l in ipairs(lines) do
		if l:find(needle, 1, true) then
			return true
		end
	end
	return false
end

local root = __ns
local ID = root.ID
local F = root.features[KEY]

check("identity is a standalone", ID.standalone, true)
check("identity names the folder", ID.addon, FOLDER)
check("the public API global is the folder's", _G[FOLDER], root.public)
check("the bundle's global is not written", rawget(_G, "KroolWorldForever"), nil)
check("the feature registered", type(F), "table")
check("no hub file: no RefreshHub", root.RefreshHub, nil)
check("the compartment click exists", type(_G[FOLDER .. "_OnCompartmentClick"]), "function")

-- Nothing before login: settings, slash and enabling all wait for PLAYER_LOGIN.
local lines = capture(function()
	FireEvent("ADDON_LOADED", FOLDER)
end)
check("no settings category before login", #Cats, 0)
check("no slash before login", SlashCmdList[ID.slashId], nil)
check("not enabled before login", F.enabled, false)

lines = capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("not yielded alone", root.yielded, nil)
check("saved variables are its own", type(_G[ID.db]), "table")
check("the saved variables hold the feature's slice", type(_G[ID.db].features[KEY]), "table")
check("the bundle's saved variables are not created", rawget(_G, "KroolWorldForeverDB"), nil)
check("enabled at login (its default)", F.enabled, F.defaultEnabled ~= false)
check("login printed no error", has(lines, "error in"), false)

-- Settings: one top-level category named for the addon, no subcategories, no hub button.
check("one top-level category", #Cats, 1)
check("it is named for the addon", Cats[1], ID.title)
check("no subcategories", #Subcats, 0)
check("registered once", #AddOnCats, 1)
check("no hub button", (SettingsButtons or {})["Open Krool World"], nil)
check("the feature's own page is that category", F.category and F.category.name, ID.title)
local enabledSetting = RegisteredSettings[ID.prefix .. "_" .. KEY .. "_enabled"]
check("its Enabled setting is registered under its prefix", type(enabledSetting), "table")
for variable in pairs(RegisteredSettings) do
	check("setting " .. variable .. " belongs to this addon", variable:sub(1, #ID.prefix + 1), ID.prefix .. "_")
end

-- The key binding header is the addon's own title, and every "where to bind" text names it.
if KEY == "fishing" or KEY == "rares" then
	local where = "Key Bindings > AddOns > " .. ID.title
	check("the binding header is the addon's title", _G["BINDING_HEADER_" .. ID.slashId], ID.title)
	local said = capture(function()
		F.OnSlash("")
	end)
	check("its slash help says where to bind the key", has(said, where), true)
	check("nothing points at the bundle's header", has(said, "AddOns > Krool World"), false)
	if KEY == "fishing" then
		check("its description says where to bind the key", F.description:find(where, 1, true) ~= nil, true)
	end
end

-- Embedded providers: loaded (data ready), never enabled, no page and no slash.
for _, ekey in ipairs(ID.embedded) do
	local E = root.features[ekey]
	check("embedded " .. ekey .. " is flagged", E and E.embedded, true)
	check("embedded " .. ekey .. " has its slice (OnLoad ran)", type(E.db), "table")
	check("embedded " .. ekey .. " never enables", E.enabled, false)
	check("embedded " .. ekey .. " has no settings page", E.category, nil)
	check("embedded " .. ekey .. " has no setting objects", E.settingObjects, nil)
	check("embedded " .. ekey .. " has no slash", rawget(_G, "SLASH_" .. ID.slashId .. "_" .. ekey:upper() .. "1"), nil)
	for variable in pairs(RegisteredSettings) do
		check("no setting for embedded " .. ekey .. ": " .. variable, variable:find("_" .. ekey .. "_", 1, true), nil)
	end
end
if root.features.disenchant and root.features.disenchant.embedded then
	local DE = root.features.disenchant
	check("embedded Disenchant: CanDisenchant works", pcall(DE.CanDisenchant), true)
	check("embedded Disenchant: Evaluate works", pcall(DE.Evaluate, 2589, 2, 4, 10), true)
	check("embedded Disenchant: Best works", pcall(DE.Best, 100, 200, 50), true)
end
if root.features.killvalue and root.features.killvalue.embedded then
	check("embedded Kill Value: Compute works", pcall(root.public.KillValue.Compute, 299), true)
end

-- Slash: the feature's words (or the manifest's), no /kw.
local words = F.slash or ID.slash
check("it has slash words", #words > 0, true)
for i, w in ipairs(words) do
	check("slash word " .. w, rawget(_G, "SLASH_" .. ID.slashId .. i), w)
end
check("no /kw", rawget(_G, "SLASH_KROOLWORLDFOREVER1"), nil)
check("the slash handler is registered", type(SlashCmdList[ID.slashId]), "function")
check("help text names the feature's own command", root.cmd, words[1])
local slash = SlashCmdList[ID.slashId]

OpenedCategory = nil
slash("settings")
check("slash settings opens the addon's category", OpenedCategory, ID.title)
lines = capture(function()
	slash("errors")
end)
check("slash errors answers", has(lines, "no errors caught"), true)
slash("chars")
for _, e in ipairs(_G[ID.db].errors or {}) do
	realPrint("  logged: " .. tostring(type(e) == "table" and (tostring(e.where) .. ": " .. tostring(e.message)) or e))
end
check("slash chars opens the character list", root.CharactersFrame() ~= nil and root.CharactersFrame():IsShown(), true)
slash("chars")
check("slash chars again closes it", root.CharactersFrame():IsShown(), false)
local untrackLines = capture(function()
	slash("untrack")
end)
check("slash untrack answers", has(untrackLines, "left out of character lists"), true)
slash("track")
local handedOn
if F.OnSlash then
	local original = F.OnSlash
	F.OnSlash = function(msg)
		handedOn = msg
	end
	slash("zzz test")
	check("other words go to the feature", handedOn, "zzz test")
	handedOn = nil
	slash("settings")
	check("settings is not handed to the feature", handedOn, nil)
	F.OnSlash = original
end

-- The compartment click and the hub-less way in.
check("compartment click does not error", pcall(_G[FOLDER .. "_OnCompartmentClick"]), true)
check("OpenHub without a hub does not error", pcall(root.OpenHub), true)

-- Off: the feature is silenced and says how to turn it on.
root.SetOption(F, "enabled", false)
check(KEY .. " off: not enabled", F.enabled, false)
local ran = false
local onSlash = F.OnSlash
F.OnSlash = function()
	ran = true
end
lines = capture(function()
	slash("anything")
end)
check(KEY .. " off: its slash does not run", ran, false)
check(KEY .. " off: it says it is off", has(lines, "is off"), true)
check(KEY .. " off: it points to the settings", has(lines, "Options > AddOns"), true)
lines = capture(function()
	slash("errors")
end)
check(KEY .. " off: errors still answers", has(lines, "no errors caught"), true)
F.OnSlash = onSlash
root.SetOption(F, "enabled", true)
check(KEY .. " on again", F.enabled, true)

-- Nothing the bundle uses.
check("no hub frame", rawget(_G, "KroolWorldForeverHub"), nil)
for _, name in ipairs(FrameNames) do
	check("named frame " .. name .. " carries the addon's prefix", name:sub(1, #ID.prefix), ID.prefix)
end
check("no errors logged", #(_G[ID.db].errors or {}), 0)

realPrint(("%d checks, %d failed"):format(count, failures))
