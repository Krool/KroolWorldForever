# Community-measured gameplay data for WoW: Forever (as of 2026-11-10)

Scope: public, community-compiled data sets about Forever gameplay (beta Sept-Oct 2026, live since
2026-11-04, build 1.60.1.70862), and which Krool World Forever feature each would feed. Research
done 2026-11-10, about 22 searches and fetches. Most sources are 1 to 6 days old and grow daily, so
every count below is a snapshot. Many "Forever guide" sites are commercial gold, boost or SEO sites;
they are flagged. Nothing here was checked in game.

## 1. Are players publishing measured drop rates or loot tables, and do any differ from 1.12?

### Takeaway
Yes. Three crowd-sourced loot collectors exist for Forever, all started at or just after launch:
foreverdroprate.com (fed by the Blackthornes Farmer addon, about 10.7k corpses on 2026-11-10),
the Forever Drops addon (shares data over addon channels, ships a community DB in each release),
and DropAtlas (personal only). None publishes a license or an export, and none publishes a
side-by-side comparison against 1.12/cmangos. Wowhead's Forever drop percentages are probably
Classic data carried over. Forum players report quest-item drops feeling too low, without Blizzard
confirming any change.

### Cited Findings
- **foreverdroprate.com** ("Real drop rates from WoW Forever", "Counted while playing, not guessed"). Operator is not named, and the site says it is not affiliated with Blizzard. Players run the **Blackthornes Farmer** addon, which records "every corpse looted and what was in it, every herb, ore and catch", then upload their counts. The site merges uploads, "never counting one twice". Helper accounts are invite-only. - [Forever Drop Rate](https://foreverdroprate.com/)
- foreverdroprate.com sample on 2026-11-10: 10,693 corpses, 1,633 items, 984 mobs, 46 of 87 zones. The largest zone is Zephras Isle (1,366 corpses, 57 mobs), and the page said it was updated "2 h ago". An earlier search snippet the same day showed 7,318 corpses, 1,212 items and 33 of 82 zones, so the data is growing fast. - [Forever Drop Rate](https://foreverdroprate.com/)
- foreverdroprate.com method: every rate shows its corpse count, rates under 20 corpses are marked "few data", and a band shows the 95% interval. Example rows: Linen Cloth from Razormane Water Seeker 48.1% (27 corpses); Small Egg from Hippogryph Protector 37.8% (37); Hunting Bow from Al'Aketh Stormchaser 1.5% (68); Satyrskin Cloak from Bazzalan 50.0% (6, "few data"). It has lookups at `/items/`, `/mobs/`, `/zones/` and `/node/`. No download, API or terms are given. NPC names and models are credited to cMaNGOS classic-db (GPL-3.0). - [Forever Drop Rate](https://foreverdroprate.com/)
- **Blackthornes Farmer** (CurseForge) describes itself as a Forever farming database and live drop tracker: search a material to see where it drops, at what level and how often. With the companion Blackthornes Tradeskills it prices drops from the player's own AH scans. Support is through Discord. - [CurseForge: Blackthornes Farmer](https://www.curseforge.com/wow/addons/blackthornes-farmer)
- **Forever Drops** (CurseForge, by Bergtrollz / "Forever Drops Team"). Main file 1.60.1 dated Nov 5, 2026, about 1,177 downloads, license "All Rights Reserved". It records mobs (name, level, zone, drops, chance, average stack), mining, herbalism, skinning, fishing, pickpocketing and chests. It notes profession skill at loot time, counts coin-only corpses, and counts a re-opened corpse once. Data spreads automatically over addon messages to guild and group users of the addon, and every release ships the community DB. Users are asked to send in `SavedVariables\ForeverDrops.lua`, but the page does not say where. It says "data that doesn't add up is thrown away" without saying how. `/drops farm <item>` ranks zones by expected items per hour. - [CurseForge: Forever Drops](https://www.curseforge.com/wow/addons/forever-drops)
- **DropAtlas** (CurseForge) is a personal tracker that counts only corpses the player opened, and shows observed drop rate per item, gold per hour per monster and where to farm. This is from a search summary of the page; it was not fetched. - [CurseForge: DropAtlas](https://www.curseforge.com/wow/addons/dropatlas)
- **ForeverDB companion addon** uploads vendor contents, quest objective locations, dungeon boss loot per kill, boss abilities, kill durations and AH prices (no seller names), through a Windows uploader, a web send page or a share code. It is on CurseForge ("foreverdb-companion") and Wago (kGr9ReKy). No license is given for ForeverDB's own data. Classic data on the site is credited to cMaNGOS classic-db (GPL-3.0). - [ForeverDB addon page](https://foreverdb.net/addon)
- **Wowhead Forever** collects data through the Wowhead Client/Looter upload, but no page was found that describes Forever-specific drop-rate output. - [Wowhead Forever client](https://www.wowhead.com/forever/tw/client)
- A Nov 9 guide says Wowhead's drop percentages for Forever items are probably Classic data carried over. Its reason: the samples (up to about 290,000 kills per mob) are far larger than five days of Forever could produce. The guide comes from a gold-selling site. - [timesaver.gg hyperspawn guide](https://timesaver.gg/blog/wow-forever-hyperspawn-grind-spots)
- Quest-item drops feel low (Blizzard forum, Bug Report, 2026-11-07). Kill counts players posted include: over 40 kills for 8 Corrupted Brain Stem (BFD); over 30 wolves for 7 Rough Wolf Pelt; over 30 kills for 5 Harvester Gyrostabilizer; 15 murlocs for 1 Longshore Murloc Gill; over 20 kills for 5 Great Goretusk Snout. A second player says Wailing Caverns hides and Serpent Blooms are "barely enough for 1 person". No Blizzard reply, and no comparison with Classic. - [Forum: Quest Item Drop Rate TOO LOWWWW](https://us.forums.blizzard.com/en/wow/t/quest-item-drop-rate-too-lowwww/2404646)
- A forum thread says the Waylaid Crate drop rate feels the same as in beta, with some players calling it extremely low. This comes from a search snippet; the thread was not fetched. - [Forum: Waylaid Crate drop rate](https://us.forums.blizzard.com/en/wow/t/waylaid-crate-drop-rate/2409297)
- A boost-selling site claims quest-item drop rates are unchanged but group looting has hidden logic that favors the member who has gone longest without a drop, and attributes this to a beta developer post. No Blizzard link was found to back it, so treat it as low confidence. - [pewpewshop: quest item drops in groups](https://pewpewshop.chatium.ai/wow-boost/blog~how-do-quest-item-drops-work-in-groups-in-wow-forever)
- foreverchanges.pro publishes per-dungeon loot tables "with drop rates", for example City of Dalaran, a Forever-only dungeon. Its method and sample are not given. This was not fetched. - [foreverchanges.pro City of Dalaran](https://foreverchanges.pro/dungeons/city-of-dalaran)

### Inferences
- **Kill Value:** foreverdroprate.com is the only source found that publishes counts, sample sizes and confidence intervals per mob from live Forever. It is the best check against the cmangos 1.12 tables. There is no export or license, though, so it can serve as a manual check, not as data to ship. Shipping it would need the operator's permission (unnamed; Discord through Blackthornes Farmer).
- Forever-only zones (Zephras Isle has the most data) and Forever-only mobs are exactly where cmangos has nothing. A "measured in Forever" layer would add most for those.
- The forum kill counts (for example, 15 kills for 1 murloc gill) are anecdotes, not rates. They could seed a few spot checks of quest-item rates against cmangos, but nobody has published that comparison.
- **New feature idea:** Kill Value could count the player's own corpses (as DropAtlas does) and show "your observed rate (n)" next to the cmangos rate. The data stays local, no third-party terms apply, and it fits the advice-only rule.

### Gaps
- No source found compares Forever drop rates with 1.12 or Classic Era for the same mob. The repo's Kill Value data is keyed by NPC id, so the sample mobs above were not cross-checked here.
- No downloadable or licensed Forever loot data set was found: no Google Sheet, no GitHub repo, and nothing from Reddit turned up in search.
- The operators and terms of foreverdroprate.com and Forever Drops are unknown.

## 2. Rare spawn timers and locations compiled for Forever

### Takeaway
ForeverDB has the best-documented rare list: 357 rares, each tagged "seen in Forever" (65) or
"Classic data" (cmangos), with respawn ranges and map pages, last extracted 2026-11-09. Several
guide sites list rares by zone, and Forever-only rares exist (Nightscreech, Coldrasp). Nobody has
published measured Forever respawn timers with sample sizes.

### Cited Findings
- **ForeverDB /rares**: 357 rares across 39 zones and 10 dungeons, 350 of them level 60 or lower. Fields: name, level or range, rank (rare / rare elite), zone, respawn range, tameable flag, and source tag "seen in Forever" or "Classic data". The intro says 65 have been seen in Forever and the rest come from Classic (cmangos). Each rare's page carries spawn points on a zone map, notable loot, and when players last saw it in Forever. Data is "extracted from the local game client" (build 1.60.1.70862, extracted 2026-11-09), plus game cache and ForeverDB addon sightings. No export or license. Examples: Bayne, level 10, Tirisfal, 1-3 h, seen in Forever; Sri'skulk, level 13, Tirisfal, 1-3 h, Classic data; Hannah Bladeleaf, level 24 rare elite, Barrens, about 7 min, seen in Forever. - [ForeverDB rares](https://foreverdb.net/rares)
- One guide counts 385 rares and rare elites, including 23 new to Forever and 79 tameable. Search results attributed it to mmonster.co or forevermastery.com; it was not fetched, so the count is unverified. - [mmonster.co rare spawns](https://mmonster.co/wow-forever/guides/rare-spawns); [forevermastery.com rares](https://forevermastery.com/en/guides/wow-forever-rares)
- The Forever Era lists "Classic rares in WoW Forever: where they spawn" and confirms fewer spawns than ForeverDB, per a search summary (not fetched). - [The Forever Era rares](https://theforeverera.com/en/rares/)
- Forever-only rares reported on the forums: a level 10 white owl "Nightscreech" in Teldrassil, said to be tameable, and a level 12 wolf "Coldrasp" in Whispering Forest. These come from a search snippet. - [Forum: new rare white owl in Teldrassil](https://us.forums.blizzard.com/en/wow/t/new-rare-spawn-white-owl-in-teldrassil/2355766)
- Petopia has a Forever-specific rare tameable pets browser, and its forum has a "New Pets in Forever" thread. - [Petopia Forever rare pets](https://www.wow-petopia.com/forever/browse.php?id=rare); [Petopia forum](https://forums.wow-petopia.com/viewtopic.php?t=27358)

### Inferences
- **Rare Alert:** ForeverDB's split between "seen in Forever" and "Classic data" is the closest thing to a Forever rare list with provenance. Its 23-or-so new rares and Petopia's Forever pet list are what to check Rare Alert's NPC id list against. Hannah Bladeleaf's roughly 7-minute respawn being "seen in Forever" suggests some timers differ from Classic, but the method is unstated.
- **New feature idea:** Rare Alert could keep a local "last seen / last killed" log per rare (time and zone), the way ForeverDB tracks sightings. Over time that gives the player their own respawn estimates without third-party data.

### Gaps
- No RareScanner or NPCScan Forever data set was found. Search turned up nothing on whether RareScanner ships a Forever database.
- No respawn timers measured in Forever with sample sizes. ForeverDB gives ranges with no method.
- ForeverDB's terms of reuse are unknown.

## 3. Skill-up chance measurements, profession guides, recipe sources

### Takeaway
No public data set measures Forever (or Classic Era) yellow or green skill-up chances. Guides
describe the colors in words, and at least one calculator assumes the classic linear rule (yellow
100% to grey 0%), which matches the owner's 174-craft fit. Forever has a Legacy perk, "Working
Overtime", that raises skill-up chance by 4 percentage points per rank (20 at max). Profession
leveling guides updated for Forever exist on Wowhead, Icy Veins, Warcraft Tavern and others.

### Cited Findings
- A search for measured Forever yellow/green chances found none. Guides describe orange as guaranteed, yellow as a "good chance" that falls toward green, green as low and falling toward grey, and grey as nothing. - [Warcraft Tavern professions](https://www.warcrafttavern.com/forever/guides/professions/); [Skycoach engineering guide](https://skycoach.gg/blog/wow-forever/articles/forever-engineering-guide)
- The Metabot profession leveling calculator assumes the Classic rule, with chance falling from 100% at yellow to 0% at grey. This is a model assumption, not a measurement. - [Metabot calculator](https://metabot.gg/en/wow-forever/profession-leveling-calculator)
- **Working Overtime** (Legacy perk): each rank adds 4 percentage points to skill-up chance, reaching 20 points at max rank. This is a boost site's guide and was not confirmed against client data. - [Boostroom journeyman professions guide](https://boostroom.com/blog/wow-forever-journeyman-professions-guide-leveling-75150-recipes-trainers-and-materials)
- Some guides say the crafting window shows each recipe's skill-up chance, but none list the actual numbers. This comes from a search summary. - [Icy Veins professions overview](https://www.icy-veins.com/wow-forever/professions-overview)
- Wowhead has 1-300 leveling guides per profession for Forever, two per profession, including a fixed "Tried & Tested" version. - [Wowhead Forever profession leveling guides](https://www.wowhead.com/forever/profession-leveling-guides)
- Endgametools has a calculator that works out the cheapest 1-300 plan from the client's recipes. Its step counts differ from other sites (Blacksmithing 21 steps against 14 on classicwowforever.com). wowcalc.net has 1-300 guides including class "professions" (Mage Comprehension, Rogue Poisons). - [Endgametools leveling](https://endgametools.com/en/wow-forever/leveling); [wowcalc.net professions](https://wowcalc.net/en/forever/guides/professions); [classicwowforever.com professions](https://classicwowforever.com/professions/)
- Rank caps are 75/150/225/300, with character-level gates whose values came from the beta; one bonus value is "unsettled". Another site says Blizzard has not confirmed trainer requirements for Forever. - [wowforevertierlist.com leveling guide](https://wowforevertierlist.com/professions/leveling-guide); [classicwowforever.com](https://classicwowforever.com/professions/)
- Forever adds "600+ new recipes", food XP, blueprints and Legacy, per a boost-site guide. - [lfcarry professions guide](https://lfcarry.com/guides/wow-forever-professions)
- ForeverDB has a professions database (recipes, gathering zones) extracted from the client. - [ForeverDB addon page (site index)](https://foreverdb.net/addon)

### Inferences
- **Skill-Up Odds:** The owner's 174 crafts appear to be the only public-ish measurement of the Forever curve. The community has nothing to replace or contradict it. Working Overtime is a real modifier the model may need: if it adds a flat 4 to 20 points, the straight line shifts up for players who own it. Check the spell in client data before modeling it.
- If the crafting window really shows a chance, the client may expose it through an API. Grep `tools/forever-api/forever-api.json` for a trade-skill chance field before trusting the guides.
- **New feature idea:** an opt-in local log of craft attempts by color and skill gap. It would grow the owner's 174-craft data set, and could later be shared as the first public measurement.

### Gaps
- No Classic Era or SoD skill-up chance data set surfaced in this pass, so there is no fallback to compare against.
- Working Overtime's exact effect is unverified in client data.

## 4. Gathering and fishing data (nodes, fishing loot and skill)

### Takeaway
GatherMate2 runs on Forever (1.52.5, Nov 6), but the ready-made node data people import is
Wowhead *Classic* data: a fallback, not Forever-measured. Forever Drops logs herb, ore, skinning,
fishing and chest loot with the skill at loot time. For fishing, ForeverDB and a fishing guide both
say Forever skill, catch and pool data is still Classic data until players record it.

### Cited Findings
- GatherMate2's Forever build is 1.52.5, released Nov 6, 2026, and records nodes as you gather. "GatherMate2 Data (Wowhead Classic)" imports Wowhead's Classic herb and ore nodes. - [foreverbase.org GatherMate2](https://foreverbase.org/en/addons/catalog/gathermate2/); [wowcalc.net GatherMate2](https://wowcalc.net/en/forever/wiki/addons/gathermate2); [CurseForge GatherMate2](https://www.curseforge.com/wow/addons/gathermate2)
- GatherPath Forever computes the shortest loop through the nodes GatherMate2 has recorded and draws it on the map and minimap. - [CurseForge GatherPath Forever](https://www.curseforge.com/wow/addons/gatherpath-forever)
- Forever-specific herbs (Marefoil, Demonsage, Death Lotus) have unknown or partly known locations; one source says a new glove enchant finds Death Lotus in Mount Hyjal. The Forever Era and Icy Veins list herbs and ores by skill and zone. These come from search summaries. - [The Forever Era gathering](https://theforeverera.com/en/gathering/); [Icy Veins herbalism](https://www.icy-veins.com/wow-forever/herbalism)
- Forever Drops logs mining, herbalism, skinning, fishing, pickpocketing and chest loot, noting the profession skill at loot time, so skill-gated drops show up. - [CurseForge: Forever Drops](https://www.curseforge.com/wow/addons/forever-drops)
- foreverdroprate.com has a `/node/` lookup, and Blackthornes Farmer records "every herb, ore and catch". - [Forever Drop Rate](https://foreverdroprate.com/)
- Fishing: ForeverDB says zone skill, catches and pools are Classic data until players record them in Forever, and a fishing guide says it fishes the live realms to add the numbers. The Forever Fishing addon (CurseForge) records catches, quantities and locations. - [ForeverDB](https://foreverdb.net/); [wowforeverinfo fishing guide](https://wowforeverinfo.com/guides/fishing/); [CurseForge Forever Fishing](https://www.curseforge.com/wow/addons/forever-fishing)
- One guide says a pool typically gives 4-6 casts before it is gone. It gives no sample. - [mmonster.co fishing](https://mmonster.co/wow-forever/guides/professions/fishing)

### Inferences
- **Camp Guide / Kill Value:** node and fishing yields measured in Forever are still thin. Forever Drops (skill at loot time) and foreverdroprate.com `/node/` are the only per-node measured sources. Imported GatherMate2 data and most guide coordinates are Classic, so label them that way if they are ever used.
- **New feature idea:** a "what this node or pool is worth" tooltip, priced from Auctionator like Kill Value, using the player's own counts. The Forever-only herbs (Marefoil, Demonsage, Death Lotus) are where it would help most, since no guide knows them yet.

### Gaps
- No HandyNotes Forever pack and no GatherMate2 data pack from Forever-measured nodes was found.
- No measured fishing loot tables with sample sizes for Forever.

## 5. Grinding spots, gold per hour, XP rates, dungeon runs

### Takeaway
Grinding guides exist, but their "measurements" are Reddit anecdotes plus Wowhead (likely Classic)
drop rates multiplied by AH medians. The solid facts are Blizzard's own: respawns were boosted for
launch, scale down with level, and will drop to "more typical" rates later. Dungeon enemy XP went up
on Nov 8, by 50% per one secondary source. No measured XP/hr or gold/hr data set was found.

### Cited Findings
- Blizzard launch notes (Nov 2, as quoted by timesaver.gg): respawns are fastest in starting zones and "gradually fall to slower rates as you level up". Low-level rates will be lowered "to more typical rates" once the launch surge settles, with no date given. - [timesaver.gg hyperspawn guide](https://timesaver.gg/blog/wow-forever-hyperspawn-grind-spots); also quoted in [conquestcapped gold farming guide](https://conquestcapped.com/guides/wow-forever/wow-forever-gold-farming/)
- Beta notes (Sep 24 to Oct 15) sped up respawns at Crystal Lake murlocs, Pyrewood, Hillsbrad, Ashenvale, Wetlands, Duskwood, Thousand Needles and the larger Dustbelcher camps. Hotfixes slowed overly fast Dustwallow murlocs (Nov 5) and Grol'bolar Quarry troggs (Nov 6). Aggrend (Nov 5) said the team would be "tweaking some numbers". All quoted by timesaver.gg. - [timesaver.gg](https://timesaver.gg/blog/wow-forever-hyperspawn-grind-spots)
- Grind-spot table (levels 6-55): Crystal Lake, Skull Rock, Stonesplinter, Riverpaw, Pyrewood, Grimtotem (Stonetalon), Raven Hill, Dragonmaw, Thousand Needles harpies, Mirefin, Badlands ogres and elementals, Wastewander, Deadwood. Status per row is "reported fast" (Reddit), "faster per beta note" or "normal expected". Reported fast spawns are mostly below level 30. - [timesaver.gg](https://timesaver.gg/blog/wow-forever-hyperspawn-grind-spots)
- Gold per 100 kills is the author's estimate (Wowhead drop rate × Nov 9 US AH median, mats only), not a measurement: harpies at least 3g55s, Lesser Rock Elementals about 3g60s, Dustbelch Grotto about 3g40s, Deadwood at least 4g. Linen's median is about 28c. Anecdotes: 45 min for 10 Stranglethorn tigers (one Reddit post); first group to 60 in about 52 h. The publisher sells gold and boosts. - [timesaver.gg](https://timesaver.gg/blog/wow-forever-hyperspawn-grind-spots)
- Dungeon enemy XP increased on November 8 (Blizzard forum post); the hotfix roundup is dated Nov 9. One secondary source gives the size as +50%. - [Forum: Dungeon enemy XP increased, November 8](https://us.forums.blizzard.com/en/wow/t/dungeon-enemy-xp-increased-november-8/2406595/1); [Blizzard: Forever hotfixes Nov 9](https://news.blizzard.com/en-us/article/24315281/wow-forever-hotfixes-november-9-2026); [Blizzard Watch, Nov 10](https://blizzardwatch.com/2026/11/10/we-are-blessed-with-another-short-world-of-warcraft-maintenance-day/); 50% figure from [timesaver.gg](https://timesaver.gg/blog/wow-forever-hyperspawn-grind-spots)
- ForeverDB's companion uploads per-boss loot, boss abilities and kill durations at the player's level. ForeverDB has `/dungeons`, `/leaderboards` (first kills, fastest clears), `/logs` and `/replay` pages. - [ForeverDB addon page](https://foreverdb.net/addon)
- Gold-farming guide for levels 30-45 (conquestcapped.com); it quotes the Nov 2 respawn note. This comes from a search snippet. - [conquestcapped gold farming](https://conquestcapped.com/guides/wow-forever/wow-forever-gold-farming/)

### Inferences
- **Camp Guide:** respawn rates are a moving target. They are boosted now, scale by level, and are due to come down, so any "respawns fast" claim in Camp Guide would go stale. Stick to things the player can see: density, level fit, value per kill from Kill Value.
- The Nov 8 dungeon XP buff means dungeon XP per hour is now higher than any pre-Nov-8 guide says.
- **New feature idea:** a local "this session" readout (kills, XP/hr, value/hr from Kill Value). It would replace the anecdotal guide numbers with the player's own, and fits Camp Guide or Kill Value.

### Gaps
- No measured XP/hr or gold/hr data set for Forever, and no Reddit data threads were reached (search returned none).
- The 50% dungeon XP figure was not read from the Blizzard post itself.

## 6. Instance lockout or dungeon-entry caps; world-buff and aura timers while offline

### Takeaway
Forever guides agree on a cap of 5 instance entries per hour and no scheduled dungeon lockouts, but
no Blizzard Forever source states it (retail is 10 per hour). Nothing public says whether Forever
world buffs or other auras tick while offline. The repo's own client-data notes (docs/09,
docs/08) already go further than the community on this.

### Cited Findings
- Fextralife's Forever wiki: dungeons have no scheduled lockouts, and the only limit is 5 instance entries per hour. Warcraft Tavern (older) says 5 resets per hour. - [Fextralife Forever Dungeons](https://wowforever.wiki.fextralife.com/Dungeons); [Warcraft Tavern dungeons guide](https://www.warcrafttavern.com/forever/guides/dungeons/)
- Retail/Classic forum threads quote Blizzard Support saying 10 instances per hour, as a rolling window from the first entry. That is not Forever-specific. - [Forum: You have entered too many instances recently](https://us.forums.blizzard.com/en/wow/t/you-have-entered-too-many-instances-recently/1778568); [EU forum: hourly lockout](https://eu.forums.blizzard.com/en/wow/t/hourly-lockout-for-instances-since-warband-release/525621)
- The repo's own notes (2026-11-09) already record the 5/hour claim from Fextralife, Chaosboost and Mythic-store against retail's 10, and say counting entries is possible but telling a new instance from a re-entry may need GUID fields that are secret inside instances. - local: `docs/09-hidden-timers.md` (row "Instance cap")
- World buffs offline: no Forever source found. A retail forum thread says food and flask timers run while offline, which is not confirmed for Forever. PizzaWorldBuffs (GitHub) tracks world-buff timers, but nothing shows it has Forever support. - [Forum: food buffs and logout](https://us.forums.blizzard.com/en/wow/t/hey-blizzard-whats-up-with-food-buffs-not-working-when-you-log-out-with-em-on/2048231); [PizzaWorldBuffs](https://github.com/Pizzahawaiii/PizzaWorldBuffs)
- The repo already has client-data findings: Sayge's hidden 4 h wait counts in time online (committed 0f293bf, "confirmed"), Forever's own world-buff spell ids, and Wowdee's report on Forever world buffs. - local: `docs/09-hidden-timers.md`, `docs/08-darkmoon-faire.md`; [Wowdee Forever world buffs](https://wowdee.com/articles/wow-forever-world-buffs)
- A beta forum thread reports no automatic logout after 8 hours AFK, which matters for anyone keeping buffs by staying online. This comes from a search snippet. - [Forum: No auto logout after 8 hours AFK](https://us.forums.blizzard.com/en/wow/t/no-auto-logout-after-8-hours-of-being-afk/2375902)
- ForeverDB's camping page (client build 70862, extracted 2026-11-09): camp features need 1 min sitting or crafting nearby, all camping features share a 1 h cooldown, and the Camp Tent raises Rested to "5% of a level". Boosted Rest duration is not listed. - [ForeverDB camping](https://foreverdb.net/camping)

### Inferences
- **Instance-cap counter (new feature idea):** the community "5 per hour" figure is consistent but unsourced. A local counter of instance entries (warn at 4) would be useful advice, and the warning text should say the cap is unconfirmed. The open problem from docs/09 (telling a new instance from a re-entry inside a secret-GUID instance) still stands.
- **Camp Guide:** ForeverDB's camping data (1 h shared cooldown, Camp Tent Rested to 5% of a level) can be checked against Camp Guide's tent note. The hidden "[DNT] Boosted Rest" (1 h) in docs/09 is still to check in game.

### Gaps
- No Blizzard statement on Forever's instance-entry cap.
- No community measurement of world buffs or other auras ticking offline on Forever.
