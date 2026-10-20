# OctoWoW mods: will they work in Forever?

Reviewed 2026-10-20 against the Forever facts in [02-addon-platform.md](02-addon-platform.md).

## Bottom line

**None of them run as-is.** All six target the 1.12.1 client (`## Interface: 11200`, Lua 5.0) and most
lean on Turtle/OctoWoW server APIs or 1.12 community addons (pfQuest, aux, nampower). Forever is the
modern Mainline client (Interface 16001, Lua 5.1, retail API, secret values). Porting means a rewrite of
the client-facing code in every case. What carries over is the **idea, the domain logic, and the test
discipline**, not the code.

Code-level gaps that hit every repo:

- Lua 5.0 idioms: implicit `this` / `arg1` handler globals, `table.getn`, `string.gfind`. All gone or
  deprecated in 5.1.
- 1.12 widget/tooltip hooks (overriding `GameTooltip.SetBagItem` and friends). Modern code uses
  `TooltipDataProcessor.AddTooltipPostCall`.
- The api-allowlist lint (`api-allowlist.json`, built from the 1.12 WoW.exe) is the wrong allowlist for
  Forever. The *tool* is worth keeping: rebuild the allowlist from the `forever` branch of wow-ui-source
  or Ketho's BlizzardInterfaceResources.

## Per addon

| Addon | Verdict | Why |
|---|---|---|
| **OctoQuestTrash** | **Port: best candidate** | The idea transfers fully, and Forever makes it *easier*. |
| **OctoKillValue** | Port: possible, data-blocked | Mechanics work. The hard part is that no Forever loot database exists. |
| **OctoTravel** | Port: low value at launch | Rewrite on the modern map, with all-new data. Blizzard covers part of it natively. |
| **OctoFaire** | Wait and see | Depends on whether Forever has a Darkmoon Faire, and Blizzard's calendar already shows holidays. |
| **0LoadProfiler** | Retire | Blizzard ships a real addon profiler (`C_AddOnProfiler`) in Forever. |
| **octowow-client-mods** | **Do not port** | MPQ patching and DLLs are client modification: against the ToS on official servers, and a ban risk. |

### OctoQuestTrash: port it

- **What it needs:** item-to-quest links, the player's completed-quest list, and repeatable/seasonal flags.
- **Forever gives you more:** `C_QuestLog.IsQuestFlaggedCompleted(questID)` is native and authoritative.
  No pfQuest history, no `/db query` backfill, no polluted-history caveat. That removes the addon's biggest
  "honest limit."
- **What to replace:** `pfDB` (the item-to-quest index). Options: read Questie's database at runtime
  (Questie ships on Forever as `Questie_Camelot.toc`), or generate your own table from DB2 data
  (wago.tools) the way `tools/gen-data.js` already does for Turtle. Forever has 1,000+ new quests, so
  the data must be Forever data, not cmangos/Turtle.
- **Tooltip:** move from the 1.12 overrides to `TooltipDataProcessor` for item tooltips.
- **Bagshui hook:** Bagshui is a 1.12 addon. On Forever, target the bag addons that actually ship there,
  or the native bag sort/filter.
- **Secrets:** item tooltips and the quest log out of combat are not restricted. Low risk.
- **Keeps:** the verdict model, the "most protective state wins" rule, the repeatable/never-delete safety
  lists (rebuild the lists for Forever), and the fengari test harness idea.

### OctoKillValue: port later, if the data shows up

- **Creature ID:** it parses `UnitExists` GUIDs (a Turtle extension). On Forever use `UnitGUID`. The
  Beta 5 obfuscation only scrambles the server and spawn parts. The wiki says the format is "otherwise
  unchanged," so the NPC ID field should still parse. **Verify in-game**, because the addon depends on it.
- **Loot data is the blocker:** `Data.lua` is the Turtle 1.18.1 database. Forever has new loot tables and
  no public server database. Client DB2s do not contain drop rates. You would need community-sourced drop
  data, which takes months to build up after launch.
- **Prices:** aux-addon does not exist on Forever. Use Auctionator's public API, TSM, or your own scan via
  `C_AuctionHouse`. The troll-price guards (lower median, 3-day rule) still apply.
- **Secrets:** the unit tooltip in combat or in instances may return secret values. Keep it out-of-combat
  or degrade gracefully.

### OctoTravel: rewrite only if a gap shows up

- The modern world map uses MapCanvas data providers and pin templates (or HereBeDragons-Pins). Nothing of
  the 1.12 `WorldMapButton` overlay carries over.
