-- Market Movers window (/kwm, the hub, and by itself after the first full scan of an auction
-- house visit): Trade Materials, then Other Items, each sorted by how far the price moved. A row
-- shows the item, its price the day before, its price now, the change and the units listed.
-- Hovering shows the item's tooltip with where "before" came from; a click searches the item in
-- Auctionator while the auction house is open, a shift-click links it in chat. Built on first open.

local _, root = ...
local ns = root.Feature("movers")
local UI = root.UI

local W, H, ROW_H, HEAD_H = 600, 500, 22, 26
-- Column left edges inside a row, and widths.
local COL = {
	name = { 30, 200 },
	was = { 236, 104 },
	now = { 344, 104 },
	change = { 452, 52 },
	qty = { 506, 42 },
}
local GREY = "|cffaaaaaa"
local frame -- built on first open

local SECTIONS = {
	{ key = "trade", title = "Trade Materials", color = { 1, 0.82, 0 } },
	{ key = "other", title = "Other Items", color = { 0.75, 0.75, 0.75 } },
}

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
	row.was = Column(row, "was", "GameFontHighlightSmall")
	row.now = Column(row, "now", "GameFontHighlightSmall")
	row.change = Column(row, "change", "GameFontHighlight")
	row.qty = Column(row, "qty", "GameFontHighlightSmall")
	row:SetScript("OnEnter", function(self)
		local r = self.data
		if not (GameTooltip and r) then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		pcall(GameTooltip.SetItemByID, GameTooltip, r.id)
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine("Now", root.Money(r.now), 1, 0.82, 0, 1, 1, 1)
		GameTooltip:AddDoubleLine(
			("Before (%s, %d %s)"):format(ns.DayText(r.day), r.scans, r.scans == 1 and "scan" or "scans"),
			root.Money(r.before),
			1, 0.82, 0, 1, 1, 1
		)
		GameTooltip:AddDoubleLine("Listed", ("%d (was %d)"):format(r.qty, r.beforeQty), 1, 0.82, 0, 1, 1, 1)
		GameTooltip:AddLine(
			ns.ahOpen and "Click: search it in Auctionator. Shift-click: link it." or "Shift-click: link it.",
			0.6, 0.6, 0.6
		)
		GameTooltip:Show()
	end)
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

-- A section header: "Trade Materials (4)" and a divider line, hidden and shown as one.
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

local function Build()
	frame = UI.Window(root.ID.prefix .. "MarketMoversFrame", "Market Movers", W, H, ns.icon)
	frame.banner = UI.Text(frame, "GameFontHighlight")
	frame.banner:SetPoint("TOPLEFT", 68, -35)
	frame.banner:SetWidth(W - 84)
	frame.banner:SetWordWrap(false)
	-- Column titles over the list.
	frame.cols = {}
	for key, label in pairs({ name = "Item", was = "Before", now = "Now", change = "Change", qty = "Listed" }) do
		local t = UI.Text(frame, "GameFontDisableSmall", key == "name" and "LEFT" or "RIGHT")
		t:SetPoint("TOPLEFT", 14 + COL[key][1], -64)
		t:SetWidth(COL[key][2])
		t:SetText(label)
		frame.cols[key] = t
	end
	frame.content = UI.ScrollList(frame, -78, 28)
	frame.content:SetWidth(W - 50)
	frame.rows, frame.headers = {}, {}
	frame.empty = UI.Empty(frame.content, UI.ATLAS.search, W - 80)

	frame.note = UI.Text(frame, "GameFontDisableSmall")
	frame.note:SetPoint("BOTTOMLEFT", 14, 10)
	frame.refresh = UI.Button(frame, "Refresh", 90, function()
		ns.RefreshWindow(true)
		local n = frame.moved or 0
		UI.Toast(frame, n > 0 and ("%d %s moved"):format(n, n == 1 and "item" or "items") or "Nothing moved", "ok")
	end)
	frame.refresh:SetPoint("BOTTOMRIGHT", -8, 4)
	UI.Tip(frame.refresh, function()
		return "Refresh", { "Redraws the lists from the last scan. Auctionator's next scan updates them by itself." }
	end)
	frame.gear = UI.IconButton(frame, 18, UI.GEAR_ICON, function()
		UI.HandOff(frame)
		root.OpenSettings(ns)
	end)
	frame.gear:SetPoint("RIGHT", frame.refresh, "LEFT", -10, 0)
	UI.Tip(frame.gear, function()
		return "Settings", { "Market Movers' options: what counts as common, the smallest move, rows per list." }
	end)
end

local function Empty(text, atlas)
	frame.empty:SetText(text)
	frame.empty.art:SetAtlas(atlas)
	frame.empty:Show()
	frame.empty.art:Show()
	frame.content:SetHeight(10)
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
	frame.note:SetText(("%s house. Gear left out."):format(ns.Faction()))

	if not root.HasAuctionator() then
		frame.banner:SetText("|cffff5555Needs Auctionator.|r")
		Empty("Market Movers reads the auction house when Auctionator scans it. Install Auctionator and reload.", UI.ATLAS.fail)
		return
	end
	local rep = ns.Report()
	if rep.state == "nodata" then
		frame.banner:SetText("No scan yet.")
		Empty("Open the auction house and let Auctionator scan it (its Scan button, or autoscan). The first scan is the start of the record.", UI.ATLAS.search)
		return
	end
	local scanned = "Last scan " .. ns.DayText(ns.Day(rep.at)) .. " " .. date("%H:%M", rep.at)
	if rep.state == "nobase" then
		frame.banner:SetText(scanned .. ".")
		Empty("Prices are compared with the day before. The first comparison comes with a scan tomorrow.", UI.ATLAS.search)
		return
	end
	frame.banner:SetText(("%s, compared with %s."):format(scanned, ns.DayText(rep.baseDay)))
	frame.moved = rep.moved

	local y, rowIndex = -4, 0
	for si, s in ipairs(SECTIONS) do
		local list = rep[s.key]
		if #list > 0 then
			local h = Header(frame.content, si)
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", 8, y - 6)
			h:SetText(("%s (%d)"):format(s.title, #list))
			h:SetTextColor(s.color[1], s.color[2], s.color[3])
			ShowHeader(h, true)
			y = y - HEAD_H
			for _, r in ipairs(list) do
				rowIndex = rowIndex + 1
				local row = Row(frame.content, rowIndex)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, y)
				row.itemID, row.data = r.id, r
				local ok, file = pcall(C_Item.GetItemIconByID, r.id)
				UI.SetIcon(row.icon, ok and file or "Interface\\Icons\\INV_Misc_QuestionMark")
				row.name:SetText(NameOf(r.id))
				row.was:SetText(root.Money(r.before))
				row.now:SetText(root.Money(r.now))
				row.change:SetText(ns.ChangeText(r.change))
				row.qty:SetText(tostring(r.qty))
				row:Show()
				y = y - ROW_H
			end
		end
	end
	frame.content:SetHeight(math.max(10, -y + 4))
	if rowIndex == 0 then
		Empty(("Nothing moved %d%% or more since %s."):format(tonumber(ns.db.minChange) or 0, ns.DayText(rep.baseDay)), UI.ATLAS.ok)
	end
end

function ns.OnOpen()
	if not frame then
		Build()
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

function ns.WindowShown()
	return frame ~= nil and frame:IsShown()
end

function ns.WindowFrame()
	return frame
end
