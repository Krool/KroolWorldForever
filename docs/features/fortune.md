# Sayge's Fortune

Folder: `KroolWorldForever/Features/Fortune/` (key `fortune`, `/sayge`, `/kwsayge`). Added 0.14.0,
the day of Forever's first Darkmoon Faire, after the owner died with a fortune and could not tell
when Sayge would give another. Research: `docs/08-darkmoon-faire.md`.

```
Sayge: Next fortune at 1:10 PM (in 3h 30m)                 <- on Sayge, and the hub card
His wait is 4 hours from your last fortune; dying does not end it.

Sayge: your next fortune at 1:10 PM (in 3h 50m), even if you die.   <- on the fortune buff
```

## How it works

- **The rule** (client data, unconfirmed on Forever): a fortune lasts 2 hours and is lost on death;
  the same cast applies Sayge's Carnie Buff (23770), a hidden 4-hour debuff kept through death.
  The next fortune comes 4 hours after the last (`ns.BUFF`, `ns.WAIT`).
- **The hidden debuff cannot be read.** The owner's check (2026-11-09:
  `C_UnitAuras.GetPlayerAuraBySpellID(23770)`) printed nothing. It is not proof, since the time of
  that fortune is unknown, but it matches the 9.2.5 change that hid hidden auras from addons.
- **So it dates the visible fortune.** On `UNIT_AURA` (a fortune id among the added auras, or a full
  update), `PLAYER_ENTERING_WORLD` and on enable, it reads the 16 fortune ids
  (`C_UnitAuras.GetPlayerAuraBySpellID`: the eight classic spells and Forever's eight copies,
  1304767-1304782). Given = `time()` minus (`GetTime()` minus (`expirationTime` minus
  `duration`)). One record per character (`ns.db.chars["Name-Realm"]`: `got`, `spell`, `kind`,
  `lost`, `offered`, `refused`), on the real clock, so it survives death, logout and alts. A record
  within 2 minutes of the stored one is the same fortune.
- **Lost early**: the removal of the aura instance it saw (`removedAuraInstanceIDs`), or
  `PLAYER_DEAD` with the fortune gone (outside instances, where a secret read is not a loss),
  before its 2 hours: `rec.lost`, and a chat line with the next fortune's time (option). Running
  out at 2 hours says nothing.
- **Ready reminder**: one `C_Timer.After` per fortune, to the end of the 4 hours (option).
- **Sayge's answers**: `GOSSIP_SHOW` with Sayge as the npc (14822 in the GUID). An option naming
  "fortune" = offered; no options at all = turned away (1.12's refusal page has none); anything
  else = unknown. Each talk is logged (`ns.db.visits`, last 50: time, the fortune, options, verdict,
  his first 160 characters) to check the 4 hours. Offered after the buff ended overrides the clock
  ("ready"); turned away after the 4 hours shows "Sayge turned you away at ...".
- **States** (`ns.State`): active, waiting, ready, refused, or no record.

## Settings and commands

Show On Sayge And Your Fortune, Tell Me If I Lose It, Tell Me When The Wait Is Over (all on).
`/sayge`: this character's state and last fortune, the rule, other characters with a fortune in
the last 8 days, and the talks with Sayge recorded.

## To check in game

- The hub card and Sayge's tooltip after a fortune; the buff's tooltip line.
- Die with a fortune: the chat line and the time.
- Ask Sayge before the 4 hours are up: does he refuse, and with no options (the "turned away" read)?
  Ask after: is he ready at 4 hours? `/sayge` shows the talks; `ns.db.visits` keeps his words.
- Which spell Forever puts on you (classic id or its 1304xxx copy): `/sayge` names the kind; the
  record keeps the id.
- Whether the wait counts while logged out (log out across the end of a wait, then ask Sayge).
