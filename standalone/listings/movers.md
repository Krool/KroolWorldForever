# KW Market Movers

- **Folder:** KW_MarketMovers
- **Main category:** Auction & Economy.
- **Relations:** Auctionator, required.
- **Logo:** `standalone/logos/movers.png`
- **CurseForge:** project 1815716 (created 2026-11-18).
- **Status:** released with 0.21.0 (2026-11-18).

## Summary

After Auctionator scans the auction house, see what is priced unusually: materials and other items that rose or fell against their usual price, bargains under the vendor price, and how the items in your bags stand. Gear is left out.

## Description

- When Auctionator finishes a full scan of the auction house, a window beside it shows what is priced unusually, in four tabs:
  - **Materials:** cloth, herbs, ore, leather and the like that are listed in quantity, rising and falling.
  - **Other:** everything else that isn't gear, such as potions and recipes, rising and falling.
  - **Bargains:** items listed under what a vendor pays for them, and items far under their usual price.
  - **My Bags:** what you carry, against its usual price, the best to sell first.
- "Usual" is the middle price of the last days, up to a week, so one odd day does not move it.
- Each row shows a small trend line, the usual price, the price now, the change and the units listed. Hover a row for the days behind the usual price.
- Click a row to search that item in Auctionator. Shift-click to link it in chat.
- It keeps its own daily record of the scans, so the first comparison comes the day after your first scan.
- The window opens beside the auction house, not over it, once per visit and only when there is something to show. It closes with the auction house. Drag it and it stays where you put it.
- A small button on the auction house shows the number of movers and bargains and opens the window.
- Settings:
  - what counts as "in quantity";
  - the fewest units listed for other items;
  - the smallest change shown;
  - how far under usual is a bargain;
  - a price floor, so a few copper either way stays out;
  - rows per list.
- It never buys, bids, posts or cancels anything.

`/kwm` opens the window, `/kwm bargains` and `/kwm bags` open those tabs, and `/kwm print` puts the top moves in chat. Settings: Esc > Options > AddOns > KW Market Movers.

Part of Krool World Forever, which has every KW addon in one: https://www.curseforge.com/wow/addons/krool-world-ui. Install one or the other: next to the bundle, this copy switches itself off.

Open source (MIT): https://github.com/Krool/KroolWorldForever

[Donate](https://ko-fi.com/kroolworld)
