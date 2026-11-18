-- Boats And Zeppelins: a pin on the world map at every dock, saying where the boat or zeppelin
-- there goes.
--
-- Data.lua holds the stops of every transport path in Forever's own TaxiPathNode table (the
-- classic routes plus Forever's new ones, such as Stormwind to Darkshore). Stops close together
-- are one dock: both Orgrimmar zeppelins leave from one tower. The client turns a stop's world
-- position into a place on the map being looked at, and names the zone a stop lies in, so the
-- names come out in the player's language.
--
-- What it cannot know: whether the server runs a path, when the next one arrives, or which
-- faction may ride it. The table has none of that.
--
-- The pins are plain frames of our own on the map's canvas, placed the way Blizzard places its
-- pins (MapCanvasMixin:ApplyPinPosition). They are not taken from the map's pin pools, which
-- addon code taints. Display only: a click goes through to the map.

local _, root = ...
local ns = root.Feature("transports")

ns.DOCK = 100 -- yards: stops this close on one continent share a pin
ns.AIR = 20 -- a stop this far above sea level is a zeppelin tower

-- Both are on the object icons sheet (UiTextureAtlasMember, sheet 647, build 1.60.1.70938), the
-- sheet of `flightmaster`, which Forever's own transport rows use (TaxiNodes.MinimapAtlasMemberID
-- 4689). Not seen in the game yet.
ns.ATLAS = { boat = "flightmasterferry", zeppelin = "vehicle-air-occupied" }

local GREY = "|cffaaaaaa"

local function Num(v)
	return type(v) == "number" and v == v -- not NaN
end

-- A world position the map API takes, or nil outside the client.
local function Vec(x, y)
	if type(CreateVector2D) ~= "function" then
		return nil
	end
	local ok, v = pcall(CreateVector2D, x, y)
	return ok and type(v) == "table" and v or nil
end

local function MapAPI()
	return type(C_Map) == "table" and C_Map or nil
end

-- Where a world position falls on a map: x, y from 0 to 1, or nil when it is off that map.
-- uiMapID nil asks for the continent's own map and also returns which map that is.
local function OnMap(continent, x, y, uiMapID)
	local api, vec = MapAPI(), Vec(x, y)
	if not api or not vec or type(api.GetMapPosFromWorldPos) ~= "function" then
		return nil
	end
	local ok, id, pos = pcall(api.GetMapPosFromWorldPos, continent, vec, uiMapID)
	if not ok or type(pos) ~= "table" or not Num(pos.x) or not Num(pos.y) then
		return nil
	end
	if pos.x < 0 or pos.x > 1 or pos.y < 0 or pos.y > 1 then
		return nil
	end
	return pos.x, pos.y, id
end

local function MapInfo(uiMapID)
	local api = MapAPI()
	if not api or type(api.GetMapInfo) ~= "function" or type(uiMapID) ~= "number" then
		return nil
	end
	local ok, info = pcall(api.GetMapInfo, uiMapID)
	return ok and type(info) == "table" and info or nil
end

local function MapKind(name)
	local kinds = type(Enum) == "table" and Enum.UIMapType
	return type(kinds) == "table" and kinds[name] or nil
end

-- The zone a stop lies in: its name and map, or nil. The map under the point is the answer when
-- the client names one. A dock's end often stands in open water, outside every zone's outline;
-- then it is the zone whose map holds the point nearest its middle.
local function ZoneAt(continent, x, y)
	local api = MapAPI()
	local cx, cy, top = OnMap(continent, x, y, nil)
	if not api or not cx or type(top) ~= "number" then
		return nil
	end
	if type(api.GetMapInfoAtPosition) == "function" then
		local ok, info = pcall(api.GetMapInfoAtPosition, top, cx, cy)
		if ok and type(info) == "table" and type(info.name) == "string" and info.mapID ~= top then
			return info.name, info.mapID
		end
	end
	local best, bestDist
	if type(api.GetMapChildrenInfo) == "function" then
		local ok, kids = pcall(api.GetMapChildrenInfo, top, MapKind("Zone"), true)
		for _, kid in ipairs(ok and type(kids) == "table" and kids or {}) do
			local zx, zy = OnMap(continent, x, y, kid.mapID)
			if zx and type(kid.name) == "string" then
				local d = (zx - 0.5) ^ 2 + (zy - 0.5) ^ 2
				if not bestDist or d < bestDist then
					best, bestDist = kid, d
				end
			end
		end
	end
	if best then
		return best.name, best.mapID
	end
	local info = MapInfo(top) -- a continent that is one zone (an island of its own)
	return info and type(info.name) == "string" and info.name or nil, top
