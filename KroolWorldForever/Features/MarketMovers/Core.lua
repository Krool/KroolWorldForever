-- Market Movers: after Auctionator scans the auction house, the items whose price moved most since
-- the day before, in two lists: trade materials that sell in quantity, and everything else. Gear
-- is left out.
--
-- Auctionator's own price history is internal (its API v1 has no history and no item list; see
-- docs/research/data-sources/prices_and_addon_api.md), so this keeps its own. Auctionator's scan is
-- a browse of the whole house; when it finishes it calls back (root.OnAuctionPrices), and the
-- client's browse results still hold every listed item with its lowest price and the units listed
-- (C_AuctionHouse.GetBrowseResults, Blizzard's API). Each full scan is added to that day's record
-- per item: the sum and count of the scans' lowest prices, and the most units seen. "Now" is the
-- latest full scan; "before" is the average over the latest earlier day that has the item, at most
-- three days back. A small search is not recorded: its results are a few items, and averaging them
-- in would weigh the items you search for.
--
-- Records are per faction (Alliance and Horde houses list different things) and keep four days.
-- Read only: it never buys, bids, posts or cancels.

local _, root = ...
local ns = root.Feature("movers")

ns.FULL_MIN = 200 -- a browse this large is Auctionator's full scan, not a search
ns.FULL_SHARE = 0.4 -- ...and at least this share of the last full scan's size
ns.KEEP_DAYS = 4
ns.LOOKBACK = 3 -- "before" is at most this many days older than "now"
ns.SAME_SCAN = 60 -- seconds: a second callback this soon after a recorded scan is the same scan
ns.TRADE_CLASS = 7 -- Enum.ItemClass.Tradegoods
-- Gear and the like: Container 1, Weapon 2, Armor 4, Quiver 11, Battlepet 17.
ns.GEAR_CLASS = { [1] = true, [2] = true, [4] = true, [11] = true, [17] = true }

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
		local key = type(r) == "table" and r.itemKey
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
	return items, n
end

-- Whether a browse of this many results is a full scan of the house.
function ns.IsFullScan(count, h)
	if count < ns.FULL_MIN then
		return false
	end
	local ok, full = pcall(C_AuctionHouse and C_AuctionHouse.HasFullBrowseResults)
	if ok and full == false then
		return false -- still paging: Auctionator calls back again when it is done
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
	h.size = count
	ns.Prune(today)
	return true
end

-- -------------------------------------------------------------------- the report

-- The two lists for this faction's house. Returns a report:
--   { state = "nodata" | "nobase" | "ok", at = time of the scan, baseDay = the newest day compared with,
--     trade = { row, ... }, other = { row, ... }, moved = rows past the filters before the row cap }
-- row = { id, now, before, change, qty, beforeQty, scans, day, trade }
function ns.Report(faction)
	local h = ns.db.ah[faction or ns.Faction()]
	if type(h) ~= "table" or type(h.now) ~= "table" or type(h.now.items) ~= "table" then
		return { state = "nodata", trade = {}, other = {}, moved = 0 }
	end
	local nowDay = ns.Day(h.now.at)
	local floor = (tonumber(ns.db.minSilver) or 0) * 100
	local minChange = (tonumber(ns.db.minChange) or 0) / 100
	local common = tonumber(ns.db.commonQty) or 0
	local trade, other, based, newest = {}, {}, false, nil
	for id, cur in pairs(h.now.items) do
		local base, baseDay
		for d = nowDay - 1, nowDay - ns.LOOKBACK, -1 do
			local day = h.days[d]
			local e = type(day) == "table" and day[id]
			if type(e) == "table" and type(e.n) == "number" and e.n > 0 then
				base, baseDay = e, d
				break
			end
		end
		if base then
			based = true
			newest = math.max(newest or baseDay, baseDay)
			local before = base.s / base.n
			local change = before > 0 and (cur.p / before - 1) or 0
			if (cur.p >= floor or before >= floor) and math.abs(change) >= minChange and not ns.IsGear(id) then
				local isTrade = ns.ClassOf(id) == ns.TRADE_CLASS and math.max(cur.q, base.q or 0) >= common
				local row = {
					id = id,
					now = cur.p,
					before = before,
					change = change,
					qty = cur.q,
					beforeQty = base.q or 0,
					scans = base.n,
					day = baseDay,
					trade = isTrade,
				}
				local list = isTrade and trade or other
				list[#list + 1] = row
			end
		end
	end
	local function ByMove(a, b)
		local ma, mb = math.abs(a.change), math.abs(b.change)
		if ma ~= mb then
			return ma > mb
		end
		return a.id < b.id
	end
	table.sort(trade, ByMove)
	table.sort(other, ByMove)
	local moved = #trade + #other
	local cap = math.max(1, math.floor(tonumber(ns.db.rows) or 12))
	for _, list in ipairs({ trade, other }) do
		for i = #list, cap + 1, -1 do
			list[i] = nil
		end
	end
	return {
		state = based and "ok" or "nobase",
		at = h.now.at,
		baseDay = newest,
		trade = trade,
		other = other,
		moved = moved,
	}
end

-- "+38%", "-12%", in green or red.
function ns.ChangeText(change)
	local pct = math.floor(math.abs(change) * 100 + 0.5)
	if change >= 0 then
		return ("|cff33ff66+%d%%|r"):format(pct)
	end
	return ("|cffff5555-%d%%|r"):format(pct)
end
