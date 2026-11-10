-- Minimal Forever client for the Sayge's Fortune feature under fengari (Lua 5.3), built on the Camp
-- Guide stubs (the whole bundle loads). Tests mutate the fixture tables below.

function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

function strtrim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

Enum = { TooltipDataType = { Item = 0, Unit = 2, Object = 4, UnitAura = 7 } }

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
InInstance = false
function IsInInstance()
	return InInstance, InInstance and "raid" or "none"
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

CanDisenchant = false
C_SpellBook = {
	ContainsAnyDisenchantSpell = function()
		return CanDisenchant
	end,
}

-- Auctionator's public API. AuctionatorOn(false) uninstalls it.
Prices = {} -- item id -> copper
LinkPrices = {} -- item link -> copper (the link API tells apart suffixes and levels)
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
			},
		},
	}
end
AuctionatorOn(true)

-- ---------------------------------------------------------------- camp

-- The player's auras: PlayerAuras[spellId] = aura table (expirationTime=); Buffs[name] = aura
-- table for class buffs looked up by name. AuraErrors makes both lookups raise.
PlayerAuras = {}
Buffs = {}
AuraErrors = false
AuraReads = 0 -- every GetPlayerAuraBySpellID call
-- AurasHidden: what C_Secrets.ShouldAurasBeSecret says (inside instances on Forever). Reading an
-- aura then errors, as the client does for tainted code.
AurasHidden = false
C_Secrets = {
	ShouldAurasBeSecret = function()
		return AurasHidden
	end,
}
C_UnitAuras = {
	GetPlayerAuraBySpellID = function(id)
		AuraReads = AuraReads + 1
		if AuraErrors or AurasHidden then
			error("Auras cannot be accessed when secret while tainted")
		end
		return PlayerAuras[id]
	end,
	GetAuraDataBySpellName = function(unit, name, filter)
		if AuraErrors then
			error("aura lookup failed")
		end
		if unit == "player" and filter == "HELPFUL" then
			return Buffs[name]
		end
		return nil
	end,
}

PlayerLevel = 35
function UnitLevel()
	return PlayerLevel
end
Rested = nil -- GetXPExhaustion: nil when none
XPMax = 10000
function GetXPExhaustion()
	return Rested
end
function UnitXPMax()
	return XPMax
end

-- Hovers a world object the way the client does: the post-calls for Object, with the name as
-- the first line. kind: a TooltipDataType to use instead (the chains of other kinds).
function ShowObject(name, tooltip, kind)
	tooltip = tooltip or GameTooltip
	GameTooltip:Reset()
	local data = { type = kind or Enum.TooltipDataType.Object, lines = { { leftText = name } } }
	for _, fn in ipairs(TooltipChains[kind or Enum.TooltipDataType.Object] or {}) do
		fn(tooltip, data)
	end
	return GameTooltip
end

-- A buff tooltip (UnitAura): id is the spell id, lines after the title are the given texts.
function ShowAura(id, texts, tooltip)
	tooltip = tooltip or GameTooltip
	GameTooltip:Reset()
	local data = { type = Enum.TooltipDataType.UnitAura, id = id, lines = { { leftText = "aura" } } }
	for _, t in ipairs(texts or {}) do
		table.insert(data.lines, { leftText = t })
	end
	for _, fn in ipairs(TooltipChains[Enum.TooltipDataType.UnitAura] or {}) do
		fn(tooltip, data)
	end
	return GameTooltip
end

-- ---------------------------------------------------------------- fortune

-- The real clock. Now starts at 08:00 UTC; Advance moves it and GetTime() together.
Now = 1800000000
function time()
	return Now
end
function Advance(seconds)
	Now = Now + seconds
	Clock = Clock + seconds
end

-- The client's stack text, for the bundle's error log.
function debugstack(start)
	return debug.traceback("", start)
end

-- date: the two clock formats the feature uses, in UTC so the tests do not depend on the zone.
function date(fmt, t)
	t = t or Now
	local m = math.floor(t / 60) % 1440
	local h, mm = math.floor(m / 60), m % 60
	if fmt == "%H:%M" then
		return ("%02d:%02d"):format(h, mm)
	elseif fmt == "%I:%M %p" then
		local h12 = h % 12
		if h12 == 0 then
			h12 = 12
		end
		return ("%02d:%02d %s"):format(h12, mm, h < 12 and "AM" or "PM")
	end
	return tostring(t)
end
Military = false
function GetCVarBool(name)
	return name == "timeMgrUseMilitaryTime" and Military or false
end

PlayerName, RealmName = "Krool", "Stormrage"
function UnitName(unit)
	return unit == "player" and PlayerName or "Someone"
end
function GetRealmName()
	return RealmName
end
UnitGUIDs = {} -- token -> guid
function UnitGUID(unit)
	return UnitGUIDs[unit]
end

-- Sayge's window: Gossip.options = { {name=}, ... }, Gossip.text.
Gossip = { options = {}, text = "" }
C_GossipInfo = {
	GetOptions = function()
		return Gossip.options
	end,
	GetText = function()
		return Gossip.text
	end,
}

-- Timers: every C_Timer.After is kept; RunTimersOver(seconds) runs the ones at least that long
-- (other features queue short ones of their own).
Timers = {}
C_Timer.After = function(delay, fn)
	table.insert(Timers, { delay = delay, fn = fn })
end
function RunTimersOver(seconds)
	local run = {}
	for i = #Timers, 1, -1 do
		if Timers[i].delay >= seconds then
			table.insert(run, table.remove(Timers, i))
		end
	end
	for _, t in ipairs(run) do
		t.fn()
	end
	return #run
end

-- A unit tooltip (Unit) for a GUID.
function ShowUnit(guid, tooltip)
	tooltip = tooltip or GameTooltip
	GameTooltip:Reset()
	local data = { type = Enum.TooltipDataType.Unit, guid = guid, lines = { { leftText = "unit" } } }
	for _, fn in ipairs(TooltipChains[Enum.TooltipDataType.Unit] or {}) do
		fn(tooltip, data)
	end
	return GameTooltip
end
