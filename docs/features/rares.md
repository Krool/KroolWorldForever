# Rare Alert

A feature (`rares`) of the Krool World Forever bundle. Tells you when a rare enemy is near and
gives you one button and one key that target it and put a raid marker on it.

## What it does

- **Spots rares** from three events: `NAME_PLATE_UNIT_ADDED` (enemy nameplates must be on),
  `UPDATE_MOUSEOVER_UNIT` and `PLAYER_TARGET_CHANGED`. A unit counts when `UnitClassification`
  is `rare` or `rareelite`, it is alive, you can attack it, and its GUID is a creature. Inside
  instances nothing is checked (unit data is secret there). Any secret value skips the unit.
- **Alerts** once per rare every 5 minutes: the raid warning sound (`SOUNDKIT.RAID_WARNING`), the
  name in the middle of the screen (`RaidNotice_AddMessage`), and a chat line naming your key.
- **The mark button** (`KroolWorldForeverRareButton`, a `SecureActionButtonTemplate`) shows the
  newest rare's marker and name near the top of the screen for 2 minutes after the last sighting.
  Left click, or the key under Key Bindings > AddOns > Krool World (`Bindings.xml`), runs:

      /cleartarget
      /targetexact <name>
      /tm [exists] !<marker>

  Clearing first means a rare out of reach leaves no target, so `/tm` marks nothing rather than
  the wrong mob. `!` keeps a second press from toggling the marker off. Right-click ignores the
  rare; shift-drag moves the button (position saved per account).
- **Ignore list** (`db.ignore`, npc id to name), seeded once with Sewer Beast (3581), the
  crocolisk in the Stormwind canals. `/kwr ignore` takes your target or the last rare seen;
  `/kwr unignore <name or id>`; `/kwr list`.

## Why not mark by itself

Since Midnight 12.0 `SetRaidTarget` is protected (`HasRestrictions` in Forever's API docs at
70790; the wiki's patch history: "Protected"). Addon code cannot mark; retail auto-mark addons
dropped the feature. A secure button's `macrotext` still runs (`SECURE_ACTIONS.macro` calls
`C_Macro.RunMacroText`, restricted to secure code, which the button is), so the mark comes from
the player's own click or key press. That keeps the bundle's advice-only rule: nothing happens
without the player.

Secure frames lock in combat: their attributes, show and hide cannot change. A rare found in
combat gets the alert; the button keeps its previous macro (or none) and updates on
`PLAYER_REGEN_ENABLED`. The button is created on the first sighting out of combat, so no secure
frame exists until it is needed.

## Limits

- **Unverified in-game (0.7.0):** that the click and key run the macro on Forever, and that
  `/targetexact` reaches a rare at nameplate range. Try `/kwr test`, then a real rare.
- Nameplate range limits how early a rare is seen; Forever has no vignettes (RareScanner notes the
  same). Mouseover and target catch the rest.
- One rare at a time: the newest sighting takes the button.
- `macrotext` is capped at 255 characters and cannot `/click` other macro buttons; ours is short
  and does not.

## Others on Forever (2026-11-05)

RareScanner (dedicated Forever build, Nov 5; alert button and a target macro you press) and
SilverDragon (Forever file, Oct 24; click-to-target popup, sounds) are the leading rare scanners
on CurseForge's Forever list. Neither page mentions raid markers. Rare Alert's sound and screen
message can be turned off to run beside them.

## Settings and commands

Options (account-wide): Play A Sound, Show A Screen Message, Chat Message, Show The Mark Button
(the key works either way), Raid Marker (1 to 8, default 8 skull). Commands: `/kwr`
(`/rarealert`) `ignore`, `unignore <name or id>`, `list`, `test`, `options`.

## Tests

`tools/test/rares/`: detection per event, what stays quiet (normal, elite, dead, friendly,
secret, pets, instances, ignored, the canal crocolisk), the button's macro, marker and icon, the
2-minute timeout, combat (alert, no blocked protected call, update after combat), the ignore list
from right-click and slash, options, the key name in chat, and `/kw rares off`.
