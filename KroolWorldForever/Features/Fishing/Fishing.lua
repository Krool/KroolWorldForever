-- One-Button Fishing: one key casts the line and, while the line is out, the same key reels the
-- bite in. With a fishing pole in your main hand, a double right-click does the same.
--
-- Casting and reeling always come from your own key press or click. The key is a CLICK binding on
-- a secure button that casts Fishing (the game itself refuses without a pole). While the line is
-- out the addon only re-points your keys at "interact with target" (and turns on the soft-target
-- CVars that find the bobber); when the line is in, everything goes back. Bindings, attributes
-- and CVars change only out of combat; what combat holds up waits for it to end.
--
-- Mechanics follow BetterFishing (third-party, proven on Forever); this is a fresh write. Unlike
-- it, the key is a CLICK binding, so it casts on the first press (no "arm, then cast" step).

local _, root = ...
local ns = root.Feature("fishing")

local BUTTON = "KroolWorldForeverFishButton"
local REEL_OWNER = "KroolWorldForeverFishReel" -- owns the reel overrides
local BINDING = "CLICK " .. BUTTON .. ":LeftButton"
-- Fishing ranks and variants, tried in this order; the first one the character knows is cast.
local CAST_IDS = { 7620, 7731, 7732, 18248, 33095, 51294, 88868, 110410, 131474, 158743 }
local IS_FISHING = {}
for _, id in ipairs(CAST_IDS) do
	IS_FISHING[id] = true
end
-- Soft-target settings that make the bobber the interact target.
local REEL_CVARS = { { "SoftTargetInteract", 3 }, { "SoftTargetInteractArc", 2 }, { "SoftTargetInteractRange", 60 } }
local DOUBLE_MIN, DOUBLE_MAX = 0.04, 0.4 -- seconds between the two right-clicks
local DEBOUNCE = 0.5 -- after acting, ignore clicks this long

-- Key Bindings > AddOns (Bindings.xml). The header is set by Rare Alert too; same text.
BINDING_HEADER_KROOLWORLDFOREVER = "Krool World"
_G["BINDING_NAME_" .. BINDING] = "Fish: Cast Or Reel In"

local button, reelOwner
local held = {} -- cvar -> { orig = value before us, mine = the value we set }
local reeling = false -- a fishing channel is running (by our events)
local clickBound = false -- BUTTON2 is overridden by a double-click
local interactBound = false -- ... to INTERACTTARGET (cleared on the mouse up)
local dirty = false -- something waits for combat to end
local lastDown, lastAct = nil, nil
local retry = false

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

local function InCombat()
	return InCombatLockdown and InCombatLockdown() and true or false
end

local function Now()
	return GetTime and GetTime() or 0
end

