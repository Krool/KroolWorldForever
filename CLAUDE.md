# WoWForeverMods

Ships one addon, **Krool World Forever** (`KroolWorldForever/`), for World of Warcraft: Forever
(launch 2026-11-04): a bundle of small features, each behind its own Enabled switch. Same shape as
the owner's Valheim mod KroolWorldUI. Research lives in `docs/`; read `docs/02-addon-platform.md`
before writing addon code.

## Platform facts (verified 2026-10-20, beta 1.60.1.70450)

- Forever is a **Mainline** game type (same client/API as Midnight 12.1.5), NOT Classic Era. Use
  retail docs and the `forever` branch of Gethe/wow-ui-source.
- Midnight addon restrictions apply: **secret values** (combo points, threat, combat log, some chat,
  all unit tooltip data inside instances). Never compare or do math on a value that may be secret;
  check `issecretvalue` first.
- `## Interface: 16001`, TOC `KroolWorldForever_Forever.toc`, detect with
  `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18).
- Creature GUIDs: the NPC id is the 6th field and reads fine in-game (stress test 2026-10-21:
  `Creature-0-6834-0-2-299-5CD49D4332` = Diseased Young Wolf). The bundle loaded with zero Lua
  errors there, and `_Forever.toc` is picked up.
- The client has per-addon Lua resource caps (`LimitedLuaResources`: 500 timers, 10000 frames, 5000
  FontStrings per addon), off (`Enabled = false`) during the stress test. Keep tickers few.
- `volumeFog 0` reverts since the Sept 24 beta (Blizzard removed the fog disable). See docs/07.
- Install folder is `World of Warcraft\_forever_`, Battle.net product `wowf` (confirmed 2026-10-20).
  The stress test serves build 1.60.1.70245, older than the 70450 allowlist; the bundle lints clean
  against both. The live Interface number is unconfirmed: see `docs/04-launch-checklist.md`.

## Bundle rules

- **One folder per feature** in `KroolWorldForever/Features/<Name>/`. Every file starts
  `local _, root = ...` / `local ns = root.Feature("<key>")`. The contract (title, description,
  options, slash, OnLoad/OnEnable/OnDisable/OnOptionChanged, ns:RegisterEvent) is documented at
  the top of `Core/Registry.lua`. Add the files to the TOC before `Core\Init.lua`.
- **No game calls at file scope** in feature files. `tools/settings-doc.js` and every test suite
  load all features outside the client. Do the work in OnLoad/OnEnable.
- **Settings come from `ns.options`.** The panel (`Core/Settings.lua`) is generic. Never hand-build
  Settings UI in a feature. Labels are Title Case and player-facing; the tooltip is the help text.
- **Tooltip hooks cannot be removed.** Register once in OnEnable and check `ns.enabled` inside.
- **Advice only.** Features never delete, sell, loot or click for the player. Any action needs the
  owner's explicit OK.
- **Never let an error reach the client.** Tooltip and event work runs under pcall (the core
  dispatcher already wraps events).
- Saved data: `KroolWorldForeverDB.features.<key>` is the feature's slice (`ns.db`). Option values
  live directly on it.

## Tests and lint

- `cd tools\test; npm test` runs one fengari suite per folder (`tools/test/<feature>/stubs.lua` +
  `test.lua`). Each suite loads the whole bundle in TOC order. Then `tools/forever-api/api-lint.js`
  rejects any `C_*` call, event or `Enum` not in Forever's API docs. Verify an API by grepping
  `tools/forever-api/forever-api.json` before using it. Regenerate the allowlist with
  `build-allowlist.js` when a new build drops.
- A new feature gets its own suite folder, including a check that `/kwf <key> off` silences it.
- Quest data comes from QuestieDB's public `LibQuestieDB`/`QuestDB`/`ItemDB` globals
  (github.com/Questie/QuestieDB docs/api.md). Numeric fields read 0, not nil. Race masks exceed
  32 bits: use arithmetic, not `bit.band`.
- **In-game errors:** the dev install (`_forever_\Interface\AddOns`) has !BugGrabber and BugSack.
  After the owner `/reload`s, `node tools\bugs.js [filter]` prints the latest session's errors with
  stacks (`--all` for every session, `--locals` for locals). Read it before guessing at a bug report.

## Releases (same rules as KroolWorldUI)

- **Every change to the addon gets a new version and a commit.** Patch for fixes, minor for a new
  feature. Write the `## x.y.z` CHANGELOG section, then `scripts\release.ps1 -Version x.y.z`
  (`-Publish` once project ids and tokens exist). It syncs the TOC version, runs the tests,
  regenerates the README settings tables, builds `dist\KroolWorldForever-x.y.z.zip`, commits only
  TOC/CHANGELOG/README, tags `vx.y.z`, and pushes. Never ship two builds under one version.
- `scripts\publish.ps1` (CurseForge + Wago) is UNTESTED until the projects exist. Ids go in the
  TOC (`X-Curse-Project-ID`, `X-Wago-ID`); tokens are the user env vars `CF_API_KEY` and
  `WAGO_API_TOKEN`. Never write them to a file or echo them.
- Commit with `git commit -F <file>`: PowerShell 5.1 mangles embedded quotes in native arguments.
- Stage only paths you touched (shared tree; never `git add -A`).

## Layout

- `KroolWorldForever/` shipped addon: `Core/` registry, settings, lifecycle; `Features/` one folder each.
- `tools/test/` test runner + suites; `tools/forever-api/` lint; `tools/killvalue-data/` loot data
  generator (cmangos classic-db); `tools/settings-doc.js` README settings tables.
- `scripts/` link-addon (dev junction), build, release, publish. `template/HelloForever` minimal skeleton.
- Lint/format config: `.luacheckrc`, `stylua.toml` (tabs, Lua51).
