# Boats And Zeppelins (feature)

**Held (2026-11-18): on the owner's install only, not released.** First seen in the game the same day (the owner's two screenshots).

**A pin on the world map at every boat dock and zeppelin tower.** Hover a pin for where it goes.

- Zone maps always show their docks. Continent maps and the world map show them too (option
  **Show On Continent Maps**, on by default). A dungeon's or a cave's map shows none.
- A dock near a zone's edge also shows on the neighbor's map when that map's picture reaches it
  (Stormwind's harbor on Elwynn's map).
- Stops within 100 yards on one continent share a pin: both Orgrimmar zeppelins leave from one
  tower, and the pin lists both destinations.
- The tooltip: **Boat** or **Zeppelin**, a "To <zone>" line per destination, then the dock's own
  zone. A stop more than 20 yards above sea level is a zeppelin tower.
- `/kwb` lists the docks of the zone you are in, `/kwb all` every dock with its destinations and
  the game build the data is from, `/kwb options` opens the settings.
- Option **Pin Size** (12 to 36, default 22).
- Display only: a click on a pin goes through to the map.

## Where the routes come from

`tools/transports-data/gen-data.js` reads Forever's own `TaxiPathNode` table (wago.tools). A
transport rides a taxi path like a flight does; its stops are the nodes with the stop flag and a
wait. Build 1.60.1.70938 has 13 such paths, 22 docks:

| Path | Route (zones as the client names them) |
|---|---|
| 241 | Ratchet - Booty Bay |
| 285 | Grom'gol - Orgrimmar (zeppelin) |
| 292 | Menethil - Theramore |
| 293 | Rut'theran - Auberdine |
| 295 | Menethil - Auberdine |
| 301 | Grom'gol - Undercity (zeppelin) |
| 302 | Orgrimmar - Undercity (zeppelin) |
| 303 | Feathermoon - Feralas coast |
| 11167 | Menethil - Hillsbrad coast - Auberdine (new) |
| 11391 | Tanaris coast - far east of the Eastern Kingdoms (new; Powderfuse Port by its flight node) |
| 11398 | near Dalaran (Silverpine) - Zephras Isle (new, airship) |
| 11457 | Mulgore - Zephras Isle (new, airship) |
| 11616 | Auberdine - Stormwind (new; the owner named it, 2026-11-18) |

`run.js` fails when the data's build differs from the API allowlist's, like Skill-Up's and Reagent
Uses' data, so a new build's routes are picked up when the allowlist is rebuilt.

## Honest limits

- **The table cannot say whether the server runs a path.** Only 11616 is confirmed by the owner.
  295 and 11167 share both end docks, so one may have replaced the other; the pins are the same
  either way, the Menethil and Auberdine ones just list Hillsbrad too. A path that turns out not
  to exist goes in `SKIP` in the generator.
- **No arrival times and no faction.** Every dock shows for everyone.
- **Names are zones**, not towns: "Boat to Darkshore", not "Boat to Auberdine". The client names
  the zone a stop lies in, so they are in the player's language. Feathermoon's boat reads "Boat to
  Feralas" at both ends.
- **The Deeprun Tram is not a taxi path** and has no pin.
- **Icons:** `flightmasterferry` for a boat and `vehicle-air-occupied` for a zeppelin, both on the
  object icons sheet that holds `flightmaster` (which Forever's own transport rows use). Chosen
  from the atlas table; the boat is seen in the game, the zeppelin not yet. `ns.ATLAS` in
  `Transports.lua` is the one place to change.

## How the pins are drawn

Plain frames of the feature's own, parented to the world map's canvas and placed the way Blizzard
places its pins (`MapCanvasMixin:ApplyPinPosition`: scale `1 / canvas scale`, anchored at
`width * x / scale, -height * y / scale`). They are not acquired from the map's pin pools, which
addon code taints. The feature hooks `WorldMapFrame`'s `OnMapChanged`, `OnCanvasScaleChanged`,
`OnCanvasSizeChanged`, `OnShow` and `OnHide` once; the hooks do nothing while it is off.

`C_Map.GetMapPosFromWorldPos(continent, position, uiMapID)` turns a stop into a place on the map
being looked at. What it answers for a map of another continent is not known, so the feature
compares continents itself (`C_Map.GetWorldPosFromMapPos`) before asking.

## Seen in the game (2026-11-18, the owner's screenshots)

- The pins draw on the Hillsbrad zone map and the Eastern Kingdoms continent map, on the coast
  where the docks are: Hillsbrad's, Menethil, Stormwind, Booty Bay and the far east one.
- The boat icon draws (a boat in a ring).
- The tooltip on Hillsbrad's dock reads Boat, To Wetlands, To Darkshore, Hillsbrad Foothills.

Still to check: the zeppelin icon (the screenshot has other small icons beside it, so it could
not be told apart), that a click on a pin still moves the map, and which of the new routes the
server runs (`/kwb all`).
