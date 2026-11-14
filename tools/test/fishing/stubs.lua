-- Minimal Forever client for the One-Button Fishing feature: the Rare Alert stubs (secure button,
-- combat lockdown, CVars, timers) plus bindings, spells, the equipped pole and player state.

__include("rares/stubs.lua")

Enum = { TooltipDataType = { Unit = 2, Item = 0 }, ItemWeaponSubclass = { Fishingpole = 20 } }
INVSLOT_MAINHAND = 16

CVars.SoftTargetInteract = "1"
CVars.SoftTargetInteractArc = "0"
CVars.SoftTargetInteractRange = "10"
CVars.ActionButtonUseKeyDown = "1"

-- Key bindings: command -> { key1, key2 }
Binds = {}
function GetBindingKey(command)
	local k = Binds[command]
	if k then
		return k[1], k[2]
	end
end

-- Override bindings: a list of { owner, key, target, click } in the order set. Combat blocks them.
Overrides = {}
local function Override(owner, key, target, click)
	if InCombat then
		BlockedCalls[#BlockedCalls + 1] = "Override " .. key
		return
	end
	Overrides[#Overrides + 1] = { owner = owner, key = key, target = target, click = click }
end
function SetOverrideBinding(owner, _, key, command)
	Override(owner, key, command, false)
end
function SetOverrideBindingClick(owner, _, key, buttonName)
	Override(owner, key, buttonName, true)
end
function ClearOverrideBindings(owner)
	if InCombat then
		BlockedCalls[#BlockedCalls + 1] = "ClearOverrideBindings"
		return
	end
	for i = #Overrides, 1, -1 do
		if Overrides[i].owner == owner then
			table.remove(Overrides, i)
		end
	end
end
function OverridesOf(owner)
	local out = {}
	for _, o in ipairs(Overrides) do
		if o.owner == owner then
			out[#out + 1] = o
		end
	end
	return out
end

WrappedScripts = {}
function SecureHandlerWrapScript(frame, script, header, body)
	WrappedScripts[#WrappedScripts + 1] = { frame = frame, script = script, header = header, body = body }
end

-- Spells
KnownSpells = {}
C_SpellBook = {
	IsSpellKnown = function(id)
		return KnownSpells[id] == true
	end,
}

-- The equipped main hand: item id -> weapon subclass
MainHand = nil
Subclasses = { [6256] = 20, [2092] = 15 } -- Fishing Pole, Worn Dagger
function GetInventoryItemID(_, slot)
	if slot == INVSLOT_MAINHAND then
		return MainHand
	end
end
C_Item.GetItemInfoInstant = function(id)
	return id, "Weapon", "Subclass", "INVTYPE_2HWEAPON", 0, 2, Subclasses[id]
end

-- Player state, all false/true by default so the double-click is allowed
State = { moving = false, mounted = false, flying = false, falling = false, swimming = false, stealthed = false, vehicle = false, control = true }
Loot = 0
MouseDown = {}
function IsPlayerMoving()
	return State.moving
end
function IsMounted()
	return State.mounted
end
function IsFlying()
	return State.flying
end
function IsFalling()
	return State.falling
end
function IsSwimming()
	return State.swimming
end
function IsStealthed()
	return State.stealthed
end
function UnitHasVehicleUI()
	return State.vehicle
end
function HasFullControl()
	return State.control
end
function GetNumLootItems()
	return Loot
end
function IsMouseButtonDown(b)
	return MouseDown[b] == true
end
-- What the mouse is over: nil = the game world, or a window's frame (a bag slot, a vendor item).
WorldFrame = { name = "WorldFrame" }
MouseFocus = nil
function GetMouseFoci()
	return { MouseFocus or WorldFrame }
end
Channel = nil -- spell id of the running channel
function UnitChannelInfo()
	if Channel then
		return "Fishing", "Fishing", 1, 0, 0, false, false, Channel
	end
end
