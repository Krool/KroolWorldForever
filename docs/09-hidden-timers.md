# Hidden timers on Forever

Researched 2026-11-09, after Sayge's hidden wait (`docs/08-darkmoon-faire.md`). Client data:
wago.tools, build 1.60.1.70862, scanned for auras of 30 minutes or more that have no aura icon
(`SpellMisc.Attributes_1` 0x10000000) or carry `Attributes_0` 0x80, and are not passive.
Scratch scripts: `hidden-timers.js` and `neighbors.js` (not kept in the repo).

## Timers that matter to a player

| Timer | What we know | Can an addon time it? |
|---|---|---|
| Sayge's wait (23770, 4 h, kept through death) | Each fortune applies it | Yes, from the visible fortune: Sayge's Fortune (0.14.0) |
| Instance cap | Classic limited new instances entered per hour (per account). Forever guides say 5 per hour (Fextralife, Chaosboost, Mythic-store); one says Blizzard has not published it and retail is 10. The game only says "You have entered too many instances recently" when you hit it. | Partly: count entries into instances. Telling a new copy from a re-entry needs the instance id in creature GUIDs, which may be secret inside instances on Forever. Unverified. |
| Camp Tent lockout | Camp Guide reads Boosted Rest (1229451). Forever also has a hidden "[DNT] Boosted Rest" (1325299, 1 h). | If the game applies only the hidden one, Camp Guide's tent note never shows. Check in game. |

## Hidden auras with no known source

All new in Forever (ids above 1,000,000), applied by the server (no client spell triggers them), so
there is no visible event to time them from:

- **Timer**, 4 h (1311812), 30 min (1311815), 1 h (1309143). Kept through death. The first two are
  numbered next to "Light's Vigil" (1311806).
- **Trigger Aura**, 7 days, debuff, kept through death: 1263377 (next to "Flag Tracking Quest") and
  1305729 (next to "Matron's Call", an Onyxia whelp healing effect). Weekly markers of something.

Older leftovers in the same scan, not Forever's: "[DNT] Tower Capture - Honor Cooldown (24 Hours)"
(366403), Season of Discovery's "Libram of Blessings" and "Idol of the Wild Spam Prevention Dummy"
(421513, 426090, 15 days), "Controller Timer" (462553).

## World buffs and death (not timers, found in the same scan)

Forever has its own copies of the world buffs, all with `Attributes_0` 0x80 and new ids:

| Copy | Length | Kept through death |
|---|---|---|
| Rallying Cry of the Dragonslayer (1304452) | 2 h | yes |
| Fengus' Ferocity, Mol'dar's Moxie, Slip'kik's Savvy (1304759, 1304753, 1304751) | 2 h | yes |
| Warchief's Blessing (1304594) | 1 h | yes |
| Might of Stormwind (1304678), new: the same bonuses as Warchief's Blessing, for the Alliance | 1 h | yes |
| Songflower Serenade (1304690) | 1 h | no |
| Sayge's eight fortunes (1304767-1304782) | 2 h | no |

So on Forever dying should keep Rallying Cry, Warchief's Blessing, the Dire Maul buffs and Might of
Stormwind, and lose Sayge's fortune and Songflower. Wowdee reports Rallying Cry's new
death-persistence flag from Wowhead's beta data, which fits. What the 0x80 copies are for is unknown:
the classic spells (with "No effect while in a raid instance" in their text) still exist too. One
guess (an AzerothCore module's unsourced claim): world buffs pause in raids and come back with their
time left.

## Sources

- Client data: https://wago.tools/db2 (SpellName, Spell, SpellMisc, SpellDuration, SpellEffect)
- Fextralife, WoW Forever dungeons: https://wowforever.wiki.fextralife.com/Dungeons
- Chaosboost, dungeons: https://www.chaosboost.com/articles/wow-forever-dungeons-and-loot
- Mythic-store, leveling zones: https://mythic-store.com/blog/top-10-leveling-zones-in-wow-forever-ranked-by-what-actually-pays
- Conquestcapped, solo farming: https://conquestcapped.com/guides/wow-forever/wow-forever-solo-farming/
- WoWWiki archive, instance limitations: https://wowwiki-archive.fandom.com/wiki/Instance_limitations
- Wowdee, Forever world buffs: https://wowdee.com/articles/wow-forever-world-buffs
- AzerothCore module (unsourced rule): https://github.com/buildthehomelab/wow-mod-forever-world-buffs
