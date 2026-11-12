-- One-Button Fishing behavior checks. Runs after stubs.lua and the whole bundle.

local failures, count = 0, 0
local realPrint = print
local function check(label, got, want)
	count = count + 1
	if got ~= want then
		failures = failures + 1
		realPrint("FAIL: " .. label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
	else
		realPrint("ok:   " .. label)
	end
end
local function quiet(fn)
	print = function() end
	local ok, err = pcall(fn)
	print = realPrint
	if not ok then
		error(err)
	end
end

local ns = __ns.features.fishing
local BINDING = "CLICK KroolWorldForeverFishButton:LeftButton"
local function Button()
	return _G.KroolWorldForeverFishButton
end
local function Reel()
	return _G.KroolWorldForeverFishReel
end
local function Targets(list)
	local out = {}
	for _, o in ipairs(list) do
		out[#out + 1] = o.key .. "=" .. o.target
	end
	return table.concat(out, ",")
end
local function ChannelStart(id)
	Channel = id
	FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-guid", id)
end
local function ChannelStop(id)
	Channel = nil
	FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-guid", id)
end
local function RightDown(gap)
	Clock = Clock + gap
	FireEvent("GLOBAL_MOUSE_DOWN", "RightButton")
end
local function RightUp()
	FireEvent("GLOBAL_MOUSE_UP", "RightButton")
end
local function DoubleClick()
	Clock = Clock + 5 -- past any debounce
	RightDown(0)
	RightDown(0.2)
end
local function reset()
	InCombat = false
	BlockedCalls = {}
	Channel = nil
	MainHand = nil
	Loot = 0
	MouseDown = {}
	for k in pairs(State) do
		State[k] = false
	end
	State.control = true
	ns.db.doubleClick = true
end

-- ---------------------------------------------------------------- lifecycle
KnownSpells[7620] = true
Binds[BINDING] = { "F", "SHIFT-F" }
FireEvent("ADDON_LOADED", "KroolWorldForever")
local db = KroolWorldForeverDB.features.fishing
check("feature slice created", type(db), "table")
check("on by default", db.enabled, true)
check("double-click on by default", db.doubleClick, true)
quiet(function()
	FireEvent("PLAYER_LOGIN")
end)
check("enabled after login", ns.enabled, true)
check("key binding named", _G["BINDING_NAME_" .. BINDING], "Fish: Cast Or Reel In")
check("binding header shared", BINDING_HEADER_KROOLWORLDFOREVER, "Krool World")
check("button built", type(Button()), "table")
check("button casts a spell on left click", Button().attrs.type1, "spell")
check("button casts Fishing", Button().attrs.spell1, 7620)
check("click-clearing snippet wrapped on PostClick", WrappedScripts[1] and WrappedScripts[1].script, "PostClick")
check("snippet honors the key-down setting", WrappedScripts[1].body:find("usekeydown", 1, true) ~= nil, true)
check("key-down setting carried as an attribute", Button().attrs.usekeydown, true)
check("hub icon is a file path", ns.icon, "Interface\\Icons\\Trade_Fishing")
check("hub card shows the key", ns.HubStatus():find("Key: F", 1, true) ~= nil, true)
check("hub card shows no pole", ns.HubStatus():find("no pole equipped", 1, true) ~= nil, true)
MainHand = 6256
check("hub card shows the pole", ns.HubStatus():find("pole equipped", 1, true) ~= nil and ns.HubStatus():find("no pole", 1, true) == nil, true)
MainHand = nil
Binds[BINDING] = nil
check("hub card says to bind a key", ns.HubStatus():find("No key: set one in Key Bindings", 1, true) ~= nil, true)
Binds[BINDING] = { "F", "SHIFT-F" }

-- ---------------------------------------------------------------- the spell
KnownSpells[7620] = false
KnownSpells[131474], KnownSpells[7732] = true, true
FireEvent("SPELLS_CHANGED")
check("first known id in list order wins", Button().attrs.spell1, 7732)
InCombat = true
KnownSpells[7732] = false
BlockedCalls = {}
FireEvent("SPELLS_CHANGED")
check("combat: attributes untouched", Button().attrs.spell1, 7732)
check("combat: nothing blocked (never tried)", #BlockedCalls, 0)
InCombat = false
FireEvent("PLAYER_REGEN_ENABLED")
check("after combat: attributes catch up", Button().attrs.spell1, 131474)
KnownSpells[131474] = false
FireEvent("SPELLS_CHANGED")
check("no known spell: nothing to cast", Button().attrs.spell1, nil)
KnownSpells[7620] = true
FireEvent("SPELLS_CHANGED")
check("learned again", Button().attrs.spell1, 7620)

-- ---------------------------------------------------------------- reeling in
reset()
CVars.SoftTargetInteract, CVars.SoftTargetInteractArc, CVars.SoftTargetInteractRange = "1", "0", "10"
ChannelStart(12345)
check("a channel that is not fishing is ignored", #Overrides, 0)
ChannelStart(7620)
check("reel: every bound key goes to INTERACTTARGET", Targets(OverridesOf(Reel())), "F=INTERACTTARGET,SHIFT-F=INTERACTTARGET")
check("reel: SoftTargetInteract 3", CVars.SoftTargetInteract, "3")
check("reel: SoftTargetInteractArc 2", CVars.SoftTargetInteractArc, "2")
check("reel: SoftTargetInteractRange 60", CVars.SoftTargetInteractRange, "60")
check("reel: nothing on the click owner", #OverridesOf(Button()), 0)
ChannelStop(7620)
check("stop: overrides cleared", #Overrides, 0)
check("stop: SoftTargetInteract restored", CVars.SoftTargetInteract, "1")
check("stop: SoftTargetInteractArc restored", CVars.SoftTargetInteractArc, "0")
check("stop: SoftTargetInteractRange restored", CVars.SoftTargetInteractRange, "10")

-- a second cast keeps the player's original values, not ours
ChannelStart(7620)
ChannelStart(7620)
ChannelStop(7620)
check("recast: still restores the original", CVars.SoftTargetInteractRange, "10")

-- combat defers the clearing
ChannelStart(7620)
InCombat = true
BlockedCalls = {}
ChannelStop(7620)
check("combat: stop does not touch bindings", #BlockedCalls, 0)
check("combat: reel overrides still there", #Overrides, 2)
check("combat: CVars still held", CVars.SoftTargetInteract, "3")
InCombat = false
FireEvent("PLAYER_REGEN_ENABLED")
check("combat over: overrides cleared", #Overrides, 0)
check("combat over: CVars restored", CVars.SoftTargetInteractRange, "10")

-- a cast that starts in combat sets nothing
InCombat = true
BlockedCalls = {}
ChannelStart(7620)
check("channel start in combat: no overrides", #Overrides, 0)
check("channel start in combat: CVars untouched", CVars.SoftTargetInteract, "1")
check("channel start in combat: nothing attempted", #BlockedCalls, 0)
InCombat = false
Channel = nil

-- a CVar the player changed while we held it survives the restore
ChannelStart(7620)
CVars.SoftTargetInteractRange = "25"
ChannelStop(7620)
check("player's own value kept", CVars.SoftTargetInteractRange, "25")
check("untouched ones still restored", CVars.SoftTargetInteract, "1")
CVars.SoftTargetInteractRange = "10"

-- logout restores
ChannelStart(7620)
FireEvent("PLAYER_LOGOUT")
check("logout: CVars restored", CVars.SoftTargetInteract, "1")
check("logout: overrides cleared", #Overrides, 0)
Channel = nil

-- ---------------------------------------------------------------- double right-click
reset()
DoubleClick()
check("no pole: a double click does nothing", #Overrides, 0)

MainHand = 2092
DoubleClick()
check("other weapon: nothing", #Overrides, 0)

MainHand = 6256
DoubleClick()
check("pole: BUTTON2 goes to the fish button", Targets(OverridesOf(Button())), "BUTTON2=KroolWorldForeverFishButton")
check("pole: it is a click override", Overrides[1].click, true)
check("pole: nothing on the reel owner", #OverridesOf(Reel()), 0)
RightUp()
check("a cast override waits for its click (the snippet clears it)", #OverridesOf(Button()), 1)
Overrides = {}

-- timing
reset()
MainHand = 6256
Clock = Clock + 5
RightDown(0)
RightDown(0.02)
check("too fast: nothing", #Overrides, 0)
Clock = Clock + 5
RightDown(0)
RightDown(0.5)
check("too slow: nothing", #Overrides, 0)
Clock = Clock + 5
RightDown(0)
RightDown(0.1)
check("in the window: acts", #Overrides, 1)
Overrides = {}
RightDown(0.1)
check("debounce: a third quick click does nothing", #Overrides, 0)
Overrides = {}

-- every gate
local gates = {
	{ "left button held", function() MouseDown.LeftButton = true end },
	{ "loot window open", function() Loot = 2 end },
	{ "in combat", function() InCombat = true end },
	{ "moving", function() State.moving = true end },
	{ "mounted", function() State.mounted = true end },
	{ "flying", function() State.flying = true end },
	{ "falling", function() State.falling = true end },
	{ "swimming", function() State.swimming = true end },
	{ "stealthed", function() State.stealthed = true end },
	{ "in a vehicle", function() State.vehicle = true end },
	{ "without full control", function() State.control = false end },
	{ "option off", function() ns.db.doubleClick = false end },
}
for _, g in ipairs(gates) do
	reset()
	MainHand = 6256
	g[2]()
	DoubleClick()
	check("blocked: " .. g[1], #Overrides, 0)
end
reset()

-- already fishing: BUTTON2 becomes INTERACTTARGET, cleared on the mouse up
MainHand = 6256
ChannelStart(7620)
DoubleClick()
check("fishing: BUTTON2 interacts with the target", Targets(OverridesOf(Button())), "BUTTON2=INTERACTTARGET")
check("fishing: separate owners (reel keys stay on the reel owner)", #OverridesOf(Reel()), 2)
RightUp()
check("mouse up clears the click owner", #OverridesOf(Button()), 0)
check("mouse up leaves the reel keys", #OverridesOf(Reel()), 2)
ChannelStop(7620)
check("stop clears the reel keys", #Overrides, 0)

-- mouse up in combat waits
reset()
MainHand = 6256
ChannelStart(7620)
DoubleClick()
InCombat = true
BlockedCalls = {}
RightUp()
check("combat: mouse up does not clear", #OverridesOf(Button()), 1)
check("combat: nothing attempted", #BlockedCalls, 0)
InCombat = false
FireEvent("PLAYER_REGEN_ENABLED")
check("after combat: the click override is cleared", #OverridesOf(Button()), 0)
check("after combat: the line is still out, reel keys stay", #OverridesOf(Reel()), 2)
ChannelStop(7620)
check("then the stop clears them", #Overrides, 0)
reset()

-- ---------------------------------------------------------------- secrets
local secretOk = pcall(FireEvent, "UNIT_SPELLCAST_CHANNEL_START", "player", "g", Secret())
check("a secret spell id is ignored without error", secretOk and #Overrides == 0, true)
secretOk = pcall(FireEvent, "GLOBAL_MOUSE_DOWN", Secret())
check("a secret mouse button is ignored without error", secretOk, true)

-- ---------------------------------------------------------------- off
reset()
MainHand = 6256
ChannelStart(7620)
DoubleClick()
check("before off: overrides set", #Overrides > 0, true)
quiet(function()
	SlashCmdList.KROOLWORLDFOREVER("fishing off")
end)
check("/kwf fishing off disables", ns.enabled, false)
check("off: every override cleared", #Overrides, 0)
check("off: CVars restored", CVars.SoftTargetInteract, "1")
check("off: button casts nothing", Button().attrs.spell1, nil)
ChannelStart(7620)
check("off: a fishing channel changes nothing", #Overrides, 0)
check("off: CVars untouched", CVars.SoftTargetInteract, "1")
DoubleClick()
check("off: double click does nothing", #Overrides, 0)
Channel = nil
quiet(function()
	SlashCmdList.KROOLWORLDFOREVER("fishing on")
end)
check("on again", ns.enabled, true)
check("on again: button casts", Button().attrs.spell1, 7620)

-- off in combat: deferred, then done by the retry timer
reset()
ChannelStart(7620)
InCombat = true
BlockedCalls = {}
quiet(function()
	SlashCmdList.KROOLWORLDFOREVER("fishing off")
end)
check("off in combat: nothing attempted", #BlockedCalls, 0)
check("off in combat: overrides wait", #Overrides, 2)
InCombat = false
Clock = Clock + 10
RunTimers()
check("combat over: overrides cleared", #Overrides, 0)
check("combat over: CVars restored", CVars.SoftTargetInteract, "1")
check("combat over: button off", Button().attrs.spell1, nil)
quiet(function()
	SlashCmdList.KROOLWORLDFOREVER("fishing on")
end)

realPrint(("\n%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
