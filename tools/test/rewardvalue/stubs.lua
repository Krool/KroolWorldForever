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

-- The quest log's side (QuestInfo.lua, forever branch, build 71139): the selected quest's
-- choices, read through their own globals. LogChoices entries are { id =, count = },
-- { currency = true } or { id =, nolink = true } (an item whose link is not ready).
LogChoices = {}
LogQuestID = 4711
LogShowRewards = true
C_QuestLog = C_QuestLog or {}
function C_QuestLog.GetSelectedQuest()
	return LogQuestID
end
function C_QuestLog.ShouldShowQuestRewards()
	return LogShowRewards
end
function GetNumQuestLogChoices(questID)
	return questID == LogQuestID and #LogChoices or 0
end
function GetQuestLogChoiceInfoLootType(i)
	local c = LogChoices[i]
	return c and c.currency and 1 or 0
end
-- By choice index: name, texture, count, quality, usable, item id.
function GetQuestLogChoiceInfo(i)
	local c = LogChoices[i]
	if not c or c.currency then
		return nil
	end
	return "name", 134400, c.count or 1, 1, true, c.id
end
-- By item number: currencies are not counted, as the client numbers the buttons.
function GetQuestLogItemLink(kind, n)
	local seen = 0
	for _, c in ipairs(kind == "choice" and LogChoices or {}) do
		if not c.currency then
			seen = seen + 1
			if seen == n then
				if c.nolink then
					return nil
				end
				return "|cffffffff|Hitem:" .. c.id .. "::::::::|h[" .. (Items[c.id] and Items[c.id].name or "?") .. "]|h|r"
			end
		end
	end
	return nil
end

-- QuestInfoFrame.rewardsFrame.RewardButtons, laid out by QuestInfo_ShowRewards. The map view has
-- a rewards frame of its own (MapQuestInfoRewardsFrame).
local function RewardsFrame(name)
	local frame = CreateFrame("Frame", name)
	frame.RewardButtons = {}
	for i = 1, 3 do
		local b = CreateFrame("Button", name .. "QuestInfoItem" .. i, frame)
		b.id = i
		function b:GetID()
			return self.id
		end
		frame.RewardButtons[i] = b
	end
	return frame
end
local rewards = RewardsFrame("QuestInfoRewardsFrame")
local mapRewards = RewardsFrame("MapQuestInfoRewardsFrame")
mapRewards.shown = false
QuestInfoFrame = { rewardsFrame = rewards }
-- As the client: a choice button has type "choice" and objectType "item" or "currency". At the
-- quest giver its id is the choice index; in the quest log items and currencies count apart.
function QuestInfo_ShowRewards()
	local frame = QuestInfoFrame.rewardsFrame
	local log = QuestInfoFrame.questLog
	local list = log and LogChoices or Choices
	local items, currencies = 0, 0
	frame.shown = not log or LogShowRewards
	for i, b in ipairs(frame.RewardButtons) do
		local c = list[i]
		b.type = c and "choice" or "reward"
		b.objectType = c and c.currency and "currency" or "item"
		b.id = i
		if c and log then
			if c.currency then
				currencies = currencies + 1
				b.id = currencies
			else
				items = items + 1
				b.id = items
			end
		end
		b.shown = true
	end
end
-- As in the client (QuestInfo.lua, forever branch): the templates hold the element function
-- itself, and QuestInfo_Display calls it from the table, so a hook on the global name never runs.
QUEST_TEMPLATE_REWARD = { questLog = nil, chooseItems = true, elements = { QuestInfo_ShowRewards, 0, -10 } }
QUEST_TEMPLATE_DETAIL = { questLog = nil, chooseItems = nil, elements = { QuestInfo_ShowRewards, 0, -15 } }
QUEST_TEMPLATE_LOG = { questLog = true, chooseItems = nil, elements = { QuestInfo_ShowRewards, 0, -10 } }
QUEST_TEMPLATE_MAP_DETAILS = { questLog = true, chooseItems = nil, elements = {} }
QUEST_TEMPLATE_MAP_REWARDS = { questLog = true, chooseItems = nil, elements = { QuestInfo_ShowRewards, 0, -10 } }
function QuestInfo_Display(template, parentFrame, acceptButton, material, mapView)
	QuestInfoFrame.questLog = template.questLog
	QuestInfoFrame.chooseItems = template.chooseItems
	if mapView then
		QuestInfoFrame.rewardsFrame = mapRewards
		rewards.shown = false
	else
		QuestInfoFrame.rewardsFrame = rewards
		mapRewards.shown = false
	end
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
-- The quest log shows a quest: no event, the log template. In the map view (QuestMapFrame.lua)
-- two templates are displayed in a row, the second with the rewards.
function OpenQuestLog(mapView)
	if mapView then
		QuestInfo_Display(QUEST_TEMPLATE_MAP_DETAILS, nil, nil, nil, true)
		QuestInfo_Display(QUEST_TEMPLATE_MAP_REWARDS, nil, nil, nil, true)
	else
		QuestInfo_Display(QUEST_TEMPLATE_LOG)
	end
end
-- The quest log closes: its frames hide, and no event says so.
function CloseQuestLog()
	rewards.shown = false
	mapRewards.shown = false
end
-- The quest giver's window closes. The event fires whatever the quest log is doing.
function CloseQuest()
	if not QuestInfoFrame.questLog then
		rewards.shown = false
	end
	FireEvent("QUEST_FINISHED")
end
