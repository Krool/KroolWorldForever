-- Minimal Forever client for the Least Valuable feature under fengari (Lua 5.3): the Disenchant
-- Value stubs plus bags (C_Container), the default bag frames and their item buttons,
-- hooksecurefunc and EventRegistry. Tests mutate the fixture tables below.

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

-- Secret() and issecretvalue come from ..\common.lua.

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
-- Unset keys read as no-op functions, so the fields below are read with rawget.
function Widget:CreateTexture()
	local t = NewWidget()
	local list = rawget(self, "textures") or {}
	self.textures = list
	table.insert(list, t)
	return t
end
function Widget:SetParent(p)
	self.parent = p
end
function Widget:GetParent()
	return rawget(self, "parent")
end
function Widget:SetAtlas(atlas)
	self.atlas = atlas
end
function Widget:SetPoint(point)
	self.point = point
end
function Widget:SetSize(w, h)
	self.width, self.height = w, h
end
function Widget:CreateAnimationGroup()
	self.animated = true
	return NewWidget()
end
function Widget:SetFrameLevel(n)
	self.level = n
end
function Widget:GetFrameLevel()
	return rawget(self, "level") or 1
end
-- Like the client: a region shows only while it and every parent are shown.
function Widget:IsVisible()
	local w = self
	while type(w) == "table" do
		if not rawget(w, "shown") then
			return false
		end
		w = rawget(w, "parent")
	end
	return true
end
UIParent = NewWidget()
UISpecialFrames = {}

CreatedFrames = {}
function CreateFrame(_, name, parent)
	local f = NewWidget(name)
	f.parent = parent
	table.insert(CreatedFrames, f)
	return f
end

-- Like the client: the hook runs after the original, with the same arguments.
function hooksecurefunc(tbl, name, fn)
	if type(tbl) == "string" then
		tbl, name, fn = _G, tbl, name
	end
	local orig = tbl[name]
	tbl[name] = function(...)
		local r = { orig(...) }
		fn(...)
		return table.unpack(r)
	end
end

-- EventRegistry: callbacks run with their owner first.
Callbacks = {}
EventRegistry = {
	RegisterCallback = function(_, event, fn, owner)
		Callbacks[event] = Callbacks[event] or {}
		table.insert(Callbacks[event], { fn = fn, owner = owner })
	end,
}
function TriggerCallback(event, ...)
	for _, c in ipairs(Callbacks[event] or {}) do
		c.fn(c.owner, ...)
	end
end

function FireEvent(e, ...)
	for _, f in ipairs(CreatedFrames) do
		if f.events[e] and f.scripts.OnEvent then
			f.scripts.OnEvent(f, e, ...)
		end
	end
end

