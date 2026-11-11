# WoW Forever: datamined and official data changes vs classic 1.12 / Classic Era

Researched 2026-11-10. Builds: Forever `wowf` 1.60.1.70888 (new today), Classic Era `wow_classic_era` 1.15.9.70576.
Note on direct pulls: "own pull" findings below come from wago.tools db2 CSV exports downloaded and diffed in this
session (scripts and CSVs in the session scratchpad, not committed). wago.tools HTML pages return HTTP 403 to
WebFetch, but `https://wago.tools/api/builds` and `https://wago.tools/db2/<Table>/csv?build=<version>` work from
PowerShell `Invoke-WebRequest` with a browser User-Agent. The baseline is Classic Era 1.15.9 (the nearest client
wago.tools serves), not 1.12 itself. Era 1.15 also carries Season of Discovery rows, so "missing from Forever" counts
include SoD content.

## 1. wago.tools: Forever builds, db2 tables, and what changed vs Classic Era

### Takeaway
wago.tools tracks Forever as product `wowf`. The list starts at 1.60.1.70245 (2026-10-13), and a new build **1.60.1.70888
landed 2026-11-10**, after the 70862 build the addon was last checked on. Forever's client tables differ a lot from
Classic Era. SkillLineAbility has 1,710 more rows, with most old Blacksmithing/Leatherworking/Tailoring recipe
thresholds moved down by about 25 points. ItemSparse changes vendor prices, item levels and quality on hundreds of
shared items. ItemDisenchantLoot adds new rare-quality brackets for items of level 5 to 20.

