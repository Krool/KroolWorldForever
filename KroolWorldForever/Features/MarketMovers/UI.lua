-- Market Movers: the definition, slash command, hub card and lifecycle. See Core.lua for the record
-- and Window.lua for the window.

local _, root = ...
local ns = root.Feature("movers")

local GREY = "|cffaaaaaa"

ns.title = "Market Movers"
ns.description = "After Auctionator scans the auction house, lists the items whose price moved most since the day "
	.. "before: trade materials that sell in quantity, and everything else. Gear is left out. It keeps its own daily "
	.. "record of the scans, so the first comparison comes the day after your first scan. Needs Auctionator."
ns.icon = "Interface\\Icons\\INV_Ore_Copper_01"
ns.blurb = "Biggest price moves since yesterday"
ns.options = {
	{
		key = "openAfterScan",
		type = "toggle",
		label = "Open After A Full Scan",
		tooltip = "Opens the window when Auctionator finishes its first full scan of each auction house visit, if "
			.. "anything moved. Later scans in the same visit only update it.",
		default = true,
	},
	{
		key = "commonQty",
		type = "range",
		label = "Common At",
		tooltip = "A trade material listed in at least this many units, now or the day before, goes in Trade "
			.. "Materials. Fewer, and it goes in Other Items.",
		default = 40,
		min = 10,
		max = 200,
		step = 10,
	},
	{
		key = "minChange",
		type = "range",
		label = "Smallest Change (%)",
		tooltip = "Price moves smaller than this are left out.",
		default = 10,
		min = 5,
		max = 50,
		step = 5,
	},
	{
		key = "minSilver",
		type = "range",
		label = "Ignore Under (Silver)",
		tooltip = "Items cheaper than this both now and the day before are left out: a few copper either way is not news.",
		default = 1,
		min = 0,
		max = 100,
		step = 1,
	},
	{
		key = "rows",
		type = "range",
		label = "Rows Per List",
		tooltip = "How many items each list shows, biggest moves first.",
		default = 12,
		min = 5,
		max = 25,
		step = 1,
	},
}
ns.slash = { "/kwm", "/marketmovers" }

local function HubChanged()
	if root.RefreshHub then
		pcall(root.RefreshHub)
	end
end

local function Line(r)
	local name = C_Item.GetItemNameByID(r.id) or ("item " .. r.id)
	return ("  %s%s  %s -> %s  %s, %d listed"):format(
		root.UI.ItemIcon(r.id),
		name,
		root.Money(r.before),
		root.Money(r.now),
		ns.ChangeText(r.change),
		r.qty
	)
end

local SHOW = 5
local function PrintReport()
	local rep = ns.Report()
	if rep.state == "nodata" then
		ns:Print("no scan yet. Open the auction house and let Auctionator scan it.")
		return
	elseif rep.state == "nobase" then
		ns:Print("prices are compared with the day before; the first comparison comes with a scan tomorrow.")
		return
	end
	ns:Print(("since %s:"):format(ns.DayText(rep.baseDay)))
	for _, s in ipairs({ { "trade", "Trade Materials" }, { "other", "Other Items" } }) do
		local list = rep[s[1]]
		if #list > 0 then
			print(GREY .. s[2] .. "|r")
			for i = 1, math.min(SHOW, #list) do
				print(Line(list[i]))
			end
		end
	end
	if rep.moved == 0 then
		print(GREY .. ("  nothing moved %d%% or more|r"):format(tonumber(ns.db.minChange) or 0))
	end
end

function ns.OnSlash(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "options" or msg == "config" then
		root.OpenSettings(ns)
	elseif msg == "print" or msg == "list" then
		PrintReport()
	elseif msg == "help" then
		ns:Print("/kwm - the Market Movers window; /kwm print - the top moves in chat; /kwm options")
	else
		ns.OnOpen()
	end
end

-- The hub card: the biggest move, and how many items moved.
function ns.HubStatus()
	if not root.HasAuctionator() then
		return "|cffff5555Needs Auctionator|r"
	end
	local rep = ns.Report()
	if rep.state == "nodata" then
		return GREY .. "Scan the auction house to start|r"
	elseif rep.state == "nobase" then
		return GREY .. "First comparison after tomorrow's scan|r"
	end
	local top = rep.trade[1] or rep.other[1]
	if not top then
		return GREY .. "Nothing moved since " .. ns.DayText(rep.baseDay) .. "|r"
	end
	local name = C_Item.GetItemNameByID(top.id) or ("item " .. top.id)
	return ("%s%s %s, %d moved"):format(root.UI.ItemIcon(top.id, 0), name, ns.ChangeText(top.change), rep.moved)
end

-- -------------------------------------------------------------------- lifecycle

-- Auctionator finished a scan (or a search): record it when it was a full scan, then update the
-- window, or open it once per auction house visit.
local function OnScan()
	if not ns.enabled or not ns.HasClock() or not ns.Record() then
		return
	end
	HubChanged()
	if ns.WindowShown() then
		ns.openedThisVisit = true
		ns.RefreshWindow()
		return
	end
	if ns.db.openAfterScan and ns.ahOpen and not ns.openedThisVisit then
		local rep = ns.Report()
		if rep.state == "ok" and rep.moved > 0 then
			ns.openedThisVisit = true
			ns.OnOpen()
		end
	end
end
ns.OnScan = OnScan

local soon = false
local function RefreshSoon()
	if soon then
		return
	end
	soon = true
	C_Timer.After(0.2, function()
		soon = false
		root.Try(ns, "item names", ns.RefreshWindow)
	end)
end

function ns.OnLoad()
	ns.db.ah = type(ns.db.ah) == "table" and ns.db.ah or {}
	if ns.HasClock() then
		ns.Prune()
	end
	ns.auctionHooked = root.OnAuctionPrices(function()
		root.Try(ns, "scan", OnScan)
	end)
end

function ns.OnDisable()
	local f = ns.WindowFrame()
	if f then
		f:Hide()
	end
end

function ns.OnOptionChanged()
	ns.RefreshWindow()
	HubChanged()
end

ns:RegisterEvent("AUCTION_HOUSE_SHOW", function()
	ns.ahOpen = true
	ns.openedThisVisit = false
end)
ns:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
	ns.ahOpen = false
end)
ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemId)
	if not (issecretvalue ~= nil and issecretvalue(itemId)) and ns.pending[itemId] then
		RefreshSoon()
	end
end)