-- After runs its function at once: the tests have no frames to wait for.
C_Timer = {
	After = function(_, fn)
		fn()
	end,
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
TooltipOwner = nil -- the frame the tooltip is shown for (a bag button)
function GameTooltip:GetOwner()
	return TooltipOwner
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

-- id -> { name=, quality=, ilvl=, sell=, class=, sub=, bind= }   (class 2 weapon, 4 armor)
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
		return i.name, "item:" .. IdOf(item), i.quality, i.ilvl or 1, 1, "", "", 1, "", 0, i.sell or 0, i.class, i.sub or 0, i.bind or 2
	end,
	GetItemNameByID = function(id)
		return ItemNames[id] or (Items[id] and Items[id].name)
	end,
	GetItemIconByID = function()
		return 134400
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

-- ---------------------------------------------------------------- bags

NUM_TOTAL_EQUIPPED_BAG_SLOTS = 4
BagSizes = { [0] = 16 }
-- Bag[bag][slot] = { id=, count=, bound=, noValue=, loot=, quest=, questID=, set=, link=, secret= }
Bag = { [0] = {} }
function Put(bag, slot, s)
	Bag[bag] = Bag[bag] or {}
	Bag[bag][slot] = s
end
function EmptyBags()
	for _, b in pairs(Bag) do
		wipe(b)
	end
end
local function SlotOf(bag, slot)
	return Bag[bag] and Bag[bag][slot]
end
C_Container = {
	GetContainerNumSlots = function(bag)
		return BagSizes[bag] or 0
	end,
	GetContainerItemInfo = function(bag, slot)
		local s = SlotOf(bag, slot)
		if not s then
			return nil
		end
		local i = Items[s.id] or {}
		return {
			iconFileID = 134400,
			stackCount = s.count or 1,
			isLocked = false,
			quality = i.quality,
			isReadable = false,
			hasLoot = s.loot or false,
			hyperlink = s.link or ("|cffffffff|Hitem:" .. s.id .. "::::::::|h[" .. (i.name or "?") .. "]|h|r"),
			isFiltered = false,
			hasNoValue = s.noValue or (i.sell or 0) == 0,
			itemID = s.secret and Secret() or s.id,
			isBound = s.bound or false,
			itemName = i.name or "",
		}
	end,
	GetContainerItemQuestInfo = function(bag, slot)
		local s = SlotOf(bag, slot) or {}
		return { isQuestItem = s.quest or false, questID = s.questID, isActive = false }
	end,
	GetContainerItemEquipmentSetInfo = function(bag, slot)
		local s = SlotOf(bag, slot) or {}
		return s.set or false, s.set and "PvP" or ""
	end,
}

-- The default bag frames: the combined one and the separate ones, each with an item button per
-- slot of its bags, created and redrawn the way ContainerFrame.lua does (UpdateItems).
local function NewButton(frame, bag, slot)
	local b = NewWidget()
	b.parent, b.bagID, b.slot = frame, bag, slot
	b.level = 10
	function b:GetBagID()
		return self.bagID
	end
	function b:GetID()
		return self.slot
	end
	return b
end
local function NewBagFrame(name, bags)
	local f = NewWidget(name)
	f.shown, f.bags, f.buttons = false, bags, {}
	function f:MatchesBagID(id)
		for _, b in ipairs(self.bags) do
			if b == id then
				return true
			end
		end
		return false
	end
	-- Buttons come from a pool: a redraw hands them out afresh, so a slot can move to another one.
	function f:Layout()
		local old = self.buttons
		self.buttons = {}
		local n = 0
		for _, bag in ipairs(self.bags) do
			for slot = 1, BagSizes[bag] or 0 do
				n = n + 1
				local b = old[#old - n + 1] or NewButton(self, bag, slot)
				b.bagID, b.slot, b.shown = bag, slot, true
				self.buttons[#self.buttons + 1] = b
			end
		end
	end
	function f:UpdateItems() end
	function f:Open()
		self.shown = true
		self:Layout()
		self:UpdateItems()
	end
	function f:Close()
		self.shown = false
		TriggerCallback("ContainerFrame.CloseBag", self)
	end
	return f
end
ContainerFrameCombinedBags = NewBagFrame("ContainerFrameCombinedBags", { 0, 1, 2, 3, 4 })
ContainerFrame1 = NewBagFrame("ContainerFrame1", { 0 })
ContainerFrame2 = NewBagFrame("ContainerFrame2", { 1 })
ContainerFrameContainer = { ContainerFrames = { ContainerFrame1, ContainerFrame2 } }

function ContainerFrameUtil_GetItemButtonAndContainer(bag, slot)
	for _, f in ipairs({ ContainerFrameCombinedBags, ContainerFrame1, ContainerFrame2 }) do
		if f:IsShown() and f:MatchesBagID(bag) then
			for _, b in ipairs(f.buttons) do
				if b:GetBagID() == bag and b:GetID() == slot then
					return b, f
				end
			end
		end
	end
end
function ButtonFor(bag, slot)
	return (ContainerFrameUtil_GetItemButtonAndContainer(bag, slot))
end

-- ---------------------------------------------------------------- Bags Full card

ERR_INV_FULL = "Inventory is full."
ERR_LOOT_NO_SPACE = "No room to loot."
Enum.LootSlotType = { None = 0, Item = 1, Money = 2, Currency = 3 }
function GetLootSourceInfo() end

-- Free slots: a bag's size less the slots Put into it. FreeSlotsSecret makes the count secret.
FreeSlotsSecret = false
C_Container.GetContainerNumFreeSlots = function(bag)
	if FreeSlotsSecret then
		return Secret(), 0
	end
	local used = 0
	for _ in pairs(Bag[bag] or {}) do
		used = used + 1
	end
	return math.max((BagSizes[bag] or 0) - used, 0), 0
end

-- The open loot window: LootSlots[i] = { kind=, link=, qty=, quest=, secret= }.
LootSlots = {}
function GetNumLootItems()
	return #LootSlots
end
function GetLootSlotType(i)
	return LootSlots[i].kind or Enum.LootSlotType.Item
end
function GetLootSlotLink(i)
	return LootSlots[i].link
end
function GetLootSlotInfo(i)
	local s = LootSlots[i]
	if s.secret then
		return 134400, "x", Secret(), nil, 1, false, Secret()
	end
	return 134400, "x", s.qty or 1, nil, 1, false, s.quest or false
end
LootFrame = NewWidget("LootFrame")
LootFrame.shown = false

-- Every call that would pick up, drop, delete or loot something fails the suite.
ForbiddenCalls = {}
for _, name in ipairs({ "DeleteCursorItem", "PickupContainerItem", "ClearCursor", "LootSlot", "ConfirmLootSlot", "PickupItem", "UseContainerItem", "SellCursorItem" }) do
	_G[name] = function()
		table.insert(ForbiddenCalls, name)
	end
	if C_Container then
		C_Container[name] = _G[name]
	end
end
