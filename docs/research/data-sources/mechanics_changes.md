# WoW: Forever mechanics changes vs Classic 1.12 (documented or measured)

Researched 2026-11-10. Reliability tags on each finding: **[P]** Blizzard primary (blue post, dev notes,
hotfix list, official article); **[M]** measured (owner in game, or Forever client data on wago.tools,
build 1.60.1.70862, recorded in this repo's docs); **[W]** established news/guide site (Warcraft Tavern,
Icy Veins, Wowhead, MassivelyOP, Mein-MMO, warcraft.wiki.gg); **[S]** low-confidence SEO/guide site or
anonymous forum post. **BREAKS 1.12** marks a finding that invalidates a 1.12 assumption an addon might
make. Icy Veins and MassivelyOP pages returned HTTP 403 to the fetcher; where only a headline or search
snippet was read, the finding says so. Blizzard's hotfix list was read from the forum mirror
(us.forums.blizzard.com/en/wow/t/2403040), which holds the Nov 5, 6 and 9 entries.

## Instance lockouts and dungeon-entry caps

### Takeaway
Blizzard has published no hourly or daily instance-entry cap for Forever; guides repeat Classic's
"5 per hour" without a source, while the Mainline client Forever runs on uses 10 per hour per account on
retail. Raid lockouts are the clearer change: Blizzard plans a weekly reset for all three raids that unlock
Dec 9, 2026, Onyxia included, where Classic Era resets Onyxia every 5 days (BREAKS 1.12 if confirmed).

