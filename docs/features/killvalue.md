# Kill Value

A feature (`killvalue`) of the Krool World Forever bundle addon (one addon, `KroolWorldForever`).
Expected gold per kill on creature tooltips, for WoW Forever (Interface 16001). A port and
redesign of OctoKillValue (1.12).

`value = average coin drop + sum(drop chance x average stack x item price)`

Hover a hostile creature (or its corpse): the tooltip gets a `Kill value` line, the top
contributors with their price source, and a `rare drops` line for the sub-0.1% tail, which is
kept out of the total. The line is tagged with where the numbers come from:
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
  already looted, such as skinning, is ignored. Skinning a corpse before looting it would
  record the skinning loot as that corpse's loot.
* Skinning and gathering values come from the baseline only and are never in the total.
* Quest-conditional loot rows and pickpocket loot are not in the baseline. Container contents
  (clams, lockboxes) are not valued.
* Forever GUIDs have obfuscated server and spawn parts; only the 6th dash field (the NPC id) is
  read, and a GUID that does not parse is treated as "unknown creature". This is unverified
  against a live client.

## Prices

Each item takes the best of:

* **Vendor:** the client's sell price (`C_Item.GetItemInfo`). If the item is not cached yet the
  client is asked to load it and the baseline vendor price is used until it arrives.
* **Auctionator** (optional): `Auctionator.API.v1.GetAuctionPriceByItemID`, minus the auction
  house cut (default 5%). Never for bind-on-pickup or grey items.

Quest items are worth 0. Results are cached per creature (64 creatures, 10 minutes) and
refreshed when settings change or when new loot is learned for that creature.

## Commands

`/fkv` (alias `/killvalue`)

| command | effect |
|---|---|
| `/fkv` | breakdown for your target |
| `/fkv id <npcId>` | breakdown for any creature id |
| `/fkv status` | baseline size, learned totals, Auctionator detection |
| `/fkv config` | every setting with its value |
| `/fkv options` | open the settings panel (also the addon compartment button) |
| `/fkv reset` | restore default settings |
| `/fkv reset learned` | erase learned loot data |
| `/fkv help` | command list |

The tooltip line's on/off is the bundle's per-feature switch (`/kwf killvalue on|off` or the
Enabled checkbox). While off there are no tooltip lines and no loot is recorded.

Switches (all saved per account): `learn` (record loot, on),
`vendor` (on), `ah` (Auctionator, on), `skin` (skinning line, off), `friendly` (show on
friendly creatures, off), `hello` (login message, on). Values: `detail <n>` (contributor lines,
default 3), `cut <pct>` (default 5), `rare <pct>` (default 0.1).

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
caps, price guards, loot capture, tooltip degradation, slash commands), then runs the repo's
`api-lint.js` against the Forever API allowlist.
