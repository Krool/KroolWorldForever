# Changelog

## 0.17.0

Two new features and a bags-full card, after a look at what Forever players like in other addons.

- **New: One-Button Fishing.**
  - Bind one key under Key Bindings > AddOns > Krool World. It casts your line; while the line is
    out, the same key reels in the bite.
  - With a fishing pole in your main hand, a double right-click does the same. It doesn't work
    while you are moving, mounted, swimming, stealthed or in combat. Option: Double Right-Click To
    Fish.
  - Every cast and reel is your own key press or click. The addon only points the key at the cast
    or at the bobber, and only out of combat.
  - While the line is out it turns on the soft-interact settings that find the bobber, then puts
    them back. If you change one of them yourself in the meantime, your value stays.
  - `/kwfish` shows your key and whether a pole is equipped.
- **New: Quest Reward Value.** When a quest asks you to pick a reward, a coin marks the one worth
  the most: its stack at the best of vendor price, auction price and disenchant value. Each
  reward's tooltip shows its value and how it was priced.
  - A reward that binds on pickup counts no auction price.
  - Only items count; a currency choice is left out.
  - A tie, or rewards still loading, shows no coin.
  - It never picks the reward for you.
- **Least Valuable: Bags Full card.** When your bags are full and you try to loot, a card opens
  beside the loot window.
  - It names your least valuable item, priced the same way as the bag coin, and the best item in
    the loot.
  - It says whether the loot is "Worth making room" or "Not worth picking up". Quest items and loot
    with no known price always count as worth taking.
  - Browse the next cheapest items with < and >. Never Mark adds one to the ignore list.
  - It never deletes, picks up or loots anything. Option: Bags Full Card.

## 0.16.4

Fixes from a review of the whole project.

- **Sayge's Fortune no longer counts time logged out when it was switched off.** A session spent
  with the feature off from login to logout counted the whole time away as played, so the next
  fortune could show as ready hours early.
- **Setups leaves equipment set and flyout buttons alone.** Undo cannot put those back, so Apply
  no longer replaces or clears a bar slot that holds one. The report counts the slots it left.
- **Setups: a refused Undo says so.** With something on the cursor, or in combat, the message was
  "Undo finished". It now says "Nothing undone".
- **Setups no longer gets stuck on "still loading".** Switching it off in the first seconds after
  login and on again later left Apply refusing until a reload.
- **Skill-Up Odds shows a craft that pays as a gain.** When the result sells for more than its
  reagents, the row said something like "99s 70c a craft". It now says "+30c a craft" in green.
- **Rare Alert takes its button down after a fight.** Switching Rare Alert off in combat could
  leave the faded button on screen, still pointed at the old rare.
- **`/kwr test` says "a minute"**, which is how long the test button stays, and in combat it only
  asks you to leave combat instead of showing the button afterwards.
- **A feature window that fails to open no longer raises a Lua error** from `/kw <feature>` or the
  settings page's Open button. It is reported and logged like every other error.
- **Item tooltips check for hidden values first** in Least Valuable, Disenchant Value and Quest
  Trash, before any other test of the item id.
- **The `/kw` hub scrolls when it has more features than the screen fits**, instead of growing
  past the screen. Nothing changes at today's nine features on a default-size screen.

## 0.16.3

- **Disenchant Value uses Forever's changes to classic items.** Forever kept the item ids but
  changed some items. Some dungeon greens are blue now, such as Cloak of Blight, and some item
  levels moved.
  - A classic item now uses its 1.12 table only when Forever still shows it with that table's
    quality.
  - The 27 items whose quality or item level Forever's game data changed go by their Forever values.
  - Blue items of item level 20 or below say "(unconfirmed on Forever)". Forever added new
    disenchant results for them, and nobody has measured what they give yet.
- **Disenchant Value records what your disenchants actually give.** Each disenchant is kept with
  the item and the materials that came out. `/kwd seen` lists them and flags anything the tables
  don't list, so the tables get checked against the game as you play. It only reads the loot
  window.
- **Skill-Up Odds checked against build 70888:** no recipe skill levels changed.

