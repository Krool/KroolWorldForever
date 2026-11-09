# Kill Value

A feature (`killvalue`) of the Krool World Forever bundle addon (one addon, `KroolWorldForever`).
Expected gold per kill on creature tooltips, for WoW Forever (Interface 16001).

`value = average coin drop + sum(drop chance x average stack x item price)`

Hover a hostile creature (or its corpse): the tooltip gets a `Kill value` line, the top
contributors with their price source, and a `rare drops` line for the sub-0.1% tail, which is
kept out of the total. If you can skin the creature (or herb or mine it), its gathering value
is added and listed. The line is tagged with where the numbers come from:
`(baseline)`, `(learned, n kills)`, `(blended)`, or `learning (n kills)` while a creature has
no baseline and fewer than 3 looted corpses.

Nothing is looked up inside instances: unit tooltip data is secret there.

## Data: two layers, blended

1. **Era baseline** (`Data.lua`, generated). Loot tables from the cmangos classic-db vanilla
   1.12 world database: coin range, creature loot with groups and references resolved the way
   the server rolls them, skinning loot, plus vendor price, quality and bonding for every
   droppable item. Forever may have rebalanced loot, and it adds creatures this database has
   never heard of, so this is only a prior.
2. **Learned** (`KroolWorldForeverDB.features.killvalue`, per account). Every time you open a loot
   window on a creature corpse, each slot is attributed to its source GUID, then to an NPC id.
   Per NPC it stores corpses looted, total coin, and item quantities. A corpse counts once
   (deduped by full GUID, with a memory of the last 200). Storage is capped at 2500 creatures
   and 100 items per creature.

Blend, per item (coin works the same way), with K = 10 pseudo-kills:

    estimate = (observed + K x baselineRate) / (corpses + K)

With no baseline, observed-only numbers are used once 3 corpses are looted. Rates are in
quantity per corpse, so they are comparable with the baseline's `chance x average stack`.

### Caveats

* **Era baseline, not Forever truth.** Data is `Full_DB/ClassicDB_1_12_1_z2815` from
  github.com/cmangos/classic-db. The repo's incremental `Updates\*.sql` files are not applied.
  Item and creature ids that Forever reused for different content will show the old numbers
  until you have looted enough to correct them.
* **Looted corpses only.** A creature that sometimes drops nothing never opens a loot window, so
  learned rates are per looted corpse and run slightly high for such creatures. The baseline
  prior damps this.
* Pickpocketing is ignored (a loot window on a live creature). Fishing, objects and item
  containers are ignored (their GUIDs are not creatures). A second window on a corpse you
  already looted, such as skinning, is ignored.
* **Gathering windows are not loot (0.6.0).** Skinning a corpse that had nothing to loot opens
  the skinning window first. A window is treated as gathering when it has no coins, every item
  is a gathering yield of one kind (any baseline creature skins, herbs or mines into it, and this
  creature's baseline loot does not list it), and you know that profession (or the skill cannot
  be read). It is not recorded, so a corpse you only skinned does not count. Before 0.6.0 such
  windows were learned as loot; a one-time cleanup removes those items and keeps the corpse
  counts (launch data: Light Leather and Ruined Leather Scraps on 22 creatures).
* **Gathering in the total (0.6.0).** Gathering values come from the baseline only. When you
  know the profession (Skinning 393, Herbalism 182, Mining 186, or their Forever child lines
  2947, 2944, 2946, read with `C_SkillInfo.GetSkillLineInfoByID`) with enough skill for the
  creature, its value joins the total (`Add My Skinning To The Total`, on). Needed skill is the
  classic rule: (level - 10) x 10 below level 20, level x 5 from 20 on, against the baseline's
  creature level; skill bonuses count. Known profession but too low: a `skinning, needs N` line.
  Otherwise the line shows only with `Show Skinning Value`.
* Quest-conditional loot rows and pickpocket loot are not in the baseline. Container contents
  (clams, lockboxes) are not valued.
* Forever GUIDs have obfuscated server and spawn parts; only the 6th dash field (the NPC id) is
  read, and a GUID that does not parse is treated as "unknown creature". Verified live: by
  2026-11-07 the saved data held 140 creatures learned this way, including ids the classic
  baseline does not have (260157).

## Prices

Each item takes the best of:

* **Vendor:** the client's sell price (`C_Item.GetItemInfo`). If the item is not cached yet the
  client is asked to load it and the baseline vendor price is used until it arrives.
* **Auctionator** (optional): `Auctionator.API.v1.GetAuctionPriceByItemID`, minus the auction
  house cut (default 5%). Never for bind-on-pickup or grey items.

Quest items are worth 0. Results are cached per creature (64 creatures, 10 minutes) and
refreshed when settings change, when new loot is learned for that creature, when the auction house
closes, and (0.13.1) when an Auctionator scan finishes (`root.OnAuctionPrices`).

**Old prices (0.13.1).** Each auction-priced drop carries its age (`root.AuctionAge`, days since
Auctionator last saw it). When drops priced from auction data over 3 days old (`root.STALE_DAYS`)
make up at least a tenth of the total (counted skinning included), the tooltip total says "old
prices" and `/fkv` prints how much. Drop lines date an old price: "(AH, seen 5 days ago)". The old
price still counts: the value already takes the higher of vendor and auction, and dropping it would
undervalue items that still sell.

## Commands

`/fkv` (alias `/killvalue`)

| command | effect |
|---|---|
| `/fkv` | breakdown for your target |
| `/fkv id <npcId>` | breakdown for any creature id |
| `/fkv status` | baseline size, learned totals, Auctionator detection, gathering skills |
| `/fkv config` | every setting with its value |
| `/fkv options` | open the settings panel (also the addon compartment button) |
| `/fkv reset` | restore default settings |
| `/fkv reset learned` | erase learned loot data |
| `/fkv help` | command list |

The tooltip line's on/off is the bundle's per-feature switch (`/kw killvalue on|off` or the
Enabled checkbox). While off there are no tooltip lines and no loot is recorded.

Switches (all saved per account): `learn` (record loot, on),
`vendor` (on), `ah` (Auctionator, on), `gather` (your skinning in the total, on), `skin`
(skinning line for creatures you cannot skin, off), `friendly` (show on friendly creatures,
off), `hello` (login message, on). Values: `detail <0-10>` (contributor lines, default 3),
`cut <pct>` (default 5), `rare <pct>` (default 0.1). Commands change settings through the
settings panel, so an open panel shows the new value.

Public API: `KroolWorldForever.KillValue.GetKillValue(npcId)` returns copper per kill or nil.

## Development

    node tools\killvalue-data\gen-data.js

downloads the classic-db dump into `tools\killvalue-data\sqlcache` (gitignored) on first run and rewrites
`KroolWorldForever\Features\KillValue\Data.lua`. Current output: 5046 creatures, 462 reference pools, 6645 items, about 2.7 MB.

    cd tools\test
    npm install
    npm test

Syntax-checks the Lua, runs the whole bundle under fengari with a stubbed Forever client (GUID
parsing including obfuscated, malformed and secret values, blending math, corpse dedupe and
caps, price guards, loot capture, gathering windows and skills, the one-time cleanup on real
launch data, tooltip degradation, slash commands), then runs the repo's `api-lint.js` against
the Forever API allowlist.
