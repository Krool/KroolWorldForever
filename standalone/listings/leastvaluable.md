# KW Least Valuable

- **Folder:** KW_LeastValuable
- **Main category:** Bags & Inventory. **More:** Auction & Economy.
- **Relations:** Auctionator, optional.
- **Logo:** `standalone/logos/leastvaluable.png`

## Summary

A copper coin on the bag slot worth the least, so you know what to sell or drop first. When your bags are full and you loot, it says whether the loot is worth making room for.

## Description

- A copper coin marks the bag slot worth the least: its whole stack, at the best of its vendor price, auction price and disenchant value.
- It never marks quest items, keys, ammunition, class reagents, profession tools, unopened containers (clams, lockboxes), equipment-set gear or worthless items like the Hearthstone. `/kwl ignore` skips anything else you keep.
- When your bags are full and you try to loot, a card beside the loot window names that item and its value against the loot's, and says whether the loot is worth making room for. Its arrows show the next cheapest items, and Never Mark stops one from being marked (`/kwl unignore` brings it back).
- The coin shows in the default bags. With a bag addon, the tooltip line and `/kwl` still work.
- The card keeps off your open bags, and you can drag it.
- The card has a Delete button for the item it shows. It deletes only when you click it, and it asks first. You can switch the question off (a rare or better item still asks), or the button itself. Nothing is ever deleted by itself.
- Auction prices come from Auctionator. Without it, it goes by vendor prices and leaves greens unmarked.

`/kwl` lists the five least valuable slots. Settings: Esc > Options > AddOns > KW Least Valuable.

Part of [Krool World Forever](https://www.curseforge.com/wow/addons/krool-world-ui), the bundle with every KW addon in one. Its page links each of them. Install one or the other: next to the bundle, this copy switches itself off.

**Found a bug, or want something added?** Comment on this page, or open an issue on [GitHub](https://github.com/Krool/KroolWorldForever/issues). For a bug, type `/kwl errors` in game and include what it prints.

Open source (MIT): https://github.com/Krool/KroolWorldForever

[Donate](https://ko-fi.com/kroolworld)
