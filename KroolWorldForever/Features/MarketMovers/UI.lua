-- Market Movers: the definition, slash command, hub card and lifecycle. See Core.lua for the record
-- and the report, and Window.lua for the window and the auction house button.

local _, root = ...
local ns = root.Feature("movers")

local GREY = "|cffaaaaaa"

ns.title = "Market Movers"
ns.description = "After Auctionator scans the auction house, shows what is priced unusually: trade materials and "
	.. "other items that rose or fell against their usual price, bargains listed under the vendor price or far under "
	.. "usual, and how the items in your bags stand. Gear is left out. It keeps its own daily record of the scans, so "
	.. "the first comparison comes the day after your first scan. Needs Auctionator."
ns.icon = "Interface\\Icons\\INV_Ore_Copper_01"
ns.blurb = "Price moves and bargains since the last scan"
ns.options = {
	{
		key = "openAfterScan",
		type = "toggle",
		label = "Open After A Full Scan",
		tooltip = "Opens the window beside the auction house when Auctionator finishes its first full scan of each "
			.. "visit, if anything moved or there is a bargain. It closes with the auction house. Later scans in the "
			.. "same visit only update it.",
		default = true,
	},
	{
		key = "showButton",
		type = "toggle",
		label = "Button On The Auction House",
		tooltip = "A small button above the auction house's top right corner with the number of movers and bargains. "
			.. "A click opens or closes the window.",
		default = true,
	},
	{
		key = "commonQty",
		type = "range",
		label = "Common At",
		tooltip = "A trade material listed in at least this many units, now or usually, goes under Materials. Fewer, "
			.. "and it goes under Other.",
		default = 40,
		min = 10,
		max = 200,
		step = 10,
	},
	{
		key = "minListed",
		type = "range",
		label = "Ignore Under (Listed)",
		tooltip = "Other items listed in fewer units than this, now and usually, are left out: one odd listing of a "
			.. "rare item is not a market move.",
		default = 10,
		min = 1,
		max = 50,
		step = 1,
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
		key = "bargain",
		type = "range",
		label = "Bargain At (% Under Usual)",
		tooltip = "An item this far under its usual price, that usually has stock, is listed under Bargains.",
		default = 30,
		min = 10,
		max = 80,
		step = 5,
	},
	{
		key = "minSilver",
		type = "range",
		label = "Ignore Under (Silver)",
		tooltip = "Items cheaper than this both now and usually are left out: a few copper either way is not news.",
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
		default = 8,
		min = 4,
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

-- Everything that shows the report: the hub card, the auction house button and the window.
local function Changed()
	HubChanged()
	ns.UpdateButton()
	ns.RefreshWindow()
end

local function NameOf(id)
	return C_Item.GetItemNameByID(id) or ("item " .. id)
end

local function Line(r, list)
	if list == "vendor" then
		return ("  %s%s  %s, vendor pays %s"):format(root.UI.ItemIcon(r.id), NameOf(r.id), root.Money(r.now), root.Money(r.vendor))
	end
	return ("  %s%s  %s -> %s  %s, %d listed"):format(
		root.UI.ItemIcon(r.id),
		NameOf(r.id),
		root.Money(r.usual),
		root.Money(r.now),
		ns.ChangeText(r.change),
		r.qty
	)
end

local SHOW = 3
local PRINTED = {
	{ "tradeUp", "Materials rising" },
	{ "tradeDown", "Materials falling" },
	{ "otherUp", "Other items rising" },
	{ "otherDown", "Other items falling" },
	{ "vendor", "Under the vendor price" },
	{ "cheap", "Far under the usual price" },
}
local function PrintReport()
	local rep = ns.Report()
	if rep.state == "nodata" then
		ns:Print("no scan yet. Open the auction house and let Auctionator scan it.")
		return
	elseif rep.state == "nobase" then
		ns:Print("prices are compared with the days before; the first comparison comes with a scan tomorrow.")
		return
	end
	ns:Print(("against the usual price (up to %d %s before):"):format(rep.days, rep.days == 1 and "day" or "days"))
	for _, s in ipairs(PRINTED) do
		local list = rep[s[1]]
		if #list > 0 then
			print(GREY .. s[2] .. "|r")
			for i = 1, math.min(SHOW, #list) do
				print(Line(list[i], s[1]))
			end
		end
	end
	if rep.moved == 0 and rep.bargains == 0 then
		print(GREY .. ("  nothing moved %d%% or more|r"):format(tonumber(ns.db.minChange) or 0))
	end
end

function ns.OnSlash(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "options" or msg == "config" then
		root.OpenSettings(ns)
	elseif msg == "print" or msg == "list" then
		PrintReport()
	elseif msg == "reset" then
		ns.ResetPlace()
		ns:Print("the window is back in its own place: beside the auction house.")
	elseif msg == "bargains" or msg == "deals" then
		ns.OnOpen("deals")
	elseif msg == "bags" then
		ns.OnOpen("bags")
	elseif msg == "help" then
		ns:Print("/kwm - the window; /kwm bargains; /kwm bags; /kwm print - the top moves in chat; /kwm reset - forget where the window was dragged; /kwm options")
	else
		ns.OnOpen()
	end
end

-- The hub card: the biggest move, how many items moved and how many bargains.
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
	local bargains = rep.bargains > 0 and (", %d %s"):format(rep.bargains, rep.bargains == 1 and "bargain" or "bargains") or ""
	local top = ns.TopMover(rep)
	if not top then
		return GREY .. "Nothing moved" .. bargains .. "|r"
	end
	return ("%s%s %s, %d moved%s"):format(root.UI.ItemIcon(top.id, 0), NameOf(top.id), ns.ChangeText(top.change), rep.moved, bargains)
end

-- -------------------------------------------------------------------- lifecycle

-- Auctionator finished a scan (or a search): record it when it was a full scan, then update what
-- shows the report, or open the window once per auction house visit.
local function OnScan()
	if not ns.enabled or not ns.HasClock() or not ns.Record() then
		return
	end
	local h = ns.House(ns.Faction())
	ns.LearnVendor(h.now and h.now.items, function()
		root.Try(ns, "vendor prices", Changed) -- a bargain under the vendor price may have turned up
	end)
	Changed()
	if ns.WindowShown() then
		ns.openedThisVisit = true
		return
	end
	if ns.db.openAfterScan and ns.ahOpen and not ns.openedThisVisit then
		local rep = ns.Report()
		if rep.state == "ok" and (rep.moved > 0 or rep.bargains > 0) then
			ns.openedThisVisit = true
			ns.OnOpen(nil, true)
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
		root.Try(ns, "refresh", ns.RefreshWindow)
	end)
end

-- Names the window is waiting for: look again a few times, a second apart, in case no event comes.
local retries, retrying = 0, false
function ns.RetryNames()
	if retrying or retries >= 5 then
		return
	end
	retrying = true
	retries = retries + 1
	C_Timer.After(1, function()
		retrying = false
		root.Try(ns, "item names", ns.RefreshWindow)
	end)
end

function ns.OnLoad()
	ns.db.ah = type(ns.db.ah) == "table" and ns.db.ah or {}
	ns.db.vendor = type(ns.db.vendor) == "table" and ns.db.vendor or {}
	if ns.HasClock() then
		ns.Prune()
	end
	ns.WatchQueries()
	ns.auctionHooked = root.OnAuctionPrices(function()
		root.Try(ns, "scan", OnScan)
	end)
end

function ns.OnDisable()
	local f = ns.WindowFrame()
	if f then
		f:Hide()
	end
	ns.UpdateButton()
end

function ns.OnOptionChanged()
	Changed()
end

local function ItemLoaded(_, itemId)
	if not (issecretvalue ~= nil and issecretvalue(itemId)) and ns.pending[itemId] then
		RefreshSoon()
	end
end

ns:RegisterEvent("AUCTION_HOUSE_SHOW", function()
	ns.ahOpen = true
	ns.openedThisVisit = false
	retries = 0
	ns.WatchQueries()
	root.Try(ns, "auction house button", ns.UpdateButton)
end)
ns:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
	ns.ahOpen = false
	local f = ns.WindowFrame()
	if ns.autoOpened and f and f:IsShown() then
		f:Hide() -- it opened by itself for this visit, so it leaves with it
	end
	ns.autoOpened = false
end)
ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", ItemLoaded)
ns:RegisterEvent("ITEM_DATA_LOAD_RESULT", ItemLoaded)
ns:RegisterEvent("BAG_UPDATE_DELAYED", function()
	if ns.WindowShown() then
		RefreshSoon()
	end
end)
