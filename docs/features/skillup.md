# Skill-Up Odds

Folder: `KroolWorldForever/Features/SkillUp/` (key `skillup`, `/kwu`, `/skillup`).

The chance that a craft gives a skill point, shown in the crafting window, and a Next Skill Point
panel that ranks learned recipes by the gold a point costs on average.

## The odds: the line, tuned by the account's crafts (0.13.0)

- The crafting window (Forever uses the modern `Blizzard_Professions` UI) shows one of three
  skill-up arrows from `recipeInfo.relativeDifficulty`: Optimal (orange), Medium (yellow), Easy
  (green). Nothing finer reaches the client.
- Each recipe's yellow and grey skill are client data: `SkillLineAbility.TrivialSkillLineRankLow`
  and `TrivialSkillLineRankHigh` (wago.tools, build 1.60.1.70862). Green is
  `floor((yellow + grey) / 2)`; every recipe sampled against the classic tables matched.
  `recipeInfo.maxTrivialLevel` carries the grey value too; yellow is not in the API.
- The chance itself is rolled on the server and appears in no client table or API. Blizzard never
  published it; the wiki calls only orange (always) and grey (never) certain. The common community
  estimate is a straight line: `line = (grey - skill) / (grey - yellow)`, 1 at yellow.
- **Chance = min(1, k x line)**, `k = (got + 10) / (expected + 10)` over every yellow and green
  craft on the account: `expected` adds up the line's chance for each craft, `got` counts the crafts
  that gave a point. `ns.PRIOR` (10) holds k near 1 until there are real numbers. Points a craft =
  chance x (points / crafts that gave one), for double points.
