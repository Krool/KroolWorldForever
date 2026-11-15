-- The bundle and every standalone in ONE Lua state, each with its own private root table, as the
-- client loads them side by side. Globals set by run.js: __addons (list of { folder, dir, files }),
-- __readfile(path), ORDER ("bundle first" or "bundle last").
-- Every addon file runs in an environment that records global writes, so a name written by two
-- addons is found even when both write the same value. SlashCmdList, StaticPopupDialogs and named
-- frames are recorded by tools/standalone/test/prelude.lua.

local failures, count = 0, 0
local realPrint = print
local function check(label, got, want)
	count = count + 1
	if got ~= want then
		failures = failures + 1
		realPrint("FAIL: [" .. ORDER .. "] " .. label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
	else
		realPrint("ok:   [" .. ORDER .. "] " .. label)
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
local function countLines(lines, needle)
	local n = 0
	for _, l in ipairs(lines) do
		if l:find(needle, 1, true) then
			n = n + 1
		end
	end
	return n
end

local BUNDLE = "KroolWorldForever"

local function Env(addon)
	local env = {}
	rawset(env, "_G", env) -- a file's explicit _G[name] = v goes through the recorder too
	return setmetatable(env, {
		__index = _G,
		__newindex = function(_, k, v)
			local key = "global:" .. tostring(k)
			WrittenBy[key] = WrittenBy[key] or {}
			WrittenBy[key][addon] = true
			rawset(_G, k, v)
		end,
	})
end

local order = {}
for _, a in ipairs(__addons) do
	if a.folder == BUNDLE then
		table.insert(order, ORDER == "bundle first" and 1 or #order + 1, a)
	else
		order[#order + 1] = a
	end
end
-- bundle last: the standalones first, then the bundle
if ORDER ~= "bundle first" then
	local bundle
	for i, a in ipairs(order) do
		if a.folder == BUNDLE then
			bundle = table.remove(order, i)
			break
		end
	end
	order[#order + 1] = bundle
end

for _, a in ipairs(order) do
	a.ns = {}
	local env = Env(a.folder)
	CurrentAddon = a.folder
	for _, f in ipairs(a.files) do
		local chunk, err = load(__readfile(a.dir .. "/" .. f), "@" .. a.folder .. "/" .. f, "t", env)
		if not chunk then
			error(err)
		end
		chunk(a.folder, a.ns)
	end
	local frame = a.ns.frame
	local run = frame and frame.scripts and frame.scripts.OnEvent
	if run then
		frame.scripts.OnEvent = function(...)
			local before = CurrentAddon
			CurrentAddon = a.folder
			local ok, err = pcall(run, ...)
			CurrentAddon = before
			if not ok then
				error(err, 0)
			end
		end
	end
	CurrentAddon = nil
	FireEvent("ADDON_LOADED", a.folder)
end

local standalones = {}
for _, a in ipairs(__addons) do
	LoadedAddons[a.folder] = true -- all of them are loaded by the time anyone logs in
	if a.folder ~= BUNDLE then
		standalones[#standalones + 1] = a
	end
end
local bundle
for _, a in ipairs(__addons) do
	if a.folder == BUNDLE then
		bundle = a
	end
end

local lines = capture(function()
	FireEvent("PLAYER_LOGIN")
end)
capture(function()
	FireEvent("PLAYER_ENTERING_WORLD")
	FireEvent("ADDON_LOADED", "Blizzard_Professions")
end)

-- The bundle works as ever.
check("bundle has its own settings category", Cats[1], "Krool World Forever")
local topLevel = 0
for _, name in ipairs(Cats) do
	if name == "Krool World Forever" then
		topLevel = topLevel + 1
	end
end
check("bundle registers one top-level category", topLevel, 1)
check("only the bundle registered a category", #Cats, 1)
local pages = 0
for _, key in ipairs(bundle.ns.featureOrder) do
	if not bundle.ns.features[key].embedded then
		pages = pages + 1
	end
end
check("bundle has one page per feature", #Subcats, pages)
check("bundle's slash is registered", type(SlashCmdList.KROOLWORLDFOREVER), "function")
check("bundle's saved variables exist", type(KroolWorldForeverDB), "table")
for _, key in ipairs(bundle.ns.featureOrder) do
	local F = bundle.ns.features[key]
	check("bundle feature " .. key .. " enabled", F.enabled, F.defaultEnabled ~= false)
end

-- Every standalone yields.
for _, a in ipairs(standalones) do
	local root = a.ns
	local ID = root.ID
	check(a.folder .. " yielded", root.yielded, true)
	for key, F in pairs(root.features) do
		check(a.folder .. ": " .. key .. " not enabled", F.enabled, false)
		check(a.folder .. ": " .. key .. " has no page", F.category, nil)
	end
	check(a.folder .. " has no slash id", rawget(RealSlashCmdList, ID.slashId), nil)
	check(a.folder .. " has no slash word", rawget(_G, "SLASH_" .. ID.slashId .. "1"), nil)
	check(a.folder .. " created no saved variables", rawget(_G, ID.db), nil)
	check(a.folder .. " said so once", countLines(lines, ID.title .. "|r is off: Krool World Forever already includes it"), 1)
	check(a.folder .. " did not register its category", (function()
		for _, name in ipairs(Cats) do
			if name == ID.title then
				return true
			end
		end
		return false
	end)(), false)
	check(a.folder .. " compartment click does nothing", pcall(_G[a.folder .. "_OnCompartmentClick"]), true)
end
check("one yield line per standalone", countLines(lines, "already includes it"), #standalones)
for _, name in ipairs(FrameNames) do
	check("frame " .. name .. " is not a standalone's", name:sub(1, 3) ~= "KW_", true)
end
for k in pairs(RealSlashCmdList) do
	check("slash id " .. k .. " is the bundle's", k:sub(1, #"KROOLWORLDFOREVER"), "KROOLWORLDFOREVER")
end
for k in pairs(RealPopups) do
	check("popup " .. k .. " is the bundle's", k:sub(1, 4), "KWF_")
end

-- No name written by two addons (globals, slash ids, popup names, frame names).
local clashes = {}
for key, who in pairs(WrittenBy) do
	local names = {}
	for addon in pairs(who) do
		names[#names + 1] = addon
	end
	if #names > 1 then
		table.sort(names)
		clashes[#clashes + 1] = key .. " <- " .. table.concat(names, ", ")
	end
end
table.sort(clashes)
check("no name is written by two addons" .. (#clashes > 0 and (": " .. table.concat(clashes, "; ")) or ""), #clashes, 0)
local seen = {}
for _, name in ipairs(UISpecialFrames) do
	check("UISpecialFrames lists " .. name .. " once", seen[name], nil)
	seen[name] = true
end

realPrint(("%d checks, %d failed"):format(count, failures))
