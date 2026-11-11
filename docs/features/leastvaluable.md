# Least Valuable

A copper coin on the corner of the bag slot worth the least, so you know what to sell or drop first when your
bags fill up. Advice only: it marks a slot and never sells, moves or deletes anything.

```
[copper coin in the slot's top-right corner]
Least valuable in your bags                       30c
10 x 3c at a vendor
```

## What a slot is worth

- **The whole stack:** the item's best price times the stack size. Ten 3c fangs (30c) are worth
  more than one 5c scale, so the scale is marked.
- **Best price:** the highest of the vendor price, the item's own auction price (by link, so
  suffixes and item levels are told apart) and its disenchant value, with the 5% auction cut taken
  off the last two. This is Disenchant Value's `ns.Best`; it now also returns the copper.
- **Bound items** have no auction price. Their disenchant value counts only when you can disenchant
  yourself (`C_SpellBook.ContainsAnyDisenchantSpell`); an unbound item's counts either way.
- **Each slot on its own:** of two part stacks of one item, the smaller is the cheaper slot.
- **Ties:** the first slot in bag order (backpack slot 1 first).
- **Old prices** still count. The tooltip dates them ("price seen 5 days ago").
- **Bags only:** the backpack and the equipped bags (0 to `NUM_TOTAL_EQUIPPED_BAG_SLOTS`), never
  the bank. The reagent bag (bag 5, `ContainerFrame_IsReagentBag` in Mainline `ContainerFrame.lua`)
  is skipped too, since what is kept there is kept for crafting.
- **Rescans:** an open hub card refreshes after each bag change. An item still loading is noted by
  id, and only its own `GET_ITEM_INFO_RECEIVED` starts a rescan.

## Never marked

Without these rules the cheapest slot would often be something you keep.

| Left out | How it is told | Why |
|---|---|---|
| Worth nothing anywhere | no vendor, auction or disenchant value (`hasNoValue`, sell price 0) | Hearthstone, soul shards, conjured food: nothing to gain |
| Quest items | item class 12, or `GetContainerItemQuestInfo` says quest item or starts a quest | Quest Trash judges those |
| Keys | item class 13 | |
| Ammunition | item class 6 | arrows and shots are 0-2c each but in use |
| Class reagents | item class 5, plus Light Feather (17056, class 15) | Ankhs, candles, runes, seeds, powders |
| Profession tools | weapon subclass 14 (Mining Pick, Skinning Knife, Blacksmith Hammer, Arclight Spanner), 20 (fishing poles), and by id: the five runed enchanting rods, Philosopher's Stone, Gyromatic Micro-Adjustor, Salt Shaker | tools sell for 3-24c |
| Unopened containers | `hasLoot` (clams, lockboxes) | what they are worth is inside |
| Equipment-set gear | `GetContainerItemEquipmentSetInfo` | |
| Unpriced uncommon or better | unbound, green or better, no auction price and no disenchant value | a BoE green's vendor price says nothing about its worth; scan the auction house |
| Ignored items | `/kwl ignore` | anything else you keep |

Classes and ids come from the 1.12 item data (`tools/killvalue-data`, checked 2026-11-10):
weapon subclass 14 holds only the tools and test items, every class reagent is class 5 except
Light Feather, and the rods and stones are trade goods (class 7), so they go by id.

A common (white) item with no auction price counts at its vendor price, and the tooltip says "no
auction price". Without Auctionator everything is vendor priced, so greens are never marked; the
hub says "vendor prices only".

Items whose info has not loaded yet are left out and counted once `GET_ITEM_INFO_RECEIVED` brings
them. A locked slot (on the cursor, in a trade) still counts, so the coin does not jump while you
move an item.

## The coin

- Art: `coin-copper`, the copper coin beside your money under the backpack (Mainline
  `MoneyFrame.xml`, forever branch; in the forever atlas list), 15 pixels, still, in the slot's
  top-right corner. Blizzard uses the other corners: top-left for the junk coin and the upgrade
  arrow, bottom-right for the stack count.
- 0.16.0 had a gold glow breathing over the whole slot (`bags-glow-white`); the owner could not
  see it and asked for a still icon in a corner (0.16.1).
- One frame of ours, parented to the marked slot's button and laid over it, above the cooldown
  swipe. It takes no mouse, so the button works as before. Nothing is written onto Blizzard's
  frames.
- Forever loads Mainline's bag code (`[Family]\ContainerFrame.lua`; the camelot override only has
  two small functions). Every default bag frame, combined or separate, redraws its buttons in
  `UpdateItems`; a `hooksecurefunc` on each frame moves the coin onto whatever button shows the
  slot after a redraw (buttons come from a pool, so a slot can change button).
  `ContainerFrameUtil_GetItemButtonAndContainer(bag, slot)` finds the button.
  `ContainerFrame.CloseBag` / `CloseAllBags` (EventRegistry) take the coin away. Item buttons are
  not protected, so this works in combat.
- Rescans: `BAG_UPDATE_DELAYED` and `EQUIPMENT_SETS_CHANGED` while the bags are open (else on the
  next look), after each Auctionator scan, and on `SPELLS_CHANGED` at the next look (learning
  Enchanting reprices bound gear).
- Bag addons that replace the default frames get the tooltip line and the hub card, but no coin. `/kwl` says when the bags are open but the coin found no button for the slot.

## Settings and commands

Mark It In Your Bags, Say It On The Tooltip. `/kwl` lists the five least valuable slots and what was
not counted, by reason. `/kwl ignore` ignores the marked item, `/kwl ignore <item>` any item
(shift-click it into the chat line), `/kwl unignore <item, id or name>`, `/kwl ignored`.

## To check in game

- Open the bags: one slot has a copper coin in its top-right corner, and its tooltip says "Least valuable in your bags".
- Sell it at a vendor: the coin moves to the next one.
- Switch combined and separate bags (bag menu): the coin follows the slot.
- The Hearthstone, a Mining Pick, an enchanting rod, arrows and quest items never get the coin.
- An unscanned BoE green gets no coin; after an auction scan it counts at its price.
- A still-locked lockbox: unverified whether the game reports `hasLoot` before it is picked. If it
  does not, the box counts at its vendor or auction price (`/kwl ignore` it if you pick locks).
