-- Minimal Forever client + QuestieDB environment for ForeverQuestTrash under fengari (Lua 5.3).
-- Only what the addon touches. Tests mutate the fixture tables below.

function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

function strtrim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

Enum = {
	ItemClass = { Questitem = 12, Key = 13, Tradegoods = 7 },
	TooltipDataType = { Item = 0 },
	BagIndex = { Backpack = 0, Bank = -1, CharacterBankTab_1 = 6, AccountBankTab_1 = 12 },
}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5

-- ---------------------------------------------------------------- frames / events

CreatedFrames = {}
function CreateFrame()
	local f = { scripts = {}, events = {} }
	function f:RegisterEvent(e)
		self.events[e] = true
	end
	function f:UnregisterEvent(e)
		self.events[e] = nil
	end
	function f:SetScript(which, fn)
		self.scripts[which] = fn
	end
	table.insert(CreatedFrames, f)
	return f
end

function FireEvent(e, ...)
	for _, f in ipairs(CreatedFrames) do
		if f.events[e] and f.scripts.OnEvent then
			f.scripts.OnEvent(f, e, ...)
		end
	end
end

Tickers = {}
C_Timer = {
	NewTicker = function(_, fn)
		local t = { fn = fn, cancelled = false }
		function t:Cancel()
			self.cancelled = true
		end
		table.insert(Tickers, t)
		return t
	end,
}

function RunTickers()
	for _ = 1, 1000 do
		local any = false
		for _, t in ipairs(Tickers) do
			if not t.cancelled then
				any = true
				t.fn()
			end
		end
		if not any then
			return
		end
	end
	error("ticker never finished")
end

-- ---------------------------------------------------------------- tooltip / settings / UI

TooltipCallbacks = {}
TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, fn)
		TooltipCallbacks[kind] = fn
	end,
}

GameTooltip = { lines = {} }
function GameTooltip:AddLine(text)
	table.insert(self.lines, text)
end
ItemRefTooltip = { lines = {}, AddLine = GameTooltip.AddLine }

function HoverItem(itemID)
	GameTooltip.lines = {}
	TooltipCallbacks[Enum.TooltipDataType.Item](GameTooltip, { id = itemID })
	return GameTooltip.lines
end

Settings = {
	VarType = { Boolean = "boolean" },
	RegisterVerticalLayoutCategory = function(name)
		return {
			name = name,
			GetID = function()
				return name
			end,
		}
	end,
	RegisterAddOnSetting = function()
		return {}
	end,
	CreateCheckbox = function() end,
	RegisterAddOnCategory = function() end,
	OpenToCategory = function() end,
}

SlashCmdList = {}

-- ---------------------------------------------------------------- player / quests / items

Player = { raceID = 1, classFile = "WARRIOR" } -- Human Warrior
function UnitRace()
	return "Human", "Human", Player.raceID
end
function UnitClass()
	return "Warrior", Player.classFile
end

QuestLog = {} -- [qid] = true while in the log
Completed = {} -- [qid] = true once turned in
C_QuestLog = {
	IsQuestFlaggedCompleted = function(qid)
		return Completed[qid] == true
	end,
	GetLogIndexForQuestID = function(qid)
		return QuestLog[qid] and 1 or nil
	end,
	GetTitleForQuestID = function()
		return nil
	end,
}

ItemClass = {} -- [itemID] = classID; missing = not cached
C_Item = {
	GetItemInfoInstant = function(itemID)
		local classID = ItemClass[itemID]
		if classID == nil then
			return nil
		end
		return itemID, "type", "subtype", "", 0, classID, 0
	end,
	GetItemNameByID = function(itemID)
		return "Item" .. itemID
	end,
}

Bags = {} -- [bag] = { itemID, ... }
C_Container = {
	GetContainerNumSlots = function(bag)
		return Bags[bag] and #Bags[bag] or 0
	end,
	GetContainerItemID = function(bag, slot)
		return Bags[bag] and Bags[bag][slot]
	end,
}

-- ---------------------------------------------------------------- fake QuestieDB

Quests = {} -- [qid] = { name=, objectives=, specialFlags=, ... } using QuestieDB field names
Items = {} -- [itemID] = { name=, startQuest=, relatedQuests= }

local NUMERIC = {
	specialFlags = true,
	questFlags = true,
	zoneOrSort = true,
	requiredRaces = true,
	requiredClasses = true,
	breadcrumbForQuestId = true,
	sourceItemId = true,
	startQuest = true,
}

-- QuestieDB semantics: numeric fields read 0 when absent, unknown ids read nil everywhere.
local function Read(store, id, key)
	local e = store[id]
	if not e then
		return nil
	end
	local v = e[key]
	if v == nil and NUMERIC[key] then
		return 0
	end
	return v
end

local function Entity(store)
	local E = {}
	function E.Get(id, key)
		return Read(store, id, key)
	end
	function E.GetAll(id, keys)
		if not store[id] then
			return nil
		end
		local out = { n = #keys }
		for i, k in ipairs(keys) do
			out[i] = Read(store, id, k)
		end
		return out
	end
	function E.GetAllIds()
		local ids = {}
		for id in pairs(store) do
			ids[#ids + 1] = id
		end
		table.sort(ids)
		return ids
	end
	setmetatable(E, {
		__index = function(_, field)
			return function(id)
				return Read(store, id, field)
			end
		end,
	})
	return E
end

QuestDB = Entity(Quests)
ItemDB = Entity(Items)
LibQuestieDB = {
	readMode = "source",
	contractVersion = 4,
	RequireContract = function(v)
		if v <= LibQuestieDB.contractVersion then
			return true
		end
		return false, "QuestieDB contract too old"
	end,
	Enum = {
		raceMaskById = { [1] = 1, [2] = 2, [95] = 4294967296, [96] = 8589934592 },
		classKeys = { WARRIOR = 1, MAGE = 128 },
	},
	Quest = QuestDB,
	Item = ItemDB,
}
