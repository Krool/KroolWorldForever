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

local COPPER, LINEN, PEACE, RARE_MAT, POTION, RECIPE, SWORD, CHEST, BAG, CHEAP, SILK, JUNK, HERB =
	2770, 2589, 2447, 7076, 929, 2553, 900301, 900302, 900303, 900304, 4306, 900305, 2450
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
Items[SILK] = { name = "Silk Cloth", class = 7 }
Items[JUNK] = { name = "Bolt of Junk", class = 15, sell = 500 } -- a vendor pays 5s
Items[HERB] = { name = "Briarthorn", class = 7 }
for i = 1, 300 do
	Items[800000 + i] = { name = "Filler " .. i, class = 15 }
end

local FULL = { searchString = "", sorts = {}, filters = {}, itemClassFilters = {} }

-- One scan: the query (default: the whole house), then the filler plus these
-- { [id] = { price, qty } }, then Auctionator's callback.
local function Scan(list, opts)
	opts = opts or {}
	wipe(Browse)
	wipe(BrowseExtra)
	Filler(opts.filler or 250)
	for id, e in pairs(list) do
		Browse[id] = e
	end
	FullBrowse = opts.full ~= false
	C_AuctionHouse.SendBrowseQuery(opts.query or FULL)
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

local function pct(x)
	return math.floor(x * 100 + 0.5)
end

-- ---------------------------------------------------------------- lifecycle

FireEvent("ADDON_LOADED", "KroolWorldForever")
local db = KroolWorldForeverDB.features.movers
check("feature slice created", type(db), "table")
check("on by default", db.enabled, true)
check("opens after a full scan by default", db.openAfterScan, true)
check("auction house button by default", db.showButton, true)
check("common at 40 by default", db.commonQty, 40)
check("ignore under 10 listed by default", db.minListed, 10)
check("smallest change 10% by default", db.minChange, 10)
check("bargain at 30% by default", db.bargain, 30)
check("ignore under 1s by default", db.minSilver, 1)
check("8 rows by default", db.rows, 8)
check("record made", type(db.ah), "table")
check("vendor prices table made", type(db.vendor), "table")
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("enabled after login", ns.enabled, true)
check("hooked to Auctionator's scans", ns.auctionHooked, true)
check("watching the browse queries", ns.queryHooked, true)

-- ---------------------------------------------------------------- text

check("coin: copper only", ns.Coin(77), "|cffeda55f77c|r")
check("coin: silver and copper", ns.Coin(2871), "|cffc7c7cf28s|r |cffeda55f71c|r")
check("coin: no zero copper", ns.Coin(1200), "|cffc7c7cf12s|r")
check("coin: gold drops copper", ns.Coin(11369), "|cffffd7001g|r |cffc7c7cf13s|r")
check("coin: no zero silver", ns.Coin(10069), "|cffffd7001g|r")
check("coin: 100g and over is gold only", ns.Coin(2205000), "|cffffd700220g|r")
check("change text up", ns.ChangeText(0.5), "|cff33ff66+50%|r")
check("change text down", ns.ChangeText(-0.2), "|cffff5555-20%|r")
check("change text flat", ns.ChangeText(0.001), "|cffaaaaaa0%|r")
check("a huge rise reads as times, not percent", ns.ChangeText(35.52), "|cff33ff6637x|r")
check("...with a decimal under ten times", ns.ChangeText(5.5), "|cff33ff666.5x|r")

-- ---------------------------------------------------------------- what is a full scan

check("an empty query is the whole house", ns.IsFullQuery(FULL), true)
check("search text is a search", ns.IsFullQuery({ searchString = "ore", filters = {}, itemClassFilters = {} }), false)
check("a class filter is a search", ns.IsFullQuery({ searchString = "", filters = {}, itemClassFilters = { { classID = 7 } } }), false)
check("a filter is a search", ns.IsFullQuery({ searchString = "", filters = { 4 }, itemClassFilters = {} }), false)
check("a level range is a search", ns.IsFullQuery({ searchString = "", minLevel = 10 }), false)
check("a secret query is not trusted", ns.IsFullQuery({ searchString = Secret() }), false)

-- ---------------------------------------------------------------- no data, first day

