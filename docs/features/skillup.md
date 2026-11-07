# Skill-Up Odds

Folder: `KroolWorldForever/Features/SkillUp/` (key `skillup`, `/kwu`, `/skillup`).

The measured chance that a craft gives a skill point, shown in the crafting window, and a Next Skill
Point panel that ranks learned recipes by the gold a point costs on average.

## Why measured

- The crafting window (Forever uses the modern `Blizzard_Professions` UI) shows one of three
  skill-up arrows from `recipeInfo.relativeDifficulty`: Optimal (orange), Medium (yellow), Easy
  (green). Nothing finer reaches the client.
- Each recipe's yellow and grey skill are client data: `SkillLineAbility.TrivialSkillLineRankLow`
  and `TrivialSkillLineRankHigh` (wago.tools, build 1.60.1.70862). Green is
  `floor((yellow + grey) / 2)`; every recipe sampled against the classic tables matched.
  `recipeInfo.maxTrivialLevel` carries the grey value too; yellow is not in the API.
- The chance itself is rolled on the server and appears in no client table or API. Blizzard never
  published it; the wiki calls only orange (always) and grey (never) certain. The common community
  estimate (a straight line from 100% at yellow to 0% at grey) is unverified, so it is not used.

## How it measures

- `UNIT_SPELLCAST_START` for a known recipe reads the skill (before); `UNIT_SPELLCAST_SUCCEEDED`
  queues the craft; the skill after is read at the next skill change, the next craft's start, or
  1.5 s later, whichever is first. The gain is after minus before.
- Skipped, not counted: crafts with no reading from before the cast (instant crafts), crafts at the
  skill cap, crafts when the skill could not be read.
- The skill compared with the thresholds is the base skill, or base plus bonus (racials), whichever
  gives the arrow the client shows. When neither does, the craft is logged but not put in a range
  (`mismatch`, in `/kwu status`).
- Pooled account-wide by position: `(skill - yellow) / (grey - yellow)` in ten ranges. Orange and
  grey have a counter each. A range shows its rate at 10 crafts; the tooltip gives the 95% Wilson
  span. Per-recipe counts are kept too.
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
- Gold a point = net cost / points a craft gives on average (measured; orange counts 1 until
  measured). The panel lists odds-and-cost-known recipes first, cheapest point first, then recipes
  still measuring by craft cost.

## Window hooks

- Rows: `ScrollUtil.AddInitializedFrameCallback` on `ProfessionsFrame.CraftingPage.RecipeList.ScrollBox`
  (fires after Blizzard's own row init; the source says it is there for addons). A FontString at the
  row's right edge, the name shortened to clear it, a hit frame with `SetPropagateMouseClicks(true)`
  so a click still selects the recipe.
- Panel: a `ButtonFrameTemplate` parented to `ProfessionsFrame`, docked at its TOPRIGHT. Closing it
  sets the Panel option off (`root.SetOption`); an icon tab outside the window turns it back on.
  Row click: `C_TradeSkillUI.OpenRecipe`.
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
  point. A second point shows as a gain of 2 and raises "points a craft".
