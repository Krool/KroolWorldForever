-- Rare Alert: tells you when a rare enemy is near (its nameplate shows, you mouse over it, or you
-- target it) and offers one button and one key that target it and put a raid marker on it.
--
-- Nameplates are the only way to notice a rare without touching it (Forever has no vignettes), and
-- Forever ships enemy nameplates off (nameplateShowEnemies 0, 45 yards). The hub card and the
-- settings page offer to turn them on; the alert and the button carry Kill Value's numbers.
--
-- Forever, like Midnight 12.0, makes SetRaidTarget protected: addon code cannot mark anything. The
-- button is a SecureActionButton whose macro runs /targetexact and /tm, so the mark always comes
-- from your own click or key press. Secure frames lock in combat: a rare found in combat gets the
-- alert, and the button catches up when combat ends. Inside instances unit data is secret, so
-- nothing is checked there.
--
-- The button goes as soon as its work is done: the rare carries your marker (the key still
-- retargets it), it died, or you right-clicked it away. There is no death event an addon can read
-- (the combat log is closed), so death is seen on its nameplate leaving, its corpse under your
-- target or mouse, or when combat ends. In combat the button can only fade; it hides after.

local _, root = ...
local ns = root.Feature("rares")

local BUTTON = "KroolWorldForeverRareButton"
local BINDING = "CLICK " .. BUTTON .. ":LeftButton"
local SEEN_TTL = 300 -- seconds before another spawn of the same rare alerts
local SHOW_FOR = 60 -- seconds the button stays up after the last sighting
local FADED = 0.35 -- the button's alpha while combat keeps it from hiding
local MARKER_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
-- The classification badges Blizzard's nameplates use (Blizzard_NamePlateClassificationFrame.lua).
local BADGE = { rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", rareelite = "nameplates-icon-elite-silver" }
-- Always up, never worth a stop: ignored until you unignore them.
local DEFAULT_IGNORE = { [3581] = "Sewer Beast" } -- the crocolisk in the Stormwind canals

-- Key Bindings > AddOns (Bindings.xml)
BINDING_HEADER_KROOLWORLDFOREVER = "Krool World"
_G["BINDING_NAME_" .. BINDING] = "Target And Mark Rare"

local current -- the newest sighting: { npcId, guid, name, level, elite, at, marked }
local lastAlert = {} -- npcId -> when it last alerted
local alerted = {} -- guid -> true: this spawn has alerted (once per spawn)
local done = {} -- guid -> "killed" | "dismissed" | "marked": no button for this spawn
local plates = {} -- nameplate token -> the rare's guid, to read its death when the plate goes
local pending = false -- the button needs an update once combat ends
local expiry = false -- a timer is waiting to take the button down
local button

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

local function Now()
	return GetTime and GetTime() or 0
end

local function InCombat()
	return InCombatLockdown and InCombatLockdown() and true or false
end

-- "Creature-0-<server>-<instance>-<zone>-<npcID>-<spawn>": the 6th field.
local function NpcId(guid)
	local kind, id = guid:match("^(%a+)%-%d+%-%w+%-%w+%-%w+%-(%d+)%-")
	if kind == "Creature" or kind == "Vehicle" then
		return tonumber(id)
	end
	return nil
end
ns.NpcId = NpcId -- test seam

local function Read(fn, ...)
	local ok, v = pcall(fn, ...)
	if not ok or Secret(v) then
		return nil
	end
	return v
end

-- A live, attackable rare on `unit`, or nil.
local function Candidate(unit)
	if not Read(UnitExists, unit) then
		return nil
	end
	local inInstance = Read(IsInInstance)
	if inInstance ~= false then
		return nil -- inside (or unknown): unit data is secret there
	end
	local cls = Read(UnitClassification, unit)
	if cls ~= "rare" and cls ~= "rareelite" then
		return nil
	end
	if Read(UnitIsDead, unit) ~= false or Read(UnitCanAttack, "player", unit) ~= true then
		return nil
	end
	local guid = Read(UnitGUID, unit)
	local name = Read(UnitName, unit)
	local npcId = type(guid) == "string" and NpcId(guid)
	if not npcId or type(name) ~= "string" or name == "" then
		return nil
	end
	local level = Read(UnitLevel, unit)
	return {
		npcId = npcId,
		guid = guid,
		name = name,
		level = type(level) == "number" and level or nil,
		elite = cls == "rareelite",
	}
end

local function BindingKey()
	local ok, key = pcall(GetBindingKey, BINDING)
	if ok and type(key) == "string" and key ~= "" then
		return key
	end
	return nil
end

local function Marker()
	local m = tonumber(ns.db and ns.db.marker) or 8
	return math.max(1, math.min(8, math.floor(m)))
end

-- Clears the target first, so a rare that is out of reach leaves you with no target, and /tm
-- then marks nothing. "!" keeps a second press from toggling the marker off.
function ns.Macro(name)
	return ("/cleartarget\n/targetexact %s\n/tm [exists] !%d"):format(name, Marker())
end

local function Describe(r)
	local lvl = r.level and r.level > 0 and (" (" .. r.level .. (r.elite and " elite" or "") .. ")") or (r.elite and " (elite)" or "")
	return r.name .. lvl
end

-- -------------------------------------------------------------------- nameplates

local PLATE_RANGE = 80 -- asked for; the client keeps what it allows

local function GetCVarValue(name)
	if not (C_CVar and C_CVar.GetCVar) then
		return nil
	end
	local ok, v = pcall(C_CVar.GetCVar, name)
	if ok and type(v) == "string" and not Secret(v) then
		return v
	end
	return nil
end

-- true / false, or nil when the client will not say.
function ns.EnemyPlatesOn()
	local v = GetCVarValue("nameplateShowEnemies")
	if v == nil then
		return nil
	end
	return v == "1"
end

-- Turns enemy nameplates on and asks for the longest range. Only from the player's click or command.
function ns.EnableNameplates()
	if InCombat() then
		ns:Print("leave combat first (nameplate settings are locked in combat)")
		return false
	end
	if not (C_CVar and C_CVar.SetCVar) then
		return false
	end
	local ok = pcall(C_CVar.SetCVar, "nameplateShowEnemies", "1")
	pcall(C_CVar.SetCVar, "nameplateMaxDistance", tostring(PLATE_RANGE))
	local range = tonumber(GetCVarValue("nameplateMaxDistance") or "")
	if not ok or ns.EnemyPlatesOn() ~= true then
		ns:Print("could not turn enemy nameplates on; press V or use Options > Interface > Nameplates")
		return false
	end
	ns:Print("enemy nameplates on" .. (range and (", range " .. math.floor(range + 0.5) .. " yards") or "")
		.. ". Rares now show up as soon as their nameplate does (V turns them off again).")
	if root.RefreshHub then
		pcall(root.RefreshHub)
	end
	return true
end

-- -------------------------------------------------------------------- what it is worth

-- Kill Value's breakdown for the rare (nil when Kill Value is off or knows nothing).
local function Worth(npcId)
	local kv, FKV = root.features.killvalue, root.public.KillValue
	if not (kv and kv.enabled and FKV and FKV.Compute) then
		return nil
	end
	local ok, acc = pcall(FKV.Compute, npcId)
	if not ok or type(acc) ~= "table" or acc.learning or not acc.total then
		return nil
	end
	return acc, FKV
end

local function ItemName(id)
	if not C_Item then
		return "item " .. id
	end
	local ok, name = pcall(C_Item.GetItemNameByID, id)
	if ok and type(name) == "string" then
		return name
	end
	pcall(C_Item.RequestLoadItemDataByID, id) -- named on the next look
	return "item " .. id
end

-- Its best drops by value: the main list first, then the rare tail.
local function BestDrops(acc, n)
	local out = {}
	for _, list in ipairs({ acc.top or {}, acc.raretop or {} }) do
		for _, c in ipairs(list) do
			if #out >= n then
				return out
			end
			if (c.value or 0) >= 1 then
				out[#out + 1] = c
			end
		end
	end
	return out
end

-- "worth about 1g 20s: Vultros's Head 14%, Linen Cloth x1.2" (or nil)
local function WorthLine(npcId)
	local acc, FKV = Worth(npcId)
	if not acc then
		return nil
	end
	local parts = {}
	for _, c in ipairs(BestDrops(acc, 3)) do
		parts[#parts + 1] = ItemName(c.id) .. " " .. FKV.FmtQty(c.qty)
	end
	return "worth about " .. FKV.Money(acc.total) .. (#parts > 0 and (": " .. table.concat(parts, ", ")) or "")
end
ns.WorthLine = WorthLine -- test seam

-- -------------------------------------------------------------------- the button

local function SavePosition(b)
	local point, _, _, x, y = b:GetPoint(1)
	if point then
		ns.db.pos = { point, x, y }
	end
end

local function Build()
	if button then
		return button
	end
	if InCombat() then
		return nil -- secure frames cannot be set up in combat
	end
	local b = CreateFrame("Button", BUTTON, UIParent, "SecureActionButtonTemplate")
	b:SetSize(46, 46)
	b:SetFrameStrata("HIGH")
	local p = ns.db.pos
	if type(p) == "table" and p[1] then
		b:SetPoint(p[1], UIParent, p[1], p[2] or 0, p[3] or 0)
	else
		b:SetPoint("TOP", UIParent, "TOP", 0, -170)
	end
	b:RegisterForClicks("AnyUp", "AnyDown") -- works whichever way ActionButtonUseKeyDown is set
	b:SetAttribute("type1", "macro")
	b:SetAttribute("macrotext1", "")
	b:SetMovable(true)
	b:SetClampedToScreen(true)
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnDragStart", function(self)
		if IsShiftKeyDown() and not InCombat() then
			self:StartMoving()
		end
	end)
	b:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition(self)
	end)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	local glow = b:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	glow:SetTexture(MARKER_ICON .. "8")
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.5)
	b.glow = glow
	-- A soft ring breathes behind the skull while the button waits (the minimap's looping glow).
	-- Only child textures animate: nothing about the secure frame itself changes in combat.
	b.ring = b:CreateTexture(nil, "BACKGROUND")
	b.ring:SetSize(80, 80)
	b.ring:SetPoint("CENTER")
	b.ring:SetAtlas(root.UI.ATLAS.glow)
	b.ring:SetBlendMode("ADD")
	b.ring:SetVertexColor(1, 0.85, 0.4)
	b.pulse = root.UI.Pulse(b.ring, 0.2, 0.75, 1)
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
	b.badge = b:CreateTexture(nil, "OVERLAY")
	b.badge:SetSize(16, 16)
	b.badge:SetPoint("RIGHT", b.label, "LEFT", -2, 0)
	b.hint = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.hint:SetPoint("TOP", b.label, "BOTTOM", 0, -1)
	b:HookScript("OnShow", function()
		pcall(b.pulse.Start)
		pcall(root.UI.Pop, b.icon)
	end)
	b:HookScript("OnHide", function()
		pcall(b.pulse.Stop)
	end)
	-- Pressed look: the skull darkens while the mouse button is down (a color, never a position).
	b:HookScript("OnMouseDown", function()
		b.icon:SetVertexColor(0.7, 0.7, 0.7)
	end)
	b:HookScript("OnMouseUp", function()
		b.icon:SetVertexColor(1, 1, 1)
	end)
	b:HookScript("OnClick", function(_, which, down)
		if which ~= "RightButton" or down or not current then
			return
		end
		if IsShiftKeyDown() then
			if current.npcId > 0 then -- 0: the /kwr test entry
				root.Try(ns, "button", ns.Ignore, current.npcId, current.name)
			end
		else
			root.Try(ns, "button", ns.Dismiss)
		end
	end)
	b:SetScript("OnEnter", function(self)
		if not (GameTooltip and current) then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local badge = BADGE[current.elite and "rareelite" or "rare"]
		GameTooltip:SetText(root.UI.InlineAtlas(badge, 16) .. " " .. Describe(current), 1, 0.82, 0)
		local acc, FKV = Worth(current.npcId)
		if acc then
			GameTooltip:AddLine("Kill value " .. FKV.Money(acc.total), 0.2, 1, 0.6)
			for _, c in ipairs(BestDrops(acc, 4)) do
				GameTooltip:AddLine("  " .. root.UI.ItemIcon(c.id, 14) .. ItemName(c.id) .. " " .. FKV.FmtQty(c.qty) .. "  " .. FKV.Money(c.value), 0.8, 0.8, 0.8)
			end
		end
		local key = BindingKey()
		GameTooltip:AddLine(root.UI.InlineIcon(MARKER_ICON .. Marker(), 14, true) .. " Click" .. (key and (" or press " .. key) or "") .. ": target it and mark it.", 1, 1, 1, true)
		if not key then
			GameTooltip:AddLine("Bind a key: Key Bindings > AddOns > Krool World.", 0.7, 0.7, 0.7, true)
		end
		GameTooltip:AddLine("Right-click: hide it.  Shift-right-click: ignore this rare.  Shift-drag: move.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	b:Hide()
	button = b
	return b
end

local Expire, TokenFor -- forward

-- Points the button (and the key) at the newest rare, or clears it. Combat locks the secure
-- button, so there it only fades when it should go, and the rest waits for combat to end.
local function UpdateButton()
	if current and (Now() - current.at > SHOW_FOR or ns.db.ignore[current.npcId]) then
		current = nil
	end
	if InCombat() then
		pending = true
		if button and (not current or current.marked or not ns.enabled) then
			pcall(button.SetAlpha, button, FADED) -- alpha is not locked in combat
		end
		return
	end
	pending = false
	if not current and not button then
		return
	end
	local b = Build()
	if not b then
		pending = true
		return
	end
	b:SetAlpha(1)
	if not current or not ns.enabled then
		b:SetAttribute("macrotext1", "")
		b:Hide()
		return
	end
	b:SetAttribute("macrotext1", ns.Macro(current.name))
	b.icon:SetTexture(MARKER_ICON .. Marker())
	b.glow:SetTexture(MARKER_ICON .. Marker())
	b.label:SetText(current.name)
	b.badge:SetAtlas(BADGE[current.elite and "rareelite" or "rare"])
	local key = BindingKey()
	b.hint:SetText(key and ("Click or " .. key) or "Click to mark")
	-- Marked: the key still retargets it, the button has nothing left to do.
	b:SetShown(ns.db.button and not current.marked and true or false)
	if not expiry then
		expiry = true
		C_Timer.After(SHOW_FOR + 1, Expire)
	end
end
ns.UpdateButton = UpdateButton

function Expire()
	expiry = false
	-- Still in view (its nameplate, your target or mouseover) and alive: that is a sighting too. A
	-- plate that stays up fires no new NAME_PLATE_UNIT_ADDED to refresh it.
	if current and current.guid ~= "" then
		local t = TokenFor(current.guid)
		if t and Read(UnitIsDead, t) == false then
			current.at = Now()
		end
	end
	if current and Now() - current.at <= SHOW_FOR then
		expiry = true
		C_Timer.After(SHOW_FOR + 1 - (Now() - current.at), Expire)
		return
	end
	UpdateButton()
	if pending and not ns.enabled then
		-- Switched off mid-fight: no combat-end event reaches a feature that is off, so look again
		-- until the button can be taken down.
		expiry = true
		C_Timer.After(5, Expire)
	end
end

-- -------------------------------------------------------------------- done with it

-- A unit token for the rare, if any (its nameplate, your target or mouseover), or nil.
function TokenFor(guid)
	if UnitTokenFromGUID then
		local t = Read(UnitTokenFromGUID, guid)
		if type(t) == "string" then
			return t
		end
	end
	for _, t in ipairs({ "target", "mouseover" }) do
		if Read(UnitGUID, t) == guid then
			return t
		end
	end
	return nil
end

-- This spawn needs no button any more: "killed", "dismissed" or "marked".
local function Finish(guid, why)
	if type(guid) ~= "string" then
		return
	end
	if guid ~= "" then -- "": the /kwr test entry
		done[guid] = why
	end
	if current and current.guid == guid then
		if why == "marked" then
			current.marked = true -- keep the key on it
		else
			current = nil
		end
		UpdateButton()
	end
end
ns.Finish = Finish -- test seam

-- Right-click: hides the button until this rare spawns again.
function ns.Dismiss()
	if current then
		Finish(current.guid, "dismissed")
	end
end

-- Looks for the current rare's corpse, or your marker on it.
local function Recheck()
	if not current or current.guid == "" then
		return
	end
	local t = TokenFor(current.guid)
	if not t then
		return
	end
	if Read(UnitIsDead, t) == true then
		Finish(current.guid, "killed")
	elseif not current.marked and Read(GetRaidTargetIndex, t) == Marker() then
		Finish(current.guid, "marked")
	end
end
ns.Recheck = Recheck -- test seam

-- -------------------------------------------------------------------- alerts

local function Alert(r)
	local db = ns.db
	if db.sound then
		pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959)
	end
	if db.screen and RaidNotice_AddMessage and RaidWarningFrame then
		pcall(RaidNotice_AddMessage, RaidWarningFrame, "Rare: " .. Describe(r), ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.82, b = 0 })
	end
	if db.chat then
		local key = BindingKey()
		local how = key and ("press " .. key .. " to target and mark it") or (db.button and "click the skull to target and mark it" or nil)
		local badge = root.UI.InlineAtlas(BADGE[r.elite and "rareelite" or "rare"], 14)
		ns:Print(badge .. " |cffffd100" .. Describe(r) .. "|r" .. (how and (" - " .. how) or ""))
		local worth = WorthLine(r.npcId)
		if worth then
			print("  |cff33ff99" .. worth .. "|r")
		end
	end
end

-- Looks at one unit and returns the rare on it (nil when none, or ignored). Alerts once per
-- spawn, and at most once every SEEN_TTL seconds for the same rare.
local function Check(unit)
	local r = Candidate(unit)
	if not r or ns.db.ignore[r.npcId] then
		return nil
	end
	local now = Now()
	ns.lastSeen = { name = r.name, at = now }
	if done[r.guid] == "dismissed" then
		return r -- you hid it: quiet until it spawns again
	end
	r.at = now
	r.marked = done[r.guid] == "marked"
	current = r
	UpdateButton()
	local last = lastAlert[r.npcId]
	if not alerted[r.guid] and (not last or now - last >= SEEN_TTL) then
		alerted[r.guid] = true
		lastAlert[r.npcId] = now
		Alert(r)
	end
	return r
end
ns.Check = Check -- test seam

-- -------------------------------------------------------------------- ignore list

function ns.Ignore(npcId, name)
	if not npcId then
		return false
	end
	ns.db.ignore[npcId] = name or ns.db.ignore[npcId] or ("creature " .. npcId)
	ns:Print("ignoring " .. ns.db.ignore[npcId] .. " (/kwr unignore " .. npcId .. " to undo)")
	UpdateButton()
	return true
end

function ns.Unignore(what)
	local id = tonumber(what)
	for npcId, name in pairs(ns.db.ignore) do
		if npcId == id or (type(what) == "string" and name:lower() == what:lower()) then
			ns.db.ignore[npcId] = nil
			ns:Print("no longer ignoring " .. name)
			return true
		end
	end
	ns:Print("not on the ignore list: " .. tostring(what) .. " (/kwr list)")
	return false
end

local function IgnoredCount()
	local n = 0
	for _ in pairs(ns.db.ignore) do
		n = n + 1
	end
	return n
end

-- -------------------------------------------------------------------- definition

ns.title = "Rare Alert"
ns.description = "Tells you when a rare enemy is near and gives you a button and a key that target it and put a raid marker on it. "
	.. "The game lets only a click or key press set a marker, so it never marks by itself."
ns.icon = MARKER_ICON .. "8"
ns.blurb = "Alert and one-key skull for rare enemies"
ns.options = {
	{ key = "sound", type = "toggle", label = "Play A Sound", tooltip = "The raid warning sound when a rare shows up.", default = true },
	{ key = "screen", type = "toggle", label = "Show A Screen Message", tooltip = "The rare's name in the middle of the screen, like a raid warning.", default = true },
	{ key = "chat", type = "toggle", label = "Chat Message", tooltip = "One line in chat with the rare's name and level.", default = true },
	{
		key = "button",
		type = "toggle",
		label = "Show The Mark Button",
		tooltip = "A marker button near the top of the screen while a rare is near. Click it to target the rare and mark it. It goes once the rare has your marker or dies, or a minute after you last saw it. Right-click hides it; shift-right-click ignores that rare; shift-drag moves it. The key in Key Bindings > AddOns > Krool World works either way.",
		default = true,
	},
	{
		key = "marker",
		type = "range",
		label = "Raid Marker",
		tooltip = "Which marker the button puts on the rare: 8 skull, 7 cross, 6 square, 5 moon, 4 triangle, 3 diamond, 2 circle, 1 star.",
		default = 8,
		min = 1,
		max = 8,
		step = 1,
	},
}
ns.slash = { "/kwr", "/rarealert" }

-- The hub card's extra button: only while enemy nameplates are off.
function ns.HubAction()
	if ns.EnemyPlatesOn() == false then
		return {
			label = "Plates On",
			tip = "Enemy nameplates are off, so Rare Alert only sees rares you mouse over or target. Turns them on and asks for the longest range. V turns them off again.",
			fn = ns.EnableNameplates,
		}
	end
	return nil
end

-- Buttons on the settings page (Core/Settings.lua).
ns.actions = {
	{
		label = "Turn On Enemy Nameplates",
		tooltip = "Rare Alert sees a rare as soon as its nameplate shows. Forever starts with enemy nameplates off and a 45 yard range: this turns them on and asks for the longest range. V turns them off again.",
		fn = function()
			ns.EnableNameplates()
		end,
	},
}

function ns.HubStatus()
	if ns.EnemyPlatesOn() == false then
		return "|cffff9955Enemy nameplates are off|r" -- the card's Plates On button says why
	end
	local parts = {}
	local last = ns.lastSeen
	if last then
		local mins = math.floor((Now() - last.at) / 60)
		parts[1] = "Last: " .. last.name .. (mins < 1 and ", just now" or (", " .. mins .. "m ago"))
	else
		parts[1] = "Watching for rares"
	end
	parts[#parts + 1] = IgnoredCount() .. " ignored"
	if not BindingKey() then
		parts[#parts + 1] = "no key bound"
	end
	return "|cffaaaaaa" .. table.concat(parts, "  ·  ") .. "|r"
end

local function Help()
	ns:Print("commands:")
	print("  /kwr ignore           ignore your target, or the last rare seen")
	print("  /kwr unignore <name or id>")
	print("  /kwr list             the ignore list")
	print("  /kwr test             show the button with a test entry (to place it and try your key)")
	print("  /kwr nameplates       turn enemy nameplates on (rares are seen as soon as theirs shows)")
	print("  bind the key in Key Bindings > AddOns > Krool World")
end

function ns.OnSlash(msg)
	msg = strtrim(msg or "")
	local cmd, arg = msg:match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()
	if cmd == "ignore" then
		local r = Candidate("target")
		if r then
			ns.Ignore(r.npcId, r.name)
		elseif current then
			ns.Ignore(current.npcId, current.name)
		else
			ns:Print("target a rare first (or wait for one to show up)")
		end
	elseif cmd == "unignore" and arg ~= "" then
		ns.Unignore(arg)
	elseif cmd == "list" then
		local names = {}
		for npcId, name in pairs(ns.db.ignore) do
			names[#names + 1] = name .. " (" .. npcId .. ")"
		end
		table.sort(names)
		ns:Print(#names == 0 and "ignoring no rares" or ("ignoring: " .. table.concat(names, ", ")))
	elseif cmd == "test" then
		if InCombat() then
			ns:Print("leave combat first")
			return
		end
		current = { npcId = 0, guid = "", name = "Rare Alert Test", level = nil, elite = false, at = Now() }
		UpdateButton()
		ns:Print("test button shown for a minute (it targets nothing real)")
	elseif cmd == "nameplates" or cmd == "plates" then
		ns.EnableNameplates()
	elseif cmd == "options" or cmd == "config" then
		root.OpenSettings(ns)
	else
		Help()
	end
end

-- -------------------------------------------------------------------- lifecycle

function ns.OnLoad()
	ns.db.ignore = ns.db.ignore or {}
	if not ns.db.seeded then
		ns.db.seeded = true
		for npcId, name in pairs(DEFAULT_IGNORE) do
			if ns.db.ignore[npcId] == nil then
				ns.db.ignore[npcId] = name
			end
		end
	end
end

-- Once per account: say why rares may go unnoticed.
function ns.OnEnable()
	if not ns.db.plateTip and ns.EnemyPlatesOn() == false then
		ns.db.plateTip = true
		ns:Print("enemy nameplates are off, so only rares you mouse over or target are noticed. "
			.. "/kwr nameplates (or the button on the /kw hub) turns them on.")
	end
	if pending then
		UpdateButton() -- switched off in a fight and on again: finish what combat held up
	end
end

function ns.OnDisable()
	current = nil
	wipe(plates) -- no REMOVED events while off: forget the tokens
	UpdateButton()
	if pending and not expiry then
		expiry = true
		C_Timer.After(5, Expire) -- combat locks the button: Expire takes it down afterwards
	end
end

function ns.OnOptionChanged()
	UpdateButton()
end

ns:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
	if type(unit) == "string" and not Secret(unit) then
		local r = Check(unit)
		plates[unit] = r and r.guid or nil
	end
end)
-- The token still reads during this event. A dead unit's plate goes away; so does one out of range.
ns:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function(_, unit)
	if type(unit) ~= "string" or Secret(unit) then
		return
	end
	local guid = plates[unit]
	plates[unit] = nil
	if guid and Read(UnitIsDead, unit) == true then
		Finish(guid, "killed")
	end
end)
ns:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function()
	if not Check("mouseover") then
		Recheck() -- its corpse?
	end
end)
ns:RegisterEvent("PLAYER_TARGET_CHANGED", function()
	if not Check("target") then
		Recheck()
	end
end)
ns:RegisterEvent("RAID_TARGET_UPDATE", function()
	Recheck() -- your marker on it?
end)
ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	Recheck() -- killed in the fight: usually still your target
	if pending then
		UpdateButton()
	end
end)