### Cited Findings
- Classic 1.12 and Classic Era baseline: 5 new instances per hour; Classic (2019 onward) added a cap of 30
  unique instances per 24 hours, and Blizzard's developer note said the 5-per-hour limit had been tracked
  per realm since 2005. Whether it is per account or per character is disputed in the thread. [P via
  forum/search snippet] - [Blizzard forum: New instance limit in WoW Classic](https://us.forums.blizzard.com/en/wow/t/new-instance-limit-in-wow-classic/556616); [Icy Veins forum copy](https://www.icy-veins.com/forums/topic/50154-new-instance-limit-in-wow-classic/); [WoWWiki archive: Instance limitations](https://wowwiki-archive.fandom.com/wiki/Instance_limitations)
- Retail (Mainline) baseline: 10 instances per hour per account, a rolling window, raised from 5 by a
  2014 hotfix. [S forum posts] - [Blizzard forum: Instance Limit Per Hour](https://us.forums.blizzard.com/en/wow/t/instance-limit-per-hour/1886788); [Blizzard forum: You have entered too many instances recently](https://us.forums.blizzard.com/en/wow/t/you-have-entered-too-many-instances-recently/1778568)
- Forever: Fextralife, Chaosboost and Mythic-store guides say 5 per hour; none cites Blizzard. One guide
  says Blizzard has not published the number. (Summarized in this repo, researched 2026-11-09.) [S] -
  [Fextralife Dungeons](https://wowforever.wiki.fextralife.com/Dungeons); [Chaosboost](https://www.chaosboost.com/articles/wow-forever-dungeons-and-loot); [Mythic-store](https://mythic-store.com/blog/top-10-leveling-zones-in-wow-forever-ranked-by-what-actually-pays); local: `docs/09-hidden-timers.md`
- No hit on Blizzard's Forever hotfix list (Nov 5, 6, 9) or the beta development notes (Sept 24 to Nov 4)
  mentions instance caps or lockouts. [P, absence] - [Forever hotfixes thread](https://us.forums.blizzard.com/en/wow/t/2403040/1); [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696)
- Searches for players hitting "You have entered too many instances recently" on Forever found nothing
  (2026-11-10). [absence]
- Raids: Blizzard's official raid preview reportedly plans a standard weekly reset for all three launch
  raids (Barrow Deeps, Hyjal Summit, Onyxia's Lair), described as planned, not promised. Icy Veins headline
  "Weekly Reset, Attunement, Locations, Raid Sizes: Official WoW Forever Raid Preview" (page 403; read via
  search snippets). [W] - [Icy Veins raid preview](https://www.icy-veins.com/wow-forever/news/weekly-reset-attunement-locations-raid-sizes-official-wow-forever-raid-preview/); [GamerFuzion](https://www.gamerfuzion.com/world-of-warcraft-forever-raids-december-9-barrow-deeps-hyjal-summit-onyxia-attunement/)
- Classic Era/Anniversary Onyxia resets every 5 days; the 3-day ZG/AQ20 timers are Classic-only too.
  BREAKS 1.12 if Forever's Onyxia goes weekly. [W] - [Warcraft Tavern Classic raids](https://www.warcrafttavern.com/wow-classic/guides/raids/); [Zockify Classic reset calendar](https://www.zockify.com/classic/calendar/)
- Raid sizes: Barrow Deeps 10-player, Hyjal Summit 20-player; raids unlock Dec 9, 2026. Whether the 10
  and the 20 share a lockout, and whether a character can run more than one group per week, is not
  published. [W/S] - [Warcraft Tavern overview](https://www.warcrafttavern.com/forever/guides/overview/); [GuildOrder: launch raids and the raid week](https://guildorder.com/games/wow_forever/wiki/the-launch-raids-and-the-raid-week)

### Inferences
- An instance-cap tracker should not hard-code 5: count entries per account in a rolling hour, show the
  count, and learn the cap from the first "too many instances" error the player hits (the message
  arrives as a UI error). Default warning at 5 is the safe choice until measured; retail's 10 is
  plausible because Forever's server code is Mainline.
- A raid-lockout feature should read lockouts from the client (saved-instance APIs) rather than compute
  Classic's 5-day/3-day cycles.

### Gaps
- The Forever hourly cap, any daily cap, and account vs character scope: no Blizzard source found.
- Raid reset weekday/hour per region and Onyxia's player size on Forever: not found (raids not open
  until Dec 9).

## World buffs on Forever (Rallying Cry, Warchief's Blessing, Songflower, Darkmoon, Zandalar)

### Takeaway
World buffs exist but do nothing inside raid instances: Forever edited the aura text ("No effect while in
a raid instance") and Blizzard applies the same pattern to new racial buffs. Forever's copies of the world
buffs persist through death (Sayge and Songflower excepted), which BREAKS 1.12. No Forever Chronoboon was
found. Offline behavior for world buffs is unmeasured, but Classic precedent and the owner's Sayge
measurement both say timers pause while logged out.

### Cited Findings
- Sayge's fortunes on Forever carry new aura text ending "No effect while in a raid instance." [M] -
  local: `docs/08-darkmoon-faire.md`; [forever.warcraftdb tooltip, spell 23768](https://forever.warcraftdb.com/api/v1/tooltip/spell/23768)
- Forever client data has its own copies of world buffs (new ids, `Attributes_0` 0x80):
  Rallying Cry of the Dragonslayer 1304452 (2 h, kept through death); Fengus' Ferocity / Mol'dar's Moxie /
  Slip'kik's Savvy 1304759/1304753/1304751 (2 h, kept); Warchief's Blessing 1304594 (1 h, kept); a new
  Alliance equivalent, Might of Stormwind 1304678 (1 h, kept); Songflower Serenade 1304690 (1 h, lost on
  death); Sayge's eight fortunes 1304767-1304782 (2 h, lost on death). The classic spells with the raid
  note also still exist. BREAKS 1.12 (world buffs dropped on death in 1.12). [M] - local:
  `docs/09-hidden-timers.md`; [wago.tools db2](https://wago.tools/db2)
- Wowdee reports Rallying Cry's new death-persistence flag from Wowhead beta data. [S] - [Wowdee: Forever world buffs](https://wowdee.com/articles/wow-forever-world-buffs)
- Mein-MMO (Cortyn, 2026-09-21): world buffs in Forever work only in the open world and lose their effect
  in dungeons AND raids; "world buff farming" will not exist. Source: people who spoke with Blizzard staff
  at BlizzCon 2026 plus a Windows Central interview with Ion Hazzikostas; no blue post. [W, secondhand] -
  [Mein-MMO](https://mein-mmo.de/wow-forever-keine-weltbuffs-fuer-raids/)
- Gamewave (Sept 2026): Savix says no world buffs in raids. A Blizzard EU forum thread quotes a BlizzCon
  streamer: open world only, not dungeons, raids or battlegrounds; no blue reply found. [S] -
  [Gamewave](https://gamewave.fr/world-of-warcraft-forever/wow-forever-les-world-buffs-sont-ils-au-programme/); [EU forum: official stance on world buffs](https://eu.forums.blizzard.com/en/wow/t/question-world-buffs/628446)
- Warcraft Tavern (Luxrah, 2026-11-09): "world buffs cannot be used inside raids". [W] - [Warcraft Tavern: Darkmoon Faire now open](https://www.warcrafttavern.com/forever/news/the-darkmoon-faire-is-now-open-in-wow-forever/)
- Blizzard dev notes (Oct 26, clarified Oct 27): new Skyborne buffs "Attuned" (1 h, Ley Line) and
  "Charged" (1 h, 30% speed) survive death and are removed on entering a raid. First-party confirmation of
  the "survives death, stripped in raids" pattern. [P] - [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696)
- Lordaeron's Blessing (Eastern Plaguelands tower shrine, +5% max health, 30 min, refreshable) reportedly
  works only in EPL, Stratholme and Scholomance, is stripped on raid entry, and its timer does not tick
  offline. The page says its numbers come from Classic Anniversary data and the raid claim from unnamed
  players. [S] - [games.gg Lordaeron's Blessing (2026-09-19)](https://games.gg/world-of-warcraft/guides/wow-forever-lordaerons-blessing/)
- Chronoboon: Classic Era added the Chronoboon Displacer in 1.13.7 (2021), sold by Chromie in Andorhal; it
  snapshots world buffs and puts a 1-hour cooldown on release. Blizzard's stated reason: "once you're
  buffed, you're incentivized to log off and stop playing to preserve your buffs." [P] - [Pazorax, The
  Future of World Buffs in Classic Era (2021-03-31)](https://us.forums.blizzard.com/en/wow/t/the-future-of-world-buffs-in-classic-era/923110); [Blizzard Watch (2021-04-20)](https://blizzardwatch.com/2021/04/05/wow-classic-chronoboon-displacer/)
- No Forever source mentions a Chronoboon or any buff-storage item. One low-confidence guide says "the
  Chronoboon Displacer never stored this buff, so the logout is your only bank" (Traces of Silithyst
  page). [S] - [games.gg Traces of Silithyst](https://games.gg/world-of-warcraft/guides/traces-of-silithyst-in-wow-forever/)
- An AzerothCore module claims world buffs pause in raids and return with their time left; unsourced. [S]
  - [wow-mod-forever-world-buffs](https://github.com/buildthehomelab/wow-mod-forever-world-buffs)
- Icy Veins headline: "Raid-wide buffs, auras and totems coming in WoW Forever" (class buffs, not world
  buffs; page 403). [W, headline only] - [Icy Veins](https://www.icy-veins.com/wow-forever/news/raid-wide-buffs-auras-and-totems-coming-in-wow-forever/)
- Addon visibility: inside instances Forever makes aura data secret ("Auras cannot be accessed when
  secret while tainted"; `UNIT_AURA` `isFullUpdate` is secret in the Deadmines, seen 2026-11-09). [M] -
  local: `CLAUDE.md` platform facts

### Inferences
- Two spell copies (classic id with the raid note, plus a 0x80 copy without it) fit a swap or suppression
  on raid entry, but which one the player actually carries is unmeasured. `docs/08` lists the in-game
  `/dump` checks.
- Advice that assumes world buffs help a raid (1.12 "world buff the raid") is wrong on Forever. Advice for
  open-world grinding, rares and dungeons may still apply; the dungeon case is contested (see Gaps).
- If buffs pause offline like Sayge's (next sections), logging out still preserves world buffs on
  Forever, so a Chronoboon is less needed for open-world play.

### Gaps
- Dungeons: the aura text says "raid instance" only, while Mein-MMO and the streamer quote say dungeons
  too. Unresolved; measurable in game.
- Rallying Cry, Nefarian/Onyxia head buffs: Onyxia unlocks Dec 9; whether the head turn-in exists on
  Forever is unknown.
- Spirit of Zandalar: Zul'Gurub is not in Forever's announced raid list; no source on Zandalar.
- Whether world buffs are removed on raid entry or merely inert inside, and whether time keeps running
  while inert: no source.

## Darkmoon Faire on Forever (schedule, Sayge, tickets)

### Takeaway
Forever's first faire ran in Elwynn from Nov 9, 2026; the next opens in Mulgore on Dec 7. Content matches
Classic so far. Sayge gives a 2-hour fortune plus a hidden 4-hour, death-proof "Carnie Buff" wait; on
Forever both timers stop while logged out (measured). The online-only wait matches an Icy Veins Classic
guide, so it is probably not new; the fortune pausing offline contradicts warcraft.wiki.gg's "real time".

### Cited Findings
- Schedule: Elwynn Forest near Goldshire, Mon Nov 9 to Mon Nov 16, 2026, 04:00 both ends on the in-game
  calendar (Wowhead screenshot via Foreverwisp); Warcraft Tavern says Nov 9-15; next run Mulgore from
  Dec 7. Dates are client data and can move. [W/M] - [Warcraft Tavern (2026-11-09)](https://www.warcrafttavern.com/forever/news/the-darkmoon-faire-is-now-open-in-wow-forever/); [Foreverwisp faire dates](https://www.foreverwisp.com/guides/wow-forever-darkmoon-faire-november-elwynn-dates); local: `docs/08-darkmoon-faire.md`
- Warcraft Tavern: the faire "brings all original activities and rewards" and they had not spotted
  anything new; Darkmoon Prize Tickets come from item turn-in quests; a 14-slot bag costs 50 tickets;
  Sayge answer table: Damage 1-1; Resistance 1-2 or 2-3; Armor 1-3 or 4-3; Spirit 2-1 or 4-2; Intelligence
  2-2 or 4-1; Stamina 3-1; Strength 3-2; Agility 3-3. [W] - [Warcraft Tavern](https://www.warcrafttavern.com/forever/news/the-darkmoon-faire-is-now-open-in-wow-forever/)
- Client data: fortunes 23735-23738 and 23766-23769 last 2 h and are removed on death; each triggers Sayge's
  Carnie Buff 23770, 4 h, hidden (no aura icon), allowed on the dead, persists through death. Values: 10%
  stat or damage, Armor 10%, Resistance +25 all. [M] - local: `docs/08-darkmoon-faire.md`; [wago.tools db2](https://wago.tools/db2)
- Owner measurement (2026-11-10): a fortune taken at 1:35 AM was still on the character after a night
  logged out; Sayge refused at 10.7 h and 12.3 h real time; refused at 231 min logged-in time, offered a
  new fortune at 239.7 min logged-in time (about 15 h real time). So: 4 h of online time on that
  character, and the fortune also pauses offline. [M] - local: `docs/08-darkmoon-faire.md`, `docs/features/fortune.md`
- warcraft.wiki.gg (edited 2026-07-25): "Duration: 2 hours (real time)"; the duration "continues ticking
  down while logged out or playing a different character"; "The cooldown period is at least a few hours
  longer than the buff duration"; buffs "may be removed by the game upon entering an instance". No
  version is given. Contradicted on Forever by the owner's measurement. [W] - [warcraft.wiki.gg Sayge's Fortunes](https://warcraft.wiki.gg/wiki/Sayge%27s_Fortunes)
- Icy Veins Classic guide (search snippet; page 403): buffs "last for two hours and have a four hour
  cooldown (only counted from time you are logged in)". Agrees with the Forever measurement for the wait.
  [W] - [Icy Veins Classic Darkmoon Faire guide](https://www.icy-veins.com/wow-classic/darkmoon-faire-guide-for-wow-classic)
- cmangos 1.12 database gates Sayge only on currently having a fortune buff, so private servers let a dead
  player ask again at once; the client's death-proof 4 h marker contradicts that. [M] - local:
  `docs/08-darkmoon-faire.md`; [cmangos classic-db](https://github.com/cmangos/classic-db)
- Classic ticket turn-ins: tiered profession item turn-ins, each worth 250 Darkmoon reputation; easier tiers
  close as reputation rises; Tier 5 is unlimited. Forever-specific counts not found. [W, Classic only] -
  [Icy Veins Classic DMF guide](https://www.icy-veins.com/wow-classic/darkmoon-faire-guide-for-wow-classic); [Warcraft Tavern Classic DMF guide](https://www.warcrafttavern.com/guides/wow-classic-darkmoon-faire-guide/)

### Inferences
- Any Sayge timer must count the character's logged-in time, not the wall clock. The fortune's own
  `expirationTime` gives the start only while logged in; across logout, store remaining seconds, not an
  absolute time.
- "Die and ask Sayge again" (a private-server habit) does not work: the 4 h marker survives death while the
  fortune does not, so a dead player loses the buff and still waits.
- Elwynn in November then Mulgore in December suggests the Classic two-location monthly alternation.

### Gaps
- Forever turn-in item lists, ticket counts, Darkmoon card/deck changes: not found.
- Whether Forever changed the cooldown or only the buff's offline behavior vs 1.12: 1.12 behavior is
  sourced only to the wiki (real time) and Icy Veins (online-only cooldown), which disagree on the buff.
- Sayge's refusal text on Forever: not recorded.

## Aura and timer behavior while offline (buffs, debuffs, Resurrection Sickness, Deserter, cooldowns)

### Takeaway
The only Forever measurement is Sayge: both the visible fortune and the hidden 4 h wait stop while logged
out. Classic precedent agrees for buffs (Blizzard said players logged off to preserve world buffs).
Nothing Forever-specific was found for Resurrection Sickness, Deserter, or item cooldowns. Rested XP is
the deliberate exception that accrues offline.

### Cited Findings
- Forever: Sayge's fortune and Carnie Buff do not tick while logged out (measured 2026-11-10). [M] -
  local: `docs/08-darkmoon-faire.md`
- Classic Era: Blizzard said "once you're buffed, you're incentivized to log off and stop playing to
  preserve your buffs" (2021-03-31), implying world-buff timers pause offline. [P] - [Pazorax blue post](https://us.forums.blizzard.com/en/wow/t/the-future-of-world-buffs-in-classic-era/923110)
- Classic Era Chronoboon cooldown ticked down offline on the 1.13.7 PTR (Icy Veins called it most likely a
  bug); the 1.13.7 patch notes list a change so it "does not tick down if you are offline". [W/P via
  snippet] - [Wowhead Classic PTR article](https://pt.classic.wowhead.com/news/how-the-chronoboon-displacer-preserves-world-buffs-on-the-classic-era-ptr-321650); [Icy Veins PTR thread](https://www.icy-veins.com/forums/topic/57571-chronoboon-world-buff-saver-details-from-the-ptr/); [1.13.7 patch notes](https://eu.forums.blizzard.com/en/wow/t/world-of-warcraft-classic-patch-notes-version-1137/271568?page=2)
- Low-confidence Forever guides say buff timers stop while offline (Lordaeron's Blessing, Resist Fire
  pages). [S] - [games.gg Lordaeron's Blessing](https://games.gg/world-of-warcraft/guides/wow-forever-lordaerons-blessing/); [games.gg Resist Fire](https://games.gg/world-of-warcraft/guides/wow-forever-resist-fire-buff/)
- Rested XP accrues offline in inns, capital cities and on the Cozy Sleeping Bag (which counts as a rested
  area offline). Camp Tent's rested buff lasts 1 h and persists through death. [W] - [Warcraft Tavern Experience & Rested XP](https://www.warcrafttavern.com/forever/guides/experience/)
- Forever timers that decay hourly (unclear whether online-only): first talent respec costs 1 silver and
  later resets fall back to 1 silver after an hour (Sept 24); Legacy talent respec cost drops by one respec
  per hour (Oct 8). Preferred Online Language has a 24 h cooldown (Oct 22 article). [P] - [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696); [Blizzard ruleset article](https://worldofwarcraft.blizzard.com/en-us/news/24302070)
- Battleground "Quitter" debuff cut to 40 s (from 5 min), its stun to 2.5 s (Nov 3 notes). [P] - [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696)
- Hidden server-applied auras new in Forever, no client trigger: "Timer" 4 h (1311812), 30 min (1311815),
  1 h (1309143), kept through death; two 7-day "Trigger Aura" debuffs (1263377, 1305729). Also a hidden
  "[DNT] Boosted Rest" (1325299, 1 h) beside the visible Boosted Rest camp debuff. [M] - local:
  `docs/09-hidden-timers.md`
- Since patch 9.2.5, `GetPlayerAuraBySpellID` no longer returns hidden auras; the owner's
  `C_UnitAuras.GetPlayerAuraBySpellID(23770)` returned nothing on Forever. [W/M] - [warcraft.wiki.gg API note](https://warcraft.wiki.gg/wiki/API:GetPlayerAuraBySpellID); local: `docs/08-darkmoon-faire.md`

### Inferences
- Default assumption for Forever: aura durations pause while logged out unless measured otherwise. Track
  any long timer as "remaining seconds at logout", resumed at login, rather than a wall-clock deadline.
- Hidden markers (Sayge's wait, the "Timer" auras) cannot be read; time them from a visible companion aura
  or event, in online time.

### Gaps
- Resurrection Sickness, Deserter, and item cooldowns (e.g. hearthstone, profession cooldowns like
  Transmute or Mooncloth) offline on Forever: no source found. Profession cooldowns run on real time in
  Classic by common knowledge, but I found no citation for Forever or 1.12.
- Whether Forever's world-buff copies behave like Sayge offline: unmeasured.

## XP, profession, loot, economy, respawn and layering changes; rulesets

### Takeaway
The XP curve and base rested rules match Classic, but Blizzard has tuned dungeon XP up repeatedly
(+20% Oct 8, +50% Nov 9), cut dungeon-quest bonus XP, rebuilt riding (level 40 and 60, TBC-style
pricing), lowered many vendor sell prices, made creatures skinnable once, added group round-robin quest
drops and new recipes, banned GDKP in NA/EU, and runs level-banded respawns with layering. Several of
these break 1.12 data the bundle uses (vendor prices, loot tables, respawn assumptions).

### Cited Findings
XP and rest
- XP to 60 is 4,084,700 (59 to 60: 209,800); 5-player group kill XP is divided by 5 and multiplied by 1.4;
  rested accrues at 5% of the level per 8 h, capped at 150% (30 bubbles), about 10 days to fill; rested
  doubles kill XP only. These match Classic. [W] - [Warcraft Tavern Experience & Rested XP](https://www.warcrafttavern.com/forever/guides/experience/)
- Legacy talent Well Rested: +4% rested rate and cap per rank. Well Fed (cooking) +5% kill XP about 15
  min, lost on death; Cozy Sleeping Bag up to 3 stacks of +1% kill XP, kept through death. New. [W] - [Warcraft Tavern](https://www.warcrafttavern.com/forever/guides/experience/)
- Camping: rest at a campsite at least 1 min for its buffs; campfires last 10 min with a 5 min cooldown.
  [W, search snippet] - [Warcraft Tavern Camping Guide](https://www.warcrafttavern.com/forever/guides/camping/)
- Dungeon XP: dungeon quests give 50% less bonus XP (Oct 1); dungeon creature XP +20% (Oct 8); party XP
  penalty now uses each player's own level, "matching Classic Era", and a member far above the enemy's
  level still zeroes everyone's XP (Oct 8); enemy kill XP in dungeons +50% (hotfix Nov 9). BREAKS 1.12
  dungeon XP values. [P] - [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696); [Forever hotfixes, Nov 9](https://us.forums.blizzard.com/en/wow/t/2403040/1)
- Quest XP values adjusted on various quests; some prerequisites and level requirements changed (Nov 3).
  [P] - [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696)
- Mage AoE farming has been reduced vs Classic. [W] - [Warcraft Tavern Experience](https://www.warcrafttavern.com/forever/guides/experience/)

Riding, training, talents
- Riding: Apprentice at 40, 100g training + 20g mount, 60%; Journeyman at 60, 1000g + 200g, 100%; 10% off
  at Honored with the home faction; one universal Riding skill; Exalted with another race to ride its
  mounts. BREAKS 1.12 (60 vs 40 split costs, universal skill). [W] - [Warcraft Tavern Riding](https://www.warcrafttavern.com/forever/guides/riding/)
- A Blizzard Deep Dive line, as reproduced by fan guides in search snippets: Forever is "adopting the
  Burning Crusade-style mount-cost approach, shifting the up-front mount cost into training and granting a
  mount when players learn the riding skill". Conflicts with Warcraft Tavern's separate mount price; LFCarry
  and Timesaver say exact gold costs are unpublished. [W/S, unverified quote] - [LFCarry mounts](https://lfcarry.com/guides/wow-forever-mounts); [Timesaver mount cost](https://timesaver.gg/blog/wow-forever-mount-cost-gold-to-save)
- Summoning the Felsteed now grants riding skill (hotfix Nov 9). [P] - [Forever hotfixes](https://us.forums.blizzard.com/en/wow/t/2403040/1)
- Class abilities 1-60 now cost 206-207 gold in total for every class (Nov 3). Abilities and ranks must be
  bought from trainers; weapon skills must be learned; dual spec from the trainer at 40. [P/W] - [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696); [Warcraft Tavern overview](https://www.warcrafttavern.com/forever/guides/overview/)
- Mob health and class power were raised just before launch (headlines; pages 403). [W, headline only] -
  [MassivelyOP 2026-11-03](https://massivelyop.com/2026/11/03/world-of-warcraft-forever-buffs-classes-increases-mob-health-prior-to-launch/); [Icy Veins Nov 2 dev notes](https://icy-veins.com/wow-forever/news/class-power-and-enemy-hp-increased-in-massive-class-tuning-wow-forever-development-notes-november-2nd/)

Loot and quests
- Quest drops round-robin among grouped players ("everyone in the group will get drops evenly", Josh
  "Aggrend" Greenfield on X, reported 2026-09-26); some randomness remains. BREAKS 1.12 per-player drop-rate
  math for grouped players. [W] - [Warcraft Tavern](https://www.warcrafttavern.com/forever/news/quest-drops-distribute-more-evenly-in-wow-forever/); [GamesRadar](https://www.gamesradar.com/games/world-of-warcraft/wow-forever-dev-says-quest-drops-arent-changing-in-the-mmo-but-blizzard-has-added-a-bit-of-under-the-hood-functionality-that-makes-them-fairer/); [Icy Veins: players have felt it](https://www.icy-veins.com/wow-forever/news/players-have-felt-a-change-to-group-quest-drops-in-wow-forever/)
- Classic looting restored, so creatures with no loot can still be interacted with (Oct 8); several
  multi-drop or shareable quest items made single (Oct 1, Oct 16); some dungeon quest rewards dropped from
  Rare to Uncommon (Oct 1); selling an unlearned-appearance BoE to a vendor makes it Soulbound (Oct 1). [P] -
  [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696)
- Creatures can be skinned only once before they disappear (Oct 1, Oct 8). Bags no longer auto-equip
  (Nov 3). Drain Soul's soul shard chance on damage cut (Nov 3). [P] - [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696)
- Hotfix loot changes: Zarla Ober drops loot; Heart of the Mountain lootable more than once; Waylaid Crates
  and Craftsman's Writs drop in dungeons again; Berdun's Trusty Rifle no longer random-stat or BoE (Nov 9);
  Ridgeshade Lurkers have loot, Damp Note drop rate up (Nov 6). [P] - [Forever hotfixes](https://us.forums.blizzard.com/en/wow/t/2403040/1)
- Dungeon BoP green/blue appearances unlock for all eligible looters; raid epic appearances only for the
  binder (guide summary of the Deep Dive; may change). [S] - [Timesaver loot rules](https://timesaver.gg/blog/wow-forever-transmog-loot-rules-classic-mode)
- Raid loot methods available to leaders: not described by Blizzard. [S] - [GuildOrder loot systems](https://guildorder.com/games/wow_forever/wiki/loot-systems-for-a-10-and-a-20)

Economy and vendors
- Vendor price changes: enchanted wands sell for 1 copper (Oct 1); several enchanting wands, Minor Wizard
  Oil and the Peace Tea recipe repriced (Oct 8); many profession-created items have lower vendor sell
  prices (Oct 16); Mild Spices sell for 1 copper (Nov 5). BREAKS 1.12 vendor-price tables. [P] - [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696); [Forever hotfixes](https://us.forums.blizzard.com/en/wow/t/2403040/1)
- "Black Market" NPCs sell certain materials at a set price to damp price swings; the auction house uses
  the Modern UI. [W] - [Warcraft Tavern overview](https://www.warcrafttavern.com/forever/guides/overview/)
- GDKP banned (Blizzard Q&A, 2026-09-17), NA and EU only per Clay Stone's Oct 8 interview with 4Gamers;
  no WoW Token; stricter gold-buying enforcement. [W] - [Icy Veins](https://www.icy-veins.com/wow-forever/news/blizzard-just-confirmed-gdkp-runs-wont-be-allowed-in-wow-forever/); [Warcraft Tavern](https://www.warcrafttavern.com/forever/news/blizzard-to-not-allow-gdkp-in-wow-forever/); [Inven Global regional scope](https://www.invenglobal.com/articles/27234/world-of-warcraft-forever-to-allow-gdkp-in-korea)
- PvP: Honor costs of PvP gear and tokens up about 50%, Honor cap 15,000 to 25,000 (Oct 1); Marks of Honor
  stack to 30 (Oct 16); Legacy bartering no longer discounts training and repairs (Oct 16). [P] - [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696)

Professions
- All nine professions return with new materials and recipes; Mobalytics counts 600+ new recipes,
  RankedBoost 884 (from game files). New factions Azeroth Commerce Authority (Alliance) and Durotar Supply
  and Logistics (Horde) sell mid-level recipes. [W/S] - [Warcraft Tavern overview](https://www.warcrafttavern.com/forever/guides/overview/); [Mobalytics](https://mobalytics.gg/wow-forever/guides/wow-forever-all-new-profession-changes); [RankedBoost](https://rankedboost.com/world-of-warcraft/forever/professions/)
- Tanning Rack requirement 140 to 125 and its skill-up range reduced by 15 (Nov 6); some Blacksmithing and
  Leatherworking recipes now random dungeon drops (Oct 8); starter-area Poor Copper Vein nodes reduced
  (Oct 1); Zephras trade supply vendors sell apprentice tradeskill bags (Nov 5). [P] - [Forever hotfixes](https://us.forums.blizzard.com/en/wow/t/2403040/1); [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696)

Respawns, layering, rulesets
- Respawn model: "Starting zones are fastest, and rates slow as characters level"; low-level rates to be
  revisited after the launch surge (Nov 3). Many per-mob and per-zone respawn changes in beta (Sept 24,
  Oct 1, Oct 8, Oct 16) and hotfixes: Ferocitas shorter, Malduko Cloudcrush slower (Nov 9); Grol'bolar
  troggs and some Dustwallow murlocs slowed (Nov 5-6). BREAKS 1.12 respawn timers. [P] - [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696); [Forever hotfixes](https://us.forums.blizzard.com/en/wow/t/2403040/1)
- Beta players (Sept 19) reported near-instant respawns (Nimsy "respawned literally two seconds after he
  died") and guessed at dynamic respawns; no blue reply. [S] - [Blizzard forum: Respawn rates are way too high](https://us.forums.blizzard.com/en/wow/t/2355345)
- Creatures regenerate health out of combat again (Oct 16). [P] - [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696)
- Layering: changing party composition can move you to another world instance (Sept 24); the "refresh
  world" prompt cannot be accepted in combat (Oct 16); congestion reduced in several zones, more on the
  PvP ruleset (hotfix Nov 9); on Oct 23 Blizzard promised fixes but said layering stays (Kami Labs);
  Forever added a warning when you are about to be moved to a new layer (Icy Veins headline). [P/W] -
  [Beta development notes](https://us.forums.blizzard.com/en/wow/t/wow-forever-beta-development-notes-%E2%80%93-updated-october-1/2360696); [Forever hotfixes](https://us.forums.blizzard.com/en/wow/t/2403040/1); [Kami Labs](https://kami-labs.fr/en/wow-forever/wow-forever-layering-correctifs/); [Icy Veins layer warning](https://www.icy-veins.com/wow-forever/news/wow-forever-adds-a-useful-warning-for-when-youre-being-phased-into-a-new-layer/)
- GUIDs were obfuscated in Beta 5 specifically to stop addons detecting layers. [W] - [warcraft.wiki.gg Forever](https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever); local: `docs/01-game-overview.md`
- Rulesets (Blizzard, updated Oct 22): Normal, PvP, Roleplay, Roleplay PvP, and Hardcore "after launch"
  (no date). No grouping, dungeons or raids across rulesets; battlegrounds mix rulesets except Hardcore;
  PvP ruleset allows one faction per account; a dead Hardcore character can transfer to another ruleset;
  Hardcore progress flows out, other progress does not flow in; faction-balance systems may limit
  creation. [P] - [Blizzard: Choose Your Ruleset](https://worldofwarcraft.blizzard.com/en-us/news/24302070)
- Legacy rewards are separate on Hardcore (headline). A Pixel Nitro piece places Hardcore in Winter 2026,
  unconfirmed by Blizzard. [W headline / S] - [Warcraft Tavern](https://www.warcrafttavern.com/forever/news/legacy-rewards-will-be-separate-on-the-wow-forever-hardcore-ruleset/); [Pixel Nitro](https://pixelnitro.com/?p=18797)
- Other rules: no flying; warlock summons need two party members; mages teleport players to cities. [W] -
  [Warcraft Tavern overview](https://www.warcrafttavern.com/forever/guides/overview/)

### Inferences
- Kill Value, Least Valuable and Disenchant Value tables built from cmangos 1.12 will mis-value items whose
  vendor price Forever cut (profession goods, wands, spices) and will miss Forever-only items. Read sell
  price from the client item info and treat the 1.12 table as a fallback.
- Camp/grind advice must not assume 1.12 respawn times; respawns scale by zone level band and change per
  hotfix. Measuring respawns in game (kill-to-respawn timestamps by NPC id) is more reliable than any
  published number.
- Quest drop-rate math for groups should use the round-robin model, not independent per-player rolls.
- Skinning advice: one skin per corpse.

### Gaps
- Exact riding gold costs (Warcraft Tavern vs the TBC-style quote conflict); no Blizzard primary found.
- Dynamic respawn: not confirmed or denied by Blizzard.
- Hardcore rules (trading, AH, self-found, dungeon limits): unpublished.
- Profession skill-up formula changes beyond Tanning Rack: none published (the repo's Skill-Up Odds
  measurements remain the best data).

## What players report as different in practice

### Takeaway
Player reports center on layering (empty worlds at launch, then crowded tag competition), respawn speed,
and the even quest-drop split. The owner's own measurements add two addon-relevant ones: Sayge's timers
stop offline, and aura data is secret inside instances.

### Cited Findings
- Launch opened very many layers; one writer counted 84 instances of Stormwind; later some zones (Westfall)
  became crowded with tag competition. [W] - [MassivelyOP](https://massivelyop.com/?p=615714); [Icy Veins: Where did everyone go](https://www.icy-veins.com/wow-forever/news/where-did-everyone-go-wow-forever-players-blast-its-disruptive-layering/)
- Beta players said layer switches interrupt quests, communication and world PvP. [W] - [Icy Veins](https://www.icy-veins.com/wow-forever/news/wow-forever-players-say-layering-is-interrupting-quests-and-pvp/)
- Launch was smooth for most (queues rarely over 10 min, Icy Veins), but Horde players on the PvP ruleset
  were blocked by faction balance until more Alliance joined (eGamers). [W/S] - [Icy Veins launch](https://www.icy-veins.com/wow-forever/news/wow-forever-launch-avoids-the-usual-queue-boss-chaos/); [eGamers](https://egamers.io/?p=128162)
- Players noticed the group quest-drop change. [W, headline] - [Icy Veins](https://www.icy-veins.com/wow-forever/news/players-have-felt-a-change-to-group-quest-drops-in-wow-forever/)
- Visibility of distant players improved (hotfix Nov 6). [P] - [Forever hotfixes](https://us.forums.blizzard.com/en/wow/t/2403040/1)
- Owner: Sayge's fortune and wait pause offline (2026-11-10); `UNIT_AURA` `isFullUpdate` secret in the
  Deadmines (2026-11-09); aura reads error inside instances. [M] - local: `docs/08-darkmoon-faire.md`, `CLAUDE.md`

### Inferences
- The highest-value 1.12 assumptions to drop in the bundle: world buffs help raids; buffs and Sayge's wait
  run on the wall clock; dying resets Sayge; 1.12 vendor prices; 1.12 respawn timers; Onyxia's 5-day reset.

### Gaps
- No Reddit or r/classicwow thread was read directly (searches returned none usable); community reports
  above come via news sites.
