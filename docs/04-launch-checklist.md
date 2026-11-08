# Launch checklist (once the game is installed)

Things the research could not confirm. Each is 30 seconds to check in-game. Update
[02-addon-platform.md](02-addon-platform.md) with the answers.

## Install and folders

- [x] Install Forever from Battle.net. Download started 2026-10-20 (stress test). Battle.net product
      `wowf`, serving build 1.60.1.70245, older than beta 70450. The bundle lints clean against 70245.
- [x] Flavor folder: `C:\Program Files (x86)\World of Warcraft\_forever_` (seen 2026-10-20).
- [x] Once the download finishes, create `Interface\AddOns` there if missing, then run:
      `.\scripts\link-addon.ps1 -AddOnsPath "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns"`
      Done: `KroolWorldForever` there is a junction to the repo folder (2026-11-07).

## Identity (run in chat)

Stress test 2026-10-21 (client 70245, realm server 70399): the first three passed.

- [x] `/dump select(4, GetBuildInfo())`: 16001.
- [x] `/dump WOW_PROJECT_ID, WOW_PROJECT_CAMELOT`: 18, 18.
- [x] `_Forever.toc` is picked up: KroolWorldForever listed and enabled, zero Lua errors.
- [x] Check whether a `WOW_PROJECT_FOREVER` constant appeared: no, live 70790 still has only
      `WOW_PROJECT_CAMELOT` (wow-ui-source, 2026-11-05).

## Restrictions (learn the boundaries)

- [x] Install BugSack: BugGrabber and BugSack are in the dev install and capturing (`node tools\bugs.js`,
      34 sessions by 2026-11-07). BugGrabber catches errors without `scriptErrors`.
- [ ] Use `/etrace` while questing, in combat and in a dungeon to learn the event flow.
- [ ] Check which values are secret: `/dump UnitPower("player", Enum.PowerType.ComboPoints)` in and
      out of combat, `issecretvalue` (or the current secret-check API, see `/api`) on threat, health, auras.
- [x] Target an NPC and run `/dump UnitGUID("target")`: the NPC id (6th part) reads fine
      (`Creature-0-6834-0-2-299-...` = Diseased Young Wolf, 2026-10-21).
- [ ] Check whether a Darkmoon Faire exists (calendar) and what the world map shows for boats/zeppelins/portals.
- [ ] Test whether `ExportInterfaceFiles code` works (launch with `-console`).
- [ ] Look at whether Lua has `import` (the wiki says `require` was renamed). Blizzard code calls
      `import()` at 70790; whether addons may is unconfirmed.

## Tooling

- [ ] Install DevTool and TextureAtlasViewer and check each has a Forever build (BugGrabber and
      BugSack are in and working).
