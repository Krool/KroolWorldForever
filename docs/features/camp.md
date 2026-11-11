# Camp Guide

What a campfire gives you. Forever's camping: a cook lights a campfire, other players place one
profession object each around it (a Camp Chair, a Lodestone...), and everyone who sits near the fire
for a minute gets Camp Benefits for an hour: one buff that holds every object's bonus. The game
shows little of this. Camp Guide adds it to the tooltips:

```
Lodestone
Camp: +49 melee attack power
Does not stack with your Blessing of Might        <- orange when you have it; grey otherwise

Basic Campfire
Camp: holds 3 camp objects
Sit near it for 1 minute (or craft without moving): every camp object here adds its buff, for an hour.
Objects placed after you sat count when you sit again.
Camp: objects you have hovered here
  Chair                      +2% critical strike, attacks and spells
  Lodestone                  +49 melee attack power (not with your Blessing of Might)
```

The Camp Benefits buff tooltip gets one line per bonus in it that a class buff of yours overlaps
("Lodestone: does not stack with your Blessing of Might"), or "None of these overlap a class buff
you have." `/kwc` prints all ten first objects with their value at your level.

## What an addon can see

- **No camping API.** Nothing lists the objects around a fire or what a fire holds. Other Forever
  addons that do camping (HastesSuperTweaks' Campfire Helper, NaowhForever) work from the
  player's own auras, as this does.
- **Objects by name.** Hovering a world object fires the Object tooltip (Blizzard's own
  `TooltipDataRules` hooks that type). Camp Guide matches the first line against the object names in
  `Data.lua`, plus "Chair" and "Tent". Campfire Tooltips: Forever reports that some objects show
  only a generic world name; those need the right alias.
- **Only at a camp.** Lines are added only while you have **Campfire Nearby** (1283391), the area
  aura everyone close to a fire gets, so an inn's chair or a city's anvil is left alone. Walking away
  (hovering a camp object without the aura) forgets the hovered list. Entries also expire after 15
  minutes, about one fire. That is the owner's experience in game (2026-11-10); Warcraft Tavern's
  Forever camping guide says "about 10 minutes" with a 5-minute cooldown on placing one, and the
  owner's 15 stands.
- **Auras used:** Camp Benefits 1229741, Welcoming Campfire 1229739 / 1289723 (the sitting minute;
  the second is the "crafting counts too" version), Boosted Rest 1229451 (no Camp Tent rested
  experience for an hour), and each bonus's own aura (Boosted Attack Power 1230164 and so on). All
  ids and names checked in forever.warcraftdb.com's tooltip API (`/api/v1/tooltip/spell/<id>`).
- **Class buffs** are looked up by English aura name (`C_UnitAuras.GetAuraDataBySpellName`), so
  another client language gets no clash lines.

## Where the numbers come from

- **Values by level:** the objects' own tooltips in client 1.60.1.70790, as Endgame Tools lists
  them ("WoW Forever campfire buffs: every object's value by level", updated 2026-11-05). The level
  60 values agree with wowforever.be's guide and Blizzard's Oct 21 table (which stops the Lute at 260
  armor and leaves out the Lodestone).
- **Higher tiers:** objects from skill 140 and 300 replace the profession's first object and keep its
  buff, with a workstation or service on top (Rock Garden keeps the Lodestone's attack power). The
  Engineering bots and the Anarchist's Workbench give no buff.
- **Clashes:** Blizzard says each camp buff is a variant of a class buff and exclusive with it. The
  Camp Chair is listed against Moonkin Aura (Endgame Tools) and Leader of the Pack (other guides).
- **Camp Tent:** rested experience up to 5% of a level. The note says "adds none" when you already
  have 5% of a level rested, and shows Boosted Rest's time while that blocks it.
- **Not used:** a Boosted Spell Power aura (1230552, "up to 23 damage, 44 healing") exists in the
  client data, but no guide ties it to an object yet.

## Settings and commands

Show On Camp Objects (object and campfire tooltips), Notes On Camp Benefits (the buff tooltip).
`/kwc` lists every camp buff at your level, the clashes, and your Camp Benefits time; `/kwc options`.
The hub card shows Camp Benefits' time left, "Sitting by a campfire", "A campfire is nearby", or
"No camp buffs".

## To check in game

- Every object around a fire shows its Camp line. Note any that do not, with the name its tooltip
  shows.
- The campfire's slot count and the hovered list.
- With a class buff on, the matching object says "Does not stack with your ...".
- The Camp Benefits buff gets its clash line or "None of these overlap".
- A value against the game's (your Stamina before and after a First Aid Kit).
