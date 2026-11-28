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
local stopCount, waits, towns = 0, 0, 0
for _, r in ipairs(ns.Data.routes) do
	for _, stop in ipairs(r.stops) do
		stopCount = stopCount + 1
		waits = waits + ((type(stop.wait) == "number" and stop.wait > 0) and 1 or 0)
		towns = towns + ((type(stop.node) == "number" and type(stop.town) == "string") and 1 or 0)
	end
end
check("data: every stop has its wait", waits, stopCount)
check("data: 21 stops stand beside a flight master", towns, 21)

-- ---------------------------------------------------------------- docks

local docks = ns.Docks()
check("22 docks, two portals and two tram stops", #docks, 26)
check("the docks are kept once every zone has a name", ns.Docks(), docks)
local labels = DockLabels()
check("Stormwind's boat goes to Auberdine", has(labels, "Stormwind City: Boat to Auberdine"), true)
check("a dock's end in open water takes the zone whose map holds it", has(labels, "Darkshore: Boat to Stormwind"), true)
check("one dock, two routes: both destinations, each once", has(labels, "Wetlands: Boat to Auberdine, Southshore"), true)
check("the new stop in Hillsbrad", has(labels, "Hillsbrad Foothills: Boat to Menethil Harbor, Auberdine"), true)
check("Orgrimmar's two zeppelins share a tower", has(labels, "Durotar: Zeppelin to Grom'gol, Undercity"), true)
check("Grom'gol's zeppelins", has(labels, "Stranglethorn Vale: Zeppelin to Orgrimmar, Undercity"), true)
check("Menethil's other dock is its own pin", has(labels, "Wetlands: Boat to Theramore"), true)
check("Ratchet is in the Barrens, not the map beside it", has(labels, "The Barrens: Boat to Booty Bay"), true)
check("a boat that stays in one zone: the island names the coast by its zone", has(labels, "Feralas: Boat to Feralas"), true)
check("a boat that stays in one zone: the coast names the island's town", has(labels, "Feralas: Boat to Feathermoon"), true)
check("the new boat from Tanaris", has(labels, "Tanaris: Boat to Powderfuse Port"), true)
check("a continent that is one zone has a name", has(labels, "Silverpine Forest: Zeppelin to Zephras Isle"), true)
check("an airship stop on the isle", has(labels, "Zephras Isle: Zeppelin to Thunder Bluff"), true)
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
check("no map API: the docks are still listed", #bare, 26)
check("no map API: a plain label", ns.Label(bare[1]), "Boat")
check("no map API: the list is not kept", ns.docks, nil)
check("no map API: no pins, no error", #ns.DocksOn(1439), 0)
C_Map = api
check("the map API is back: names again", has(DockLabels(), "Stormwind City: Boat to Auberdine"), true)

-- ---------------------------------------------------------------- pins

OpenMap(1439)
check("Darkshore: Auberdine's three docks", #Shown(), 3)
local pin = PinFor("Boat to Stormwind")
check("Darkshore: the Stormwind boat has a pin", pin ~= nil, true)
check("a boat's icon", pin.icon.atlas, ns.ATLAS.boat)
check("the pin is on the map's canvas", pin.anchor, MapCanvas)
check("the pin is anchored by its middle", pin.point, "CENTER")
near("placed across: (2600 - 942.2) / 2700 of 1000", pin.px, 614.0)
near("placed down: (8300 - 6548.3) / 4000 of 600", pin.py, -262.755)
check("pin size from the option", pin.width, 22)
check("a click goes through to the map", pin.clicks, false)
check("no dock of the other continent, though the client places it in range", PinFor("Boat to Auberdine"), nil)

ZoomMap(2)
check("zoomed in: the pin shrinks against the canvas", pin.scale, 0.5)
near("zoomed in: its place is counted in its own scale", pin.px, 1228.0)
ZoomMap(1)
check("zoomed out again", pin.scale, 1)

GameTooltip:Reset()
GameTooltip.title = nil
pin.scripts.OnEnter(pin)
check("tooltip: what it is", GameTooltip.title, "Boat")
check("tooltip: where it goes, the zone alone when it says the town", has(GameTooltip.lines, "To Stormwind City |cffaaaaaa(Alliance)|r"), true)
check("tooltip: where it is, town and zone", has(GameTooltip.lines, "Auberdine, Darkshore |cffaaaaaa(Alliance)|r"), true)
check("tooltip: how long it waits", has(GameTooltip.lines, "Waits 1 minute at the dock"), true)

OpenMap(1438)
check("Teldrassil: Rut'theran's dock and the two ends of Darnassus' portal", #Shown(), 3)
check("Teldrassil: the boat to Auberdine", PinFor("Boat to Auberdine") ~= nil, true)
OpenMap(1411)
check("Durotar: one tower for both zeppelins, and Ratchet's dock at the map's edge", #Shown(), 2)
check("a zeppelin's icon", PinFor("Zeppelin to Grom'gol, Undercity").icon.atlas, ns.ATLAS.zeppelin)
OpenMap(1429)
check("Elwynn: the city's dock is on its map too", PinFor("Boat to Auberdine") ~= nil, true)
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
check("the client answers nothing for the other continent: same pins", #Shown(), 3)
WrongContinentInRange = true

-- ---------------------------------------------------------------- commands

PlayerMapID = 1439
local out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("")
end)
check("/kwb: the zone", has(out, "Darkshore:"), true)
check("/kwb: its boats", has(out, "Boat to Stormwind"), true)
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
check("/kwb all: the count and the data's build", has(out, "22 docks on 13 routes, 2 portals, 2 tram stops (game data " .. ns.Data.build .. ")"), true)
check("/kwb all: one line per dock, a header and a note", #out, 28)
check("/kwb all: a dock is listed by town and zone", has(out, "Ratchet, The Barrens: Boat to Booty Bay"), true)
check("/kwb all: says what the data cannot know", has(out, "cannot say whether the server runs a route"), true)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("help")
end)
check("/kwb help", has(out, "/kwb all"), true)
OpenedCategory = nil
SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("options")
check("/kwb options opens the settings", OpenedCategory ~= nil, true)

-- ---------------------------------------------------------------- portals

check("data: three portals and two tram stops by hand", #ns.PORTALS, 5)
check("not Skyborne: Dalaran's portal is not in the list", #ns.Docks(), 26)
OpenMap(1416)
check("not Skyborne: Alterac shows only the airship stop", #Shown(), 1)
check("not Skyborne: no portal pin", PinFor("Portal to Stormwind City"), nil)

PlayerRaceID = 96
ns.docks = nil
check("Windshaper Skyborne (Horde): no Dalaran portal", #ns.Docks(), 26)

PlayerRaceID = nil
ns.docks = nil
check("race not known yet: no Dalaran portal", #ns.Docks(), 26)
check("race not known yet: the list is not kept", ns.docks, nil)

PlayerRaceID = 95
ns.docks = nil
local withPortal = ns.Docks()
check("High Order Skyborne: the portal joins the list", #withPortal, 27)
check("High Order Skyborne: the list is kept", ns.Docks(), withPortal)
check("the portal's label and zone", has(DockLabels(), "Alterac Mountains: Portal to Stormwind City"), true)
local stops, portals, trams = ns.Counts()
check("counts: docks", stops, 22)
check("counts: portals", portals, 3)
check("counts: tram stops", trams, 2)
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
check("/kwb all: the portal counted apart", has(out, "22 docks on 13 routes, 3 portals, 2 tram stops (game data"), true)
check("/kwb all: a line for the portal", #out, 29)
PlayerMapID = 1412 + 9000
check("hub: a portal is not a dock", ns.HubStatus(), "22 docks on the map")

PlayerRaceID = 1
ns.docks = nil
CloseMap()

-- ---------------------------------------------------------------- towns, sides and waits

local function Tip(p)
	GameTooltip:Reset()
	GameTooltip.title = nil
	p.scripts.OnEnter(p)
	return GameTooltip.lines
end
local function DockAt(label, zone)
	for _, dock in ipairs(ns.Docks()) do
		if ns.Label(dock) == label and (zone == nil or dock.name == zone) then
			return dock
		end
	end
	return nil
end

OpenMap(1411)
local tower = PinFor("Zeppelin to Grom'gol, Undercity")
local lines = Tip(tower)
check("an Alliance player: a Horde town it goes to is red", has(lines, "To Grom'gol, Stranglethorn Vale |cffff5555(Horde)|r"), true)
check("an Alliance player: the Horde town it stands in is red", has(lines, "Orgrimmar, Durotar |cffff5555(Horde)|r"), true)
PlayerFaction = "Horde"
check("a Horde player: the same town is grey", has(Tip(tower), "Orgrimmar, Durotar |cffaaaaaa(Horde)|r"), true)
PlayerFaction = nil
check("side not known: grey, never red", has(Tip(tower), "|cffff5555"), false)
PlayerFaction = "Alliance"
check("a town of both sides has no tag", ns.SideTag(DockAt("Boat to Booty Bay")), "")
check("a dock with no flight master beside it has no tag", ns.SideTag(DockAt("Boat to Powderfuse Port")), "")
check("a dock with no flight master is its zone alone", ns.Place(DockAt("Boat to Powderfuse Port")), "Tanaris")
check("town and zone", ns.Place(DockAt("Boat to Booty Bay")), "Ratchet, The Barrens")
check("a zone that says the town stands alone", ns.Place(DockAt("Boat to Auberdine", "Stormwind City")), "Stormwind City")
check("waits: one minute", ns.Wait(DockAt("Boat to Booty Bay")), "Waits 1 minute at the dock")
check("waits: a round trip's two halves are one wait", ns.Wait(DockAt("Boat to Feralas")), "Waits 1 minute at the dock")
check("waits: 30 seconds", ns.Wait({ waits = { 30 } }), "Waits 30 seconds at the dock")
check("waits: two transports that differ", ns.Wait({ waits = { 120, 60 } }), "Waits 1 minute or longer at the dock")
check("waits: nothing to say of a portal", ns.Wait({ waits = {} }), nil)

-- The client's own names for the flight masters: the town in the player's language.
check("the client named no flight master: the English town", DockAt("Boat to Booty Bay") ~= nil, true)
TaxiNodes[1415] = { { 18, "Beutebucht, Schlingendorntal" }, { 7, "Hafen von Menethil" } }
ns.docks = nil
check("the client's name for the town wins", DockAt("Boat to Beutebucht") ~= nil, true)
check("a name without a comma is the town", DockAt("Boat to Hafen von Menethil, Auberdine") ~= nil, true)
check("a town the client did not name keeps the English one", DockAt("Zeppelin to Orgrimmar, Undercity") ~= nil, true)
local asked = TaxiCalls
ns.docks = nil
ns.Docks()
check("a continent's flight masters are asked for once", TaxiCalls - asked <= 12, true)
TaxiNodes[1415] = nil
ns.taxi = {}
ns.docks = nil

-- ---------------------------------------------------------------- the tram and Darnassus

OpenMap(1453)
check("Stormwind City: the harbor's dock and the tram", #Shown(), 2)
local tram = PinFor("Tram to Ironforge")
check("Stormwind City: the tram has a pin", tram ~= nil, true)
check("the tram's icon", tram.icon.atlas, ns.ATLAS.tram)
lines = Tip(tram)
check("tram tooltip: what it is", GameTooltip.title, "Tram")
check("tram tooltip: where it goes", has(lines, "To Ironforge |cffaaaaaa(Alliance)|r"), true)
check("tram tooltip: no wait is claimed", has(lines, "Waits"), false)
OpenMap(1455)
check("Ironforge: the tram back", PinFor("Tram to Stormwind City") ~= nil, true)
OpenMap(1429)
check("Elwynn: the tram shows where its map reaches the city", PinFor("Tram to Ironforge") ~= nil, true)
OpenMap(1438)
local gate = PinFor("Portal to Darnassus")
check("Teldrassil: the portal at Rut'theran", gate ~= nil, true)
check("a portal's icon", gate.icon.atlas, ns.ATLAS.portal)
check("portal tooltip: where it stands", has(Tip(gate), "Rut'theran Village, Teldrassil"), true)
check("Teldrassil: the portal back, named by the village", PinFor("Portal to Rut'theran Village") ~= nil, true)
OpenMap(1457)
check("Darnassus: its portal", PinFor("Portal to Rut'theran Village") ~= nil, true)
check("portal tooltip: village and zone", has(Tip(PinFor("Portal to Rut'theran Village")), "To Rut'theran Village, Teldrassil"), true)
OpenMap(1415)
check("the continent map: no tram pin", PinFor("Tram to Ironforge"), nil)
OpenMap(1414)
check("the continent map: no portal pin, the same 11 docks", #Shown(), 11)
CloseMap()

-- ---------------------------------------------------------------- nearest, search and the map pin

PlayerMapID = 1440 -- Ashenvale: no dock
PlayerPos = { 0.5, 0.5 } -- world 2950, -700
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("")
end)
check("/kwb in a zone with no dock says so", has(out, "No boat or zeppelin stops in Ashenvale"), true)
check("and names the nearest dock", has(out, "Nearest: Auberdine, Darkshore: Boat to Menethil Harbor, Southshore"), true)
check("with how far it is", has(out, "(3,777 yards)"), true)
check("and how to mark it", has(out, "/kwb go marks it on your map"), true)
Waypoint, Tracked = nil, false
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("go")
end)
check("/kwb go: says what it marked", has(out, "Marked on your map: Auberdine, Darkshore: Boat to Menethil Harbor, Southshore"), true)
check("/kwb go: the pin is on the dock's zone map", Waypoint and Waypoint.uiMapID, 1439)
near("/kwb go: across, (2600 - 823.1) / 2700", Waypoint and Waypoint.x, 0.6581)
near("/kwb go: down, (8300 - 6406.2) / 4000", Waypoint and Waypoint.y, 0.4734)
check("/kwb go: the pin is followed", Tracked, true)
Waypoint = nil
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("go undercity")
end)
check("/kwb go <place>: the nearest dock that goes there", has(out, "Marked on your map: Orgrimmar, Durotar: Zeppelin to Grom'gol, Undercity"), true)
check("/kwb go <place>: its pin", Waypoint and Waypoint.uiMapID, 1411)
Waypoint = nil
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("go Ironforge")
end)
check("/kwb go <place> on another continent: says so", has(out, "Nothing on this continent goes to \"ironforge\""), true)
check("/kwb go <place> on another continent: no pin", Waypoint, nil)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("go xyzzy")
end)
check("/kwb go <nowhere>", has(out, "goes to \"xyzzy\""), true)
NoPinMaps[1439], NoPinMaps[1414] = true, true
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("go")
end)
check("a map that takes no pin: says so, and still names the dock", has(out, "The map takes no pin there. Nearest: Auberdine, Darkshore"), true)
check("a map that takes no pin: none set", Waypoint, nil)
NoPinMaps[1439] = nil
capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("go")
end)
check("the zone map takes it again", Waypoint and Waypoint.uiMapID, 1439)
NoPinMaps[1439], NoPinMaps[1414] = true, nil
Waypoint = nil
capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("go")
end)
check("the zone map takes none: the continent map does", Waypoint and Waypoint.uiMapID, 1414)
NoPinMaps[1439] = nil

out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("Stormwind")
end)
check("/kwb <place>: a header", has(out, "To \"stormwind\":"), true)
check("/kwb <place>: the boat, by town", has(out, "Auberdine, Darkshore: Boat to Stormwind"), true)
check("/kwb <place>: the tram, by its zone's name", has(out, "Ironforge: Tram to Stormwind City"), true)
check("/kwb <place>: the nearest comes first, with its distance", out[2]:find("Auberdine, Darkshore: Boat to Stormwind", 1, true) ~= nil and out[2]:find("yards", 1, true) ~= nil, true)
check("/kwb <place>: a dock on another continent has no distance", out[3]:find("yards", 1, true), nil)
check("/kwb <place>: how to mark the nearest", has(out, "/kwb go stormwind marks the nearest"), true)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("xyzzy")
end)
check("/kwb <nowhere>", has(out, "No boat, zeppelin, portal or tram goes to \"xyzzy\""), true)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("help")
end)
check("/kwb help names go", has(out, "/kwb go [place]"), true)

PlayerPos = nil -- a dungeon: the client will not say where the player is
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("")
end)
check("place unknown: no nearest line", has(out, "Nearest:"), false)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("go")
end)
check("place unknown: /kwb go says so", has(out, "Cannot tell where you are here."), true)
issecretvalue = function(v)
	return v == 0.25
end
PlayerPos = { 0.25, 0.5 }
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_TRANSPORTS("go")
end)
check("a secret position: no pin, no error", has(out, "Cannot tell where you are here."), true)
issecretvalue = nil
PlayerPos = nil
local saved = { C_Map.SetUserWaypoint, UiMapPoint }
C_Map.SetUserWaypoint, UiMapPoint = nil, nil
check("a client without map pins: Mark says no", ns.Mark(ns.Docks()[1]), false)
C_Map.SetUserWaypoint, UiMapPoint = saved[1], saved[2]
PlayerMapID = 1439

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
