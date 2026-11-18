-- Boats And Zeppelins' client: the Least Valuable stubs (widgets, settings, tooltip), plus a small
-- world of maps and a world map frame.
--
-- A map is a rectangle of world coordinates, as in the client: world x runs north (the top of a
-- map is its highest x), world y runs west (the left of a map is its highest y). `outline` is the
-- part of the rectangle the zone really covers: C_Map.GetMapInfoAtPosition answers only inside it,
-- like the client, which names no zone over open water.

__include("leastvaluable/stubs.lua")

Enum.UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 }

function CreateVector2D(x, y)
	return { x = x, y = y }
end

-- rect/outline = { top, bottom, left, right }
Maps = {
	[947] = { name = "Azeroth", type = 1, parts = { [1] = { 0, 0.45 }, [0] = { 0.55, 1 } }, tops = { [1] = 1414, [0] = 1415 } },
	[1414] = { name = "Kalimdor", type = 2, parent = 947, continent = 1, rect = { 12000, -12000, 6000, -8000 } },
	[1415] = { name = "Eastern Kingdoms", type = 2, parent = 947, continent = 0, rect = { 5000, -16000, 4000, -7000 } },
	-- Kalimdor
	[1439] = { name = "Darkshore", type = 3, parent = 1414, continent = 1, rect = { 8300, 4300, 2600, -100 }, outline = { 8300, 4300, 900, -100 } },
	[1438] = { name = "Teldrassil", type = 3, parent = 1414, continent = 1, rect = { 11900, 8400, 3300, 0 } },
	[1411] = { name = "Durotar", type = 3, parent = 1414, continent = 1, rect = { 2000, -1500, -3700, -5600 }, outline = { 2000, -1500, -4100, -5600 } },
	[1413] = { name = "The Barrens", type = 3, parent = 1414, continent = 1, rect = { 1500, -4500, -1000, -4200 } },
	[1445] = { name = "Dustwallow Marsh", type = 3, parent = 1414, continent = 1, rect = { -2000, -5500, -2500, -5000 } },
	[1444] = { name = "Feralas", type = 3, parent = 1414, continent = 1, rect = { -2500, -6000, 5500, 0 } },
	[1446] = { name = "Tanaris", type = 3, parent = 1414, continent = 1, rect = { -5800, -10500, -2300, -5500 } },
	[1412] = { name = "Mulgore", type = 3, parent = 1414, continent = 1, rect = { 600, -3500, 2000, -1000 } },
	-- Eastern Kingdoms
	[1437] = { name = "Wetlands", type = 3, parent = 1415, continent = 0, rect = { -2100, -4700, 300, -4100 } },
	[1453] = { name = "Stormwind City", type = 3, parent = 1415, continent = 0, rect = { -8100, -9300, 1700, 100 } },
	[1429] = { name = "Elwynn Forest", type = 3, parent = 1415, continent = 0, rect = { -8000, -10500, 1500, -2000 }, outline = { -9300, -10500, 100, -2000 } },
	[1434] = { name = "Stranglethorn Vale", type = 3, parent = 1415, continent = 0, rect = { -11000, -15500, 2500, -1500 } },
	[1420] = { name = "Tirisfal Glades", type = 3, parent = 1415, continent = 0, rect = { 3500, 1000, 1700, -2000 } },
	[1424] = { name = "Hillsbrad Foothills", type = 3, parent = 1415, continent = 0, rect = { 500, -1700, 1100, -2100 } },
	[1421] = { name = "Silverpine Forest", type = 3, parent = 1415, continent = 0, rect = { 1500, -700, 2500, 300 } },
	[1500] = { name = "Powderfuse Port", type = 3, parent = 1415, continent = 0, rect = { -7000, -9500, -5000, -6500 } },
	-- A cave inside Darkshore: its rectangle holds Auberdine's docks, and it must show none.
	[1600] = { name = "Auberdine Cellar", type = 5, parent = 1439, continent = 1, rect = { 7000, 6000, 1500, 0 } },
	-- A continent that is one zone.
	[2500] = { name = "Zephras Isle", type = 3, continent = 2991, rect = { 3000, 0, 2000, 0 } },
}
for id, m in pairs(Maps) do
	m.id = id
end
TopMap = { [0] = 1415, [1] = 1414, [2991] = 2500 }

