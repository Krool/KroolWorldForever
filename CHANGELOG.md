# Changelog

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
