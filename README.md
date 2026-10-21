# Krool World Forever

**Small quality-of-life features for World of Warcraft: Forever, in one addon.** Each feature has
its own on/off switch, so you keep what you want and turn off the rest.

- **Pick what you want.** Every feature is a page under **Options > AddOns > Krool World Forever**
  with an Enabled switch and its own settings. `/kwf list` shows them all, `/kwf <feature> on|off`
  toggles one, and `/kwf` opens the settings.
- **Advice only.** The addon never deletes, sells or loots anything for you. Setups is the one
  feature that changes your UI, and only when you click Apply (with an undo).
- **Plays by Forever's addon rules.** Nothing reads combat data Blizzard hides from addons. Every
  feature checks for hidden ("secret") values and steps aside instead of erroring.

## At a glance

| Feature | What you get | On by default |
|---|---|---|
| **Quest Trash** | A keep/delete verdict on quest item tooltips, and `/fqt` lists what in your bags and bank you can throw away. Needs QuestieDB. | Yes |
| **Kill Value** | Expected gold per kill on creature tooltips: coins plus each drop's chance times its price. It learns real drop rates from what you loot. | Yes |
| **Setups** | Save a character's bars, keybindings, macros, Edit Mode layout, interface settings and addon list, then apply them to another character from a window (`/kws`). New characters get a picker on first login. | Yes |

## Settings

Generated from the features' own definitions by `tools/settings-doc.js`. Do not edit by hand.

<!-- settings:begin -->
### Quest Trash

Marks quest items you can safely delete on their tooltips. Needs QuestieDB.

On by default: yes. Toggle: `/kwf questtrash on|off`. Commands: `/fqt, /questtrash`.

| Setting | Default | What it does |
|---|---|---|
| Show Verdict on Tooltips | On | Adds a keep or delete line to quest item tooltips. |
| List the Quests Involved | On | Shows up to four quests and their status under the verdict. |

### Kill Value

Adds the expected gold per kill to creature tooltips: coins plus drop table times vendor or Auctionator prices.

On by default: yes. Toggle: `/kwf killvalue on|off`. Commands: `/fkv, /killvalue`.

| Setting | Default | What it does |
|---|---|---|
| Learn From My Loot | On | Records what corpses drop so new or rebalanced creatures get real numbers. |
| Use Vendor Prices | On | Vendor sell price as fallback and floor. |
| Use Auctionator Prices | On | If Auctionator is installed, price drops from the auction house minus the cut. |
| Show Skinning Value | Off | Adds a skinning/gathering line (not part of the total). |
| Show On Friendly Creatures | Off | Also adds the line to creatures you cannot attack. |
| Login Message | On | Prints one line at login. |
| Contributor Lines | 3 (0 to 10) | Top drops listed under the total (0 = none). |
| Auction House Cut % | 5 (0 to 100) | Taken off Auctionator prices. |

### Setups

Save a character's action bars, keybindings, macros, Edit Mode layout, interface settings and addon list, and apply them to another character. /kws opens the window.

On by default: yes. Toggle: `/kwf setups on|off`. Commands: `/kws, /kwsetups`.

| Setting | Default | What it does |
|---|---|---|
| Offer A Setup On New Characters | On | The first time a character logs in, open the Setups window so you can start from a saved setup. Preselects the setup marked for new characters. |
| Auto Snapshot Each Character | On | Keep one automatic setup per character, refreshed after login and shortly after you change bars, keybindings, macros, Edit Mode or settings, so any character can copy any other. |
| Applied Keybindings Are Per Character | On | On: applying a setup saves its keybindings for this character only. Off: for the whole account, which changes every character that uses account keybindings. |
| Clear Bar Slots The Setup Leaves Empty | On | On: an apply makes your bars match the setup exactly. Off: only fills slots, keeping anything already in a slot the setup leaves empty. |
<!-- settings:end -->

## Install

Not published yet. For now, link the folder from this repo (see Development).

Optional companions: **QuestieDB** (required for Quest Trash, comes with Questie) and
**Auctionator** (auction prices for Kill Value; vendor prices are used without it).

## Development

```
.\scripts\link-addon.ps1 -AddOnsPath "<WoW>\<flavor folder>\Interface\AddOns"   # junction for dev
cd tools\test; npm install; npm test                                            # all suites + API lint
.\scripts\build.ps1                                                             # dist\KroolWorldForever-<v>.zip
.\scripts\release.ps1 -Version x.y.z [-Publish]                                 # see CLAUDE.md
```

- `KroolWorldForever/` is the shipped addon: `Core/` (registry, settings panel, lifecycle) and
  `Features/<Name>/` (one folder per feature).
- `tools/test/<feature>/` holds one suite per feature: a stub client plus behavior checks. Each suite
  loads the whole bundle.
- `tools/forever-api/` holds the API allowlist lint. It checks every `C_*` call, event and `Enum`
  against Forever's API docs.
- `tools/killvalue-data/` holds the Kill Value loot data generator (cmangos classic-db).

### Research notes

| File | What it covers |
|---|---|
| [docs/01-game-overview.md](docs/01-game-overview.md) | What the game is, features, timeline, business model |
| [docs/02-addon-platform.md](docs/02-addon-platform.md) | Forever's technical facts: TOC, project ID, API base, restrictions, ecosystem |
| [docs/03-toolchain.md](docs/03-toolchain.md) | Addon anatomy, editor setup, in-game tools, libraries, packaging, addon policy |
| [docs/04-launch-checklist.md](docs/04-launch-checklist.md) | What to verify once the game is installed |
| [docs/05-opportunities.md](docs/05-opportunities.md) | Gaps and addon ideas |
| [docs/06-octowow-port-review.md](docs/06-octowow-port-review.md) | Which OctoWoW (1.12) addons port to Forever |
| [docs/07-fog-control.md](docs/07-fog-control.md) | Fog/weather control: what Blizzard locked, what is left |
| [docs/features/](docs/features) | Per-feature design notes and honest limits |
| [docs/sources.md](docs/sources.md) | Sources with confidence tags |

Nothing here has been run in the live game yet. The game launches Nov 4, 2026. See the launch
checklist.

MIT licensed.