## 0.16.2

Fixes from a review of 0.16.0 and 0.16.1.

- **Sayge's Fortune:**
  - Time played with the feature turned off now counts toward Sayge's wait. It is saved at logout
    either way, and counted from the login even if you turn the feature on later.
  - A fortune first seen partway through its time says "first seen" instead of a guessed start
    time.
  - An older record whose fortune is still on keeps its history; the fortune's time left corrects
    the count.
  - An older record where Sayge offered after turning you away now reads ready.
  - `/sayge` lists another character from an earlier faire if its wait isn't used up, since the
    wait stands still while that character is logged out.
- **Least Valuable:**
  - The reagent bag is never counted.
  - An open hub card updates when your bags change.
  - Only the item still loading starts a rescan when its info arrives, not every item the game
    loads.

## 0.16.1

- **Least Valuable: a copper coin instead of the glow.** The slot worth the least now has a small
  copper coin in its top-right corner, still, in Blizzard's own coin art. The breathing glow was
  hard to see. The top-right corner is free: Blizzard puts the junk coin and the upgrade arrow
  top-left and the stack count bottom-right. `/kwl` says so if your bags are open but the coin
  found no button for the slot.
- **Sayge's Fortune counts his wait only while you are logged in.** On Forever both the fortune and
  Sayge's hidden 4-hour wait stop while you are logged out. Your visits showed it: a fortune taken
  at 1:35 AM outlasted a night logged out, and Sayge still refused 12 hours later, about 3h 20m of
  play in.
  - The wait now counts time online on each character, saved at logout. Other characters' waits
    stand still. While the fortune is on you, its own time left sets the wait exactly.
  - It reads "Next fortune after 1h 30m more online (2:40 PM if you stay on)".
  - A fortune still on you after a night away is no longer taken for a new one.
  - His "Here is your fortune" page is no longer counted as a refusal.
  - Each talk with Sayge now records the count, to check it.

## 0.16.0

- **New feature: Least Valuable.** A soft gold glow on the bag slot worth the least, so you know
  what to sell or drop first.
  - A slot is worth its whole stack at the best of its vendor price, auction price and disenchant
    value (the last two after the 5% cut). A bound item's disenchant counts only if you can
    disenchant it yourself.
  - It never marks quest items, keys, ammunition, class reagents, profession tools (pick, knife,
    hammer, enchanting rods, fishing poles), unopened clams and lockboxes, equipment-set gear,
    items worth nothing like the Hearthstone, or a green with no auction price yet.
    `/kwl ignore` skips anything else you keep.
  - Its tooltip says what it is worth and at which price. `/kwl` lists the five cheapest slots and
    what was not counted. The hub card names the item.
  - Works in combined and separate bags. It only marks: nothing is sold or moved.

## 0.15.0

- **Errors are logged, and printed once.** The addon catches its own errors so they never reach the
  game, which also kept them out of BugSack. Each one is now saved with its stack and a count.
  `/kw errors` lists them (`/kw errors clear` empties the list), and the chat line shows once per
  session instead of on every repeat, as it did in the Deadmines.
- Tooltip lines, hub card lines, Kill Value's loot learning, the Skill-Up panel and Rare Alert's
  button used to drop an error without a word. They log it now: tooltips and the hub quietly,
  the others with one chat line.

## 0.14.1

- **Sayge's Fortune:** no more "error in UNIT_AURA" lines inside dungeons. The game hides buff details
  from addons in instances, and the feature tested one of those hidden values on every buff change.
  It now leaves buffs alone while they are hidden, and catches up when you leave: a fortune lost in
  there is reported then.
- **Camp Guide:** the same care. It no longer tries to read your buffs while the game hides them.

## 0.14.0

- **New feature: Sayge's Fortune.** When Sayge at the Darkmoon Faire can give you your next
  fortune.
  - Sayge makes you wait 4 hours from your last fortune, and dying does not end the wait, though
    the fortune itself is lost. The game hides that wait from you and from addons, so this notes
    when you got each fortune, on every character, and counts from there.
  - The time shows on the hub card, on Sayge's tooltip and on the fortune buff's tooltip.
  - Die with the buff and a chat line says when you can get the next one. Another says when the
    wait is over, if you are logged in.
  - `/sayge` lists this character and your others for this faire.
  - It records what Sayge says each time you talk to him, to check the 4 hours against real visits.
    The 4 hours come from the game's data and are not yet confirmed on Forever.

