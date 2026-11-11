-- Core checks: the registry, lifecycle and slash commands (Registry.lua, Init.lua), the settings
-- plumbing (Settings.lua), prices and money (Prices.lua) and the hub (Hub.lua). A made-up feature,
-- "probe", is declared here before ADDON_LOADED, the way a feature file declares itself at load.

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

local root = __ns

-- ---------------------------------------------------------------- a feature of our own

local calls = { load = 0, enable = 0, disable = 0, event = 0, option = {} }
local probe = root.Feature("probe")
probe.title = "Probe"
probe.description = "A feature for the core suite."
probe.options = {
	{ key = "loud", type = "toggle", label = "Loud", default = true },
	{ key = "size", type = "range", label = "Size", default = 5, min = 1, max = 10 },
}
probe.slash = { "/probe" }
function probe.OnSlash(msg)
	calls.slash = msg
end
function probe.OnLoad()
	calls.load = calls.load + 1
end
function probe.OnEnable()
	calls.enable = calls.enable + 1
end
function probe.OnDisable()
	calls.disable = calls.disable + 1
end
function probe.OnOptionChanged(key, value)
	calls.option[#calls.option + 1] = key .. "=" .. tostring(value)
end
function probe.OnOpen()
	error("window broke")
end
function probe.HubStatus()
	return calls.status
end
probe:RegisterEvent("KW_PROBE", function(_, what)
	calls.event = calls.event + 1
	if what == "boom" then
		error("boom")
	end
end)
check("root.Feature returns the same table for a key", root.Feature("probe"), probe)

-- ---------------------------------------------------------------- lifecycle

FireEvent("ADDON_LOADED", "SomeOtherAddon")
check("another addon loading does nothing", calls.load, 0)
capture(function()
	FireEvent("ADDON_LOADED", "KroolWorldForever")
end)
local sv = KroolWorldForeverDB
check("saved variables created", type(sv.features), "table")
check("the feature's slice is its db", sv.features.probe, probe.db)
check("OnLoad ran once", calls.load, 1)
check("defaults: enabled", probe.db.enabled, true)
check("defaults: a toggle", probe.db.loud, true)
check("defaults: a range", probe.db.size, 5)
check("not enabled before login", probe.enabled, false)
root.Dispatch("KW_PROBE")
check("no events before login", calls.event, 0)
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("enabled at login", probe.enabled, true)
check("OnEnable ran once", calls.enable, 1)
root.Dispatch("KW_PROBE")
check("events reach an enabled feature", calls.event, 1)

-- A saved choice survives the next load; a missing one gets its default.
probe.db.size = 9
probe.db.loud = nil
capture(function()
	FireEvent("ADDON_LOADED", "KroolWorldForever")
end)
check("a saved option is kept", probe.db.size, 9)
check("a missing option gets its default", probe.db.loud, true)
probe.db.size = 5

-- ---------------------------------------------------------------- on and off

local out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER("probe off")
end)
check("/kw probe off: saved", probe.db.enabled, false)
check("/kw probe off: off now", probe.enabled, false)
check("/kw probe off: OnDisable ran", calls.disable, 1)
check("/kw probe off: says so", has(out, "off"), true)
root.Dispatch("KW_PROBE")
check("off: no events", calls.event, 1)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_PROBE("hello")
end)
check("off: its own slash command does not run", calls.slash, nil)
check("off: and says how to turn it on", has(out, "/kw probe on"), true)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("probe off")
end)
check("off twice: OnDisable only once", calls.disable, 1)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("probe on")
end)
check("/kw probe on: OnEnable ran again", calls.enable, 2)
SlashCmdList.KROOLWORLDFOREVER_PROBE("hello")
check("on: its own slash command runs", calls.slash, "hello")

-- Every real feature answers its switch.
for _, key in ipairs(root.featureOrder) do
	local F = root.features[key]
	capture(function()
		SlashCmdList.KROOLWORLDFOREVER(key .. " off")
	end)
	check("/kw " .. key .. " off", F.enabled == false and F.db.enabled == false, true)
	capture(function()
		SlashCmdList.KROOLWORLDFOREVER(key .. " on")
	end)
	check("/kw " .. key .. " on", F.enabled == true and F.db.enabled == true, true)
