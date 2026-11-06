# Forever as an addon platform

Snapshot 2026-10-20, beta build 1.60.1.70450, with a live-launch update (2026-11-05, build 70790)
below. Sources in [sources.md](sources.md). Anything marked **UNCONFIRMED** belongs on the
[launch checklist](04-launch-checklist.md).

## Live launch update (2026-11-05, build 1.60.1.70790)

- **Build:** launch shipped 70790 (`.build.info`, product `wowf`). Builds since the beta snapshot:
  70532 (Oct 22), 70707 (Nov 2), 70755 (Nov 3), 70790 (Nov 4). wow-ui-source `forever` is at 70790
  and tracks the `wowf` product since Nov 2.
- **Interface stays 16001** (wiki `Template:LatestPatchInfo`, `wowf` row, 2026-11-03; Questie and
  QuestieDB TOCs of Nov 5 agree). Not yet confirmed with `/dump` in-game.
- **No `WOW_PROJECT_FOREVER`.** Only `WOW_PROJECT_CAMELOT = 18`. Blizzard TOCs use the `camelot`
  load token, none use `forever`.
- **API drift vs 70450 is tiny:** +`C_ActionBar.IsHighestSpellRank`, +`C_BattleNet.GetDefaultTitleWhisperTarget`,
  `C_GameRules.SetForeverExperiencePreset` split into `...PreLogin` / `...PostLogin`,
  +`C_PetInfo.IsPetOrderMoveToPending`, events +`PET_ORDER_MOVE_TO_PENDING_CHANGED`,
  +`SETTINGS_HEADER_TEXT_UPDATE`. Enum `ForeverExperiencePreset.Modern` renamed `Enhanced`.
- **More secrets:** loss-of-control data is always secret (even for the player), `UnitCombat`
  amounts are secret, damage meter `specIconID` became secret, `C_Spell.IsSpellCrowdControl` takes
  secret arguments only from untainted code.
- **Raid markers are protected.** `SetRaidTarget` carries `HasRestrictions` at 70790 (wiki: protected
  since 12.0.0), so addons cannot mark, and `GetRaidTargetIndex` on enemies is restricted. A
  `SecureActionButtonTemplate` with `type1 = "macro"` and `macrotext1` still works:
  `SECURE_ACTIONS.macro` calls `C_Macro.RunMacroText` (restricted to secure code, which the button
  is). `/tm` takes conditionals and `!N` (do not toggle off). Macrotext: 255 characters, no
  `/click` chaining (11.0). Rare Alert uses this; unverified in-game.
