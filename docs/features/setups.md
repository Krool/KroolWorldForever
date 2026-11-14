# Setups (feature)

**Copy one character's setup to another.** Saves action bars, keybindings, macros, the Edit Mode
layout, interface settings and the addon list, and applies any of them to the character you are on.

`/kws` (or `/kw setups`, the hub card, or the button on the Setups settings page) opens the window (0.5.0 layout):

- **Banner** under the title: one line saying what to do next, or what just happened.
- **Left:** class icon, name, level and age of every saved setup on this PC, in two groups: **Saved
  Setups**, then **Characters** (one auto snapshot per character). A star marks the setup used for
  new characters. Hover a row for its source and save time. The auto snapshot refreshes 8 seconds
  after login, when the window opens, and 10 seconds after you change bars, keybindings, macros,
  Edit Mode or settings. Never at logout: by then the client has emptied the bars and reset Edit
  Mode (found on the stress test, fixed in 0.2.1).
- **Right, card:** the selected setup, an arrow, then you (class icon, name, level), so the direction
  of the copy is visible. Click the setup's name to rename it. Under the card: the **Use For New
  Characters** star toggle, **Update** (refresh icon: replace the setup with this character) and
  **Delete** (red X). Every icon has a tooltip.
- **Right, What To Copy:** one row per part with its icon, a checkbox and what the setup holds
  ("74 slots", "built-in Classic + 3 options"). The whole row is the click target. A small reload
  icon marks the parts that finish after a UI reload; the tooltip says what the part does. After an
  apply the header turns into **What Changed** and each row shows a green check, a yellow warning
  (something skipped) or a red X (nothing applied) with the part's summary; hovering lists the
  details. The full report also goes to chat.
- **Bottom:** **New Setup** on the left; **Undo** and **Apply To <character>** on the right (Apply
  asks first and keeps an undo). In new-character mode **Not Now** (ask again next login) and
  **Don't Ask Again** take Undo's place.
- **Reload bar:** after an apply that changed Edit Mode or the addon list, a yellow strip with
  **Reload Now** stays until the UI reloads.
- **New characters:** with a setup marked **Use For New Characters**, a brand-new character (level 1
  with no experience and no money, at its first login) gets it about 8 seconds in (option **Apply The Default Setup
  Automatically**, on by default), and the window opens on what changed. A character the addon has
  not seen before but that is not brand-new (the addon was installed later, or the default was chosen
  later) gets the picker instead, never an automatic apply. Without a default, or with that option
  off, the window opens as a picker. Closing it counts as Not Now. The automatic apply skips Krool
  World Settings (they are account-wide); a manual apply keeps that part.
- **Reload:** Edit Mode and the addon list need a UI reload. Apply reloads by itself and prints the
  report again after it (option **Reload Automatically After Apply**, on by default). The automatic
  apply on a new character cannot: it runs from a timer, and the client blocks `C_UI.Reload` outside
  a click (`ADDON_ACTION_BLOCKED`, seen on live 2026-11-04), so the window shows Reload Now instead.

Slash: `/kws save [name]`, `/kws list`, `/kws undo`.

## What each part does

| Part | Saved | Applied |
|---|---|---|
| Action Bars | Every slot 1-180: spell (id and name), item, macro (by name), mount; and which of Action Bars 2-8 are switched on | Spells by id, then by name (another rank). A slot whose action this character cannot use keeps what it has. Slots the setup leaves empty are cleared (option). A setup from another class leaves slots 73-144 (stance, form and override bars) alone. Flyouts and other types are reported, not placed. |
| Keybindings | Every bound command, both keys | Full replace, saved per character (option) or for the account. A character already on its own set always saves there, and the report says which. |
| Macros | Account and character macros | Missing ones are created; one with the same name is kept as is; full macro slots are reported |
| Edit Mode Layout | The active layout (or which built-in one: Modern or Classic), including unit frame options such as the player portrait; and Edit Mode's own checkboxes (show target and focus, cast bar, party frames, pet frame, grid, snap...) | Added as a new character layout with a unique name and made active; refused when the character has 5 layouts. Finishes after a UI reload. The account-wide checkboxes are only put back by Undo, never copied. |
| Interface Settings | Per-character server-stored CVars changed from default (account-wide ones are shared already, so they are not copied); never secure, locked or read-only ones | Set (one the client refuses is counted as refused), and server-stored ones the setup left at default are reset. Graphics and sound are local (Config.wtf) and not touched. |
| Addon List | Which addons are on for the character | Turned on/off for this character; never turns itself off; missing addons listed. Finishes after a reload. |
| Krool World Settings | Every bundle feature's Enabled switch and declared options (Kill Value, Quest Trash, Setups...). A feature's new options are included automatically. Learned data is not. | Set through the settings panel's own setting objects, so the panel and each feature react at once. Slider values are clamped to the current range; options this version does not have are skipped and counted. Never turns Setups itself off. These settings are account-wide today, so this part is a backup/restore until some become per character. |

Apply never runs in combat or while the cursor holds something. Undo restores bars, bindings,
settings, addons and switches Edit Mode back; macros it created stay (it never edits existing ones).

Undo can put back spells, items, macros and mounts. A bar slot holding anything else (an equipment
set, a flyout) is therefore left alone by Apply, whether the setup wants another action there or
wants it empty, and the report counts those slots (0.16.4). `Unrestorable` in `Core.lua` is the
list; a type moves out of it only when `Pickup` learns to restore it.

## Characters are told apart by GUID

A character is keyed by name and realm, plus its GUID. When a name comes back as a different
character (deleted and remade, or a stress-test name reused at launch), its old auto snapshot is
kept as a named setup, "<name> (earlier character)", and the new character gets the picker.

## Interface settings left out on purpose

Server-stored CVars that are game state, not preferences, are never copied or reset: tutorial and
"seen" flags, collapsed lists, tracked quests, "last selected" values, and anything whose help text
says it is internal, serialized or "stores the last". Checked against Forever's full CVar list:
84 excluded, 807 kept.

## Honest limits

- **Account-wide settings and keybindings** apply to every character that uses them. That is how the
  game stores them, not a choice here.
- **Keybindings are a full replace**, including keys for addon commands the setup does not have
  (Undo restores them).

- **Other addons' per-character settings** (Questie, Auctionator profiles) are out of reach: the game
  only loads an addon's per-character data for that addon. Use their own profile options.
- **Chat windows** are not copied yet.
- **Classic or HD character models** (part of Forever's first-login experience preset) are not part
  of a setup. The client can read the choice (`C_GameRules.AccountHasSDEnabled`, account-wide by its
  name) and set it (`C_GameRules.SetSDHDToggleValue`), so this could be added; it is not yet. The
  preset's other choices (one bag, quest markers, UI layout) are captured as settings and layout.
- **Setups' own options** are never part of a setup, so applying an old setup cannot switch them.
- Spells the character has not learned stay off the bars until it learns them and the setup is applied again.
- **Adding an Edit Mode layout has not been seen working in-game yet** (the stress test only
  exercised switching). Verified by 211 checks against a stubbed client and the Forever API
  allowlist (builds 70245, 70450 and live 70790). The stubbed client blocks protected calls made
  outside a click, as the live one does. The Edit Mode path mirrors Blizzard's own save
  (`EditModeManagerFrameMixin:MakeNewLayout`) without calling the Edit Mode frame, which would taint it.
