-- Sayge's Fortune: when Sayge at the Darkmoon Faire gives you your next fortune.
--
-- A fortune lasts 2 hours and is gone when you die. The same cast puts Sayge's Carnie Buff (23770)
-- on you: a hidden 4-hour debuff that stays through death, his wait before the next fortune
-- (docs/08-darkmoon-faire.md). Addons cannot see hidden auras (the owner checked in game,
-- 2026-11-09), so this notes when the visible fortune began, per character and on the real clock,
-- and counts the 4 hours from there. What Sayge says when you talk to him is recorded too, to
-- check the 4 hours against real visits.

local _, root = ...
local ns = root.Feature("fortune")

ns.SAYGE = 14822 -- Sayge's npc id
ns.BUFF = 2 * 3600 -- a fortune lasts 2 hours
ns.WAIT = 4 * 3600 -- Sayge's Carnie Buff: the wait from one fortune to the next
ns.KEEP = 8 * 24 * 3600 -- other characters' fortunes are listed for about one faire
ns.VISITS_MAX = 50

-- The eight fortunes, and Forever's own copies of them (1304767-1304782, purpose unknown).
ns.FORTUNES = {
	[23735] = "Strength",
	[23736] = "Agility",
	[23737] = "Stamina",
	[23738] = "Spirit",
	[23766] = "Intelligence",
	[23767] = "Armor",
	[23768] = "Damage",
	[23769] = "Resistance",
	[1304782] = "Strength",
	[1304780] = "Agility",
	[1304778] = "Stamina",
	[1304775] = "Spirit",
	[1304772] = "Intelligence",
	[1304771] = "Armor",
	[1304769] = "Damage",
	[1304767] = "Resistance",
}

local LABEL = "|cffb48cffSayge:|r "
local GREY, ORANGE, GREEN = "|cffaaaaaa", "|cffff9955", "|cff33ff99"

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- v when it is a readable value of that type, else nil.
local function Plain(v, kind)
	if Secret(v) or type(v) ~= kind then
		return nil
	end
	return v
end

-- Seconds on the real clock (it keeps counting while you are logged out), or nil.
local function Now()
	if type(time) ~= "function" then
		return nil
	end
	local ok, t = pcall(time)
	return ok and Plain(t, "number") or nil
end

local function InInstance()
	local ok, inside = pcall(IsInInstance)
	return not ok or Secret(inside) or inside == true
end

local function CharKey()
	local okN, name = pcall(UnitName, "player")
	local okR, realm = pcall(GetRealmName)
	name = okN and Plain(name, "string") or nil
	realm = okR and Plain(realm, "string") or nil
	if not name or name == "" then
		return nil
	end
	return realm and realm ~= "" and (name .. "-" .. realm) or name
end

local function Chars()
	if type(ns.db.chars) ~= "table" then
		ns.db.chars = {}
	end
	return ns.db.chars
end

-- This character's record ({ got, spell, kind, lost, offered, refused }) and key.
function ns.Mine()
	local key = CharKey()
	return key and Chars()[key] or nil, key
end

local function Refresh()
	if root.RefreshHub then
		pcall(root.RefreshHub)
	end
end

-- -------------------------------------------------------------------- text

-- "1h 52m", "12m", "under a minute".
function ns.Duration(s)
	s = math.max(0, math.floor(s + 0.5))
	local h, m = math.floor(s / 3600), math.floor((s % 3600) / 60)
	if h > 0 then
		return ("%dh %dm"):format(h, m)
	elseif m > 0 then
		return ("%dm"):format(m)
	end
	return "under a minute"
end

-- "3:40 PM" (or "15:40" with the 24-hour clock option), or nil.
function ns.Clock(t)
	if type(date) ~= "function" or type(t) ~= "number" then
		return nil
	end
	local ok24, mil = pcall(GetCVarBool, "timeMgrUseMilitaryTime")
	local ok, s = pcall(date, (ok24 and mil) and "%H:%M" or "%I:%M %p", t)
	if not ok or type(s) ~= "string" then
		return nil
	end
	return (s:gsub("^0", ""))
end

-- "at 3:40 PM (in 1h 52m)", or "now".
function ns.When(t, now)
	if t <= now then
		return "now"
	end
	local c = ns.Clock(t)
	return c and ("at %s (in %s)"):format(c, ns.Duration(t - now)) or ("in " .. ns.Duration(t - now))
end

