-- Boats And Zeppelins: a pin on the world map at every dock, saying where the boat or zeppelin
-- there goes.
--
-- Data.lua holds the stops of every transport path in Forever's own TaxiPathNode table (the
-- classic routes plus Forever's new ones, such as Stormwind to Darkshore). Stops close together
-- are one dock: both Orgrimmar zeppelins leave from one tower. The client turns a stop's world
-- position into a place on the map being looked at, and names the zone a stop lies in, so the
-- names come out in the player's language.
--
-- A dock also has its town: the flight master beside it (Data.lua's `node`), named by the client
-- in the player's language, or by Data.lua's English `town` when the client names none. `side`
-- says whose town it is, `wait` how long the transport stays.
--
-- What it cannot know: whether the server runs a path, when the next one arrives, how long the
-- crossing takes, or which faction may ride it. The tables have none of that.
--
-- Portals and the tram are in no route table: ns.PORTALS below holds them by hand, each shown
-- only to the races that may use it, and only on zone maps.
--
-- The pins are plain frames of our own on the map's canvas, placed the way Blizzard places its
-- pins (MapCanvasMixin:ApplyPinPosition). They are not taken from the map's pin pools, which
-- addon code taints. Display only: a click goes through to the map.

local _, root = ...
local ns = root.Feature("transports")

ns.DOCK = 100 -- yards: stops this close on one continent share a pin
ns.AIR = 20 -- a stop this far above sea level is a zeppelin tower

-- All three are on the object icons sheet (UiTextureAtlasMember, sheet 647, build 1.60.1.70938),
-- the sheet of `flightmaster`, which Forever's own transport rows use (TaxiNodes.MinimapAtlasMemberID
-- 4689). The boat and zeppelin are seen in the game; `mageportalalliance` (member 4772, still there
-- in 71139) is not yet.
-- `vehicle-alliancecart` (member 4748, the same sheet, 71139) is the tram's; not seen in the game yet.
ns.ATLAS = { boat = "flightmasterferry", zeppelin = "vehicle-air-occupied", portal = "mageportalalliance", tram = "vehicle-alliancecart" }

-- Portals and tram stops, by hand: { kind = "portal" or "tram", continent, x, y (world), map = the
-- zone map it stands on, to = the map it goes to, races = { [ChrRaces id] = true } the races that
-- may use it, or nil for everyone, side = whose town it is, node/town = the flight master beside
-- it (as in Data.lua), toNode/toTown = the one where it lets you out }.
ns.PORTALS = {
	-- Dalaran, the Sky Enclave, to Stormwind City. Read by the owner standing at it, 2026-11-25:
	-- map 1416 (Alterac Mountains) at 0.1209, 0.5653, world 444.8, 444.8. Method and Wowhead say
	-- Skyborne only, and the enclave is the High Order's, so it is for High Order Skyborne (95, the
	-- Alliance side), not Windshaper Skyborne (96, Horde: Dalaran's guards attack Horde on sight).
	{ kind = "portal", continent = 0, x = 444.8, y = 444.8, map = 1416, to = 1453, races = { [95] = true } },
	-- The four below are walk-in triggers in Forever's own AreaTrigger table (build 71139), where
	-- these positions are from. Where each leads is the classic server's answer (cmangos classic-db,
	-- areatrigger_teleport, the same trigger ids). Not seen in the game yet.
	-- The Deeprun Tram: trigger 2173 in Stormwind's Dwarven District, 2175 in Ironforge's Tinker Town.
	{ kind = "tram", continent = 0, x = -8346.5, y = 514, map = 1453, to = 1455, side = "A" },
	{ kind = "tram", continent = 0, x = -4840.3, y = -1330.5, map = 1455, to = 1453, side = "A" },
	-- Rut'theran Village and Darnassus: trigger 542 at the village's portal, 527 in the city.
	{ kind = "portal", continent = 1, x = 8799.4, y = 969.8, map = 1438, to = 1457, side = "A", node = 27, town = "Rut'theran Village" },
	{ kind = "portal", continent = 1, x = 9947.5, y = 2630, map = 1457, to = 1438, side = "A", toNode = 27, toTown = "Rut'theran Village" },
}

local GREY = "|cffaaaaaa"
local RED = "|cffff5555"

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

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