check("no scan yet: report says so", ns.Report().state, "nodata")
check("hub: scan to start", ns.HubStatus():find("Scan the auction house", 1, true) ~= nil, true)

-- A broad search before any scan: 250 complete results, but it was a search.
Now = At(2026, 11, 16, 9, 0)
Scan({ [COPPER] = { 1, 1 } }, { query = { searchString = "", filters = {}, itemClassFilters = { { classID = 7 } } } })
check("a broad search is not a scan, whatever its size", ns.Report().state, "nodata")

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
	[SILK] = { 1000, 200 },
	[JUNK] = { 800, 20 },
})
local day1 = ns.Day()
check("a full scan is recorded", type(House().days[day1]), "table")
check("copper recorded", House().days[day1][COPPER].n, 1)
check("gear is not recorded (weapon)", House().days[day1][SWORD], nil)
check("gear is not recorded (armor)", House().days[day1][CHEST], nil)
check("bags are not recorded", House().days[day1][BAG], nil)
check("first day: nothing to compare yet", ns.Report().state, "nobase")
check("hub: first comparison tomorrow", ns.HubStatus():find("tomorrow", 1, true) ~= nil, true)
check("vendor prices learned after the scan", db.vendor[JUNK], 500)
check("...and none where a vendor pays nothing", db.vendor[COPPER], 0)

-- The same results call back again (a price refresh), minutes later: already recorded.
Now = Now + 600
AuctionatorScan()
check("the same browse is not recorded twice", House().days[day1][COPPER].n, 1)
-- A fresh full scan seconds after the last one is the same scan.
Now = Now + 20
C_AuctionHouse.SendBrowseQuery(FULL)
AuctionatorScan()
Now = Now + 20
C_AuctionHouse.SendBrowseQuery(FULL)
AuctionatorScan()
check("two scans within a minute count once", House().days[day1][COPPER].n, 2)

Now = At(2026, 11, 16, 18, 0)
Scan({
	[COPPER] = { 1600, 100 },
	[LINEN] = { 300, 380 },
	[PEACE] = { 500, 110 },
	[RARE_MAT] = { 50000, 5 },
	[POTION] = { 2000, 25 },
	[RECIPE] = { 90000, 1 },
	[CHEAP] = { 40, 280 },
	[SILK] = { 1000, 180 },
	[JUNK] = { 800, 20 },
})
check("three scans on day 1", House().days[day1][COPPER].n, 3)
check("day 1 copper sum", House().days[day1][COPPER].s, 3600)
check("day 1 copper most listed", House().days[day1][COPPER].q, 120)

-- A search on day 1: recorded nowhere.
Now = Now + 300
Scan({ [COPPER] = { 1, 1 } }, { filler = 0, query = { searchString = "Copper Ore" } })
check("a search is not a full scan", House().days[day1][COPPER].n, 3)
check("a search leaves 'now' alone", House().now.items[COPPER].p, 1600)

-- A full browse still paging: wait for the rest.
Now = Now + 300
Scan({ [COPPER] = { 1, 1 } }, { full = false })
check("a browse still paging is not recorded", House().days[day1][COPPER].n, 3)
FullBrowse = true

-- ---------------------------------------------------------------- day 2: the report

-- In the bags: copper, linen, and a sword the house has no price for.
BagSizes[0] = 16
Put(0, 1, { id = COPPER, count = 10 })
Put(0, 2, { id = COPPER, count = 6 })
Put(0, 3, { id = LINEN, count = 40 })
Put(0, 4, { id = SWORD, count = 1 })

Now = At(2026, 11, 17, 9, 0)
ns.ahOpen = true -- the auction house is open (AUCTION_HOUSE_SHOW, below, tests the event)
ns.openedThisVisit = false
local function Day2Scan()
	Scan({
		[COPPER] = { 1800, 90 }, -- +50% on the day-1 average of 1200
		[LINEN] = { 240, 420 }, -- -20%
		[PEACE] = { 520, 110 }, -- +4%: under the smallest change
		[RARE_MAT] = { 80000, 4 }, -- +60%, but a handful listed: left out
		[POTION] = { 3000, 20 }, -- +50%, 30 usually listed: Other
		[RECIPE] = { 45000, 1 }, -- -50%, one listed: left out
		[CHEAP] = { 80, 300 }, -- +100%, but under 1s both days
		[SILK] = { 500, 200 }, -- -50%: falling, and a bargain
		[JUNK] = { 300, 20 }, -- -62%, and under the 5s a vendor pays
	})
