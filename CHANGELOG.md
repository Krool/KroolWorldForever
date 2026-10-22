# Changelog

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