- **Why (owner's decision, 2026-11-09).** 0.11.0 to 0.12.2 showed ten separately measured ranges
  (position between yellow and grey) and ?% under 10 crafts. With 10 to 30 crafts a range, next
  ranges disagreed wildly (50-60%: 7 of 10; 60-70%: 8 of 26), so one skill point could double a
  recipe's gold a point and reorder the panel, and a recipe that had just turned yellow showed ?%
  and sorted below nearly-grey ones. The owner's 174 yellow and green crafts then fit the line: 67
  points where it expected 62.7 (k 1.059), every range within noise of it but one.
- The ten ranges are still counted (now with `exp`, the line's expectation in each) as the check on
  the line: `/kwu` prints got against expected per range, and the tooltip shows the range the skill
  is in. Stats from before 0.13.0 got `exp` rebuilt once from the raw log (`st.v = 2`).

## How it measures

- `UNIT_SPELLCAST_START` for a known recipe reads the skill (before); `UNIT_SPELLCAST_SUCCEEDED`
  queues the craft; the skill after is read at the next skill change, the next craft's start, or
  1.5 s later, whichever is first. The gain is after minus before.
- Skipped, not counted: crafts with no reading from before the cast (instant crafts), crafts at the
  skill cap, crafts when the skill could not be read.
- The skill compared with the thresholds is the base skill, or base plus bonus (racials), whichever
  gives the arrow the client shows. When neither does, the craft is logged but not put in a range
  (`mismatch`, in `/kwu status`).
- Pooled account-wide (`SavedVariables`, not per character: every character on the WoW account
  adds to it; it reaches disk on logout, `/reload` or a clean exit, so a crash loses that session).
  Yellow and green crafts go into ten ranges by position `(skill - yellow) / (grey - yellow)`, each
  counting crafts, crafts that gave a point, points and the line's expectation. Orange and grey have
  a counter each; a measured orange rate (10 crafts) replaces the rule, with the 95% Wilson span in
  the tooltip. Per-recipe counts are kept too.
- `ns.db.stats.log` keeps the last 4,000 crafts raw (`recipe:skill:bonus:gain:arrow:time`), so the
  pooling (by position, across professions) can be checked later against per-profession data.
- The skill is read through `C_TradeSkillUI.GetProfessionInfoByRecipeID`, then
  `GetProfessionInfoBySkillLineID(child line)`, then `C_SkillInfo.GetSkillLineInfoByID` (the
  higher of the base and child line). `/kwu status` names the one that answered.

## Cost per point

- A craft: each Basic reagent slot at the cheaper of Auctionator's price and the vendor price seen
  at a merchant (`MERCHANT_SHOW`: trade goods and reagents, not extended cost). Optional reagents are
  left out. A reagent with no price leaves the cost unknown and is named.
- Minus the result's vendor price (option), or its auction price after the 5% cut when higher
  (option, off by default).
- Gold a point = net cost / points a craft gives on average (orange counts 1 until measured).

## Auctionator (0.13.0)

- `root.AuctionPrice` is Auctionator's last-seen minimum buyout. `root.AuctionAge`
  (`API.v1.GetAuctionAgeByItemID`) is the days since the item was last seen at auction.
- Stale = older than `root.STALE_DAYS` (3, `Core/Prices.lua`, shared with Kill Value and
  Disenchant Value since 0.13.1). A stale reagent price still prices the craft (better than
  no cost) but loses to any known vendor price, and the tooltip ("Auction prices up to N days old")
  and the panel row ("old prices") say so. A stale price never values the result (resale option).
  Each reagent's source in the tooltip carries its age ("auction, today").
- `root.OnAuctionPrices(fn)` registers once with `API.v1.RegisterForDBUpdate` (full and
  incremental scans) and fans out; Skill-Up Odds re-prices the open panel. `/kwu status` says
  whether the hook took.
- Not done: Auctionator keeps only a daily minimum, so one cheap listing sets the price. Its mean
  price (`Database:GetMeanPrice`) is internal, not `API.v1`, so it is not used.

## A steady panel (0.13.0)

- `ns.Rank` is the plain ranking: tier (odds and cost known, cost only, neither), then gold a point
  (or craft cost), then name.
- The panel passes it through `ns.Steady(list, previous order)`: recipes start in the order on
  screen (new ones after), then each moves up past every recipe it clearly beats: a better tier, or
  a gold a point cheaper by more than `ns.STEADY` (10%, at least 1 copper). Opening the panel or
  switching profession starts from the plain ranking.

## Window hooks

- Rows: `ScrollUtil.AddInitializedFrameCallback` on `ProfessionsFrame.CraftingPage.RecipeList.ScrollBox`
  (fires after Blizzard's own row init; the source says it is there for addons). A FontString at the
  row's right edge, the name shortened to clear it, a hit frame with `SetPropagateMouseClicks(true)`
  so a click still selects the recipe.
- Forever's `ProfessionsFrame` has a column of profession tabs down its right edge (Camelot
  `Blizzard_ProfessionsFrame.xml`: `ProfessionsOverviewTab` at TOPRIGHT y -60, then the shown
  `rightProfessionTabs`, each a `LargeSideTabButtonTemplate` sized to the `common-sidetab` atlas).
  0.12.0 docked the panel over that column; seen in game 2026-11-07.
- Panel: a `ButtonFrameTemplate` parented to `ProfessionsFrame`, docked at its TOPRIGHT plus the
  overview tab's width, so it sits past the tab column. Closing it sets the Panel option off
  (`root.SetOption`). Its toggle is our own `LargeSideTabButtonTemplate` tab under the lowest
  shown profession tab (re-placed after `RefreshRightTabs`), unchecked so it never looks like the
  open profession. Row click: `C_TradeSkillUI.OpenRecipe`.
- Recipes are enumerated from the data (the profession's line), not `GetAllRecipeIDs` /
  `GetFilteredRecipeIDs`: those are not in the generated API docs, so the lint rejects them.

## Regenerating the data

```
Invoke-WebRequest "https://wago.tools/db2/SkillLineAbility/csv?build=<build>" -OutFile sla.csv
node tools/skillup-data/gen-skillup.js sla.csv <build>
```

## Unverified in-game (0.11.0)

- Which API reads the skill on Forever, and that the skill-up has arrived by the next skill change
  or within 1.5 s.
- That the rows look right (the odds at the right edge, the name not overlapping) and the panel
  docks cleanly beside the window.
- Whether racial bonuses count toward the arrows (the mismatch count says).
- Working Overtime (Legacy perk): guides disagree whether it raises the chance or adds a second
  point. A second point shows as a gain of 2 and raises "points a craft". The owner's log shows 1.06
  points per craft that gave a point (2026-11-09), so second points do happen.
