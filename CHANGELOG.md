# Changelog

## 0.11.0

- **Skill-Up Odds** (new): the real chance a craft gives a skill point, and the cheapest way to your
  next one. The game shows only three skill-up arrows, and the chance behind them is rolled on
  Blizzard's servers and was never published, so Skill-Up Odds measures it: every craft on every
  character of your account records your skill before it and the points it gave, pooled by where
  your skill sat between the recipe's yellow and grey (ten ranges). Each recipe in the crafting
  window shows the measured chance beside its arrow once its range has ten crafts (?% until then);
  hover it for the crafts behind it, the likely span, the yellow, green and grey skills, and what a
  craft and a point cost. Orange shows 100% and grey 0%, the game's rule, measured as well.
- **Next Skill Point panel**, docked beside the crafting window: your learned recipes ranked by the
  gold a point costs on average (a craft's reagents at the cheaper of their auction and vendor
  price, minus what the result sells for, divided by the points a craft gives). Click a row to
  select the recipe. Vendor prices are learned from the merchants you visit. `/kwu` lists the
  measured odds range by range; `/kwu status` says where the numbers come from.
- Recipe thresholds come from Forever's own recipe data (build 1.60.1.70862, 2,544 recipes).

## 0.10.1

- **Rare Alert: the mark button goes when its work is done.** It used to stay two minutes after
  the last sighting, even after the kill. Now it hides once the rare carries your marker (the key
  still retargets it), and goes when the rare dies: seen when its nameplate leaves, on its corpse
  under your target or mouse, or when combat ends. In a fight it fades and hides once combat ends
  (the game locks it in combat). Otherwise it goes a minute after you last saw the rare.
- **Rare Alert: right-click hides the button** for that spawn; it stays quiet even if you see the
  rare again. Shift-right-click now ignores the rare for good (right-click did before).
- **Rare Alert: one alert per spawn.** Seeing the same rare again no longer replays the sound and
  message every 5 minutes; a new spawn still alerts.

- **Camp Guide** (new): what a campfire gives you. Hover a camp object (the chair, the lodestone
  and the rest) for its buff at your level, and whether a class buff you already have covers it:
  "Does not stack with your Blessing of Might". Objects from skill 140 and 300 show the buff they
  keep and what else they do. Hover the campfire for its slot count, how sitting works (a minute,
  crafting counts, objects placed later need another sit) and the objects you have hovered around
  it. The Camp Benefits buff names any bonus in it that one of your class buffs overlaps. `/kwc`
  lists all ten camp buffs at your level. Lines show only while you have Campfire Nearby, so an
  inn's chair is left alone. The game cannot list a fire's objects for an addon: the campfire
  lists the ones you hover.

## 0.9.0

- **Disenchant Value** (new): weapon and armor tooltips (green and up) show what the item is worth
  disenchanted, at Auctionator's prices for its dust, essences and shards, and a Best line:
  disenchant it, sell it at auction, or sell it to a vendor, after the 5% auction cut. Hold Shift
  for each material's chance and price. Bound items skip the auction compare and get the Best line
  only if you can disenchant. The tables are the 1.12 ones: exact for classic items, by quality,
  weapon or armor and item level for Forever's new items. Auctionator's own disenchant line does
  not cover classic-level items on Forever (it loads its retail tables). `/kwd` lists the material
  prices, so you can see which still need an auction scan.

## 0.8.0

- **Rare Alert: turn enemy nameplates on in one click.** Rares are noticed as soon as their
  nameplate shows, but Forever starts with enemy nameplates off (and a 45 yard range), so only
  rares you mouse over or target were found. While they are off, the hub card says so and shows a
  Plates On button; the settings page has Turn On Enemy Nameplates, and `/kwr nameplates` does
  the same. It turns them on and asks for the longest range; chat says the range you got. A
  one-time tip at login points to it.