-- The player's race id (ChrRaces), or nil.
function ns.PlayerRace()
	if type(UnitRace) ~= "function" then
		return nil
	end
	local ok, _, _, id = pcall(UnitRace, "player")
	return ok and type(id) == "number" and id or nil
end

-- The player's side: "A", "H" or nil.
function ns.PlayerSide()
	if type(UnitFactionGroup) ~= "function" then
		return nil
	end
	local ok, group = pcall(UnitFactionGroup, "player")
	if not ok or Secret(group) then
		return nil
	end
	return group == "Alliance" and "A" or group == "Horde" and "H" or nil
end

-- A flight master's town as the client names it: "Booty Bay, Stranglethorn" gives "Booty Bay".
-- top is the continent's map, which lists every flight master on it. nil when the client names
-- none (the caller then has Data.lua's English name).
ns.taxi = {} -- [continent map] = { [node id] = name }, once the client answers
local function TaxiTown(top, node)
	if type(top) ~= "number" or type(node) ~= "number" then
		return nil
	end
	local names = ns.taxi[top]
	if not names then
		local T = type(C_TaxiMap) == "table" and C_TaxiMap or nil
		if not T or type(T.GetTaxiNodesForMap) ~= "function" then
			return nil
		end
		local ok, list = pcall(T.GetTaxiNodesForMap, top)
		if not ok or type(list) ~= "table" or #list == 0 then
			return nil
		end
		names = {}
		for _, n in ipairs(list) do
			if type(n) == "table" and type(n.nodeID) == "number" and not Secret(n.name) and type(n.name) == "string" then
				names[n.nodeID] = n.name
			end
		end
		ns.taxi[top] = names
	end
	local name = names[node]
	if not name then
		return nil
	end
	local town = name:match("^%s*([^,]-)%s*,") or name
	return town ~= "" and town or nil
end

-- A place's short name: its town, or its zone.
function ns.Short(place)
	return place.town or place.name
end

-- A place in full: "Booty Bay, Stranglethorn Vale". The zone alone when it says the same
-- ("Stormwind City", not "Stormwind, Stormwind City").
function ns.Place(place)
	local town, zone = place.town, place.name
	if not town then
		return zone
	end
	if not zone or zone:find(town, 1, true) then
		return zone or town
	end
	return town .. ", " .. zone
end

-- Every dock, built once from the data: { continent, x, y, zeppelin, kind ("portal" or "tram"
-- for the ones by hand), name (its zone, or nil), mapID (that zone's map), town, side, waits = {
-- seconds, one per transport }, to = { the places its transports go to } }. A place is another
-- dock, or for the ones by hand a table with the same name, town and side. Names need the
-- client's maps, so this waits for the first use after login.
function ns.Docks()
	if ns.docks then
		return ns.docks
	end
	local docks = {}
	local function DockFor(stop)
		local continent, x, y, z = stop[1], stop[2], stop[3], stop[4]
		local d
		for _, known in ipairs(docks) do
			if known.continent == continent and (known.x - x) ^ 2 + (known.y - y) ^ 2 < ns.DOCK ^ 2 then
				d = known
				break
			end
		end
		if not d then
			d = { continent = continent, x = x, y = y, zeppelin = false, to = {}, seen = {}, waits = {} }
			docks[#docks + 1] = d
		end
		d.zeppelin = d.zeppelin or z > ns.AIR
		d.node = d.node or stop.node
		d.english = d.english or stop.town
		d.side = d.side or stop.side
		return d
	end
	-- A dock's zone, its map, and its town: asked once per dock.
	local function Name(d)
		if d.name == nil then
			local _, _, top = OnMap(d.continent, d.x, d.y, nil)
			d.name, d.mapID = ZoneAt(d.continent, d.x, d.y)
			d.top = top
			d.town = TaxiTown(top, d.node) or d.english
		end
		return d.name ~= nil
	end
	local routes = type(ns.Data) == "table" and type(ns.Data.routes) == "table" and ns.Data.routes or {}
	local named = true
	for _, route in ipairs(routes) do
		local stops = {}
		for i, stop in ipairs(route.stops) do
			stops[i] = DockFor(stop)
			if type(stop.wait) == "number" and stop.wait > 0 then
				table.insert(stops[i].waits, stop.wait)
			end
		end
		for _, from in ipairs(stops) do
			for _, to in ipairs(stops) do
				if to ~= from then
					named = Name(to) and named
					local key = to.name and ns.Short(to)
					if key and not from.seen[key] then
						from.seen[key] = true
						from.to[#from.to + 1] = to
					end
				end
			end
		end
	end
	for _, d in ipairs(docks) do
		named = Name(d) and named -- a dock nothing sails to still has its own zone
	end
	ns.routeCount = #routes
	local race = ns.PlayerRace()
	for _, p in ipairs(type(ns.PORTALS) == "table" and ns.PORTALS or {}) do
		if p.races and not race then
			named = false -- the race is not known yet: ask again next time
		elseif not p.races or p.races[race] then
			local at, dest = MapInfo(p.map), MapInfo(p.to)
			local d = { continent = p.continent, x = p.x, y = p.y, kind = p.kind or "portal", hand = true, side = p.side, to = {}, seen = {}, waits = {} }
			local _, _, top = OnMap(p.continent, p.x, p.y, nil)
			d.name = at and type(at.name) == "string" and at.name or nil
			d.mapID, d.top = p.map, top
			d.town = TaxiTown(top, p.node) or p.town
			if dest and type(dest.name) == "string" then
				d.to[1] = { name = dest.name, town = TaxiTown(top, p.toNode) or p.toTown, side = p.side }
			end
			named = named and d.name ~= nil and #d.to > 0
			docks[#docks + 1] = d
		end
	end
	if #docks > 0 and named then
		ns.docks = docks -- every zone has its name: keep the list
	end
	return docks
end

function ns.Kind(dock)
	if dock.kind == "tram" then
		return "Tram"
	elseif dock.kind == "portal" then
		return "Portal"
	end
	return dock.zeppelin and "Zeppelin" or "Boat"
end

-- Boat and zeppelin docks, portals and tram stops in the list.
function ns.Counts()
	local stops, portals, trams = 0, 0, 0
	for _, dock in ipairs(ns.Docks()) do
		if dock.kind == "tram" then
			trams = trams + 1
		elseif dock.kind == "portal" then
			portals = portals + 1
		else
			stops = stops + 1
		end
	end
	return stops, portals, trams
end

-- "Boat to Auberdine, Southshore", or "Boat" before the zones have names.
function ns.Label(dock)
	if #dock.to == 0 then
		return ns.Kind(dock)
	end
	local names = {}
	for i, place in ipairs(dock.to) do
		names[i] = ns.Short(place)
	end
	return ns.Kind(dock) .. " to " .. table.concat(names, ", ")
end

-- "(Horde)" after a town that is one side's: red when it is not the player's, grey when it is.
function ns.SideTag(place)
	local side = place.side
	if side ~= "A" and side ~= "H" then
		return ""
	end
	local name = side == "A" and (FACTION_ALLIANCE or "Alliance") or (FACTION_HORDE or "Horde")
	local mine = ns.PlayerSide()
	return " " .. ((mine and mine ~= side) and RED or GREY) .. "(" .. name .. ")|r"
end

-- "1 minute", "30 seconds".
local function Span(seconds)
	if seconds % 60 == 0 then
		local m = seconds / 60
		return m == 1 and "1 minute" or (m .. " minutes")
	end
	return seconds .. " seconds"
end

-- How long a transport stays at this dock: "Waits 1 minute at the dock", or nil when the data
-- has no wait (a portal). Two transports that wait differently give the shorter one.
function ns.Wait(dock)
	local least, same = nil, true
	for _, w in ipairs(dock.waits or {}) do
		same = same and (least == nil or w == least)
		least = (least == nil or w < least) and w or least
	end
	if not least then
		return nil
	end
	return same and ("Waits " .. Span(least) .. " at the dock") or ("Waits " .. Span(least) .. " or longer at the dock")
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
-- the world map by the option, without the portals and tram stops (they stand in cities, and
-- Dalaran's portal would cover the airship stop beside it). Never a dungeon's or a cave's map.
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
		if not (dock.hand and wide) and (not here or here == dock.continent) then
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
	for _, place in ipairs(dock.to) do
		GameTooltip:AddLine("To " .. (ns.Place(place) or "?") .. ns.SideTag(place), 1, 1, 1)
	end
	if dock.name then
		GameTooltip:AddLine(ns.Place(dock) .. ns.SideTag(dock), 0.67, 0.67, 0.67)
	end
	local wait = ns.Wait(dock)
	if wait then
		GameTooltip:AddLine(wait, 0.67, 0.67, 0.67)
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
		pin.icon:SetAtlas(ns.ATLAS[at.dock.kind] or at.dock.zeppelin and ns.ATLAS.zeppelin or ns.ATLAS.boat)
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
ns.description = "Puts a pin on the world map at every boat dock and zeppelin tower. Hover a pin for the town it goes to, whose town that is, and how long the boat waits. "
	.. "The routes come from the game's own data, so the new ones are there too. It cannot tell when the next one arrives. "
	.. "Zone maps also show the Deeprun Tram, the portal between Rut'theran Village and Darnassus, and for High Order Skyborne Dalaran's portal to Stormwind."
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

-- Where the player stands in the world: continent, x, y. nil where the client will not say (a
-- dungeon, or a place whose position is kept from addons).
local function PlayerSpot()
	local api, id = MapAPI(), PlayerMap()
	if not api or not id or type(api.GetPlayerMapPosition) ~= "function" or type(api.GetWorldPosFromMapPos) ~= "function" then
		return nil
	end
	local ok, pos = pcall(api.GetPlayerMapPosition, id, "player")
	if not ok or type(pos) ~= "table" or Secret(pos.x) or Secret(pos.y) or not Num(pos.x) or not Num(pos.y) then
		return nil
	end
	local vec = Vec(pos.x, pos.y)
	if not vec then
		return nil
	end
	local okW, continent, world = pcall(api.GetWorldPosFromMapPos, id, vec)
	if not okW or type(continent) ~= "number" or type(world) ~= "table" or not Num(world.x) or not Num(world.y) then
		return nil
	end
	return continent, world.x, world.y
end

-- Does a dock go to a place whose town or zone holds this text? Plain text, any case.
local function GoesTo(dock, text)
	for _, place in ipairs(dock.to) do
		local town, zone = place.town, place.name
		if (town and town:lower():find(text, 1, true)) or (zone and zone:lower():find(text, 1, true)) then
			return true
		end
	end
	return false
end

-- The docks that go to a place matching text (nil or "": every dock), nearest first when the
-- player's place is known: { { dock = , yards = (nil on another continent, or place unknown) } }.
function ns.Find(text)
	text = type(text) == "string" and text:lower() or ""
	local continent, px, py = PlayerSpot()
	local out = {}
	for _, dock in ipairs(ns.Docks()) do
		if text == "" or GoesTo(dock, text) then
			local yards
			if continent and continent == dock.continent then
				yards = math.sqrt((dock.x - px) ^ 2 + (dock.y - py) ^ 2)
			end
			out[#out + 1] = { dock = dock, yards = yards }
		end
	end
	table.sort(out, function(a, b)
		if (a.yards ~= nil) ~= (b.yards ~= nil) then
			return a.yards ~= nil
		end
		if a.yards and a.yards ~= b.yards then
			return a.yards < b.yards
		end
		return (ns.Place(a.dock) or "") .. ns.Label(a.dock) < (ns.Place(b.dock) or "") .. ns.Label(b.dock)
	end)
	return out
end

-- "1,240 yards".
local function Yards(yards)
	local n = math.floor(yards + 0.5)
	local s = tostring(n)
	if n >= 1000 then
		s = math.floor(n / 1000) .. "," .. ("%03d"):format(n % 1000)
	end
	return s .. " yards"
end

-- "Ratchet, The Barrens: Boat to Booty Bay", with how far it is when that is known.
local function Line(found)
	local line = (ns.Place(found.dock) or "?") .. ": " .. ns.Label(found.dock)
	if found.yards then
		line = line .. " " .. GREY .. "(" .. Yards(found.yards) .. ")|r"
	end
	return line
end

-- Puts the game's own map pin on a dock and follows it. Returns true when the pin is set. The
-- player asked for it by name (/kwb go), and one pin replaces another the player set before.
function ns.Mark(dock)
	local api = MapAPI()
	if not api or type(api.SetUserWaypoint) ~= "function" or type(UiMapPoint) ~= "table" or type(UiMapPoint.CreateFromCoordinates) ~= "function" then
		return false
	end
	for _, mapID in ipairs({ dock.mapID or false, dock.top or false }) do
		local x, y = nil, nil
		if mapID then
			x, y = OnMap(dock.continent, dock.x, dock.y, mapID)
		end
		local can = x ~= nil
		if can and type(api.CanSetUserWaypointOnMap) == "function" then
			local ok, yes = pcall(api.CanSetUserWaypointOnMap, mapID)
			can = ok and yes == true
		end
		if can then
			local ok = pcall(function()
				api.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
				if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
					C_SuperTrack.SetSuperTrackedUserWaypoint(true)
				end
			end)
			if ok then
				return true
			end
		end
	end
	return false
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
		local nearest = ns.Find()[1]
		if nearest and nearest.yards then
			print("  Nearest: " .. Line(nearest) .. ". " .. GREY .. ns.slash[1] .. " go marks it on your map.|r")
		end
		return
	end
	ns:Print((zone or "Here") .. ":")
	for _, label in ipairs(labels) do
		print("  " .. label)
	end
end

local function PrintAll()
	local docks = ns.Docks()
	local stops, portals, trams = ns.Counts()
	local head = ("%d docks on %d routes"):format(stops, ns.routeCount or 0)
	if portals > 0 then
		head = head .. (portals == 1 and ", 1 portal" or (", %d portals"):format(portals))
	end
	if trams > 0 then
		head = head .. (trams == 1 and ", 1 tram stop" or (", %d tram stops"):format(trams))
	end
	ns:Print(head .. (" (game data %s):"):format(ns.Data.build))
	local lines = {}
	for _, dock in ipairs(docks) do
		lines[#lines + 1] = (ns.Place(dock) or "?") .. ": " .. ns.Label(dock)
	end
	table.sort(lines)
	for _, line in ipairs(lines) do
		print("  " .. line)
	end
	print("  " .. GREY .. "The data cannot say whether the server runs a route. Tell Krool about one that is not there.|r")
end

-- /kwb <place>: every dock that goes there, nearest first.
local function PrintTo(text)
	local found = ns.Find(text)
	if #found == 0 then
		ns:Print("No boat, zeppelin, portal or tram goes to \"" .. text .. "\". " .. GREY .. ns.slash[1] .. " all lists every dock.|r")
		return
	end
	ns:Print("To \"" .. text .. "\":")
	for _, f in ipairs(found) do
		print("  " .. Line(f))
	end
	if found[1].yards then
		print("  " .. GREY .. ns.slash[1] .. " go " .. text .. " marks the nearest on your map.|r")
	end
end

-- /kwb go [place]: the game's map pin on the nearest dock, or the nearest that goes to a place.
local function Go(text)
	local found = ns.Find(text)
	local nearest = found[1]
	if not nearest then
		ns:Print("No boat, zeppelin, portal or tram goes to \"" .. text .. "\".")
		return
	end
	if not nearest.yards then
		ns:Print(text ~= "" and ("Nothing on this continent goes to \"" .. text .. "\". " .. GREY .. ns.slash[1] .. " " .. text .. " lists what does.|r") or "Cannot tell where you are here.")
		return
	end
	if ns.Mark(nearest.dock) then
		ns:Print("Marked on your map: " .. Line(nearest) .. ".")
	else
		ns:Print("The map takes no pin there. Nearest: " .. Line(nearest) .. ".")
	end
end

function ns.OnSlash(msg)
	msg = strtrim(msg or "")
	local word, rest = msg:lower():match("^(%S*)%s*(.-)$")
	if word == "options" or word == "config" then
		root.OpenSettings(ns)
	elseif word == "all" then
		PrintAll()
	elseif word == "help" then
		ns:Print(ns.slash[1] .. " - the boats and zeppelins of the zone you are in, or the nearest; " .. ns.slash[1] .. " <place> - what goes there; " .. ns.slash[1] .. " go [place] - mark the nearest on your map; " .. ns.slash[1] .. " all - every dock; " .. ns.slash[1] .. " options.")
	elseif word == "go" then
		Go(rest)
	elseif word ~= "" then
		PrintTo(msg:lower())
	else
		PrintHere()
	end
end

function ns.HubStatus()
	local labels = Here()
	if #labels > 0 then
		return "Here: " .. table.concat(labels, "; ")
	end
	return ("%d docks on the map"):format((ns.Counts()))
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
