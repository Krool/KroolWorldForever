-- Sayge's Fortune behavior checks. Runs after stubs.lua and the whole bundle.

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
local function has(list, needle)
	for _, l in ipairs(list) do
		if tostring(l):find(needle, 1, true) then
			return true
		end
	end
	return false
end
local function capture(fn)
	local out = {}
	print = function(...)
		local t = {}
		for i = 1, select("#", ...) do
			t[#t + 1] = tostring((select(i, ...)))
		end
		out[#out + 1] = table.concat(t, " ")
	end
	local ok, err = pcall(fn)
	print = realPrint
	if not ok then
		error(err)
	end
	return out
end
local function count_of(list, needle)
	local n = 0
	for _, l in ipairs(list) do
		if tostring(l):find(needle, 1, true) then
			n = n + 1
		end
	end
	return n
end

local root = __ns
local ns = root.features.fortune

local DAMAGE, STRENGTH, FOREVER_DAMAGE = 23768, 23735, 1304769
local SAYGE = "Creature-0-4170-0-12-14822-0000A1B2C3"
local OTHER = "Creature-0-4170-0-12-299-0000A1B2C3"
local START = Now -- 08:00 UTC

-- Puts a fortune on the player that was given `ago` seconds ago, and tells the feature.
local nextInstance = 100
local function Gain(id, ago)
	nextInstance = nextInstance + 1
	PlayerAuras[id] = {
		spellId = id,
		duration = 7200,
		expirationTime = Clock - (ago or 0) + 7200,
		auraInstanceID = nextInstance,
	}
	return capture(function()
		FireEvent("UNIT_AURA", "player", { addedAuras = { { spellId = id, auraInstanceID = nextInstance } } })
	end)
end
-- Takes it off again, the way the client reports a removal.
local function Remove(id)
	local inst = PlayerAuras[id] and PlayerAuras[id].auraInstanceID
	PlayerAuras[id] = nil
	return capture(function()
		FireEvent("UNIT_AURA", "player", { removedAuraInstanceIDs = { inst } })
	end)
end
local function Status()
	return ns.HubStatus()
end
local function Mine()
	return (ns.Mine())
end

-- ---------------------------------------------------------------- lifecycle

FireEvent("ADDON_LOADED", "KroolWorldForever")
local db = KroolWorldForeverDB.features.fortune
check("feature slice created", type(db), "table")
check("on by default", db.enabled, true)
check("tooltips on by default", db.tooltip, true)
check("lost warning on by default", db.warn, true)
check("ready reminder on by default", db.ready, true)
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("enabled after login", ns.enabled, true)
check("unit tooltip hooked", has(TooltipChains[Enum.TooltipDataType.Unit] or {}, tostring(ns.OnUnitTooltip)), true)
check("aura tooltip hooked", has(TooltipChains[Enum.TooltipDataType.UnitAura] or {}, tostring(ns.OnAuraTooltip)), true)
local hooks = #TooltipChains[Enum.TooltipDataType.Unit]
ns.OnEnable()
check("hooked once only", #TooltipChains[Enum.TooltipDataType.Unit], hooks)
check("/sayge registered", SLASH_KROOLWORLDFOREVER_FORTUNE1, "/sayge")
check("hub icon is the fortune's file id", ns.icon, 134334)
check("hub blurb", type(ns.blurb), "string")
check("sixteen fortune spells known", (function()
	local n = 0
	for _ in pairs(ns.FORTUNES) do
		n = n + 1
	end
	return n
end)(), 16)

-- ---------------------------------------------------------------- text

check("duration hours", ns.Duration(6720), "1h 52m")
check("duration minutes", ns.Duration(720), "12m")
check("duration under a minute", ns.Duration(20), "under a minute")
check("clock 12-hour", ns.Clock(START), "8:00 AM")
check("clock noon", ns.Clock(START + 4 * 3600), "12:00 PM")
Military = true
check("clock 24-hour option", ns.Clock(START + 7 * 3600), "15:00")
Military = false
check("when: later", ns.When(START + 3600, START), "at 9:00 AM (in 1h 0m)")
check("when: due", ns.When(START, START + 5), "now")

-- ---------------------------------------------------------------- a fortune

check("nothing yet", Status():find("No fortune seen on this character yet", 1, true) ~= nil, true)
Gain(DAMAGE)
local rec = Mine()
check("fortune recorded", type(rec), "table")
check("given now", rec and rec.got, START)
check("which one", rec and rec.kind, "Damage")
check("its spell", rec and rec.spell, DAMAGE)
check("stored per character", db.chars["Krool-Stormrage"], rec)
check("status: active", Status():find("Fortune of Damage, 2h 0m left", 1, true) ~= nil, true)
check("a reminder is set for the end of the wait", #Timers > 0 and Timers[#Timers].delay, 4 * 3600 + 1)

Advance(600)
capture(function()
	FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
end)
check("the same fortune is not recorded again", Mine().got, START)

-- seen later (a reload half an hour in): dated from its time left
PlayerAuras[DAMAGE] = nil
db.chars = {}
PlayerAuras[DAMAGE] = { spellId = DAMAGE, duration = 7200, expirationTime = Clock + 5400, auraInstanceID = 150 }
capture(function()
	FireEvent("PLAYER_ENTERING_WORLD")
end)
check("dated from its time left", Mine() and Mine().got, Now - 1800)

-- ---------------------------------------------------------------- death

wipe(PlayerAuras)
db.chars = {}
Advance(3600) -- 09:10
local at = Now
Gain(DAMAGE)
Advance(1800) -- died 30 minutes in
local out = Remove(DAMAGE)
check("lost: says so", has(out, "You lost your fortune"), true)
check("lost: with when the next one comes", has(out, "the next one at 1:10 PM (in 3h 30m)"), true)
check("lost: noted", Mine().lost, Now)
check("status: waiting", Status():find("Next fortune at 1:10 PM (in 3h 30m)", 1, true) ~= nil, true)
out = capture(function()
	FireEvent("PLAYER_DEAD")
end)
check("PLAYER_DEAD after the removal: said once only", has(out, "You lost"), false)
check("the wait still counts from the fortune", Mine().got, at)

-- death reported only by PLAYER_DEAD (no removal event first)
db.chars = {}
Gain(STRENGTH)
Advance(60)
PlayerAuras[STRENGTH] = nil
out = capture(function()
	FireEvent("PLAYER_DEAD")
end)
check("PLAYER_DEAD alone: lost", has(out, "You lost your fortune"), true)
check("a Strength fortune", Mine().kind, "Strength")

-- running out after 2 hours is not losing it
db.chars = {}
Gain(DAMAGE)
Advance(7200)
out = Remove(DAMAGE)
check("ran out: no message", #out, 0)
check("ran out: not lost", Mine().lost, nil)
check("ran out: waiting for the rest of the 4 hours", Status():find("Next fortune", 1, true) ~= nil, true)
Advance(7200)
check("after 4 hours: ready", Status():find("Ready for a new fortune", 1, true) ~= nil, true)

-- inside an instance an unreadable aura is not called lost
db.chars = {}
Gain(DAMAGE)
InInstance = true
PlayerAuras[DAMAGE] = nil
out = capture(function()
	FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
end)
check("instance: no false loss", has(out, "You lost"), false)
check("instance: not marked lost", Mine().lost, nil)
InInstance = false

-- ---------------------------------------------------------------- the reminder

wipe(PlayerAuras)
db.chars = {}
wipe(Timers)
Advance(60) -- a different fortune from the last scenario's
Gain(DAMAGE)
check("one reminder", #Timers, 1)
Gain(DAMAGE) -- the same fortune seen again
check("not set twice", #Timers, 1)
Advance(4 * 3600 + 1)
out = capture(function()
	RunTimersOver(3600)
end)
check("reminder: the wait is over", has(out, "Sayge's wait is over"), true)

-- a newer fortune silences the old reminder
db.chars = {}
wipe(Timers)
wipe(PlayerAuras)
Gain(DAMAGE)
Advance(5 * 3600)
Remove(DAMAGE)
Gain(STRENGTH)
Advance(4 * 3600)
out = capture(function()
	RunTimersOver(3600)
end)
check("old reminder stays quiet, the new one speaks once", count_of(out, "Sayge's wait is over"), 1)

-- ---------------------------------------------------------------- tooltips

wipe(PlayerAuras)
wipe(Timers)
db.chars = {}
local base = Now
Gain(DAMAGE)
local tt = ShowUnit(SAYGE)
check("Sayge: status line", has(tt.lines, "Sayge:") and has(tt.lines, "Fortune of Damage"), true)
check("Sayge: when the next one comes", has(tt.lines, "even if you die"), true)
check("another creature: nothing from us", has(ShowUnit(OTHER).lines, "Sayge:"), false)
check("a secret GUID: nothing", has(ShowUnit(Secret()).lines, "Sayge:"), false)
tt = ShowAura(DAMAGE)
check("fortune buff: next fortune", has(tt.lines, "your next fortune at " .. ns.Clock(base + 4 * 3600)), true)
check("other buffs: nothing", has(ShowAura(12345).lines, "Sayge:"), false)
Advance(1800)
Remove(DAMAGE)
tt = ShowUnit(SAYGE)
check("Sayge while waiting: the wait explained", has(tt.lines, "dying does not end it"), true)
root.SetOption(ns, "tooltip", false)
check("option off: no Sayge line", has(ShowUnit(SAYGE).lines, "Sayge:"), false)
root.SetOption(ns, "tooltip", true)

-- Forever's own copies count too
wipe(PlayerAuras)
db.chars = {}
Gain(FOREVER_DAMAGE)
check("Forever's copy recorded", Mine() and Mine().spell, FOREVER_DAMAGE)

-- ---------------------------------------------------------------- Sayge's answers

wipe(PlayerAuras)
db.chars = {}
db.visits = nil
Gain(DAMAGE)
Advance(2 * 3600)
Remove(DAMAGE)
UnitGUIDs.npc = SAYGE
Gossip.options, Gossip.text = {}, "Come back later, child."
capture(function()
	FireEvent("GOSSIP_SHOW")
end)
check("visit recorded", #db.visits, 1)
check("no options: turned away", db.visits[1].verdict, "refused")
check("his words kept", db.visits[1].text, "Come back later, child.")
check("while waiting it changes nothing", Status():find("Next fortune", 1, true) ~= nil, true)
Advance(2 * 3600 + 60)
capture(function()
	FireEvent("GOSSIP_SHOW")
end)
check("turned away after the 4 hours: said", Status():find("Sayge turned you away at", 1, true) ~= nil, true)
Gossip.options = { { name = "I am ready to discover where my fortune lies!" } }
capture(function()
	FireEvent("GOSSIP_SHOW")
end)
check("fortune option: offered", db.visits[3].verdict, "offered")
check("offered: ready", Status():find("Ready for a new fortune", 1, true) ~= nil, true)
Gossip.options = { { name = "Tell me about the faire." } }
capture(function()
	FireEvent("GOSSIP_SHOW")
end)
check("other options: unknown", db.visits[4].verdict, "unknown")
UnitGUIDs.npc = OTHER
capture(function()
	FireEvent("GOSSIP_SHOW")
end)
check("other npcs are not recorded", #db.visits, 4)
UnitGUIDs.npc = nil
for _ = 1, 60 do
	ns.OnGossip() -- no npc: ignored
end
check("still four", #db.visits, 4)

-- offered before the 4 hours were up: Sayge knows best
db.chars = {}
Gain(DAMAGE)
Advance(2 * 3600 + 60)
Remove(DAMAGE)
UnitGUIDs.npc = SAYGE
Gossip.options = { { name = "I am ready to discover where my fortune lies!" } }
capture(function()
	FireEvent("GOSSIP_SHOW")
end)
check("offered early: ready", Status():find("Ready for a new fortune", 1, true) ~= nil, true)
UnitGUIDs.npc = nil

-- ---------------------------------------------------------------- /sayge and other characters

wipe(PlayerAuras)
db.chars = {}
Gain(DAMAGE)
PlayerName = "Mick"
wipe(PlayerAuras)
Advance(600)
Gain(STRENGTH)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_FORTUNE("")
end)
check("/sayge: this character", has(out, "Fortune of Strength"), true)
check("/sayge: the rule", has(out, "4 hours from a fortune"), true)
check("/sayge: other characters", has(out, "Krool-Stormrage: "), true)
check("/sayge: talks recorded", has(out, "Talks with Sayge recorded"), true)
Advance(9 * 24 * 3600)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_FORTUNE("")
end)
check("/sayge: old faires left out", has(out, "Krool-Stormrage"), false)
PlayerName = "Krool"
OpenedCategory = nil
capture(function()
	SlashCmdList.KROOLWORLDFOREVER_FORTUNE("options")
end)
check("/sayge options opens settings", OpenedCategory, "Sayge's Fortune")

-- ---------------------------------------------------------------- warn option, secrets, errors

wipe(PlayerAuras)
db.chars = {}
root.SetOption(ns, "warn", false)
Gain(DAMAGE)
Advance(60)
out = Remove(DAMAGE)
check("warn off: no message", has(out, "You lost"), false)
check("warn off: still noted", Mine().lost ~= nil, true)
root.SetOption(ns, "warn", true)

wipe(PlayerAuras)
db.chars = {}
PlayerAuras[DAMAGE] = { spellId = DAMAGE, duration = 7200, expirationTime = Secret(), auraInstanceID = 5 }
local okSecret = pcall(function()
	capture(function()
		FireEvent("UNIT_AURA", "player", { addedAuras = { { spellId = Secret() } } })
	end)
end)
check("secret time left: no error", okSecret, true)
check("secret time left: nothing recorded", Mine(), nil)
wipe(PlayerAuras)
AuraErrors = true
out = capture(function()
	FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
end)
check("aura lookup error stays inside", has(out, "error"), false)
check("hub survives it", type(ns.HubStatus()), "string")
AuraErrors = false

-- ---------------------------------------------------------------- secrets (the Deadmines, 2026-11-09)

-- UNIT_AURA's own fields can be secret: a boolean test on isFullUpdate raised every aura change.
-- A stub secret cannot make a boolean test fail (plain Lua has no hook for it), so this checks the
-- handling, not the error itself; the fix is the Secret() check before each test in OnAura.
wipe(PlayerAuras)
db.chars = {}
Gain(DAMAGE)
out = capture(function()
	FireEvent("UNIT_AURA", "player", { isFullUpdate = Secret(), addedAuras = Secret(), removedAuraInstanceIDs = Secret() })
	FireEvent("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { { spellId = Secret() } } })
	FireEvent("UNIT_AURA", Secret(), {})
end)
check("secret event fields: no error", has(out, "error"), false)
check("secret event fields: the record stands", Mine() and Mine().kind, "Damage")

-- while auras are hidden nothing is read, and a hidden fortune is not a lost one
AurasHidden = true
AuraReads = 0
out = capture(function()
	FireEvent("UNIT_AURA", "player", { isFullUpdate = true })
	FireEvent("UNIT_AURA", "player", { removedAuraInstanceIDs = { 999 } })
	FireEvent("PLAYER_DEAD")
	ShowUnit(SAYGE)
	ShowAura(DAMAGE)
	SlashCmdList.KROOLWORLDFOREVER_FORTUNE("")
end)
check("hidden auras: not one read", AuraReads, 0)
check("hidden auras: no error", has(out, "error"), false)
check("hidden auras: no false loss", has(out, "You lost"), false)
check("hidden auras: the clock still answers", Status():find("Fortune of Damage", 1, true) ~= nil, true)
check("hidden auras: the record stands", Mine().lost, nil)
-- died in there: the loss shows once the auras can be read again
PlayerAuras[DAMAGE] = nil
Advance(600)
AurasHidden = false
out = capture(function()
	FireEvent("PLAYER_ENTERING_WORLD")
end)
check("out again: the loss is noticed", has(out, "You lost your fortune"), true)
check("the shared check reads the predicate", root.AurasSecret(), false)
C_Secrets.ShouldAurasBeSecret = function()
	error("no")
end
check("an erroring predicate counts as hidden", root.AurasSecret(), true)
C_Secrets.ShouldAurasBeSecret = function()
	return AurasHidden
end

-- ---------------------------------------------------------------- on/off

wipe(PlayerAuras)
db.chars = {}
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER("fortune off")
end)
check("/kw fortune off", ns.enabled, false)
Gain(DAMAGE)
check("off: no record", Mine(), nil)
check("off: no tooltip line", has(ShowUnit(SAYGE).lines, "Sayge:"), false)
check("off: no buff line", has(ShowAura(DAMAGE).lines, "Sayge:"), false)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("fortune on")
end)
check("/kw fortune on", ns.enabled, true)
check("on: the fortune is picked up", Mine() and Mine().kind, "Damage")

-- ---------------------------------------------------------------- caught errors (core)
-- The bundle catches every error, so BugSack never sees them: they are logged instead.

local sv = KroolWorldForeverDB
sv.errors = nil
check("a session number is kept", type(root.session) == "number" and root.session == sv.session, true)
ns.events.KW_TEST = function()
	error("boom")
end
out = capture(function()
	root.Dispatch("KW_TEST")
	Advance(30)
	root.Dispatch("KW_TEST")
end)
check("an event error is printed once", count_of(out, "boom"), 1)
check("the line names the event", has(out, "error|r in KW_TEST"), true)
local e = sv.errors and sv.errors[1]
check("and logged once", sv.errors and #sv.errors, 1)
check("with a count", e and e.count, 2)
check("its feature", e and e.feature, "fortune")
check("its event", e and e.where, "KW_TEST")
check("its session", e and e.session, root.session)
check("its stack", type(e and e.stack) == "string" and e.stack:find("test.lua", 1, true) ~= nil, true)
check("first and last time", e and e.last - e.first, 30)
ns.events.KW_TEST = nil

out = capture(function()
	root.TryQuiet(ns, "tooltip", function()
		error("quiet one")
	end)
end)
check("a quiet error prints nothing", #out, 0)
check("but is logged, newest last", sv.errors[#sv.errors].where, "tooltip")

local ok, a, b = root.Try(ns, "x", function(x)
	return x, 2
end, 1)
check("Try passes results through", ok and a == 1 and b == 2, true)
local okF, errF
capture(function()
	okF, errF = root.Try(ns, "x", function()
		error("bad", 0)
	end)
end)
check("Try returns false and the error", okF == false and errF == "bad", true)

for i = 1, root.ERRORS_MAX + 5 do
	root.TryQuiet(ns, "many", error, "error " .. i, 0)
end
check("the log is capped", #sv.errors, root.ERRORS_MAX)
check("the newest stays", sv.errors[#sv.errors].message, "error " .. (root.ERRORS_MAX + 5))

out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER("errors")
end)
check("/kw errors lists them", has(out, "error(s) caught"), true)
check("/kw errors names the feature", has(out, "Sayge's Fortune"), true)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER("errors clear")
	SlashCmdList.KROOLWORLDFOREVER("errors")
end)
check("/kw errors clear empties the log", #sv.errors, 0)
check("and says so", has(out, "no errors caught"), true)
ns.events.KW_TEST = function()
	error("boom")
end
out = capture(function()
	root.Dispatch("KW_TEST")
end)
ns.events.KW_TEST = nil
check("after clearing, an error prints again", count_of(out, "boom"), 1)
sv.errors = nil
out = capture(function()
	root.Report(nil, "core thing", "core boom")
end)
check("a core error prints as the bundle", has(out, "core boom"), true)
check("and is logged as core", sv.errors and sv.errors[1].feature, "core")

realPrint(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
