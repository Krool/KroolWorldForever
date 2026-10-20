# Addon dev toolchain (Windows + PowerShell)

Because Forever is Mainline, every retail/Midnight tool and doc applies. Sources in
[sources.md](sources.md).

## 1. Addon anatomy

```
Interface\AddOns\MyAddon\
  MyAddon_Forever.toc     <- metadata + load list (folder name must match the TOC base name)
  Core.lua
  Options.lua
  Libs\                   <- embedded libraries (fetched by the packager, gitignored)
```

### TOC essentials

```toc
## Interface: 16001
## Title: MyAddon
## Notes: Does a thing.
## Author: Krool
## Version: @project-version@
## Category: Interface Enhancements
## IconTexture: Interface\Icons\INV_Misc_QuestionMark
## AddonCompartmentFunc: MyAddon_OnCompartmentClick
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB
## OptionalDeps: Ace3
## X-Curse-Project-ID: 000000
## X-Wago-ID: xxxxxxxx

Core.lua
ForeverOnly.lua [AllowLoadGameType forever]
```

- `## Interface:` takes a comma list for multi-flavor TOCs, e.g. `16001, 120105`.
- `Title`/`Notes` support locale variants (`## Title-deDE:`).
- `Category` groups addons in the AddOn list. `Group` nests sub-addons under a parent.
- `IconTexture`/`IconAtlas` set the AddOn list icon. `AddonCompartmentFunc[OnEnter|OnLeave]` adds
  the addon to the minimap compartment menu (marked on the wiki as Midnight and Forever).
- `LoadOnDemand: 1`, `Dependencies` (`RequiredDeps`), `OptionalDeps`, `LoadWith`, `LoadManagers`.
- `AllowLoadGameType` / `ExcludeLoadGameType`: an unknown type passes, so pair them carefully.
- `OnlyBetaAndPTR`, `DefaultState: disabled`, `LoadSavedVariablesFirst: 1`.
- File-line variables `[Game]`, `[Family]`, `[TextLocale]` and inline conditions work on file lines only
  (12.1.7 blocked them in directives).
- Lines over 1024 chars are truncated. The client reads TOCs only at startup, so **a TOC change or a new
  file needs a full client restart**, not just `/reload`.

### Lua environment

- Lua 5.1, sandboxed (no `io`/`os` file access). Extra globals: `strsplit`, `wipe`, `C_Timer`, etc.
- Each file gets `local addonName, ns = ...` (a private namespace table shared across your files).
- SavedVariables exist starting at `ADDON_LOADED(addonName)`. Never read them at file scope. They are written
  on logout, `/reload` and disconnect. A crash loses changes since the last write.
- Build UI that needs unit/world data on `PLAYER_LOGIN` (Forever beta had `UnitName("player")`
  return "Unknown" earlier).
