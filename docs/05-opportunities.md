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

## Suggested first project

Start small to learn the platform: a classic-mechanics panel (ammo + pet happiness + weapon skill
progress), all out-of-combat-safe, using only Forever-native APIs. It exercises events, SavedVariables,
Settings, Edit Mode-friendly frames and the packager, with no secret-value risk. Then grow into
#2 or #1.
