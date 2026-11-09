-- Minimal Forever client for the Skill-Up Odds feature under fengari (Lua 5.3). Only what the
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

Enum = {
	TooltipDataType = { Unit = 2, Item = 0 },
	TradeskillRelativeDifficulty = { Optimal = 0, Medium = 1, Easy = 2, Trivial = 3 },
	CraftingReagentType = { Modifying = 0, Basic = 1, Finishing = 2, Automatic = 3 },
}

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
Now = 1800000000
function time()
	return Now
end
function InCombatLockdown()
	return false
end
function IsInInstance()
	return false, "none"
end
function UnitFullName()
	return "Tester", "Realm"
end

SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856 }
Sounds = {}
function PlaySound(id)
	table.insert(Sounds, id)
end

-- ---------------------------------------------------------------- timers

Timers = {}
C_Timer = {
	After = function(_, fn)
		table.insert(Timers, fn)
	end,
	NewTicker = function()
		return { Cancel = function() end }
	end,
}
function RunTimers()
	local n = 0
	while #Timers > 0 do
		local fn = table.remove(Timers, 1)
		fn()
		n = n + 1
		if n > 100 then
			error("timer loop")
		end
	end
end

-- ---------------------------------------------------------------- widgets

-- Methods (CamelCase) default to no-ops; fields (lowercase, or set by a test) stay nil when unset,
-- so "does this frame already have my fontstring" checks work.
local Widget = {}
local WidgetMeta = {
	__index = function(_, k)
		if Widget[k] then
			return Widget[k]
		end
		if type(k) == "string" and k:match("^[A-Z]") then
			return function() end
		end
		return nil
	end,
}
local function NewWidget(name)
	local w = setmetatable({ scripts = {}, hooks = {}, events = {}, shown = true, text = "", width = 200 }, WidgetMeta)
	if name then
		_G[name] = w
		w.name = name
	end
	return w
end
NewWidgetStub = NewWidget
function Widget:RegisterEvent(e)
	self.events[e] = true
end
function Widget:SetScript(which, fn)
	self.scripts[which] = fn
end
function Widget:GetScript(which)
	return self.scripts[which]
end
function Widget:HookScript(which, fn)
	self.hooks[which] = self.hooks[which] or {}
	table.insert(self.hooks[which], fn)
end
function Widget:Show()
	local was = self.shown
	self.shown = true
	if not was and self.scripts.OnShow then
		self.scripts.OnShow(self)
	end
end
function Widget:Hide()
	self.shown = false
end
function Widget:SetShown(v)
	if v then
		self:Show()
	else
		self:Hide()
	end
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
function Widget:SetWidth(w)
	self.width = w
end
function Widget:GetWidth()
	return self.width
end
function Widget:SetHeight(h)
	self.height = h
end
function Widget:SetSize(w, h)
	self.width, self.height = w, h
end
function Widget:GetHeight()
	return self.height
end
function Widget:GetStringWidth()
	return #tostring(self.text or "") * 6
end
function Widget:SetTexture(t)
	self.texture = t
end
-- Anchors are recorded, so a test can check what a frame is docked to.
function Widget:ClearAllPoints()
	self.points = {}