-- -------------------------------------------------------------------- the fortune on you

-- The fortune on you now: its spell id and aura, or nil.
function ns.Current()
	local fn = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	if not fn then
		return nil
	end
	for id in pairs(ns.FORTUNES) do
		local ok, aura = pcall(fn, id)
		aura = ok and Plain(aura, "table") or nil
		if aura then
			return id, aura
		end
	end
	return nil
end

-- When a fortune began on the real clock: its end minus its length, moved from GetTime().
local function Began(aura, now)
	local ends, length = Plain(aura.expirationTime, "number"), Plain(aura.duration, "number")
	local okG, gt = pcall(GetTime)
	gt = okG and Plain(gt, "number") or nil
	if not (ends and length and gt and now) or ends <= 0 or length <= 0 then
		return nil
	end
	return math.floor(now - (gt - (ends - length)) + 0.5)
end

local seenInstance -- the aura instance of the fortune seen on you this session
local remindFor -- the fortune a ready reminder is set for

-- Says in chat when the wait is over, if you are still logged in then.
function ns.Schedule()
	local rec, now = ns.Mine(), Now()
	if not (rec and now and ns.db.ready and C_Timer and C_Timer.After) then
		return
	end
	local left = rec.got + ns.WAIT - now
	if left <= 0 or remindFor == rec.got then
		return
	end
	remindFor = rec.got
	local got = rec.got
	C_Timer.After(left + 1, function()
		local r = ns.Mine()
		if ns.enabled and ns.db.ready and r and r.got == got then
			ns:Print("Sayge's wait is over: he can give you a new fortune while the faire is in town.")
			Refresh()
		end
	end)
end

-- The fortune went before its 2 hours were up: you died (or cancelled it).
local function Lost()
	seenInstance = nil
	local rec, now = ns.Mine(), Now()
	if not (rec and now) or rec.lost or now >= rec.got + ns.BUFF - 60 then
		return
	end
	rec.lost = now
	if ns.db.warn then
		ns:Print(("You lost your fortune. Sayge's wait still runs: the next one %s."):format(ns.When(rec.got + ns.WAIT, now)))
	end
	Refresh()
end

-- Notes the fortune on you (a new one replaces the record), or notices it is gone.
function ns.Scan()
	local id, aura = ns.Current()
	if not id then
		if seenInstance and not InInstance() then
			Lost()
		end
		return
	end
	seenInstance = Plain(aura.auraInstanceID, "number") or seenInstance or true
	local now = Now()
	local began = Began(aura, now)
	local _, key = ns.Mine()
	if not (began and key) then
		return
	end
	local rec = Chars()[key]
	if rec and math.abs((rec.got or 0) - began) < 120 then
		return -- the same fortune
	end
	Chars()[key] = { got = began, spell = id, kind = ns.FORTUNES[id] }
	ns.Schedule()
	Refresh()
end

local function OnAura(_, unit, info)
	if unit ~= "player" then
		return
	end
	if type(info) ~= "table" or info.isFullUpdate then
		ns.Scan()
		return
	end
	local added = Plain(info.addedAuras, "table")
	for _, a in ipairs(added or {}) do
		local sid = type(a) == "table" and a.spellId
		if Secret(sid) or (type(sid) == "number" and ns.FORTUNES[sid]) then
			ns.Scan()
			break
		end
	end
	local removed = type(seenInstance) == "number" and Plain(info.removedAuraInstanceIDs, "table")
	for _, rid in ipairs(removed or {}) do
		if not Secret(rid) and rid == seenInstance then
			Lost()
			break
		end
	end
end

-- -------------------------------------------------------------------- state

-- What a character can expect, and when the next fortune comes:
--   "active"  a fortune on you      "waiting" Sayge's wait runs      "ready" the wait is over
--   "refused" the wait should be over, but Sayge turned you away after it
-- have: whether the fortune is on you (nil: go by the clock, for other characters).
function ns.State(rec, now, have)
	if not (rec and now and rec.got) then
		return nil
	end
	local nextAt = rec.got + ns.WAIT
	if have == true or (have == nil and not rec.lost and now < rec.got + ns.BUFF) then
		return "active", nextAt
	end
	if rec.offered and rec.offered > rec.got + ns.BUFF then
		return "ready", nextAt -- Sayge offered one: he knows best
	end
	if now < nextAt then
		return "waiting", nextAt
	end
	if rec.refused and rec.refused >= nextAt then
		return "refused", nextAt
	end
	return "ready", nextAt
