# WoWForeverMods

Ships one addon, **Krool World Forever** (`KroolWorldForever/`), for World of Warcraft: Forever
(launch 2026-11-04): a bundle of small features, each behind its own Enabled switch. Same shape as
the owner's Valheim mod KroolWorldUI. Research lives in `docs/`; read `docs/02-addon-platform.md`
before writing addon code.

## Platform facts (verified 2026-10-20 on beta 1.60.1.70450; live rechecked 2026-11-05 and 2026-11-07)

- Forever is a **Mainline** game type (same client/API as Midnight 12.1.5), NOT Classic Era. Use
  retail docs and the `forever` branch of Gethe/wow-ui-source.
- Midnight addon restrictions apply: **secret values** (combo points, threat, combat log, some chat,
  all unit tooltip data inside instances). Never compare or do math on a value that may be secret;
  check `issecretvalue` first. That includes boolean tests (`if x`, `x and y or z`): **UNIT_AURA's
  `updateInfo.isFullUpdate` is secret inside instances** (seen in the Deadmines, 2026-11-09). Aura
  reads there error ("Auras cannot be accessed when secret while tainted"): gate every aura read on
  `root.AurasSecret()` (`C_Secrets.ShouldAurasBeSecret`).
- `## Interface: 16001`, TOC `KroolWorldForever_Forever.toc`, detect with
  `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18).
- Creature GUIDs: the NPC id is the 6th field and reads fine in-game (stress test 2026-10-21:
  `Creature-0-6834-0-2-299-5CD49D4332` = Diseased Young Wolf). The bundle loaded with zero Lua
  errors there, and `_Forever.toc` is picked up.
- The client has per-addon Lua resource caps (`LimitedLuaResources`: 500 timers, 10000 frames, 5000
  FontStrings per addon), off (`Enabled = false`) during the stress test. Keep tickers few.
- Fog cannot be reduced: `volumeFog 0` reverts since the Sept 24 beta, and the stress test
  (2026-10-21) showed no lasting change from `ffxGlow`, horizon/farclip, `volumeFogLevel` or
  Compute Effects. No fog feature. See docs/07.
- Install folder is `World of Warcraft\_forever_`, Battle.net product `wowf` (confirmed 2026-10-20).
  Live launched (2026-11-04) on 1.60.1.70790. **Live is now 70888 (2026-11-10, the installed
  `.build.info`), Interface still 16001** (the bundle loads on it). The allowlist is built from
  wow-ui-source `forever` at 70888 (it tracks `wowf` since Nov 2); 70840, 70862 and 70888 changed
  no function, event or enum. Still no `WOW_PROJECT_FOREVER`.
- **Protected calls need a click.** `C_UI.Reload` (and anything else hardware-event restricted) is
  blocked with `ADDON_ACTION_BLOCKED` from a timer or event handler; the API docs carry no flag for
  it, so the lint cannot see it. The Setups test stubs model this (`HardwareDepth`, `BlockedCalls`).
  `SetRaidTarget` is protected outright (secure code only): mark through a
  `SecureActionButtonTemplate` macro (Rare Alert), whose attributes can change only out of combat.

## Bundle rules

- **One folder per feature** in `KroolWorldForever/Features/<Name>/`. Every file starts
  `local _, root = ...` / `local ns = root.Feature("<key>")`. The contract (title, description,
  options, slash, OnLoad/OnEnable/OnDisable/OnOptionChanged, ns:RegisterEvent) is documented at
  the top of `Core/Registry.lua`. Add the files to the TOC before `Core\Hub.lua` and `Core\Init.lua`.
  The `/kw` hub (`Core/Hub.lua`) shows a card per feature from `ns.icon`, `ns.blurb` and
  `ns.HubStatus()`; give a new feature all three. Feature windows use `root.UI` (`Core/Widgets.lua`);
  Auctionator prices and money text come from `root.AuctionPrice` / `root.Money` (`Core/Prices.lua`);
  a price's age from `root.AuctionAge` (mark it old with `root.AuctionStale`, over 3 days), and a
  refresh after each scan from `root.OnAuctionPrices`.
- **Polish comes from the kit** (0.12.0): `UI.Window`/`UI.Polish` (open animation and sounds),
  `UI.Toast` for "done", `UI.Hover`/`UI.Selected`/`UI.Divider`/`UI.Empty`, `UI.FadeIn`/`Flash`/
  `Pop`/`Pulse`, `UI.Sound`, inline `UI.ItemIcon`/`InlineAtlas`. Animations are AnimationGroups
  only (no OnUpdate, no timers). A missing texture shows as a green square: use only atlases in
  `UI.ATLAS` or ones you prove in the forever atlas list and Blizzard's forever code, and note where.
- **Test stubs chain tooltip post-calls** like the client (every feature's hook runs), so a new
  tooltip feature must leave other features' tooltips alone and survive their fixture items.
- **No game calls at file scope** in feature files. `tools/settings-doc.js` and every test suite
  load all features outside the client. Do the work in OnLoad/OnEnable.
- **Settings come from `ns.options`.** The panel (`Core/Settings.lua`) is generic. Never hand-build
  Settings UI in a feature. Labels are Title Case and player-facing; the tooltip is the help text.
  Setups saves and applies every declared option automatically ("Krool World Settings" part), so:
  keep player choices in `ns.options` and learned data or caches out of them; change an option
  in code with `root.SetOption(F, key, value)`, never by writing `F.db` directly (it keeps the panel
  and `OnOptionChanged` in sync); a new option `type` needs a case in Setups' `Fit()`.
- **Tooltip hooks cannot be removed.** Register once in OnEnable and check `ns.enabled` inside.
- **Advice only.** Features never delete, sell, loot or click for the player. Any action needs the
  owner's explicit OK. The one approved exception (2026-10-21) is **Setups**: it changes bars,
  bindings, macros, layouts, CVars and the addon list, only out of combat, with an undo snapshot
  taken first, and either on a confirmed click or (owner's request) automatically on a brand-new
  character's first login when the player has marked a setup "Use For New Characters". Brand-new
  means level 1 with zero XP, not merely "not seen by the addon yet" (that is the picker only). It
  may reload the UI by itself after a clicked apply that needs it (option, default on); the
  automatic apply opens the window on its result with Reload Now instead. Keep those guards.
  Rare Alert (owner's request, 2026-11-05) is not an exception: its target-and-mark runs only from
  the player's click or key on the secure button; the addon only points the button at the rare.
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
- Most suites' stub widgets return a no-op function for ANY unset key, so `frame.myField` reads
  truthy under test. Check fields with `type(x) == "table"`, or use a stub that returns nil for
  lowercase keys (the skillup suite does).
- Quest data comes from QuestieDB's public `LibQuestieDB`/`QuestDB`/`ItemDB` globals
  (github.com/Questie/QuestieDB docs/api.md). Numeric fields read 0, not nil. Race masks exceed
  32 bits: use arithmetic, not `bit.band`.
- **In-game errors:** the dev install (`_forever_\Interface\AddOns`) has !BugGrabber and BugSack.
  After the owner `/reload`s, `node tools\bugs.js [filter]` prints the latest session's errors with
  stacks (`--all` for every session, `--locals` for locals). Read it before guessing at a bug report.
  BugSack never sees the bundle's own errors (every handler is caught), so bugs.js also prints the
  bundle's log (`KroolWorldForeverDB.errors`, `/kw errors` in game). Wrap feature code in
  `root.Try(F, where, fn, ...)` (prints once per session) or `root.TryQuiet` (tooltips: log only),
  not a bare `pcall` that drops the error; bare `pcall` is for probing an API.

## Releases (same rules as KroolWorldUI)

- **Every change to the addon gets a new version and a commit.** Patch for fixes, minor for a new
  feature. Write the `## x.y.z` CHANGELOG section, then `scripts\release.ps1 -Version x.y.z`
  (`-Publish` once project ids and tokens exist). It syncs the TOC version, runs the tests,
  regenerates the README settings tables, builds `dist\KroolWorldForever-x.y.z.zip`, commits only
  TOC/CHANGELOG/README, tags `vx.y.z`, and pushes. Never ship two builds under one version.
