# Opportunities

Where a new addon author can actually win at launch. This is opinion built on the research in
[02-addon-platform.md](02-addon-platform.md), not established fact.

## Constraints that shape the field

- Combat logic is closed (secret values, combat log lockdown). Do not plan a rotation helper, a
  threat meter that branches on threat values, or a combat-log-parsing meter.
- Big incumbents already ported: Questie, Details, DBM, BigWigs, ElvUI. Competing head-on is low value.
- Everything is fresh: new zones, dungeons, quests, a race, legacy points and campfires have no
  existing addon data.

## Gaps worth looking at

1. **WeakAuras replacement / lightweight aura and alert tool.** WeakAuras does not support
   Forever. Within secret-value rules you can still show Blizzard-provided data (pass secrets to
   widgets) and do out-of-combat logic. Big demand, but big scope. A narrow version (buff/consumable
   reminders, cooldown icons) is achievable.
2. **"Classic look" UI skins.** Blizzard reportedly left classic UI options to addons. The modern
   client with classic-styled unit frames, action bars, bags and minimap is pure cosmetics, fully allowed,
   and has a big nostalgia audience. Note the Beta 5 reskins: anchor to live frames carefully.
3. **Hardcore toolkit** for when Hardcore realms launch (Winter 2026/27): death log, self-found
   tracking, danger warnings, using `C_GameRules`. Classic Era Hardcore addons were very popular.
4. **Classic-mechanic helpers** the modern client lacks: hunter pet happiness/food tracker
   (`UNIT_HAPPINESS`, though `GetPetFoodTypes` was removed), ammo counter (`UnitUsesAmmo`), swing
   timer (`PLAYER_SWING` exists; check whether it is secret in combat), weapon skill tracker
   (`C_SkillInfo`).
5. **Forever-content guides:** new dungeon notes, Barrow Deeps/Hyjal info panels, a campfire recipe
   helper, a legacy points tracker, transmog/collection helpers for the account-wide collections.
6. **Profession and economy tools** if Auctionator/TSM lag behind.

## Launch landscape (CurseForge Forever filter, 2026-11-05)

8,511 projects list a 1.60.1 file. Sorted by popularity (lifetime downloads, all flavors) the top
is retail ports: DBM, Details, Questie, Auctionator, RareScanner, Leatrix Plus/Maps, TomTom, Plater,
Bagnon, BigWigs, Baganator, Pawn, GTFO, ATT, Scrap. TradeSkillMaster is listed too (pre-launch
guides said it had no Forever build). Built for Forever and doing well: OpenMap (492K),
DungeonJournal, GearQuest Forever, AtlasLoot Classic Forever, Keep or Toss: Forever (42K), Forever
Loot Sparkles, Node Sight, Lueur, Musca Auras and ForeverAuras (WeakAuras forks), NeedRoll, Happy
Camper (campfires), Books on Map Forever, Talents Forever, Forever Threat.

Against our features:

- **Rare Alert:** RareScanner (5th overall) and SilverDragon. Ours stays the light option.
- **Quest Trash:** Keep or Toss: Forever covers every item, not just quest items, and flags items
  new to Forever. Look at it before growing Quest Trash.
- **Kill Value:** no Forever equivalent found. The nearest, Should I Grind This? (session gold per
  hour), is TBC-only with 28 downloads.
- **Setups:** Myslot (bars, macros, bindings as an export string). Setups covers more.
- **Camp Guide (0.10.0):** Campfire Tooltips: Forever (130 downloads, Oct 4) adds the same
  per-object buff text; Happy Camper and SMore Skills share campfire locations; HastesSuperTweaks
  and NaowhForever time the camp auras. Ours adds the clash with your own class buffs and the
  campfire's list of what you hovered.

## How the leaders work (source read 2026-11-12)

Asked after the r/wowforever "addons you're most pleased with" megathread. We read source copies
and ran nothing from them.

- **Questie / QuestieDB.** Phantom "!" quest givers come from the data, not the logic. Every check
  in `QuestieDB.IsDoable` fails open: a missing prerequisite or a race mask of 0 passes. Forever data
  is a Wowhead scrape laid over Era data. Fixes ship fast: 8 Questie and 6 QuestieDB releases
  Nov 4-11. QuestieDB 1.0.14-1.0.15 held back 212 quests nobody can obtain.
  - Questie already compares an NPC's offered quests with its own list on gossip, but hides only
    dailies. It has no public API for hiding a quest.
  - Anything we build on QuestieDB inherits the same holes, so show "unknown" rather than guess.
  - To report a phantom, use Questie's "Quest issue" template. `/questie doable <id>` prints why
    Questie thinks a quest is available.
- **Attune** (All Rights Reserved: take ideas only, no data).
  - It hand-writes its dungeon chains and checks them against Wowhead /forever/. About 12% of its
    quest ids are new to Forever (90000+).
  - Players like its "Next" window most: one row per unfinished chain near your level.
  - A quest in the log is not done even if it is flagged complete. Quest Trash already checks
    "active" first.
  - It detects Forever by interface 16000-19999 and uses PARTY_KILL / UNIT_DIED in place of the
    combat log.
- **One For All** (GPL-3, smoergi/OneForAll_Forever) is a large bundle.
  - Its bags-full helper triggers on UI_ERROR_MESSAGE (ERR_INV_FULL, ERR_LOOT_NO_SPACE) and ranks
    items by vendor price only.
  - It shows a card beside the LootFrame: "Destroy & loot" (it deletes the item, even in combat)
    and "Not worth picking up" when the loot is worth less than your cheapest item.
  - It also puts a best-sell coin on quest rewards, by vendor price only.
  - Our edge: pricing at the best of vendor, AH and disenchant, and never deleting.
- **BetterFishing.** Protected actions ride the player's key press through a client binding.
  - Out of combat it points the key at `SetOverrideBindingSpell(..., "Fishing")`.
  - On CHANNEL_START it rebinds the key to INTERACTTARGET with the SoftTargetInteract CVars, then
    clears that on CHANNEL_STOP.
  - CVars are cached at load. Player edits are tracked with `hooksecurefunc(C_CVar, "SetCVar")`,
    and everything is restored on stop and logout.
  - One-button fishing is crowded (BetterFishing, Forever Fishing, EllesmereUI). Not for us.
- **What's Training?** Static per-class tables keyed by Forever spell ids (`Classes/Camelot/`).
  - Rank chains count replaced ranks as known; `IsSpellKnown` alone misses them.
  - The data was built from in-game trainers and fixed by hand after launch. It covers professions
    too.
  - Done well. Not for us.

## Suggested first project

Start small to learn the platform: a classic-mechanics panel (ammo + pet happiness + weapon skill
progress), all out-of-combat-safe, using only Forever-native APIs. It exercises events, SavedVariables,
Settings, Edit Mode-friendly frames and the packager, with no secret-value risk. Then grow into
#2 or #1.
