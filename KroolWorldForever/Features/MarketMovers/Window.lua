-- Market Movers window (/kwm, the hub, the button on the auction house, and by itself after the
-- first full scan of an auction house visit). Four tabs: Materials and Other (rising, falling),
-- Bargains (under the vendor price, far under the usual price) and My Bags. A row shows the item, a
-- small trend line over the last days against the usual price, the usual price, the price now, the
-- change and the units listed. Hovering shows the item's tooltip with the days behind "usual"; a
-- click searches the item in Auctionator while the auction house is open, a shift-click links it.
--
-- While the auction house is open the window sits beside it, not over it. Dragging it sets its
-- place from then on (/kwm reset forgets that). Built on first open.

local _, root = ...
local ns = root.Feature("movers")
local UI = root.UI

local W, H, ROW_H, HEAD_H, GAP = 540, 520, 22, 26, 6
-- Column left edges inside a row, and widths.
local COL = {
	name = { 30, 152 },
	trend = { 186, 46 },
	usual = { 234, 66 },
	now = { 302, 66 },
	change = { 370, 62 },
	last = { 436, 50 },
}
local SPARK_H = 14
local GREY, BLUE = "|cffaaaaaa", "|cff88ccff"
local GOLD = { 1, 0.82, 0 }
local frame -- built on first open

-- Each tab: its report lists as sections, and the column titles.
local TABS = {
	{
		key = "trade",
		title = "Materials",
		sections = { { "tradeUp", "Rising" }, { "tradeDown", "Falling" } },
		cols = { usual = "Usual", now = "Now", change = "Change", last = "Listed" },
		empty = "No trade material moved %d%% or more from its usual price.",
	},
	{
		key = "other",
		title = "Other",
		sections = { { "otherUp", "Rising" }, { "otherDown", "Falling" } },
		cols = { usual = "Usual", now = "Now", change = "Change", last = "Listed" },
		empty = "No other item moved %d%% or more from its usual price.",
	},
	{
		key = "deals",
		title = "Bargains",
		sections = { { "vendor", "Under the vendor price: vendor pays, price, gain" }, { "cheap", "Far under the usual price" } },
		cols = { usual = "Usual", now = "Now", change = "Change", last = "Listed" },
		empty = "Nothing is listed under its vendor price or far under its usual price.",
	},
	{
		key = "bags",
		title = "My Bags",
		sections = { { "bags", "In your bags, the best to sell first" } },
		cols = { usual = "Usual", now = "Now", change = "Change", last = "Bags" },
		empty = "Nothing in your bags has a usual price yet.",
	},
}
ns.TABS = TABS

local function TabCount(tab, rep)
	local n = 0
	for _, s in ipairs(tab.sections) do
		n = n + (rep.total[s[1]] or 0)
	end
	return n
end

-- Names the client has not loaded yet: asked for, and the list redraws when they arrive.
ns.pending = {}
local function NameOf(id)
	local ok, name = pcall(C_Item.GetItemNameByID, id)
	if ok and type(name) == "string" and name ~= "" then
		ns.pending[id] = nil
		return name
	end
	ns.pending[id] = true
	pcall(C_Item.RequestLoadItemDataByID, id)
	return GREY .. "Item " .. id .. "|r"
end

local function Column(row, col, font, justify)
	local t = UI.Text(row, font, justify or "RIGHT")
	t:SetPoint("LEFT", COL[col][1], 0)
	t:SetWidth(COL[col][2])
	t:SetWordWrap(false)
	return t
end

local function Search(row)
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	if not (ns.ahOpen and type(api) == "table" and type(api.MultiSearchExact) == "function") then
		return
	end
	local name = row.itemID and C_Item.GetItemNameByID(row.itemID)
	if type(name) == "string" and name ~= "" then
		pcall(api.MultiSearchExact, root.ID.addon, { name })
	end
end

-- -------------------------------------------------------------------- trend line