end
calls.enable, calls.disable = 0, 0

-- ---------------------------------------------------------------- options

root.SetOption(probe, "loud", false)
check("SetOption writes the value", probe.db.loud, false)
check("SetOption tells the feature once", table.concat(calls.option, " "), "loud=false")
check("SetOption goes through the panel's setting", RegisteredSettings["KroolWorldForever_probe_loud"].tbl.loud, false)
root.SetOption(probe, "enabled", false)
check("SetOption enabled=false turns the feature off", probe.enabled == false and calls.disable, 1)
root.SetOption(probe, "enabled", true)
check("and on again", probe.enabled == true and calls.enable, 1)
-- Before the panel exists (or for an option it does not show) the value is written directly.
local keep = probe.settingObjects
probe.settingObjects = nil
root.SetOption(probe, "size", 7)
probe.settingObjects = keep
check("SetOption without a panel setting still writes", probe.db.size, 7)
check("and still tells the feature", calls.option[#calls.option], "size=7")

-- ---------------------------------------------------------------- errors stay inside

sv.errors = nil
local ok
out = capture(function()
	ok = pcall(root.Dispatch, "KW_PROBE", "boom")
end)
check("an event handler's error does not escape", ok, true)
check("it prints once", has(out, "boom"), true)
check("it is logged with the feature and the event", sv.errors[1].feature .. "/" .. sv.errors[1].where, "probe/KW_PROBE")
out = capture(function()
	root.Dispatch("KW_PROBE", "boom")
end)
check("the same error does not print twice", has(out, "boom"), false)
check("but it is counted", sv.errors[1].count, 2)

out = capture(function()
	ok = pcall(SlashCmdList.KROOLWORLDFOREVER, "probe")
end)
check("/kw probe: a window that fails to open does not escape", ok, true)
check("and is reported", has(out, "window broke"), true)
out = capture(function()
	ok = pcall(SettingsButtons["Open Probe"].onClick)
end)
check("the settings page's Open button: the same", ok, true)

local a, b, c = root.Try(nil, "a test", function(x)
	return x, "two"
end, "one")
check("Try returns what pcall would", tostring(a) .. tostring(b) .. tostring(c), "trueonetwo")
out = capture(function()
	a, b = root.TryQuiet(probe, "a quiet place", function()
		error("hush")
	end)
end)
check("TryQuiet returns false and the error", a == false and tostring(b):find("hush", 1, true) ~= nil, true)
check("TryQuiet prints nothing", #out, 0)
check("TryQuiet still logs", sv.errors[#sv.errors].where, "a quiet place")
capture(function()
	for i = 1, root.ERRORS_MAX + 5 do
		root.Report(probe, "flood", "error " .. i)
	end
end)
check("the log is capped", #sv.errors, root.ERRORS_MAX)
check("and keeps the newest", sv.errors[#sv.errors].message, "error " .. (root.ERRORS_MAX + 5))
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER("errors")
end)
check("/kw errors lists them", has(out, "error " .. (root.ERRORS_MAX + 5)), true)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("errors clear")
end)
check("/kw errors clear empties the log", #sv.errors, 0)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER("nosuchfeature")
end)
check("an unknown feature is named", has(out, "unknown feature 'nosuchfeature'"), true)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER("list")
end)
check("/kw list names every feature", has(out, "probe - Probe") and has(out, "questtrash"), true)

-- ---------------------------------------------------------------- hidden auras

AurasHidden = false
check("auras readable", root.AurasSecret(), false)
AurasHidden = true
check("auras hidden", root.AurasSecret(), true)
AurasHidden = Secret()
check("a secret answer counts as hidden", root.AurasSecret(), true)
AurasHidden = false
local realSecrets = C_Secrets
C_Secrets = {
	ShouldAurasBeSecret = function()
		error("no")
	end,
}
check("a failing predicate counts as hidden", root.AurasSecret(), true)
C_Secrets = nil
check("a client without the predicate has no hidden auras", root.AurasSecret(), false)
C_Secrets = realSecrets

-- ---------------------------------------------------------------- money and prices

local function plain(s)
	return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
check("money: copper only", plain(root.Money(5)), "5c")
check("money: silver shows copper", plain(root.Money(120)), "1s 20c")
check("money: gold shows all three", plain(root.Money(12345)), "1g 23s 45c")
check("money: nothing", plain(root.Money(nil)), "0c")
check("money: rounds", plain(root.Money(99.6)), "1s 0c")
check("money: a negative amount keeps its size", plain(root.Money(-30)), "-30c")
check("money: negative gold", plain(root.Money(-12345)), "-1g 23s 45c")

Prices[100] = 250
LinkPrices["item:100::suffix"] = 900
Prices[101] = 0
check("price by id", root.AuctionPrice(100), 250)
check("price by link: the link's own price", root.AuctionPrice("item:100::suffix"), 900)
check("a zero price is no price", root.AuctionPrice(101), nil)
check("an unknown item has no price", root.AuctionPrice(102), nil)
Ages[100] = 0
check("age by id", root.AuctionAge(100), 0)
check("an unknown age", root.AuctionAge(102), nil)
check("not old at the limit", root.AuctionStale(root.STALE_DAYS), false)
check("old past it", root.AuctionStale(root.STALE_DAYS + 1), true)
check("an unknown age is never old", root.AuctionStale(nil), false)
check("seen today", root.SeenText(0), "seen today")
check("seen yesterday", root.SeenText(1), "seen yesterday")
check("seen days ago", root.SeenText(5), "seen 5 days ago")
check("seen: unknown", root.SeenText(nil), nil)

local scans = 0
check("scan listeners: Auctionator will call back", root.OnAuctionPrices(function()
	error("a listener that fails")
end), true)
root.OnAuctionPrices(function()
	scans = scans + 1
end)
check("registered with Auctionator once, however many listen", #ScanCallbacks, 1)
ok = pcall(AuctionatorScan)
check("a failing listener does not reach Auctionator", ok, true)
check("or stop the others", scans, 1)

AuctionatorOn(false)
check("no Auctionator: says so", root.HasAuctionator(), false)
check("no Auctionator: no price", root.AuctionPrice(100), nil)
check("no Auctionator: no age", root.AuctionAge(100), nil)
AuctionatorOn(true)
Auctionator.API.v1.GetAuctionPriceByItemID = function()
	error("auctionator broke")
end
check("an Auctionator error is no price", root.AuctionPrice(100), nil)
AuctionatorOn(true)

-- ---------------------------------------------------------------- hub

check("hub rows: the default screen fits nine", root.HubRows(768), 9)
check("hub rows: a short screen fits fewer", root.HubRows(600), 6)
check("hub rows: unknown height means the default", root.HubRows(nil), 9)
check("hub rows: never fewer than three", root.HubRows(100), 3)

local n = #root.featureOrder
check("this suite has more features than fit one screen", n > 9, true)
root.OpenHub()
local hub = root.HubFrame()
check("the hub opens", hub:IsShown(), true)
check("one card per feature", #hub.cards, n)
check("the hub shows a screen of cards and scrolls the rest", hub.visibleCards, 9)
local card
for _, c2 in ipairs(hub.cards) do
	if c2.feature == probe then
		card = c2
	end
end
check("the card names its feature", card.title.text, "Probe")
calls.status = "doing fine"
root.RefreshHub()
check("the card shows the feature's status", card.status.text, "doing fine")
probe.HubStatus = function()
	error("status broke")
end
ok = pcall(root.RefreshHub)
check("a failing status does not break the hub", ok and card.status.text, "")
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("probe off")
end)
check("an open hub follows the switch", card.status.text:find("Off", 1, true) ~= nil, true)
root.OpenHub()
check("opening it again closes it", hub:IsShown(), false)

realPrint(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
