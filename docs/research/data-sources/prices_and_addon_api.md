# WoW: Forever auction-price data sources and addon-API facts (researched 2026-11-10)

Reliability tags: **[P]** Blizzard primary (docs, API, client code), **[A]** addon author primary (repo, changelog, shipped files), **[C]** community developer probe or library (first-hand but unofficial), **[S]** guide/SEO/listing site or search snippet only (low confidence). "Local" sources are files on this machine: the owner's Forever install at `C:\Program Files (x86)\World of Warcraft\_forever_\` and this repo. Facts about retail or Classic Era are labeled as such.

## Q1. Is there an official Blizzard Game Data API for Forever (realms, auctions, commodities, namespaces)?

### Takeaway
Yes in practice, no in documentation. Since 2026-11-06 Blizzard serves Forever auction houses under undocumented **ruleset** routes in the `dynamic-forever-{region}` namespace (there are no realms). Every ruleset returns the same houses, 43% of auctioned item ids are missing from `static-forever`, Blizzard staff have said nothing in public, and the standard Developer API terms apply (30-day retention cap, no transfer to third parties).

### Cited Findings
- **Namespaces [C]:** `static-forever-{region}`, `dynamic-forever-{region}`, `profile-forever-{region}` work in US, EU, KR and TW; CN needs a separate client. `static-forever` serves version `1.60.1_70399`, pinnable as `static-1.60.1_70399-forever-{region}`. Poster vman-2993, 2026-11-05, says the API "isn't documented yet" and "can change in a heartbeat". - [Blizzard API forum: "WoW: Forever API: what works so far, plus a TS client"](https://us.forums.blizzard.com/en/blizzard/t/wow-forever-api-what-works-so-far-plus-a-ts-client/60334)
- **No realms [C]:** the realm index returns 404 and realm search returns 0. Use `/data/wow/ruleset/index` and `/data/wow/ruleset/{id}` (returns `{ id, name, auctions, status }`). EU/US rulesets: 1 PvP, 2 Normal, 3 Roleplay, 15 Roleplay PvP; KR/TW: 1 and 2 only; 999 returns 404. - [same thread](https://us.forums.blizzard.com/en/blizzard/t/wow-forever-api-what-works-so-far-plus-a-ts-client/60334)
- **Auction routes (live 2026-11-06, update posted 08:41) [C]:**
  - index `/data/wow/ruleset/{id}/auctions/` (dynamic namespace; the trailing slash is required, without it 404) returns `{ auctions: [{ key, name, id }] }`
  - house `/data/wow/ruleset/{id}/auctions/{houseId}` returns `{ id, name, auctions, commodities, ruleset }`
  - commodities `/data/wow/ruleset/{id}/auctions/{houseId}/commodities` returns `{ auctions: [{ id, item, quantity, unit_price, time_left }] }`
  - the retail-style `/data/wow/auctions/commodities` still 404s. On 2026-11-05 the auctions link existed but had no route.
  - [same thread](https://us.forums.blizzard.com/en/blizzard/t/wow-forever-api-what-works-so-far-plus-a-ts-client/60334)
- **Houses [C]:** 15 houses per ruleset in every region, ids 110-121 and 123-125: five each of "Alliance Auction House", "Horde Auction House" and "Blackwater Auction House" (neutral), which the poster likens to Classic Era faction AHs. Houses 112, 115 and 118 have no `auctions` field. - [same thread](https://us.forums.blizzard.com/en/blizzard/t/wow-forever-api-what-works-so-far-plus-a-ts-client/60334)
- **Ruleset does not partition the data [C]:** every ruleset lists the same houses with identical auctions (house 113 returns the same ~68k auction ids through rulesets 1, 2 and 3). The poster warns not to sum across rulesets and says it may be a bug. - [same thread](https://us.forums.blizzard.com/en/blizzard/t/wow-forever-api-what-works-so-far-plus-a-ts-client/60334); confirmed by library author: "The ruleset ID must be valid, but doesn't filter them." - [Pinta365/blizzard_api release 0.8.2, 2026-11-06](https://github.com/Pinta365/blizzard_api/releases/tag/0.8.2). TheWoWDB reads the same thing as intended: "Blizzard publishes the same region-wide pool for Normal, PvP and Roleplay realms." - [TheWoWDB](https://thewowdb.com/) [S]. **These two readings conflict (bug vs region-wide design). Blizzard has not said which.**
- **Which ruleset owns which house is not in the API [S]:** "The API doesn't say which group of three houses (Alliance, Horde, Blackwater) is which ruleset." (search snippet, not opened) - [michaelwhelehan/forever-build-coach PR #10](https://github.com/michaelwhelehan/forever-build-coach/pull/10)
- **Entry format [C]:** looks like retail. Auctions carry `id`, `item` (`id`, `context`, `bonus_lists`, `modifiers`), `buyout`, optional `bid`, `quantity`, `time_left`; some are bid-only with no buyout; commodities use `unit_price`. The busiest houses hold 50-68k auctions, about 9 MB per response. - [forum thread](https://us.forums.blizzard.com/en/blizzard/t/wow-forever-api-what-works-so-far-plus-a-ts-client/60334)
- **Item data gap [C]:** in one EU Alliance house, 652 of 1,515 distinct item ids (43%) return 404 from `/data/wow/item/{id}` in `static-forever` (example: 720 Brawler Gloves, many Classic-era greens and blues). - [forum thread](https://us.forums.blizzard.com/en/blizzard/t/wow-forever-api-what-works-so-far-plus-a-ts-client/60334); the library notes the same: `wowForever.item(id)` can 404. - [Pinta365 0.8.2](https://github.com/Pinta365/blizzard_api/releases/tag/0.8.2)
- **Profile API [C]:**
  - characters appear only from level 10 and only after logout; the profile has `surname` and `ruleset` instead of `realm`
  - the account summary lags the character profile by 20-40 min; `hunter-pets` 404s
  - character media renders at `render.worldofwarcraft.com/forever-{region}/...` and can take 12+ hours to appear
  - guilds use `ruleset` instead of realm
  - [forum thread](https://us.forums.blizzard.com/en/blizzard/t/wow-forever-api-what-works-so-far-plus-a-ts-client/60334)
- **No Blizzard staff reply** in the thread as of 2026-11-06. - [forum thread](https://us.forums.blizzard.com/en/blizzard/t/wow-forever-api-what-works-so-far-plus-a-ts-client/60334)
- **Official docs do not cover Forever [P, via search snippet]:** the Game Data APIs page lists only `/data/wow/connected-realm/{connectedRealmId}/auctions` and `/data/wow/auctions/commodities`, with nothing on rulesets. - [develop.battle.net Game Data APIs (WoW)](https://community.developer.battle.net/documentation/world-of-warcraft/game-data-apis); Classic docs, which describe passing the namespace as a `Battlenet-Namespace` header or query parameter: [Classic Game Data APIs](https://community.developer.battle.net/documentation/world-of-warcraft-classic/game-data-apis)
- **Timeline [S]:** on 2026-10-28 one project found no Forever namespace at all (search snippet). - [jkc-be/goldbook issue #67](https://github.com/jkc-be/goldbook/issues/67)
- **TS client [C]:** `@pinta365/blizzard-api` (JSR `jsr:@pinta365/blizzard-api`, npm `@pinta365/blizzard_api`; Deno/Node/Bun/browser).
  - Forever support since 0.8.0; Forever auctions since 0.8.2 (2026-11-06)
  - methods: `auctionHouses(rulesetId)`, `auctionHouse(rulesetId, auctionHouseId)`, `auctionHouseCommodities(rulesetId, auctionHouseId)`
  - license not stated in the release or the forum thread
  - [GitHub repo](https://github.com/Pinta365/blizzard_api), [0.8.2 release](https://github.com/Pinta365/blizzard_api/releases/tag/0.8.2)
- **Auth [C]:** OAuth client id and secret are required, and the secret cannot live in browser JS. - [Khelthos/template-forever BLIZZARD-API.md (Oct 2026)](https://github.com/Khelthos/template-forever/blob/main/docs/BLIZZARD-API.md)
- **Terms [P]:** Blizzard Developer API Terms of Use, "Last updated October 1, 2019":
  - "You must implement a maximum 30-day TTL (time-to-live) policy for all Data obtained through our APIs" and "retain data ... for no longer than 30 days"
  - 36,000 calls per hour
  - you may "distribute the Data to end users for their personal use via Your Application", but "You are not allowed to sell, license or otherwise transfer the Data to any third party"
  - no charging players and no paid "Premium" tier built on the APIs
  - credit Blizzard as the data source without implying endorsement; no Blizzard trademarks in the app title or URL
  - delete the data on termination
  - [Blizzard Developer API Terms of Use](https://www.blizzard.com/en-us/legal/a2989b50-5f16-43b1-abec-2ae17cc09dd6/blizzard-developer-api-terms-of-use)

### Inferences
- The house ids are consistent with TheWoWDB's "24 auction houses, US and EU": 15 houses per region minus the 3 empty ones (112, 115, 118) leaves 12 per region, and 12 x 2 regions = 24. The ids group into five triples (110-112, 113-115, 116-118, 119-121, 123-125), and each empty house is the third of the first three triples. This suggests five Alliance/Horde/Blackwater groups shared region-wide, but it is a pattern guess, not documented.
- **Bundle use:** an addon cannot make HTTP calls, so the API is only usable from offline Node tools in `tools/`.
  - Safe uses: dev-time cross-checks (is Auctionator's figure sane, which items actually trade), and test fixtures that are not shipped.
  - Risky use: shipping API-derived prices inside the release zip (for example a seed price table like the Kill Value loot tables). That data would sit in players' installs well past the 30-day cap, and handing it out in a public download is arguably a "transfer to third parties". Treat it as off-limits unless the owner accepts that reading.
- For item metadata (names, quality, vendor price), use wago.tools DB2 tables, which the repo already uses for Skill-Up Odds, not the `static-forever` item endpoint: 43% of item ids are missing there.
- Because rulesets do not partition the data, a tool that groups by ruleset would count each house four times. Key by `houseId` and region instead.

### Gaps
- No Blizzard announcement, docs page or staff post on Forever Game Data APIs was found. It is unconfirmed whether identical-per-ruleset data is intended.
- The update cadence comes only from [S] sites (forevermastery and TheWoWDB say hourly). The `Last-Modified` header and snapshot timing were not verified first-hand.
- Which ruleset or region group each house triple belongs to, and what TheWoWDB means by "realm houses Blizzard does not publish", are unknown.
- The Pinta365 library's license was not verified.

## Q2. Which price sites or datasets cover Forever, and on what terms?

### Takeaway
TradeSkillMaster officially claims Forever support from 4.15 (launch day 2026-11-04), but how Forever data is delivered and keyed is undocumented. The Undermine Exchange backend gained Forever code in September, but live site coverage is unverified. Saddlebag Exchange shows no Forever coverage. A crop of new Forever-only price sites mostly reads the Blizzard API hourly, and none publishes an API, downloadable data or terms of use.

### Cited Findings
- **TSM 4.15 [A]:**
  - "the major 4.15 update does support WoW: Forever"; "you'll be able to use it from launch day on November 4th"
  - ships a new TSM Desktop app for Windows, Mac and Linux, rebuilt for "different levels of support for Auction House price data" and new realm types
  - Premium users get the beta early
  - does not name Forever price sources (DBMarket, DBRegionMarketAvg and so on), the data keying, or the cadence
  - by gumdrops, page dated about 2026-11-01
  - [TSM news: "TSM 4.15 brings WoW: Forever Support, plus New Desktop app"](https://tradeskillmaster.com/news/tsm-4-15-brings-wow-forever-support-plus-new-desktop-app-1180)
- **Conflicting [S]:** wowcalc.net lists TSM for Forever as "not verified" with "no Forever version" yet. It is contradicted by TSM's own announcement. - [wowcalc.net TSM page](https://wowcalc.net/en/forever/wiki/addons/tradeskillmaster)
- **TSM data keying, unofficial client [C]:** Wuild/TSM-App (MIT, "not affiliated with ... TradeSkillMaster LLC"):
  - Forever "requires TradeSkillMaster 4.15 or later with AppHelper"
  - Forever markets are split by region, ruleset and faction "when that information is available"
  - automatic Forever price downloads depend on "the legacy TSM service supplying Forever data"
  - authenticated refresh every 30 min
  - [Wuild/TSM-App](https://github.com/Wuild/TSM-App/)
- **TSM project-id fix:** LibTSMCore needed a Forever project-id fix (recorded in the repo's 2026-10-20 research). - [LibTSMCore PR #28](https://github.com/TradeSkillMaster/LibTSMCore/pull/28); see `docs/sources.md`
- **TSM as a price source for other addons [S]:** CraftProfit Forever auto-detects TSM and can use it as a price source; its page warns the Forever API can change between builds. - [CraftProfit Forever (CurseForge)](https://www.curseforge.com/wow/addons/craftprofit-forever)
- **Undermine Exchange (successor of The Undermine Journal and Oribos Exchange) [A]:**
  - backend repo `erorus/shatari` is Apache-2.0
  - commits 2026-09-20 "add support for reading forever realms with faction houses" and "add forever game data"; 2026-09-26 "data update for 12.1.0.69933 1.60.1.70009"; last push 2026-10-17
  - that is before Blizzard's ruleset routes went live on 2026-11-06
  - [erorus/shatari](https://github.com/erorus/shatari), [front end](https://github.com/erorus/shatari-front)
  - Oribos Exchange addon (retail): tooltips show the region median of the lowest commodity price over 4 days. - [Oribos Exchange (CurseForge)](https://www.curseforge.com/wow/addons/oribos-exchange); renaming history: [Grahran's WoW Gold](https://grahranswowgold.com/oribos-exchange/) [S]
- **Saddlebag Exchange:** searches found only retail item pages and nothing Forever-specific. Its WoW addon repo was last pushed 2026-10-15. - [saddlebagexchange.com item page (retail)](https://saddlebagexchange.com/wow/item-data/116259); [SaddlebagExchangeWoW addon](https://www.curseforge.com/wow/addons/saddlebag-exchange)
- **TheWoWDB [S, site self-description]:**
  - "Blizzard's own Forever auction data, every auction house, read hourly"
  - player uploads via the "TheWoWDB - Forever addon" add "the realm houses Blizzard does not publish"
  - 24 auction houses (US and EU); rulesets Normal, PvP, Roleplay, Roleplay PvP
  - no API, no CSV/JSON download, no terms page; "Independent fan-made market tool"
  - last player scan shown 10 Nov 2026 23:22 UTC
  - [thewowdb.com](https://thewowdb.com/), [Forever AH](https://thewowdb.com/wow-forever/auction-house/), [addon](https://thewowdb.com/addons/#wow-forever)
- **Other Forever price sites [S, search snippets only, terms not checked]:**
  - [forevermastery.com/en/prices](https://forevermastery.com/en/prices): says Blizzard's API publishes every Forever AH every hour
  - [azerothauctions.com/forever/us](https://azerothauctions.com/forever/us): live prices for EU, US, KR and TW, with top movers
  - [wow-forever.gg](https://wow-forever.gg/auction-house/browse/all/): lowest buyout per unit
  - [wowauctionhouse.com](https://wowauctionhouse.com/): Forever prices from player scans uploaded with the TheWoWDB addon
  - [ahprice.com](https://ahprice.com/): free addon plus PC app, "True Value" tooltips, shared scans
  - [bootybaybroker.com/forever](https://bootybaybroker.com/forever)
  - [timesaver.gg](https://timesaver.gg/wow-forever/auction-prices): its launch-week article and daily page disagree on figures
- **In-game AH addons with Forever builds [S, CurseForge via search snippets, not opened]:**
  - [Goblin Terminal](https://www.curseforge.com/wow/addons/goblin-terminal) (Forever only)
  - [Hammerprice](https://www.curseforge.com/wow/addons/hammerprice)
  - [ForeverStonks](https://www.curseforge.com/wow/addons/foreverstonks) (Retail and Forever; notes a beta bug where settings are not reloaded after logout)
  - [Grimlight Auctions](https://www.curseforge.com/wow/addons/grimlight-auctions) (16001 / 1.60.1, early testing)
  - [auxForever](https://www.curseforge.com/wow/addons/auxforever) (port of shirsig's aux; "do not report auxForever problems to Simon")
  - [Auctioneer (Forever)](https://www.curseforge.com/wow/addons/auctioneer-forever), [FlipQueue](https://www.curseforge.com/wow/addons/flipqueue/files/8349304), [WoW Markets](https://www.curseforge.com/wow/addons/wow-markets/files/8418454)
- **Guide [S]:** U4N on Forever commodities, Auctionator and changed undercutting. - [u4n.com guide](https://www.u4n.com/news/wow-forever-auction-house-guide-commodities-auctionator-and-why-undercutting-has-changed.html)

### Inferences
- For the bundle, Auctionator is still the only price source with a documented, stable in-game API that the owner already runs. TSM could become a second optional source (via `TSM_API`) once its Forever price sources are confirmed in game.
- None of the external sites offers machine-readable data or terms, and their upstream is the Blizzard API under the terms in Q1. The best they can serve is manual sanity checks while writing docs or test fixtures.
- Sites that merge player scans ("realm houses Blizzard does not publish") hint that some houses are absent from the API. That cannot be confirmed from here.

### Gaps
- TSM's Forever price-source names, region vs house scope, and whether `TSM_API.GetCustomPriceValue` works on Forever were not found. TSM's terms for third-party addons reading TSM prices were not checked.
- Whether undermine.exchange shows Forever data after the 2026-11-06 route change is unverified (the site is a JS app; not fetched).
- No Forever evidence was found for Saddlebag, and no NexusHub-like site came up in searches.

## Q3. Auctionator on Forever: changelog, price database format, public API (plus Journalator and others)

### Takeaway
Auctionator 345 (2026-11-10) runs on Forever. It treats Forever as Mainline (modern AH code), stores prices under the ruleset name (for example `"PvE"`) with no faction in the key, and exposes a stable `Auctionator.API.v1` that already covers what the bundle needs. Its license is "All Rights Reserved", and its GitHub repo is not publicly reachable, so the changelogs for 341-344 could not be retrieved.

### Cited Findings
- **Shipped TOC (local, [A]):**
  - `## Version: 345`
  - `## Interface: 120100, 120105, 16001, 50504, 38000, 20506, 11508, 11509`
  - `## Author: plusmouse, Borjamacare`
  - SavedVariables: `AUCTIONATOR_CONFIG, AUCTIONATOR_SAVEDVARS, AUCTIONATOR_SHOPPING_LISTS, AUCTIONATOR_PRICE_DATABASE, AUCTIONATOR_POSTING_HISTORY, AUCTIONATOR_VENDOR_PRICE_CACHE, AUCTIONATOR_RECENT_SEARCHES, AUCTIONATOR_SELLING_GROUPS`
  - `## X-Website: https://www.curseforge.com/wow/addons/auctionator`
  - local file `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\Auctionator\Auctionator.toc`; site: [Auctionator (CurseForge)](https://www.curseforge.com/wow/addons/auctionator)
- **Changelog (local, [A]):** the packaged `CHANGELOG.md` holds only `## [345] (2026-11-10)`: "Forever: Crafting: Fix profit" and "Fix undercut % losing item price". It links to `github.com/TheMouseNest/Auctionator`, which returned 404 to both WebFetch and the GitHub API on 2026-11-10 (private or moved). `github.com/Auctionator/Auctionator` also 404s. The Wago versions page returned no content. - local `...\AddOns\Auctionator\CHANGELOG.md`; [Wago Auctionator](https://addons.wago.io/addons/auctionator/versions)
- **License (local, [A]):** "All Rights Reserved. Copyright (c) 2020-2025 plusmouse, borjamacare". - local `...\Auctionator\LICENSE`
- **Forever detection (local `Source/Constants/Main.lua`) [A]:**
  - `IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or WOW_PROJECT_ID == WOW_PROJECT_CAMELOT, -- temporary fix assigning retail to mainline`
  - `IsForever = build >= 16000 and build < 20000`
  - `Source_Mainline/CraftingInfo/Professions.lua` branches on `IsForever` (the 345 crafting-profit fix lives here)
- **Forever posting durations (local `Source_Forever/Constants.lua`) [A]:** `Durations = { Short = 2, Medium = 8, Long = 24 }` (hours). These are Classic-style; retail uses 12/24/48.
- **Price DB key on Forever (local `Source_ModernAH/Variables/Main.lua`) [A]:**
  - when `RegionalUniqueNamesEnabled()` is true, `GetConnectedRealmRoot()` returns the ruleset name only
  - the name is `"RPPvP"`, `"PvP"`, `"RP"`, `"HC"` or `"PvE"`, picked with `C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset / RPRuleset / HardcoreRuleset)`
  - otherwise it falls back to the connected-realm root; the legacy-AH flavor keys `GetRealmName() .. " " .. UnitFactionGroup("player")`
  - `RegionalUniqueNamesEnabled` is in the Forever API docs (local allowlist `tools/forever-api/forever-api.json`, build 70862)
- **Owner's live DB (local SavedVariables, written 2026-11-10 16:17) [A]:** `AUCTIONATOR_PRICE_DATABASE = { ["__dbversion"] = 8, ["PvE"] = "<binary>" }`. The value is serialized with `LibCBOR:Serialize(data)` (`Source/Variables/Main.lua` line 138, `VERSION_KEY_SERIALIZED = 8`). - local `...\_forever_\WTF\Account\56513560#1\SavedVariables\Auctionator.lua`
- **Record format (local `Source/Database/Mixin.lua`) [A]:** per item key:
  - `m` = latest buyout
  - `h[day]` / `l[day]` = highest and lowest price seen that day, keyed by days-since-zero
  - `a[day]` = quantity available
  - helpers: `GetPriceHistory`, `GetPriceAge`, `GetMeanPrice(dbKey, days)`
- **External API (local `Source/API/v1/README.md` and files) [A]:** "This API is intended to remain stable." and "Calling any other functions related to Auctionator is not supported and may break without warning". Every call takes a `callerID` checked by `InternalVerifyID`.
  - prices and age: `GetAuctionPriceByItemID/ItemLink`, `GetAuctionAgeByItemID/ItemLink`, `IsAuctionDataExactByItemID/ItemLink`
  - other prices: `GetDisenchantPriceByItemID/ItemLink`, `GetVendorPriceByItemID/ItemLink`
  - search: `MultiSearch`, `MultiSearchAdvanced`, `MultiSearchExact` (the AH must be open)
  - shopping lists: `CreateShoppingList`, `GetShoppingListItems`, `AlterShoppingListItem`, `DeleteShoppingListItem`, `ConvertToSearchString`, `ConvertFromSearchString`
  - scan callback: `RegisterForDBUpdate(callerID, callback)`, in `Source_ModernAH/API/v1/RegisterForDBUpdate.lua`, which is the flavor Forever loads
- **What the bundle uses today (local `KroolWorldForever/Core/Prices.lua`) [A]:** `GetAuctionPrice*`, `GetAuctionAge*` and `RegisterForDBUpdate`, each pcall-wrapped behind `root.AuctionPrice` / `root.AuctionAge` / `root.OnAuctionPrices`.
- **Client AH API on Forever [P]:** the forever-branch API docs at 70862 list 86 `C_AuctionHouse` functions, including `ReplicateItems`, `GetNumReplicateItems`, `GetReplicateItemInfo`, `GetReplicateItemLink`, `SendBrowseQuery`, `GetItemSearchResultInfo` and `GetCommoditySearchResultInfo`. The events `AUCTION_HOUSE_SHOW`, `REPLICATE_ITEM_LIST_UPDATE` and `COMMODITY_SEARCH_RESULTS_UPDATED` are also present. - local allowlist built from [Gethe/wow-ui-source forever](https://github.com/Gethe/wow-ui-source/tree/forever)
- **Journalator:** no Forever evidence found in searches, and it is not installed locally.

### Inferences
- **Faction mixing:** the key has no faction, so on one ruleset an Alliance alt's scans and a Horde alt's scans (and Blackwater-house scans) all write the same `"PvE"` table. `m` is whichever scan ran last, and the daily `h`/`l` merge across houses. The bundle cannot tell which house a price came from through API v1. Worth a line in the Kill Value, Disenchant Value and Least Valuable docs and tooltips ("last scanned price on your ruleset").
- **Cheap wins with no new dependency:**
  - `IsAuctionDataExactByItemLink`: flag when a link price fell back to the base item, for random-suffix greens
  - `GetDisenchantPriceByItemID`: cross-check the bundle's own Disenchant Value tables
  - `GetVendorPriceByItemID`: covers items whose vendor price the client has not cached
- **Do not read Auctionator's SavedVariables directly:** the format is CBOR-serialized internals, the README calls it unsupported, and the license is All Rights Reserved (no copying or vendoring Auctionator code). Stay on API v1 with the existing feature checks (`type(api.X) == "function"`).
- Auctionator's Forever handling is self-described as a "temporary fix", so future versions may move Forever off the retail path. The bundle's pcall and feature checks already cover that.

### Gaps
- Changelogs for versions 341-344 (Nov 2026) were not retrievable: the repo returns 404, CurseForge and Wago pages did not render, and the packaged file holds only 345.
- Whether Auctionator's full scan (`ReplicateItems`) works on Forever, and with what throttle, was not tested here.
- Whether `RegionalUniqueNamesEnabled()` is actually true on live Forever (implied by the `"PvE"` key in the owner's DB) has no Blizzard statement.
- Journalator on Forever is unknown.

## Q4. Forever addon restrictions: secret values, blocked APIs, Lua resource caps, Blizzard policy, known addon breakages

### Takeaway
Blizzard said on 2026-09-15 that Midnight's restrictions, secrets included, carry over to Forever. The concrete Forever deltas are recorded on the wiki's 1.60.1 notes. The per-addon Lua caps (500 timers, 10000 frames, 5000 FontStrings) have no public source beyond this repo's own stress test. Questie and DBM spent October-November fixing secret-value errors. A new build, 70888, landed in wow-ui-source today with one API-doc change.

### Cited Findings
- **Blizzard policy (Discord post mirrored by the wiki) [W/P]:** 2026-09-15 "An Update On Secrets In WoW: Forever". Midnight's addon disarmament, including secrets, is active in Forever. Forever shares the Mainline UI architecture and most APIs from 12.1.5; "Camelot" and "Standard" are game types within the Mainline family. - [warcraft.wiki.gg Patch 1.60.1/API changes/notes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes)
- **Beta Changes 4, 2026-10-08, build 70291 [W]:**
  - new secret aspect `FrameStrata`: `GetFrameStrata` returns a secret for frames that have it
  - minimap rotation is no longer readable during encounters
  - trial accounts can no longer send addon messages
  - `SendChatMessage` with "EMOTE" needs a hardware event outside instances, like "SAY"/"YELL"
  - `require` renamed to `import`
  - `C_PvP.IsWarModeFeatureEnabled` returns false
  - `GetInspectHonorData` returns two extra values
  - Edit Mode layouts are saved separately for mouse/keyboard and gamepad
  - AuraContainer/AuraButton from 12.1.0 are available
  - [wiki notes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes)
- **Beta Changes 5, 2026-10-16, build 70425 [W]:** the player, target, pet, target-of-target, totem and focus frames and the minimap header were reskinned, and some child frames were reorganized. Addons that anchor to Blizzard frames should re-check. - [wiki notes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes); API diff page: [Patch 1.60.1/API changes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes)
- **Secret-gate APIs in the Forever API docs at 70862 (local allowlist) [P]:**
  - auras: `C_Secrets.ShouldAurasBeSecret`, `ShouldSpellAuraBeSecret`, `ShouldUnitAuraIndexBeSecret`, `ShouldUnitAuraInstanceBeSecret`, `ShouldUnitAuraSlotBeSecret`
  - cooldowns: `ShouldCooldownsBeSecret`, `ShouldActionCooldownBeSecret`, `ShouldSpellCooldownBeSecret`, `ShouldSpellBookItemCooldownBeSecret`
  - totems: `ShouldTotemSlotBeSecret`, `ShouldTotemSpellBeSecret`
  - units: `ShouldUnitComparisonBeSecret`, `ShouldUnitHealthMaxBeSecret`, `ShouldUnitIdentityBeSecret`, `ShouldUnitPowerBeSecret`, `ShouldUnitPowerMaxBeSecret`, `ShouldUnitSpellCastBeSecret`, `ShouldUnitSpellCastingBeSecret`, `ShouldUnitStatsBeSecret`, `ShouldUnitThreatStateBeSecret`, `ShouldUnitThreatValuesBeSecret`
  - general: `C_Secrets.HasSecretRestrictions`, plus the frame methods `HasSecretAspect`, `HasAnySecretAspect`, `HasSecretValues`, `IsPreventingSecretValues`, `IsAnchoringSecret`, `AddSecretAspect`
  - local `tools/forever-api/forever-api.json` from [Gethe/wow-ui-source forever](https://github.com/Gethe/wow-ui-source/tree/forever)
- **Combat log [P local; S]:** the 70862 docs list the event `COMBAT_LOG_EVENT_UNFILTERED`, but `CombatLogGetCurrentEventInfo` is not in the generated API docs. `C_DamageMeter` has 8 functions (`GetAvailableCombatSessions`, `GetCombatSessionFromID/FromType`, `GetCombatSessionSourceFromID/FromType`, `GetSessionDurationSeconds`, `IsDamageMeterAvailable`, `ResetAllCombatSessions`). - local allowlist. A guide says the combat log is unavailable to addons and meters rely on server-side `C_DamageMeter`. - [theforeverguides.com Details page](https://theforeverguides.com/addons/details/) [S]
- **New build today [P]:** the wow-ui-source `forever` branch committed "1.60.1 (70888)" on 2026-11-10 (after 70840 on 11-06 and 70862 on 11-07). It changed 16 files.
  - the only generated-API change: `PartyInfoDocumentation.lua` adds `{ Name = "isCrossShard", Type = "bool" }` to the party-invite info struct
  - new `Blizzard_Game/Camelot/EventImplementationUtils.lua`
  - nameplate and target-frame edits (`Blizzard_NamePlateUnitFrame.lua` +19, `Camelot/TargetFrame.lua` +8)
  - `Camelot/NewDefinitions.lua` settings -11 lines
  - [Gethe/wow-ui-source forever branch](https://github.com/Gethe/wow-ui-source/tree/forever)
- **Other API mirrors:**
  - Ketho/BlizzardInterfaceResources has a `forever` branch whose last commit is "1.60.1 (70532)" from 2026-10-21, so it lags. - [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources)
  - Ketho/vscode-wow-api: MIT, last push 2026-10-03. - [Ketho/vscode-wow-api](https://github.com/Ketho/vscode-wow-api)
  - wow-ui-source carries no license (Blizzard code). - [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source)
- **LimitedLuaResources caps:** no public source found (web search returned nothing relevant). The only record is this repo's 2026-10-21 stress test: "`LimitedLuaResources`: 500 timers, 10000 frames, 5000 FontStrings per addon, off (`Enabled = false`)". - local commit `2d9cc0d` / `CLAUDE.md`. Related documented APIs: `C_AddOnProfiler.GetAddOnMetric`, `GetApplicationMetric`, `GetOverallMetric`, `GetTopKAddOnsForMetric`, `CheckForPerformanceMessage` (local allowlist).
- **Secret data reports (Blizzard forums, from the repo's earlier research) [P forum]:**
  - [combo points are secret](https://us.forums.blizzard.com/en/wow/t/combo-points-are-secret-values/2352853)
  - [threat is secret](https://eu.forums.blizzard.com/en/wow/t/threat-is-a-secrethidden-value-in-addon-api-why/633885)
  - [settings wiped on restart (beta)](https://us.forums.blizzard.com/en/wow/t/uiaddon-settings-wiped-on-client-restart/2353992)
  - policy: [UI Add-On Development Policy](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534)
  - news: [Wowhead: Forever will have addon changes from Midnight](https://www.wowhead.com/news/wow-forever-will-have-addon-changes-from-midnight-382921)
- **Questie releases [A]:**
  - 12.1.0 (2026-10-12): "Handle secret system messages on Forever", "[Forever] Fix tooltips not showing in combat"
  - 12.2.0 (2026-10-23): "[Forever] Fix lua errors when clicking map icons during combat"
  - 12.6.4 (2026-11-07): "[Forever] Fix secret value errors when clicking chat links in instances", "Auto-hide Questie dropdown menus on WoW Forever"
  - 12.6.5 (2026-11-10): "[Forever] Fix reload ui from minimap dropdown"
  - GitHub license field: NOASSERTION
  - [Questie releases](https://github.com/Questie/Questie/releases)
- **DBM releases [A]:**
  - 12.1.13: "manually allow WOW_PROJECT_CAMELOT", "update infoframe to have methods for using secrets", "fix range radar lua errors in forever"
  - 12.1.15: "Expand scope of secret based trash/boss alert systems to forever across the board"
  - 12.1.17 (2026-10-22): "more secret protection if pulling boss with frame still open"
  - 12.1.18 (2026-10-26): "Fix isTanking on Forever", re-enable LibSpec
  - 12.1.19 (2026-11-03): "Fix toc load directive for libspec so it actually loads in forever"
  - latest 12.1.20 (2026-11-07)
  - [DBM releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)
- **WeakAuras [A]:** GPL-2.0; the latest release is 5.22.1 (2026-10-10) with no Forever entry. - [WeakAuras2 releases](https://github.com/WeakAuras/WeakAuras2/releases). Guides say there is no Forever version and point to forks (ForeverAuras, EverAuras, Musca Auras) that cannot do everything under combat restrictions. - [wowprivateservers census](https://wowprivateservers.vercel.app/news/forever-addon-ecosystem-census/) [S], [EverAuras](https://www.curseforge.com/wow/addons/everauras) [S]
- **Details [S]:** its GitHub releases stop in 2021, so they are no evidence. Guides list it as working within combat-value limits, next to Blizzard's built-in meter (Options > Advanced > Damage Meter). - [Details repo](https://github.com/Tercioo/Details-Damage-Meter), [theforeverguides](https://theforeverguides.com/addons/details/)
- **Beta fixes [S]:** build 70009 (2026-09-24) fixed unsaved settings and broken click casting. - search snippet across [howtoplayhub](https://howtoplayhub.com/wow-forever/addons-guide) / [timesaver addons list](https://timesaver.gg/blog/wow-forever-addons-save-beta-ui-before-launch)

### Inferences
- **Bundle actions:** regenerate the allowlist for 70888 (`build-allowlist.js`). It adds one struct field and no functions, so lint risk is low. CLAUDE.md's "live is 70862" line is now stale if 70888 is live (wow-ui-source tracks `wowf`).
- **Chat in instances:** Questie's 12.6.4 fix suggests chat hyperlink payloads and `CHAT_MSG_SYSTEM` text can be secret there. Any bundle feature parsing system or chat messages should gate on `issecretvalue` before string ops. This extends the repo's rule from aura reads to chat.
- **Reload from menus:** Questie's "fix reload ui from minimap dropdown" fits the repo's finding that `C_UI.Reload` needs a hardware event and can fail from a menu callback that is not a direct click. Unverified.
- **Frame anchors:** the 70425 unit-frame reskin and the 70888 TargetFrame and nameplate edits mean any feature anchoring to Blizzard unit frames should re-check after each build.

### Gaps
- Blizzard's own text of the 2026-09-15 secrets post (Discord) was not retrieved; only the wiki mirror was.
- There is no official list of which chat events or fields are secret on Forever.
- The `LimitedLuaResources` caps are undocumented publicly, and whether Blizzard will enable them on live is unknown.
- Details' Forever changelog lives off GitHub (CurseForge) and was not checked.
- Whether 70888 is live or only on the CDN is not confirmed by a Blizzard post.

## Q5. Data-collecting addons on Forever that publish their data

### Takeaway
Questie/QuestieDB is the one open, frequently updated Forever dataset (quests, NPCs including ranks, objects, quest XP from "traces"), and the bundle already reads it. Wowhead's Client/Looter collects Forever data but publishes only through Wowhead pages. AH-scan uploaders (TheWoWDB addon, ahprice) feed private sites. No public Forever loot or NPC dump was found.

### Cited Findings
- **QuestieDB, Forever entries in the Questie bundle releases [A]:**
  - 12.1.0 (2026-10-12): "refresh base data from October 10 snapshot"
  - 12.2.0 (2026-10-23): "add latest trace data", "Fix library book quests", "Fix spawn location of 'Zaal Stormshield'"
  - 12.4.0 (2026-11-02): "Add NPC ranks", "Add fraction digits for reputation spillover"
  - 12.6.1 to 12.6.4 (2026-11-05 to 11-07): "Update all databases" and "Update all translations"
  - 12.6.5 (2026-11-10): "Add quest XP from traces" and fixes for "The Sleeper Has Awakened"
  - [Questie releases](https://github.com/Questie/Questie/releases), [QuestieDB](https://github.com/Questie/QuestieDB) (API: `docs/api.md`, per the repo CLAUDE.md)
  - local install has `Questie_Forever.toc`, `Questie_Camelot.toc` and `QuestieDB`
- **Wowhead Client / Looter [S, search snippets of Wowhead Forever client pages; the page itself fetched empty]:**
  - changelog: "initial WoW Forever support" 2026-09-17, "updated combat log support for WoW Forever Beta", and updated loot tracking 2026-09-30
  - Windows-only app that uploads collected data to Wowhead; the in-game Looter shows NPC ids in tooltips
  - [wowhead.com/forever/client](https://www.wowhead.com/forever/client) (language variants: [es](https://www.wowhead.com/forever/es/client))
- **AH scan uploaders [S]:** "TheWoWDB - Forever" addon: scan, then "Send to TheWoWDB", then upload the saved file. - [TheWoWDB upload guide](https://thewowdb.com/addon/upload/). [ahprice.com](https://ahprice.com/) is an addon plus PC app with shared scans.
- **Static game data:** wago.tools serves Forever builds and DB2 tables, which the repo already uses for `SkillLineAbility`. - [wago.tools builds](https://wago.tools/builds); flavor data at [addons.wago.io/api/data/game](https://addons.wago.io/api/data/game)

### Inferences
- **QuestieDB NPC ranks (new 2026-11-02)** are a ready elite/rare flag for Rare Alert and Kill Value, through the public `QuestieDB` globals the bundle already uses. Numeric fields read 0, not nil (repo rule).
- QuestieDB's "trace data" suggests Questie collects live Forever observations from players. The mechanism and its terms were not verified, and the bundle should only read the shipped DB, never re-publish it.
- With the Blizzard `static-forever` item endpoint missing 43% of ids and Wowhead Looter data not exportable, wago.tools DB2 plus QuestieDB remain the practical offline sources for the bundle's generators. cmangos classic-db, used by Kill Value and Disenchant Value, is Classic Era data, not Forever.

### Gaps
- Questie and QuestieDB licenses read NOASSERTION on GitHub and were not checked in the files.
- Wowhead Looter's data terms and current client version were not retrievable.
- No public Forever loot, drop-rate or NPC export (CSV/JSON) was found.
