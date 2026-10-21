-- Minimal Forever client for the Setups feature under fengari (Lua 5.3): action bars and the cursor,
-- spells, items, mounts, macros, keybindings, server-stored CVars, the addon list, Edit Mode, and
-- generic widgets so the window can be built and clicked. Tests mutate the fixture tables below.

function wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

function strtrim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

tinsert = table.insert
Clock = 1000000
function time()
	return Clock
end
function date(fmt, t)
	return "T" .. tostring(t or Clock)
end
ACCEPT, CANCEL, YES, NO = "Accept", "Cancel", "Yes", "No"
MAX_ACCOUNT_MACROS = 120

Enum = {
	EditModeLayoutType = { Preset = 0, Account = 1, Character = 2 },
	EditModePresetLayouts = { Modern = 0, Classic = 1 },
	ConsoleCommandType = { Cvar = 0, Command = 1, Macro = 2, Script = 3 },
	TooltipDataType = { Item = 0, Unit = 2 },
	ItemClass = { Questitem = 12 },
	BagIndex = { Backpack = 0 },
}
Constants = { EditModeConsts = { EditModeMaxLayoutsPerType = 5 } }

-- ---------------------------------------------------------------- widgets

-- Every widget accepts any method (unknown ones are no-ops), and keeps what tests look at.
local Widget = {}
local WidgetMeta = {
	__index = function(_, k)
		local m = Widget[k]
		if m then
			return m
		end
		return function() end
	end,
}
local function NewWidget(kind, name)
	local w = setmetatable({ kind = kind, scripts = {}, events = {}, shown = true, enabled = true, text = "", children = {} }, WidgetMeta)
	if name then
		_G[name] = w
		w.name = name
	end
	return w
end
function Widget:SetScript(which, fn)
	self.scripts[which] = fn
end
function Widget:GetScript(which)
	return self.scripts[which]
end
function Widget:RegisterEvent(e)
	self.events[e] = true
end
function Widget:UnregisterEvent(e)
	self.events[e] = nil
end
function Widget:Show()
	self.shown = true
end
function Widget:Hide()
	local was = self.shown
	self.shown = false
	if was and self.scripts.OnHide then
		self.scripts.OnHide(self) -- real frames fire OnHide when a shown frame hides
	end
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
function Widget:SetChecked(v)
	self.checked = v and true or false
end
function Widget:GetChecked()
	return self.checked
end
function Widget:SetEnabled(v)
	self.enabled = v and true or false
end
function Widget:IsEnabled()
	return self.enabled
end
function Widget:GetName()
	return self.name
end
function Widget:CreateFontString()
	return NewWidget("FontString")
end
function Widget:CreateTexture()
	return NewWidget("Texture")
end
function Widget:Click()
	if self.scripts.OnClick then
		self.scripts.OnClick(self)
	end
end

CreatedFrames = {}
function CreateFrame(kind, name, parent, template)
	local f = NewWidget(kind, name)
	f.template = template
	table.insert(CreatedFrames, f)
	return f
end
UIParent = NewWidget("Frame")
UISpecialFrames = {}

function FireEvent(e, ...)
	for _, f in ipairs(CreatedFrames) do
		if f.events[e] and f.scripts.OnEvent then
			f.scripts.OnEvent(f, e, ...)
		end
	end
end

Timers = {}
C_Timer = {
	After = function(_, fn)
		table.insert(Timers, fn)
	end,
	NewTicker = function(_, fn)
		local t = { Cancel = function() end }
		return t
	end,
}
function RunTimers()
	local list = Timers
	Timers = {}
	for _, fn in ipairs(list) do
		fn()
	end
end

-- Popups: StaticPopup_Show records the last one; tests accept it with AcceptPopup(text).
StaticPopupDialogs = {}
LastPopup = nil
function StaticPopup_Show(which, text, _, data)
	LastPopup = { which = which, text = text, data = data }
end
function AcceptPopup(text)
	local p = LastPopup
	LastPopup = nil
	local box = NewWidget("EditBox")
	box.text = text or ""
	local dialog = NewWidget("Frame")
	dialog.which, dialog.data = p.which, p.data
	function dialog:GetEditBox()
		return box
	end
	StaticPopupDialogs[p.which].OnAccept(dialog, p.data)
end