end
function Widget:SetPoint(point, rel, relPoint, x, y)
	self.points = self.points or {}
	self.points[#self.points + 1] = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
end
function Widget:SetTitle(t)
	self.title = t
end
function Widget:CreateFontString()
	local fs = NewWidget()
	fs.shown = true
	return fs
end
function Widget:CreateTexture()
	return NewWidget()
end
function Widget:CreateAnimationGroup()
	local ag = NewWidget()
	ag.played = 0
	function ag:CreateAnimation()
		return NewWidget()
	end
	function ag:Play()
		self.played = self.played + 1
	end
	return ag
end
-- A click: the script, then any hooks.
function Widget:Click()
	if self.scripts.OnClick then
		self.scripts.OnClick(self, "LeftButton")
	end
	for _, fn in ipairs(self.hooks.OnClick or {}) do
		fn(self, "LeftButton")
	end
end
UIParent = NewWidget()
UISpecialFrames = {}

CreatedFrames = {}
function CreateFrame(_, name, parent, template)
	local f = NewWidget(name)
	f.parent = parent
	f.template = template
	if template == "ButtonFrameTemplate" then
		f.CloseButton = NewWidget()
		f.CloseButton:SetScript("OnClick", function()
			f:Hide()
		end)
		f.Inset = NewWidget()
	elseif template == "LargeSideTabButtonTemplate" then
		-- SidePanelTabButtonMixin (Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua, forever).
		f.Icon = NewWidget()
		f.SelectedTexture = NewWidget() -- shown until SetChecked(false), as in the XML
		function f:SetFillToInterior(v)
			self.fillToInterior = v
		end
		function f:SetChecked(v)
			self.SelectedTexture:SetShown(v)
		end
		function f:SetCustomOnMouseUpHandler(fn)
			self.customMouseUpHandler = fn
		end
		-- The mixin's OnMouseUp: the tab sound, then the custom handler.
		function f:MouseUp(button, upInside)
			if self.customMouseUpHandler then
				self.customMouseUpHandler(self, button or "LeftButton", upInside ~= false)
			end
		end
	end
	f.shown = true -- like the client: a new frame is shown
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

function ButtonFrameTemplate_HidePortrait(f)
	f.portraitHidden = true
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
function CreateSettingsButtonInitializer(name, text, onClick, tooltip)
	return { text = text, onClick = onClick, tooltip = tooltip }
end
SettingsPanel = {
	GetLayout = function()
		return { AddInitializer = function() end }
	end,
	Hide = function() end,
}
SlashCmdList = {}

-- ---------------------------------------------------------------- tooltips

TooltipDataProcessor = { AddTooltipPostCall = function() end }
GameTooltip = { lines = {} }
function GameTooltip:SetOwner(owner)
	self.owner = owner
	self.lines = {}
	self.title = nil
end
function GameTooltip:SetText(t)
	self.title = t
end
function GameTooltip:AddLine(t)
	table.insert(self.lines, t)
end
function GameTooltip:AddDoubleLine(l)
	table.insert(self.lines, l)
end
function GameTooltip:Show()
	self.shown = true
end
function GameTooltip:Hide()
	self.shown = false
end

-- ---------------------------------------------------------------- items and prices

-- id -> { name=, sell=, class= }
Items = {}
C_Item = {
	GetItemInfo = function(id)
		local i = Items[id]
		if not i then
			return nil
		end
		return i.name, "item:" .. id, 1, 10, 1, "", "", 20, "", 0, i.sell or 0, i.class or 7, 0, 0
	end,
	GetItemNameByID = function(id)
		return Items[id] and Items[id].name
	end,
	GetItemInfoInstant = function(id)
		local i = Items[id]
		return id, "", "", "", 0, i and i.class or 7, 0
	end,
	GetItemIconByID = function()
		return 134400
	end,
}

Prices = {}
Ages = {} -- id -> days since Auctionator last saw it (nil: no record)
AuctionatorCallbacks = {}
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
					return Prices[tonumber(tostring(link):match("item:(%d+)"))]
				end,
				GetAuctionAgeByItemID = function(_, id)
					return Ages[id]
				end,
				-- Auctionator 341: the callback runs after a full or incremental scan's prices land.
				RegisterForDBUpdate = function(_, fn)
					table.insert(AuctionatorCallbacks, fn)
				end,
			},
		},
	}
end
AuctionatorOn(true)
function AuctionatorScan()
	for _, fn in ipairs(AuctionatorCallbacks) do
		fn()
	end
end

-- The open merchant: { {id=, price=, stack=, extended=} }
Merchant = {}
function GetMerchantNumItems()
	return #Merchant
end
function GetMerchantItemID(i)
	return Merchant[i] and Merchant[i].id
end
C_MerchantFrame = {
	GetItemInfo = function(i)
		local m = Merchant[i]
		if not m then
			return nil
		end
		return { price = m.price, stackCount = m.stack or 1, hasExtendedCost = m.extended or false }
	end,
}

-- ---------------------------------------------------------------- professions

-- The player's skill per profession line: Skill[line] = level. SkillMax/SkillMod apply to all.
Skill = {}
SkillMax, SkillMod = 75, 0
-- line -> child line, and what the open crafting window shows.
OpenLine = 197
ChildOf = { [197] = 2948, [129] = 2942 }
ProfName = { [197] = "Tailoring", [129] = "First Aid" }

-- Recipes the character has: id -> { name=, line=, y=, g=, learned=, icon= }
Recipes = {}
ForceBand = {} -- id -> Enum value, to make the client disagree with the data
Schematics = {} -- id -> { out=, qmin=, qmax=, reagents = { {id, qty, [type]} } }
Opened = {}
Craftable = {}

local function ProfInfo(line)
	local lvl = Skill[line]
	if not lvl then
		return nil
	end
	return {
		professionID = ChildOf[line],
		professionName = ProfName[line],
		skillLevel = lvl,
		maxSkillLevel = SkillMax,
		skillModifier = SkillMod,
	}
end

local function LineOfChild(child)
	for line, c in pairs(ChildOf) do
		if c == child then
			return line
		end
	end
	return nil
end

