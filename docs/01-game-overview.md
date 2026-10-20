# World of Warcraft: Forever - game overview

Snapshot: 2026-10-20. Tags: **[P]** Blizzard primary source, **[W]** warcraft.wiki.gg,
**[S]** guide/SEO site (low confidence). Full URLs in [sources.md](sources.md).

## What it is

- Blizzard calls it "a new permanent home alongside modern and Classic WoW." [P]
- It is set in original Azeroth (after the WC3 Reforged "Forsaken Kingdom" campaign, before Molten
  Core). The level cap is 60, and one design pillar is "no level cap increases." [P][W]
- The community calls it "Classic+." The internal codename was **Camelot**, and that name still
  appears in the API and TOC system. [W]
- **Engine:** the modern retail (Mainline) client, patch **1.60.1**, which "includes all Modern
  changes up to 12.1.5." It has retail systems: Edit Mode, Cooldown Manager, Personal Resource
  Display, Gamepad UI, Settings. [P][W]
- **Platforms:** Windows and macOS. [W]
- **Access:** included with a WoW subscription or Game Time. The Skyborne race needs the Heroic or
  Epic Pack. Shop editions: Skyborne Heroic Pack, Skyborne Epic Pack (beta access and 30 days of game time),
  Warcraft Forever Collection (adds WC3 Reforged, sold until Jan 11, 2027), and a physical
  Collector's Edition. [P]

## New content vs Classic

- **New race:** Skyborne, starting on Zephras Isle. Horde Skyborne can be Shaman, Alliance Skyborne can be
  Mage. Both can be Warrior, Hunter, Rogue or Druid (new druid forms). [P]
- **Dungeons/raids:** 9 new dungeons (Hall of Thanes, Ruins of Lordaeron, Blackmaw Hold, ...),
  Barrow Deeps (a 10-player max-level challenge), Hyjal Summit (a 20-player raid). [P]
- **PvP:** Darkspear Islands, a 15v15 battleground. [P]
- **Zones:** Mount Hyjal, Riverglades, Shen'dralas, Zephras Isle, Dalaran (Alterac Mtns). [W]
- **Quests:** over 1,000 new quests. [W]
- **Systems:** Legacy progression for alts (Legacy Points pay for talent respecs), camping
  (craftable campfires), opt-in transmog, an HD/SD model toggle, official gamepad support, account-wide
  collections, first and last names, dual spec at 40 for 10g. [P][W]
- **Talents:** reworked (e.g. "31-point gold medal talents"). [P]
- **Rules:** no flying, no level scaling. [P]
- **Realms:** one mega-realm per ruleset (Normal, PvP, RP, Hardcore) per region. Layering exists,
  and GUIDs were obfuscated in Beta 5 specifically to stop addons from detecting layers. [W]
- **Hunter pets are back to classic style:** `UNIT_HAPPINESS` and `UNIT_PET_TRAINING_POINTS` events, plus ammo
  (`UnitUsesAmmo`). [W]

## Timeline

| Date (PST) | Event |
|---|---|
| Sep 17 - Oct 21, 2026 | Beta (Blizzard calls Oct 21 the last full day; the wiki says Oct 22). Level cap was 20, raised to 30. [P] |
| ~Oct 5, 2026 | Separate Forever PTR seen, build 70245. [W] |
| Oct 20 | Invite-A-Friend codes go out (valid Nov 4 - 11). [P] |
| Oct 27 - Nov 3 | Early name reservation, up to 3 characters. [P] |
| **Nov 4, 3:00 p.m. PST** | **Launch.** [P] |
| Dec 9, 2026 | New raids unlock (Barrow Deeps, Hyjal Summit, Onyxia's Lair). [P date / W list] |
| Winter 2026/27 | Hardcore realms (Blizzard says only "after launch"). [P][W] |
| Spring 2027 | 2 raids, 2 dungeons, a legendary questline. [W] |
| Summer 2027 | A "revamped iconic raid," a new raid, 2 dungeons. [W] |

## Why this matters for modding

- Content will keep growing (new raids on Dec 9, Hardcore later). Boss mods, dungeon guides and
  quest databases all need data for brand-new content, which old Classic data cannot cover.
- Hardcore realms are coming, and `C_GameRules` exposes the ruleset. Hardcore addons (death
  logs, self-found tracking) were huge in Classic Era and will need Forever-native rewrites.
- Classic-style hunter pets, ammo and training points bring back old addon niches.