-- Settings: same recorder as the other suites.
RegisteredSettings = {}
local function Category(name)
	return { name = name, GetID = function()
		return name
	end }
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
SettingsButtons = {}
SettingsPanel = {
	GetLayout = function(_, category)
		return { AddInitializer = function(_, init)
			SettingsButtons[category.name] = init
		end }
	end,
	Hide = function() end,
}
function CreateSettingsButtonInitializer(name, text, onClick)
	return { text = text, click = onClick }
end

SlashCmdList = {}
C_UI = { Reload = function()
	Reloaded = true
end }
C_ClassColor = { GetClassColor = function()
	return nil
end }

-- ---------------------------------------------------------------- player / combat

Player = { name = "Kaptain", realm = "Realm", class = "WARRIOR", level = 10 }
function UnitFullName()
	return Player.name, Player.realm
end
function UnitName()
	return Player.name
end
function UnitClass()
	return Player.class, Player.class
end
function UnitLevel()
	return Player.level
end
function GetNormalizedRealmName()
	return Player.realm
end
function UnitGUID()
	return Player.guid or ("Player-1-" .. Player.name)
end
InCombat = false
function InCombatLockdown()
	return InCombat
end

-- ---------------------------------------------------------------- action bars / cursor

Actions = {} -- [slot] = { kind, id }
Cursor = nil -- { kind, id }
KnownSpells = {} -- [spellID] = name
SpellByName = {} -- [name] = spellID the player knows under that name
OwnedItems = {} -- [itemID] = true
MountList = {} -- displayed order: { mountID, ... }

function GetActionInfo(slot)
	local a = Actions[slot]
	if a then
		return a[1], a[2]
	end
end
function GetCursorInfo()
	if Cursor then
		return Cursor[1], Cursor[2]
	end
end
function ClearCursor()
	Cursor = nil
end
function PlaceAction(slot)
	local old = Actions[slot]
	Actions[slot] = Cursor
	Cursor = old
end
function PickupAction(slot)
	Cursor = Actions[slot]
	Actions[slot] = nil
end
C_ActionBar = {
	HasAction = function(slot)
		return Actions[slot] ~= nil
	end,
	GetActionText = function(slot)
		local a = Actions[slot]
		if a and a[1] == "macro" then
			return (GetMacroInfo(a[2]))
		end
	end,
}
C_Spell = {
	GetSpellName = function(id)
		return KnownSpells[id] or SpellNameOf[id]
	end,
	PickupSpell = function(x)
		local id = type(x) == "number" and (KnownSpells[x] and x) or SpellByName[x]
		if id then
			Cursor = { "spell", id }
		end
	end,
}
SpellNameOf = {} -- names of spells the player does not know (for capture)
C_Item = {
	PickupItem = function(id)
		if OwnedItems[id] then
			Cursor = { "item", id }
		end
	end,
}
C_MountJournal = {
	GetNumDisplayedMounts = function()
		return #MountList
	end,
	GetDisplayedMountID = function(i)
		return MountList[i]
	end,
	Pickup = function(i)
		Cursor = { "summonmount", MountList[i] }
	end,
}

-- ---------------------------------------------------------------- macros

AccountMacros, CharMacros = {}, {} -- { name, icon, body }
MacroLimits = { account = 120, char = 18 }
function GetNumMacros()
	return #AccountMacros, #CharMacros
end
function GetMacroInfo(index)
	local m
	if index <= 120 then
		m = AccountMacros[index]
	else
		m = CharMacros[index - 120]
	end
	if m then
		return m.name, m.icon, m.body
	end
end
function GetMacroIndexByName(name)
	for i, m in ipairs(AccountMacros) do
		if m.name == name then
			return i
		end
	end
	for i, m in ipairs(CharMacros) do
		if m.name == name then
			return 120 + i
		end
	end
	return 0
end
function PickupMacro(index)
	if GetMacroInfo(index) then
		Cursor = { "macro", index }
	end
