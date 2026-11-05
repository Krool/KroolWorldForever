# Launch checklist (once the game is installed)

Things the research could not confirm. Each is 30 seconds to check in-game. Update
[02-addon-platform.md](02-addon-platform.md) with the answers.

## Install and folders

- [x] Install Forever from Battle.net. Download started 2026-10-20 (stress test). Battle.net product
      `wowf`, serving build 1.60.1.70245, older than beta 70450. The bundle lints clean against 70245.
- [x] Flavor folder: `C:\Program Files (x86)\World of Warcraft\_forever_` (seen 2026-10-20).
- [ ] Once the download finishes, create `Interface\AddOns` there if missing, then run:
      `.\scripts\link-addon.ps1 -AddOnsPath "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns"`

## Identity (run in chat)

Stress test 2026-10-21 (client 70245, realm server 70399): the first three passed.

- [x] `/dump select(4, GetBuildInfo())`: 16001.
- [x] `/dump WOW_PROJECT_ID, WOW_PROJECT_CAMELOT`: 18, 18.
- [x] `_Forever.toc` is picked up: KroolWorldForever listed and enabled, zero Lua errors.
- [x] Check whether a `WOW_PROJECT_FOREVER` constant appeared: no, live 70790 still has only`n      `WOW_PROJECT_CAMELOT` (wow-ui-source, 2026-11-05).

## Restrictions (learn the boundaries)

- [ ] Enable `/console scriptErrors 1` and install BugSack.
- [ ] Use `/etrace` while questing, in combat and in a dungeon to learn the event flow.
- [ ] Check which values are secret: `/dump UnitPower("player", Enum.PowerType.ComboPoints)` in and
      out of combat, `issecretvalue` (or the current secret-check API, see `/api`) on threat, health, auras.
- [x] Target an NPC and run `/dump UnitGUID("target")`: the NPC id (6th part) reads fine
      (`Creature-0-6834-0-2-299-...` = Diseased Young Wolf, 2026-10-21).
- [ ] Check whether a Darkmoon Faire exists (calendar) and what the world map shows for boats/zeppelins/portals.
- [ ] Test whether `ExportInterfaceFiles code` works (launch with `-console`).
- [ ] Look at whether Lua has `import` (the wiki says `require` was renamed). Blizzard code calls`n      `import()` at 70790; whether addons may is unconfirmed.

## Tooling

- [ ] Install BugGrabber, BugSack, DevTool, TextureAtlasViewer, and check each has a Forever build.
- [ ] Browse CurseForge's Forever filter (`gameVersionTypeId=88568`) to see what exists at launch.
- [x] Re-check WeakAuras / Auctionator Forever status (2026-11-05): WeakAuras still none, Auctionator`n      341 listed under Forever on CurseForge.

## Game files (as soon as the download finishes, before playing)

- [ ] Launch with `-console`, run `ExportInterfaceFiles code`, and diff the export against
      wow-ui-source at the matching build. It is the exact UI code of the installed build.
- [x] Rebuild the allowlist: done 2026-11-05 from wow-ui-source `forever` at 70790 (it now tracks
      the live `wowf` product), lint clean. Diffing an `ExportInterfaceFiles` export is still open.
- [x] `.build.info` in `World of Warcraft\` lists 1.60.1.70790 (2026-11-05).

## Our addons (Krool World Forever)

- [x] Link the bundle, `/kwf list` shows both features (2026-10-21).
- [ ] `/kwf killvalue off` and `/kwf killvalue on` silence and restore it.
- [x] Quest Trash: `/fqt status` reports QuestieDB found and the index ready (QuestieDB 1.0.6 then;`n      it is a separate install, 1.0.11 on Nov 5).
- [ ] Quest Trash: hover a quest item from a finished quest, then run `/fqt` with the bank open.
- [x] Kill Value: open-world mob tooltip shows a value line; looting records the corpse (wolf 299:
      Broken Fang, Chipped Claw, Ripped Wolf Pelt).
- [ ] Kill Value: hover a mob in a dungeon (nothing should show); after 3+ corpses of one mob,
      check `/fkv` for "blended".
- [ ] Kill Value: check that a skinned-before-looted corpse and a pickpocket are not recorded as loot.`n      **Launch data says they are** (2026-11-05): 13 of 35 learned beasts carry leather that the baseline`n      lists only as skinning yield (e.g. npc 1128: Light Leather, Ruined Leather Scraps). A corpse with`n      nothing to loot opens no loot window, so skinning it is its first capture.
- [ ] Kill Value: compare a few vendor prices with what a merchant actually pays (Blackthornes Farmer
      reports the client's stored sell price can be wrong on Forever).
- [ ] Kill Value: run an Auctionator full scan, then check AH-priced drops show "ah" as the source.
      Note whether Alliance and Horde share one auction house (Auctionator pools them).
- [ ] The minimap addon-compartment button opens the settings (the 70245 UI loads it for Forever).
- [ ] Setups 0.5.0 window: `/kws` shows the class icons, part icons, star, refresh and red X art (none
      is a green square), the from/to card reads right, and hovering a part row after an apply lists
      its details. Then make a new level 1 character with a default set: the window opens on the
      result with Reload Now, and BugSack stays empty (`node tools\bugs.js`).

## Before publishing anything

- [ ] Create CurseForge and Wago projects and put their IDs in the TOC (`X-Curse-Project-ID`, `X-Wago-ID`).
- [ ] Add API tokens as GitHub repo secrets. Pin a packager version that knows `forever`.
- [ ] Confirm the first upload is tagged with the Forever game version.
