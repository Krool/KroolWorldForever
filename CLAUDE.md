# WoWForeverMods

Addons for World of Warcraft: Forever (launch 2026-11-04). Research lives in `docs/`; read
`docs/02-addon-platform.md` before writing addon code.

## Hard facts (verified 2026-10-20, beta 1.60.1.70450)

- Forever is a **Mainline** game type (same client/API as Midnight 12.1.5), NOT Classic Era. Use
  retail docs and the `forever` branch of Gethe/wow-ui-source. Classic-era API assumptions are wrong here.
- Midnight addon restrictions apply: **secret values** in combat (combo points, threat, combat log,
  some chat). Never write code that compares or does math on values that may be secret.
- `## Interface: 16001`, TOC file `<Addon>_Forever.toc`, detect with
  `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18). Do not use `WOW_PROJECT_MAINLINE` to mean Forever.
- Creature/pet/object GUIDs are obfuscated (Beta 5). Do not parse them without testing in-game.
- Live install folder and live Interface number are unconfirmed: see `docs/04-launch-checklist.md`.

## Layout

- `addons/<Name>/` real addons (create as needed); `template/HelloForever/` skeleton to copy.
- `scripts/link-addon.ps1` junctions an addon into the game's AddOns folder.
- Lint: `.luacheckrc`; format: `stylua.toml` (tabs, Lua51). Libraries go in `Libs/` (gitignored, via `.pkgmeta`).
- Each addon has `tools/test` (fengari harness: stubbed client, `npm test`). Its test script also runs
  `tools/forever-api/api-lint.js`, which rejects any `C_*` call, event or `Enum` not in Forever's API
  docs. Verify an API by grepping `tools/forever-api/forever-api.json` before using it.
- Quest data comes from QuestieDB's public `LibQuestieDB`/`QuestDB`/`ItemDB` globals (docs/api.md in
  github.com/Questie/QuestieDB). Numeric fields read 0, not nil. Race masks exceed 32 bits.
