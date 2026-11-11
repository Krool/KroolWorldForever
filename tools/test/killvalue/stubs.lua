-- Minimal Forever client environment for the Kill Value feature under fengari (Lua 5.3).
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
	TooltipDataType = { Unit = 2, Item = 0 },
	ItemClass = { Questitem = 12, Key = 13, Tradegoods = 7 },
	BagIndex = { Backpack = 0, Bank = -1, CharacterBankTab_1 = 6, AccountBankTab_1 = 12 },
	LootSlotType = { None = 0, Item = 1, Money = 2, Currency = 3 },
}

-- Secret() and issecretvalue come from ..\common.lua. SecretGuid is one more secret: still a
-- well-formed string, so type() checks alone would let it through.
SecretGuid = "Creature-0-1-2-3-4242-secret"
local baseSecret = issecretvalue
function issecretvalue(v)
	return baseSecret(v) or v == SecretGuid
end

Clock = 1000
function GetTime()
	return Clock
end

InInstance = false
function IsInInstance()
	return InInstance, InInstance and "party" or "none"
end

-- ---------------------------------------------------------------- frames / events

-- Frames accept any method (unknown ones are no-ops) and keep what tests look at, so windows such
-- as the hub can build here too.
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
function Widget:IsShown()
	return self.shown
end
function Widget:SetText(t)
	self.text = t
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

C_Timer = {}

-- ---------------------------------------------------------------- tooltip / settings

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

TooltipUnitToken = "mouseover"
GameTooltip = { left = {}, right = {} }
function GameTooltip:AddDoubleLine(l, r)
	table.insert(self.left, l)
	table.insert(self.right, r)
end
function GameTooltip:GetUnit()
	return "Name", TooltipUnitToken
end
function GameTooltip:Reset()
	self.left, self.right = {}, {}
end

-- Hover a unit: returns the left and right text columns.
function Hover(guid)
	GameTooltip:Reset()
	TooltipCallbacks[Enum.TooltipDataType.Unit](GameTooltip, { guid = guid })
	return GameTooltip.left, GameTooltip.right
end

-- Settings: records every registered setting by variable name; SettingsSet(variable, value)
-- simulates the player clicking it (writes the table, then fires the change callback).
RegisteredSettings = {}
SetValueCalls = {} -- variable -> last value written through the setting object
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
		-- what root.SetOption calls: writes the registered table and fires the change callback
		function s:SetValue(value)
			SetValueCalls[variable] = value
			self.tbl[self.key] = value
			if self.cb then
				self.cb(self, value)
			end
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

-- ---------------------------------------------------------------- units

Units = {} -- token -> { guid=, dead=, canAttack=, name= }
function UnitGUID(token)
	local u = Units[token]
	return u and u.guid
end
function UnitIsDead(token)
	local u = Units[token]
	return u and u.dead or false
end
function UnitCanAttack(_, token)
	local u = Units[token]
	if u and u.canAttack ~= nil then
		return u.canAttack
	end
	return true
end
function UnitName(token)
	local u = Units[token]
	return u and u.name or "Target"
end

-- ---------------------------------------------------------------- items

ItemCache = {} -- [itemID] = { quality=, sell=, bind=, class=, name= }; missing = not cached
LoadRequests = {}
C_Item = {
	GetItemInfo = function(itemID)
		local i = ItemCache[itemID]
		if not i then
			return nil
		end
		return i.name or ("Item" .. itemID), "link", i.quality or 1, 10, 1, "type", "sub", 20, "", 0,
			i.sell or 0, i.class or 15, 0, i.bind or 0
	end,
	RequestLoadItemDataByID = function(itemID)
		LoadRequests[#LoadRequests + 1] = itemID
	end,
	GetItemNameByID = function(itemID)
		local i = ItemCache[itemID]
		return i and (i.name or ("Item" .. itemID)) or nil
	end,
}

-- ---------------------------------------------------------------- skills

SkillLines = {} -- [skillLineID] = { rank=, modifier= }; missing = not learned
SkillReads = 0
C_SkillInfo = {
	GetSkillLineInfoByID = function(id)
		SkillReads = SkillReads + 1
		local s = SkillLines[id]
		if not s then
			return nil
		end
		return { skillID = id, name = "Skill" .. id, rank = s.rank, modifier = s.modifier or 0, maxRank = 300 }
	end,
}

-- ---------------------------------------------------------------- loot window

Loot = { slots = {}, fishing = false } -- slot = { type=, link=, sources={guid, qty, guid, qty...} }
function GetNumLootItems()
	return #Loot.slots
end
function GetLootSlotType(i)
	return Loot.slots[i].type
end
function GetLootSlotLink(i)
	return Loot.slots[i].link
end
function GetLootSourceInfo(i)
	return table.unpack(Loot.slots[i].sources)
end
function IsFishingLoot()
	return Loot.fishing
end
