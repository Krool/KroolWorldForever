# Setups (feature)

**Copy one character's setup to another.** Saves action bars, keybindings, macros, the Edit Mode
layout, interface settings and the addon list, and applies any of them to the character you are on.

`/kws` (or `/kwf setups`, or the button on the Setups settings page) opens the window:

- **Left:** every saved setup on this PC, named ones first, then one auto snapshot per character.
- **Right:** what the selected setup holds, a checkbox per part, and the actions:
  - **Apply To <character>**: asks first, keeps an undo, then reports what it could not restore.
  - **Undo Last Apply**: puts the character back the way it was before the last apply (one level).
  - **Save Current As New**, **Overwrite With Current**, **Rename**, **Delete**.
  - **Use For New Characters**: the setup the new-character picker preselects.
- **New characters:** the first time a character logs in and other setups exist, the window opens
  with the default preselected. **Not Now** asks again next login; **Don't Ask Again** stops.

Slash: `/kws save [name]`, `/kws list`, `/kws undo`.

## What each part does

| Part | Saved | Applied |
|---|---|---|
| Action Bars | Every slot 1-180: spell (id and name), item, macro (by name), mount | Spells by id, then by name (another rank). A slot whose action this character cannot use keeps what it has. Slots the setup leaves empty are cleared (option). Flyouts and other types are reported, not placed. |
| Keybindings | Every bound command, both keys | Full replace, saved per character (option) or for the account |
| Macros | Account and character macros | Missing ones are created; one with the same name is kept as is; full macro slots are reported |
| Edit Mode Layout | The active layout (or which built-in one) | Added as a new character layout with a unique name and made active; refused when the character has 5 layouts. Finishes after a UI reload. |
| Interface Settings | Server-stored CVars changed from default; never secure, locked or read-only ones | Set, and server-stored ones the setup left at default are reset. Graphics and sound are local (Config.wtf) and not touched. |
| Addon List | Which addons are on for the character | Turned on/off for this character; never turns itself off; missing addons listed. Finishes after a reload. |

Apply never runs in combat or while the cursor holds something. Undo restores bars, bindings,
settings, addons and switches Edit Mode back; macros it created stay (it never edits existing ones).

## Honest limits

- **Other addons' per-character settings** (Questie, Auctionator profiles) are out of reach: the game
  only loads an addon's per-character data for that addon. Use their own profile options.
- **Chat windows** are not copied yet.
- Spells the character has not learned stay off the bars until it learns them and the setup is applied again.
- **Not yet run in the live game.** Verified by 100 checks against a stubbed client and the Forever
  API allowlist (builds 70245 and 70450). The Edit Mode path mirrors Blizzard's own save
  (`EditModeManagerFrameMixin:MakeNewLayout`) without calling the Edit Mode frame, which would taint it.
