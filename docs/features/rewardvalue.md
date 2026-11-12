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

## When it marks

On `QUEST_COMPLETE` (and `QUEST_DETAIL`, which previews the same choices) with two or more choices.
No mark when:

- there is a single choice;
- the top two are worth the same;
- every choice is worth nothing;
- any choice is not cached yet. Items re-price on `GET_ITEM_INFO_RECEIVED` for their own id.

The coin goes when the quest frame closes (`QUEST_FINISHED`) or the quest changes.

## Tooltip

Only on reward-choice tooltips (the owner is a reward button with `.type == "choice"` and the item is
that choice's): "Best value: 1g 20s (Auction House)" on the marked one, "Worth 35s (vendor)" on the
others. An Auction House price older than three days adds "(price seen 5 days ago)".

## Where the frames are

Blizzard's Mainline `QuestInfo.lua` (forever branch; written from memory, not re-fetched on
2026-11-12, so check it in game): `QuestInfo_ShowRewards` lays out `QuestInfoFrame.rewardsFrame`
(global `QuestInfoRewardsFrame`); buttons are `rewardsFrame.RewardButtons[n]` (globals
`QuestInfoRewardsFrameQuestInfoItem<n>`) with `.type == "choice"` and `:GetID()` the choice index.
`QUEST_COMPLETE` fires before the buttons are laid out, so the feature also hooks
`QuestInfo_ShowRewards`. The coin is Blizzard's `coin-copper` atlas (as Least Valuable), on one frame
of ours parented to the button.

## Options

- **Mark Best Reward** (default on): the coin.
- **Value On Reward Tooltips** (default on): the tooltip line.

Hub icon: `Interface\Icons\INV_Misc_Coin_02`.
