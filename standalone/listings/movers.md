# KW Market Movers

- **Folder:** KW_MarketMovers
- **Main category:** Auction & Economy.
- **Relations:** Auctionator, required.
- **Logo:** `standalone/logos/movers.png`
- **Status:** held (2026-11-17): on the owner's install only, not released. No CurseForge project yet.

## Summary

After Auctionator scans the auction house, see which items moved most in price since the day before: trade materials that sell in quantity first, then everything else. Gear is left out.

## Description

- When Auctionator finishes a full scan of the auction house, a window lists the biggest price moves since the day before, in two lists:
  - **Trade Materials:** cloth, herbs, ore, leather and the like, when they are listed in quantity.
  - **Other Items:** everything else that isn't gear, such as potions, recipes and rare materials.
- Each row shows the price the day before, the price now, the change and the units listed. Hover a row for where the "before" price came from.
- Click a row to search that item in Auctionator. Shift-click to link it in chat.
- It keeps its own daily record of the scans, so the first comparison comes the day after your first scan.
- It opens once per auction house visit, after the first full scan, and only when something moved. Later scans in the same visit update it.
- Settings:
  - what counts as "in quantity";
  - the smallest change shown;
  - a price floor, so a few copper either way stays out;
  - rows per list.
- It never buys, bids, posts or cancels anything.

`/kwm` opens the window, and `/kwm print` puts the top moves in chat. Settings: Esc > Options > AddOns > KW Market Movers.

Part of Krool World Forever, which has every KW addon in one: https://www.curseforge.com/wow/addons/krool-world-ui. Install one or the other: next to the bundle, this copy switches itself off.

Open source (MIT): https://github.com/Krool/KroolWorldForever

[Donate](https://ko-fi.com/kroolworld)
