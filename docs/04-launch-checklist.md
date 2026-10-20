# Launch checklist (once the game is installed)

Things the research could not confirm. Each is 30 seconds to check in-game. Update
[02-addon-platform.md](02-addon-platform.md) with the answers.

## Install and folders

- [ ] Install Forever from Battle.net (it should appear as its own Game Version entry).
- [ ] Find the actual flavor folder under `World of Warcraft\` (`_forever_`? `_classic_`?
      `_classic_era_`?). The beta used `_classic_beta_`.
- [ ] Create `Interface\AddOns` there if missing, then run:
      `.\scripts\link-addon.ps1 -Addon HelloForever -AddOnsPath "<that folder>\Interface\AddOns"`

## Identity (run in chat)

- [ ] `/dump select(4, GetBuildInfo())`: Interface number (expect 16001).
- [ ] `/dump GetBuildInfo()`: version and build.
- [ ] `/dump WOW_PROJECT_ID, WOW_PROJECT_CAMELOT`: expect `18, 18`. Check whether a
      `WOW_PROJECT_FOREVER` constant appeared (the Camelot rename was pending).
- [ ] Check that `HelloForever` shows up and loads from `HelloForever_Forever.toc`.

## Restrictions (learn the boundaries)

- [ ] Enable `/console scriptErrors 1` and install BugSack.
- [ ] Use `/etrace` while questing, in combat and in a dungeon to learn the event flow.
- [ ] Check which values are secret: `/dump UnitPower("player", Enum.PowerType.ComboPoints)` in and
      out of combat, `issecretvalue` (or the current secret-check API, see `/api`) on threat, health, auras.
- [ ] Target an NPC and run `/dump UnitGUID("target")`. Check that the NPC ID field (6th part) is readable
      and matches the NPC on Wowhead. OctoKillValue-style ports depend on it.
- [ ] Check whether a Darkmoon Faire exists (calendar) and what the world map shows for boats/zeppelins/portals.
- [ ] Test whether `ExportInterfaceFiles code` works (launch with `-console`).
- [ ] Look at whether Lua has `import` (the wiki says `require` was renamed).

## Tooling

- [ ] Install BugGrabber, BugSack, DevTool, TextureAtlasViewer, and check each has a Forever build.
- [ ] Browse CurseForge's Forever filter (`gameVersionTypeId=88568`) to see what exists at launch.
- [ ] Re-check WeakAuras / Auctionator Forever status.

## Our addons

- [ ] ForeverQuestTrash: install QuestieDB, link the addon, run `/fqt status` (expect "index: ready"),
      hover a quest item from a finished quest, then run `/fqt` with the bank open.
- [ ] ForeverKillValue: hover a hostile mob in the open world (a value line should show), hover one in a
      dungeon (nothing should show), loot a few corpses, then check `/fkv status` and `/fkv` for "blended".
- [ ] ForeverKillValue: check that a skinned-before-looted corpse and a pickpocket are not recorded as loot.

## Before publishing anything

- [ ] Create CurseForge and Wago projects and put their IDs in the TOC (`X-Curse-Project-ID`, `X-Wago-ID`).
- [ ] Add API tokens as GitHub repo secrets. Pin a packager version that knows `forever`.
- [ ] Confirm the first upload is tagged with the Forever game version.
