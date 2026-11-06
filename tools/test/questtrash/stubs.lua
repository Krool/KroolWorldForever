-- Minimal Forever client + QuestieDB environment for the Quest Trash feature under fengari (Lua 5.3).
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
	TooltipDataType = { Item = 0, Unit = 2 },
	BagIndex = { Backpack = 0, Bank = -1, CharacterBankTab_1 = 6, AccountBankTab_1 = 12 },
}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5

-- ---------------------------------------------------------------- frames / events

-- Frames accept any method (unknown ones are no-ops) and keep what tests look at, so the Quest
-- Trash window builds here.
local Widget = {}
local WidgetMeta = {
	__index = function(_, k)
		return Widget[k] or function() end
	end,
}
local function NewWidget(name)
	local w = setmetatable({ scripts = {}, events = {}, shown = true, text = "" }, WidgetMeta)
	if name then
		_G[name] = w
	end
	return w
end
function Widget:RegisterEvent(e)
	self.events[e] = true
end
function Widget:UnregisterEvent(e)
	self.events[e] = nil
end
function Widget:SetScript(which, fn)
	self.scripts[which] = fn
end
function Widget:Show()
	self.shown = true
end
function Widget:Hide()
	self.shown = false
end
function Widget:SetShown(v)
	self.shown = v and true or false
end
function Widget:IsShown()
	return self.shown
end
function Widget:SetText(t)
	self.text = t
end
function Widget:GetText()
	return self.text
end
function Widget:Click()
	if self.scripts.OnClick then
		self.scripts.OnClick(self)
	end
end
function Widget:CreateFontString()
	return NewWidget()
end
function Widget:CreateTexture()
	return NewWidget()
end
UIParent = NewWidget()
UISpecialFrames = {}

CreatedFrames = {}
function CreateFrame(_, name)
	local f = NewWidget(name)
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

-- Like the client, every post-call registered for a tooltip type runs, in order.
TooltipCallbacks = {}
TooltipChains = {}
TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, fn)
		local chain = TooltipChains[kind] or {}
		TooltipChains[kind] = chain
		table.insert(chain, fn)
		TooltipCallbacks[kind] = function(...)
			for _, f in ipairs(chain) do
				f(...)
			end
		end
	end,
}

GameTooltip = { lines = {} }
function GameTooltip:AddLine(text)
	table.insert(self.lines, text)
end
function GameTooltip:SetOwner(owner)
	self.owner = owner
end
function GameTooltip:SetItemByID(id) -- the client builds the item tooltip, then our hook adds the verdict
	self.lines, self.item = {}, id
	TooltipCallbacks[Enum.TooltipDataType.Item](self, { id = id })
end
function GameTooltip:Show() end
function GameTooltip:Hide() end
ItemRefTooltip = { lines = {}, AddLine = GameTooltip.AddLine }

function HoverItem(itemID)
	GameTooltip.lines = {}
	TooltipCallbacks[Enum.TooltipDataType.Item](GameTooltip, { id = itemID })
	return GameTooltip.lines
end

-- Settings: records every registered setting by variable name; SettingsSet(variable, value)
-- simulates the player clicking it (writes the table, then fires the change callback).
RegisteredSettings = {}
local function Category(name)
	return {
		name = name,
		GetID = function()
			return name
		end,
	}
end
Settings = {
	VarType = { Boolean = "boolean", Number = "number" },
	RegisterVerticalLayoutCategory = Category,
	RegisterVerticalLayoutSubcategory = function(_, name)
		return Category(name)
	end,
	RegisterAddOnSetting = function(category, variable, key, tbl, varType, label, default)
		local s = { category = category, key = key, tbl = tbl, label = label, default = default }
		function s:SetValueChangedCallback(fn)
			self.cb = fn
		end
		RegisteredSettings[variable] = s
		return s
	end,
	CreateCheckbox = function() end,
	CreateSliderOptions = function(min, max, step)
		return { min = min, max = max, step = step }
	end,
	CreateSlider = function() end,
	RegisterAddOnCategory = function() end,
	OpenToCategory = function(id)
		OpenedCategory = id
	end,
}
function SettingsSet(variable, value)
	local s = RegisteredSettings[variable]
	s.tbl[s.key] = value
	if s.cb then
		s.cb(s, value)
	end
end

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
Stacks = {} -- [itemID] = stack size of each slot holding it (default 1)
C_Container = {
	GetContainerNumSlots = function(bag)
		return Bags[bag] and #Bags[bag] or 0
	end,
	GetContainerItemID = function(bag, slot)
		return Bags[bag] and Bags[bag][slot]
	end,
	GetContainerItemInfo = function(bag, slot)
		local id = Bags[bag] and Bags[bag][slot]
		return id and { itemID = id, stackCount = Stacks[id] or 1, iconFileID = 134400 } or nil
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
