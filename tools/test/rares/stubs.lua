-- Minimal Forever client for the Rare Alert feature under fengari (Lua 5.3). Only what the addon
-- touches. Tests mutate the fixture tables below.

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

InInstance = false
function IsInInstance()
	return InInstance, InInstance and "party" or "none"
end

-- Combat lockdown: protected frame calls made in combat are recorded as blocked, like the client.
InCombat = false
function InCombatLockdown()
	return InCombat
end
BlockedCalls = {}

-- ---------------------------------------------------------------- widgets

local Widget = {}
local WidgetMeta = {
	__index = function(_, k)
		return Widget[k] or function() end
	end,
}
local function NewWidget(name, template)
	local w = setmetatable({ scripts = {}, hooks = {}, events = {}, attrs = {}, shown = true, text = "", template = template }, WidgetMeta)
	if name then
		_G[name] = w
		w.name = name
	end
	return w
end
local function Protected(self, what)
	if self.template == "SecureActionButtonTemplate" and InCombat then
		BlockedCalls[#BlockedCalls + 1] = what
		return true
	end
	return false
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
function Widget:HookScript(which, fn)
	self.hooks[which] = fn
end
function Widget:Show()
	if not Protected(self, "Show") then
		self.shown = true
	end
end
function Widget:Hide()
	if not Protected(self, "Hide") then
		self.shown = false
	end
end
function Widget:SetShown(v)
	if not Protected(self, "SetShown") then
		self.shown = v and true or false
	end
end
function Widget:IsShown()
	return self.shown
end
function Widget:SetAttribute(k, v)
	if not Protected(self, "SetAttribute") then
		self.attrs[k] = v
	end
end
function Widget:GetAttribute(k)
	return self.attrs[k]
end
function Widget:SetText(t)
	self.text = t
end
function Widget:SetTexture(t)
	self.texture = t
end
function Widget:CreateFontString()
	return NewWidget()
end
function Widget:CreateTexture()
	return NewWidget()
end
function Widget:GetPoint()
	return "TOP", nil, "TOP", 10, -150
end
-- A click: runs the secure action (recorded) and then the hooked OnClick, down and up.
function Widget:Click(which)
	which = which or "LeftButton"
	for _, down in ipairs({ true, false }) do
		local suffix = which == "LeftButton" and "1" or "2"
		if not down and self.attrs["type" .. suffix] == "macro" then
			RanMacros[#RanMacros + 1] = self.attrs["macrotext" .. suffix]
		end
		if self.hooks.OnClick then
			self.hooks.OnClick(self, which, down)
		end
	end
end
RanMacros = {}
UIParent = NewWidget()
UISpecialFrames = {}

CreatedFrames = {}
function CreateFrame(_, name, _, template)
	local f = NewWidget(name, template)
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

Timers = {}
C_Timer = {
	After = function(delay, fn)
		Timers[#Timers + 1] = { at = Clock + delay, fn = fn }
	end,
}
function RunTimers()
	local due = {}
	for i = #Timers, 1, -1 do
		if Timers[i].at <= Clock then
			due[#due + 1] = table.remove(Timers, i)
		end
	end
	for _, t in ipairs(due) do
		t.fn()
	end
end

-- ---------------------------------------------------------------- alerts

Sounds = {}
function PlaySound(id)
	Sounds[#Sounds + 1] = id
end
SOUNDKIT = { RAID_WARNING = 8959 }
ScreenMessages = {}
RaidWarningFrame = NewWidget()
ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.3, b = 0.1 } }
function RaidNotice_AddMessage(_, text)
	ScreenMessages[#ScreenMessages + 1] = text
end
BoundKey = nil
function GetBindingKey(command)
	BindingAsked = command
	return BoundKey
end
ShiftDown = false
function IsShiftKeyDown()
	return ShiftDown
end

GameTooltip = NewWidget("GameTooltip")
GameTooltip.lines = {}
function GameTooltip:SetOwner()
	self.lines = {}
end
function GameTooltip:SetText(t)
	self.lines = { t }
end
function GameTooltip:AddLine(t)
	table.insert(self.lines, t)
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
function SettingsSet(variable, value)
	RegisteredSettings[variable]:SetValue(value)
end

SlashCmdList = {}
TooltipDataProcessor = { AddTooltipPostCall = function() end } -- other features hook tooltips at login

-- ---------------------------------------------------------------- units

-- token -> { guid=, name=, level=, class=, dead=, canAttack=, exists= }
Units = {}
function UnitExists(token)
	local u = Units[token]
	return u ~= nil and u.exists ~= false
end
function UnitGUID(token)
	return Units[token] and Units[token].guid
end
function UnitName(token)
	return Units[token] and Units[token].name
end
function UnitLevel(token)
	return Units[token] and Units[token].level or 0
end
function UnitClassification(token)
	return Units[token] and Units[token].class or "normal"
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
