-- Market Movers' client: the Least Valuable stubs (widgets, settings, items, Auctionator's price
-- API), plus the auction house's browse results, an Auctionator that calls back after a scan and
-- searches, the item class lookup, the player's faction and a settable clock (UTC, so the tests do
-- not depend on the time zone).

__include("leastvaluable/stubs.lua")

-- ---------------------------------------------------------------- clock

local function DaysFromCivil(y, m, d)
	y = m <= 2 and y - 1 or y
	local era = (y >= 0 and y or y - 399) // 400
	local yoe = y - era * 400
	local doy = (153 * (m + (m > 2 and -3 or 9)) + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end
local function CivilFromDays(z)
	z = z + 719468
	local era = (z >= 0 and z or z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = mp < 10 and mp + 3 or mp - 9
	return yoe + era * 400 + (m <= 2 and 1 or 0), m, d
end

-- At(2026, 11, 17, 15, 0): seconds for that UTC moment.
function At(y, m, d, h, mi)
	return DaysFromCivil(y, m, d) * 86400 + (h or 12) * 3600 + (mi or 0) * 60
end
Now = At(2026, 11, 17, 15, 0)
function time(t)
	if type(t) == "table" then
		return At(t.year, t.month, t.day, t.hour or 12, t.min or 0) + (t.sec or 0)
	end
	return Now
end
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
function date(fmt, t)
	t = t or Now
	local days = t // 86400
	local secs = t - days * 86400
	if fmt == "%H:%M" then
		return ("%02d:%02d"):format(secs // 3600, (secs % 3600) // 60)
	elseif fmt == "%b %d" then
		local _, m, d = CivilFromDays(days)
		return ("%s %02d"):format(MONTHS[m], d)
	elseif fmt == "%b %d %H:%M" then
		return date("%b %d", t) .. " " .. date("%H:%M", t)
	end
	return "?"
end

-- ---------------------------------------------------------------- auction house

-- Browse = { [itemID] = { price, qty } }; BrowseExtra = a list of raw results added as they are.
Browse, BrowseExtra = {}, {}
FullBrowse = true
BrowseCalls = 0
C_AuctionHouse = {
	GetBrowseResults = function()
		BrowseCalls = BrowseCalls + 1
		local out = {}
		for id, e in pairs(Browse) do
			out[#out + 1] = { itemKey = { itemID = id, itemLevel = 1, itemSuffix = 0, battlePetSpeciesID = 0 }, minPrice = e[1], totalQuantity = e[2] }
		end
		for _, r in ipairs(BrowseExtra) do
			out[#out + 1] = r
		end
		return out
	end,
	HasFullBrowseResults = function()
		return FullBrowse
	end,
}

-- n filler items (ids 800001..), each listed at 1g: makes a browse big enough to be a full scan.
function Filler(n, price)
	for i = 1, n do
		Browse[800000 + i] = { price or 10000, 5 }
	end
end

Faction = "Alliance"
function UnitFactionGroup()
	return Faction
end

-- Item class from the Items fixtures (class 7 trade goods, 2 weapon, 4 armor, ...).
C_Item.GetItemInfoInstant = function(item)
	local id = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)"))
	local i = id and Items[id]
	if not i then
		return nil
	end
	return id, "", "", "", 134400, i.class or 15, i.sub or 0
end

-- Auctionator with the scan callback and the search the window's rows use.
ScanCallbacks, Searches = {}, {}
local plain = AuctionatorOn
function AuctionatorOn(on)
	plain(on)
	if Auctionator then
		Auctionator.API.v1.RegisterForDBUpdate = function(_, fn)
			ScanCallbacks[#ScanCallbacks + 1] = fn
		end
		Auctionator.API.v1.MultiSearchExact = function(caller, terms)
			Searches[#Searches + 1] = { caller = caller, term = terms[1] }
		end
	end
end
AuctionatorOn(true)
function AuctionatorScan()
	for _, fn in ipairs(ScanCallbacks) do
		fn()
	end
end

Linked = {}
function HandleModifiedItemClick(link)
	Linked[#Linked + 1] = link
	return true
end

function debugstack(start)
	return debug.traceback("", start)
end
