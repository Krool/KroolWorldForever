# Forever as an addon platform

Snapshot 2026-10-20, beta build 1.60.1.70450. Sources in [sources.md](sources.md). Anything marked
**UNCONFIRMED** belongs on the [launch checklist](04-launch-checklist.md).

## Identity cheat sheet

| Item | Value | Notes |
|---|---|---|
| `## Interface:` | `16001` | Confirmed for Beta and Test. Live value is **UNCONFIRMED** (wiki row blank). Check with `/dump select(4, GetBuildInfo())`. |
| Client version | `1.60.1` | Latest build seen: 70450 (Oct 16). |
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
| Questie | Yes | `Questie_Camelot.toc` (16001), v12.1.0 on Oct 12. The unofficial `questie-forever` CurseForge package is NOT theirs. Good reference repo. |
| Details! | Yes | `Details_Camelot.toc` plus plugins. |
| DBM | Yes | Multi-interface TOC includes 16001. Secret-based alert systems extended to Forever. |
| BigWigs | Yes | 16001 in the Interface list. Retail modules gated with `AllowLoadGameType`. Good reference for multi-flavor TOC tricks. |
| ElvUI | Yes | Skin fixes for Forever. |
| **WeakAuras** | **No** | No Mainline/Camelot TOC (it stopped at Midnight). A third-party "EverAuras" exists (unverified). |
| Auctionator | Unverified | Only fan sites claim support. |
| Bagnonium, LibTSMCore | Patched | Fixes for the project ID change and missing classic templates are useful to read. |

Lessons from what broke: the project ID switch (1 to 18), classic templates missing on a modern client
(e.g. `CharacterFrameTabButtonTemplate`), secret values in combat and system messages, combat
taint on map calls, GUID obfuscation, reskinned unit frames.

## Distribution

- **CurseForge:** Forever is `gameVersionTypeId=88568` (game version 1.60.1). Filter:
  `https://www.curseforge.com/wow/search?class=addons&gameVersionTypeId=88568`
- **Wago Addons:** flavor `forever`, patch `1.60.1`, TOC suffixes `_Forever`/`_Camelot`.
- **BigWigs packager (master):** game type `forever` (alias `camelot`), auto-detected from Interface
  `16???`. Keywords `@version-forever@` / `@non-version-forever@`, `-g forever`. Uploads to CF and Wago.
- **WoWInterface:** not supported by the packager yet ("No WoWInterface game type match").
- **WowUp / CurseForge app:** not verified.

## Reference material

- UI source: `https://github.com/Gethe/wow-ui-source/tree/forever` (one commit per build). This is the
  single most useful reference. Diff against `12.1.5` to see exactly what Forever changed.
- API diffs: `https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes` and `/notes`
- Ketho/BlizzardInterfaceResources: globals, events and CVar lists per build.
- wago.tools: DB2 tables (spells, items, NPCs), builds, files.
- In-game: `/api` (Blizzard's API documentation browser), `/fstack`, `/etrace`.