## 0.13.2

- **Hub:** the On/Off checkboxes line up in one column on every card, whether or not the card has
  an Open button.

## 0.13.1

- **Disenchant Value: old auction prices are marked.**
  - When the item's own auction price is more than 3 days old, the Best line says so: "Best: sell
    it at auction (price seen 6 days ago)". The old price still counts; you decide.
  - When a main material's price is more than 3 days old, the value says "(old prices)".
  - Shift dates old materials, `/kwd` shows when each material was last seen, and the hub card
    counts the old ones.
- **Kill Value:**
  - New prices show as soon as an Auctionator scan finishes. Before, they waited until you closed
    the auction house.
  - When a tenth or more of a kill value comes from auction prices more than 3 days old, the total
    says "old prices", the drop lines show "(AH, seen 5 days ago)", and `/fkv` says how much.

## 0.13.0

- **Skill-Up Odds: steadier odds.**
  - Every yellow and green recipe now has a chance from its first craft. No more ?%.
  - The chance is the common straight line, 100% at yellow down to 0% at grey, tuned by your own
    crafts on every character. If your crafts gave 6% more points than the line expected, every
    chance is 6% higher (never above 100%). Your crafts so far fit the line: 67 points where it
    expected 63.
  - It changes a little with each skill point instead of jumping between ten separately measured
    ranges. Before, one skill point could double a recipe's gold a point.
  - Hover a chance for the line at your skill, how your crafts move it, and how that part of the
    range has gone for you. `/kwu` sets each range against the line.
- **Next Skill Point panel: no more reshuffling.** Two recipes only swap places when one's point is
  more than 10% cheaper. Opening the panel or switching profession starts from a fresh ranking.
- **Auctionator:**
  - The panel re-prices as soon as an Auctionator scan finishes.
  - Each auction price in the tooltip shows its age ("auction, today"). Prices more than 3 days old
    are flagged in the tooltip and on the panel ("old prices"). A vendor price you have seen beats
    an old auction price, and an old price is never used for what the result sells for.

## 0.12.2

- **Skill-Up Odds:** the Next Skill Point panel is just its title and the recipe rows, and it is as
  tall as the rows it lists, so there is no empty space.
  - The skill heading is gone (the crafting window already shows it). So are the explainer and the
    price footer: each row's tooltip shows prices, and hovering the side tab shows the explainer
    and how many ranges are measured.
  - "Odds ready" notes now appear just under the panel.

## 0.12.1

- **Skill-Up Odds:**
  - The Next Skill Point panel no longer covers the profession tabs down the right edge of the
    crafting window: it docks past them.
  - The panel's button is now a tab at the bottom of that column, in the same style as the
    profession tabs. Click it to hide or show the panel. Its old spot was on top of the
    Professions tab.

## 0.12.0

- **Polish everywhere.**
  - **Windows:** they fade and grow in when they open, with Blizzard's own open, close, click and
    checkbox sounds.
  - **Done messages:** a short note rises in at the bottom of a window and fades: "Applied",
    "Saved", "Rechecked: 3 to delete", "Rare Alert off".
  - **Rows and cards:** they use Blizzard's list highlights, and icons sink a little when pressed.
- **Hub:**
  - Cards arrive one after another. Each has a hover highlight and a green bar down its edge while
    the feature is on.
  - Flipping a switch flashes the card's status line.
  - Right-click a card for its settings.
- **Quest Trash window:**
  - Group headers carry an icon (red X, check mark, magnifying glass) and a divider.
  - Rows are striped, and each reason takes its group's color.
  - An empty list shows a picture.
- **Setups window:**
  - A note confirms apply, undo, save, rename, update, delete and the new-character star.
  - Result icons pop in, and the Reload Now bar glows while a reload is waiting.