C_TradeSkillUI = {
	GetRecipeInfo = function(id)
		local r = Recipes[id]
		if not r then
			return nil
		end
		local s = Skill[r.line] or 0
		local E = Enum.TradeskillRelativeDifficulty
		local band
		if s >= r.g then
			band = E.Trivial
		elseif s < r.y then
			band = E.Optimal
		elseif s < math.floor((r.y + r.g) / 2) then
			band = E.Medium
		else
			band = E.Easy
		end
		if ForceBand[id] ~= nil then
			band = ForceBand[id]
		end
		return {
			recipeID = id,
			name = r.name,
			learned = r.learned ~= false,
			canSkillUp = band ~= E.Trivial,
			relativeDifficulty = band,
			icon = r.icon or 136243,
			numSkillUps = 1,
		}
	end,
	GetProfessionInfoByRecipeID = function(id)
		local r = Recipes[id]
		return r and ProfInfo(r.line)
	end,
	GetProfessionInfoBySkillLineID = function(child)
		local line = LineOfChild(child)
		return line and ProfInfo(line)
	end,
	GetChildProfessionInfo = function()
		return ProfInfo(OpenLine)
	end,
	GetBaseProfessionInfo = function()
		local p = ProfInfo(OpenLine)
		if p then
			p.professionID = OpenLine
		end
		return p
	end,
	GetRecipeSchematic = function(id)
		local s = Schematics[id]
		if not s then
			return nil
		end
		local slots = {}
		for _, rg in ipairs(s.reagents) do
			table.insert(slots, {
				reagents = { { itemID = rg[1] } },
				quantityRequired = rg[2],
				reagentType = rg[3] or Enum.CraftingReagentType.Basic,
			})
		end
		return { recipeID = id, outputItemID = s.out, quantityMin = s.qmin or 1, quantityMax = s.qmax or 1, reagentSlotSchematics = slots }
	end,
	GetCraftableCount = function(id)
		return Craftable[id] or 0
	end,
	OpenRecipe = function(id)
		table.insert(Opened, id)
	end,
	IsNPCCrafting = function()
		return false
	end,
}

C_SkillInfo = {
	GetSkillLineInfoByID = function()
		return nil
	end,
}

-- ---------------------------------------------------------------- the professions window

ScrollBoxListMixin = { Event = { OnInitializedFrame = "OnInitializedFrame" } }
ScrollUtil = {
	AddInitializedFrameCallback = function(scrollBox, callback, owner)
		scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(o, frame, elementData)
			callback(o, frame, elementData)
		end, owner)
	end,
}

RecipeRows = {} -- { {row=, node=} } on screen
function NewRecipeRow(recipeID)
	local row = NewWidget()
	row.width = 260
	row.Label = NewWidget()
	row.Label.width = 230
	row.SkillUps = NewWidget()
	row.SkillUps.width = 14
	row.Count = NewWidget()
	row.Count.shown = false
	local node = {
		GetData = function()
			return { recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID) }
		end,
	}
	return row, node
end

function MakeProfessionsFrame()
	local box = NewWidget()
	box.callbacks = {}
	function box:RegisterCallback(event, fn, owner)
		self.callbacks[#self.callbacks + 1] = { event = event, fn = fn, owner = owner }
	end
	function box:ForEachFrame(fn)
		for _, e in ipairs(RecipeRows) do
			fn(e.row, e.node)
		end
	end
	-- What the client does after its own row initializer.
	function box:InitRow(row, node)
		for _, cb in ipairs(self.callbacks) do
			if cb.event == ScrollBoxListMixin.Event.OnInitializedFrame then
				cb.fn(cb.owner, row, node)
			end
		end
	end
	ProfessionsFrame = NewWidget("ProfessionsFrame")
	ProfessionsFrame.shown = false
	ProfessionsFrame.CraftingPage = { RecipeList = { ScrollBox = box } }
	-- Forever's right-hand tab column (Camelot Blizzard_ProfessionsFrame.xml): the overview tab,
	-- then one tab per profession that has a crafting window, the rest hidden.
	ProfessionsFrame.ProfessionsOverviewTab = NewWidget()
	ProfessionsFrame.ProfessionsOverviewTab.width = 58
	ProfessionsFrame.rightProfessionTabs = {}
	for i = 1, 7 do
		local t = NewWidget()
		t.width = 58
		t.shown = i <= 2
		ProfessionsFrame.rightProfessionTabs[i] = t
	end
	function ProfessionsFrame:RefreshRightTabs() end
	return ProfessionsFrame
end

function hooksecurefunc(t, name, fn)
	local orig = t[name]
	t[name] = function(...)
		local r = { orig(...) }
		fn(...)
		return table.unpack(r)
	end
end