-- The points of a row's trend: each earlier day's average, then the price now.
local function TrendPoints(r)
	local pts = {}
	for _, d in ipairs(r.series or {}) do
		pts[#pts + 1] = d.p
	end
	pts[#pts + 1] = r.now
	return pts
end
ns.TrendPoints = TrendPoints

-- Draws the trend in the row's trend column: a faint line at the usual price, the prices as a
-- line (green above usual at the end, red below), and a dot for now. Hidden with under two points.
local function DrawTrend(row, r)
	local s = rawget(row, "spark") -- rawget: a widget may answer any name
	if not s then
		s = { lines = {} }
		row.spark = s
		s.base = row:CreateTexture(nil, "BORDER")
		s.base:SetColorTexture(1, 1, 1, 0.22)
		s.base:SetHeight(1)
		s.dot = row:CreateTexture(nil, "OVERLAY")
		s.dot:SetSize(4, 4)
	end
	for _, l in ipairs(s.lines) do
		l:Hide()
	end
	local pts = r.usual and TrendPoints(r) or {}
	row.trendPoints = #pts
	if #pts < 2 then
		s.base:Hide()
		s.dot:Hide()
		return
	end
	local lo, hi = r.usual, r.usual
	for _, p in ipairs(pts) do
		lo, hi = math.min(lo, p), math.max(hi, p)
	end
	local span = hi - lo
	local x0, w = COL.trend[1] + 2, COL.trend[2] - 6
	local function Y(p)
		return span > 0 and ((p - lo) / span - 0.5) * SPARK_H or 0
	end
	local function X(i)
		return x0 + (i - 1) / (#pts - 1) * w
	end
	local up = r.now >= r.usual
	local cr, cg, cb = up and 0.2 or 1, up and 1 or 0.33, up and 0.4 or 0.33
	s.base:ClearAllPoints()
	s.base:SetPoint("LEFT", row, "LEFT", x0, Y(r.usual))
	s.base:SetWidth(w)
	s.base:Show()
	if type(row.CreateLine) == "function" then
		for i = 1, #pts - 1 do
			local l = s.lines[i]
			if not l then
				l = row:CreateLine(nil, "ARTWORK")
				if not l then
					break
				end
				l:SetThickness(1.5)
				s.lines[i] = l
			end
			l:SetColorTexture(cr, cg, cb, 0.9)
			l:SetStartPoint("LEFT", row, X(i), Y(pts[i]))
			l:SetEndPoint("LEFT", row, X(i + 1), Y(pts[i + 1]))
			l:Show()
		end
	end
	s.dot:ClearAllPoints()
	s.dot:SetPoint("CENTER", row, "LEFT", X(#pts), Y(pts[#pts]))
	s.dot:SetColorTexture(cr, cg, cb, 1)
	s.dot:Show()
end

-- -------------------------------------------------------------------- rows

-- The last column: units listed (amber when stock is under half the usual), or units in the bags.
local function LastText(r, tabKey)
	if tabKey == "bags" then
		return ("%sx%d|r"):format(BLUE, r.bags or 0)
	end
	if r.usualQty and r.usualQty > 0 and r.qty < r.usualQty / 2 then
		return ("|cffffaa33%d|r"):format(r.qty)
	end
	return tostring(r.qty)
end

-- What to do with a bag item, from how its price stands against usual.
function ns.Advice(r)
	local min = (tonumber(ns.db.minChange) or 10) / 100
	if not r.change then
		return nil
	elseif r.change >= min then
		return "|cff33ff66Selling above usual: a good time to sell.|r"
	elseif r.change <= -min then
		return "|cffff5555Selling below usual: better to wait.|r"
	end
	return GREY .. "Selling at about its usual price.|r"
end

local function RowTip(self)
	local r = self.data
	if not (GameTooltip and r) then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	pcall(GameTooltip.SetItemByID, GameTooltip, r.id)
	GameTooltip:AddLine(" ")
	GameTooltip:AddDoubleLine("Now", root.Money(r.now), 1, 0.82, 0, 1, 1, 1)
	if r.usual then
		GameTooltip:AddDoubleLine(
			("Usual (%d %s)"):format(r.days, r.days == 1 and "day" or "days"),
			root.Money(r.usual),
			1, 0.82, 0, 1, 1, 1
		)
		for i = #r.series, 1, -1 do
			local d = r.series[i]
			GameTooltip:AddDoubleLine(
				("  %s, %d %s, %d listed"):format(ns.DayText(d.d), d.n, d.n == 1 and "scan" or "scans", d.q),
				root.Money(d.p),
				0.7, 0.7, 0.7, 0.85, 0.85, 0.85
			)
		end
		GameTooltip:AddDoubleLine("Listed", ("%d (usually %d)"):format(r.qty, math.floor(r.usualQty + 0.5)), 1, 0.82, 0, 1, 1, 1)
		if r.usualQty > 0 and r.qty < r.usualQty / 2 then
			GameTooltip:AddLine("Stock is under half the usual: the cheap ones sold.", 1, 0.67, 0.2, true)
		end
		if r.days < 3 then
			GameTooltip:AddLine("Only " .. r.days .. (r.days == 1 and " day" or " days") .. " of history: usual is a rough guide.", 0.6, 0.6, 0.6, true)
		end
	end
	if r.vendor then
		GameTooltip:AddDoubleLine("Vendor pays", root.Money(r.vendor), 1, 0.82, 0, 1, 1, 1)
		if r.vendor > r.now then
			GameTooltip:AddLine(
				("Under the vendor price by %s each. Only the cheapest listing is sure to be this low; check it is a buyout."):format(root.Money(r.vendor - r.now)),
				0.2, 1, 0.4, true
			)
		end
	end
	if r.bags then
		GameTooltip:AddDoubleLine("In your bags", ("%d, worth %s now"):format(r.bags, root.Money(r.bags * r.now)), 1, 0.82, 0, 1, 1, 1)
		local advice = ns.Advice(r)
		if advice then
			GameTooltip:AddLine(advice, 1, 1, 1, true)
		end
	end
	GameTooltip:Show()
end

local function Row(content, i)
	local row = frame.rows[i]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, content)
	row:SetSize(W - 50, ROW_H - 2)
	UI.Hover(row)
	row.stripe = row:CreateTexture(nil, "BACKGROUND")
	row.stripe:SetAllPoints()
	row.stripe:SetColorTexture(1, 1, 1, 0.03)
	row.stripe:SetShown(i % 2 == 0)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(18, 18)
	row.icon:SetPoint("LEFT", 6, 0)
	row.name = Column(row, "name", "GameFontHighlight", "LEFT")
	row.usual = Column(row, "usual", "GameFontHighlightSmall")
	row.now = Column(row, "now", "GameFontHighlightSmall")
	row.change = Column(row, "change", "GameFontHighlight")
	row.last = Column(row, "last", "GameFontHighlightSmall")
	row:SetScript("OnEnter", RowTip)
	row:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	row:SetScript("OnClick", function(self)
		root.Try(ns, "row click", function()
			if IsShiftKeyDown and IsShiftKeyDown() then
				local ok, _, link = pcall(C_Item.GetItemInfo, self.itemID)
				if ok and type(link) == "string" and type(HandleModifiedItemClick) == "function" then
					pcall(HandleModifiedItemClick, link)
				end
				return
			end
			Search(self)
		end)
	end)
	frame.rows[i] = row
	return row
end

local function FillRow(row, r, listKey, tabKey)
	row.itemID, row.data, row.list = r.id, r, listKey
	local ok, file = pcall(C_Item.GetItemIconByID, r.id)
	UI.SetIcon(row.icon, ok and file or "Interface\\Icons\\INV_Misc_QuestionMark")
	local name = NameOf(r.id)
	if r.bags and tabKey ~= "bags" then
		name = name .. (" %sx%d|r"):format(BLUE, r.bags) -- you hold some
	end
	row.name:SetText(name)
	if listKey == "vendor" then
		-- Buy and sell to a vendor: what the vendor pays, the price, and the gain on each.
		row.usual:SetText(ns.Coin(r.vendor))
		row.now:SetText(ns.Coin(r.now))
		row.change:SetText("|cff33ff66+|r" .. ns.Coin(r.vendor - r.now))
	else
		row.usual:SetText(ns.Coin(r.usual))
		row.now:SetText(ns.Coin(r.now))
		row.change:SetText(ns.ChangeText(r.change))
	end
	row.last:SetText(LastText(r, tabKey))
	DrawTrend(row, r)
	row:Show()
end

-- A section header: "Rising (8 of 23)" and a divider line, hidden and shown as one.
local function Header(content, i)
	local h = frame.headers[i]
	if h then
		return h
	end
	h = UI.Text(content, "GameFontNormal")
	h.line = UI.Divider(content, W - 70)
	h.line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", -2, -3)
	frame.headers[i] = h
	return h
end

local function ShowHeader(h, on)
	h:SetShown(on)
	h.line:SetShown(on)
end

-- -------------------------------------------------------------------- place

-- Where the window goes. A place the player dragged it to wins. Otherwise, with the auction house
-- open: beside it on the right, or the left, wherever there is room; with no room, the right edge
-- of the screen. Otherwise the middle. Returns which, for tests.
local function Place()
	frame:ClearAllPoints()
	local pos = ns.db.pos
	if type(pos) == "table" and type(pos[1]) == "string" and type(pos[3]) == "number" and type(pos[4]) == "number" then
		frame:SetPoint(pos[1], UIParent, type(pos[2]) == "string" and pos[2] or pos[1], pos[3], pos[4])
		return "saved"
	end
	local ah = AuctionHouseFrame
	if ns.ahOpen and type(ah) == "table" and type(ah.IsShown) == "function" and ah:IsShown() then
		local ok, side = pcall(function()
			local mine = frame:GetEffectiveScale()
			local k = ah:GetEffectiveScale() / mine
			local screen = UIParent:GetWidth() * UIParent:GetEffectiveScale() / mine
			if ah:GetRight() * k + GAP + W <= screen then
				return "right"
			elseif ah:GetLeft() * k - GAP - W >= 0 then
				return "left"
			end
			return "edge"
		end)
		side = ok and side or "edge"
		if side == "right" then
			frame:SetPoint("TOPLEFT", ah, "TOPRIGHT", GAP, 0)
		elseif side == "left" then
			frame:SetPoint("TOPRIGHT", ah, "TOPLEFT", -GAP, 0)
		else
			frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -8, -110)
		end
		return side
	end
	frame:SetPoint("CENTER")
	return "center"
end

-- -------------------------------------------------------------------- build

local function SelectTab(key)
	ns.db.tab = key
	ns.RefreshWindow(true)
	if frame.scroll and frame.scroll.SetVerticalScroll then
		frame.scroll:SetVerticalScroll(0)
	end
end

local function Build()
	frame = UI.Window(root.ID.prefix .. "MarketMoversFrame", "Market Movers", W, H, ns.icon)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint(1)
		if type(point) == "string" and type(x) == "number" and type(y) == "number" then
			ns.db.pos = { point, relPoint, x, y }
		end
	end)
	frame.banner = UI.Text(frame, "GameFontHighlight")
	frame.banner:SetPoint("TOPLEFT", 68, -35)
	frame.banner:SetWidth(W - 84)
	frame.banner:SetWordWrap(false)

	-- Tabs: plain text buttons with a gold line under the open one.
	frame.tabs = {}
	local tabW = math.floor((W - 28) / #TABS)
	for i, tab in ipairs(TABS) do
		local b = CreateFrame("Button", nil, frame)
		b:SetSize(tabW - 4, 22)
		b:SetPoint("TOPLEFT", 14 + (i - 1) * tabW, -60)
		UI.Hover(b)
		b.label = UI.Text(b, "GameFontNormal", "CENTER")
		b.label:SetPoint("CENTER", 0, 1)
		b.line = b:CreateTexture(nil, "ARTWORK")
		b.line:SetPoint("BOTTOMLEFT", 6, 0)
		b.line:SetPoint("BOTTOMRIGHT", -6, 0)
		b.line:SetHeight(2)
		b.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
		b.key = tab.key
		b:SetScript("OnClick", function()
			UI.Sound("click")
			root.Try(ns, "tab", function()
				SelectTab(tab.key)
			end)
		end)
		frame.tabs[i] = b
	end

	-- Column titles over the list.
	frame.cols = {}
	for _, key in ipairs({ "name", "trend", "usual", "now", "change", "last" }) do
		local t = UI.Text(frame, "GameFontDisableSmall", key == "name" and "LEFT" or key == "trend" and "CENTER" or "RIGHT")
		t:SetPoint("TOPLEFT", 14 + COL[key][1], -90)
		t:SetWidth(COL[key][2])
		frame.cols[key] = t
	end
	frame.cols.name:SetText("Item")
	frame.cols.trend:SetText("Trend")
	frame.content = UI.ScrollList(frame, -104, 28)
	frame.content:SetWidth(W - 50)
	frame.rows, frame.headers = {}, {}
	frame.empty = UI.Empty(frame.content, UI.ATLAS.search, W - 80)

	frame.note = UI.Text(frame, "GameFontDisableSmall")
	frame.note:SetPoint("BOTTOMLEFT", 14, 10)
	frame.gear = UI.IconButton(frame, 18, UI.GEAR_ICON, function()
		UI.HandOff(frame)
		root.OpenSettings(ns)
	end)
	frame.gear:SetPoint("BOTTOMRIGHT", -12, 6)
	UI.Tip(frame.gear, function()
		return "Settings", { "Market Movers' options: what counts as common, the smallest move, what counts as a bargain." }
	end)
end

local function Empty(text, atlas)
	frame.empty:SetText(text)
	frame.empty.art:SetAtlas(atlas)
	frame.empty:Show()
	frame.empty.art:Show()
	frame.content:SetHeight(10)
end

local function CurrentTab()
	for _, tab in ipairs(TABS) do
		if tab.key == ns.db.tab then
			return tab
		end
	end
	return TABS[1]
end

local function DrawTabs(rep, current)
	for i, tab in ipairs(TABS) do
		local b = frame.tabs[i]
		local n = rep and TabCount(tab, rep) or 0
		local on = tab.key == current.key
		b.label:SetText(n > 0 and ("%s %s(%d)|r"):format(tab.title, on and "|cffffffff" or GREY, n) or tab.title)
		if on then
			b.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		else
			b.label:SetTextColor(0.6, 0.6, 0.6)
		end
		b.line:SetShown(on)
		b.count = n
	end
	for key, t in pairs(frame.cols) do
		if current.cols[key] then
			t:SetText(current.cols[key])
		end
	end
end

-- Rebuilds the lists. Skipped while the window is closed unless forced.
function ns.RefreshWindow(force)
	if not frame or not (force or frame:IsShown()) then
		return
	end
	for _, r in ipairs(frame.rows) do
		r:Hide()
	end
	for _, h in ipairs(frame.headers) do
		ShowHeader(h, false)
	end
	frame.empty:Hide()
	frame.empty.art:Hide()
	frame.moved = 0
	frame.note:SetText(
		ns.ahOpen and "Click a row: search it in Auctionator. Shift-click: link it."
			or "Shift-click a row: link it. At the auction house, a click searches it."
	)
	local tab = CurrentTab()
	frame.tab = tab.key

	if not root.HasAuctionator() then
		DrawTabs(nil, tab)
		frame.banner:SetText("|cffff5555Needs Auctionator.|r")
		Empty("Market Movers reads the auction house when Auctionator scans it. Install Auctionator and reload.", UI.ATLAS.fail)
		return
	end
	local rep = ns.Report()
	DrawTabs(rep.state == "ok" and rep or nil, tab)
	if rep.state == "nodata" then
		frame.banner:SetText("No scan yet.")
		Empty("Open the auction house and let Auctionator scan it (its Scan button, or autoscan). The first scan is the start of the record.", UI.ATLAS.search)
		return
	end
	local scanned = ("%s house, last scan %s %s"):format(ns.Faction(), ns.DayText(ns.Day(rep.at)), date("%H:%M", rep.at))
	if rep.state == "nobase" then
		frame.banner:SetText(scanned .. ".")
		Empty("Prices are compared with the days before. The first comparison comes with a scan tomorrow.", UI.ATLAS.search)
		return
	end
	frame.banner:SetText(
		("%s. Usual: up to %d %s before."):format(scanned, rep.days, rep.days == 1 and "day" or "days")
	)
	frame.moved = rep.moved

	local y, rowIndex = -4, 0
	for si, s in ipairs(tab.sections) do
		local list = rep[s[1]]
		if #list > 0 then
			local h = Header(frame.content, si)
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", 8, y - 6)
			local total = rep.total[s[1]]
			h:SetText(total > #list and ("%s (%d of %d)"):format(s[2], #list, total) or ("%s (%d)"):format(s[2], #list))
			local falling = s[1] == "tradeDown" or s[1] == "otherDown"
			if falling then
				h:SetTextColor(1, 0.45, 0.4)
			elseif s[1] == "tradeUp" or s[1] == "otherUp" then
				h:SetTextColor(0.3, 1, 0.5)
			else
				h:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
			end
			ShowHeader(h, true)
			y = y - HEAD_H
			for _, r in ipairs(list) do
				rowIndex = rowIndex + 1
				local row = Row(frame.content, rowIndex)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, y)
				FillRow(row, r, s[1], tab.key)
				y = y - ROW_H
			end
		end
	end
	frame.content:SetHeight(math.max(10, -y + 4))
	if rowIndex == 0 then
		Empty(tab.empty:format(tonumber(ns.db.minChange) or 0), UI.ATLAS.ok)
	end
	-- Names still loading: look again shortly, in case the client does not say when they arrive.
	if next(ns.pending) and ns.RetryNames then
		ns.RetryNames()
	end
end

-- Opens the window. tab: the tab to show (default: the last one). auto: opened by a scan, not by
-- the player, so it closes with the auction house.
function ns.OnOpen(tab, auto)
	if not frame then
		Build()
	end
	if type(tab) == "string" then
		ns.db.tab = tab
	end
	ns.autoOpened = auto == true
	if not frame:IsShown() then
		ns.placed = Place()
	end
	frame:Show()
	ns.RefreshWindow(true)
	-- The first screenful of rows arrives one after another; the rest are below the fold.
	local shown = 0
	for _, row in ipairs(frame.rows) do
		if row:IsShown() and shown < 16 then
			shown = shown + 1
			UI.FadeIn(row, 0.025 * shown)
		end
	end
end

-- Forgets where the window was dragged to, and puts it back in its own place.
function ns.ResetPlace()
	ns.db.pos = nil
	if frame then
		ns.placed = Place()
	end
end

function ns.WindowShown()
	return frame ~= nil and frame:IsShown()
end

function ns.WindowFrame()
	return frame
end

-- -------------------------------------------------------------------- the auction house button

-- A small button above the auction house's top right corner: how many items moved and how many
-- bargains there are. A click opens or closes the window. It belongs to the auction house frame,
-- so it shows and hides with it.
function ns.UpdateButton()
	local ah = AuctionHouseFrame
	local b = ns.ahButton
	if not (ns.enabled and ns.db.showButton and type(ah) == "table" and root.HasAuctionator()) then
		if b then
			b:Hide()
		end
		return
	end
	if not b then
		b = UI.Button(ah, "Market Movers", 170, function()
			if ns.WindowShown() then
				frame:Hide()
			else
				ns.OnOpen()
			end
		end)
		b:SetPoint("BOTTOMRIGHT", ah, "TOPRIGHT", -28, 0)
		UI.Tip(b, function()
			return "Market Movers", { "What is priced unusually since Auctionator's last scan: movers, bargains and your bags. Click to open or close." }
		end)
		ns.ahButton = b
	end
	local rep = ns.Report()
	local text = "Market Movers"
	if rep.state == "ok" then
		text = ("Movers: %d"):format(rep.moved)
		if rep.bargains > 0 then
			text = text .. (", %d %s"):format(rep.bargains, rep.bargains == 1 and "bargain" or "bargains")
		end
	end
	b:SetText(text)
	b.text = text
	b:Show()
end
