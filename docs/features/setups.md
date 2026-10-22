# Setups (feature)

**Copy one character's setup to another.** Saves action bars, keybindings, macros, the Edit Mode
layout, interface settings and the addon list, and applies any of them to the character you are on.

`/kws` (or `/kwf setups`, or the button on the Setups settings page) opens the window:

- **Left:** every saved setup on this PC, named ones first, then one auto snapshot per character.
  The auto snapshot refreshes 8 seconds after login, when the window opens, and 10 seconds after
  you change bars, keybindings, macros, Edit Mode or settings. Never at logout: by then the client
  has emptied the bars and reset Edit Mode (found on the stress test, fixed in 0.2.1).
- **Right:** what the selected setup holds, a checkbox per part, and the actions:
  - **Apply To <character>**: asks first, keeps an undo, then reports what it could not restore.
  - **Undo Last Apply**: puts the character back the way it was before the last apply (one level).
  - **Save Current As New**, **Overwrite With Current**, **Rename**, **Delete**.
  - **Use For New Characters**: the setup the new-character picker preselects.
- **New characters:** with a setup marked **Use For New Characters**, a brand-new character gets it
  about 8 seconds after its first login, then the UI reloads (option **Apply The Default Setup
  Automatically**, on by default). Without a default, or with that option off, the window opens as a
  picker instead. **Not Now** asks again next login; **Don't Ask Again** stops.
- **Reload:** Edit Mode and the addon list need a UI reload. Applying reloads by itself and prints
  the report again after it (option **Reload Automatically After Apply**, on by default).

Slash: `/kws save [name]`, `/kws list`, `/kws undo`.

## What each part does

| Part | Saved | Applied |
|---|---|---|
| Action Bars | Every slot 1-180: spell (id and name), item, macro (by name), mount; and which of Action Bars 2-8 are switched on | Spells by id, then by name (another rank). A slot whose action this character cannot use keeps what it has. Slots the setup leaves empty are cleared (option). Flyouts and other types are reported, not placed. |
| Keybindings | Every bound command, both keys | Full replace, saved per character (option) or for the account |
| Macros | Account and character macros | Missing ones are created; one with the same name is kept as is; full macro slots are reported |
| Edit Mode Layout | The active layout (or which built-in one: Modern or Classic), including unit frame options such as the player portrait; and Edit Mode's own checkboxes (show target and focus, cast bar, party frames, pet frame, grid, snap...) | Added as a new character layout with a unique name and made active; refused when the character has 5 layouts. Finishes after a UI reload. |
| Interface Settings | Server-stored CVars changed from default; never secure, locked or read-only ones | Set, and server-stored ones the setup left at default are reset. Graphics and sound are local (Config.wtf) and not touched. |
| Addon List | Which addons are on for the character | Turned on/off for this character; never turns itself off; missing addons listed. Finishes after a reload. |
| Krool World Settings | Every bundle feature's Enabled switch and declared options (Kill Value, Quest Trash, Setups...). A feature's new options are included automatically. Learned data is not. | Set through the settings panel's own setting objects, so the panel and each feature react at once. Slider values are clamped to the current range; options this version does not have are skipped and counted. Never turns Setups itself off. These settings are account-wide today, so this part is a backup/restore until some become per character. |

Apply never runs in combat or while the cursor holds something. Undo restores bars, bindings,
settings, addons and switches Edit Mode back; macros it created stay (it never edits existing ones).

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
- **Classic or HD character models** (part of Forever's first-login experience preset) cannot be
  copied: the client has a setter (`C_GameRules.SetSDHDToggleValue`) but no way to read the value.
  The preset's other choices (one bag, quest markers, UI layout) are captured as settings and layout.
- **Setups' own options** are never part of a setup, so applying an old setup cannot switch them.
- Spells the character has not learned stay off the bars until it learns them and the setup is applied again.
- **Adding an Edit Mode layout has not been seen working in-game yet** (the stress test only
  exercised switching). Verified by 138 checks against a stubbed client and the Forever API
  allowlist (builds 70245 and 70450). The Edit Mode path mirrors Blizzard's own save
  (`EditModeManagerFrameMixin:MakeNewLayout`) without calling the Edit Mode frame, which would taint it.