- The public download is a GitHub release per tag with the dist zip attached
  (`gh release create vx.y.z dist\KroolWorldForever-x.y.z.zip`); release.ps1 does not do this yet.
  The README links `releases/latest`. `dist/` is git-ignored.
- `scripts\publish.ps1` (CurseForge + Wago) is UNTESTED until the projects exist. Ids go in the
  TOC (`X-Curse-Project-ID`, `X-Wago-ID`); tokens are the user env vars `CF_API_KEY` and
  `WAGO_API_TOKEN`. Never write them to a file or echo them.
- Commit with `git commit -F <file>`: PowerShell 5.1 mangles embedded quotes in native arguments.
- Stage only paths you touched (shared tree; never `git add -A`).

## Layout

- `KroolWorldForever/` shipped addon: `Core/` registry, settings, widgets, hub, lifecycle; `Features/`
  one folder each; `Bindings.xml` (Rare Alert's key, loads by itself, not in the TOC).
- `tools/test/` test runner + suites; `tools/forever-api/` lint; `tools/killvalue-data/` the cmangos
  classic-db generators (`classicdb.js` reader; `gen-data.js` Kill Value loot, `gen-disenchant.js`
  Disenchant Value tables); `tools/skillup-data/gen-skillup.js` Skill-Up Odds recipe thresholds from
  wago.tools `SkillLineAbility` (regenerate when a build changes recipes); `tools/settings-doc.js`
  README settings tables.
- Skill-up chances are server-side and unpublished. Skill-Up Odds uses the straight line (yellow 100%
  to grey 0%) scaled by the account's measured crafts (owner's call 2026-11-09: 174 crafts fit it);
  the per-range counts stay as the check. Change the model only on new data; see docs/features/skillup.md.
- `scripts/` link-addon (dev junction), build, release, publish. `template/HelloForever` minimal skeleton.
- Lint/format config: `.luacheckrc`, `stylua.toml` (tabs, Lua51).