- XML is for templates/mixins (mirrors Blizzard's FrameXML). Pure-Lua `CreateFrame` is the norm for
  small addons. Libraries load through an `embeds.xml`.

See [template/HelloForever](../template/HelloForever) for a working skeleton of all of this.

## 2. Editor

- **VS Code** + **Lua Language Server** (`sumneko.lua`) + **WoW API** (`ketho.wow-api`).
  - IntelliSense for the API, events, widgets, CVars, Enums, GlobalStrings. Auto-activates in a
    folder with a `.toc`.
  - Turn on `wowAPI.luals.frameXML` (annotated FrameXML).
  - No flavor switch is needed: it targets Mainline, which is what Forever is. Forever-only APIs
    (`C_GameRules`, `C_SkillInfo`, ...) may be missing until the extension updates, so check
    `/api` in-game or the `forever` branch of wow-ui-source.
- **luacheck** (`lunarmodules/luacheck`) for CI. Config in [../.luacheckrc](../.luacheckrc).
  Install: needs Lua plus luarocks, or grab a prebuilt Windows `luacheck.exe` from its releases.
- **StyLua** formatter, `syntax = "Lua51"`. Config in [../stylua.toml](../stylua.toml).

## 3. In-game dev tools

| Tool | Use |
|---|---|
| `/reload` | Reload UI (writes SVs). |
| `/console scriptErrors 1` | Show Lua errors. |
| `/dump <expr>` | Pretty-print a value. `/dump select(4, GetBuildInfo())` gives the Interface number. |
| `/fstack` | Frame stack under the mouse (Alt cycles, Ctrl shows textures). |
| `/etrace` | Live event trace. Essential for learning Forever's new events. |
| `/tinspect <table>` | Table inspector. |
| `/api system list`, `/api <system> search <x>` | Blizzard's built-in API docs. |
| **BugGrabber + BugSack** | Capture errors with history, no popups. |
| **DevTool** | Table/event/function inspector (ViragDevTool successor). |
| **TextureAtlasViewer** | Browse atlases for `SetAtlas` / `IconAtlas`. |
| **WowLua** | In-game Lua scratchpad. |

Check that each addon has a Forever build before relying on it.

## 4. Reference sources

- **warcraft.wiki.gg**: the canonical wiki (Wowpedia/Fandom is deprecated). TOC format, API pages,
  per-patch "API changes" pages, including `Patch_1.60.1/API_changes`.
- **Gethe/wow-ui-source**, `forever` branch: Blizzard's UI code per build.
- **Townlong Yak FrameXML browser**: searchable, diffable FrameXML.
- **wago.tools**: DB2 browser (spells, items, creatures), builds, files.
- **Export the UI yourself:** launch the client with `-console`, then at login or character select press
  the backtick key and run `ExportInterfaceFiles code` / `ExportInterfaceFiles art`. Output lands in
  `BlizzardInterfaceCode\` / `BlizzardInterfaceArt\` in the game folder. The wiki page is from 2024,
  so test it on Forever.

## 5. Libraries

- **LibStub** (registry), **CallbackHandler-1.0** (callbacks).
- **Ace3**: AceAddon (OnInitialize/OnEnable lifecycle), AceDB (profiles and defaults), AceConfig and
  AceConfigDialog (options tables registered into Blizzard Settings), AceEvent, AceConsole, AceTimer, AceGUI.
- **LibDataBroker-1.1 + LibDBIcon-1.0**: minimap/broker buttons. On Forever, the native
  AddonCompartment is a lighter alternative.
- **LibSharedMedia-3.0**: shared fonts, statusbars, sounds.
- Embed through `.pkgmeta` externals and gitignore `Libs/`. For local dev, run the packager locally
  or install the libs as standalone addons.

Ace3 is optional. For small addons, plain Lua plus the native `Settings` API is less code and less
to break.

## 6. Packaging and publishing

**BigWigsMods/packager@v2** (GitHub Action) builds the zip, substitutes keywords, writes the changelog,
and uploads to CurseForge, Wago and GitHub Releases. Targets come from the TOC `X-*-ID` fields.

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags: ['**']
jobs:
  release:
    runs-on: ubuntu-latest
    permissions: { contents: write }
    env:
      CF_API_KEY: ${{ secrets.CF_API_KEY }}
      WAGO_API_TOKEN: ${{ secrets.WAGO_API_TOKEN }}
      GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: BigWigsMods/packager@v2
```

- Token env names differ between the wiki (`CF_API_KEY`, `GITHUB_OAUTH`) and the README
  (`CF_API_TOKEN`, `GH_API_TOKEN`). Check the README when you set this up.
- Get tokens from: CurseForge `wow.curseforge.com/account/api-tokens`, Wago
  `addons.wago.io/account/apikeys`.
- Keywords: `@project-version@`, `--@debug@ ... --@end-debug@`, `@version-forever@` /
  `@non-version-forever@`. Version keywords do not work in multi-game builds, so branch on `WOW_PROJECT_ID` at
  runtime instead.
- Forever support is in packager **master** (game type `forever`, auto-detected from `16???`). Make
  sure the action version you pin includes it, and confirm the first upload lands under Forever on
  CurseForge/Wago.
- The packager runs on Linux (GitHub runner). Locally on Windows, run it through Git Bash or just
  rely on CI. Per house rules, no bash scripts ship in this repo.

## 7. Windows workflow

- Keep repos outside the game folder and link them in with a **junction** (no admin):
  `scripts\link-addon.ps1 -Addon HelloForever -AddOnsPath "<game>\<flavor>\Interface\AddOns"`
- Each flavor folder (`_retail_`, `_classic_beta_`, ...) has its own `Interface\AddOns` and `WTF`.
- To reset an addon's saved data: delete `WTF\Account\<ACCOUNT>\SavedVariables\MyAddon.lua` while logged out.

## 8. Blizzard UI Add-On Development Policy (the rules)

1. Addons must be free. No paid or premium versions, no paywalled downloads.
2. Code must not be obfuscated and must be publicly viewable.
3. Must not hurt realm or client performance (chat spam, heavy load).
4. No advertising.
5. Donation requests only on the addon's website or distribution page, never in-game.
6. Content must fit the ESRB "T" rating.
7. Must comply with the Terms of Use and EULA.
8. Blizzard may disable any addon functionality at any time.

No Forever-specific policy has been published. Assume the general one applies.
