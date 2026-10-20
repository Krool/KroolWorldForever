# Fog control in Forever

Researched 2026-10-20 against Forever build 1.60.1 (Ketho/BlizzardInterfaceResources `forever`
CVar dump, wow-ui-source `forever` Settings code, EULA). Sources at the bottom.

## Why this is interesting

Forever shipped a fog revamp: volumetric fog over the old world. The beta forum thread "Fog Revamp
Aesthetic Concerns" (Sept 2026) complains about a grey haze ("smog") over Westfall, Elwynn
and Mulgore and asks for a toggle and a density slider. **Blizzard's Graphics settings have no fog
control and no weather slider.**

## Blizzard closed the main lever (correction, 2026-10-20)

**`/console volumeFog 0` no longer turns the fog off.** The Sept 24 beta development notes say:
"Removed a setting that could disable fog in an unintended manner." After that build, testers report
the fog disappears "for a split second" and then snaps back, or only thins. The CVar still exists in
the dump (it is not flagged secure), but the client now overrides it. Blizzard has not replied to the
"please let us disable the fog" threads. The wording ("unintended") says the fog is meant to stay.

Consequences:

- The haze itself (volumetric fog) cannot be removed by a setting, an addon or a console command.
- An addon that re-applies `volumeFog 0` every frame to fight the reset would be circumventing a
  deliberate change. It would flicker at best, and it is the kind of thing that gets patched or
  frowned on. Not recommended.
- What is **untested** after Sept 24: the distance-fog CVars (`horizonStart`, `horizonClip`,
  `disableHorizonStart`), `farclip`, and `weatherDensity`. No report says they revert, but no report
  says they help with the haze either. Test them in-game at launch before building anything.

## The levers (CVars, none flagged secure; `volumeFog` now reverts)

| CVar | Default | Effect |
|---|---|---|
| `volumeFog` | 1 | **Reverts since Sept 24.** Was volumetric fog on/off. |
| `volumeFogLevel` | 3 | Fog quality 0-3 (not density). |
| `volumeFogInterior` | 1 | Volumetric fog indoors. |
| `disableHorizonStart` | 0 | **New in Forever.** Disables the "full fog" distance. |
| `horizonStart` | 800 | Where the distance-fog ramp starts. |
| `horizonClip` | 1600 | Where it ends. |
| `farclip` | 1000 | Draw distance. |
| `weatherDensity` | 2 | Weather intensity 0-3. |
| `ffxGlow` | | Full-screen glow. A guide (Pro-Gamer, Oct 19) says `0` "removes the milky bloom and glow haze overlay". Some of what players call fog may be glow, so this is the most promising untested lever. |
| `SkyCloudLOD`, `sunShafts`, `bloomEnable`, `bloomUserMult`, `giQuality`, `graphicsLightMode` | | Sky, bloom and lighting. |
| `RAID*` variants | | Same settings for the raid graphics profile. |

- Because none of these is secure, `C_CVar.SetCVar` from an addon works **any time, including combat**.
  Secure CVars (most nameplate ones) are the ones blocked in combat.
- Readable but not settable: `C_Weather.GetCurrentWeather()` (`type` Clear/Rain/Snow/Sandstorm/Misc,
  `intensity`) and the `WEATHER_CHANGED` event. An addon can react to weather but cannot change it.
- `C_CVar.SetTempCVar` / `RemoveTempCVar` are new in Forever and look like non-persisted overrides
  (inferred from the names). Worth testing: they would let an addon change fog without permanently
  rewriting the user's Config.wtf.

## What is NOT possible

- **Per-zone fog color, density, tint.** That comes from the client's Light DB2 data (LightData /
  LightParams: `fogEnd`, `fogDensity`, `skyFogColor`...). No API or CVar reaches it. A real "density
  slider" does not exist. The closest thing is moving the horizon distances, which may not touch the
  volumetric haze at all.
- **Editing game files** (Light.db2 overrides, "no fog" patches, model edits) or **memory editing**.
  The EULA §1.C bans modifying the client and unauthorized third-party software. The client monitors
  memory and checks files against CASC, so this is a ban risk. (OctoWoW's `patch-9.mpq` approach does not
  carry over.)

## Addon idea: ForeverFog (on hold)

**On hold until the launch test.** Without `volumeFog`, this can only move distance fog and weather.
If the horizon CVars do nothing visible to the haze, the idea is dead. If they help, it becomes a
small feature in the bundle. Original sketch:

- **Presets:** Blizzard default / Clear (volumetric off, horizon pushed out) / Light haze
  (volumetric on at lower quality, `disableHorizonStart 1`) / Atmospheric (everything on, weather 3) /
  Performance.