- **Rare Alert:**
  - The rare or rare-elite badge Blizzard's nameplates use shows beside the name, in the tooltip
    and in the chat alert.
  - A gold ring breathes behind the skull, and the skull pops in when the button appears.
  - Only colors and art change: the button never moves, so combat is unaffected.
- **Item icons** on Kill Value drop lines, Disenchant Value materials, Rare Alert's drop list and
  Skill-Up Odds' reagents. Chat lines start with the addon's icon.
- **Skill-Up Odds:**
  - The Next Skill Point panel animates in, and its rows arrive one after another.
  - The cheapest point is highlighted, and the row of the recipe you just crafted flashes.
  - A note says when a range has enough crafts to show its odds.

## 0.11.0

- **Skill-Up Odds** (new): the real chance a craft gives a skill point, and the cheapest way to your
  next one. The game shows only three skill-up arrows, and the chance behind them is rolled on
  Blizzard's servers and was never published, so Skill-Up Odds measures it: every craft on every
  character of your account records your skill before it and the points it gave, pooled by where
  your skill sat between the recipe's yellow and grey (ten ranges). Each recipe in the crafting
  window shows the measured chance beside its arrow once its range has ten crafts (?% until then);
  hover it for the crafts behind it, the likely span, the yellow, green and grey skills, and what a
  craft and a point cost. Orange shows 100% and grey 0%, the game's rule, measured as well.
- **Next Skill Point panel**, docked beside the crafting window: your learned recipes ranked by the
  gold a point costs on average (a craft's reagents at the cheaper of their auction and vendor
  price, minus what the result sells for, divided by the points a craft gives). Click a row to
  select the recipe. Vendor prices are learned from the merchants you visit. `/kwu` lists the
  measured odds range by range; `/kwu status` says where the numbers come from.
- Recipe thresholds come from Forever's own recipe data (build 1.60.1.70862, 2,544 recipes).

## 0.10.1

- **Rare Alert: the mark button goes when its work is done.** It used to stay two minutes after
  the last sighting, even after the kill. Now it hides once the rare carries your marker (the key
  still retargets it), and goes when the rare dies: seen when its nameplate leaves, on its corpse
  under your target or mouse, or when combat ends. In a fight it fades and hides once combat ends
  (the game locks it in combat). Otherwise it goes a minute after you last saw the rare.
- **Rare Alert: right-click hides the button** for that spawn; it stays quiet even if you see the
  rare again. Shift-right-click now ignores the rare for good (right-click did before).
- **Rare Alert: one alert per spawn.** Seeing the same rare again no longer replays the sound and
  message every 5 minutes; a new spawn still alerts.

- **Camp Guide** (new): what a campfire gives you. Hover a camp object (the chair, the lodestone
  and the rest) for its buff at your level, and whether a class buff you already have covers it:
  "Does not stack with your Blessing of Might". Objects from skill 140 and 300 show the buff they
  keep and what else they do. Hover the campfire for its slot count, how sitting works (a minute,
  crafting counts, objects placed later need another sit) and the objects you have hovered around
  it. The Camp Benefits buff names any bonus in it that one of your class buffs overlaps. `/kwc`
  lists all ten camp buffs at your level. Lines show only while you have Campfire Nearby, so an
  inn's chair is left alone. The game cannot list a fire's objects for an addon: the campfire
  lists the ones you hover.

## 0.9.0

- **Disenchant Value** (new): weapon and armor tooltips (green and up) show what the item is worth
  disenchanted, at Auctionator's prices for its dust, essences and shards, and a Best line:
  disenchant it, sell it at auction, or sell it to a vendor, after the 5% auction cut. Hold Shift
  for each material's chance and price. Bound items skip the auction compare and get the Best line
  only if you can disenchant. The tables are the 1.12 ones: exact for classic items, by quality,
  weapon or armor and item level for Forever's new items. Auctionator's own disenchant line does
  not cover classic-level items on Forever (it loads its retail tables). `/kwd` lists the material
  prices, so you can see which still need an auction scan.

## 0.8.0

