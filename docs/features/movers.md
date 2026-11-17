# Market Movers

After Auctionator scans the auction house, a window lists the items whose price moved most since the
day before. It has two lists, Trade Materials and Other Items, and leaves gear out. Read only: it
never buys, bids, posts or cancels.

Owner's request (2026-11-17): "an AH report when auctionator scans and surfaces things that have
shifted the most in value over the past day focusing on like common trade materials as opposed to
obscure things but maybe its two sections. probably exclude gear here."

**Status:** held. The owner said "dont deploy to anyone else yet just put it on my version". It is
`"held": true` in `standalone/addons.json`, so releases leave it out (see the repo CLAUDE.md). The
owner's game has it through the dev junction.

```
Market Movers
Last scan today 16:12, compared with yesterday.
Item                      Before        Now   Change  Listed
Trade Materials (2)
[ore] Copper Ore           12s 0c     18s 0c    +50%      90
[cloth] Linen Cloth         3s 0c      2s 40c   -20%     420
Other Items (1)
[potion] Healing Potion    20s 0c     30s 0c    +50%      20
```

## Where the prices come from

**Not from Auctionator's history.** Auctionator keeps a daily low, high and quantity per item, but
only internally. Its API v1 has no history and no item list, and the repo rule is API v1 only
(`docs/research/data-sources/prices_and_addon_api.md`).

**From the auction house itself.** Auctionator's scan on Forever is a browse scan: an empty browse
query, paged until `C_AuctionHouse.HasFullBrowseResults()`. When the scan's prices are processed,
Auctionator calls our `RegisterForDBUpdate` callback (`root.OnAuctionPrices`). The client's
`C_AuctionHouse.GetBrowseResults()` then still holds every listed item with `minPrice` and
`totalQuantity`. That is Blizzard's API, and it is on the Forever allowlist.

**What counts as a full scan:** at least 200 results, `HasFullBrowseResults()` not false, and at
least 40% of the last full scan's size. That last check rules out a broad search of your own.
- The same callback also fires after ordinary searches. Those are not recorded: averaging them in
  would weigh the items you search for.
- A second callback within 60 seconds of a recorded scan is the same scan, and is not counted twice.

## The record

`KroolWorldForeverDB.features.movers.ah[<faction>]`:
- `days[<day>][itemID] = { s = sum of the scans' lowest prices, n = scans, q = most units seen }`.
  The day is local days since 2020-01-01, like Auctionator's scan day.
- `now = { at = time, items = { [itemID] = { p = lowest price, q = units } } }`: the latest full
  scan.
- `size`: how many results that scan had.

**Per faction:** Alliance and Horde houses list different things. Auctionator's own key on Forever
is the ruleset ("PvE"), which mixes them.

**Days kept:** four. Older days are pruned on every recorded scan and at login.

**Left out when recording:**
- gear (`C_Item.GetItemInfoInstant` classes 1 container, 2 weapon, 4 armor, 11 quiver, 17 battle pet);
- battle pets (`itemKey.battlePetSpeciesID > 0`);
- anything not listed;
- any secret value.

When one item is listed under two keys, the cheapest price and all units count.

## The report

- **Now:** the latest full scan's lowest price.
- **Before:** the average of the scans' lowest prices on the newest earlier day that has the item.
  That day is at most three days before the scan. With no such day, the item is not compared.
- **Change:** now / before - 1.
- **Trade Materials:** class 7 (Trade Goods), listed in at least "Common At" units (default 40),
  now or before.
- **Other Items:** everything else.

**Filters:**
- Items under "Ignore Under" (default 1s) both now and before are left out.
- Moves under "Smallest Change" (default 10%) are left out.

**Sorting:** each list is sorted by the size of the move, with ties by item id, and cut at "Rows
Per List" (default 12). `moved` counts every mover before the cut.

## When the window opens

- **By itself:** after the first full scan of each auction house visit, when the report has at
  least one mover. The visit starts at `AUCTION_HOUSE_SHOW`. Later scans in that visit only refresh
  the window if it is open, so autoscan every 30 minutes does not keep reopening it. The option is
  "Open After A Full Scan".
- **On request:** `/kwm`, the hub's Open button, or the compartment for the standalone.
- **`/kwm print`:** the top five of each list in chat.

**Rows:**
- **Click:** while the house is open, runs Auctionator's `MultiSearchExact` for the item.
- **Shift-click:** `HandleModifiedItemClick`, which puts the link in chat.
- **Hover:** the item tooltip, plus Now, Before (which day and how many scans), and units listed now
  and before.

## Known limits

- **First day:** with nothing to compare, the window says the first comparison comes with
  tomorrow's scan.
- **Neutral houses:** a neutral house (Booty Bay and the like) is recorded under the player's
  faction.
- **Autoscan off:** with Auctionator's autoscan off, nothing is recorded until you press its Scan
  button.
- **Replicate scan on:** with Auctionator's "replicate scan" on, it uses `ReplicateItems`, not
  browse. The browse results are then not the whole house, so nothing is recorded. The owner's
  config has it off.

## Tests

`tools/test/movers` covers:
- what is recorded: gear, bags and pets left out; small searches, still-paging browses and repeat
  callbacks not recorded; secret values skipped;
- the report: the day average, the two lists and Common At, each filter, sorting and the row cap;
- the record over time: a three-day gap, pruning, and separate faction records;
- the window: opening by itself once per visit, rows, click to search, shift-click, the tooltip;
- `/kwm print`, the hub line, and `/kwf movers off`.