- **Rare Alert: what a rare is worth.** The alert's chat line is followed by its kill value and
  best drops from Kill Value ("worth about 1g 20s: ..."), and the skull button's tooltip lists the
  kill value and top drops with their chance.
- Hub: a feature without its own window can show one fix-it button on its card.

## 0.7.0

- **`/kw` opens the new Krool World hub** (so does the minimap addon button): one card per feature
  with its icon, what it is doing right now (items you can delete, creatures learned, your
  setups, the last rare), an On switch, and the way in: Open for features with a window, and a
  gear for settings. `/kw settings` opens the settings; `/kwf` still works.
- **Rare Alert** (new): a sound, a screen message and a chat line when a rare enemy is near (from
  its nameplate, your mouseover or your target), once per rare every 5 minutes. A skull button and
  a key (Key Bindings > AddOns > Krool World) target it and mark it with one press; the game lets
  only a click or key press set a marker, so it never marks by itself. Right-click the button to
  ignore a rare; Sewer Beast in the Stormwind canals is ignored out of the box. `/kwr test` shows
  the button to place it (shift-drag). Options for the sound, screen message, chat line, button
  and which marker.
- **Quest Trash window.** `/fqt` opens a window instead of printing to chat: your bag items (and
  bank items while it is open) in Can Delete, Keep and Still Checking, with stack totals and why.
  Hover a row for the item's tooltip and its quests. `/fqt print` keeps the chat list.

## 0.6.1

- **Quest Trash: no stale verdicts after turning it off and on.** While off it does not see
  quests accepted or turned in, and turning it back on kept the verdicts from before, so an item
  from a quest finished in the meantime could still read "keep". Turning it on now rechecks.

## 0.6.0

- **Kill Value: skinning is no longer learned as loot.** Skinning a corpse that had nothing to
  loot opened the skinning window first, and its leather was recorded as that creature's drops,
  which inflated beast values. A window with no coins and only gathering yields (skinning,
  herbalism, mining) is now skipped when you know that profession. A one-time cleanup removes
  the leather already learned and says so at login.
- **Kill Value: your skinning counts in the total.** If you know Skinning (or Herbalism or Mining,
  for creatures gathered that way) with enough skill for the creature, its skinning value is
  added to the total and listed under it. Too low a skill shows "skinning, needs N". New option
  Add My Skinning To The Total (on). Show Skinning Value now covers creatures you cannot skin.
- `/fkv status` shows your gathering skills.
- `/fkv` commands change settings through the settings panel, so the panel stays in sync, and
  `/fkv detail` stops at 10 like the slider.

## 0.5.0

- **Setups: redesigned window.** A card at the top shows the setup, an arrow, and the character it
  goes onto. The list has class icons and levels, grouped into Saved Setups and Characters, with a
  star on the setup used for new characters. Each part has its own icon and row, and the whole row
  is clickable. After an apply the rows show a check, a warning or an X with that part's result;
  hover a row for the details. Click a setup's name to rename it; Update and Delete are icons. Help
  text moved into tooltips.
- **Setups: fixed the blocked reload after a new character's automatic apply.** The game allows a
  UI reload only from a click, so the reload after the automatic apply was blocked with an error,
  and the Edit Mode layout and addon list never finished. Now the window opens on the result with a
  Reload Now button.
- **Setups: automatic apply only on brand-new characters** (level 1, no experience). Before, any
  character the addon had not seen yet counted as new, so an existing character logging in for the
  first time after you marked a default got it applied. Those characters get the picker instead.
- Setups: asks for a reload only when Edit Mode or the addon list actually changed.
- Setups: snapshots filter the game's CVar list once per session instead of on every snapshot.
- `/kws undo` says when a reload is needed.
- API allowlist rebuilt for the live build, 1.60.1.70790 (lint clean).

## 0.4.1

- Removed legacy repeatable-quest ids not in cmangos; doc cleanup.

## 0.4.0

