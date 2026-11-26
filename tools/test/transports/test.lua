-- Boats And Zeppelins behavior checks. Runs after stubs.lua and the whole bundle.

local failures, count = 0, 0
local realPrint = print
local function check(label, got, want)
	count = count + 1
	if got ~= want then
		failures = failures + 1
		realPrint("FAIL: " .. label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
	else
		realPrint("ok:   " .. label)
	end
end
local function near(label, got, want)
	check(label, type(got) == "number" and math.abs(got - want) < 0.01, true)
end
local function has(list, needle)
	for _, l in ipairs(list) do
		if tostring(l):find(needle, 1, true) then
			return true
		end
	end
	return false
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

local root = __ns
local ns = root.features.transports

-- The pins the map shows now.
local function Shown()
	local out = {}
	for _, pin in ipairs(ns.Pins()) do
		if pin:IsShown() and rawget(pin, "dock") then
			out[#out + 1] = pin
		end
	end
	return out
end
-- The shown pin whose label is this, or nil.
local function PinFor(label)
	for _, pin in ipairs(Shown()) do
		if ns.Label(pin.dock) == label then
			return pin
		end
	end
	return nil
end
local function DockLabels()
	local out = {}
	for _, dock in ipairs(ns.Docks()) do
		out[#out + 1] = (dock.name or "?") .. ": " .. ns.Label(dock)
	end
	return out
end

-- ---------------------------------------------------------------- lifecycle

FireEvent("ADDON_LOADED", "KroolWorldForever")
local db = KroolWorldForeverDB.features.transports
check("feature slice created", type(db), "table")
check("on by default", db.enabled, true)
check("continent maps on by default", db.continent, true)
check("pin size default", db.size, 22)
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("enabled after login", ns.enabled, true)
check("/kwb registered", SLASH_KROOLWORLDFOREVER_TRANSPORTS1, "/kwb")
check("hub icon", type(ns.icon), "string")
check("hub blurb", type(ns.blurb), "string")
check("the map's show is hooked", type(MapHooks.OnShow), "function")
local changed = WorldMapFrame.OnMapChanged
ns.OnEnable()
check("the map is hooked once only", WorldMapFrame.OnMapChanged, changed)
check("no pins before the map opens", #Shown(), 0)

-- ---------------------------------------------------------------- data

check("data: build", type(ns.Data.build), "string")
check("data: 13 routes", #ns.Data.routes, 13)
local twoPlus = true
for _, r in ipairs(ns.Data.routes) do
	twoPlus = twoPlus and #r.stops >= 2
end
check("data: every route has two stops or more", twoPlus, true)

-- ---------------------------------------------------------------- docks

local docks = ns.Docks()
check("22 docks", #docks, 22)
check("the docks are kept once every zone has a name", ns.Docks(), docks)
local labels = DockLabels()
check("Stormwind's boat goes to Darkshore", has(labels, "Stormwind City: Boat to Darkshore"), true)
check("a dock's end in open water takes the zone whose map holds it", has(labels, "Darkshore: Boat to Stormwind City"), true)
check("one dock, two routes: both destinations, each once", has(labels, "Wetlands: Boat to Darkshore, Hillsbrad Foothills"), true)
check("the new stop in Hillsbrad", has(labels, "Hillsbrad Foothills: Boat to Wetlands, Darkshore"), true)
check("Orgrimmar's two zeppelins share a tower", has(labels, "Durotar: Zeppelin to Stranglethorn Vale, Tirisfal Glades"), true)
check("Grom'gol's zeppelins", has(labels, "Stranglethorn Vale: Zeppelin to Durotar, Tirisfal Glades"), true)
check("Menethil's other dock is its own pin", has(labels, "Wetlands: Boat to Dustwallow Marsh"), true)
check("Ratchet is in the Barrens, not the map beside it", has(labels, "The Barrens: Boat to Stranglethorn Vale"), true)
check("a boat that stays in one zone", has(labels, "Feralas: Boat to Feralas"), true)
check("the new boat from Tanaris", has(labels, "Tanaris: Boat to Powderfuse Port"), true)
check("a continent that is one zone has a name", has(labels, "Silverpine Forest: Zeppelin to Zephras Isle"), true)
check("an airship stop on the isle", has(labels, "Zephras Isle: Zeppelin to Mulgore"), true)
local zeppelins = 0
for _, dock in ipairs(docks) do
	zeppelins = zeppelins + (dock.zeppelin and 1 or 0)
end
check("7 zeppelin towers", zeppelins, 7)

-- Before the maps can name a zone, a dock is still a dock; the list is built again later.
local api = C_Map
C_Map = nil
ns.docks = nil
local bare = ns.Docks()
check("no map API: the docks are still listed", #bare, 22)
check("no map API: a plain label", ns.Label(bare[1]), "Boat")
check("no map API: the list is not kept", ns.docks, nil)
check("no map API: no pins, no error", #ns.DocksOn(1439), 0)
C_Map = api
check("the map API is back: names again", has(DockLabels(), "Stormwind City: Boat to Darkshore"), true)

-- ---------------------------------------------------------------- pins

OpenMap(1439)
check("Darkshore: Auberdine's three docks", #Shown(), 3)
local pin = PinFor("Boat to Stormwind City")
check("Darkshore: the Stormwind boat has a pin", pin ~= nil, true)
check("a boat's icon", pin.icon.atlas, ns.ATLAS.boat)
check("the pin is on the map's canvas", pin.anchor, MapCanvas)
check("the pin is anchored by its middle", pin.point, "CENTER")
near("placed across: (2600 - 942.2) / 2700 of 1000", pin.px, 614.0)
near("placed down: (8300 - 6548.3) / 4000 of 600", pin.py, -262.755)
check("pin size from the option", pin.width, 22)
check("a click goes through to the map", pin.clicks, false)
check("no dock of the other continent, though the client places it in range", PinFor("Boat to Darkshore"), nil)

ZoomMap(2)
check("zoomed in: the pin shrinks against the canvas", pin.scale, 0.5)
near("zoomed in: its place is counted in its own scale", pin.px, 1228.0)
ZoomMap(1)
check("zoomed out again", pin.scale, 1)

GameTooltip:Reset()
GameTooltip.title = nil
pin.scripts.OnEnter(pin)
check("tooltip: what it is", GameTooltip.title, "Boat")
check("tooltip: where it goes", has(GameTooltip.lines, "To Stormwind City"), true)
check("tooltip: where it is", has(GameTooltip.lines, "Darkshore"), true)

OpenMap(1438)
check("Teldrassil: Rut'theran only", #Shown(), 1)
check("Teldrassil: the boat to Darkshore", PinFor("Boat to Darkshore") ~= nil, true)
OpenMap(1411)
check("Durotar: one tower for both zeppelins, and Ratchet's dock at the map's edge", #Shown(), 2)
check("a zeppelin's icon", PinFor("Zeppelin to Stranglethorn Vale, Tirisfal Glades").icon.atlas, ns.ATLAS.zeppelin)
OpenMap(1429)
check("Elwynn: the city's dock is on its map too", PinFor("Boat to Darkshore") ~= nil, true)
OpenMap(2500)
check("Zephras Isle: both airship stops", #Shown(), 2)
OpenMap(1600)
check("a cave's map shows none", #Shown(), 0)
OpenMap(1414)
check("Kalimdor: its 11 docks", #Shown(), 11)
OpenMap(947)
check("the world map: every dock of both continents", #Shown(), 20)

capture(function()
	RegisteredSettings["KroolWorldForever_transports_continent"]:SetValue(false)
end)
check("continent maps off: the option is saved", db.continent, false)
check("continent maps off: the world map clears at once", #Shown(), 0)
OpenMap(1414)
check("continent maps off: Kalimdor shows none", #Shown(), 0)
OpenMap(1439)
check("continent maps off: a zone still shows its docks", #Shown(), 3)
capture(function()
	RegisteredSettings["KroolWorldForever_transports_continent"]:SetValue(true)
	RegisteredSettings["KroolWorldForever_transports_size"]:SetValue(30)
end)
check("pin size changes at once", Shown()[1].width, 30)

CloseMap()
check("the map closed: no pins", #Shown(), 0)
OpenMap(1439)
check("the map opened again: the pins are back", #Shown(), 3)
check("pins are reused, not made again", #ns.Pins(), 20)

-- A map the client cannot place a continent for still shows what falls on it.
WrongContinentInRange = false
OpenMap(1438)
check("the client answers nothing for the other continent: same pins", #Shown(), 1)
WrongContinentInRange = true

-- ---------------------------------------------------------------- commands

PlayerMapID = 1439
local out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("")
end)
check("/kwb: the zone", has(out, "Darkshore:"), true)
check("/kwb: its boats", has(out, "Boat to Stormwind City"), true)
check("/kwb: three lines for three docks", #out, 4)
check("hub: what is here", ns.HubStatus():find("Here: Boat to", 1, true) ~= nil, true)
PlayerMapID = 1412 + 9000 -- nowhere the maps know
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("")
end)
check("/kwb: nothing here", has(out, "No boat or zeppelin stops"), true)
check("hub: the count when nothing is here", ns.HubStatus(), "22 docks on the map")
PlayerMapID = 1446
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("")
end)
check("/kwb in Tanaris: the new boat", has(out, "Boat to Powderfuse Port"), true)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("all")
end)
check("/kwb all: the count and the data's build", has(out, "22 docks on 13 routes (game data " .. ns.Data.build .. ")"), true)
check("/kwb all: one line per dock, a header and a note", #out, 24)
check("/kwb all: says what the data cannot know", has(out, "cannot say whether the server runs a route"), true)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("help")
end)
check("/kwb help", has(out, "/kwb all"), true)
OpenedCategory = nil
SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("options")
check("/kwb options opens the settings", OpenedCategory ~= nil, true)

-- ---------------------------------------------------------------- portals

check("data: one portal by hand", #ns.PORTALS, 1)
check("not Skyborne: no portal in the list", #ns.Docks(), 22)
OpenMap(1416)
check("not Skyborne: Alterac shows only the airship stop", #Shown(), 1)
check("not Skyborne: no portal pin", PinFor("Portal to Stormwind City"), nil)

PlayerRaceID = 96
ns.docks = nil
check("Windshaper Skyborne (Horde): no portal", #ns.Docks(), 22)

PlayerRaceID = nil
ns.docks = nil
check("race not known yet: no portal", #ns.Docks(), 22)
check("race not known yet: the list is not kept", ns.docks, nil)

PlayerRaceID = 95
ns.docks = nil
local withPortal = ns.Docks()
check("High Order Skyborne: the portal joins the list", #withPortal, 23)
check("High Order Skyborne: the list is kept", ns.Docks(), withPortal)
check("the portal's label and zone", has(DockLabels(), "Alterac Mountains: Portal to Stormwind City"), true)
local stops, portals = ns.Counts()
check("counts: docks", stops, 22)
check("counts: portals", portals, 1)
check("the airship stop beside it keeps its zone", has(DockLabels(), "Silverpine Forest: Zeppelin to Zephras Isle"), true)

OpenMap(1416)
check("Alterac: the portal and the airship stop", #Shown(), 2)
local portal = PinFor("Portal to Stormwind City")
check("Alterac: the portal has a pin", portal ~= nil, true)
check("a portal's icon", portal.icon.atlas, ns.ATLAS.portal)
-- What the game printed at the portal: map 1416 at 0.1209, 0.5653.
near("placed across where the game put it: 0.1209 of 1000", portal.px, 120.9)
near("placed down where the game put it: 0.5653 of 600", portal.py, -339.17)
GameTooltip:Reset()
GameTooltip.title = nil
portal.scripts.OnEnter(portal)
check("portal tooltip: what it is", GameTooltip.title, "Portal")
check("portal tooltip: where it goes", has(GameTooltip.lines, "To Stormwind City"), true)
check("portal tooltip: where it is", has(GameTooltip.lines, "Alterac Mountains"), true)
OpenMap(1415)
check("the continent map: no portal pin", PinFor("Portal to Stormwind City"), nil)
check("the continent map: the airship stop still shows", PinFor("Zeppelin to Zephras Isle") ~= nil, true)
OpenMap(947)
check("the world map: no portal pin, the same 20 docks", #Shown(), 20)

PlayerMapID = 1416
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("")
end)
check("/kwb in Alterac: the portal", has(out, "Portal to Stormwind City"), true)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("all")
end)
check("/kwb all: the portal counted apart", has(out, "22 docks on 13 routes, 1 portal (game data"), true)
check("/kwb all: a line for the portal", #out, 25)
PlayerMapID = 1412 + 9000
check("hub: a portal is not a dock", ns.HubStatus(), "22 docks on the map")

PlayerRaceID = 1
ns.docks = nil
CloseMap()

-- ---------------------------------------------------------------- off

OpenMap(1439)
check("on: pins shown", #Shown(), 3)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("transports off")
end)
check("/kwf transports off", ns.enabled, false)
check("off: the pins go at once", #Shown(), 0)
OpenMap(1414)
check("off: another map shows none", #Shown(), 0)
ZoomMap(2)
check("off: zooming shows none", #Shown(), 0)
ZoomMap(1)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("")
end)
check("off: /kwb says it is off", has(out, "is off"), true)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("transports on")
end)
check("/kwf transports on", ns.enabled, true)
check("on again: the open map gets its pins", #Shown(), 11)

local mine = 0
for _, err in ipairs(KroolWorldForeverDB.errors or {}) do
	if err.feature == "transports" then
		mine = mine + 1
		realPrint("  caught: " .. tostring(err.where) .. ": " .. tostring(err.message))
	end
end
check("no errors caught in Boats And Zeppelins", mine, 0)

realPrint(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