### Cited Findings
- `wowf` builds on wago.tools, newest first, with UTC timestamps: 1.60.1.70888 (2026-11-10 15:10), 70862 (11-07 04:43), 70840 (11-07 02:28), 70790 (11-04 18:08, launch), 70755 (11-03), 70753 (11-02), 70707 (10-30), 70685 (10-28), 70658 (10-28), 70634 (10-27), 70630 (10-27), 70532 (10-21), 70245 (10-13). No separate Forever beta product appears in the API product list (`wowt, wow, wowxptr, wow_beta, wowlivetest, wow_classic_era_ptr, wowz, wow_classic, wow_classic_ptr, wow_classic_beta, wow_classic_titan, wow_anniversary, wowf, wow_cn_beta, wow_classic_era`). — [wago.tools builds API](https://wago.tools/api/builds) (own pull 2026-11-10)
- Latest Classic Era builds for comparison: 1.15.9.70576 (2026-10-26), 1.15.9.70003 (09-29), 1.15.9.69722 (09-12). — [wago.tools builds API](https://wago.tools/api/builds)
- **SkillLineAbility** (own pull, wowf 70888 vs era 70576): 7,853 rows vs 6,143. Per profession (Forever rows / era rows / added / removed / threshold-changed): Blacksmithing 527/326/208/6/192; Leatherworking 616/322/294/0/213; Tailoring 486/296/191/1/215; Engineering 295/209/86/0/20; Enchanting 273/205/69/1/4; Alchemy 212/137/76/1/19; Cooking 141/94/48/1/17; First Aid 40/19/21/0/0; Mining 33/23/10/0/0; Herbalism 17/8/9/0/1; Fishing 14/5/9/0/0; Skinning 12/4/8/0/0. — [wago.tools SkillLineAbility CSV, wowf](https://wago.tools/db2/SkillLineAbility/csv?build=1.60.1.70888) vs [era](https://wago.tools/db2/SkillLineAbility/csv?build=1.15.9.70576)
- SkillLineAbility threshold changes are mostly a flat -25 on both `TrivialSkillLineRankLow` (yellow start) and `TrivialSkillLineRankHigh` (grey) for older crafting recipes. Examples, era -> Forever (Low/High): Blacksmithing 2664 115/140 -> 90/115; 3497 225/250 -> 200/225; 3336 180/210 -> 155/185; Leatherworking 2158 120/150 -> 95/125; 2166 145/170 -> 120/145; 2159 105/135 -> 70/100 (-35). Many trainer recipes also had `MinSkillLineRank` set to 1 (for example Leatherworking 2166 125 -> 1, Cooking 2548 135 -> 1). Alchemy 2329/2330/2337/3174/3447 changed `AcquireMethod`. — same CSVs (own pull)
- New recipe spell id blocks (Forever only, `SkillLine:Spell`): Alchemy 1244421, 1244645-1244648, 1249630-1249633, 1250775-1250797; Blacksmithing 1252229-1252262+; Leatherworking 1254965-1254987+; Tailoring 1257013, 1257017, 1257368-1257394+; Enchanting 1248458-1249071+; Engineering 1266893-1266933+; Cooking 1249957-1249968, 1250142-1250158, 1270632-1270635; First Aid 1244431-1244436, 1259341-1259349; gathering lines got 1262975-1263071 and 1306126 (Mining). Every profession also gains 1240927-1240988-range entries with thresholds 0/0, plus 1229xxx/1230xxx entries at 20/25. — same CSVs (own pull)
- Some new recipes have grey thresholds above 300: First Aid 1259345 (295/355), Leatherworking 1254967-1254970 (320/340), Engineering 1266930-1266933 (320/340), Cooking 1250143+ (280/310), Mining 1306126 (300/315). — same CSVs (own pull)
- Recipe rows dropped from Forever: Blacksmithing 16650, 16728, 16746, 16661, 23628, 23629; Alchemy 2336; Tailoring 8468; Cooking 30047; Enchanting 1219586. — same CSVs (own pull)
- **ItemSparse** (own pull): Forever has 19,325 rows vs era 24,442; 14,251 ids in both; 5,074 ids only in Forever; 10,191 era ids absent from Forever's client table (that count includes era-only SoD items). Among the 14,251 shared ids: SellPrice changed on 148, BuyPrice 219, ItemLevel 265, OverallQualityID 169, RequiredLevel 209, RequiredSkillRank 375. — [wago.tools ItemSparse CSV, wowf](https://wago.tools/db2/ItemSparse/csv?build=1.60.1.70888) vs [era](https://wago.tools/db2/ItemSparse/csv?build=1.15.9.70576)
- ItemSparse examples, era -> Forever. Crafted gear went white to green and got cheaper: Fine Leather Boots 2307 quality 1 -> 2, sell 243 -> 195 copper; Bronze Axe 2849 sell 1269 -> 917; Rough Bronze Bracers 2867 sell 629 -> 317. Mounts: Horn of the Black Wolf 1041, Horn of the Timber Wolf 1132, Black Stallion Bridle 2411, Pinto Bridle 2414 buy 800000 -> 200000 (80g -> 20g), and 1041 quality 1 -> 3. Food was re-leveled: Slitherskin Mackerel 787 ilvl 5 -> 10, Murloc Fin Soup 3663 required level 15 -> 1. Recipe items need less skill: Pattern: Fine Leather Boots 2406 90 -> 65, Plans: Mighty Iron Hammer 3608 145 -> 120, Pattern: Red Linen Robe 2598 40 -> 25. Mining Pick 2901 sell 16 -> 2. — same CSVs (own pull)
- **ItemDisenchantLoot** (own pull; columns ID, Subclass, Quality, MinLevel, MaxLevel, SkillRequired, ExpansionID, Class): Forever 54 rows vs era 50. Rows 9 and 10 (Quality 3 = rare, armor Class 4 and weapon Class 2) start at item level 21 instead of 20. Four new rows cover rare items of item level 5-15 and 16-20: id 335 (armor 5-15), 336 (armor 16-20), 337 (weapon 16-20), 338 (weapon 5-15). The client table holds brackets only. What the disenchant yields is server-side. — [wago.tools ItemDisenchantLoot CSV, wowf](https://wago.tools/db2/ItemDisenchantLoot/csv?build=1.60.1.70888) vs [era](https://wago.tools/db2/ItemDisenchantLoot/csv?build=1.15.9.70576)
- **Sayge copies identified** (own pull of SpellName): the 1304767-1304782 block is named "Sayge's **Dark** Fortune of ...": 1304767 Resistance, 1304769 Damage, 1304771 Armor, 1304772 Intelligence, 1304775 Spirit, 1304778 Stamina, 1304780 Agility, 1304782 Strength. Neighbours are 1304765 "(DNT) Darkness Effect" and 1304773 "Transform". — [wago.tools SpellName CSV, wowf](https://wago.tools/db2/SpellName/csv?build=1.60.1.70888)

### Inferences
- Skill-Up Odds should keep reading Forever's own SkillLineAbility, as it already does. Classic Era or 1.12 recipe thresholds would be about 25 points too high for most old Blacksmithing, Leatherworking and Tailoring recipes.
- The new rare disenchant brackets match the BlizzCon claim that dungeon boss items become rare quality (Section 3). Disenchant Value's cmangos 1.12 tables likely have no matching result for blue items of item level 5 to 20, or a different one. The client cannot show the yields.
- "Dark Fortune" plus a "(DNT) Darkness Effect" suggests a darker Sayge variant, perhaps a second fortune set or an event version. That is a guess from names. No source explains it.
- 70888 is a new client. The repo's API allowlist was built at 70862, so it may need a regenerate-and-diff.

### Gaps
- I did not check whether wago.tools CSV exports include Blizzard's server hotfixes (DBCache) or only the shipped client rows. If they do not, live hotfixes such as the Nov 6 Tanning Rack change may be missing.
- No pre-70245 beta builds (Sept beta, including 70450) appear under `wowf`, and I could not find where wago.tools lists them.
- I did not check wago.tools' terms of use or rate limits.
- I did not diff ItemSparse, SkillLineAbility or SpellName across Forever builds (70790 -> 70862 -> 70888), only Forever vs Era.
- Not pulled: Spell/SpellEffect for the Dark Fortune spells, so their effects and auras are unknown.

## 2. Third-party databases: forever.warcraftdb.com, Wowhead, ForeverChanges and others

### Takeaway
No public database offers datamined Forever loot tables or drop rates from client data, because Forever's loot is server-side and much item data is hidden. ForeverChanges (foreverchanges.pro) is the most transparent aggregator: wago.tools client reads, a Raidbots cache for hidden items, player sightings for drops. forever.warcraftdb.com is a Wowhead-style DB with no documented API or terms. Wowhead covers Forever with news under /forever/.

### Cited Findings
- forever.warcraftdb.com has list pages for classes, factions, instances, items, item sets, mounts, NPCs, objects, professions, quests, races, spells and titles (`/list/items`, `/list/npcs`, `/list/quests`, `/list/professions`, ...), plus a `/tools` hub. The hub has a Dressing Room, Talent Calculator, Legacy Talents, Icons, Calendar, Data Table (`/tool/data-table`) and Tooltip (`/tool/tooltip`). — [forever.warcraftdb.com](https://forever.warcraftdb.com/) (own pull); [warcraftdb tools](https://forever.warcraftdb.com/tools)
- warcraftdb lists no exports, API endpoints, tooltip script URL, data-source statement or build number. The footer reads "© 2026 Lexicon Gaming, LLC All Rights Reserved" and links to a privacy policy, with no terms of use. A probe of `/api/v1/tooltip/item/2589` gave no usable result (output garbled; treat as unconfirmed). — [warcraftdb tools](https://forever.warcraftdb.com/tools); [privacy](https://warcraftdb.com/privacy)
- ForeverChanges says it reads the Forever client (1.60.1.70888) through wago.tools for talents, spellbooks, items, recipes, Legacy, racials and the world map. It reads server hotfixes from player game caches collected by Raidbots, and compares against Classic Era 1.15.9.69722 (not 1.12). — [ForeverChanges: About the data](https://foreverchanges.pro/about) (updated 2026-11-10)
- ForeverChanges drop rates: "from AtlasLootClassic for Classic and from player sightings for Forever". Entries marked "Reported"/"Unverified" come from videos or reports, not the client. Tooltip numbers are base values. No reuse terms are stated on the About page. The operator is unnamed (contact hello@foreverchanges.pro). — [ForeverChanges: About](https://foreverchanges.pro/about)
- ForeverChanges hidden-item tracker (by "Vektor", updated 2026-11-10): 6,225 of 12,683 hidden items revealed. Of these, 1,258 of 2,499 are new Forever items, 4,041 of 5,005 are Classic items (**1,417 with changed stats, effects or damage**), and 926 of 5,179 are SoD leftovers. There are 19 encrypted groups (two raids, five new dungeons, quest series, pets, mounts, cosmetics) whose keys are not on the public TACT key list. Querying the server directly for hidden items worked for only about a third of them (test on Sept 25). — [ForeverChanges: hidden items](https://foreverchanges.pro/hidden-items)
- ForeverChanges' changes page (Forever 70888 vs Era 1.15.9.69722) counts 118 new talents, 303 changed, 83 removed, and 264 changed spells. Its detail is mainly talents and spells, with nothing on loot or professions. — [ForeverChanges: changes](https://foreverchanges.pro/changes)
- ForeverChanges also tracks undocumented hotfixes. On 2026-11-10 at 16:51 and 19:12 UTC it saw unannounced class tuning (Arcane Shot, Summon Hawk, Wrack, Imp Firebolt) and an item change: Rage of the Storm went from +12 Int to +16 Str and from 3.20 to 3.60 speed. — [ForeverChanges home](https://foreverchanges.pro/)
- Wowhead runs Forever news under `wowhead.com/forever/news/`, for example raid tier set models datamined for all nine classes. — [Wowhead: Raid Tier Set Models Datamined](https://www.wowhead.com/forever/news/raid-tier-set-models-datamined-for-wow-forever-382938) (date not captured)
- Search turned up other Forever guide sites (Mobalytics, RankedBoost, Zockify, SeeMeta, MetaForge "recent changes", Warcraft Tavern) and three sites of unknown provenance (wowforever.news, ai-exodus.com companion pages). None were opened. — [Mobalytics profession changes](https://mobalytics.gg/wow-forever/guides/wow-forever-all-new-profession-changes); [MetaForge recent changes](https://metaforge.app/wow-forever/recent-changes); [wowforever.news datamining](https://wowforever.news/topics/datamining.html); [ai-exodus hidden loot](https://ai-exodus.com/companion/wowforever/news/hidden-loot-datamining/)

### Inferences
- For Forever drop rates, the only sources are crowdsourced sightings (ForeverChanges, its addon, Wowhead-style comment data). Client datamining cannot supply them.
- ForeverChanges' "1,417 classic items changed" is the strongest public evidence that classic item stats are not 1.12 stats. Its counts are a fan aggregation, so treat the exact numbers as moderate-confidence.

### Gaps
- I did not confirm whether Wowhead has a Forever item/NPC database with loot tabs and drop percentages (a probe of `wowhead.com/forever/item=2589` returned no usable title).
- warcraftdb's tooltip API and data-table export are unconfirmed.
- I found no license or terms for reusing ForeverChanges or warcraftdb data.

## 3. Blizzard official sources: patch notes, hotfixes, development notes

### Takeaway
Blizzard's Beta Development Notes thread (Kaivax, Sept 24 to Nov 4) and the launch-week hotfix posts (Nov 5, 6, 9) confirm Forever-specific content that cmangos 1.12 lacks. That covers new zones and dungeons, loot fixes for new bosses, profession changes (Tanning Rack, dungeon-dropped recipes, lower vendor prices for crafted items), XP changes, and raid-entry buff removal. Blizzard also says it is deliberately hiding item stats from dataminers, and there are no raid PTRs.

### Cited Findings
- Interview (MMORPG.com, reported by Method on 2026-09-17), Josh Greenfield: "you will not see an item's stats until it drops for you, until it drops for someone on your server". Blizzard plans no PTRs for new raid content, and there will be no dungeon journal at launch. — [Method.gg: No PTRs and new datamining restrictions](https://www.method.gg/wow-forever/no-ptrs-and-new-datamining-restrictions-coming-to-world-of-warcraft-forever)
- Development notes, **2026-09-24**: Wizard Oil spell power reverted to Classic values, except Brilliant Wizard Oil. Wands no longer gain from spell damage. Some quest rewards had their item level corrected. Campfire buff fixes. A "Catching Wind" redesign on Zephras Isle. — [Blizzard forums: WoW Forever Beta Development Notes](https://us.forums.blizzard.com/en/wow/t/2360696) (Kaivax)
- Development notes, **2026-10-01**: level cap 30. New dungeon Excavation Site: Wetlands (26-31). Razorfen Downs and Uldaman open. Dungeon quest bonus XP cut 50%. "Some Blacksmithing and Leatherworking recipes now drop from dungeons". Poor Copper Vein nodes reduced in starter areas. Creatures can be skinned only once. Common and uncommon wands sell for 1 copper. — [Blizzard forums: Dev Notes](https://us.forums.blizzard.com/en/wow/t/2360696)
- Development notes, **2026-10-08**: Classic looting restored. Twisted totem drop rate up. Eye of the Tempest made multi-drop. City of Dalaran dungeon in testing. Dungeon creature XP up about 20%. Some dungeon quest rewards lowered from Rare to Uncommon. Peace Tea recipe sells for 10 copper. Vendor prices of enchanting-made wands and oils adjusted. — [Blizzard forums: Dev Notes](https://us.forums.blizzard.com/en/wow/t/2360696)
- Development notes, **2026-10-16**: "Many profession-created items had their vendor prices reduced". Scrolls now share a global cooldown. Horde are attacked on sight in Dalaran. — [Blizzard forums: Dev Notes](https://us.forums.blizzard.com/en/wow/t/2360696)
- Development notes, **2026-10-26/27**: Attuned and Charged buffs are removed on entering a raid. **2026-11-03**: class damage and creature health both raised; respawn rates changed for launch load; class training costs about 206-207g for 1-60; race base stats corrected; raids open "next month". — [Blizzard forums: Dev Notes (later posts)](https://us.forums.blizzard.com/en/wow/t/2360696)
- Hotfixes **2026-11-05**: Zephras Isle trade supply vendors sell apprentice tradeskill bags. "Mild Spices now sell to vendors for 1 copper each (was 2 copper)". — [Blizzard: WoW Forever Hotfixes](https://worldofwarcraft.blizzard.com/en-us/news/24315281)
- Hotfixes **2026-11-06**: "Tanning Rack skill requirement lowered to 125 (was 140)", and Tanning Rack skill-ups reduced by 15 points (Leatherworking). Loot corrected for Ridgeshade Lurkers (Durotar) and Krek the Noxious (Riverglades). Searing Dagger proc fix. Damp Note drop rate increased. Zaetar's Spirit can spawn in Maraudon. — [Blizzard: WoW Forever Hotfixes](https://worldofwarcraft.blizzard.com/en-us/news/24315281)
- Hotfixes **2026-11-09**: "Experience rewarded for all enemy kills in dungeons increased by 50%". Bosses that dropped no loot now do: Zarla Ober (Alcaz Prison) and Vitrix, Snowtalon and Cinder (The Shaper's Terrace), the last three with higher-level skinning materials. Heart of the Mountain (BRD) can be looted more than once. Waylaid Crates and Craftsman's Writs can drop inside dungeons. Berdun's Trusty Rifle loses random stats and is no longer BoE. Deathless Marrow (The Drowned City) tuned down. Young Diemetradons spawn at 51-52, not 58. — [Blizzard: WoW Forever Hotfixes - November 9, 2026](https://worldofwarcraft.blizzard.com/en-us/news/24315281); [forum mirror](https://us.forums.blizzard.com/en/wow/t/wow-forever-hotfixes-november-9-2026/2403040/5)
- Blue post (Kaivax, 2026-11-10, as reported by ForeverChanges): XP-to-gold conversion for quests completed at max level is disabled. — [ForeverChanges home](https://foreverchanges.pro/) (secondary; original post not opened)
- The Nov 5/6 general "Hotfixes" posts on the main WoW site cover Midnight and the other Classic versions, not Forever. Forever has its own "WoW: Forever Hotfixes" post. — [Blizzard: Hotfixes November 6, 2026](https://worldofwarcraft.blizzard.com/en-us/news/24307310)

### Inferences
- "Attuned and Charged buffs removed on entering a raid" and Sayge's new aura text "No effect while in a raid instance" point the same way: Forever disables world and fortune buffs in raids.
- Mild Spices: the hotfix says 1 copper (was 2), while my ItemSparse pull shows era 0 -> Forever 1. Either the baseline differs or the export does not apply hotfixes. In both cases, 1.12 vendor prices are not reliable for Forever.

### Gaps
- The launch patch notes and the Nov 4 "pre-launch class changes" post were not opened (only seen via [Warcraft Tavern](https://www.warcrafttavern.com/forever/news/wow-forever-pre-launch-class-changes-bug-fixes/) and [GamesRadar](https://www.gamesradar.com/games/world-of-warcraft/world-of-warcraft-forever-patch-notes-leave-fans-asking-blizzard-why-and-hoping-for-more-class-adjustments/)).
- I found no official statement on raid size or lockouts, disenchanting, Darkmoon Faire scheduling, or the current live level cap. The Nov 3 notes mention "players past level 30" and raids next month, but give no number.

## 4. Datamining write-ups and news coverage

### Takeaway
Press and community datamining coverage centres on itemization (tier sets, set bonuses, crafted tier sets), talents and professions. The common message is that Forever reworks classic itemization and adds hundreds of recipes. The exact counts disagree between sources.

### Cited Findings
- Icy Veins: "WoW Forever Crafted Tier Sets Datamined: Recipes, Costs, and Set Bonuses", and separately "WoW Forever Is Completely Reworking Classic Itemization" (pages returned 403; titles only). — [Icy Veins crafted tier sets](https://www.icy-veins.com/wow-forever/news/wow-forever-crafted-tier-sets-datamined-recipes-costs-and-set-bonuses/); [Icy Veins itemization rework](https://www.icy-veins.com/wow-forever/news/wow-forever-is-completely-reworking-classic-itemization/)
- PC Gamer: dataminers found set bonuses, including on low-level gear. — [PC Gamer](https://www.pcgamer.com/games/world-of-warcraft/wow-forever-dataminers-have-dug-up-set-bonuses-which-are-interesting-even-on-low-level-gear/) (not opened)
- BlizzCon 2026 deep dive coverage: dungeon loot fully reworked, unique dungeon boss items raised to rare quality, hundreds of new items, set bonuses improved, BoP dungeon appearances shared with the party. Over 600 new recipes. Campfires replace cooking fires and carry vendors, repairs, professions and buffs. Mount cost moves into training cost (TBC model). Ruleset replaces realm choice. — [Massively OP: BlizzCon deep dive](https://massivelyop.com/2026/09/13/blizzcon-2026-world-of-warcraft-forevers-deep-dive-panel-talks-group-play-progression-and-item-updates/); [kami-labs deep dive summary](https://kami-labs.fr/en/wow-forever/wow-forever-deep-dive-resume/) (via search summary, not opened)
- Recipe counts disagree: one analysis says 884 new recipes vs the original client, another says 861 in the beta (Leatherworking 239), and Blizzard says "over 600". Professions keep 12 skills, four ranks, cap 300. — search summary of [Mobalytics](https://mobalytics.gg/wow-forever/guides/wow-forever-all-new-profession-changes), [RankedBoost](https://rankedboost.com/world-of-warcraft/forever/professions/), [SeeMeta](https://seemeta.com/en/wow-forever/professions) (not opened; attribution of each number uncertain)
- Blizzard forum threads discuss datamined talent changes (paladin, druid, hunter) and explain what datamined data means. — [EU forums: Recent data mined changes](https://eu.forums.blizzard.com/en/wow/t/recent-data-mined-changes-and-my-thoughts/638795); [US forums: Does no one understand Datamining?](https://us.forums.blizzard.com/en/wow/t/does-no-one-understand-datamining/2397218)
- Warcraft Tavern: City of Dalaran dungeon and Legacy Points live in beta; Nov 4 pre-launch class changes. — [Warcraft Tavern](https://www.warcrafttavern.com/forever/news/city-of-dalaran-dungeon-legacy-points-now-live-in-the-wow-forever-beta/)

### Inferences
- My SkillLineAbility diff adds 1,029 rows across the 12 profession lines, which includes rank and placeholder spells. That fits "600 to 900 new recipes" once non-recipe rows are excluded.
- Some recipe thresholds run past 300 (Section 1). Either the cap is above 300, or those recipes simply stay orange or yellow to the cap. The "cap 300" claim is secondary and unverified.

### Gaps
- I found no Reddit or YouTube datamining summary specific to loot tables or disenchanting.
- I did not open the Wowhead datamining articles. Their dates and builds were not recorded.

## 5. Evidence against using cmangos 1.12 data for Forever

### Takeaway
The evidence is strong and comes from several directions. Forever changes classic item stats, quality, item levels and vendor prices. It adds about 2,500 new items and new dungeons and zones that cmangos lacks. It reworks dungeon loot, moves recipes to dungeon drops, adds disenchant brackets, and rebalances recipe thresholds. cmangos 1.12 can serve as a fallback for unchanged open-world mobs. It is wrong for new content, reworked dungeon loot, low-level blue disenchants, crafted-item prices, and recipe skill levels.

### Cited Findings
- 1,417 of 4,041 revealed classic items have changed stats, effects or damage, and 2,499 items are new to Forever. — [ForeverChanges hidden items](https://foreverchanges.pro/hidden-items)
- Shared ItemSparse rows: 148 sell price, 265 item level and 169 quality changes. Crafted green and blue gear is generally cheaper to vendor. Mount items are 80g -> 20g. — own pull, [wago.tools ItemSparse wowf](https://wago.tools/db2/ItemSparse/csv?build=1.60.1.70888)
- Blizzard repriced vendor values several times: profession-created items down (Oct 16), wands to 1 copper (Oct 1), Mild Spices 1 copper (Nov 5). — [Dev Notes](https://us.forums.blizzard.com/en/wow/t/2360696); [Hotfixes](https://worldofwarcraft.blizzard.com/en-us/news/24315281)
- Dungeon loot reworked and boss uniques raised to rare quality; some Blacksmithing and Leatherworking recipes moved to dungeon drops; Waylaid Crates and Craftsman's Writs drop in dungeons. — [Massively OP](https://massivelyop.com/2026/09/13/blizzcon-2026-world-of-warcraft-forevers-deep-dive-panel-talks-group-play-progression-and-item-updates/); [Dev Notes](https://us.forums.blizzard.com/en/wow/t/2360696); [Hotfixes Nov 9](https://worldofwarcraft.blizzard.com/en-us/news/24315281)
- New disenchant brackets for rare items of item level 5-20, and the rare 20-25 bracket starts at 21. — own pull, [ItemDisenchantLoot wowf](https://wago.tools/db2/ItemDisenchantLoot/csv?build=1.60.1.70888)
- Recipe yellow and grey thresholds are about 25 lower on most old Blacksmithing, Leatherworking and Tailoring recipes. Recipe item `RequiredSkillRank` is lower by 15-25 (for example 2406 90 -> 65). There is a new Tanning Rack station (skill 125 after the Nov 6 hotfix). — own pull; [Hotfixes Nov 6](https://worldofwarcraft.blizzard.com/en-us/news/24315281)
- Content absent from 1.12 includes Zephras Isle, Riverglades, Alcaz Prison, The Shaper's Terrace, The Drowned City, City of Dalaran, Excavation Site: Wetlands and Ruins of Lordaeron, plus mobs with corrected Forever loot (Ridgeshade Lurkers, Krek the Noxious). — [Hotfixes](https://worldofwarcraft.blizzard.com/en-us/news/24315281); [Dev Notes](https://us.forums.blizzard.com/en/wow/t/2360696)
- Item stats are hidden until they drop on a server, so client data cannot fully reveal them. — [Method.gg](https://www.method.gg/wow-forever/no-ptrs-and-new-datamining-restrictions-coming-to-world-of-warcraft-forever)

### Inferences
- Kill Value: cmangos drop lists will miss Forever's new mobs and items, and may list classic items whose stats, quality and vendor price have changed. Valuing from live `GetItemInfo` sell prices, not stored 1.12 prices, avoids the price drift.
- Disenchant Value: the four new rare brackets are where cmangos 1.12 results are most likely wrong. The rest of the brackets are unchanged in the client table, but yields are server-side, so "unchanged bracket" does not prove "unchanged yield".
- Skill-Up Odds: already on Forever SkillLineAbility, which is the right source. Recheck it each build (70888 is new), since Blizzard tunes professions by hotfix (Tanning Rack).

### Gaps
- No source compares actual Forever disenchant yields or open-world mob drop tables against 1.12. Those are server-side, and only crowdsourced loot logs could show them.
- I did not check whether open-world drop rates for unchanged classic mobs differ from cmangos.
