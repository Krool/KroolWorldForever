-- Quest Trash window (/fqt, the hub): every quest item in your bags, and the bank while it is
-- open, sorted into Can Delete, Keep and Still Checking. Hovering a row shows the item's tooltip,
-- which carries the verdict and its quests. Advice only: nothing here deletes or moves items.
-- Built on first open, never at file scope.

local _, root = ...
local ns = root.Feature("questtrash")
local FQT = ns.FQT
local UI = root.UI

local W, H, ROW_H, HEAD_H = 420, 470, 24, 26
local frame -- built on first open

local GROUPS = {
	{ title = "Can Delete", color = { 1, 0.4, 0.35 }, atlas = UI.ATLAS.fail, verdicts = { safe = true, notyours = true } },
	{ title = "Keep", color = { 0.55, 0.9, 0.55 }, atlas = UI.ATLAS.ok, verdicts = { active = true, farm = true, maybe = true, keep = true } },
	{ title = "Still Checking", color = { 0.7, 0.7, 0.7 }, atlas = UI.ATLAS.search, verdicts = { pending = true, unknown = true } },
}

-- The row's right column: why, in a few words.
local function Why(e)
	local v = e.verdict
	if v == "safe" then
		if FQT.IsQuestItem(e.id) == false then
			return "No quest needs it"
		end
		return FQT.SafeReason(e.links) == "closed" and "Quests closed" or "Quests done"
	end
	return ({
		notyours = "Not for your race/class",
		active = "Active quest",
		farm = "Repeatable quest",
		maybe = "Quest not done",
		keep = "Key item",
		pending = "Checking...",
		unknown = "No quest data",
	})[v] or v
end

local function Row(content, i)
	local row = frame.rows[i]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, content)
	row:SetSize(W - 50, ROW_H - 2)
	UI.Hover(row)
	-- Every other row is a shade darker, so a long list stays easy to follow across.
	row.stripe = row:CreateTexture(nil, "BACKGROUND")
	row.stripe:SetAllPoints()
	row.stripe:SetColorTexture(1, 1, 1, 0.03)
	row.stripe:SetShown(i % 2 == 0)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(20, 20)
	row.icon:SetPoint("LEFT", 4, 0)
	row.name = UI.Text(row, "GameFontHighlight")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.name:SetWidth(W - 220)
	row.name:SetWordWrap(false)
	row.why = UI.Text(row, "GameFontHighlightSmall", "RIGHT")
	row.why:SetPoint("RIGHT", -6, 0)
	row.why:SetWidth(130)
	row.why:SetTextColor(0.7, 0.7, 0.7)
	row:SetScript("OnEnter", function(self)
		if GameTooltip and self.itemID then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID) -- the verdict lines come from the tooltip hook
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	frame.rows[i] = row
	return row
end

-- A group header: its icon, "Can Delete (3)" and a divider line. Hidden and shown as one.
local function Header(content, i)
	local h = frame.headers[i]
	if h then
		return h
	end
	h = UI.Text(content, "GameFontNormal")
	h.icon = content:CreateTexture(nil, "ARTWORK")
	h.icon:SetSize(14, 14)
	h.icon:SetAtlas(GROUPS[i].atlas)
	h.icon:SetPoint("RIGHT", h, "LEFT", -5, 0)
	h.line = UI.Divider(content, W - 70)
	h.line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", -19, -3)
	frame.headers[i] = h
	return h
end

local function ShowHeader(h, on)
	h:SetShown(on)
	h.icon:SetShown(on)
	h.line:SetShown(on)
end