- **Rare Alert: turn enemy nameplates on in one click.** Rares are noticed as soon as their
  nameplate shows, but Forever starts with enemy nameplates off (and a 45 yard range), so only
  rares you mouse over or target were found. While they are off, the hub card says so and shows a
  Plates On button; the settings page has Turn On Enemy Nameplates, and `/kwr nameplates` does
  the same. It turns them on and asks for the longest range; chat says the range you got. A
  one-time tip at login points to it.
- **Rare Alert: what a rare is worth.** The alert's chat line is followed by its kill value and
  best drops from Kill Value ("worth about 1g 20s: ..."), and the skull button's tooltip lists the
  kill value and top drops with their chance.
- Hub: a feature without its own window can show one fix-it button on its card.

## 0.7.0

- **`/kw` opens the new Krool World hub** (so does the minimap addon button): one card per feature
  with its icon, what it is doing right now (items you can delete, creatures learned, your
  setups, the last rare), an On switch, and the way in: Open for features with a window, and a
  gear for settings. `/kw settings` opens the settings; `/kwf` still works.
- **Rare Alert** (new): a sound, a screen message and a chat line when a rare enemy is near (from
  its nameplate, your mouseover or your target), once per rare every 5 minutes. A skull button and
  a key (Key Bindings > AddOns > Krool World) target it and mark it with one press; the game lets
  only a click or key press set a marker, so it never marks by itself. Right-click the button to
  ignore a rare; Sewer Beast in the Stormwind canals is ignored out of the box. `/kwr test` shows
  the button to place it (shift-drag). Options for the sound, screen message, chat line, button
  and which marker.
- **Quest Trash window.** `/fqt` opens a window instead of printing to chat: your bag items (and
  bank items while it is open) in Can Delete, Keep and Still Checking, with stack totals and why.
  Hover a row for the item's tooltip and its quests. `/fqt print` keeps the chat list.

## 0.6.1

- **Quest Trash: no stale verdicts after turning it off and on.** While off it does not see
  quests accepted or turned in, and turning it back on kept the verdicts from before, so an item
  from a quest finished in the meantime could still read "keep". Turning it on now rechecks.

## 0.6.0

- **Kill Value: skinning is no longer learned as loot.** Skinning a corpse that had nothing to
  loot opened the skinning window first, and its leather was recorded as that creature's drops,
  which inflated beast values. A window with no coins and only gathering yields (skinning,
  herbalism, mining) is now skipped when you know that profession. A one-time cleanup removes
  the leather already learned and says so at login.
- **Kill Value: your skinning counts in the total.** If you know Skinning (or Herbalism or Mining,
  for creatures gathered that way) with enough skill for the creature, its skinning value is
  added to the total and listed under it. Too low a skill shows "skinning, needs N". New option
  Add My Skinning To The Total (on). Show Skinning Value now covers creatures you cannot skin.
- `/fkv status` shows your gathering skills.
- `/fkv` commands change settings through the settings panel, so the panel stays in sync, and
  `/fkv detail` stops at 10 like the slider.

## 0.5.0

- **Setups: redesigned window.** A card at the top shows the setup, an arrow, and the character it
  goes onto. The list has class icons and levels, grouped into Saved Setups and Characters, with a
  star on the setup used for new characters. Each part has its own icon and row, and the whole row
  is clickable. After an apply the rows show a check, a warning or an X with that part's result;
  hover a row for the details. Click a setup's name to rename it; Update and Delete are icons. Help
  text moved into tooltips.
- **Setups: fixed the blocked reload after a new character's automatic apply.** The game allows a
  UI reload only from a click, so the reload after the automatic apply was blocked with an error,
  and the Edit Mode layout and addon list never finished. Now the window opens on the result with a
  Reload Now button.
- **Setups: automatic apply only on brand-new characters** (level 1, no experience). Before, any
  character the addon had not seen yet counted as new, so an existing character logging in for the
  first time after you marked a default got it applied. Those characters get the picker instead.
- Setups: asks for a reload only when Edit Mode or the addon list actually changed.
- Setups: snapshots filter the game's CVar list once per session instead of on every snapshot.
- `/kws undo` says when a reload is needed.
- API allowlist rebuilt for the live build, 1.60.1.70790 (lint clean).