end
function CreateMacro(name, icon, body, perChar)
	local list = perChar and CharMacros or AccountMacros
	if #list >= (perChar and MacroLimits.char or MacroLimits.account) then
		error("too many macros")
	end
	table.insert(list, { name = name, icon = icon, body = body })
	return perChar and (120 + #list) or #list
end

-- ---------------------------------------------------------------- keybindings

BindingCommands = { "MOVEFORWARD", "MOVEBACKWARD", "JUMP", "ACTIONBUTTON1", "ACTIONBUTTON2", "TOGGLEBAG" }
Bound = {} -- [key] = command
BindingSet = 1
SavedBindingSet = nil
local function KeysFor(command)
	local keys = {}
	for k, c in pairs(Bound) do
		if c == command then
			keys[#keys + 1] = k
		end
	end
	table.sort(keys)
	return keys[1], keys[2]
end
function GetNumBindings()
	return #BindingCommands
end
function GetBinding(i)
	local c = BindingCommands[i]
	return c, "category", KeysFor(c)
end
function SetBinding(key, command)
	if command == nil then
		Bound[key] = nil
		return true
	end
	for _, c in ipairs(BindingCommands) do
		if c == command then
			Bound[key] = command
			return true
		end
	end
	return false
end
function SaveBindings(set)
	SavedBindingSet = set
	BindingSet = set
end
function GetCurrentBindingSet()
	return BindingSet
end

-- ---------------------------------------------------------------- cvars

-- [name] = { value, default, account, character, locked, secure, readOnly }
CVars = {}
CVarHelp = {} -- [name] = help text
function ConsoleGetAllCommands()
	local out = {}
	for name in pairs(CVars) do
		out[#out + 1] = { command = name, commandType = 0, help = CVarHelp[name] or "", category = 0 }
	end
	out[#out + 1] = { command = "reloadui", commandType = 1 }
	table.sort(out, function(a, b)
		return a.command < b.command
	end)
	return out
end
C_CVar = {
	GetCVarInfo = function(name)
		local c = CVars[name]
		if c then
			return c[1], c[2], c[3], c[4], c[5], c[6], c[7]
		end
	end,
	SetCVar = function(name, value)
		local c = CVars[name]
		if c[6] then
			error("secure cvar")
		end
		c[1] = tostring(value)
		return true
	end,
}

-- ---------------------------------------------------------------- addons

AddonNames = { "KroolWorldForever", "Questie", "Auctionator", "BugSack" }
AddonOn = {} -- [character] = { [name] = bool }
local function OnFor(char)
	AddonOn[char] = AddonOn[char] or { KroolWorldForever = true, Questie = true, Auctionator = true, BugSack = true }
	return AddonOn[char]
end
C_AddOns = {
	GetNumAddOns = function()
		return #AddonNames
	end,
	GetAddOnInfo = function(i)
		return AddonNames[i]
	end,
	GetAddOnEnableState = function(name, char)
		return OnFor(char)[name] and 2 or 0
	end,
	EnableAddOn = function(name, char)
		OnFor(char)[name] = true
	end,
	DisableAddOn = function(name, char)
		OnFor(char)[name] = false
	end,
}

-- ---------------------------------------------------------------- edit mode

PresetLayouts = { { layoutName = "Modern", layoutType = 0 }, { layoutName = "Classic", layoutType = 0 } }
EditLayouts = { layouts = {}, activeLayout = 1 } -- saved layouts only, like C_EditMode.GetLayouts()
SaveLayoutsCalls = {}
local function Copy(t)
	if type(t) ~= "table" then
		return t
	end
	local o = {}
	for k, v in pairs(t) do
		o[k] = Copy(v)
	end
	return o
end
EditModePresetLayoutManager = {
	GetCopyOfPresetLayouts = function()
		return Copy(PresetLayouts)
	end,
}
C_EditMode = {
	GetLayouts = function()
		return Copy(EditLayouts)
	end,
	ConvertLayoutInfoToString = function(layout)
		return "LAYOUT:" .. layout.layoutName
	end,
	ConvertStringToLayoutInfo = function(s)
		local name = s:match("^LAYOUT:(.+)$")
		if name then
			return { layoutName = name, layoutType = 1, systems = {} }
		end
	end,
	SaveLayouts = function(info)
		table.insert(SaveLayoutsCalls, Copy(info))
		local saved = {}
		for _, l in ipairs(info.layouts) do
			if l.layoutType ~= 0 then
				saved[#saved + 1] = l
			end
		end
		EditLayouts.layouts = saved
	end,
	OnLayoutAdded = function(index, activate)
		if activate then
			EditLayouts.activeLayout = index
		end
	end,
	SetActiveLayout = function(i)
		EditLayouts.activeLayout = i
	end,
	IsValidLayoutName = function(name)
		return #name > 0 and #name <= 32
	end,
}
EditModeManagerFrame = NewWidget("Frame")
EditModeManagerFrame:Hide()
