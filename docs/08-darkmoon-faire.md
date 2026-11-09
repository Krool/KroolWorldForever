# Darkmoon Faire and Sayge's fortunes on Forever

Researched 2026-11-09, the morning Forever's first faire opened. The owner got a fortune, died, lost
the buff and could no longer see when Sayge would give another. Client data is from wago.tools,
build 1.60.1.70862 (Forever live); the 1.12 rows are from the cmangos classic-db dump Kill Value
already uses (`tools/killvalue-data/sqlcache`).

## The faire

- First run: Elwynn Forest beside Goldshire, Monday 9 to Monday 16 November 2026, 04:00 at both
  ends on the in-game calendar (Wowhead's screenshot, via Foreverwisp). Warcraft Tavern says
  "November 9th through 15th". Next: Mulgore, near Thunder Bluff, from 7 December. The dates are
  stored in the client, so Blizzard can still move them. Each run is 168 hours.
- Sayge (npc 14822) asks two questions; the answers pick the fortune (Warcraft Tavern): Damage 1-1;
  Resistance 1-2 or 2-3; Armor 1-3 or 4-3; Spirit 2-1 or 4-2; Intelligence 2-2 or 4-1; Stamina
  3-1; Strength 3-2; Agility 3-3. Last option: a written fortune (item 19422, spell 23765).
- Forever's change: world buffs do nothing inside raids (Blizzard via Wowhead; the aura text below).

## The spells (Forever client data)

| Spell | What it is | Duration | Death | Notes |
|---|---|---|---|---|
| 23735-23738, 23766-23769 | Sayge's Dark Fortune of Strength, Agility, Stamina, Spirit, Intelligence, Armor, Damage, Resistance | 2 h (`SpellDuration` 367) | removed | Aura text now ends "No effect while in a raid instance." (Forever's edit). Effect 2 triggers 23770. |
| 23770 | Sayge's Carnie Buff | **4 h** (`SpellDuration` 527, 14,400,000 ms) | **kept** | Hidden debuff: `Attributes_0` 0x24800100 (is a debuff), `Attributes_1` 0x10000088 (no aura icon), `Attributes_2` 0x1 (allowed on the dead), `Attributes_3` 0x00100000 (persists through death). No text. |
| 1304767-1304782 | Same eight names, new in Forever | 2 h | removed | Cast on self, one effect, no trigger, `Attributes_0` 0x80. Aura text without the raid note. Purpose unknown (maybe the open-world half of the raid rule). |
| 23765 | Darkmoon Faire Fortune | - | - | Creates the written fortune. |

Values: 10% (damage, or the stat), Armor 10%, Resistance +25 to all.

## How the wait works

Blizzard's server code is not public, so this is the best reading of the evidence:

- Every fortune also puts **Sayge's Carnie Buff** on you: hidden, 4 hours, and kept through death.
  A hidden marker that outlives the buff and survives death only makes sense as Sayge's cooldown.
- Guides agree in shape: Prima gives a four-hour cooldown between fortunes; warcraft.wiki.gg says
  "the cooldown period is at least a few hours longer than the buff duration". Some guides say 2
  hours (likely the buff's own length).
- The cmangos 1.12 database gates Sayge only on having a fortune buff right now (conditions 869 and
  870: any of the eight auras). Private servers built on it let a dead player ask again at once,
  which is likely where the "die and just ask again" belief comes from. The client data says the
  original design is the 4-hour marker.
- **So: a new fortune about 4 hours after the last one, and dying does not shorten it.**
  Unverified on Forever.
- The fortune runs down in real time while logged out (warcraft.wiki.gg). Whether the 4-hour marker
  does too is unknown.

## What an addon can see

- **Not the marker, most likely.** Since patch 9.2.5, `GetPlayerAuraBySpellID` "no longer returns
  information about hidden auras" (warcraft.wiki.gg); `C_UnitAuras` came after. The owner ran
  `C_UnitAuras.GetPlayerAuraBySpellID(23770)` the same day and got nothing. The time of that
  fortune is unknown, so the wait may already have ended, but it fits. Sayge's Fortune (0.14.0)
  dates the visible fortune instead (`docs/features/fortune.md`).
- **The fortune itself, yes**: `UNIT_AURA`, then `C_UnitAuras.GetPlayerAuraBySpellID(id)` for the
  eight ids. Its `expirationTime` minus 2 hours is when it was given; plus 4 hours is when Sayge
  should answer again. Kept per character against the real clock (`time()`), it survives death and
  logout. Outside instances the player's own auras are not secret, and fortunes are useless in
  raids anyway.
- **Sayge's refusal**: `GOSSIP_SHOW` with Sayge targeted, then `C_GossipInfo.GetText()`. In 1.12
  his "come back later" page is gossip menu 6189 (text 7393); Forever's wording is not recorded yet.
  Reading it would confirm or correct the 4 hours from real visits.
- All the calls above are in Forever's API docs (`tools/forever-api/forever-api.json`).

## To check in game

1. During the wait: `/dump C_UnitAuras.GetPlayerAuraBySpellID(23770)`. Data means the exact time
   left is readable; nil means hidden, as expected.
2. Ask Sayge again before the 4 hours are up; write down what he says and the time.
3. After the next fortune: `/dump C_UnitAuras.GetPlayerAuraBySpellID(23768)` (or the stat's id)
   and the same for 1304769, to see which spell Forever puts on you.

## Sources

- Client data: wago.tools db2 `SpellName`, `Spell`, `SpellMisc`, `SpellDuration`, `SpellEffect`,
  build 1.60.1.70862 (https://wago.tools/db2).
- forever.warcraftdb.com tooltip, spell 23768: https://forever.warcraftdb.com/api/v1/tooltip/spell/23768
- cmangos classic-db 1.12 (`spell_template`, `gossip_menu`, `conditions`):
  https://github.com/cmangos/classic-db
- Warcraft Tavern, "The Darkmoon Faire is Now Open in WoW Forever":
  https://www.warcrafttavern.com/forever/news/the-darkmoon-faire-is-now-open-in-wow-forever/
- Foreverwisp, faire dates: https://www.foreverwisp.com/guides/wow-forever-darkmoon-faire-november-elwynn-dates
- Warcraftmaps, faire guide: https://warcraftmaps.com/guides/darkmoon-faire
- warcraft.wiki.gg, Sayge's Dark Fortune: https://warcraft.wiki.gg/wiki/Sayge%27s_Fortunes
- warcraft.wiki.gg, GetPlayerAuraBySpellID (9.2.5 note): https://warcraft.wiki.gg/wiki/API:GetPlayerAuraBySpellID
- Prima Games, Sayge buffs (Season of Discovery): https://primagames.com/tips/how-to-get-sayges-darkmoon-faire-buffs-in-wow-season-of-discovery-sod
