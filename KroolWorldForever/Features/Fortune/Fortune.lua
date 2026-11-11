-- Sayge's Fortune: when Sayge at the Darkmoon Faire gives you your next fortune.
--
-- A fortune lasts 2 hours and is gone when you die. The same cast puts Sayge's Carnie Buff (23770)
-- on you: a hidden 4-hour debuff that stays through death, his wait before the next fortune
-- (docs/08-darkmoon-faire.md). Addons cannot see hidden auras (the owner checked in game,
-- 2026-11-09), so this counts the 4 hours itself, per character.
--
-- Both timers stop while you are logged out (the owner's visits on 2026-11-10: a fortune taken at
-- 1:35 AM was still running after a night logged out, and Sayge refused at 1:51 PM, 12 hours later
-- but about 3h 20m of play in). So the wait is kept as time left (`left`, as of `at` on the
-- real clock) and runs down only while that character is logged in. While the fortune is on you,
-- its own time left sets the wait exactly: wait left = 4 hours minus the fortune's time used.
-- What Sayge says when you talk to him is recorded too, with the count, to check it.

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

-- Seconds on the real clock (it keeps counting while you are logged out; Sayge's wait does not),
-- or nil.
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

-- This character's record and key. A record: got (when the fortune was given, real clock), spell,
-- kind, left and at (Sayge's wait left, as of at), lost, offered, refused (when Sayge said so),
-- turnedAway (he refused after the count ran out: the count is off).
function ns.Mine()
	local key = CharKey()
	return key and Chars()[key] or nil, key
end

-- Seconds of Sayge's wait left. live: the record is the logged-in character's, whose wait runs
-- down; any other character's stands still until it logs in.
function ns.Left(rec, now, live)
	local left = rec and Plain(rec.left, "number")
	if not left then
		return nil
	end
	if live and now and type(rec.at) == "number" then
		left = left - (now - rec.at)
	end
	return math.max(0, left)
end

-- A fortune's own time left, from the wait left (both began with the same cast).
local function FortuneLeft(left)
	return left - (ns.WAIT - ns.BUFF)
end

-- A new session on this character: the time logged out does not count, so the wait goes on from
-- where the last session left it, counting from the login (OnLoad notes it), even when the
-- feature is turned on later. start: the login time (the tests log in again with it).
local sessionStart
function ns.Resume(start)
	sessionStart = start or sessionStart or Now()
	local rec = ns.Mine()
	if rec and rec.left and sessionStart and (type(rec.at) ~= "number" or rec.at < sessionStart) then
		rec.at = sessionStart
	end
	ns.remindFor = nil -- the last session's reminder died with it
end

-- Logging out (or reloading): keep what is left. Runs whether the feature is on or off, so time
-- played with it off still counts.
local function Save()
	local rec, now = ns.Mine(), Now()
	local left = ns.Left(rec, now, true)
	if left then
		rec.left, rec.at = left, now
	end
end

-- Records from before 0.16.1 kept only `got` and counted the real clock. The wait they had is the
-- best guess left (`guess`: the fortune still on you corrects it); a refusal after it means Sayge
-- disagreed, unless he offered later.
local function Migrate()
	local now = Now()
	if not now then
		return
	end
	for _, rec in pairs(Chars()) do
		if type(rec) == "table" and type(rec.got) == "number" and rec.left == nil then
			rec.left, rec.at, rec.guess = math.max(0, rec.got + ns.WAIT - now), now, true
			local refused, offered = Plain(rec.refused, "number"), Plain(rec.offered, "number")
			if offered and offered > rec.got + ns.BUFF and (not refused or offered >= refused) then
				rec.left = 0 -- the old code's "ready": he offered after the fortune ended
			elseif refused and refused >= rec.got + ns.WAIT then
				rec.turnedAway = refused
			end
		end
	end
end
ns.Migrate = Migrate -- test seam

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

-- Sayge's wait: "after 1h 52m more online (3:40 PM if you stay on)", "after 1h 52m more online"
-- for a character that is not logged in, or "now".
function ns.Wait(left, now, live)
	if not left or left <= 0 then
		return "now"
	end
	local text = "after " .. ns.Duration(left) .. " more online"
	local c = live and now and ns.Clock(now + left)
	return c and (text .. " (" .. c .. " if you stay on)") or text
end

-- -------------------------------------------------------------------- the fortune on you

-- The fortune on you now: its spell id and aura, or nil (also while auras are hidden).
function ns.Current()
	local fn = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	if not fn or root.AurasSecret() then
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

-- Sayge's wait left, from the fortune on you: 4 hours minus the fortune's time used. Both timers
-- stop while you are logged out, so this holds after any time away.
local function WaitFromAura(aura)
	local ends, length = Plain(aura.expirationTime, "number"), Plain(aura.duration, "number")
	local okG, gt = pcall(GetTime)
	gt = okG and Plain(gt, "number") or nil
	if not (ends and length and gt) or ends <= 0 or length <= 0 then
		return nil
	end
	return math.max(0, ns.WAIT - (length - (ends - gt)))
end

local seenInstance -- the aura instance of the fortune seen on you this session

-- Says in chat when the wait is over, if you are still logged in then. Timers count real time,
-- which is time online while they run; a timer that fires early (the count moved) sets another.
function ns.Schedule()
	local rec, now = ns.Mine(), Now()
	if not (rec and now and ns.db.ready and C_Timer and C_Timer.After) then
		return
	end
	local left = ns.Left(rec, now, true)
	if not left or left <= 0 or ns.remindFor == rec.got then
		return
	end
	ns.remindFor = rec.got
	local got = rec.got
	C_Timer.After(left + 1, function()
		local r = ns.Mine()
		if not (ns.enabled and ns.db.ready and r and r.got == got) then
			return
		end
		if (ns.Left(r, Now(), true) or 0) > 30 then
			ns.remindFor = nil
			ns.Schedule()
			return
		end
		ns:Print("Sayge's wait is over: he can give you a new fortune while the faire is in town.")
		Refresh()
	end)
end

-- The fortune went before its 2 hours were up: you died (or cancelled it).
local function Lost()
	seenInstance = nil
	local rec, now = ns.Mine(), Now()
	local left = ns.Left(rec, now, true)
	if not (left and now) or rec.lost or FortuneLeft(left) <= 60 then
		return -- ran out: its 2 hours are used
	end
	rec.lost = now
	if ns.db.warn then
		ns:Print(("You lost your fortune. Sayge's wait still runs: the next one %s."):format(ns.Wait(left, now, true)))
	end
	Refresh()
end

-- Whether the fortune is on you: true, false, or nil while auras are hidden (go by the clock).
local function Have()
	if root.AurasSecret() then
		return nil
	end
	return ns.Current() ~= nil
end

-- Notes the fortune on you, or notices it is gone. A fortune with more time left than the count
-- allows is a new one and replaces the record; otherwise its time left sets the count. Does nothing
-- while auras are hidden (instances): a hidden fortune is not a lost one.
function ns.Scan()
	if root.AurasSecret() then
		return
	end
	local id, aura = ns.Current()
	if not id then
		if seenInstance and not InInstance() then
			Lost()
		end
		return
	end
	seenInstance = Plain(aura.auraInstanceID, "number") or seenInstance or true
	local now = Now()
	local began, waitLeft = Began(aura, now), WaitFromAura(aura)
	local _, key = ns.Mine()
	if not (began and waitLeft and key) then
		return
	end
	local rec = Chars()[key]
	local left = ns.Left(rec, now, true)
	if left and (waitLeft <= left + 120 or (rec.guess and rec.spell == id)) then
		rec.left, rec.at, rec.guess = waitLeft, now, nil -- the same fortune (it corrects a guess)
		return
	end
	-- First seen well into its time (after a logout, or the feature newly on): when it was given
	-- is unknown, since its time stood still while logged out. "late": got is when it was seen.
	local used = ns.BUFF - FortuneLeft(waitLeft)
	local late = used > 120 or nil
	Chars()[key] = { got = late and now or began, late = late, spell = id, kind = ns.FORTUNES[id], left = waitLeft, at = now }
	ns.Schedule()
	Refresh()
end

-- UNIT_AURA's fields can be secret (inside instances on Forever): every one is checked before it
-- is tested or compared, and nothing is read at all while auras are hidden.
local function OnAura(_, unit, info)
	if Secret(unit) or unit ~= "player" or root.AurasSecret() then
		return
	end
	if type(info) ~= "table" then
		ns.Scan()
		return
	end
	local full = info.isFullUpdate
	if Secret(full) or full == true then
		ns.Scan()
		return
	end
	local added = Plain(info.addedAuras, "table")
	for _, a in ipairs(added or {}) do
		local sid = type(a) == "table" and a.spellId -- no "or": that would test a secret
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

-- What a character can expect, and the wait left:
--   "active"  a fortune on you      "waiting" Sayge's wait runs      "ready" the wait is over
--   "refused" the count ran out, but Sayge turned you away after it
-- have: whether the fortune is on you (nil: go by the count, for other characters and while
-- auras are hidden). live: the logged-in character's record (its wait is running).
function ns.State(rec, now, have, live)
	local left = ns.Left(rec, now, live)
	if not (left and now) then
		return nil
	end
	local fortuneLeft = FortuneLeft(left)
	if have == true or (have == nil and not rec.lost and fortuneLeft > 0) then
		return "active", left
	end
	if left > 0 then
		return "waiting", left
	end
	if rec.turnedAway then
		return "refused", left
	end
	return "ready", left
end

-- One line: what this character has and when the next fortune comes.
function ns.StatusText(rec, now, have, live)
	local state, left = ns.State(rec, now, have, live)
	if not state then
		return GREY .. "No fortune seen on this character yet|r"
	elseif state == "active" then
		return GREEN .. ("Fortune of %s, %s left|r"):format(rec.kind or "?", ns.Duration(FortuneLeft(left)))
	elseif state == "waiting" then
		return ORANGE .. "Next fortune " .. ns.Wait(left, now, live) .. "|r"
	elseif state == "refused" then
		local c = ns.Clock(rec.turnedAway)
		return ORANGE .. "Sayge turned you away" .. (c and (" at " .. c) or "") .. ": try again later|r"
	end
	return GREEN .. "Ready for a new fortune|r"
end

local function MyStatus()
	local rec, now = ns.Mine(), Now()
	return ns.StatusText(rec, now, Have(), true), rec, now
end

-- -------------------------------------------------------------------- Sayge's answers

local function NpcId(unit)
	local ok, guid = pcall(UnitGUID, unit)
	guid = ok and Plain(guid, "string") or nil
	local kind, id = (guid or ""):match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
	return kind == "Creature" and tonumber(id) or nil
end

-- Sayge's window: his fortune option (offered), no options at all (turned away), or neither. No
-- options with the fortune on you is his "here is your fortune" page, not a refusal. Offered: the
-- wait is over whatever the count says. Turned away after the count ran out: the count is off.
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
	local have = Have()
	local verdict = offered and "offered" or (#options == 0 and have ~= true and "refused" or "unknown")
	local okT, text = pcall(C_GossipInfo.GetText)
	text = okT and Plain(text, "string") or nil
	local rec, now = ns.Mine(), Now()
	local left = ns.Left(rec, now, true)
	if type(ns.db.visits) ~= "table" then
		ns.db.visits = {}
	end
	local visits = ns.db.visits
	visits[#visits + 1] = {
		t = now,
		got = rec and rec.got,
		left = left, -- the count then, to check it against his answer
		have = have,
		n = #options,
		verdict = verdict,
		text = text and text:sub(1, 160),
	}
	while #visits > ns.VISITS_MAX do
		table.remove(visits, 1)
	end
	if rec and now and verdict ~= "unknown" then
		rec[verdict] = now
		if verdict == "offered" and have ~= true then
			rec.left, rec.at, rec.turnedAway = 0, now, nil -- he knows best
		elseif verdict == "refused" and left and left <= 0 then
			rec.turnedAway = now
		end
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
	local state, left = ns.State(rec, now, Have(), true)
	if state == "active" then
		tooltip:AddLine(GREY .. "The next one " .. ns.Wait(left, now, true) .. ", even if you die.|r", nil, nil, nil, true)
	elseif state == "waiting" then
		tooltip:AddLine(GREY .. "His wait is 4 hours online from your last fortune: time logged out does not count, and dying does not end it.|r", nil, nil, nil, true)
	end
end

local function AddFortuneLines(tooltip, data)
	local id = Plain(data.id, "number")
	if not (id and ns.FORTUNES[id]) then
		return
	end
	ns.Scan()
	local rec, now = ns.Mine(), Now()
	local left = ns.Left(rec, now, true)
	if left and now then
		tooltip:AddLine(LABEL .. GREY .. "your next fortune " .. ns.Wait(left, now, true) .. ", even if you die.|r", nil, nil, nil, true)
	end
end

-- Both run on every tooltip of their kind; any failure must degrade to no line.
local function OnUnitTooltip(tooltip, data)
	if tooltip ~= GameTooltip or not (ns.enabled and ns.db and ns.db.tooltip) or type(data) ~= "table" then
		return
	end
	root.TryQuiet(ns, "Sayge tooltip", AddSaygeLines, tooltip, data)
end
ns.OnUnitTooltip = OnUnitTooltip -- test seam

local function OnAuraTooltip(tooltip, data)
	if tooltip ~= GameTooltip or not (ns.enabled and ns.db and ns.db.tooltip) or type(data) ~= "table" then
		return
	end
	root.TryQuiet(ns, "buff tooltip", AddFortuneLines, tooltip, data)
end
ns.OnAuraTooltip = OnAuraTooltip -- test seam

-- -------------------------------------------------------------------- definition

ns.title = "Sayge's Fortune"
ns.description = "When Sayge at the Darkmoon Faire can give you your next fortune. His wait is 4 hours from your last "
	.. "fortune, counted only while that character is logged in, and dying does not end it, though the fortune itself is "
	.. "lost. The game hides that wait, so this counts it, on every character."
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
		tooltip = "Says in chat when Sayge's 4-hour wait ends while you are logged in.",
		default = true,
	},
}
ns.slash = { "/sayge", "/kwsayge" }

local function PrintStatus()
	local text, rec, now = MyStatus()
	ns:Print(text)
	if rec and now then
		local state, left = ns.State(rec, now, Have(), true)
		if state == "active" then
			print("  " .. GREY .. "The next one " .. ns.Wait(left, now, true) .. ", even if you die.|r")
		end
		local c = ns.Clock(rec.got)
		print("  " .. GREY .. "Last fortune: " .. (rec.kind or "?") .. (c and ((rec.late and ", first seen " or ", ") .. c) or "") .. (rec.lost and ", lost early" or "") .. ".|r")
	end
	print("  " .. GREY .. "Sayge's wait is 4 hours from a fortune, counted only while that character is logged in, and dying does not end it.|r")
	local _, myKey = ns.Mine()
	local others = {}
	for key, r in pairs(Chars()) do
		-- this faire's, and any older one whose wait is not used up (it only runs while logged in)
		if key ~= myKey and type(r) == "table" and r.got and now and (now - r.got < ns.KEEP or (ns.Left(r, now, false) or 0) > 0) then
			others[#others + 1] = { key = key, rec = r }
		end
	end
	table.sort(others, function(a, b)
		return a.rec.got < b.rec.got
	end)
	if #others > 0 then
		print("  Other characters:")
		for _, o in ipairs(others) do
			print("    " .. o.key .. ": " .. ns.StatusText(o.rec, now, nil, false))
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

local resumed = false -- this session's count has been picked up
local function ResumeOnce()
	if not resumed then
		resumed = true
		ns.Resume()
	end
end

ns:RegisterEvent("UNIT_AURA", OnAura)
ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	ResumeOnce()
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
	ResumeOnce()
	ns.Scan()
	ns.Schedule()
end

-- At login, on or off: note when the session began, and save the count at logout through a frame
-- of our own (the bundle's events reach only enabled features).
function ns.OnLoad()
	Migrate()
	sessionStart = Now()
	if not ns.logoutFrame then
		local f = CreateFrame("Frame")
		f:RegisterEvent("PLAYER_LOGOUT")
		f:SetScript("OnEvent", function()
			root.TryQuiet(ns, "logout", Save)
		end)
		ns.logoutFrame = f
	end
end
