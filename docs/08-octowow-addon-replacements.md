# OctoWoW third-party addons: Forever replacements

Checked 2026-10-20 (beta) against the addons in the OctoWoW install
(`C:\Users\junk7\WoW\Interface\Addons`). The owner's own Octo* addons are covered in
[06-octowow-port-review.md](06-octowow-port-review.md). None of the 1.12 addons below load on Forever;
the question is whether something else already does the job. Nothing here is verified in-game.

| OctoWoW addon | What it did | Forever option | Status |
|---|---|---|---|
| pfQuest + pfQuest-octo | Quest database, map markers | Questie (Forever build reported; one guide calls an early build a community fork), ForeverWisp, Everything Quests | Covered |
| pfUI (was disabled) | Full UI replacement | ElvUI (Forever build reported), ForeverUI, ForeverForge | Covered |
| aux-addon | Auction house | Auctionator 341 (source checked: Forever loads its modern AH code, full scan works) | Covered |
| AuxVendorSeed | Seeds vendor prices for aux | Not needed: the modern client knows sell prices. Blackthornes Farmer notes the stored sell price can be wrong on Forever and reads the tooltip instead | Check Kill Value's vendor prices at launch |
| Bagshui | Bags | Bagnon, Baganator (both list Forever) | Covered |
| NotGrid | Raid frames | Blizzard raid frames; ForeverUI and ForeverForge raid frames. Grid2, Cell, VuhDo: Forever status not confirmed. ForeverUI says Forever hides health, names and threat from addons in combat, which breaks older frame addons | Covered by Blizzard frames; addon frames depend on secrets |
| Postal-Returned | Mailbox (open all, returns) | Postal's CurseForge page lists no Forever flavor (Oct 2). Modern client has a native Open All button (unverified on Forever) | **Possible gap** |
| Atlas | Instance maps | AtlasLoot Forever (loot and BiS only, no maps); MapUtils has dungeon maps | Mostly covered |
| ShaguScan | Nearby unit scanner (SuperWoW GUIDs) | Nameplates. Unit data is secret in instances and combat | Gap, but limited by secrets |
| ProximityAlert | Rare mob alerts from pfDB | RareScanner lists Forever. SilverDragon does not | Covered |
| RallyHelper | World buff timers (Ony, Nef, Rend, ZG, DMF) | Nothing found for Forever | **Gap if world buffs exist.** A secondhand claim says Forever drops world buffs in raids; no Blizzard statement |
| OnyLogoff | Auto-logout after a world buff | Nothing found | **Gap if world buffs exist.** Check whether `Logout()` is callable from an addon on Forever |
| QuestProgressShare | Party chat on quest progress | Everything Quests, Questie's own announce option, Quest Announce 3 (retail, Forever unconfirmed) | Covered |
| !!!ClassicAPI | Modern API shim for 1.12 | Not needed: Forever is the modern API | Obsolete |

## Gaps worth building (into the bundle)

1. **World buff timers + auto-logout** (RallyHelper + OnyLogoff in one feature). Only if Forever has
   world buffs at all. First check at launch: turn in a head, see if the buff exists and where it
   works. Timers would come from yell/buff events and sharing over an addon channel.
2. **Mail helper** (Postal-lite: open all with a safe delay, return selected, recent recipients). Check
   first whether Forever's mailbox already has Open All, and whether Postal adds a Forever file.
3. **Nearby scanner** (ShaguScan): only outside instances and out of combat, from nameplates. Lower
   value now that RareScanner covers rares.

## Sources

- Addon roundups: https://metammo.com/guides/wow-forever-addons-restedxp-questie-setup , https://wowforevertierlist.com/addons
- Postal: https://www.curseforge.com/wow/addons/postal
- AtlasLoot Forever: https://www.curseforge.com/wow/addons/atlasloot-classic-forever
- RareScanner: https://www.curseforge.com/wow/addons/rarescanner
- ForeverUI: https://www.curseforge.com/wow/addons/foreverui
- Everything Quests: https://www.curseforge.com/wow/addons/everything-quests
- World buffs claim: https://gamewave.fr/world-of-warcraft-forever/wow-forever-les-world-buffs-sont-ils-au-programme/ , https://eu.forums.blizzard.com/en/wow/t/question-world-buffs/628446