end

-- ---------------------------------------------------------------- docks

-- Every dock, built once from the data: { continent, x, y, zeppelin, name (its zone, or nil),
-- to = { zone names its transports go to } }. Names need the client's maps, so this waits for
-- the first use after login.
function ns.Docks()
	if ns.docks then
		return ns.docks
	end
	local docks = {}
	local function DockFor(stop)
		local continent, x, y, z = stop[1], stop[2], stop[3], stop[4]
		for _, d in ipairs(docks) do
			if d.continent == continent and (d.x - x) ^ 2 + (d.y - y) ^ 2 < ns.DOCK ^ 2 then
				d.zeppelin = d.zeppelin or z > ns.AIR
				return d
			end
		end
		local d = { continent = continent, x = x, y = y, zeppelin = z > ns.AIR, to = {}, seen = {} }
		docks[#docks + 1] = d
		return d
	end
	local routes = type(ns.Data) == "table" and type(ns.Data.routes) == "table" and ns.Data.routes or {}
	local named = true
	for _, route in ipairs(routes) do
		local stops = {}
		for i, stop in ipairs(route.stops) do
			stops[i] = DockFor(stop)
		end
		for _, from in ipairs(stops) do
			for _, to in ipairs(stops) do
				if to ~= from then
					to.name = to.name or ZoneAt(to.continent, to.x, to.y)
					named = named and to.name ~= nil
					if to.name and not from.seen[to.name] then
						from.seen[to.name] = true
						from.to[#from.to + 1] = to.name
					end
				end
			end
		end
	end
	ns.routeCount = #routes
	if #docks > 0 and named then
		ns.docks = docks -- every zone has its name: keep the list
	end
	return docks
end

function ns.Kind(dock)
	return dock.zeppelin and "Zeppelin" or "Boat"
end

-- "Boat to Darkshore, Hillsbrad Foothills", or "Boat" before the zones have names.
function ns.Label(dock)
	if #dock.to == 0 then
		return ns.Kind(dock)
	end
	return ns.Kind(dock) .. " to " .. table.concat(dock.to, ", ")
end

-- The continent a map shows, or nil for the world map and anything the client will not place.
local continentOf = {}
local function ContinentOf(uiMapID)
	if continentOf[uiMapID] == nil then
		local api, mid = MapAPI(), Vec(0.5, 0.5)
		local found = false
		if api and mid and type(api.GetWorldPosFromMapPos) == "function" then
			local ok, continent = pcall(api.GetWorldPosFromMapPos, uiMapID, mid)
			found = ok and type(continent) == "number" and continent or false
		end
		continentOf[uiMapID] = found
	end
	return continentOf[uiMapID] or nil
end

-- The docks a map shows: a list of { dock = , x = , y = }. Zone maps always; continent maps and
-- the world map by the option. Never a dungeon's or a cave's map.
function ns.DocksOn(uiMapID)
	local out = {}
	local info = MapInfo(uiMapID)
	if not info then
		return out
	end
	local kind = info.mapType
	local wide = kind == MapKind("Continent") or kind == MapKind("World")
	if not (kind == MapKind("Zone") or (wide and ns.db.continent)) then
		return out
	end
	local here = kind ~= MapKind("World") and ContinentOf(uiMapID) or nil
	for _, dock in ipairs(ns.Docks()) do
		if not here or here == dock.continent then
			local x, y = OnMap(dock.continent, dock.x, dock.y, uiMapID)
			if x then
				out[#out + 1] = { dock = dock, x = x, y = y }
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- pins

local pins = {}

local function Map()
	local map = WorldMapFrame
	return type(map) == "table" and map or nil
end

local function ShowTip(pin)
	local dock = pin.dock
	if not dock or type(GameTooltip) ~= "table" then
		return
	end
	GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
	GameTooltip:SetText(ns.Kind(dock))
	for _, name in ipairs(dock.to) do
		GameTooltip:AddLine("To " .. name, 1, 1, 1)
	end
	if dock.name then
		GameTooltip:AddLine(dock.name, 0.67, 0.67, 0.67)
	end
	GameTooltip:Show()
end

local function NewPin(canvas)
	local pin = CreateFrame("Frame", nil, canvas)
	pin.icon = pin:CreateTexture(nil, "OVERLAY")
	pin.icon:SetAllPoints()
	pin:EnableMouse(true)
	pin:SetMouseClickEnabled(false) -- hover only: a click is the map's
	pin:SetScript("OnEnter", function(self)
		root.TryQuiet(ns, "tooltip", ShowTip, self)
	end)
	pin:SetScript("OnLeave", function()
		if type(GameTooltip) == "table" then
			GameTooltip:Hide()
		end
	end)
	return pin
end

-- Blizzard's own placement: the pin keeps its size on screen while the canvas zooms under it.
local function Place(map, pin)
	local canvas = map:GetCanvas()
	local zoom = map:GetCanvasScale()
	local scale = Num(zoom) and zoom > 0 and 1 / zoom or 1
	local w, h = canvas:GetWidth(), canvas:GetHeight()
	if not Num(w) or not Num(h) then
		return
	end
	pin:SetScale(scale)
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", canvas, "TOPLEFT", w * pin.x / scale, -h * pin.y / scale)
end

local function HideFrom(n)
	for i = n, #pins do
		pins[i].dock = nil
		pins[i]:Hide()
	end
end

-- Puts the pins of the map being looked at where they belong, and hides the rest.
function ns.Refresh()
	local map = Map()
	if not map then
		return
	end
	if not ns.enabled or not map:IsShown() then
		HideFrom(1)
		return
	end
	local id = map:GetMapID()
	local shown = type(id) == "number" and ns.DocksOn(id) or {}
	local canvas = map:GetCanvas()
	local size = tonumber(ns.db.size) or 22
	for i, at in ipairs(shown) do
		local pin = pins[i] or NewPin(canvas)
		pins[i] = pin
		pin.dock, pin.x, pin.y = at.dock, at.x, at.y
		pin:SetSize(size, size)
		pin:SetFrameLevel(2100) -- over the map's art and points of interest (Blizzard's pins start at 2000)
		pin.icon:SetAtlas(at.dock.zeppelin and ns.ATLAS.zeppelin or ns.ATLAS.boat)
		Place(map, pin)
		pin:Show()
	end
	HideFrom(#shown + 1)
end

-- The map zoomed or changed size: the pins stay, their places move.
local function Replace()
	local map = Map()
	if not map or not ns.enabled then
		return
	end
	for _, pin in ipairs(pins) do
		if pin.dock then
			Place(map, pin)
		end
	end
end

function ns.Pins()
	return pins
end

-- Hooks cannot be removed: they are added once and do nothing while the feature is off.
local function Hook()
	local map = Map()
	if ns.hooked or not map or type(hooksecurefunc) ~= "function" then
		return
	end
	ns.hooked = true
	local function refresh()
		root.TryQuiet(ns, "refresh", ns.Refresh)
	end
	local function replace()
		root.TryQuiet(ns, "place", Replace)
	end
	hooksecurefunc(map, "OnMapChanged", refresh)
	hooksecurefunc(map, "OnCanvasScaleChanged", replace)
	hooksecurefunc(map, "OnCanvasSizeChanged", replace)
	map:HookScript("OnShow", refresh)
	map:HookScript("OnHide", refresh)
end

-- ---------------------------------------------------------------- settings and commands

ns.title = "Boats And Zeppelins"
ns.description = "Puts a pin on the world map at every boat dock and zeppelin tower. Hover a pin for where it goes. "
	.. "The routes come from the game's own data, so the new ones are there too. It cannot tell when the next one arrives."
ns.icon = "Interface\\Icons\\INV_Misc_Spyglass_02"
ns.blurb = "Map pins for every boat and zeppelin"
ns.options = {
	{
		key = "continent",
		type = "toggle",
		label = "Show On Continent Maps",
		tooltip = "Also shows the pins on the continent maps and the world map. Off: zone maps only.",
		default = true,
	},
	{
		key = "size",
		type = "range",
		label = "Pin Size",
		tooltip = "How big a pin is on the map.",
		default = 22,
		min = 12,
		max = 36,
		step = 2,
	},
}
ns.slash = { "/kwb", "/kwboats" }

local function PlayerMap()
	local api = MapAPI()
	if not api or type(api.GetBestMapForUnit) ~= "function" then
		return nil
	end
	local ok, id = pcall(api.GetBestMapForUnit, "player")
	return ok and type(id) == "number" and id or nil
end

-- The docks of the zone the player is in, as labels.
local function Here()
	local id = PlayerMap()
	local info = id and MapInfo(id)
	local out = {}
	if info and info.mapType == MapKind("Zone") then
		for _, at in ipairs(ns.DocksOn(id)) do
			out[#out + 1] = ns.Label(at.dock)
		end
	end
	return out, info and info.name
end

local function PrintHere()
	local labels, zone = Here()
	if #labels == 0 then
		ns:Print("No boat or zeppelin stops in " .. (zone or "this place") .. ". " .. GREY .. ns.slash[1] .. " all lists every dock.|r")
		return
	end
	ns:Print((zone or "Here") .. ":")
	for _, label in ipairs(labels) do
		print("  " .. label)
	end
end

local function PrintAll()
	local docks = ns.Docks()
	ns:Print(("%d docks on %d routes (game data %s):"):format(#docks, ns.routeCount or 0, ns.Data.build))
	local lines = {}
	for _, dock in ipairs(docks) do
		lines[#lines + 1] = (dock.name or "?") .. ": " .. ns.Label(dock)
	end
	table.sort(lines)
	for _, line in ipairs(lines) do
		print("  " .. line)
	end
	print("  " .. GREY .. "The data cannot say whether the server runs a route. Tell Krool about one that is not there.|r")
end

function ns.OnSlash(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "options" or msg == "config" then
		root.OpenSettings(ns)
	elseif msg == "all" then
		PrintAll()
	elseif msg == "help" then
		ns:Print(ns.slash[1] .. " - the boats and zeppelins of the zone you are in; " .. ns.slash[1] .. " all - every dock; " .. ns.slash[1] .. " options.")
	else
		PrintHere()
	end
end

function ns.HubStatus()
	local labels = Here()
	if #labels > 0 then
		return "Here: " .. table.concat(labels, "; ")
	end
	local docks = ns.Docks()
	return ("%d docks on the map"):format(#docks)
end

function ns.OnOptionChanged()
	root.TryQuiet(ns, "refresh", ns.Refresh)
end

-- The world map loads with the game, but not before every addon: wait for it when it is late.
ns:RegisterEvent("ADDON_LOADED", function()
	Hook()
end)

function ns.OnEnable()
	Hook()
	root.TryQuiet(ns, "refresh", ns.Refresh)
end

function ns.OnDisable()
	HideFrom(1)
end
