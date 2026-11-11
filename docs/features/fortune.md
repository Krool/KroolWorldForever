# Sayge's Fortune

Folder: `KroolWorldForever/Features/Fortune/` (key `fortune`, `/sayge`, `/kwsayge`). Added 0.14.0,
the day of Forever's first Darkmoon Faire, after the owner died with a fortune and could not tell
when Sayge would give another. Research: `docs/08-darkmoon-faire.md`.

```
Sayge: Next fortune after 3h 30m more online (1:10 PM if you stay on)     <- on Sayge, and the hub card
His wait is 4 hours online from your last fortune: time logged out does not count, and dying does not end it.

Sayge: your next fortune after 3h 50m more online (1:10 PM if you stay on), even if you die.   <- on the fortune buff
```

## How it works

- **The rule** (client data): a fortune lasts 2 hours and is lost on death; the same cast applies
  Sayge's Carnie Buff (23770), a hidden 4-hour debuff kept through death. The next fortune comes 4
  hours after the last (`ns.BUFF`, `ns.WAIT`).
- **Both timers stop while you are logged out** (the owner's visits, 2026-11-10; fixed in 0.16.1):
  - A Damage fortune was taken at 1:35 AM and the character logged out about 2:45 AM. At the 10 AM
    login the fortune was still on, with its time left unchanged. The old code re-dated it to
    8:51 AM, the start that time left implied.
  - Sayge refused at 12:15 PM and 1:51 PM. That was 10.7 and 12.3 hours after the fortune, but only
    about 3h 20m of play (login and logout times from `Logs\Connection.log`).
  - A wait on the real clock would have ended at 5:35 AM. So the wait is time online on that
    character, not hours on the clock.
  - **Confirmed the same day.** Predicted from the logs: ready about 38 minutes into the next
    session. Stone entered the world at 3:39:50 PM. Sayge refused at 3:40, 3:57 and 4:08:56 PM, about
    231 minutes online. He offered at 4:17:11 PM, 239.7 minutes online, which is 4 hours to within the
    login timestamps. 0.16.1 recorded that fortune with `left` 14400 and saved 14396 at the logout
    4 seconds later.
- **The hidden debuff cannot be read.** The owner's check (2026-11-09:
  `C_UnitAuras.GetPlayerAuraBySpellID(23770)`) printed nothing. It is not proof, since the time of
  that fortune is unknown, but it matches the 9.2.5 change that hid hidden auras from addons.
- **So it counts the wait itself.** Each record keeps `left` (seconds of wait) as of `at` (real
  clock):
  - For the logged-in character, `left` runs down. `PLAYER_LOGOUT` (and turning the feature off)
    saves it, and the next login carries on from there (`ns.Resume`), so time away does not count.
  - Other characters' waits stand still.
  - While the fortune is on you, its own time left sets the wait exactly: 4 hours minus the
    fortune's time used.
  - A fortune with more time left than the count allows is a new one.
  - Records from 0.16.0 and before (`got` only) get the old clock guess. A refusal after that guess
    marks them turned away.
- **The visible fortune is read** on `UNIT_AURA` (a fortune id among the added auras, or a full
  update), on `PLAYER_ENTERING_WORLD` and on enable, from the 16 fortune ids
  (`C_UnitAuras.GetPlayerAuraBySpellID`: the eight classic spells and Forever's eight copies,
  1304767-1304782). Given = `time()` minus the fortune's time used.
- **One record per character** (`ns.db.chars["Name-Realm"]`): `got`, `spell`, `kind`, `left`,
  `at`, `lost`, `offered`, `refused`, `turnedAway`.
- **Lost early**: the removal of the aura instance it saw (`removedAuraInstanceIDs`), or
  `PLAYER_DEAD` with the fortune gone (outside instances, where a secret read is not a loss),
  before its 2 hours: `rec.lost`, and a chat line with the next fortune's time (option). Running
  out at 2 hours says nothing.
- **Ready reminder**: one `C_Timer.After` per fortune, to the end of the 4 hours (option).
- **Sayge's answers** come from `GOSSIP_SHOW` with Sayge as the npc (14822 in the GUID):
  - An option naming "fortune" means offered.
  - No options at all means turned away. His "Alas... I am sorry to say I cannot currently give you
    your fortune" page has none.
  - No options with the fortune on you is his "Here is your fortune" page, so it counts as unknown,
    like anything else.
  - Each talk is logged (`ns.db.visits`, last 50): time, the fortune, the count, options, verdict and
    his first 160 characters.
  - Offered sets the count to zero ("ready"). Turned away after the count ran out shows "Sayge
    turned you away at ...".
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
- That the online count is right. The visits log keeps `left` beside each answer: a refusal with
  `left` at 0, or an offer with `left` well above 0, means the count is off.
