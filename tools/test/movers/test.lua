-- Market Movers behavior checks. Runs after stubs.lua and the whole bundle.

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
local ns = root.features.movers

-- ---------------------------------------------------------------- fixtures

local COPPER, LINEN, PEACE, RARE_MAT, POTION, RECIPE, SWORD, CHEST, BAG, CHEAP =
	2770, 2589, 2447, 7076, 929, 2553, 900301, 900302, 900303, 900304
Items[COPPER] = { name = "Copper Ore", class = 7 }
Items[LINEN] = { name = "Linen Cloth", class = 7 }
Items[PEACE] = { name = "Peacebloom", class = 7 }
Items[RARE_MAT] = { name = "Essence of Earth", class = 7 }
Items[POTION] = { name = "Healing Potion", class = 0 }
Items[RECIPE] = { name = "Recipe: Elixir of Minor Agility", class = 9 }
Items[SWORD] = { name = "Cruel Sword", class = 2 }
Items[CHEST] = { name = "Forever Chestguard", class = 4 }
Items[BAG] = { name = "Linen Bag", class = 1 }
Items[CHEAP] = { name = "Rough Stone", class = 7 }
for i = 1, 300 do
	Items[800000 + i] = { name = "Filler " .. i, class = 15 }
end

-- One day's scan: the filler plus these { [id] = { price, qty } }.
local function Scan(list, opts)
	opts = opts or {}
	wipe(Browse)
	wipe(BrowseExtra)
	Filler(opts.filler or 250)
	for id, e in pairs(list) do
		Browse[id] = e
	end
	FullBrowse = opts.full ~= false
	AuctionatorScan()
end

