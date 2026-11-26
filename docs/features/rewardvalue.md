# Quest Reward Value

A copper coin on the quest reward choice worth the most, so you can pick the reward that pays best.
Our version of One For All's "best-sell coin", which looks at vendor prices only; this one uses the
best of vendor, Auction House and disenchant. Advice only: it never selects a reward or accepts the
quest (`GetQuestReward` is never called).

```
[copper coin on the reward's button]
Best value: 1g 20s (Auction House)
```

## What a choice is worth

- **The stack:** the best price times the count shown on the reward (`GetQuestItemInfo("choice", i)`).
- **Best price:** the same as Least Valuable: Disenchant Value's `Evaluate` and `Best`, with the 5%
  auction cut off the Auction House and disenchant values. The Auction House price is by item link.
- **Rewards that bind on pickup** (bind type 1, or 4 for a quest item) have no auction price. Their
  disenchant value counts only when you can disenchant yourself.
- **Without Auctionator** only vendor prices count (the tooltip says so).
- **Low blues** (item level 20 or less): Forever's disenchant results for them are unmeasured, so a
  disenchant-based value carries "(unconfirmed)" on the tooltip.

## When it marks

On `QUEST_COMPLETE` (and `QUEST_DETAIL`, which previews the same choices) with two or more choices.
No mark when:

- there is a single choice;
- the top two are worth the same;
- every choice is worth nothing;
- any choice is not cached yet. Items re-price on `GET_ITEM_INFO_RECEIVED` for their own id.

The coin goes when the quest frame closes (`QUEST_FINISHED`) or the quest changes.

## In the quest log (0.26.0)

The quest log and the map's quest view mark the same way, for the selected quest (a CurseForge
comment asked, 2026-11-23). There is no event: the mark is set each time the panel is laid out
(the `QuestInfo_Display` hook), and it follows the selection. Closing the log has no event
either; the coin hides with its button, and the hub names the reward only while that button is on
screen. `QUEST_FINISHED` clears the quest giver's mark, not the log's.

The log reads other calls than the quest giver's window (Blizzard's `QuestInfo.lua`, build 71139):

| | Quest giver | Quest log |
|---|---|---|
| Count | `GetNumQuestChoices()` | `GetNumQuestLogChoices(questID, true)`, quest from `C_QuestLog.GetSelectedQuest()` |
| Item or currency | `GetQuestItemInfoLootType("choice", i)` | `GetQuestLogChoiceInfoLootType(i)` |
| Stack | `GetQuestItemInfo("choice", i)` | `GetQuestLogChoiceInfo(i)` (also gives the item id) |
| Link | `GetQuestItemLink("choice", i)` | `GetQuestLogItemLink("choice", n)` |
| Button id | the choice index | items and currencies numbered apart |

- **Button ids differ in the log.** `n` counts item choices only, and a currency choice can carry
  the same id as an item choice; `button.objectType` (`"item"` or `"currency"`) tells them apart.
  Each priced choice keeps both numbers (`index`, `button`).
- **Nothing is read** when no quest is selected or `C_QuestLog.ShouldShowQuestRewards` says no.
- **The log calls are plain globals**, absent from the API docs, so the lint cannot check them.
  Blizzard's own panel calls them at this build.
- **Not yet seen in game** (2026-11-26): written from Blizzard's source and the test stubs.

## Tooltip

Only on reward-choice tooltips (the owner is a reward button with `.type == "choice"` and the item is
that choice's): "Best value: 1g 20s (Auction House)" on the marked one, "Worth 35s (vendor)" on the
others. An Auction House price older than three days adds "(price seen 5 days ago)".

## Where the frames are

Blizzard's Mainline `QuestInfo.lua` (forever branch, read 2026-11-13): `QuestInfo_ShowRewards` lays
out `QuestInfoFrame.rewardsFrame` (global `QuestInfoRewardsFrame`); buttons are
`rewardsFrame.RewardButtons[n]` (globals `QuestInfoRewardsFrameQuestInfoItem<n>`) with
`.type == "choice"` and `:GetID()` the choice index. `QUEST_COMPLETE` fires before the buttons are
laid out, so the feature also hooks `QuestInfo_Display`. It cannot hook `QuestInfo_ShowRewards`:
the `QUEST_TEMPLATE_*` tables hold that function itself in `.elements`, and `QuestInfo_Display`
calls it from the table, so a hook on the global name never runs. `QuestFrame.lua` calls
`QuestInfo_Display(QUEST_TEMPLATE_REWARD / QUEST_TEMPLATE_DETAIL, ...)`; the quest log and the map
view call it with templates that have `questLog = true` (`QuestMapFrame.lua`), and the map view
swaps `QuestInfoFrame.rewardsFrame` to `MapQuestInfoRewardsFrame`. The coin is
Blizzard's `coin-copper` atlas (as Least Valuable), on one frame of ours parented to the button.

## Options

- **Mark Best Reward** (default on): the coin.
- **Value On Reward Tooltips** (default on): the tooltip line.

Hub icon: `Interface\Icons\INV_Misc_Coin_02`.