- **Setups: new characters get the default automatically.** With a setup marked Use For New
  Characters, a brand-new character applies it a few seconds after its first login and reloads; no
  picker (option, on by default; off brings the picker back).
- **Setups: reloads by itself** after an apply that needs it (Edit Mode, addon list) and prints the
  report again after the reload (option, on by default).
- **Setups: which action bars are switched on** (Action Bars 2-8) is now part of the Action Bars part.
- **Setups: Edit Mode's own checkboxes** (show target and focus, cast bar, party frames, pet frame,
  grid, snap...) are now part of the Edit Mode part. The window names the built-in layout (Modern or
  Classic).
- Setups' own options are no longer copied by the Krool World Settings part: an old setup could
  switch auto reload or the picker off.

## 0.3.0

- **Setups: Krool World Settings part.** A setup now also holds every bundle feature's Enabled switch
  and settings (Kill Value, Quest Trash, Setups), and applying it restores them. New settings any
  feature adds are included automatically. Learned data such as Kill Value's loot counts is not.
  The settings are account-wide today, so this part works as a backup and restore.
- Core: `root.SetOption` changes a setting the way the settings panel does, so the panel and the
  feature stay in sync.

## 0.2.3

Setups review fixes:

- A name that comes back as a different character (deleted and remade, or a stress-test name reused
  at launch) no longer overwrites the earlier character's snapshot: it is kept as a named setup
  "(earlier character)", and the new character gets the picker. Characters are told apart by GUID.
- Opening the window now refreshes the character's snapshot (a declaration-order bug skipped it).
- Undo can restore bars that were empty; a setup with no keybindings no longer clears yours.
- Interface settings skip game state (tutorial and "seen" flags, collapsed lists, tracked quests,
  "last selected" values): 84 Forever CVars excluded, real preferences kept.
- Edit Mode: refuses while Edit Mode is open, and checks the layout name is valid.
- Apply waits until the character has finished loading. The full report is also printed to chat.
- Closing the new-character picker, or logging in during combat, asks again next login.
- Long setup names no longer wrap in the list.

## 0.2.2

- **Setups:** applying an Edit Mode layout the character already has (for example re-applying its own
  setup) switches to that layout instead of adding a numbered copy.

## 0.2.1

- **Setups fix:** the auto snapshot no longer refreshes at logout. The client has already emptied the
  action bars and reset Edit Mode by then, so 0.2.0 saved empty bars and the built-in layout over
  the real setup. It now refreshes after login, when the window opens, and shortly after you change
  bars, keybindings, macros, Edit Mode or settings.
- An auto refresh that reads empty bars keeps the previously saved bars.
- Applying a setup with no saved bar slots now leaves your bars alone instead of clearing them.

## 0.2.0

- **Setups** (new): save a character's action bars, keybindings, macros, Edit Mode layout,
  interface settings and addon list, and apply them to another character from a window (`/kws`).
  Auto snapshot of every character, a picker on a new character's first login, a default setup for
  new characters, and one-level undo. Refuses in combat; reports anything it could not restore.
- `/kwf <feature>` opens a feature's own window when it has one; its settings page gets an Open button.
- Stress test (2026-10-21): the bundle loads on Forever with no Lua errors; Kill Value reads NPC ids
  and records loot correctly.

## 0.1.0

First bundle build, not yet released or run in the live game.

- **Krool World Forever** bundle: one addon with a settings page per feature, each with an Enabled
  switch. `/kwf` opens settings, `/kwf list` shows features, `/kwf <feature> on|off` toggles one.
- **Quest Trash**: keep/delete verdicts on quest item tooltips, `/fqt` bag and bank scan. Uses
  QuestieDB data and the client's own completed-quest flags.
- **Kill Value**: expected gold per kill on creature tooltips from a 1.12 loot baseline, blended with
  drop rates learned from your own looting. Vendor and Auctionator prices.