- **Sliders** for horizon start/end, farclip and weather density, plus a volumetric toggle, with a
  live preview.
- **Context rules:** different preset per zone, indoors vs outdoors, or per weather type
  (`WEATHER_CHANGED`), e.g. keep rain fog but kill the Westfall haze. Raid profile handled through the
  `RAID*` variants.
- **Restore:** snapshot the user's original values on first run and offer one-click restore. Prefer
  `SetTempCVar` if it turns out to be non-persistent.
- **Competition:** "Forever Graphics Panel" on CurseForge already offers fog, bloom and weather presets.
  "Foggin Stupid" (CurseForge, lists 1.60.1) is a minimap toggle for `volumeFog` only. Its last update
  was Sept 19, before the Sept 24 change, so it should hit the same revert. As of 2026-10-20 no addon
  has a working way around it.
  The differentiators would be per-zone and per-weather automation plus clean restore.
- **Risk:** Blizzard can mark these CVars secure or read-only in a later build (the Forever Graphics
  Panel author warns about this). Detect a blocked set and tell the user.

Effort: small (one evening for presets and restore, a bit more for zone/weather rules). No secret-value
exposure at all.

## Also possible: map fog of war

If "fog" means the unexplored parts of the world map: reveal addons (Leatrix Maps style) are
allowed and work on the Mainline map. They ship per-map tables of overlay textures and draw them
with a map data provider. `C_MapExplorationInfo.GetExploredMapTextures` only returns explored areas.
No Forever release of such an addon was found. Building the overlay tables from Forever's map and art
IDs (wago.tools) would be a solid niche addon, including Forever's new zones.

## To verify in-game

Pick one spot with heavy haze (Westfall or Elwynn at midday). Take a screenshot before each change
and after it, then undo the change before the next test so each result stands alone.

- [ ] `/console volumeFog 0`: confirm it still snaps back, or only thins the fog (forum reports differ).
- [ ] `/console ffxGlow 0` (undo: `1`): does the milky haze go, or only bloom on bright surfaces?
- [ ] Graphics > Compute Effects at its lowest vs default, once with Shadows at Low and once at Good
  or higher. Forum reports disagree: one player says low Compute plus Good+ shadows "really did
  help", another saw no change, and a third says Low/Fair shadows make the fog stronger.
- [ ] `/console disableHorizonStart 1`, `/console horizonStart 3000` (or 6000), `/console horizonClip 10000`,
  `/console farclip 10000`: does the distant fog line move, and does any of it touch the haze near you?
- [ ] `/console weatherDensity 0`: removes weather, but does it thin the fog in zones with rain or dust?
- [ ] Whether `SetCVar` on these works in combat (no `ADDON_ACTION_BLOCKED`).
- [ ] Whether `C_CVar.SetTempCVar` survives `/reload` and logout (it should not).
- [ ] Performance cost of each change.

## Sources

- CVars: https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/forever/Resources/CVars.lua
- API diff: https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes
- Settings code: https://github.com/Gethe/wow-ui-source/tree/forever (Blizzard_SettingsDefinitions_Shared/Graphics.lua, CVarDocumentation.lua, WeatherScriptDocumentation.lua)
- LightData: https://wowdev.wiki/DB/LightData
- EULA: https://www.blizzard.com/en-us/legal/fba4d00f-c7e4-4883-b8b9-1b4500a402ea/blizzard-end-user-license-agreement
- Forum, fog concerns: https://us.forums.blizzard.com/en/wow/t/2352979
- Forum, "PLEASE let us disable the fog" (Oct 2): https://us.forums.blizzard.com/en/wow/t/please-let-us-disable-the-fog/2369785
- Forum, "Console volumefog 0": https://us.forums.blizzard.com/en/wow/t/console-volumefog-0/2360755
- Sept 24 change and revert reports (secondary): https://wowsod.pro/articles/wow-forever-beta-fog-volumefog
- Weather increase: https://www.warcrafttavern.com/forever/news/weather-effects-increasing-for-some-zones-in-wow-forever-beta/
- Forever Graphics Panel: https://www.curseforge.com/wow/addons/forever-graphics-panel
- Foggin Stupid: https://www.curseforge.com/wow/addons/foggin-stupid
- Forum, Compute/Shadows reports: https://us.forums.blizzard.com/en/wow/t/cant-turn-off-volumetric-fog/2363444
- Forum, haze reverts after a split second: https://us.forums.blizzard.com/en/wow/t/need-an-option-to-disable-the-volumetric-fog/2353063
- ffxGlow, horizon and farclip values (unofficial guide): https://pro-gamer.gg/world-of-warcraft-forever-graphic-settings-hidden-cvars-commands-guide/