local function Rows(list)
	local out = {}
	for _, r in ipairs(list) do
		out[#out + 1] = r.id
	end
	return table.concat(out, ",")
end

local function House()
	return KroolWorldForeverDB.features.movers.ah[Faction]
end

-- ---------------------------------------------------------------- lifecycle

FireEvent("ADDON_LOADED", "KroolWorldForever")
local db = KroolWorldForeverDB.features.movers
check("feature slice created", type(db), "table")
check("on by default", db.enabled, true)
check("opens after a full scan by default", db.openAfterScan, true)
check("common at 40 by default", db.commonQty, 40)
check("smallest change 10% by default", db.minChange, 10)
check("ignore under 1s by default", db.minSilver, 1)
check("12 rows by default", db.rows, 12)
check("record made", type(db.ah), "table")
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("enabled after login", ns.enabled, true)
check("hooked to Auctionator's scans", ns.auctionHooked, true)

-- ---------------------------------------------------------------- no data, first day

check("no scan yet: report says so", ns.Report().state, "nodata")
check("hub: scan to start", ns.HubStatus():find("Scan the auction house", 1, true) ~= nil, true)

-- Day 1 (Nov 16): two full scans, the second a little dearer for copper.
Now = At(2026, 11, 16, 10, 0)
Scan({
	[COPPER] = { 1000, 120 },
	[LINEN] = { 300, 400 },
	[PEACE] = { 500, 120 },
	[RARE_MAT] = { 50000, 6 },
	[POTION] = { 2000, 30 },
	[RECIPE] = { 90000, 1 },
	[SWORD] = { 70000, 1 },
	[CHEST] = { 120000, 1 },
	[BAG] = { 4000, 10 },
	[CHEAP] = { 40, 300 },
})
local day1 = ns.Day()
check("a full scan is recorded", type(House().days[day1]), "table")
check("copper recorded", House().days[day1][COPPER].n, 1)
check("gear is not recorded (weapon)", House().days[day1][SWORD], nil)
check("gear is not recorded (armor)", House().days[day1][CHEST], nil)
check("bags are not recorded", House().days[day1][BAG], nil)
check("first day: nothing to compare yet", ns.Report().state, "nobase")
check("hub: first comparison tomorrow", ns.HubStatus():find("tomorrow", 1, true) ~= nil, true)

-- A second callback for the same scan, seconds later: not counted twice.
Now = Now + 20
AuctionatorScan()
check("the same scan is not counted twice", House().days[day1][COPPER].n, 1)

Now = At(2026, 11, 16, 18, 0)
Scan({
	[COPPER] = { 1400, 100 },
	[LINEN] = { 300, 380 },
	[PEACE] = { 500, 110 },
	[RARE_MAT] = { 50000, 5 },
	[POTION] = { 2000, 25 },
	[RECIPE] = { 90000, 1 },
	[CHEAP] = { 40, 280 },
})
check("two scans on day 1", House().days[day1][COPPER].n, 2)
check("day 1 copper sum", House().days[day1][COPPER].s, 2400)
check("day 1 copper most listed", House().days[day1][COPPER].q, 120)

-- A small search on day 1: recorded nowhere.
wipe(Browse)
Browse[COPPER] = { 1, 1 }
AuctionatorScan()
check("a small search is not a full scan", House().days[day1][COPPER].n, 2)
check("a small search leaves 'now' alone", House().now.items[COPPER].p, 1400)

-- A big browse still paging: wait for the rest.
Now = Now + 300
Filler(250)
FullBrowse = false
AuctionatorScan()
check("a browse still paging is not recorded", House().days[day1][COPPER].n, 2)
FullBrowse = true

-- ---------------------------------------------------------------- day 2: the report

Now = At(2026, 11, 17, 9, 0)
ns.ahOpen = true -- the auction house is open (AUCTION_HOUSE_SHOW, below, tests the event)
ns.openedThisVisit = false
local function Day2Scan()
	Scan({
		[COPPER] = { 1800, 90 }, -- +50% on the day-1 average of 1200
		[LINEN] = { 240, 420 }, -- -20%
		[PEACE] = { 520, 110 }, -- +4%: under the smallest change
		[RARE_MAT] = { 80000, 4 }, -- +60%, but only a handful listed: Other Items
		[POTION] = { 3000, 20 }, -- +50%
		[RECIPE] = { 45000, 1 }, -- -50%
		[CHEAP] = { 80, 300 }, -- +100%, but under 1s both days
	})
end
Day2Scan()
local rep = ns.Report()
check("day 2: report ready", rep.state, "ok")
check("compared with day 1", rep.baseDay, day1)
check("trade materials: copper then linen", Rows(rep.trade), COPPER .. "," .. LINEN)
check("other items: essence, then the 50% ties by id", Rows(rep.other), RARE_MAT .. "," .. POTION .. "," .. RECIPE)
check("copper's change is +50%", math.floor(rep.trade[1].change * 100 + 0.5), 50)
check("copper's before is the day-1 average", rep.trade[1].before, 1200)
check("copper's before came from 2 scans", rep.trade[1].scans, 2)
check("linen's change is -20%", math.floor(rep.trade[2].change * 100 + 0.5), -20)
check("peacebloom's 4% is left out", has({ Rows(rep.trade), Rows(rep.other) }, tostring(PEACE)), false)
check("rough stone under 1s both days is left out", has({ Rows(rep.trade), Rows(rep.other) }, tostring(CHEAP)), false)
check("moved counts rows past the filters", rep.moved, 5)
check("change text up", ns.ChangeText(0.5), "|cff33ff66+50%|r")
check("change text down", ns.ChangeText(-0.2), "|cffff5555-20%|r")

-- The window opened by itself: the first full scan of this visit, and something moved.
local win = ns.WindowFrame()
check("the window opened after the scan", win ~= nil and win:IsShown(), true)
local function rowsShown()
	local out = {}
	for _, r in ipairs(win.rows) do
		if r.shown then
			out[#out + 1] = r
		end
	end
	return out
end
local function headersShown()
	local out = {}
	for _, h in ipairs(win.headers) do
		if h.shown then
			out[#out + 1] = h.text
		end
	end
	return out
end
local rows = rowsShown()
check("five rows", #rows, 5)
check("trade header first", headersShown()[1], "Trade Materials (2)")
check("other header second", headersShown()[2], "Other Items (3)")
check("first row is copper", rows[1].name.text, "Copper Ore")
check("its change", rows[1].change.text, "|cff33ff66+50%|r")
check("its units listed", rows[1].qty.text, "90")
check("its before price", rows[1].was.text, root.Money(1200))
check("banner names the day compared with", win.banner.text:find("compared with yesterday", 1, true) ~= nil, true)

-- Later scans in the same visit only update the open window; closed, it stays closed.
win:Hide()
Now = Now + 1800
Scan({ [COPPER] = { 2400, 140 }, [LINEN] = { 240, 420 } })
check("a later scan in the same visit does not reopen it", win:IsShown(), false)
check("...but the record has it", House().now.items[COPPER].p, 2400)
FireEvent("AUCTION_HOUSE_CLOSED")
check("closing the house is seen", ns.ahOpen, false)
FireEvent("AUCTION_HOUSE_SHOW")
check("opening the house starts a new visit", ns.ahOpen and not ns.openedThisVisit, true)
Now = Now + 1800
Scan({ [COPPER] = { 2400, 140 }, [LINEN] = { 240, 420 } })
check("the first full scan of the new visit opens it", win:IsShown(), true)

-- Rows: hover, click to search, shift-click to link.
rows = rowsShown()
rows[1].scripts.OnClick(rows[1])
check("a click searches the item in Auctionator", Searches[1] and Searches[1].term, "Copper Ore")
check("...as this addon", Searches[1] and Searches[1].caller, root.ID.addon)
ShiftDown = true
rows[1].scripts.OnClick(rows[1])
ShiftDown = false
check("a shift-click links the item", Linked[1], "item:" .. COPPER)
check("the shift-click did not search", #Searches, 1)
ns.ahOpen = false
rows[1].scripts.OnClick(rows[1])
check("no search while the house is closed", #Searches, 1)
ns.ahOpen = true
GameTooltip:Reset()
rows[1].scripts.OnEnter(rows[1])
check("the tooltip says where 'before' came from", has(GameTooltip.left, "Before (yesterday, 2 scans)"), true)

-- Options: the row cap, common at, the smallest change, the price floor. Back to day 2's prices.
Now = Now + 1800
Day2Scan()
root.SetOption(ns, "rows", 1)
rep = ns.Report()
check("rows per list caps each list", #rep.trade .. "/" .. #rep.other, "1/1")
check("moved still counts every mover", rep.moved, 5)
root.SetOption(ns, "rows", 12)
root.SetOption(ns, "commonQty", 200)
rep = ns.Report()
check("common at 200: only linen (420 listed) is a trade material", Rows(rep.trade), tostring(LINEN))
check("...copper (120 at most) moves to other items", has({ Rows(rep.other) }, tostring(COPPER)), true)
root.SetOption(ns, "commonQty", 40)
root.SetOption(ns, "minChange", 55)
rep = ns.Report()
check("smallest change 55%: no trade material moved that much", #rep.trade, 0)
check("...the essence's 60% stays", Rows(rep.other), tostring(RARE_MAT))
root.SetOption(ns, "minChange", 10)
root.SetOption(ns, "minSilver", 0)
rep = ns.Report()
check("ignore under 0s: rough stone's +100% shows, first", rep.trade[1] and rep.trade[1].id, CHEAP)
root.SetOption(ns, "minSilver", 1)

-- ---------------------------------------------------------------- gaps, look-back, pruning, factions

-- Day 5 (Nov 20): the newest earlier day is day 2, three days back: still compared.
Now = At(2026, 11, 20, 12, 0)
Scan({ [COPPER] = { 1200, 160 } })
rep = ns.Report()
check("a gap of three days still compares", rep.state, "ok")
check("...with day 2", rep.baseDay, day1 + 1)
check("days older than four are pruned", House().days[day1], nil)
-- Day 9: four days after the last scan: too old to compare.
Now = At(2026, 11, 24, 12, 0)
Scan({ [COPPER] = { 5000, 160 } })
check("over three days back: nothing to compare", ns.Report().state, "nobase")
-- Horde has its own record.
Faction = "Horde"
check("another faction starts empty", ns.Report().state, "nodata")
Scan({ [COPPER] = { 5000, 160 } })
check("the horde scan went to the horde record", type(House()), "table")
Faction = "Alliance"
check("the alliance record is untouched", House().now.items[COPPER].p, 5000)

-- A secret value in a result is skipped, not touched.
Now = At(2026, 11, 25, 12, 0)
wipe(Browse)
wipe(BrowseExtra)
Filler(250)
BrowseExtra[1] = { itemKey = { itemID = Secret(), battlePetSpeciesID = 0 }, minPrice = 100, totalQuantity = 1 }
BrowseExtra[2] = { itemKey = { itemID = LINEN, battlePetSpeciesID = 0 }, minPrice = Secret(), totalQuantity = 1 }
BrowseExtra[3] = { itemKey = { itemID = 900399, battlePetSpeciesID = 42 }, minPrice = 100, totalQuantity = 1 }
AuctionatorScan()
check("secrets and pets skipped, the rest recorded", House().now.items[LINEN] == nil and House().now.items[900399] == nil and House().now.items[800001] ~= nil, true)

-- ---------------------------------------------------------------- slash, hub

local out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_MOVERS("print")
end)
check("/kwm print answers", #out > 0, true)
check("hub status names a mover or says nothing moved", type(ns.HubStatus()), "string")
AuctionatorOn(false)
check("hub without Auctionator", ns.HubStatus(), "|cffff5555Needs Auctionator|r")
AuctionatorOn(true)

-- ---------------------------------------------------------------- on/off

capture(function()
	SlashCmdList.KROOLWORLDFOREVER("movers off")
end)
check("/kwf movers off", ns.enabled, false)
check("off: the window closes", win:IsShown(), false)
local before = House().now.at
Now = At(2026, 11, 26, 12, 0)
ns.ahOpen = true
ns.openedThisVisit = false
Scan({ [COPPER] = { 9000, 160 } })
check("off: a scan is not recorded", House().now.at, before)
check("off: the window stays shut", win:IsShown(), false)
out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_MOVERS("")
end)
check("off: /kwm says it is off", has(out, "is off"), true)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("movers on")
end)
check("/kwf movers on", ns.enabled, true)
Scan({ [COPPER] = { 9000, 160 } })
check("on: scans are recorded again", House().now.at, Now)

local mine = 0
for _, err in ipairs(KroolWorldForeverDB.errors or {}) do
	if err.feature == "movers" then
		mine = mine + 1
		realPrint("  caught: " .. tostring(err.where) .. ": " .. tostring(err.message))
	end
end
check("no errors caught in Market Movers", mine, 0)

realPrint(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