end
Day2Scan()
local rep = ns.Report()
check("day 2: report ready", rep.state, "ok")
check("usual rests on one day", rep.days, 1)
check("materials rising: copper", Rows(rep.tradeUp), tostring(COPPER))
check("materials falling: silk, then linen", Rows(rep.tradeDown), SILK .. "," .. LINEN)
check("other rising: the potion", Rows(rep.otherUp), tostring(POTION))
check("other falling: the junk", Rows(rep.otherDown), tostring(JUNK))
check("copper's change is +50%", pct(rep.tradeUp[1].change), 50)
check("copper's usual is the day-1 average", rep.tradeUp[1].usual, 1200)
check("copper's usual units", rep.tradeUp[1].usualQty, 120)
check("copper's day came from 3 scans", rep.tradeUp[1].series[1].n, 3)
check("copper is marked as held: 16 in the bags", rep.tradeUp[1].bags, 16)
check("linen's change is -20%", pct(rep.tradeDown[2].change), -20)
local all = { Rows(rep.tradeUp), Rows(rep.tradeDown), Rows(rep.otherUp), Rows(rep.otherDown) }
check("peacebloom's 4% is left out", has(all, tostring(PEACE)), false)
check("rough stone under 1s both days is left out", has(all, tostring(CHEAP)), false)
check("a handful of essence is not a market move", has(all, tostring(RARE_MAT)), false)
check("one recipe is not a market move", has(all, tostring(RECIPE)), false)
check("moved counts the four lists", rep.moved, 5)
check("under the vendor price: the junk", Rows(rep.vendor), tostring(JUNK))
check("...a vendor pays 5s", rep.vendor[1].vendor, 500)
check("far under usual: the junk, then silk", Rows(rep.cheap), JUNK .. "," .. SILK)
check("three bargains", rep.bargains, 3)
check("my bags: copper (above usual) before linen (below)", Rows(rep.bags), COPPER .. "," .. LINEN)
check("the biggest mover is a material: silk's halving beats copper's +50%", ns.TopMover(rep).id, SILK)
check("advice: copper is a good time to sell", ns.Advice(rep.bags[1]):find("good time to sell", 1, true) ~= nil, true)
check("advice: linen is better kept", ns.Advice(rep.bags[2]):find("better to wait", 1, true) ~= nil, true)
check("hub: movers and bargains", ns.HubStatus():find("5 moved, 3 bargains", 1, true) ~= nil, true)

-- A halving and a doubling are the same size of move: neither outranks the other by its percent.
Items[HERB] = { name = "Briarthorn", class = 7 }
House().days[day1][HERB] = { s = 1000, n = 1, q = 100 }
House().now.items[HERB] = { p = 1900, q = 100 } -- +90%: less than silk's halving, more than copper
rep = ns.Report()
check("a +90% rise ranks under a halving", ns.TopMover(rep).id, SILK)
check("...and over a +50% rise", Rows(rep.tradeUp), HERB .. "," .. COPPER)
House().days[day1][HERB] = nil
House().now.items[HERB] = nil

-- ---------------------------------------------------------------- the window

-- It opened by itself: the first full scan of this visit, and something moved.
local win = ns.WindowFrame()
check("the window opened after the scan", win ~= nil and win:IsShown(), true)
check("with no auction house frame to sit beside: the middle", ns.placed, "center")
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
local function tab(i)
	win.tabs[i].scripts.OnClick(win.tabs[i])