-- A value from the client, or nil when the call fails or the value is secret.
local function Read(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, v = pcall(fn, ...)
	if not ok or Secret(v) then
		return nil
	end
	return v
end

-- true when the condition holds or cannot be told (secret): the safe answer for a "not while" test.
local function Is(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	local ok, v = pcall(fn, ...)
	if not ok then
		return false
	end
	if Secret(v) then
		return true
	end
	return v and true or false
end

local function BindingKeys()
	local ok, a, b = pcall(GetBindingKey, BINDING)
	if not ok then
		return nil, nil
	end
	if type(a) ~= "string" or a == "" then
		a = nil
	end
	if type(b) ~= "string" or b == "" then
		b = nil
	end
	return a, b
end

local function CastId()
	if not (C_SpellBook and C_SpellBook.IsSpellKnown) then
		return nil
	end
	for _, id in ipairs(CAST_IDS) do
		if Read(C_SpellBook.IsSpellKnown, id) == true then
			return id
		end
	end
	return nil
end

local function PoleEquipped()
	local slot = INVSLOT_MAINHAND or 16
	local itemId = Read(GetInventoryItemID, "player", slot)
	if type(itemId) ~= "number" or not (C_Item and C_Item.GetItemInfoInstant) then
		return false
	end
	local ok, _, _, _, _, _, _, subclass = pcall(C_Item.GetItemInfoInstant, itemId)
	if not ok or Secret(subclass) then
		return false
	end
	local pole = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole
	return pole ~= nil and subclass == pole
end

local function IsFishing()
	if reeling then
		return true
	end
	if type(UnitChannelInfo) ~= "function" then
		return false
	end
	local ok, _, _, _, _, _, _, _, id = pcall(UnitChannelInfo, "player")
	if not ok or Secret(id) or type(id) ~= "number" then
		return false
	end
	return IS_FISHING[id] == true
end

-- -------------------------------------------------------------------- CVars

local function GetCVarValue(name)
	if not (C_CVar and C_CVar.GetCVar) then
		return nil
	end
	local v = Read(C_CVar.GetCVar, name)
	return type(v) == "string" and v or nil
end

local function HoldCVars()
	for _, c in ipairs(REEL_CVARS) do
		local name, want = c[1], tostring(c[2])
		local cur = GetCVarValue(name)
		if held[name] then
			if cur ~= held[name].mine then
				held[name].mine = nil -- the player changed it while we hold it: leave their value
			end
		elseif cur ~= nil then
			held[name] = { orig = cur, mine = want }
		end
		if held[name] and held[name].mine and C_CVar and C_CVar.SetCVar then
			pcall(C_CVar.SetCVar, name, want)
		end
	end
end

-- Puts back what we changed, unless the player has changed it since. Out of combat only.
local function RestoreCVars()
	if InCombat() then
		return false
	end
	for name, h in pairs(held) do
		if h.mine ~= nil and GetCVarValue(name) == h.mine and C_CVar and C_CVar.SetCVar then
			pcall(C_CVar.SetCVar, name, h.orig)
		end
		held[name] = nil
	end
	return true
end

-- -------------------------------------------------------------------- the button

local function UseKeyDown()
	return GetCVarValue("ActionButtonUseKeyDown") == "1"
end

-- Clears the double-click override after its one click. It runs in the secure environment, so it
-- works in combat too.
local CLEAR_SNIPPET = [[
	local useKeyDown = self:GetAttribute("usekeydown")
	if (useKeyDown and down) or (not useKeyDown and not down) then
		self:ClearBindings()
	end
]]

local function Build()
	if button then
		return button
	end
	if InCombat() then
		return nil
	end
	local b = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyUp", "AnyDown") -- works whichever way ActionButtonUseKeyDown is set
	b:SetAttribute("type1", "spell")
	if SecureHandlerWrapScript then
		SecureHandlerWrapScript(b, "PostClick", b, CLEAR_SNIPPET)
	end
	reelOwner = reelOwner or CreateFrame("Frame", REEL_OWNER, UIParent)
	button = b
	return b
end

-- Points the button at the first fishing spell the character knows (nothing while the feature is
-- off). Out of combat only; combat sets `dirty`.
local function SyncButton()
	if InCombat() then
		dirty = true
		return
	end
	local b = Build()
	if not b then
		dirty = true
		return
	end
	b:SetAttribute("spell1", ns.enabled and CastId() or nil)
	b:SetAttribute("usekeydown", UseKeyDown())
end

-- -------------------------------------------------------------------- overrides

local function ClearReel()
	if reelOwner then
		ClearOverrideBindings(reelOwner)
	end
end

local function ClearClick()
	if button then
		ClearOverrideBindings(button)
	end
	clickBound, interactBound = false, false
end

-- The line is out: my keys reel the bite in.
local function StartReel()
	if InCombat() then
		return
	end
	Build()
	reeling = true
	HoldCVars()
	local k1, k2 = BindingKeys()
	for _, key in ipairs({ k1 or false, k2 or false }) do
		if key then
			SetOverrideBinding(reelOwner, true, key, "INTERACTTARGET")
		end
	end
end

-- The line is in (or the feature went off): everything back. Combat defers it.
local function StopReel()
	reeling = false
	if InCombat() then
		dirty = true
		return
	end
	ClearReel()
	RestoreCVars()
end

local function Cleanup()
	if InCombat() then
		dirty = true
		return false
	end
	dirty = false
	ClearReel()
	ClearClick()
	RestoreCVars()
	SyncButton()
	return true
end

-- -------------------------------------------------------------------- double right-click

local function CanFish()
	if IsMouseButtonDown and Is(IsMouseButtonDown, "LeftButton") then
		return false
	end
	if InCombat() then
		return false
	end
	if (Read(GetNumLootItems) or 0) ~= 0 then
		return false
	end
	if Is(IsPlayerMoving) or Is(IsMounted) or Is(IsFlying) or Is(IsFalling) or Is(IsSwimming) or Is(IsStealthed) then
		return false
	end
	if Is(UnitHasVehicleUI, "player") then
		return false
	end
	if type(HasFullControl) == "function" and Read(HasFullControl) ~= true then
		return false
	end
	return true
end

local function OnMouseDown(_, which)
	if Secret(which) or which ~= "RightButton" then
		return
	end
	if not ns.db.doubleClick or not PoleEquipped() then
		lastDown = nil
		return
	end
	local now = Now()
	local gap = lastDown and (now - lastDown) or nil
	lastDown = now
	if not gap or gap < DOUBLE_MIN or gap > DOUBLE_MAX then
		return
	end
	if lastAct and now - lastAct < DEBOUNCE then
		return
	end
	if not CanFish() then
		return
	end
	if IsFishing() then
		Build()
		if not button then
			return
		end
		SetOverrideBinding(button, true, "BUTTON2", "INTERACTTARGET")
		clickBound, interactBound = true, true
		lastDown, lastAct = nil, now
	elseif CastId() then
		SyncButton()
		if not button or InCombat() then
			return
		end
		SetOverrideBindingClick(button, true, "BUTTON2", BUTTON)
		clickBound = true
		lastDown, lastAct = nil, now
	end
end

local function OnMouseUp(_, which)
	if Secret(which) or which ~= "RightButton" or not interactBound then
		return
	end
	if InCombat() then
		dirty = true
		return
	end
	ClearClick()
end

-- -------------------------------------------------------------------- definition

ns.title = "One-Button Fishing"
ns.description = "One key casts your line and reels in the bite: set it in Key Bindings > AddOns > Krool World. "
	.. "With a fishing pole in your main hand a double right-click does the same. "
	.. "Every cast and reel is your own key press or click; the addon only re-points keys, and only out of combat."
ns.icon = "Interface\\Icons\\Trade_Fishing"
ns.blurb = "One key to cast and reel in"
ns.options = {
	{
		key = "doubleClick",
		type = "toggle",
		label = "Double Right-Click To Fish",
		tooltip = "While a fishing pole is in your main hand, a quick double right-click casts, and reels in when the line is out. Not while moving, mounted, swimming, stealthed, in a vehicle or in combat.",
		default = true,
	},
}
ns.slash = { "/kwfish" }

function ns.HubStatus()
	local key = BindingKeys()
	local line = key and ("Key: " .. key) or "No key: set one in Key Bindings"
	return "|cffaaaaaa" .. line .. "  ·  " .. (PoleEquipped() and "pole equipped" or "no pole equipped") .. "|r"
end

function ns.OnSlash(msg)
	local key = BindingKeys()
	ns:Print(key and ("press " .. key .. " to cast, and again to reel in") or "no key yet: set one in Key Bindings > AddOns > Krool World")
	print("  fishing pole: " .. (PoleEquipped() and "equipped" or "not equipped") .. "; double right-click " .. (ns.db.doubleClick and "on" or "off"))
end

-- Combat held something up while the feature was off: no events reach it, so look again.
local function Retry()
	retry = false
	if Cleanup() then
		return
	end
	if not ns.enabled and C_Timer then
		retry = true
		C_Timer.After(2, Retry)
	end
end

function ns.OnEnable()
	SyncButton()
end

function ns.OnDisable()
	reeling = false
	lastDown = nil
	if not Cleanup() and not retry and C_Timer then
		retry = true
		C_Timer.After(2, Retry)
	end
end

function ns.OnOptionChanged(key)
	if key == "doubleClick" and not ns.db.doubleClick then
		lastDown = nil
		if clickBound then
			if InCombat() then
				dirty = true
			else
				ClearClick()
			end
		end
	end
end

ns:RegisterEvent("SPELLS_CHANGED", function()
	SyncButton()
end)
ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if dirty then
		dirty = false
		if interactBound then
			ClearClick() -- the right button came up in combat
		end
		if reeling then
			SyncButton() -- still fishing: keep the reel keys, only the button catches up
		else
			Cleanup()
		end
	end
end)
ns:RegisterEvent("CVAR_UPDATE", function(_, name)
	if not Secret(name) and name == "ActionButtonUseKeyDown" then
		SyncButton()
	end
end)
ns:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", function(_, unit, _, spellId)
	if Secret(unit) or unit ~= "player" or Secret(spellId) or not IS_FISHING[spellId] then
		return
	end
	StartReel()
end)
ns:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit, _, spellId)
	if Secret(unit) or unit ~= "player" or Secret(spellId) or not IS_FISHING[spellId] then
		return
	end
	StopReel()
end)
ns:RegisterEvent("PLAYER_LOGOUT", function()
	reeling = false
	pcall(ClearReel)
	pcall(RestoreCVars)
end)
ns:RegisterEvent("GLOBAL_MOUSE_DOWN", OnMouseDown)
ns:RegisterEvent("GLOBAL_MOUSE_UP", OnMouseUp)