## 0.4.1

- Removed legacy repeatable-quest ids not in cmangos; doc cleanup.

## 0.4.0

- **Setups: new characters get the default automatically.** With a setup marked Use For New
  Characters, a brand-new character applies it a few seconds after its first login and reloads; no
  picker (option, on by default; off brings the picker back).
- **Setups: reloads by itself** after an apply that needs it (Edit Mode, addon list) and prints the
  report again after the reload (option, on by default).
- **Setups: which action bars are switched on** (Action Bars 2-8) is now part of the Action Bars part.
- **Setups: Edit Mode's own checkboxes** (show target and focus, cast bar, party frames, pet frame,
  grid, snap...) are now part of the Edit Mode part. The window names the built-in layout (Modern or
  Classic).
- Setups' own options are no longer copied by the Krool World Settings part: an old setup could
  switch auto reload or the picker off.

## 0.3.0

- **Setups: Krool World Settings part.** A setup now also holds every bundle feature's Enabled switch
  and settings (Kill Value, Quest Trash, Setups), and applying it restores them. New settings any
  feature adds are included automatically. Learned data such as Kill Value's loot counts is not.
  The settings are account-wide today, so this part works as a backup and restore.
- Core: `root.SetOption` changes a setting the way the settings panel does, so the panel and the
  feature stay in sync.

## 0.2.3

Setups review fixes:

- A name that comes back as a different character (deleted and remade, or a stress-test name reused
  at launch) no longer overwrites the earlier character's snapshot: it is kept as a named setup
  "(earlier character)", and the new character gets the picker. Characters are told apart by GUID.
- Opening the window now refreshes the character's snapshot (a declaration-order bug skipped it).
- Undo can restore bars that were empty; a setup with no keybindings no longer clears yours.
- Interface settings skip game state (tutorial and "seen" flags, collapsed lists, tracked quests,
  "last selected" values): 84 Forever CVars excluded, real preferences kept.
- Edit Mode: refuses while Edit Mode is open, and checks the layout name is valid.
- Apply waits until the character has finished loading. The full report is also printed to chat.
- Closing the new-character picker, or logging in during combat, asks again next login.
- Long setup names no longer wrap in the list.

## 0.2.2

- **Setups:** applying an Edit Mode layout the character already has (for example re-applying its own
  setup) switches to that layout instead of adding a numbered copy.

## 0.2.1

- **Setups fix:** the auto snapshot no longer refreshes at logout. The client has already emptied the
  action bars and reset Edit Mode by then, so 0.2.0 saved empty bars and the built-in layout over
  the real setup. It now refreshes after login, when the window opens, and shortly after you change
  bars, keybindings, macros, Edit Mode or settings.
- An auto refresh that reads empty bars keeps the previously saved bars.
- Applying a setup with no saved bar slots now leaves your bars alone instead of clearing them.

## 0.2.0

- **Setups** (new): save a character's action bars, keybindings, macros, Edit Mode layout,
  interface settings and addon list, and apply them to another character from a window (`/kws`).
  Auto snapshot of every character, a picker on a new character's first login, a default setup for
  new characters, and one-level undo. Refuses in combat; reports anything it could not restore.
- `/kwf <feature>` opens a feature's own window when it has one; its settings page gets an Open button.
- Stress test (2026-10-21): the bundle loads on Forever with no Lua errors; Kill Value reads NPC ids
  and records loot correctly.

## 0.1.0

First bundle build, not yet released or run in the live game.

- **Krool World Forever** bundle: one addon with a settings page per feature, each with an Enabled
  switch. `/kwf` opens settings, `/kwf list` shows features, `/kwf <feature> on|off` toggles one.
- **Quest Trash**: keep/delete verdicts on quest item tooltips, `/fqt` bag and bank scan. Uses
  QuestieDB data and the client's own completed-quest flags.
- **Kill Value**: expected gold per kill on creature tooltips from a 1.12 loot baseline, blended with
  drop rates learned from your own looting. Vendor and Auctionator prices.