- **Enemy nameplates start off.** Forever's CVar defaults (Ketho/BlizzardInterfaceResources `forever`
  branch, 2026-11-05): `nameplateShowEnemies` 0, `nameplateMaxDistance` 45. There are no vignettes
  (RareScanner's Forever notes), so nameplates are the only passive way to notice a unit at range.
  The real cap on `nameplateMaxDistance` is unverified (RareScanner suggests 80).
- **`C_UI.Reload` needs a hardware event** (a click or key press). From a timer or event handler the
  client blocks it with `ADDON_ACTION_BLOCKED` (our Setups hit this on 2026-11-04). The generated API
  docs carry no flag for it, so an allowlist cannot catch it; the wiki marks it `restrictedapi|hwevent`.
- `import()` exists (Blizzard_GamepadActionBars calls it); whether addons may call it is unconfirmed.
- **Profession skills:** `C_SkillInfo.GetSkillLineInfoByID(id)` returns `{ rank, modifier, maxRank, ... }`
  or nil when the skill is not learned (Blizzard's Camelot PaperDollFrame reads weapon skills this
  way). Forever's SkillLine table (wago.tools, 70790) has the classic professions plus a Forever
  child line each: Skinning 393 / 2947, Herbalism 182 / 2944, Mining 186 / 2946. Which one carries
  the player's rank is unverified in-game; Kill Value reads both and takes the higher.
- Legacy globals are not in the generated API docs, so the allowlist cannot check them, but they
  exist: `IsInGroup` (Blizzard's Forever UI calls it), and `GetLootSourceInfo` / `GetLootSlotType`
  (Kill Value's loot capture worked in the stress test).
- Beta 5 note missing from our docs: importing an Edit Mode layout string from an older version no
  longer raises an error.
- **Sell prices:** of 2,110 items in both wago.tools ItemSparse (70790) and Kill Value's table, 17
  differ (mostly Naxxramas, about 0.25x; six now sell for 0). Another 4,192 have no client row: their
  price comes from the server at runtime, so the runtime price is the authority.

## Identity cheat sheet

| Item | Value | Notes |
|---|---|---|
| `## Interface:` | `16001` | Beta, Test and live 70790 (wiki, 2026-11-03). In-game `/dump select(4, GetBuildInfo())` not run yet. |
| Client version | `1.60.1` | Live launch build: 70790 (Nov 4). |
| Code family | **Mainline** (same as Midnight) | Family TOC suffix `_Mainline.toc` loads on Forever too. |
| Game type | `camelot`, alias `forever` (since build 70291) | `[Game]` resolves to `"Camelot"`. The wiki says it "may be changed to Forever in the future." |
| TOC filename | `MyAddon_Forever.toc` (or `_Camelot.toc`) | Lookup order: game suffix, then family suffix, then plain `MyAddon.toc`. |
| Project ID | `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18) | Added in build 70170. Earlier beta builds returned 1 (Mainline), so guides saying "Mainline" are stale. |
| Ruleset detection | `C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset)` etc. | Also `IsHardcoreActive`, `IsSelfFoundAllowed`, event `GAME_RULES_CHANGED`. |
| Install folder | `World of Warcraft\_forever_\Interface\AddOns` | Confirmed 2026-10-20 from the stress-test install. The beta used `_classic_beta_`. |
| CDN product | `wowf` | Confirmed 2026-10-20: the install's `.product.db` says `wowf`, and `us.patch.battle.net:1119/wowf/versions` serves 1.60.1.70245. Beta (`wow_classic_beta`) is at 70450. |

Robust flavor detection:

```lua
local IS_FOREVER = WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
-- fallback the wiki also suggests:
local iface = select(4, GetBuildInfo())
local IS_FOREVER_BY_IFACE = iface >= 16000 and iface < 20000
```

## API base

- The wiki diff runs **12.1.5 (69952) to 1.60.1 (70205)**, and wow-ui-source has a `12.1.5..forever`
  compare. So: **retail docs, retail FrameXML, retail C_ namespaces, retail Settings/Edit Mode.**
- Diff size vs 12.1.5: global API +176/-10, FrameXML +471/-1041, events +24/-2, CVars +138/-7.
- **Forever-only additions** worth knowing:
  - `C_GameRules` (ruleset), `C_SkillInfo` (weapon/profession skills are back), `C_Spell.GetItemCooldown`,
    `UnitUsesAmmo`, `C_GamepadUI`, `C_GamepadTargeting`.
  - Events: `UNIT_HAPPINESS`, `UNIT_PET_TRAINING_POINTS`, `PLAYER_SWING` (a swing timer event),
    `GAME_RULES_CHANGED`, `SHARD_TRANSFER`.
- **Removed vs 12.1.5 (listed, direction ambiguous on the wiki):** AbandonSkill, BNSetBlocked,
  GetPetFoodTypes, SetBarSlotFromIntro, a few C_PvP training-ground and C_TransmogOutfitInfo calls.
- Blizzard ships its own versions of things addons used to provide: `Blizzard_CooldownViewer`
  (Cooldown Manager), `Blizzard_DamageMeter`, `Blizzard_EncounterTimeline`, Aggro Display, Edit Mode.
- `C_PvP.IsWarModeFeatureEnabled` returns false in Forever.
- Lua `require` was renamed to `import` (a wiki note from build 70291; worth looking at in-game).

## Restrictions (the part that shapes what you can build)

Official (WoWUIDev Discord, mirrored on the wiki, Sep 15): **"The addon disarmament changes
introduced in Midnight, including secrets, will also be active in Forever."**

What that means in practice:

- **Secret values:** certain APIs return opaque "secret" values during combat/encounters. You
  can pass them to Blizzard widgets for display (e.g. set a status bar from them). You cannot
  compare them, do arithmetic on them, or branch on them in addon code.
  - Seen in Forever beta: **combo points**, **threat** (`UnitDetailedThreatSituation`,
    `UnitThreatPercentageOfLead`), secret **system chat messages** (Questie had to handle these),
    and `GetFrameStrata` on frames with the new FrameStrata secret aspect.
- **Combat log:** the forever branch ships Midnight's `C_CombatLog` with `IsCombatLogRestricted` and
  restricted/secure entry info. Expect the same lockdown as Midnight (inferred from the API docs, not
  stated in a blue post). Meters rely on Blizzard's server-side damage meter data.
- **AuraContainer/AuraButton** changes from 12.1.0 apply.
- **GUID obfuscation (Beta 5):** server ID and spawn ID in creature, vehicle, pet and object GUIDs are
  obfuscated. Layer-detection addons are dead. Do not rely on GUID parsing for NPC IDs without
  testing in-game.
- **Chat:** `SendChatMessage` with SAY/YELL/EMOTE outside instances needs a hardware event (a keypress or
  click). Trial accounts cannot send addon messages.
- **Taint:** classic combat-lockdown rules still apply (e.g. Questie found `WorldMapFrame:SetMapID`
  taints in combat).
- **Reskinned frames (Beta 5):** the player, target and pet frames and the minimap were reskinned. Addons that
  anchor to or skin them need re-testing on the live build.

**Design rule of thumb:** out-of-combat quality of life, information, collection, social,
economy, questing, map, UI layout and cosmetics are all wide open. In-combat decision making is
deliberately closed.

## Known beta bugs (may be fixed by launch)

- SavedVariables not loading / settings wiped on client restart (fixed in 70009 per the wiki, but players
  reported it later too).
- `UnitName("player")` returned "Unknown" before `PLAYER_LOGIN` (fixed in 70170). Init in
  `PLAYER_LOGIN`, not at file scope.

## Ecosystem status (major addons, from their repos)

| Addon | Forever? | Notes |
|---|---|---|
| Questie | Yes | v12.6.1 (Nov 5) ships `Questie_Forever.toc` and `_Camelot.toc` (16001); 12.2.0 fixed map-icon errors in combat and secret-aura taint. QuestieDB is a separate install now (1.0.11, Nov 5, Forever data); the CurseForge app does not pull it in (Questie #8149, #8161). The unofficial `questie-forever` CurseForge package is NOT theirs. Good reference repo. |
| Details! | Yes | `Details_Camelot.toc` plus plugins. |
| DBM | Yes | Multi-interface TOC includes 16001. Secret-based alert systems extended to Forever. |
| BigWigs | Yes | 16001 in the Interface list. Retail modules gated with `AllowLoadGameType`. Good reference for multi-flavor TOC tricks. |
| ElvUI | Yes | Skin fixes for Forever. |
| **WeakAuras** | **No** | Still no Mainline/Camelot TOC at launch (repo pushed Nov 2). A third-party "EverAuras" exists (unverified). |
| Auctionator | Yes | 341 (Oct 13) declares 16001 and CurseForge lists it under WoW Forever. No public repo. |
| BugGrabber / BugSack | Yes | v12.1.1 / v12.1.9 (Oct 26, cleanups) list 16001. |
| Bagnonium, LibTSMCore | Patched | Fixes for the project ID change and missing classic templates are useful to read. |

Lessons from what broke: the project ID switch (1 to 18), classic templates missing on a modern client
(e.g. `CharacterFrameTabButtonTemplate`), secret values in combat and system messages, combat
taint on map calls, GUID obfuscation, reskinned unit frames.

## Distribution

- **CurseForge:** Forever is `gameVersionTypeId=88568` (game version 1.60.1). Filter:
  `https://www.curseforge.com/wow/search?class=addons&gameVersionTypeId=88568`
- **Wago Addons:** flavor `forever`, patch `1.60.1`, TOC suffixes `_Forever`/`_Camelot`.
- **BigWigs packager (v2.7.0, Nov 5):** game type `forever` (alias `camelot`), auto-detected from
  Interface `16???`. Keywords `@version-forever@` / `@non-version-forever@`, `-g forever`. Uploads to
  CF and Wago. **It does not know the `_Forever.toc` suffix** (its lists end at `Camelot`), so with
  our `_Forever`-only TOC it would misname or fail to find the TOC (read from its code, not run).
  Add a `_Camelot.toc` or a plain `.toc` before adopting it.
- **Wago** accepts `-Forever`, `_Forever`, `-Camelot`, `_Camelot`; forever patch `1.60.1` is live.
- **WoWInterface:** not supported by the packager yet ("No WoWInterface game type match").
- **WowUp / CurseForge app:** not verified.

## Reference material

- UI source: `https://github.com/Gethe/wow-ui-source/tree/forever` (one commit per build). This is the
  single most useful reference. Diff against `12.1.5` to see exactly what Forever changed.
- API diffs: `https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes` and `/notes`
- Ketho/BlizzardInterfaceResources: globals, events and CVar lists per build.
- wago.tools: DB2 tables (spells, items, NPCs), builds, files.
- In-game: `/api` (Blizzard's API documentation browser), `/fstack`, `/etrace`.
