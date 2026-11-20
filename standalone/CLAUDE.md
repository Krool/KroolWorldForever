# Standalone addons

Every bundle feature also ships as its own addon (owner, 2026-11-14). One source: the bundle's
`KroolWorldForever/`. `tools/standalone/build.js` generates each standalone from it; nothing here is
hand-copied code.

## Files

- `addons.json`: the manifest, one entry per standalone.
  - `key` is the feature's registry key, `folder` is `KW_<Name>`, and `title` is "KW <Title>".
  - `features` lists folders under `KroolWorldForever/Features`. `embedded` lists provider folders carried for their data only: Disenchant for Least Valuable and Quest Reward Value, Kill Value for Rare Alert.
  - `optionalDeps` go in the TOC. `relations` are CurseForge slugs and types.
  - `curseId` stays empty until the project exists.
  - `held: true`: on the owner's install only, left out of every release. See "Held features" in the repo CLAUDE.md. Nothing is held now.
  - Optional fields: `db` (default `<folder>DB`), `slash` (fallback words when the feature declares none, e.g. Quest Reward Value's `/kwq`) and `bindings` (secure button suffixes for Bindings.xml).
- `published.json` is the upload ledger: key -> {hash, version}. `release.ps1` commits it after a `-Publish`.
- `listings/<key>.md`: the CurseForge name, categories, relations, summary and description. Each description ends with `[Donate](https://ko-fi.com/kroolworld)`: labeled Donate, never the platform name. Before that come the named link back to the bundle and the "Found a bug, or want something added?" paragraph, which names the addon's own slash word plus `errors` (`/kw errors` on the bundle).
- `listings/bundle.md`: the bundle's own CurseForge page (project 1804317). Each feature name in its list links that feature's KW addon, and every KW description links back to the bundle. No CurseForge relations between the bundle and the KW addons (2026-11-15): every relation type (required, optional, embedded library, tool, incompatible) misdescribes "the same feature, packaged alone", and the CurseForge app installs required ones.
- `logos/<key>.png`: 512px placeholder logos, the same style as Reagent Uses' logo. The owner may swap them.

## How a standalone behaves

- **Contents.** It gets the Core files from the bundle TOC minus Hub.lua, plus a generated `Core/Identity.lua` (`root.ID.standalone = true`, its own names). It also gets its feature files, any embedded providers, a generated TOC, and Bindings.xml when needed.
- **Startup.** Nothing happens at ADDON_LOADED. At PLAYER_LOGIN it checks `C_AddOns.IsAddOnLoaded("KroolWorldForever")`.
  - If the bundle is loaded, the standalone yields: no saved table, settings, slash or hooks. It prints one line telling the player to disable one of the two.
- **Settings and commands.**
  - It has one Settings category, named after its title.
  - Its slash command is the feature's own (`/fqt`, `/kws`, ...). `settings`, `errors`, `chars`, `track`, `untrack` and `forget` are answered by Core.
  - The compartment click opens the feature's window or its settings.
- **Embedded providers** load their data but never enable or register events, so their learned data (Disenchant "seen", Kill Value loot) is not recorded by the host.
- **Reagent Uses** keeps its old folder `ReagentUses` and `ReagentUsesDB`, so the first users update in place. Its feature's `MigrateSaved` carries the old options over.

## Rules

- Lockstep versions: a release builds every standalone from the tag. `publish.ps1` uploads a standalone only when the SHA-256 of its files (the TOC Version line removed) differs from the ledger.
- A standalone's CurseForge changelog is the CHANGELOG bullets whose bold lead starts with the feature title. Otherwise it is "Shared fixes from Krool World Forever x.y.z.". So start bullets with the feature name: `- **Quest Trash: ...**`.
- Tests live in `tools/standalone/test/` because everything under `tools/test/` runs as a suite. `npm test` runs them:
  - each standalone alone;
  - the collision suite: the bundle plus every standalone in one Lua state, in both load orders;
  - the API lint over `build/standalone`.
- The `family` list in the bundle's `Core/Identity.lua` must equal the bundle plus every manifest folder (a test checks). Setups never toggles a family member.
- Listings are the source for the live pages, which nothing uploads: after a listing changes, set each page's Description (Markdown editor) and General > Summary in the authors console and save. A summary is at most 256 characters. Description and General save separately: save one tab before opening the other, or the console asks to discard. The editor rewrites the Markdown it stores (bare links become named links), so compare by content, not by length.
- Allow Comments (General tab) is on for every project (owner, 2026-11-20): comments and GitHub issues are where players report bugs and ask for features. A new project gets it switched on when it is created.
- CurseForge: every standalone is its own project under the same author, with Ko-fi as the donation method, GitHub source (this repo) and Automatic Packaging off. Check that each uploaded file is tagged Forever 1.60.1.
- A project created minutes ago can refuse its first API upload: 403, errorCode 1006, "You do not have permission to manage files for this project" (KW Boats And Zeppelins, 2026-11-18, about 15 minutes after it was created; a retry a few minutes later went through). By then the bundle is already up, so finish with `scripts\publish.ps1 -Zip dist\KroolWorldForever-<v>.zip -Version <v> -Notes <the CHANGELOG section> -SkipBundle`, which uploads only the standalones still owed, then commit `published.json` as "Record standalone uploads <v>".

## Adding a feature

1. Feature folder, TOC entries and a test suite, as for any bundle feature.
2. A manifest entry, and its folder in `Identity.lua`'s `family`.
3. `listings/<key>.md` and `logos/<key>.png`; create the CurseForge project and put its id in `curseId`. Add the feature, linked to its KW page, to `listings/bundle.md` and paste that description into the bundle's CurseForge page.
4. Release: the bundle and the new standalone ship together.