- All the data is Turtle-custom (Gilneas, Tel'Abim, rental mounts...). Forever has its own new zones
  (Hyjal, Riverglades, Shen'dralas, Zephras Isle, Dalaran). Every pin would be new.
- The modern client already shows flight masters and dungeon entrances. Check in-game what Forever's map
  shows for boats, zeppelins and portals before deciding there is a gap.

### OctoFaire: check in-game first

- Unknown whether Forever has a Darkmoon Faire, or on what schedule (nothing found as of 2026-10-20).
- If it does, `C_Calendar` exposes holiday events directly, so the "read the calendar replies" trick
  becomes a few documented API calls. Blizzard's minimap calendar already flags active holidays,
  though, so the addon's value shrinks to the site/next-move tooltip.

### 0LoadProfiler: retire

- Forever ships `C_AddOnProfiler` (confirmed in the `forever` branch: `GetAddOnMetric`,
  `GetTopKAddOnsForMetric`, `GetOverallMetric`...), plus `C_AddOns` memory APIs. Retail's AddOn list
  already shows per-addon CPU. The 1.12 workaround of measuring gaps between `ADDON_LOADED` events is
  obsolete.
- If you want something here, a small "addon cost dashboard" over `C_AddOnProfiler` is a quick first
  addon, but it is a new addon, not a port.

### octowow-client-mods: do not port

- `patch-9.mpq` replaces client files, nampower is an injected DLL, and the realm probe logs in a
  throwaway account. On an official Blizzard server, all of that is client modification and
  against the Terms of Use, with ban risk (Warden).
- OctoChallenges reads Turtle's server-specific `TW_UI` channel. The Forever equivalent is `C_GameRules`
  (Hardcore/RP/PvP ruleset). That makes a **Hardcore status/challenge panel** a natural new addon when
  Hardcore realms launch, but as a normal addon only.

## Suggested order

1. **OctoQuestTrash for Forever** (new repo, e.g. `ForeverQuestTrash`): the strongest idea, with native
   quest completion. Blocked only on a Forever item-to-quest source, so check Questie's DB format first.
2. **An addon-cost dashboard** over `C_AddOnProfiler`: small, a good first Forever build to learn the
   toolchain.
3. Revisit OctoKillValue once community drop data exists, and OctoFaire/OctoTravel after looking at the
   live game.

## Forever addons that already cover these (checked 2026-10-20, beta)

Download counts are CurseForge totals during the beta. None of these are verified in-game.

| Our mod | Existing Forever addons | Gap left for us |
|---|---|---|
| Quest Trash | [Keep or Toss: Forever](https://www.curseforge.com/wow/addons/keep-or-toss-forever) (about 2,900 downloads, QuestieDB, also covers professions, recipes, gear, bag and bank list, sell/destroy warning). [Quest Item Cleaner Forever](https://www.curseforge.com/wow/addons/quest-item-cleaner-forever) (63 downloads, Keep / Can be removed / Unknown, needs Questie). [Forever Quest Items](https://www.curseforge.com/wow/addons/forever-quest-items) (which quests need it, no verdict). | Neither page mentions repeatable or seasonal quests, breadcrumbs, or race/class "not for you". Keep or Toss is broader than ours. |
| Kill Value | [Blackthornes Farmer](https://www.curseforge.com/wow/addons/blackthornes-farmer) (about 6,900 downloads, learned values per mob, exact after 20 kills, ~estimate before, Rankings tab, AH prices via Blackthornes Tradeskills, vendor price read from the tooltip because Forever's stored sell price can be wrong). [Loot Tracker Forever](https://www.curseforge.com/wow/addons/loot-tracker-forever) (value per kill per source). [Lootify](https://www.curseforge.com/wow/addons/lootify), [MoneyLooter](https://www.curseforge.com/wow/addons/moneylooter) (session trackers with Auctionator/TSM pricing). | Ours shows a value on the mob tooltip before the first kill (baseline loot data) and prices from Auctionator. Check Blackthornes' sell-price note against our vendor prices. |
| OctoTravel | [Mapzeroth](https://www.curseforge.com/wow/addons/mapzeroth), [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever), [Travelcraft](https://www.curseforge.com/wow/addons/travelcraft), [OpenMap](https://www.curseforge.com/wow/addons/openmap), [MapUtils](https://www.curseforge.com/wow/addons/maputils), xeR's Forever Navigation. | None. Route planning with boats, zeppelins, portals and gates is already covered several times. Drop it. |
| OctoFaire | Nothing found. No source confirms a Darkmoon Faire schedule in Forever. | Still wait for the live game. |
| 0LoadProfiler | Nothing found, but `C_AddOnProfiler` and the AddOn list already show per-addon CPU. | Retire. |
| Hardcore idea (from client-mods) | [Hardcore Achievements](https://www.curseforge.com/wow/addons/hardcore-achievements) lists Forever; Legacy Forever, Forever Goal Tracker. | Crowded. Only worth it with a specific angle. |