- [x] Browse CurseForge's Forever filter (`gameVersionTypeId=88568`) to see what exists at launch:
      2026-11-05, summary in [05-opportunities.md](05-opportunities.md#launch-landscape-curseforge-forever-filter-2026-11-05).
- [x] Re-check WeakAuras / Auctionator Forever status (2026-11-05): WeakAuras still none, Auctionator
      341 listed under Forever on CurseForge.

## Game files (as soon as the download finishes, before playing)

- [ ] Launch with `-console`, run `ExportInterfaceFiles code`, and diff the export against
      wow-ui-source at the matching build. It is the exact UI code of the installed build.
- [x] Rebuild the allowlist: done 2026-11-05 from wow-ui-source `forever` at 70790 (it now tracks
      the live `wowf` product), lint clean. Rebuilt again 2026-11-07 at 70862: no API change since
      70790. Diffing an `ExportInterfaceFiles` export is still open.
- [x] `.build.info` in `World of Warcraft\` lists 1.60.1.70790 (2026-11-05), 70862 (2026-11-07).

## Our addons (Krool World Forever)

- [x] Link the bundle, `/kwf list` shows both features (2026-10-21).
- [ ] `/kw killvalue off` and `/kw killvalue on` silence and restore it.
- [ ] Hub 0.7.0: `/kw` and the minimap button open it; four cards with icons (no green squares),
      status lines, the On switch, Open (Quest Trash, Setups) and the gear; nothing overlaps.
- [ ] Quest Trash window: `/fqt` lists bag items in Can Delete / Keep / Still Checking; hovering a
      row shows the item tooltip with the verdict; opening the bank adds bank items.
- [ ] Rare Alert: `/kwr test` shows the skull button; bind Key Bindings > AddOns > Krool World >
      Target And Mark Rare; on a real rare: sound, screen message, chat line, and the key targets
      it and puts a skull on it (the open question: that the secure `macrotext` click runs on
      Forever). Sewer Beast in the Stormwind canals stays quiet. BugSack empty.
- [ ] Rare Alert 0.8.0: with enemy nameplates off the hub card shows Plates On; clicking it turns
      them on and chat reports the range the client kept (asked for 80; note the real cap here).
      A rare's alert ends with "worth about ...", and the button tooltip lists its drops.
- [ ] Rare Alert 0.10.1: mark a rare with the button: the button hides once the skull is on it, and
      the key still retargets it. Kill a rare: the button fades in the fight and is gone when combat
      ends. Right-click hides it; seeing the same rare again does not bring it back or alert again.
- [ ] Disenchant Value 0.9.0: after an Auctionator scan, a BoE green's tooltip shows Disenchant with a
      value and a Best line; Shift lists the materials; `/kwd` lists material prices; the hub card
      counts priced materials. Auctionator shows no second Disenchant line. Disenchant a few greens
      (or watch a disenchanter's trade) and compare with the tables: armor mostly dust, weapons
      mostly essence, about 5% shards.
- [ ] Camp Guide 0.10.0: at a campfire (with Campfire Nearby in your buffs), hover each object: the
      tooltip shows "Camp:" and its buff at your level. Note any object that shows nothing and the
      exact name its tooltip shows (the data knows "Chair" and "Tent" besides the full names). Hover
      the fire: slot count, how sitting works, and the objects you hovered. With a class buff on
      (Blessing of Might, Fortitude...), the matching object says "Does not stack with your ...".
      After sitting a minute, hover the Camp Benefits buff: a clash line or "None of these overlap".
      Compare a value with the game's own (e.g. your Stamina before and after). `/kwc` lists all ten.
- [ ] UI polish 0.12.0, hub:
      - `/kw` fades and grows in with the open sound, and the cards arrive one after another.
      - Hovering a card shows a soft highlight. Judge whether it looks stretched on the wide
        cards (if so, use the row style).
      - The left bar is green when a feature is on, grey when off.
      - Flipping a switch plays a checkbox sound and shows a toast "<Feature> on/off" that rises
        and fades within about 2.5 s.
      - Right-clicking a card opens its settings.
      - Opening a feature from the hub plays one open sound and no close sound.
- [ ] UI polish 0.12.0, `/fqt`:
      - The window animates in.
      - Headers show a red X, check mark or magnifying glass with a divider. Rows are striped and
        the first rows fade in.
      - Refresh shows "Rechecked: ..." and fades. With nothing to sort, a faded check mark sits
        above the text.
- [ ] UI polish 0.12.0, `/kws`:
      - List rows show the pet-list hover and selected art.
      - Ticking a part plays the checkbox sound.
      - Apply shows the "Applied X" toast above the Reload Now bar (not over it), and the result
        icons pop in once. The glow behind the Reload Now icon breathes.
      - Star, rename, update and delete each show a toast.
- [ ] UI polish 0.12.0, Rare Alert (`/kwr test`, then a real rare):
      - The badge sits left of the name: a star for a rare, a silver dragon for a rare elite.
      - A gold ring breathes behind the skull, which pops in on appear and darkens while pressed.
      - The tooltip has the badge, item icons and the marker icon. The chat alert starts with the
        badge.
      - In combat nothing moves, and BugSack stays empty.
- [ ] UI polish 0.12.0, tooltips and chat:
      - Kill Value drop lines and Disenchant materials (hold Shift) show item icons, and the
        Disenchant line has its icon.
      - Chat lines start with the bag icon.
      - No green squares anywhere.
- [ ] UI polish 0.12.0, Next Skill Point panel:
      - It grows in with the crafting window, and its rows arrive one after another.
      - The top row has the selected-row highlight. After a counted craft, that recipe's cost
        flashes.
      - When a range reaches 10 crafts, "Odds ready at ..." rises in just under the panel.
      - 0.12.2: the panel is only the title bar and the rows, and as tall as the rows it lists (no
        empty space). Hovering the side tab shows how many ranges are measured.
- [ ] Skill-Up Odds 0.11.0: open a crafting profession. Each recipe with an arrow shows a % (or ?%)
      at the row's right edge, the name never overlaps it, and clicking the % still selects the
      recipe. Hover it: yellow/green/grey skills, crafts behind it, what a craft and a point cost.
      The Next Skill Point panel docks to the right of the window (no overlap, no green squares),
      ranks recipes, and a row click selects that recipe. 0.12.1: the panel sits past the
      profession tab column (0.12.0 covered it); a hammer-and-anvil tab at the bottom of that column
      hides and shows the panel, plays the tab sound, and never looks selected. Craft a few yellow or green recipes, then `/kwu status`: crafts logged go up, "skill
      read through" names an API, and the mismatch count stays 0 (if not, note your race and
      profession). `/kwu` shows the counts per range. Visit a thread vendor, then hover a recipe
      that uses thread: the thread says (vendor).
- [x] Quest Trash: `/fqt status` reports QuestieDB found and the index ready (QuestieDB 1.0.6 then;
      it is a separate install, 1.0.11 on Nov 5).
- [ ] Quest Trash: hover a quest item from a finished quest, then run `/fqt` with the bank open.
- [x] Kill Value: open-world mob tooltip shows a value line; looting records the corpse (wolf 299:
      Broken Fang, Chipped Claw, Ripped Wolf Pelt).
- [ ] Kill Value: hover a mob in a dungeon (nothing should show); after 3+ corpses of one mob,
      check `/fkv` for "blended".
- [ ] Kill Value: check that a skinned-before-looted corpse and a pickpocket are not recorded as loot.
      **Launch data said they were** (2026-11-05): leather on 22 learned creatures (e.g. npc 1128: Light
      Leather, Ruined Leather Scraps). A corpse with nothing to loot opens no loot window, so skinning
      it was its first capture. Fixed in 0.6.0; to verify: login prints "removed N skinning yields",
      `/fkv status` shows your Skinning skill (if it says none or unavailable, the skill read is
      wrong), and after skinning a beast that had no loot, `/fkv id <npc>` lists no leather.
      Saved data 2026-11-07: the cleanup ran (`gatherClean`) and none of the 140 learned creatures
      holds a leather or hide; the skill read and a fresh skin-first corpse are still to see.
- [ ] Kill Value: compare a few vendor prices with what a merchant actually pays (Blackthornes Farmer
      reports the client's stored sell price can be wrong on Forever).
- [ ] Kill Value: run an Auctionator full scan, then check AH-priced drops show "ah" as the source.
      Note whether Alliance and Horde share one auction house (Auctionator pools them).
- [ ] The minimap addon-compartment button opens the settings (the 70245 UI loads it for Forever).
- [ ] Setups 0.5.0 window: `/kws` shows the class icons, part icons, star, refresh and red X art (none
      is a green square), the from/to card reads right, and hovering a part row after an apply lists
      its details. Then make a new level 1 character with a default set: the window opens on the
      result with Reload Now, and BugSack stays empty (`node tools\bugs.js`). Half seen 2026-11-07
      (from the saved data, 70862): Krool-Mule, a new level 1 warrior, got the default (Sz-Sd)
      automatically with an undo snapshot 16 seconds after first login, and BugSack logged nothing.
      Still to see: the window opening on the result with Reload Now, and the art.

## Before publishing anything

- [ ] Create CurseForge and Wago projects and put their IDs in the TOC (`X-Curse-Project-ID`, `X-Wago-ID`).
- [ ] Add API tokens as GitHub repo secrets. Pin a packager version that knows `forever`.
- [ ] Confirm the first upload is tagged with the Forever game version.
