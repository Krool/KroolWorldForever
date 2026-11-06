# Rare Alert

A feature (`rares`) of the Krool World Forever bundle. Tells you when a rare enemy is near and
gives you one button and one key that target it and put a raid marker on it.

## What it does

- **Spots rares** from three events: `NAME_PLATE_UNIT_ADDED` (enemy nameplates must be on),
  `UPDATE_MOUSEOVER_UNIT` and `PLAYER_TARGET_CHANGED`. A unit counts when `UnitClassification`
  is `rare` or `rareelite`, it is alive, you can attack it, and its GUID is a creature. Inside
  instances nothing is checked (unit data is secret there). Any secret value skips the unit.
- **Alerts** once per spawn (by GUID), and at most once every 5 minutes for the same rare (npc
  id): the raid warning sound (`SOUNDKIT.RAID_WARNING`), the
  name in the middle of the screen (`RaidNotice_AddMessage`), and a chat line naming your key,
  followed by what it is worth while Kill Value is on: `worth about 1g 20s: <best drops>` (Kill
  Value's total and its top three drops by value). The button's tooltip lists the kill value and
  the top four drops with their chance and value.
- **Nameplates.** Nameplates are the only way to notice a rare without touching it: Forever has no
  vignettes. Forever starts with enemy nameplates off (`nameplateShowEnemies` 0) and a 45 yard
  range (`nameplateMaxDistance`), so out of the box only mouseover and target find rares. While
  they are off, the hub card says so and shows a Plates On button, the settings page has Turn On
  Enemy Nameplates, `/kwr nameplates` does the same, and the first login prints a one-time tip.
  Turning on sets `nameplateShowEnemies` 1 and asks for 80 yards; the client keeps what it
  allows, and the chat line reports the range it kept. Only from the player's click or command,
  never in combat. A "spam this key" scan for rares beyond nameplate range (RareScanner's Forever
  macro) was considered and left out at the owner's call (2026-11-05).
- **The mark button** (`KroolWorldForeverRareButton`, a `SecureActionButtonTemplate`) shows the
  newest rare's marker and name near the top of the screen. Left click, or the key under Key
  Bindings > AddOns > Krool World (`Bindings.xml`), runs:

      /cleartarget
      /targetexact <name>
      /tm [exists] !<marker>

  Clearing first means a rare out of reach leaves no target, so `/tm` marks nothing rather than
  the wrong mob. `!` keeps a second press from toggling the marker off. Right-click hides the
  button for that spawn; shift-right-click ignores the rare; shift-drag moves the button (position
  saved per account).
- **When the button goes** (0.10.1; before, it stayed 2 minutes after the last sighting, dead or
  not). Per spawn (`done[guid]`):
  - **Marked:** on `RAID_TARGET_UPDATE`, the rare's token (`UnitTokenFromGUID`) carries your
    marker (`GetRaidTargetIndex`). The button hides; the key stays on the rare until it dies or
    times out, so it still retargets.
  - **Killed:** no death event reaches addons (the combat log is closed), so death is read three
    ways: its nameplate leaves with `UnitIsDead` true (`NAME_PLATE_UNIT_REMOVED`; the token still
    reads during the event, Blizzard's own driver looks it up there), its corpse under your target
    or mouseover, or a look at its token when combat ends (a kill usually leaves the corpse
    targeted). A plate that leaves alive (out of range) changes nothing.
  - **Hidden** by right-click: that spawn stays quiet; a new spawn shows again.
  - **Timed out:** 1 minute after the last sighting (nameplate added, mouseover, target).
  In combat the secure button cannot hide, so it fades (`SetAlpha`, not locked) and hides on
  `PLAYER_REGEN_ENABLED`.
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
(the key works either way), Raid Marker (1 to 8, default 8 skull). Settings page button: Turn On
Enemy Nameplates. Commands: `/kwr` (`/rarealert`) `ignore`, `unignore <name or id>`, `list`,
`test`, `nameplates`, `options`.

## Tests

`tools/test/rares/`: detection per event, what stays quiet (normal, elite, dead, friendly,
secret, pets, instances, ignored, the canal crocolisk), one alert per spawn, the button's macro,
marker and icon, the 1-minute timeout, the button going on a kill (plate, corpse, after combat)
and on your marker, fading in combat, combat (alert, no blocked protected call, update after
combat), right-click hide, the ignore list from shift-right-click and slash, options, the key name
in chat, and `/kw rares off`.
