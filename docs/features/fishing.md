# One-Button Fishing (`fishing`)

Owner's request, 2026-11-12: one button fishing, and maybe detect the equipped fishing pole.
Approved like Rare Alert: every cast and reel comes from the player's own key or click; the addon
only re-points bindings, and only out of combat.

## What it does

- **Key Bindings > AddOns > Krool World > "Fish: Cast Or Reel In"**: a `CLICK KroolWorldForeverFishButton:LeftButton`
  binding on a secure button (`type1 = "spell"`, `useOnKeyDown = true`: it acts on the press whatever `ActionButtonUseKeyDown` says, so a release never recasts). `spell1` is the highest known id of
  7620, 7731, 7732, 18248, 33095, 51294, 88868, 110410, 131474, 158743 (`C_SpellBook.IsSpellKnown`),
  rechecked on `SPELLS_CHANGED`. The key works with or without a pole; the game refuses the cast.
- **Reeling in.** On `UNIT_SPELLCAST_CHANNEL_START` (player, a fishing id) the addon sets
  `SoftTargetInteract 3`, `SoftTargetInteractArc 2`, `SoftTargetInteractRange 60` (remembering the
  old values) and overrides every key bound to the fishing binding with `INTERACTTARGET`, owned by
  a plain frame (`KroolWorldForeverFishReel`). After `..._CHANNEL_STOP` the keys keep `INTERACTTARGET`
  until the catch's loot window closes (`LOOT_CLOSED`), or 0.3 s when none opens, so pressing the key
  over the loot does not cast a new line (0.18.0). Then the overrides are cleared and the CVars put
  back, unless the player changed one meanwhile (then theirs stays). The value compared is the one
  the client reads back after the set. Combat defers the clearing to `PLAYER_REGEN_ENABLED`. Also
  restored on `PLAYER_LOGOUT` and when the feature is off. The held originals live in the saved
  variables (`db.held`), so a reload, crash or logout in combat with the line out is put right at the
  next load.
- **Double right-click** (option "Double Right-Click To Fish", default on), only with a fishing pole
  in the main hand (`GetInventoryItemID` + `C_Item.GetItemInfoInstant` subclass
  `Enum.ItemWeaponSubclass.Fishingpole`). A second right-button down 0.04 to 0.4 s after the first,
  with both clicks over the game world (`GetMouseFoci`; a click a window takes never reaches a
  binding), the left button up, out of combat, no loot window, and not moving, mounted, flying, falling,
  swimming, stealthed, in a vehicle, and with full control:
  - not fishing: `BUTTON2` is overridden to click the fish button; a `SecureHandlerWrapScript`
    PostClick snippet clears it on the click's press. One the click never spent is cleared 0.3 s after
    the right button comes up (or when combat ends), so it can never wait for a later right-click;
  - already fishing: `BUTTON2` -> `INTERACTTARGET` until the right button comes up.
  The click override is owned by the button itself (the snippet's `ClearBindings` needs that), the
  reel keys by the separate frame.
- Never: auto-loot, gear swaps, lures, sound or nameplate CVars.

## Provenance

Mechanics from BetterFishing (third party, runs on Forever); code is a fresh write. Its Lua-binding
"arm, then cast" key is not used: ours is a CLICK binding and casts on the first press.

Icon `Interface\Icons\Trade_Fishing`: the file name appears in the Forever addon Spoken_Quests
(`UI/QuestsTab.lua`, profession icon table, skill line 101). Not confirmed in Blizzard's forever
source from here (the search was not reachable); the standard Blizzard icon, and a bad path would
show a green square on the hub card only.

## Only testable in game

Whether `INTERACTTARGET` actually reels in at the bobber with these CVars (BetterFishing says yes),
the key-down/key-up behaviour of the snippet, `GLOBAL_MOUSE_*` payloads on Forever, that
`GetMouseFoci()` reports `WorldFrame` (or nothing) over the world, and whether
`IsFlying` needs BetterFishing's Dragonriding aura special case on Forever.