local function Build()
	frame = UI.Window("KroolWorldForeverQuestTrashFrame", "Quest Trash", W, H, ns.icon)
	frame.banner = UI.Text(frame, "GameFontHighlight")
	frame.banner:SetPoint("TOPLEFT", 68, -35)
	frame.banner:SetWidth(W - 84)
	frame.banner:SetWordWrap(false)
	frame.content = UI.ScrollList(frame, -60, 28)
	frame.content:SetWidth(W - 50)
	frame.rows, frame.headers = {}, {}
	frame.empty = UI.Empty(frame.content, UI.ATLAS.ok, W - 80)

	frame.note = UI.Text(frame, "GameFontDisableSmall")
	frame.note:SetPoint("BOTTOMLEFT", 14, 10)
	frame.refresh = UI.Button(frame, "Refresh", 90, function()
		FQT.ClearCache()
		ns.RefreshWindow(true)
		local n = frame.deletable or 0
		UI.Toast(frame, n > 0 and ("Rechecked: %d to delete"):format(n) or "Rechecked: nothing to delete", n > 0 and "warn" or "ok")
	end)
	frame.refresh:SetPoint("BOTTOMRIGHT", -8, 4)
	UI.Tip(frame.refresh, function()
		return "Refresh", { "Checks every item again against your quest log and QuestieDB." }
	end)
	frame.gear = UI.IconButton(frame, 18, UI.GEAR_ICON, function()
		UI.HandOff(frame)
		root.OpenSettings(ns)
	end)
	frame.gear:SetPoint("RIGHT", frame.refresh, "LEFT", -10, 0)
	UI.Tip(frame.gear, function()
		return "Settings", { "Quest Trash's options." }
	end)
end

-- Rebuilds the list. Skipped while the window is closed unless forced.
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
	frame.note:SetText(FQT.BankOpen() and "Bags and bank." or "Bags only. Open your bank to include it.")
	if not ns.ready then
		local ok, info = FQT.ProviderStatus()
		frame.banner:SetText(ok and "Reading quest data..." or ("|cffff5555" .. tostring(info) .. "|r"))
		frame.empty:SetText(ok and "Hover again in a moment." or "Install QuestieDB (a separate download from Questie) and reload.")
		frame.empty.art:SetAtlas(ok and UI.ATLAS.search or UI.ATLAS.fail)
		frame.empty:Show()
		frame.empty.art:Show()
		frame.deletable = 0
		return
	end
	local list = FQT.Collect()
	local y, rowIndex, deletable = -4, 0, 0
	for gi, g in ipairs(GROUPS) do
		local members = {}
		for _, e in ipairs(list) do
			if g.verdicts[e.verdict] then
				members[#members + 1] = e
			end
		end
		table.sort(members, function(a, b)
			return a.name < b.name
		end)
		if gi == 1 then
			deletable = #members
		end
		if #members > 0 then
			local h = Header(frame.content, gi)
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", 26, y - 6)
			h:SetText(("%s (%d)"):format(g.title, #members))
			h:SetTextColor(g.color[1], g.color[2], g.color[3])
			ShowHeader(h, true)
			y = y - HEAD_H
			for _, e in ipairs(members) do
				rowIndex = rowIndex + 1
				local row = Row(frame.content, rowIndex)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, y)
				row.itemID = e.id
				local icon = e.icon
				if not icon then
					local ok, file = pcall(C_Item.GetItemIconByID, e.id)
					icon = ok and file or "Interface\\Icons\\INV_Misc_QuestionMark"
				end
				UI.SetIcon(row.icon, icon)
				row.name:SetText(e.count > 1 and ("%s |cffaaaaaax%d|r"):format(e.name, e.count) or e.name)
				row.why:SetText(Why(e))
				-- The reason takes its group's color, a little softer than the header.
				row.why:SetTextColor(0.55 + g.color[1] * 0.35, 0.55 + g.color[2] * 0.35, 0.55 + g.color[3] * 0.35)
				row:Show()
				y = y - ROW_H
			end
		end
	end
	frame.content:SetHeight(math.max(10, -y + 4))
	frame.deletable = deletable
	frame.empty:SetShown(rowIndex == 0)
	frame.empty.art:SetShown(rowIndex == 0)
	frame.empty.art:SetAtlas(UI.ATLAS.ok)
	frame.empty:SetText("No quest items in your bags.")
	if deletable > 0 then
		frame.banner:SetText(("|cffff5555%d %s you can delete.|r Hover one for why."):format(deletable, deletable == 1 and "item" or "items"))
	elseif rowIndex > 0 then
		frame.banner:SetText("|cff33ff99Nothing to delete.|r Everything here is still needed.")
	else
		frame.banner:SetText("Nothing to sort.")
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
		if row:IsShown() and shown < 14 then
			shown = shown + 1
			UI.FadeIn(row, 0.025 * shown)
		end
	end
end

function ns.WindowFrame()
	return frame
end
