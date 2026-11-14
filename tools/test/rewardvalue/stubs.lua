-- Minimal Forever client for Quest Reward Value: the Least Valuable stubs (widgets, tooltip chain,
-- items, Auctionator, hooksecurefunc) plus the quest frame's reward buttons and the quest API.

__include("leastvaluable/stubs.lua")

-- Choices shown by the open quest: { id = item id, count = n }.
Choices = {}
GetQuestRewardCalls = 0
function GetNumQuestChoices()
	return #Choices
end
-- 0 = item, 1 = currency (a choice { currency = true } has no item link).
function GetQuestItemInfoLootType(kind, i)
	local c = kind == "choice" and Choices[i]
	return c and c.currency and 1 or 0
end
function GetQuestItemLink(kind, i)
	local c = kind == "choice" and Choices[i]
	if c and c.currency then
		return nil
	end
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
-- As in the client (QuestInfo.lua, forever branch): the templates hold the element function
-- itself, and QuestInfo_Display calls it from the table, so a hook on the global name never runs.
QUEST_TEMPLATE_REWARD = { questLog = nil, chooseItems = true, elements = { QuestInfo_ShowRewards, 0, -10 } }
QUEST_TEMPLATE_DETAIL = { questLog = nil, chooseItems = nil, elements = { QuestInfo_ShowRewards, 0, -15 } }
QUEST_TEMPLATE_LOG = { questLog = true, chooseItems = nil, elements = { QuestInfo_ShowRewards, 0, -10 } }
function QuestInfo_Display(template, parentFrame, acceptButton, material, mapView)
	QuestInfoFrame.questLog = template.questLog
	QuestInfoFrame.chooseItems = template.chooseItems
	local elements = template.elements
	for i = 1, #elements, 3 do
		elements[i](parentFrame)
	end
end
-- The quest frame opens: the event first, then Blizzard displays the template.
function OpenQuest(event)
	FireEvent(event or "QUEST_COMPLETE")
	QuestInfo_Display(event == "QUEST_DETAIL" and QUEST_TEMPLATE_DETAIL or QUEST_TEMPLATE_REWARD)
end
-- The quest log (or map view) shows a quest: no event, the log template.
function OpenQuestLog()
	QuestInfo_Display(QUEST_TEMPLATE_LOG)
end
function CloseQuest()
	rewards.shown = false
	FireEvent("QUEST_FINISHED")
end
