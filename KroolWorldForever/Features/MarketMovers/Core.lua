-- Market Movers: after Auctionator scans the auction house, what is priced unusually. Four views:
-- trade materials that sell in quantity (rising and falling), other items (rising and falling),
-- bargains (listed under the vendor price, or far under the usual price), and the items in your
-- bags against their usual price. Gear is left out.
--
-- Auctionator's own price history is internal (its API v1 has no history and no item list; see
-- docs/research/data-sources/prices_and_addon_api.md), so this keeps its own. Auctionator's scan is
-- a browse of the whole house with an empty query; when it finishes it calls back
-- (root.OnAuctionPrices), and the client's browse results still hold every listed item with its
-- lowest price and the units listed (C_AuctionHouse.GetBrowseResults, Blizzard's API). Each full
-- scan is added to that day's record per item: the sum and count of the scans' lowest prices, and
-- the most units seen.
--
-- "Now" is the latest full scan. "Usual" is the median of the earlier days' averages, up to a week
-- back: one odd day does not move it. A browse is a full scan when the query that made it was empty
-- and unfiltered (a hook on C_AuctionHouse.SendBrowseQuery sees each query); a search is never
-- recorded, since averaging it in would weigh the items you search for.
--
-- Records are per faction (Alliance and Horde houses list different things) and keep two weeks.
-- Read only: it never buys, bids, posts or cancels.

local _, root = ...
local ns = root.Feature("movers")

ns.FULL_MIN = 200 -- without the query hook: a browse this large is a full scan, not a search
ns.FULL_SHARE = 0.4 -- ...and at least this share of the last full scan's size
ns.KEEP_DAYS = 14
ns.LOOKBACK = 7 -- "usual" is the median over at most this many earlier days
ns.SAME_SCAN = 60 -- seconds: a second callback this soon after a recorded scan is the same scan
ns.TRADE_CLASS = 7 -- Enum.ItemClass.Tradegoods
-- Gear and the like: Container 1, Weapon 2, Armor 4, Quiver 11, Battlepet 17.
ns.GEAR_CLASS = { [1] = true, [2] = true, [4] = true, [11] = true, [17] = true }
ns.BAG_ROWS = 40 -- the My Bags list shows at most this many
ns.TIMES = 5 -- a rise this many times the usual price or more reads "12x", not "+1100%"

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- -------------------------------------------------------------------- days

-- Local days since 2020-01-01, like Auctionator's scan day (local midnight to midnight).
local day0
function ns.Day(t)
	if not day0 then
		day0 = time({ year = 2020, month = 1, day = 1, hour = 0 })
	end
	return math.floor(((t or time()) - day0) / 86400)
end

-- Whether the clock calls exist (they do in the client; some test clients load the bundle without them).
function ns.HasClock()
	return type(time) == "function" and type(date) == "function"
end

-- The noon of a day number, for date().
function ns.DayTime(d)
	ns.Day() -- sets day0
	return day0 + d * 86400 + 43200
end

function ns.DayText(d)
	local today = ns.Day()
	if d == today then
		return "today"
	elseif d == today - 1 then
		return "yesterday"
	end
	return date("%b %d", ns.DayTime(d))
end

-- -------------------------------------------------------------------- items

-- The item's class from the client's own item table (no server query), or nil.
local classCache = {}
function ns.ClassOf(id)
	local c = classCache[id]
	if c == nil then
		local fn = C_Item and C_Item.GetItemInfoInstant
		local ok, _, _, _, _, _, classID = pcall(fn, id)
		c = ok and type(classID) == "number" and classID or false
		classCache[id] = c
	end
	return c or nil
end

function ns.IsGear(id)
	local c = ns.ClassOf(id)
	return c ~= nil and ns.GEAR_CLASS[c] == true
end

-- How many of each item the bags hold: { [itemID] = units }.
function ns.BagCounts()
	local out = {}
	local C = C_Container
	if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then
		return out
	end
	local last = (type(NUM_TOTAL_EQUIPPED_BAG_SLOTS) == "number" and NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4)
	for bag = 0, last do
		local ok, n = pcall(C.GetContainerNumSlots, bag)
		n = ok and not Secret(n) and type(n) == "number" and n or 0
		for slot = 1, n do
			local ok2, info = pcall(C.GetContainerItemInfo, bag, slot)
			if ok2 and type(info) == "table" then
				local id, count = info.itemID, info.stackCount
				if not Secret(id) and not Secret(count) and type(id) == "number" then
					out[id] = (out[id] or 0) + (type(count) == "number" and count or 1)
				end
			end
		end
	end
	return out
end

-- -------------------------------------------------------------------- the record

function ns.Faction()
	local ok, f = pcall(UnitFactionGroup, "player")
	return ok and type(f) == "string" and f ~= "" and f or "Neutral"
end

local function House(faction)
	local ah = ns.db.ah
	local h = ah[faction]
	if type(h) ~= "table" then
		h = { days = {} }
		ah[faction] = h
	end
	h.days = type(h.days) == "table" and h.days or {}
	return h
end
ns.House = House

-- Drops days older than KEEP_DAYS, in every house.
function ns.Prune(today)
	today = today or ns.Day()
	for _, h in pairs(ns.db.ah) do
		if type(h) == "table" and type(h.days) == "table" then
			for d in pairs(h.days) do
				if type(d) ~= "number" or d <= today - ns.KEEP_DAYS then
					h.days[d] = nil
				end
			end
		end
	end
end

-- The browse results, by item id: the lowest price and the units listed. Pets, gear, nothing
-- listed and anything secret are left out. Returns the table and how many results there were.
function ns.ReadBrowse()
	local ok, results = pcall(C_AuctionHouse and C_AuctionHouse.GetBrowseResults)
	if not ok or type(results) ~= "table" then
		return nil, 0
	end
	local items, n = {}, 0
	for _, r in ipairs(results) do
		n = n + 1
		if type(r) == "table" then
			local key = r.itemKey
			local id, price, qty = type(key) == "table" and key.itemID, r.minPrice, r.totalQuantity
			local pet = type(key) == "table" and key.battlePetSpeciesID
			if
				not Secret(id)
				and not Secret(price)
				and not Secret(qty)
				and not Secret(pet)
				and type(id) == "number"
				and type(price) == "number"
				and type(qty) == "number"
				and price > 0
				and qty > 0
				and not (type(pet) == "number" and pet > 0)
				and not ns.IsGear(id)
			then
				local e = items[id]
				if e then -- one item listed under two keys: its cheapest, all its units
					e.p = math.min(e.p, price)
					e.q = e.q + qty
				else
					items[id] = { p = price, q = qty }
				end
			end
		end
	end
	return items, n
end

-- Whether a browse query asks for the whole house: no search text, no filters, no level range.
function ns.IsFullQuery(q)
	if type(q) ~= "table" then
		return false
	end
	local text, classes, filters, lo, hi = q.searchString, q.itemClassFilters, q.filters, q.minLevel, q.maxLevel
	if Secret(text) or Secret(classes) or Secret(filters) or Secret(lo) or Secret(hi) then
		return false
	end
	return (text == nil or text == "")
		and (type(classes) ~= "table" or next(classes) == nil)
		and (type(filters) ~= "table" or next(filters) == nil)
		and (lo == nil or lo == 0)
		and (hi == nil or hi == 0)
end

-- Watches the browse queries, so a scan is told from a search by what was asked, not by size.
-- ns.lastQuery: "full" (the whole house was asked for), "search", or "recorded" (that full browse
-- is already in the record).
function ns.WatchQueries()
	if ns.queryHooked or type(hooksecurefunc) ~= "function" then
		return
	end
	if not (type(C_AuctionHouse) == "table" and type(C_AuctionHouse.SendBrowseQuery) == "function") then
		return
	end
	ns.queryHooked = pcall(hooksecurefunc, C_AuctionHouse, "SendBrowseQuery", function(q)
		local ok, full = pcall(ns.IsFullQuery, q)
		ns.lastQuery = ok and full and "full" or "search"
	end)
end

-- Whether the browse results in the client are a full scan not yet recorded.
function ns.IsFullScan(count, h)
	local ok, full = pcall(C_AuctionHouse and C_AuctionHouse.HasFullBrowseResults)
	if ok and full == false then
		return false -- still paging: Auctionator calls back again when it is done
	end
	if ns.queryHooked then
		return ns.lastQuery == "full" and count > 0
	end
	-- No hook (a client without hooksecurefunc): judge by size.
	if count < ns.FULL_MIN then
		return false
	end
	local last = h and h.size
	return not (type(last) == "number" and count < last * ns.FULL_SHARE)
end

-- Records the browse results when they are a full scan. Returns true when it recorded one.
function ns.Record(now)
	now = now or time()
	local items, count = ns.ReadBrowse()
	if not items then
		return false
	end
	local h = House(ns.Faction())
	if not ns.IsFullScan(count, h) then
		return false
	end
	if type(h.now) == "table" and type(h.now.at) == "number" and now - h.now.at < ns.SAME_SCAN then
		return false
	end
	local today = ns.Day(now)
	local day = h.days[today]
	if type(day) ~= "table" then
		day = {}
		h.days[today] = day
	end
	for id, e in pairs(items) do
		local d = day[id]
		if d then
			d.s, d.n, d.q = d.s + e.p, d.n + 1, math.max(d.q, e.q)
		else
			day[id] = { s = e.p, n = 1, q = e.q }
		end
	end
	h.now = { at = now, items = items }
	h.size = math.max(count, type(h.size) == "number" and h.size * 0.8 or 0) -- never shrinks fast
	if ns.lastQuery == "full" then
		ns.lastQuery = "recorded"
	end
	ns.Prune(today)
	return true
end

-- -------------------------------------------------------------------- vendor prices

-- What a vendor pays for each item (0: nothing), learned from the client's item data a few at a
-- time after a scan and kept, since it never changes. done() runs when the pass ends.
local CHUNK, PASSES = 60, 3
function ns.LearnVendor(items, done)
	if ns.learning or type(items) ~= "table" then
		return
	end
	local known = ns.db.vendor
	local queue = {}
	for id in pairs(items) do
		if known[id] == nil then
			queue[#queue + 1] = id
		end
	end
	if #queue == 0 then
		return
	end
	ns.learning = true
	local i, pass, retry, learned = 1, 1, {}, 0
	local function Step()
		for _ = 1, CHUNK do
			local id = queue[i]
			if not id then
				break
			end
			i = i + 1
			local ok, name, _, _, _, _, _, _, _, _, _, sell = pcall(C_Item.GetItemInfo, id)
			if ok and name ~= nil and not Secret(name) and not Secret(sell) then
				known[id] = type(sell) == "number" and sell > 0 and sell or 0
				learned = learned + 1
			else
				retry[#retry + 1] = id -- not loaded yet: the call asked the server for it
			end
		end
		if i <= #queue then
			C_Timer.After(0.1, Step)
		elseif #retry > 0 and pass < PASSES then
			queue, retry, i, pass = retry, {}, 1, pass + 1
			C_Timer.After(2, Step)
		else
			ns.learning = false
			if done and learned > 0 then
				pcall(done)
			end
		end
	end
	Step()
end

-- -------------------------------------------------------------------- the report

local function Median(list)
	local t = {}
	for i, v in ipairs(list) do
		t[i] = v
	end
	table.sort(t)
	local n = #t
	if n % 2 == 1 then
		return t[(n + 1) / 2]
	end
	return (t[n / 2] + t[n / 2 + 1]) / 2
end

-- The item's usual price and units from the days before nowDay: the medians of each day's average
-- price and most units. Also the days themselves, oldest first: { d, p, n, q }. nil with no day.
function ns.Usual(h, id, nowDay)
	local prices, qtys, series = {}, {}, {}
	for d = nowDay - ns.LOOKBACK, nowDay - 1 do
		local day = h.days[d]
		local e = type(day) == "table" and day[id]
		if type(e) == "table" and type(e.n) == "number" and e.n > 0 and type(e.s) == "number" and e.s > 0 then
			local avg = e.s / e.n
			prices[#prices + 1] = avg
			qtys[#qtys + 1] = e.q or 0
			series[#series + 1] = { d = d, p = avg, n = e.n, q = e.q or 0 }
		end
	end
	if #prices == 0 then
		return nil
	end
	return Median(prices), Median(qtys), series
end

-- The lists for this faction's house. Returns a report:
--   { state = "nodata" | "nobase" | "ok", at = time of the scan, days = most days behind a usual price,
--     tradeUp, tradeDown, otherUp, otherDown, vendor, cheap, bags = { row, ... },
--     total = { [list] = rows before the row cap }, moved = movers in all four lists,
--     bargains = vendor + cheap rows }
-- row = { id, now, usual, ratio, change, qty, usualQty, days, series, trade, vendor, bags }
-- (usual, ratio, change, usualQty and series are nil for a vendor row with no history.)
local LISTS = { "tradeUp", "tradeDown", "otherUp", "otherDown", "vendor", "cheap", "bags" }
ns.LISTS = LISTS
function ns.Report(faction)
	local rep = { state = "nodata", total = {}, moved = 0, bargains = 0, days = 0 }
	for _, k in ipairs(LISTS) do
		rep[k], rep.total[k] = {}, 0
	end
	local h = ns.db.ah[faction or ns.Faction()]
	if type(h) ~= "table" or type(h.now) ~= "table" or type(h.now.items) ~= "table" then
		return rep
	end
	rep.at = h.now.at
	local nowDay = ns.Day(h.now.at)
	local floor = (tonumber(ns.db.minSilver) or 0) * 100
	local minChange = (tonumber(ns.db.minChange) or 0) / 100
	local bargain = (tonumber(ns.db.bargain) or 30) / 100
	local common = tonumber(ns.db.commonQty) or 0
	local minListed = tonumber(ns.db.minListed) or 0
	local vendorOf = type(ns.db.vendor) == "table" and ns.db.vendor or {}
	local bags = ns.BagCounts()
	local based = false

	for id, cur in pairs(h.now.items) do
		local usual, usualQty, series = ns.Usual(h, id, nowDay)
		local vendor = vendorOf[id]
		vendor = type(vendor) == "number" and vendor > 0 and vendor or nil
		local row
		local function Row()
			if not row then
				local ratio = usual and cur.p / usual or nil
				row = {
					id = id,
					now = cur.p,
					usual = usual,
					ratio = ratio,
					change = ratio and ratio - 1 or nil,
					qty = cur.q,
					usualQty = usualQty,
					days = series and #series or 0,
					series = series,
					vendor = vendor,
					bags = bags[id],
				}
			end
			return row
		end
		if vendor and vendor > cur.p then
			table.insert(rep.vendor, Row())
		end
		if usual then
			based = true
			rep.days = math.max(rep.days, #series)
			local change = cur.p / usual - 1
			local liquid = math.max(cur.q, usualQty)
			local priced = cur.p >= floor or usual >= floor
			if priced and math.abs(change) >= minChange then
				local isTrade = ns.ClassOf(id) == ns.TRADE_CLASS and liquid >= common
				if isTrade or liquid >= minListed then
					local r = Row()
					r.trade = isTrade
					table.insert(rep[(isTrade and "trade" or "other") .. (change > 0 and "Up" or "Down")], r)
				end
			end
			-- A bargain is far under usual for something that usually has stock: not a one-off listing.
			if usual >= floor and change <= -bargain and usualQty >= minListed then
				table.insert(rep.cheap, Row())
			end
			if bags[id] then
				table.insert(rep.bags, Row())
			end
		end
	end

	local function Size(r) -- how far from usual, rises and falls alike: 2x and half are the same size
		return math.abs(math.log(r.ratio))
	end
	local function ByMove(a, b)
		local ma, mb = Size(a), Size(b)
		if ma ~= mb then
			return ma > mb
		end
		return a.id < b.id
	end
	local function ByProfit(a, b)
		local pa, pb = a.vendor - a.now, b.vendor - b.now
		if pa ~= pb then
			return pa > pb
		end
		return a.id < b.id
	end
	local function ByRatio(a, b)
		if a.ratio ~= b.ratio then
			return a.ratio > b.ratio
		end
		return a.id < b.id
	end
	local cap = math.max(1, math.floor(tonumber(ns.db.rows) or 8))
	for _, k in ipairs(LISTS) do
		local list = rep[k]
		table.sort(list, k == "vendor" and ByProfit or k == "bags" and ByRatio or ByMove)
		rep.total[k] = #list
		for i = #list, (k == "bags" and ns.BAG_ROWS or cap) + 1, -1 do
			list[i] = nil
		end
	end
	local t = rep.total
	rep.moved = t.tradeUp + t.tradeDown + t.otherUp + t.otherDown
	rep.bargains = t.vendor + t.cheap
	rep.state = (based or t.vendor > 0) and "ok" or "nobase"
	return rep
end

-- The biggest mover: materials before other items, the larger move first. nil when nothing moved.
function ns.TopMover(rep)
	local best
	for _, pair in ipairs({ { "tradeUp", "tradeDown" }, { "otherUp", "otherDown" } }) do
		for _, k in ipairs(pair) do
			local r = rep[k][1]
			if r and (not best or math.abs(math.log(r.ratio)) > math.abs(math.log(best.ratio))) then
				best = r
			end
		end
		if best then
			return best
		end
	end
	return nil
end

-- -------------------------------------------------------------------- text

local UP, DOWN, FLAT = "|cff33ff66", "|cffff5555", "|cffaaaaaa"

-- "+38%", "-12%", "12x", in green or red; grey under one percent.
function ns.ChangeText(change)
	if type(change) ~= "number" then
		return ""
	end
	local ratio = change + 1
	if ratio >= ns.TIMES then
		return ("%s%s|r"):format(UP, ratio >= 10 and ("%dx"):format(math.floor(ratio + 0.5)) or ("%.1fx"):format(ratio))
	end
	local pct = math.floor(math.abs(change) * 100 + 0.5)
	if pct == 0 then
		return FLAT .. "0%|r"
	elseif change > 0 then
		return ("%s+%d%%|r"):format(UP, pct)
	end
	return ("%s-%d%%|r"):format(DOWN, pct)
end

-- Short money for a table cell: "22g", "1g 13s", "28s 71c", "77c". No zero parts, and no copper
-- once there is gold.
local GOLD, SILVER, COPPER = "|cffffd700", "|cffc7c7cf", "|cffeda55f"
function ns.Coin(copper)
	copper = math.floor((tonumber(copper) or 0) + 0.5)
	if copper < 0 then
		return "-" .. ns.Coin(-copper)
	end
	local g = math.floor(copper / 10000)
	local s = math.floor((copper % 10000) / 100)
	local c = copper % 100
	if g >= 100 then
		return ("%s%dg|r"):format(GOLD, g)
	elseif g > 0 then
		return s > 0 and ("%s%dg|r %s%ds|r"):format(GOLD, g, SILVER, s) or ("%s%dg|r"):format(GOLD, g)
	elseif s > 0 then
		return c > 0 and ("%s%ds|r %s%dc|r"):format(SILVER, s, COPPER, c) or ("%s%ds|r"):format(SILVER, s)
	end
	return ("%s%dc|r"):format(COPPER, c)
end
