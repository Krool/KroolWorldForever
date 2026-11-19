# Market Movers

After Auctionator scans the auction house, a window shows what is priced unusually, in four tabs:
Materials, Other, Bargains and My Bags. Gear is left out. Read only: it never buys, bids, posts or
cancels.

Owner's requests:
- 2026-11-17: "an AH report when auctionator scans and surfaces things that have shifted the most
  in value over the past day focusing on like common trade materials as opposed to obscure things
  but maybe its two sections. probably exclude gear here."
- 2026-11-18, after the first real lists and a look at another addon (Midas): easier to read,
  graphs, fits the game, not obtrusive, does not open over other windows, "consider up and down.
  and oddities, elements worth buyings below market price".

**Status:** released in 0.21.0 (2026-11-18), in the bundle and as KW Market Movers. It was held
(owner's install only) from 2026-11-17 until the owner said "we can make an addon for this ... and
put it in the main bundle".

```
Market Movers
Alliance house, last scan today 16:12. Usual: up to 3 days before.
 Materials (5)    Other (2)    Bargains (3)    My Bags (4)
Item                 Trend    Usual      Now   Change  Listed
Rising (2)
[ore] Copper Ore x16  _/      12s        18s    +50%      90
Falling (3)
[cloth] Silk Cloth    ‾\      10s         5s    -50%     200
```

## What the first real lists taught (2026-11-18)

The first version compared the latest scan with the day before and sorted by percent. The owner's
first real list was all rises, led by "+3652%".
- **The cheap stock had sold.** That row was listed 48, was 389: what was left was the dear tail.
  The row now shows that (amber units, and a line in the tooltip).
- **A percent favors rises.** A drop cannot pass -100%; a rise has no limit. Moves are now ranked
  by the ratio (a doubling and a halving are the same size), rising and falling have their own
  lists, and a rise of five times or more reads "12x".
- **One day is a weak baseline.** "Usual" is now the median of up to seven earlier days.
- **Thin items are noise.** An item with three listed is one seller's price, not a market.
- The change column cut off five-digit percents, half the names had not loaded, and "1g 0s 69c"
  carried zeros nobody needs.

## Where the prices come from

**Not from Auctionator's history.** Auctionator keeps a daily low, high and quantity per item, but
only internally. Its API v1 has no history and no item list, and the repo rule is API v1 only
(`docs/research/data-sources/prices_and_addon_api.md`).

**From the auction house itself.** Auctionator's scan on Forever is a browse scan: an empty browse
query, paged until `C_AuctionHouse.HasFullBrowseResults()`. When the scan's prices are processed,
Auctionator calls our `RegisterForDBUpdate` callback (`root.OnAuctionPrices`). The client's
`C_AuctionHouse.GetBrowseResults()` then still holds every listed item with `minPrice` and
`totalQuantity`. That is Blizzard's API, and it is on the Forever allowlist.

**What counts as a full scan:** the last browse query was empty and unfiltered, and
`HasFullBrowseResults()` is not false.
- A `hooksecurefunc` on `C_AuctionHouse.SendBrowseQuery` sees every query (Auctionator's go through
  it too) and sets `ns.lastQuery` to "full" or "search". Recording sets it to "recorded", so a
  later callback for the same results (a price refresh) is not counted again.
- The same callback also fires after ordinary searches. Those are not recorded: averaging them in
  would weigh the items you search for.
- A second full scan within 60 seconds of a recorded one is the same scan.
- Without `hooksecurefunc` the old size rule applies: at least 200 results and at least 40% of the
  last full scan's size. That rule can take a broad search for a scan on a small house, which is
  why the query is watched.

## The record

`KroolWorldForeverDB.features.movers`:
- `ah[<faction>].days[<day>][itemID] = { s = sum of the scans' lowest prices, n = scans, q = most
  units seen }`. The day is local days since 2020-01-01, like Auctionator's scan day.
- `ah[<faction>].now = { at = time, items = { [itemID] = { p = lowest price, q = units } } }`: the
  latest full scan.
- `ah[<faction>].size`: about how many results a full scan has (only the no-hook rule reads it).
- `vendor[itemID]`: what a vendor pays (0: nothing). Learned from `C_Item.GetItemInfo` after a
  scan, 60 items every 0.1s, and kept: it never changes.
- `pos`: where the owner dragged the window. `tab`: the tab last open.

**Per faction:** Alliance and Horde houses list different things. Auctionator's own key on Forever
was the ruleset ("PvE"), which mixed them, until its version 348 (2026-11-18) added the faction.

**Days kept:** fourteen. Older days are pruned on every recorded scan and at login.

**Left out when recording:**
- gear (`C_Item.GetItemInfoInstant` classes 1 container, 2 weapon, 4 armor, 11 quiver, 17 battle pet);
- battle pets (`itemKey.battlePetSpeciesID > 0`);
- anything not listed;
- any secret value.

When one item is listed under two keys, the cheapest price and all units count.

## The report

- **Now:** the latest full scan's lowest price.
- **Usual:** the median of each earlier day's average lowest price, over at most seven days before
  the scan's day. Usual units is the median of each day's most units. With no earlier day, the
  item is not compared.
- **Change:** now / usual - 1. Lists are sorted by |ln(now / usual)|, ties by item id.

**The lists** (`ns.Report()`; each is cut at "Rows Per List", `total` has the full counts):
- `tradeUp`, `tradeDown`: class 7 (Trade Goods) listed in at least "Common At" units (default 40),
  now or usually.
- `otherUp`, `otherDown`: everything else listed in at least "Ignore Under (Listed)" units
  (default 10), now or usually.
- Both need a move of "Smallest Change" (default 10%) and a price of "Ignore Under (Silver)"
  (default 1s) now or usually.
- `vendor`: the lowest price is under what a vendor pays. Sorted by the gain on each. Needs no
  history. Only the cheapest listing is known to be that low, and the tooltip says so.
- `cheap`: at least "Bargain At" (default 30%) under usual, usual at least the price floor, and
  usually at least "Ignore Under (Listed)" units: something that normally has stock.
- `bags`: every item in the bags that has a usual price, the furthest above usual first (at most
  40). The tooltip says whether it is a good time to sell.

## The window

- **Tabs:** Materials, Other, Bargains, My Bags, each with its count. The last tab open is kept.
- **Row:** icon, name (and "x16" when you hold some), a trend line, usual, now, change, units listed.
  - **Trend:** each earlier day's average and the price now as a line (`CreateLine`), over a faint
    line at the usual price. Green when now is above usual, red below.
  - **Listed** is amber when stock is under half the usual.
  - **Money** is short: "22g", "1g 13s", "28s 71c".
- **Hover:** the item tooltip, plus now, usual, each day behind it (scans and units), units now and
  usually, the vendor price, and what your bags hold.
- **Click:** while the house is open, runs Auctionator's `MultiSearchExact` for the item.
  **Shift-click:** `HandleModifiedItemClick`, which puts the link in chat. The footer says both.

**Where it opens:**
- A place the owner dragged it to wins (`/kwm reset` forgets it).
- Otherwise, with the auction house open: beside it on the right, or the left, wherever there is
  room; with no room, at the right edge of the screen.
- Otherwise the middle.

**When it opens:**
- **By itself:** after the first full scan of each auction house visit, when something moved or
  there is a bargain. It then closes with the auction house. Later scans in that visit only refresh
  it, so autoscan every 30 minutes does not keep reopening it. The option is "Open After A Full
  Scan".
- **The auction house button:** a small button above the house's top right corner, "Movers: 14, 3
  bargains". A click opens or closes the window. The option is "Button On The Auction House".
- **On request:** `/kwm`, `/kwm bargains`, `/kwm bags`, the hub's Open button, or the compartment
  for the standalone. Opened this way it stays when the house closes.
- **`/kwm print`:** the top three of each list in chat.

## Not copied from Midas

A price chart per item, and odds of selling at a price. Both need weeks of history and a model of
sales; this record is two weeks of lowest prices.

## Known limits

- **Checked in the game only by the owner's use (2026-11-18).** A session with it loaded logged no
  errors, and the owner then asked for the release. No screenshot of the rewritten window, the
  auction house button or the docking has been reviewed.
- **Lowest price only.** A browse result has no depth: one cheap listing is "the price". Usual
  dampens that on the baseline side; on the "now" side a single cheap listing is a real bargain,
  and a single dear one only shows when the cheaper stock is gone.
- **`minPrice` may be a bid.** If the client reports a bid-only listing's bid as the lowest price,
  a "bargain" may not be a buyout. The vendor tooltip says to check.
- **First day:** with nothing to compare, the window says the first comparison comes with
  tomorrow's scan.
- **Neutral houses:** a neutral house (Booty Bay and the like) is recorded under the player's
  faction.
- **Autoscan off:** with Auctionator's autoscan off, nothing is recorded until you press its Scan
  button.
- **Replicate scan on:** with Auctionator's "replicate scan" on, it uses `ReplicateItems`, not
  browse, so nothing is recorded. The owner's config has it off.

## Tests

`tools/test/movers` covers:
- what is a full scan: the query (text, class filter, filter, level range, secret), a broad search
  before any scan, a small house, still-paging browses, repeat callbacks, two scans in a minute;
- what is recorded: gear, bags and pets left out; secret values skipped; vendor prices learned;
- the report: the median usual, the six lists, bag marks, ranking a halving against a rise, each
  option, the row cap and totals;
- the record over time: a week's gap, pruning at two weeks, and separate faction records;
- the window: the tabs and their counts, rows, the trend's points, the vendor row, tooltips, click
  to search, shift-click;
- where it opens (right, left, edge, dragged, reset), the auction house button, opening once per
  visit and closing with the house;
- the short money and change text, `/kwm print`, the hub line, and `/kwf movers off`.
