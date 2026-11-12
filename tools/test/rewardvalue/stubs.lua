-- Minimal Forever client for Quest Reward Value: the Least Valuable stubs (widgets, tooltip chain,
-- items, Auctionator, hooksecurefunc) plus the quest frame's reward buttons and the quest API.

__include("leastvaluable/stubs.lua")

-- Choices shown by the open quest: { id = item id, count = n }.
Choices = {}
GetQuestRewardCalls = 0
function GetNumQuestChoices()
	return #Choices
end
function GetQuestItemLink(kind, i)
	local c = kind == "choice" and Choices[i]
	return c and ("|cffffffff|Hitem:" .. c.id .. "::::::::|h[" .. (Items[c.id] and Items[c.id].name or "?") .. "]|h|r") or nil
end
function GetQuestItemInfo(kind, i)
	local c = kind == "choice" and Choices[i]
	return c and "name", 134400, c and (c.count or 1), 1, true
end
-- The reward is never taken by the addon: any call fails the suite.
function GetQuestReward()
	GetQuestRewardCalls = GetQuestRewardCalls + 1
end

-- QuestInfoFrame.rewardsFrame.RewardButtons, laid out by QuestInfo_ShowRewards.
local rewards = CreateFrame("Frame", "QuestInfoRewardsFrame")
rewards.RewardButtons = {}
QuestInfoFrame = { rewardsFrame = rewards }
local function Button(i)
	local b = CreateFrame("Button", "QuestInfoRewardsFrameQuestInfoItem" .. i, rewards)
	b.id = i
	function b:GetID()
		return self.id
	end
	rewards.RewardButtons[i] = b
	return b
end
Button(1)
Button(2)
Button(3)
function QuestInfo_ShowRewards()
	rewards.shown = true
	for i, b in ipairs(rewards.RewardButtons) do
		b.type = i <= #Choices and "choice" or "reward"
		b.shown = true
	end
end
-- The quest frame opens: the event first, then Blizzard lays the buttons out.
function OpenQuest(event)
	FireEvent(event or "QUEST_COMPLETE")
	QuestInfo_ShowRewards()
end
function CloseQuest()
	rewards.shown = false
	FireEvent("QUEST_FINISHED")
end
