-- The Reagent Uses suite's client: the Camp Guide stubs (widgets, settings, items, Auctionator, the
-- tooltip post-call chain; enough to load the whole bundle) plus what this feature touches: the
-- player, skills, the crafting window, keys and ordered tooltips. Tests change the fixture tables
-- (Player, Skills, Window, RecipeInfo, Keys, Combat, Instance) and fire events.

__include("camp/stubs.lua")

time = os.time

-- Counts every issecretvalue question (common.lua defines it; the feature keeps a reference taken at
-- load, after this wrapper), so a test can prove a value was checked even where a type test would
-- also have rejected the stub secret.
local realIsSecret = issecretvalue
SecretAsks = 0
function issecretvalue(v)
	SecretAsks = SecretAsks + 1
	return realIsSecret(v)
end

Combat, Instance = false, false
function InCombatLockdown()
	return Combat
end
function IsInInstance()
	return Instance, Instance and "party" or "none"
end

-- ---------------------------------------------------------------- character

Player = { name = "Krool", realm = "Forever", class = "MAGE" }
function UnitFullName(unit)
	if unit == "player" then
		return Player.name, Player.realm
	end
end
function UnitName(unit)
	if unit == "player" then
		return Player.name
	end
end
function GetRealmName()
	return Player.realm
end
function GetNormalizedRealmName()
	return Player.realm
end
function UnitClass(unit)
	if unit == "player" then
		return "Mage", Player.class, 8
	end
end

-- Skills[skill line id] = rank, as C_SkillInfo reports it.
Skills = {}
C_SkillInfo = {
	GetNumSkillLines = function()
		local n = 0
		for _ in pairs(Skills) do
			n = n + 1
		end
		return n
	end,
	GetSkillLineInfoByID = function(id)
		local rank = Skills[id]
		if rank == nil then
			return nil
		end
		return { skillID = id, rank = rank, modifier = 0, maxRank = 300 }
	end,
}

-- Blizzard_ProfessionsTemplates' check: not NPC, guild, guild member or linked.
Professions = {
	InLocalCraftingMode = function()
		return not (Window and (Window.npc or Window.linked))
	end,
}

-- The crafting window: Window = { base = ProfessionInfo, child = ProfessionInfo, npc, linked } or nil.
Window = nil
RecipeInfo = {} -- recipe id -> TradeSkillRecipeInfo (only learned matters here)
RecipeInfoCalls = 0
C_TradeSkillUI = {
	GetBaseProfessionInfo = function()
		return Window and Window.base or nil
	end,
	GetChildProfessionInfo = function()
		return Window and Window.child or nil
	end,
	IsNPCCrafting = function()
		return Window and Window.npc or false
	end,
	GetRecipeInfo = function(id)
		RecipeInfoCalls = RecipeInfoCalls + 1
		if not Window then
			return nil
		end
		return RecipeInfo[id]
	end,
	GetProfessionInfoBySkillLineID = function()
		return nil -- outside the window this answers nothing here; C_SkillInfo carries the rank
	end,
	GetTradeSkillDisplayName = function()
		return nil -- falls back to the English name in Data.lua
	end,
}

SpellNames = {
	[3839] = "Bolt of Silk Cloth",
	[7928] = "Silk Bandage",
	[7929] = "Heavy Silk Bandage",
	[3959] = "Discombobulator Ray",
	[3962] = "Iron Grenade",
	[8243] = "Flash Bomb",
	[9273] = "Goblin Jumper Cables",
	[12586] = "Solid Dynamite",
	[23069] = "EZ-Thro Dynamite II",
	[1266916] = "EZ-Thro Grenade",
}
C_Spell = {
	GetSpellName = function(id)
		return SpellNames[id] or ("Recipe " .. id)
	end,
}

-- ---------------------------------------------------------------- keys and timers

Keys = { CTRL = false, ALT = false, SHIFT = false }
function IsControlKeyDown()
	return Keys.CTRL
end
function IsAltKeyDown()
	return Keys.ALT
end
function IsShiftKeyDown()
	return Keys.SHIFT
end

-- C_Timer.After queues; RunTimers runs what is queued (and only that).
Timers = {}
C_Timer.After = function(_, fn)
	Timers[#Timers + 1] = fn
end
function RunTimers()
	local list = Timers
	Timers = {}
	for _, fn in ipairs(list) do
		fn()
	end
end

Fire = FireEvent

-- ---------------------------------------------------------------- tooltips

-- Tooltips keep every line in order (rows = { {left=, right=}, ... }) beside camp's left/right/lines.
local TipMethods = {}
local function NewTip()
	return setmetatable({ left = {}, right = {}, lines = {}, rows = {}, shown = false, item = nil, refreshes = 0 }, { __index = TipMethods })
end
function TipMethods:Reset()
	self.left, self.right, self.lines, self.rows, self.link = {}, {}, {}, {}, nil
end
function TipMethods:AddLine(text)
	table.insert(self.lines, text)
	self.rows[#self.rows + 1] = { left = text }
end
function TipMethods:AddDoubleLine(l, r)
	table.insert(self.left, l)
	table.insert(self.right, r)
	self.rows[#self.rows + 1] = { left = l, right = r }
end
function TipMethods:IsShown()
	return self.shown
end
function TipMethods:GetOwner()
	return self.owner
end
function TipMethods:GetItem()
	return "name", self.link, self.item
end
function TipMethods:RefreshData()
	self.refreshes = self.refreshes + 1
end
function TipMethods:SetOwner() end
function TipMethods:SetText() end
function TipMethods:Show() end
function TipMethods:Hide() end
GameTooltip = NewTip()
ItemRefTooltip = NewTip()
ShoppingTooltip1 = NewTip()

-- Shows item on tooltip the way the client does: clear, then every item post-call. Returns the rows.
function ShowTip(tip, item, data)
	tip:Reset()
	tip.item = item
	tip.link = type(item) == "number" and ("item:" .. item) or nil
	tip.shown = true
	for _, fn in ipairs(TooltipChains[Enum.TooltipDataType.Item] or {}) do
		fn(tip, data or { id = item, lines = {} })
	end
	return tip.rows
end

-- ---------------------------------------------------------------- settings

-- What the settings panel was given: the dropdowns' choices, the sliders' ranges and the controls
-- made, by setting variable (every feature registers its settings, so look ours up by name).
SettingsLog = { dropdown = {}, controls = {}, sliders = {} }
Settings.VarType.String = "string"
do
	local register = Settings.RegisterAddOnSetting
	Settings.RegisterAddOnSetting = function(category, variable, key, tbl, varType, label, default)
		local s = register(category, variable, key, tbl, varType, label, default)
		s.varType, s.variable = varType, variable
		return s
	end
end
Settings.CreateCheckbox = function(_, setting)
	SettingsLog.controls[setting.variable] = "checkbox"
end
Settings.CreateSlider = function(_, setting, options)
	SettingsLog.controls[setting.variable] = "slider"
	SettingsLog.sliders[setting.variable] = options
end
Settings.CreateDropdown = function(_, setting, options, tooltip)
	SettingsLog.controls[setting.variable] = "dropdown"
	SettingsLog.dropdown[setting.variable] = options()
	SettingsLog.tooltip = tooltip
end
Settings.CreateControlTextContainer = function()
	local c = { data = {} }
	function c:Add(value, label)
		self.data[#self.data + 1] = { value = value, label = label }
	end
	function c:GetData()
		return self.data
	end
	return c
end