-- What the client answers for a map of another continent is not known. true: a place in range
-- (the worst case, so the feature's own continent check is what keeps those pins off).
WrongContinentInRange = true

local function Norm(rect, wx, wy)
	return (rect[3] - wy) / (rect[3] - rect[4]), (rect[1] - wx) / (rect[1] - rect[2])
end
local function Inside(rect, wx, wy)
	return wx <= rect[1] and wx >= rect[2] and wy <= rect[3] and wy >= rect[4]
end
local function Info(m)
	return { mapID = m.id, name = m.name, mapType = m.type, parentMapID = m.parent or 0 }
end

MapCalls = 0 -- how often the client was asked to place a world position
PlayerMapID = 1439
C_Map = {
	GetMapInfo = function(id)
		return Maps[id] and Info(Maps[id]) or nil
	end,
	GetMapPosFromWorldPos = function(continent, vec, override)
		MapCalls = MapCalls + 1
		local m = Maps[override or TopMap[continent]]
		if not m then
			return nil
		end
		if m.parts then -- the world map: each continent has its strip
			local part, top = m.parts[continent], Maps[m.tops[continent] or 0]
			if not part or not top then
				return nil
			end
			local x, y = Norm(top.rect, vec.x, vec.y)
			return m.id, { x = part[1] + x * (part[2] - part[1]), y = y }
		end
		if m.continent ~= continent then
			if WrongContinentInRange then
				return m.id, { x = 0.5, y = 0.5 }
			end
			return nil
		end
		local x, y = Norm(m.rect, vec.x, vec.y)
		return m.id, { x = x, y = y }
	end,
	GetWorldPosFromMapPos = function(id, vec)
		local m = Maps[id]
		if not m or not m.rect then
			return nil
		end
		return m.continent, { x = m.rect[1] - vec.y * (m.rect[1] - m.rect[2]), y = m.rect[3] - vec.x * (m.rect[3] - m.rect[4]) }
	end,
	GetMapInfoAtPosition = function(id, x, y)
		local m = Maps[id]
		if not m or not m.rect then
			return nil
		end
		local wx, wy = m.rect[1] - y * (m.rect[1] - m.rect[2]), m.rect[3] - x * (m.rect[3] - m.rect[4])
		local ids = {}
		for kid in pairs(Maps) do
			ids[#ids + 1] = kid
		end
		table.sort(ids)
		for _, kid in ipairs(ids) do
			local k = Maps[kid]
			if k.parent == id and k.type == 3 and Inside(k.outline or k.rect, wx, wy) then
				return Info(k)
			end
		end
		return Info(m)
	end,
	GetMapChildrenInfo = function(id, kind)
		local out = {}
		for _, k in pairs(Maps) do
			if k.parent == id and (kind == nil or k.type == kind) then
				out[#out + 1] = Info(k)
			end
		end
		table.sort(out, function(a, b)
			return a.mapID < b.mapID
		end)
		return out
	end,
	GetBestMapForUnit = function()
		return PlayerMapID
	end,
}

-- Frames remember where they were put and at what scale.
local plainCreate = CreateFrame
function CreateFrame(kind, name, parent)
	local f = plainCreate(kind, name, parent)
	f.scale = 1
	function f:SetScale(s)
		self.scale = s
	end
	function f:GetScale()
		return rawget(self, "scale")
	end
	function f:SetPoint(point, to, toPoint, x, y)
		self.point, self.anchor, self.px, self.py = point, to, x, y
	end
	function f:SetMouseClickEnabled(on)
		self.clicks = on
	end
	return f
end

-- The world map: a canvas of 1000 by 600, zoomed by CanvasScale.
CanvasScale = 1
local canvas = plainCreate("Frame")
function canvas:GetWidth()
	return 1000
end
function canvas:GetHeight()
	return 600
end
WorldMapFrame = plainCreate("Frame", "WorldMapFrame")
WorldMapFrame.shown = false
function WorldMapFrame:GetMapID()
	return rawget(self, "mapID")
end
function WorldMapFrame:GetCanvas()
	return canvas
end
function WorldMapFrame:GetCanvasScale()
	return CanvasScale
end
function WorldMapFrame:OnMapChanged() end
function WorldMapFrame:OnCanvasScaleChanged() end
function WorldMapFrame:OnCanvasSizeChanged() end
MapHooks = {}
function WorldMapFrame:HookScript(which, fn)
	MapHooks[which] = fn
end
MapCanvas = canvas

-- Opens the map on a zone the way the client does: shown, then told its map.
function OpenMap(id)
	WorldMapFrame.shown = true
	if MapHooks.OnShow then
		MapHooks.OnShow(WorldMapFrame)
	end
	WorldMapFrame.mapID = id
	WorldMapFrame:OnMapChanged()
end
function CloseMap()
	WorldMapFrame.shown = false
	if MapHooks.OnHide then
		MapHooks.OnHide(WorldMapFrame)
	end
end
function ZoomMap(scale)
	CanvasScale = scale
	WorldMapFrame:OnCanvasScaleChanged()
end

-- The tooltip remembers its title.
function GameTooltip:SetText(t)
	self.title = t
end
