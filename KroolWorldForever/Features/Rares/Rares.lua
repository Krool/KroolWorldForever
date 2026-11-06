-- Rare Alert: tells you when a rare enemy is near (its nameplate shows, you mouse over it, or you
-- target it) and offers one button and one key that target it and put a raid marker on it.
--
-- Forever, like Midnight 12.0, makes SetRaidTarget protected: addon code cannot mark anything. The
-- button is a SecureActionButton whose macro runs /targetexact and /tm, so the mark always comes
-- from your own click or key press. Secure frames lock in combat: a rare found in combat gets the
-- alert, and the button catches up when combat ends. Inside instances unit data is secret, so
-- nothing is checked there.

local _, root = ...
local ns = root.Feature("rares")

local BUTTON = "KroolWorldForeverRareButton"
local BINDING = "CLICK " .. BUTTON .. ":LeftButton"
local SEEN_TTL = 300 -- seconds before the same rare alerts again
local SHOW_FOR = 120 -- seconds the button stays up after the last sighting
local MARKER_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
-- Always up, never worth a stop: ignored until you unignore them.
local DEFAULT_IGNORE = { [3581] = "Sewer Beast" } -- the crocolisk in the Stormwind canals

-- Key Bindings > AddOns (Bindings.xml)
BINDING_HEADER_KROOLWORLDFOREVER = "Krool World"
_G["BINDING_NAME_" .. BINDING] = "Target And Mark Rare"

local current -- the newest sighting: { npcId, guid, name, level, elite, at }
local seen = {} -- npcId -> last sighting time
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
	b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
	b.hint = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.hint:SetPoint("TOP", b.label, "BOTTOM", 0, -1)
	b:HookScript("OnClick", function(_, which, down)
		if which == "RightButton" and not down and current and current.npcId > 0 then -- 0: the /kwr test entry
			pcall(ns.Ignore, current.npcId, current.name)
		end
	end)
	b:SetScript("OnEnter", function(self)
		if not (GameTooltip and current) then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(Describe(current), 1, 0.82, 0)
		local key = BindingKey()
		GameTooltip:AddLine("Click" .. (key and (" or press " .. key) or "") .. ": target it and mark it.", 1, 1, 1, true)
		if not key then
			GameTooltip:AddLine("Bind a key: Key Bindings > AddOns > Krool World.", 0.7, 0.7, 0.7, true)
		end
		GameTooltip:AddLine("Right-click: ignore this rare.  Shift-drag: move.", 0.7, 0.7, 0.7, true)
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

local Expire -- forward

-- Points the button (and the key) at the newest rare, or clears it. Waits out combat.
local function UpdateButton()
	if InCombat() then
		pending = true
		return
	end
	pending = false
	if current and (Now() - current.at > SHOW_FOR or ns.db.ignore[current.npcId]) then
		current = nil
	end
	if not current and not button then
		return
	end
	local b = Build()
	if not b then
		pending = true
		return
	end
	if not current or not ns.enabled then
		b:SetAttribute("macrotext1", "")
		b:Hide()
		return
	end
	b:SetAttribute("macrotext1", ns.Macro(current.name))
	b.icon:SetTexture(MARKER_ICON .. Marker())
	b.glow:SetTexture(MARKER_ICON .. Marker())
	b.label:SetText(current.name)
	local key = BindingKey()
	b.hint:SetText(key and ("Click or " .. key) or "Click to mark")
	b:SetShown(ns.db.button and true or false)
	if not expiry then
		expiry = true
		C_Timer.After(SHOW_FOR + 1, Expire)
	end
end
ns.UpdateButton = UpdateButton

function Expire()
	expiry = false
	if current and Now() - current.at <= SHOW_FOR then
		expiry = true
		C_Timer.After(SHOW_FOR + 1 - (Now() - current.at), Expire)
		return
	end
	UpdateButton()
end

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
		ns:Print("|cffffd100" .. Describe(r) .. "|r" .. (how and (" - " .. how) or ""))
	end
end

-- Looks at one unit; alerts at most once per rare every SEEN_TTL seconds.
local function Check(unit)
	local r = Candidate(unit)
	if not r or ns.db.ignore[r.npcId] then
		return
	end
	local now = Now()
	local last = seen[r.npcId]
	seen[r.npcId] = now
	r.at = now
	current = r
	ns.lastSeen = { name = r.name, at = now }
	UpdateButton()
	if not last or now - last >= SEEN_TTL then
		Alert(r)
	end
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
		tooltip = "A marker button near the top of the screen while a rare is near. Click it to target the rare and mark it; right-click ignores that rare; shift-drag moves it. The key in Key Bindings > AddOns > Krool World works either way.",
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

function ns.HubStatus()
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
		current = { npcId = 0, guid = "", name = "Rare Alert Test", level = nil, elite = false, at = Now() }
		UpdateButton()
		ns:Print(InCombat() and "leave combat first" or "test button shown for two minutes (it targets nothing real)")
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

function ns.OnDisable()
	current = nil
	UpdateButton()
end

function ns.OnOptionChanged()
	UpdateButton()
end

ns:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
	if type(unit) == "string" and not Secret(unit) then
		Check(unit)
	end
end)
ns:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function()
	Check("mouseover")
end)
ns:RegisterEvent("PLAYER_TARGET_CHANGED", function()
	Check("target")
end)
ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	if pending then
		UpdateButton()
	end
end)