end
local rows = rowsShown()
check("materials tab first", win.tab, "trade")
check("three rows", #rows, 3)
check("rising header first", headersShown()[1], "Rising (1)")
check("falling header second", headersShown()[2], "Falling (2)")
check("first row is copper, with the 16 held", rows[1].name.text, "Copper Ore |cff88ccffx16|r")
check("its change", rows[1].change.text, "|cff33ff66+50%|r")
check("its units listed", rows[1].last.text, "90")
check("its usual price, short", rows[1].usual.text, ns.Coin(1200))
check("its trend: the day before and now", rows[1].trendPoints, 2)
check("banner: the house and the scan", win.banner.text:find("Alliance house, last scan today 09:00", 1, true) ~= nil, true)
check("the footer says what a click does", win.note.text:find("search it in Auctionator", 1, true) ~= nil, true)
check("tab label counts its rows", win.tabs[1].count, 3)
check("the bargains tab counts three", win.tabs[3].count, 3)

tab(2)
rows = rowsShown()
check("other tab: potion rising, junk falling", rows[1].itemID .. "," .. rows[2].itemID, POTION .. "," .. JUNK)
tab(3)
rows = rowsShown()
check("bargains tab: three rows", #rows, 3)
check("vendor header", headersShown()[1], "Under the vendor price: vendor pays, price, gain (1)")
check("usual header", headersShown()[2], "Far under the usual price (2)")
check("the vendor row shows what the vendor pays", rows[1].usual.text, ns.Coin(500))
check("...and the gain on each", rows[1].change.text, "|cff33ff66+|r" .. ns.Coin(200))
GameTooltip:Reset()
rows[1].scripts.OnEnter(rows[1])
check("its tooltip names the vendor price", has(GameTooltip.left, "Vendor pays"), true)
check("...and warns that only the cheapest is sure", has(GameTooltip.lines, "Only the cheapest listing"), true)
tab(4)
rows = rowsShown()
check("my bags tab: two rows", #rows, 2)
check("the last column is the units held", rows[1].last.text, "|cff88ccffx16|r")
check("its title says so", win.cols.last.text, "Bags")
GameTooltip:Reset()
rows[1].scripts.OnEnter(rows[1])
check("the tooltip says where usual came from", has(GameTooltip.left, "Usual (1 day)"), true)
check("...lists the day", has(GameTooltip.left, "yesterday, 3 scans, 120 listed"), true)
check("...and what the bags are worth", has(GameTooltip.left, "In your bags"), true)
check("the open tab is remembered", db.tab, "bags")
tab(1)

-- Later scans in the same visit only update the open window; closed, it stays closed.
win:Hide()
Now = Now + 1800
Scan({ [COPPER] = { 2400, 140 }, [LINEN] = { 240, 420 } })
check("a later scan in the same visit does not reopen it", win:IsShown(), false)
check("...but the record has it", House().now.items[COPPER].p, 2400)
FireEvent("AUCTION_HOUSE_CLOSED")
check("closing the house is seen", ns.ahOpen, false)

-- Beside the auction house, not over it.
AuctionHouseFrame = CreateFrame("Frame", "AuctionHouseFrame")
AuctionHouseFrame.GetEffectiveScale = function()
	return 1
end
local ahLeft, ahRight, screenW = 16, 906, 1600
AuctionHouseFrame.GetLeft = function()
	return ahLeft
end
AuctionHouseFrame.GetRight = function()
	return ahRight
end
UIParent.GetWidth = function()
	return screenW
end
UIParent.GetEffectiveScale = function()
	return 1
end
win.GetEffectiveScale = function()
	return 1
end
FireEvent("AUCTION_HOUSE_SHOW")
check("opening the house starts a new visit", ns.ahOpen and not ns.openedThisVisit, true)
check("the button is on the auction house", ns.ahButton ~= nil and ns.ahButton:IsShown(), true)
check("...it belongs to the auction house frame", ns.ahButton.parent, AuctionHouseFrame)
check("...and counts movers and bargains", ns.ahButton.text, "Movers: 2")
Now = Now + 1800
Scan({ [COPPER] = { 2400, 140 }, [LINEN] = { 240, 420 }, [JUNK] = { 300, 20 } })
check("the first full scan of the new visit opens it", win:IsShown(), true)
check("with room on the right: beside the house", ns.placed, "right")
check("the button follows the scan", ns.ahButton.text, "Movers: 3, 2 bargains")
ns.ahButton.scripts.OnClick(ns.ahButton)
check("the button closes the open window", win:IsShown(), false)
screenW, ahLeft, ahRight = 1500, 560, 1450
ns.ahButton.scripts.OnClick(ns.ahButton)
check("...and opens it again", win:IsShown(), true)
check("no room on the right: on the left", ns.placed, "left")
win:Hide()
ahLeft = 100
ns.OnOpen()
check("no room on either side: the screen's right edge", ns.placed, "edge")
-- Dragging it sets its place from then on.
win.GetPoint = function()
	return "TOPLEFT", UIParent, "TOPLEFT", 50, -60
end
win.scripts.OnDragStop(win)
check("a drag is remembered", db.pos and db.pos[3], 50)
win:Hide()
ns.OnOpen()
check("...and used next time", ns.placed, "saved")
local out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_MOVERS("reset")
end)
check("/kwm reset forgets the drag", db.pos, nil)
check("...and says so", has(out, "beside the auction house"), true)

-- Opened by the player, it stays when the house closes; opened by a scan, it leaves with it.
FireEvent("AUCTION_HOUSE_CLOSED")
check("opened by hand: stays open after the house closes", win:IsShown(), true)
win:Hide()
FireEvent("AUCTION_HOUSE_SHOW")
Now = Now + 1800
Scan({ [COPPER] = { 2400, 140 }, [LINEN] = { 240, 420 } })
check("opened by the scan", win:IsShown() and ns.autoOpened, true)
FireEvent("AUCTION_HOUSE_CLOSED")
check("...it closes with the house", win:IsShown(), false)
root.SetOption(ns, "showButton", false)
check("button option off: hidden", ns.ahButton:IsShown(), false)
root.SetOption(ns, "showButton", true)
check("button option on: back", ns.ahButton:IsShown(), true)
FireEvent("AUCTION_HOUSE_SHOW")

-- Rows: click to search, shift-click to link.
ns.OnOpen("trade")
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
SlashCmdList.KROOLWORLDFOREVER_MOVERS("bargains")
check("/kwm bargains opens that tab", win.tab, "deals")
SlashCmdList.KROOLWORLDFOREVER_MOVERS("bags")
check("/kwm bags opens that tab", win.tab, "bags")

-- Options. Back to day 2's prices.
Now = Now + 1800
Day2Scan()
root.SetOption(ns, "rows", 4)
House().days[day1][HERB] = { s = 1000, n = 1, q = 100 }
House().now.items[HERB] = { p = 1900, q = 100 }
for i = 1, 5 do -- five more risers than the cap
	Items[900400 + i] = { name = "Riser " .. i, class = 7 }
	House().days[day1][900400 + i] = { s = 1000, n = 1, q = 100 }
	House().now.items[900400 + i] = { p = 1200 + i, q = 100 }
end
rep = ns.Report()
check("rows per list caps a list", #rep.tradeUp, 4)
check("...total still counts every mover", rep.total.tradeUp, 7)
ns.OnOpen("trade")
check("the header says how many of how many", headersShown()[1], "Rising (4 of 7)")
for i = 1, 5 do
	House().days[day1][900400 + i] = nil
	House().now.items[900400 + i] = nil
end
House().days[day1][HERB] = nil
House().now.items[HERB] = nil
root.SetOption(ns, "rows", 8)
root.SetOption(ns, "commonQty", 200)
rep = ns.Report()
check("common at 200: linen (420) and silk (200) are materials", Rows(rep.tradeDown), SILK .. "," .. LINEN)
check("...copper (120 at most) moves to other", Rows(rep.otherUp), POTION .. "," .. COPPER)
root.SetOption(ns, "commonQty", 40)
root.SetOption(ns, "minListed", 5)
rep = ns.Report()
check("ignore under 5 listed: the essence (6 usually) shows", has({ Rows(rep.otherUp) }, tostring(RARE_MAT)), true)
root.SetOption(ns, "minListed", 10)
root.SetOption(ns, "minChange", 55)
rep = ns.Report()
check("smallest change 55%: no material moved that much", #rep.tradeUp + #rep.tradeDown, 0)
check("...the junk's 62% stays", Rows(rep.otherDown), tostring(JUNK))
root.SetOption(ns, "minChange", 10)
root.SetOption(ns, "bargain", 60)
check("bargain at 60%: silk's 50% is no bargain", Rows(ns.Report().cheap), tostring(JUNK))
root.SetOption(ns, "bargain", 30)
root.SetOption(ns, "minSilver", 0)
rep = ns.Report()
check("ignore under 0s: rough stone's doubling shows, first", rep.tradeUp[1] and rep.tradeUp[1].id, CHEAP)
root.SetOption(ns, "minSilver", 1)

-- ---------------------------------------------------------------- usual over days, pruning, factions

-- Horde has its own record. Three days: 1s, a 10s spike, 1s 20c. Usual is the middle one.
Faction = "Horde"
check("another faction starts empty", ns.Report().state, "nodata")
Now = At(2026, 11, 20, 12, 0)
Scan({ [HERB] = { 100, 100 } })
Now = At(2026, 11, 21, 12, 0)
Scan({ [HERB] = { 1000, 3 } })
Now = At(2026, 11, 22, 12, 0)
Scan({ [HERB] = { 120, 90 } })
Now = At(2026, 11, 23, 12, 0)
Scan({ [HERB] = { 60, 100 } })
local usual, usualQty, series = ns.Usual(House(), HERB, ns.Day())
check("usual is the median day: the spike does not move it", usual, 120)
check("usual units is the median too", usualQty, 90)
check("three days behind it, oldest first", #series .. ":" .. math.floor(series[1].p), "3:100")
rep = ns.Report()
check("half of usual: falling", Rows(rep.tradeDown), tostring(HERB))
check("the report rests on three days", rep.days, 3)
local printed = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_MOVERS("print")
end)
check("/kwm print lists the falling material", has(printed, "Materials falling") and has(printed, "Briarthorn"), true)
Faction = "Alliance"
check("the alliance record is untouched", House().now.items[COPPER].p, 1800)

-- A week later (Nov 24): day 2 is seven days back: still compared.
Now = At(2026, 11, 24, 12, 0)
Scan({ [COPPER] = { 1200, 160 } })
check("a gap of a week still compares", ns.Report().state, "ok")
check("two weeks are kept", House().days[day1] ~= nil, true)
Now = At(2026, 11, 30, 12, 0)
Scan({ [COPPER] = { 1200, 160 } })
check("days two weeks old are pruned", House().days[day1], nil)
Now = At(2026, 12, 9, 12, 0)
Scan({ [COPPER] = { 5000, 160 } })
check("over a week back: nothing to compare", ns.Report().state, "nobase")

-- A secret value in a result is skipped, not touched.
Now = At(2026, 12, 10, 12, 0)
wipe(Browse)
wipe(BrowseExtra)
Filler(250)
BrowseExtra[1] = { itemKey = { itemID = Secret(), battlePetSpeciesID = 0 }, minPrice = 100, totalQuantity = 1 }
BrowseExtra[2] = { itemKey = { itemID = LINEN, battlePetSpeciesID = 0 }, minPrice = Secret(), totalQuantity = 1 }
BrowseExtra[3] = { itemKey = { itemID = 900399, battlePetSpeciesID = 42 }, minPrice = 100, totalQuantity = 1 }
C_AuctionHouse.SendBrowseQuery(FULL)
AuctionatorScan()
check("secrets and pets skipped, the rest recorded", House().now.items[LINEN] == nil and House().now.items[900399] == nil and House().now.items[800001] ~= nil, true)

-- A small house: a full scan of 50 items is still a full scan.
Now = At(2026, 12, 11, 12, 0)
Scan({ [COPPER] = { 5000, 160 } }, { filler = 50 })
check("a small house's full scan is recorded", House().now.at, Now)

-- ---------------------------------------------------------------- slash, hub

out = capture(function()
	SlashCmdList.KROOLWORLDFOREVER_MOVERS("print")
end)
check("/kwm print answers", #out > 0, true)
check("hub status is text", type(ns.HubStatus()), "string")
AuctionatorOn(false)
check("hub without Auctionator", ns.HubStatus(), "|cffff5555Needs Auctionator|r")
AuctionatorOn(true)

-- ---------------------------------------------------------------- on/off

win:Show()
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("movers off")
end)
check("/kwf movers off", ns.enabled, false)
check("off: the window closes", win:IsShown(), false)
check("off: the button hides", ns.ahButton:IsShown(), false)
local before = House().now.at
Now = At(2026, 12, 12, 12, 0)
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
