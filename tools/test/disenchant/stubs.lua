-- Minimal Forever client for the Disenchant Value feature under fengari (Lua 5.3). Only what the
-- bundle touches. Tests mutate the fixture tables below.

function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

function strtrim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

Enum = { TooltipDataType = { Unit = 2, Item = 0 } }

-- Secret values: a table tagged __secret.
function Secret()
	return { __secret = true }
end
function issecretvalue(v)
	return type(v) == "table" and v.__secret == true
end

Clock = 1000
function GetTime()
	return Clock
end
function IsInInstance()
	return false, "none"
end
function InCombatLockdown()
	return false
end

-- ---------------------------------------------------------------- widgets

local Widget = {}
local WidgetMeta = {
	__index = function(_, k)
		return Widget[k] or function() end
	end,
}
local function NewWidget(name)
	local w = setmetatable({ scripts = {}, hooks = {}, events = {}, attrs = {}, shown = true, text = "" }, WidgetMeta)
	if name then
		_G[name] = w
		w.name = name
	end
	return w
end
function Widget:RegisterEvent(e)
	self.events[e] = true
end
function Widget:SetScript(which, fn)
	self.scripts[which] = fn
end
function Widget:HookScript(which, fn)
	self.hooks[which] = fn
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

C_Timer = {
	After = function() end,
	NewTicker = function()
		return { Cancel = function() end }
	end,
}

ShiftDown = false
function IsShiftKeyDown()
	return ShiftDown
end

-- ---------------------------------------------------------------- settings

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
		function s:SetValue(value)
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
SettingsButtons = {}
function CreateSettingsButtonInitializer(name, text, onClick, tooltip)
	return { text = text, onClick = onClick, tooltip = tooltip }
end
SettingsPanel = {
	GetLayout = function()
		return {
			AddInitializer = function(_, init)
				SettingsButtons[init.text] = init
			end,
		}
	end,
	Hide = function() end,
}
SlashCmdList = {}

-- ---------------------------------------------------------------- tooltips

-- Like the client, every post-call registered for a tooltip type runs, in order.
TooltipChains = {}
TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, fn)
		TooltipChains[kind] = TooltipChains[kind] or {}
		table.insert(TooltipChains[kind], fn)
	end,
}

GameTooltip = { left = {}, right = {}, lines = {} }
function GameTooltip:Reset()
	self.left, self.right, self.lines, self.link = {}, {}, {}, nil
end
function GameTooltip:AddLine(t)
	table.insert(self.lines, t)
end
function GameTooltip:AddDoubleLine(l, r)
	table.insert(self.left, l)
	table.insert(self.right, r)
end
function GameTooltip:GetItem()
	return "name", self.link
end
function GameTooltip:SetOwner() end
function GameTooltip:SetText() end
function GameTooltip:Show() end
function GameTooltip:Hide() end
ItemRefTooltip = { AddLine = GameTooltip.AddLine, AddDoubleLine = GameTooltip.AddDoubleLine }

-- Shows an item tooltip the way the client does: builds it, then runs the post-calls.
-- extra: fields merged into the tooltip data (lines = { {leftText=}, ... }).
function ShowItem(id, extra, tooltip)
	tooltip = tooltip or GameTooltip
	GameTooltip:Reset()
	GameTooltip.link = type(id) == "number" and ("item:" .. id) or nil
	local data = { id = id, lines = {} }
	for k, v in pairs(extra or {}) do
		data[k] = v
	end
	for _, fn in ipairs(TooltipChains[Enum.TooltipDataType.Item] or {}) do
		fn(tooltip, data)
	end
	return GameTooltip
end

ITEM_SOULBOUND = "Soulbound"
ITEM_ACCOUNTBOUND = "Account Bound"

-- ---------------------------------------------------------------- items and prices

-- id -> { name=, quality=, ilvl=, sell=, class=, bind= }   (class 2 weapon, 4 armor)
Items = {}
ItemInfoErrors = false
local function IdOf(item)
	if type(item) == "number" then
		return item
	end
	return tonumber(tostring(item):match("item:(%d+)"))
end
C_Item = {
	GetItemInfo = function(item)
		if ItemInfoErrors then
			error("item info failed")
		end
		local i = Items[IdOf(item)]
		if not i then
			return nil
		end
		return i.name, "item:" .. IdOf(item), i.quality, i.ilvl, 1, "", "", 1, "", 0, i.sell or 0, i.class, 0, i.bind or 2
	end,
	GetItemNameByID = function(id)
		return ItemNames[id]
	end,
	RequestLoadItemDataByID = function() end,
}
ItemNames = {}

-- The loot window and bag slots, for the disenchant recorder.
-- LootSlots = { {link=, source=guid, count=}, ... }; BagItems[bag * 100 + slot] = ContainerItemInfo
LootSlots = {}
Enum.LootSlotType = Enum.LootSlotType or { None = 0, Item = 1, Money = 2, Currency = 3 }
function GetNumLootItems()
	return #LootSlots
end
function GetLootSlotType(i)
	return LootSlots[i] and Enum.LootSlotType.Item or Enum.LootSlotType.None
end
function GetLootSlotLink(i)
	return LootSlots[i] and LootSlots[i].link
end
function GetLootSourceInfo(i)
	local s = LootSlots[i]
	if s then
		return s.source, s.count
	end
end
BagItems = {}
C_Container = C_Container or {}
C_Container.GetContainerItemInfo = function(bag, slot)
	return BagItems[bag * 100 + slot]
end

CanDisenchant = false
C_SpellBook = {
	ContainsAnyDisenchantSpell = function()
		return CanDisenchant
	end,
}

-- Auctionator's public API. AuctionatorOn(false) uninstalls it.
Prices = {} -- item id -> copper
LinkPrices = {} -- item link -> copper (the link API tells apart suffixes and levels)
Ages = {} -- item id -> days since Auctionator last saw it (missing: it cannot say)
LinkAges = {} -- item link -> days
function AuctionatorOn(on)
	if on == false then
		Auctionator = nil
		return
	end
	Auctionator = {
		API = {
			v1 = {
				GetAuctionPriceByItemID = function(_, id)
					return Prices[id]
				end,
				GetAuctionPriceByItemLink = function(_, link)
					return LinkPrices[link] or Prices[IdOf(link)]
				end,
				GetAuctionAgeByItemID = function(_, id)
					return Ages[id]
				end,
				GetAuctionAgeByItemLink = function(_, link)
					return LinkAges[link] or Ages[IdOf(link)]
				end,
			},
		},
	}
end
AuctionatorOn(true)