end

-- One line: what this character has and when the next fortune comes.
function ns.StatusText(rec, now, have)
	local state, nextAt = ns.State(rec, now, have)
	if not state then
		return GREY .. "No fortune seen on this character yet|r"
	elseif state == "active" then
		return GREEN .. ("Fortune of %s, %s left|r"):format(rec.kind or "?", ns.Duration(rec.got + ns.BUFF - now))
	elseif state == "waiting" then
		return ORANGE .. "Next fortune " .. ns.When(nextAt, now) .. "|r"
	elseif state == "refused" then
		local c = ns.Clock(rec.refused)
		return ORANGE .. "Sayge turned you away" .. (c and (" at " .. c) or "") .. ": try again later|r"
	end
	return GREEN .. "Ready for a new fortune|r"
end

local function MyStatus()
	local rec, now = ns.Mine(), Now()
	return ns.StatusText(rec, now, ns.Current() ~= nil), rec, now
end

-- -------------------------------------------------------------------- Sayge's answers

local function NpcId(unit)
	local ok, guid = pcall(UnitGUID, unit)
	guid = ok and Plain(guid, "string") or nil
	local kind, id = (guid or ""):match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
	return kind == "Creature" and tonumber(id) or nil
end

-- Sayge's window: his fortune option (offered), no options at all (turned away), or neither.
local function OnGossip()
	if NpcId("npc") ~= ns.SAYGE or not C_GossipInfo then
		return
	end
	local okO, options = pcall(C_GossipInfo.GetOptions)
	options = okO and Plain(options, "table") or {}
	local offered = false
	for _, o in ipairs(options) do
		local name = type(o) == "table" and Plain(o.name, "string")
		if name and name:lower():find("fortune", 1, true) then
			offered = true
		end
	end
	local verdict = offered and "offered" or (#options == 0 and "refused" or "unknown")
	local okT, text = pcall(C_GossipInfo.GetText)
	text = okT and Plain(text, "string") or nil
	local rec, now = ns.Mine(), Now()
	if type(ns.db.visits) ~= "table" then
		ns.db.visits = {}
	end
	local visits = ns.db.visits
	visits[#visits + 1] = {
		t = now,
		got = rec and rec.got,
		have = ns.Current() ~= nil,
		n = #options,
		verdict = verdict,
		text = text and text:sub(1, 160),
	}
	while #visits > ns.VISITS_MAX do
		table.remove(visits, 1)
	end
	if rec and now and verdict ~= "unknown" then
		rec[verdict] = now
	end
	Refresh()
end
ns.OnGossip = OnGossip -- test seam

-- -------------------------------------------------------------------- tooltips

local function AddSaygeLines(tooltip, data)
	local guid = Plain(data.guid, "string") or ""
	local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
	if kind ~= "Creature" or tonumber(id) ~= ns.SAYGE then
		return
	end
	local text, rec, now = MyStatus()
	tooltip:AddLine(LABEL .. text)
	local state, nextAt = ns.State(rec, now, ns.Current() ~= nil)
	if state == "active" then
		tooltip:AddLine(GREY .. "The next one " .. ns.When(nextAt, now) .. ", even if you die.|r", nil, nil, nil, true)
	elseif state == "waiting" then
		tooltip:AddLine(GREY .. "His wait is 4 hours from your last fortune; dying does not end it.|r", nil, nil, nil, true)
	end
end

local function AddFortuneLines(tooltip, data)
	local id = Plain(data.id, "number")
	if not (id and ns.FORTUNES[id]) then
		return
	end
	ns.Scan()
	local rec, now = ns.Mine(), Now()
	if rec and now then
		tooltip:AddLine(LABEL .. GREY .. "your next fortune " .. ns.When(rec.got + ns.WAIT, now) .. ", even if you die.|r", nil, nil, nil, true)
	end
end

-- Both run on every tooltip of their kind; any failure must degrade to no line.
local function OnUnitTooltip(tooltip, data)
	if tooltip ~= GameTooltip or not (ns.enabled and ns.db and ns.db.tooltip) or type(data) ~= "table" then
		return
	end
	pcall(AddSaygeLines, tooltip, data)
end
ns.OnUnitTooltip = OnUnitTooltip -- test seam

local function OnAuraTooltip(tooltip, data)
	if tooltip ~= GameTooltip or not (ns.enabled and ns.db and ns.db.tooltip) or type(data) ~= "table" then
		return
	end
	pcall(AddFortuneLines, tooltip, data)
end
ns.OnAuraTooltip = OnAuraTooltip -- test seam

-- -------------------------------------------------------------------- definition

ns.title = "Sayge's Fortune"
ns.description = "When Sayge at the Darkmoon Faire can give you your next fortune. His wait is 4 hours from your last "
	.. "fortune and dying does not end it, though the fortune itself is lost. The game hides that wait, so this notes when "
	.. "you got each fortune, on every character."
ns.icon = 134334 -- the fortunes' own icon (SpellMisc, build 1.60.1.70862)
ns.blurb = "When Sayge gives your next fortune"
ns.options = {
	{
		key = "tooltip",
		type = "toggle",
		label = "Show On Sayge And Your Fortune",
		tooltip = "Adds when you can get your next fortune to Sayge's tooltip and to the fortune buff's tooltip.",
		default = true,
	},
	{
		key = "warn",
		type = "toggle",
		label = "Tell Me If I Lose It",
		tooltip = "When your fortune goes early (you died), says in chat when Sayge gives the next one.",
		default = true,
	},
	{
		key = "ready",
		type = "toggle",
		label = "Tell Me When The Wait Is Over",
		tooltip = "Says in chat when Sayge's 4-hour wait ends, if you are logged in.",
		default = true,
	},
}
ns.slash = { "/sayge", "/kwsayge" }

local function PrintStatus()
	local text, rec, now = MyStatus()
	ns:Print(text)
	if rec and now then
		local state, nextAt = ns.State(rec, now, ns.Current() ~= nil)
		if state == "active" then
			print("  " .. GREY .. "The next one " .. ns.When(nextAt, now) .. ", even if you die.|r")
		end
		local c = ns.Clock(rec.got)
		print("  " .. GREY .. "Last fortune: " .. (rec.kind or "?") .. (c and (", " .. c) or "") .. (rec.lost and ", lost early" or "") .. ".|r")
	end
	print("  " .. GREY .. "Sayge's wait is 4 hours from a fortune, and dying does not end it (from the game's data; unconfirmed on Forever).|r")
	local _, myKey = ns.Mine()
	local others = {}
	for key, r in pairs(Chars()) do
		if key ~= myKey and type(r) == "table" and r.got and now and now - r.got < ns.KEEP then
			others[#others + 1] = { key = key, rec = r }
		end
	end
	table.sort(others, function(a, b)
		return a.rec.got < b.rec.got
	end)
	if #others > 0 then
		print("  Other characters:")
		for _, o in ipairs(others) do
			print("    " .. o.key .. ": " .. ns.StatusText(o.rec, now, nil))
		end
	end
	local visits = type(ns.db.visits) == "table" and ns.db.visits or {}
	if #visits > 0 then
		local offered, refused = 0, 0
		for _, v in ipairs(visits) do
			offered = offered + (v.verdict == "offered" and 1 or 0)
			refused = refused + (v.verdict == "refused" and 1 or 0)
		end
		print(("  %sTalks with Sayge recorded: %d (%d offered a fortune, %d turned you away).|r"):format(GREY, #visits, offered, refused))
	end
end

function ns.OnSlash(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "options" or msg == "config" then
		root.OpenSettings(ns)
	elseif msg == "help" then
		ns:Print("/sayge - when Sayge gives your next fortune, on this and your other characters; /sayge options.")
	else
		PrintStatus()
	end
end

function ns.HubStatus()
	return (MyStatus())
end

ns:RegisterEvent("UNIT_AURA", OnAura)
ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	ns.Scan()
	ns.Schedule()
end)
ns:RegisterEvent("PLAYER_DEAD", function()
	ns.Scan()
end)
ns:RegisterEvent("GOSSIP_SHOW", function()
	OnGossip()
end)

-- Tooltip hooks cannot be removed, so they are added once and check ns.enabled each time.
function ns.OnEnable()
	local kinds = TooltipDataProcessor and Enum and Enum.TooltipDataType
	if not ns.hooked and kinds and kinds.Unit and kinds.UnitAura then
		ns.hooked = true
		TooltipDataProcessor.AddTooltipPostCall(kinds.Unit, OnUnitTooltip)
		TooltipDataProcessor.AddTooltipPostCall(kinds.UnitAura, OnAuraTooltip)
	end
	ns.Scan()
	ns.Schedule()
end
