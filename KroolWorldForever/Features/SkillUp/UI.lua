-- Skill-Up Odds: the crafting window's side of it. A measured chance beside each recipe's skill-up
-- arrow (with the numbers behind it on hover), and a Next Skill Point panel docked to the right of
-- the professions window that ranks learned recipes by the gold a skill point costs on average.
-- Advice only: clicking a row selects the recipe; crafting stays the player's click.

local _, root = ...
local ns = root.Feature("skillup")
local UI = root.UI

local Num, Call = ns.Num, ns.Call
local PANEL_ROWS = 8

local BAND_HEX = { orange = "ffff8040", yellow = "ffffff00", green = "ff40bf40", grey = "ff808080" }
local BAND_NAME = { orange = "orange", yellow = "yellow", green = "green", grey = "grey" }

local function Hex(band, text)
	return "|c" .. (BAND_HEX[band] or "ffffffff") .. text .. "|r"
end

local function Pct(x)
	return ("%d%%"):format(math.floor(x * 100 + 0.5))
end

local function Grey(text)
	return "|cffaaaaaa" .. text .. "|r"
end

-- -------------------------------------------------------------------- text

-- The short label beside the arrow: "63%", or "?%" while its range is still being measured.
function ns.OddsText(o)
	if not o or o.capped or o.band == "grey" then
		return nil
	end
	if o.chance then
		return Hex(o.band, Pct(o.chance))
	end
	return Grey("?%")
end

local function PerPointText(o)
	if o.perPoint then
		if o.perPoint < 0 then
			return "|cff33ff99+" .. root.Money(-o.perPoint) .. "|r" .. Grey(" a point")
		end
		return root.Money(o.perPoint) .. Grey(" a point")
	end
	if o.craft and o.craft.net then
		return Grey("measuring")
	end
	return Grey("no price")
end

local SOURCE = { vendor = "vendor", ah = "auction" }

-- Tooltip title and lines for one evaluated recipe.
function ns.TipLines(o)
	local lines = {}
	local function add(t)
		lines[#lines + 1] = t
	end
	local r = o.r
	local title
	if o.capped then
		title = "Skill-Up Odds: at your skill cap"
	elseif o.chance and not o.rule then
		title = "Skill-Up Odds: " .. Hex(o.band, Pct(o.chance)) .. " measured"
	elseif o.chance then
		title = "Skill-Up Odds: " .. Hex(o.band, Pct(o.chance))
	else
		title = "Skill-Up Odds: still measuring"
	end
	add(
		("%s at %d, %s at %d, %s at %d. Your skill: %d."):format(
			Hex("yellow", "Yellow"),
			r.y,
			Hex("green", "green"),
			ns.Green(r),
			Hex("grey", "grey"),
			r.g,
			o.skill or 0
		)
	)
	if o.capped then
		add("No point can come until you train the next rank.")
	elseif o.band == "orange" and o.rule then
		add("Orange always gives a point (the game's rule).")
		if (o.n or 0) > 0 then
			add(Grey(("Measured so far: %d of %d crafts gave a point."):format(o.up, o.n)))
		end
	elseif o.chance then
		local where = o.bin and ("at " .. ns.BinRange(o.bin) .. " of the way from yellow to grey") or "on orange recipes"
		add(("Measured on your account: %d of %d crafts gave a point %s."):format(o.up, o.n, where))
		add(Grey(("Likely between %s and %s."):format(Pct(o.lo), Pct(o.hi))))
		if o.pts and o.pts > o.up then
			add(Grey(("Some gave two points: %.2f points a craft on average."):format(o.perCraft)))
		end
	else
		add(
			("Still measuring this part of the range (%s from yellow to grey): %d of %d crafts so far."):format(
				o.bin and ns.BinRange(o.bin) or "?",
				o.n or 0,
				ns.MIN_SHOWN
			)
		)
		add(Grey("Every yellow or green craft on any of your characters counts."))
	end
	local rc = ns.Stats().recipes[o.id]
	if rc and rc.n > 0 then
		add(Grey(("This recipe: %d of %d crafts gave a point."):format(rc.up, rc.n)))
	end
	local c = o.craft
	if c then
		add(" ")
		if c.cost then
			local parts = {}
			for _, rg in ipairs(c.reagents) do
				parts[#parts + 1] = ("%s%s x%d (%s)"):format(UI.ItemIcon(rg.id, 14), ns.ItemName(rg.id), rg.qty, SOURCE[rg.source] or "?")
			end
			add("A craft costs " .. root.Money(c.cost) .. Grey(": " .. table.concat(parts, ", ")))
			if c.resale and c.resale > 0 then
				add("The result sells for " .. root.Money(c.resale) .. Grey(" (" .. (SOURCE[c.resaleSource] or "vendor") .. ")"))
			end
			if o.perPoint then
				add("A point costs " .. PerPointText(o) .. Grey(" on average"))
			end
		else
			add("|cffff9955No price for " .. tostring(c.missing) .. "|r" .. Grey(": scan the auction house or visit a vendor that sells it."))
		end
	end
	return title, lines
end

local function ShowTip(owner, o)
	if not (GameTooltip and o) then
		return
	end
	local title, lines = ns.TipLines(o)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title, 1, 0.82, 0)
	for _, line in ipairs(lines) do
		GameTooltip:AddLine(line, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

-- -------------------------------------------------------------------- recipe rows

local function RowInfo(node)
	local data = type(node) == "table" and node.GetData and node:GetData() or nil
	local info = type(data) == "table" and data.recipeInfo or nil
	return type(info) == "table" and info or nil
end

-- Runs after Blizzard's own row setup (ScrollBox OnInitializedFrame): the measured chance at the
-- row's right edge, the recipe name kept clear of it.
local function DecorateRow(_, row, node)
	if type(row) ~= "table" or not row.CreateFontString then
		return
	end
	local fs = row.kwfOdds
	if not fs then
		fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		fs:SetJustifyH("RIGHT")
		row.kwfOdds = fs
		local hit = CreateFrame("Button", nil, row)
		hit:SetAllPoints(fs)
		if hit.SetPropagateMouseClicks then
			hit:SetPropagateMouseClicks(true) -- a click still selects the recipe
		end
		hit:SetScript("OnEnter", function(self)
			pcall(function()
				local o = ns.Evaluate(row.kwfRecipe, nil, nil, true)
				ShowTip(self, o)
			end)
		end)
		hit:SetScript("OnLeave", function()
			if GameTooltip then
				GameTooltip:Hide()
			end
		end)
		row.kwfHit = hit
	end
	fs:Hide()
	row.kwfHit:Hide()
	row.kwfRecipe = nil
	if not (ns.enabled and ns.db and ns.db.list) then
		return
	end
	local info = RowInfo(node)
	if not info or not info.learned or not info.canSkillUp then
		return
	end
	local id = Num(info.recipeID)
	local o = id and ns.Evaluate(id, info, nil, false)
	local text = ns.OddsText(o)
	if not text then
		return
	end
	fs:SetText(text)
	fs:Show()
	row.kwfHit:Show()
	row.kwfRecipe = id
	local label = row.Label
	local width = Num(row.GetWidth and row:GetWidth())
	local textWidth = Num(fs.GetStringWidth and fs:GetStringWidth()) or 24
	if label and width and label.GetWidth then
		local skill = row.SkillUps and Num(row.SkillUps:GetWidth()) or 0
		local count = row.Count and row.Count.IsShown and row.Count:IsShown() and Num(row.Count:GetStringWidth()) or 0
		local room = width - skill - count - textWidth - 22
		local current = Num(label:GetWidth())
		if current and room > 20 and current > room then
			label:SetWidth(room)
		end
	end
end
ns.DecorateRow = DecorateRow -- test seam

local function RecipeBox()
	local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
	local list = page and page.RecipeList
	return list and list.ScrollBox
end

-- Redraws the rows on screen (an option changed, a craft was counted).
function ns.RedecorateRows()
	local box = RecipeBox()
	if box and box.ForEachFrame then
		box:ForEachFrame(function(frame, node)
			pcall(DecorateRow, nil, frame, node)
		end)
	end
end

-- -------------------------------------------------------------------- next point panel

local panel, tab
local refreshQueued = false

local function SelectRecipe(id)
	if C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
		pcall(C_TradeSkillUI.OpenRecipe, id)
	end
end

local function BuildRow(parent, i)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(40)
	b:SetPoint("TOPLEFT", 0, -(i - 1) * 42)
	b:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
	b.best = UI.Selected(b) -- the cheapest point stands out
	UI.Hover(b)
	b.rank = UI.Text(b, "GameFontNormalSmall", "CENTER")
	b.rank:SetPoint("LEFT", 2, 0)
	b.rank:SetWidth(16)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(30, 30)
	b.icon:SetPoint("LEFT", 20, 0)
	b.name = UI.Text(b, "GameFontNormal")
	b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 6, -1)
	b.name:SetPoint("RIGHT", b, "RIGHT", -4, 0)
	b.name:SetWordWrap(false)
	b.cost = UI.Text(b, "GameFontHighlight", "RIGHT")
	b.cost:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 5)
	b.detail = UI.Text(b, "GameFontHighlightSmall")
	b.detail:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 6, 1)
	b.detail:SetPoint("RIGHT", b.cost, "LEFT", -6, 0)
	b.detail:SetWordWrap(false)
	b:SetScript("OnEnter", function(self)
		pcall(ShowTip, self, self.o)
	end)
	b:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	b:SetScript(
		"OnClick",
		UI.Safe(function(self)
			if self.o then
				UI.Sound("click")
				SelectRecipe(self.o.id)
			end
		end, ns)
	)
	return b
end

-- Forever's crafting window has a column of profession tabs down its right edge (Camelot
-- Blizzard_ProfessionsFrame.xml: ProfessionsOverviewTab at TOPRIGHT y -60, then the shown
-- rightProfessionTabs below it, each a LargeSideTabButtonTemplate). The panel docks past that
-- column, and its own tab joins the bottom of it. Returns the column's first and lowest shown tab.
local function SideTabs()
	local pf = ProfessionsFrame
	local first = pf and pf.ProfessionsOverviewTab
	if type(first) ~= "table" or type(first.GetWidth) ~= "function" then
		return nil
	end
	local last = first
	if type(pf.rightProfessionTabs) == "table" then
		for _, t in ipairs(pf.rightProfessionTabs) do
			if type(t) == "table" and t ~= tab and type(t.IsShown) == "function" and t:IsShown() then
				last = t
			end
		end
	end
	return first, last
end

local function DockPanel()
	local first = SideTabs()
	local column = first and Num(Call(first.GetWidth, first)) or 0
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", column + 2, 0)
end

local function PlaceTab()
	if not tab then
		return
	end
	local _, last = SideTabs()
	tab:ClearAllPoints()
	if last then
		tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2) -- the same step as Blizzard's tabs
	else
		tab:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 4, -60)
	end
end

-- The panel is as tall as its rows: title bar, the rows (40 high, 42 apart), a small margin.
local PANEL_TOP, PANEL_BOTTOM, ROW_STEP = 30, 8, 42

local function PanelHeight(rows)
	return PANEL_TOP + math.max(rows, 1) * ROW_STEP - 2 + PANEL_BOTTOM
end

local function RangesReady()
	local st, ready = ns.Stats(), 0
	for i = 1, ns.BINS do
		if st.bins[i].n >= ns.MIN_SHOWN then
			ready = ready + 1
		end
	end
	return ready
end

local function BuildPanel()
	local f = CreateFrame("Frame", "KroolWorldForeverSkillUpPanel", ProfessionsFrame, "ButtonFrameTemplate")
	f:SetSize(300, PanelHeight(1))
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	if ButtonFrameTemplate_HidePortrait then
		pcall(ButtonFrameTemplate_HidePortrait, f)
	end
	if f.SetTitle then
		f:SetTitle("Next Skill Point")
	end
	if f.CloseButton and f.CloseButton.HookScript then
		f.CloseButton:HookScript(
			"OnClick",
			UI.Safe(function()
				root.SetOption(ns, "panel", false)
			end, ns)
		)
	end
	-- Just the title bar and the list: the inset where Blizzard's ButtonFrameTemplate_HideAttic and
	-- _HideButtonBar put it (PANEL_INSET_TOP_OFFSET -24, PANEL_INSET_BOTTOM_OFFSET 4). The skill is
	-- on the crafting window's own bar; the rest is in the tooltips.
	local inset = f.Inset
	if type(inset) == "table" and inset.ClearAllPoints then
		inset:ClearAllPoints()
		inset:SetPoint("TOPLEFT", 4, -PANEL_TOP + 6)
		inset:SetPoint("BOTTOMRIGHT", -6, 4)
	end
	local list = CreateFrame("Frame", nil, f)
	list:SetPoint("TOPLEFT", 10, -PANEL_TOP)
	list:SetPoint("BOTTOMRIGHT", -12, PANEL_BOTTOM)
	f.rows = {}
	for i = 1, PANEL_ROWS do
		f.rows[i] = BuildRow(list, i)
	end
	f.message = UI.Text(list, "GameFontDisable", "CENTER")
	f.message:SetPoint("TOPLEFT", 0, -2)
	f.message:SetPoint("BOTTOMRIGHT", 0, 2)
	UI.ToastAt(f, 0, -36) -- just under the panel, clear of the rows
	-- The kit's open animation; no open sound: the crafting window just played its own.
	f:SetScript("OnShow", function(self)
		local intro = UI.Intro(self)
		if intro then
			pcall(intro.Restart, intro)
		end
		self.fresh = true -- the next fill staggers its rows in
		ns.QueueRefresh()
	end)
	f:Hide() -- shown by UpdatePanel, so even the first show animates
	return f
end

local TAB_TIP = "Ranks your recipes by the gold the next skill point costs: a craft's cost over the points it gives."

local function TabLines()
	return {
		TAB_TIP,
		("Odds measured on this account: %d of %d ranges ready."):format(RangesReady(), ns.BINS),
		Grey(ns.db.panel and "Click to hide the panel." or "Click to show the panel."),
	}
end

local function TogglePanel()
	root.SetOption(ns, "panel", not ns.db.panel)
end

-- A side tab like the profession tabs above it (Blizzard's own template and art). It toggles the
-- panel; the template plays the tab sound. Where the window has no tab column, a plain icon button.
local function BuildTab()
	local ok, t = pcall(CreateFrame, "Frame", nil, ProfessionsFrame, "LargeSideTabButtonTemplate")
	if ok and type(t) == "table" and type(t.Icon) == "table" and type(t.SetCustomOnMouseUpHandler) == "function" then
		t.Icon:SetTexture(ns.icon)
		if type(t.SetFillToInterior) == "function" then
			pcall(t.SetFillToInterior, t, true) -- as the profession tabs: the icon fills the tab
		end
		if type(t.SetChecked) == "function" then
			pcall(t.SetChecked, t, false) -- "selected" belongs to the open profession
		end
		t.tooltipText = "Next Skill Point"
		function t.GetTooltipTextSetupFunction()
			return function(tooltip)
				tooltip:SetText("Next Skill Point")
				for _, line in ipairs(TabLines()) do
					tooltip:AddLine(line, 1, 1, 1, true)
				end
				return true
			end
		end
		t:SetCustomOnMouseUpHandler(UI.Safe(function(_, button, upInside)
			if button == "LeftButton" and upInside ~= false then
				TogglePanel()
			end
		end, ns))
		return t
	end
	local b = UI.IconButton(ProfessionsFrame, 32, ns.icon, TogglePanel)
	UI.Tip(b, function()
		return "Next Skill Point", TabLines()
	end)
	return b
end

-- One line in place of the rows (nil: the rows are showing), and the panel fits what it shows.
local function Fit(rows, message)
	panel.message:SetText(message or "")
	panel.message:SetShown(message ~= nil)
	panel:SetHeight(PanelHeight(rows))
end

function ns.RefreshPanel()
	if not (panel and panel:IsShown()) then
		return
	end
	local list, prof = ns.Rank()
	local fresh = panel.fresh
	panel.fresh = false
	local flash = ns.flashRecipe
	ns.flashRecipe = nil
	for _, row in ipairs(panel.rows) do
		row:Hide()
		row.o = nil
		row.best:Hide()
	end
	if not prof then
		Fit(1, "Open a crafting profession.")
		return
	end
	if prof.max and prof.max > 0 and prof.lvl >= prof.max then
		Fit(1, "|cffff9955At your cap: train the next rank.|r")
		return
	end
	local shown = 0
	for i, o in ipairs(list or {}) do
		if i > PANEL_ROWS then
			break
		end
		local row = panel.rows[i]
		row.o = o
		row.rank:SetText(o.perPoint and ("|cffffd100" .. i .. "|r") or Grey(tostring(i)))
		UI.SetIcon(row.icon, o.icon or ns.icon)
		row.name:SetText(o.name or "?")
		row.cost:SetText(PerPointText(o))
		local bits = {}
		local odds = ns.OddsText(o)
		if odds then
			bits[#bits + 1] = odds
		end
		if o.craft and o.craft.net then
			bits[#bits + 1] = root.Money(o.craft.net) .. Grey(" a craft")
		end
		local have = C_TradeSkillUI and Num(Call(C_TradeSkillUI.GetCraftableCount, o.id))
		if have and have > 0 then
			bits[#bits + 1] = Grey("[" .. have .. "]")
		end
		row.detail:SetText(table.concat(bits, Grey("  ")))
		row.best:SetShown(i == 1 and o.perPoint ~= nil)
		row:Show()
		if fresh then
			UI.FadeIn(row, (i - 1) * 0.04) -- rows arrive one after another
		elseif flash and o.id == flash then
			UI.Flash(row.cost) -- the recipe just crafted: its numbers moved
		end
		shown = shown + 1
	end
	if shown == 0 then
		Fit(1, "No learned recipe here can give a point.")
	else
		Fit(shown, nil)
	end
end

function ns.QueueRefresh()
	if refreshQueued or not (panel and panel:IsShown()) then
		return -- one refresh at a time, and only for a panel on screen
	end
	if not (C_Timer and C_Timer.After) then
		pcall(ns.RefreshPanel)
		return
	end
	refreshQueued = true
	C_Timer.After(0.2, function()
		refreshQueued = false
		pcall(ns.RefreshPanel)
	end)
end

function ns.UpdatePanel()
	if not ProfessionsFrame then
		return
	end
	local want = ns.enabled and ns.db.panel and ProfessionsFrame:IsShown()
	if want and not panel then
		panel = BuildPanel()
	end
	if not tab and ns.enabled then
		tab = BuildTab()
		if type(ProfessionsFrame.RefreshRightTabs) == "function" and hooksecurefunc then
			-- Learning or dropping a profession changes the column; follow its new bottom.
			hooksecurefunc(ProfessionsFrame, "RefreshRightTabs", function()
				pcall(PlaceTab)
			end)
		end
	end
	if panel then
		if want then
			DockPanel()
		end
		panel:SetShown(want and true or false)
	end
	if tab then
		PlaceTab()
		tab:SetShown(ns.enabled and true or false)
	end
	if want then
		ns.QueueRefresh()
	end
end

function ns.Panel()
	return panel
end

-- -------------------------------------------------------------------- hooking the window

local hooked = false
function ns.SetupProfessions()
	if hooked then
		return true
	end
	local box = RecipeBox()
	if not (box and ScrollUtil and ScrollUtil.AddInitializedFrameCallback) then
		return false
	end
	hooked = true
	ScrollUtil.AddInitializedFrameCallback(box, UI.Safe(DecorateRow, ns), ns, false)
	ns.RedecorateRows()
	return true
end

-- -------------------------------------------------------------------- definition

ns.title = "Skill-Up Odds"
ns.description = "In the crafting window: the measured chance each recipe gives a skill point, and a Next Skill Point panel "
	.. "that ranks your recipes by the gold a point costs. The chance is measured from your own crafts: Blizzard never "
	.. "published it, so until enough crafts are in, a recipe shows ?%."
ns.icon = "Interface\\Icons\\Trade_BlackSmithing"
ns.blurb = "Measured skill-up odds and the cheapest next point"
ns.options = {
	{
		key = "list",
		type = "toggle",
		label = "Show Odds In The Recipe List",
		tooltip = "Puts the measured skill-up chance beside each recipe's arrow. Hover it for the crafts behind it and what a point costs.",
		default = true,
	},
	{
		key = "panel",
		type = "toggle",
		label = "Show The Next Skill Point Panel",
		tooltip = "Docks a panel beside the crafting window that ranks your learned recipes by the gold a skill point costs on average.",
		default = true,
	},
	{
		key = "resale",
		type = "toggle",
		label = "Subtract What The Result Sells For",
		tooltip = "Takes the crafted item's vendor price off the cost of a craft.",
		default = true,
	},
	{
		key = "resaleAH",
		type = "toggle",
		label = "Value The Result At Auction",
		tooltip = "Uses the crafted item's Auctionator price (after the 5% cut) when it beats the vendor price. Only if you will really sell it there.",
		default = false,
	},
	{
		key = "learn",
		type = "toggle",
		label = "Measure Your Crafts",
		tooltip = "Records each craft's skill before and after, account-wide. This is where the chances come from.",
		default = true,
	},
}
ns.slash = { "/kwu", "/skillup" }

local function CounterText(c)
	if c.n == 0 then
		return Grey("none yet")
	end
	local lo, hi = ns.Wilson(c.up, c.n)
	return ("%d of %d gave a point (%s, likely %s-%s)"):format(c.up, c.n, Pct(c.up / c.n), Pct(lo), Pct(hi))
end

local function PrintTable()
	local st = ns.Stats()
	ns:Print("measured on this account (where your skill was between a recipe's yellow and grey):")
	print("  " .. Hex("orange", "orange") .. ": " .. CounterText(st.orange))
	local empty = {}
	for i = 1, ns.BINS do
		local c = st.bins[i]
		if c.n > 0 then
			local band = (i <= ns.BINS / 2) and "yellow" or "green"
			print("  " .. Hex(band, ns.BinRange(i)) .. ": " .. CounterText(c) .. (c.n < ns.MIN_SHOWN and Grey(" (measuring)") or ""))
		else
			empty[#empty + 1] = ns.BinRange(i)
		end
	end
	if #empty > 0 then
		print("  " .. Grey("no crafts yet at " .. table.concat(empty, ", ")))
	end
	print("  " .. Hex("grey", "grey") .. ": " .. CounterText(st.grey))
end

local function PrintStatus()
	local st = ns.Stats()
	local vendors = 0
	for _ in pairs(ns.db.vendor) do
		vendors = vendors + 1
	end
	ns:Print(("recipe data from build %s; %d crafts logged, %d skipped (no reading before the cast, capped), %d where the arrow disagreed."):format(
		tostring(ns.Data and ns.Data.build),
		#st.log,
		st.skipped,
		st.mismatch
	))
	print(("  skill read through: %s; vendor prices known: %d; Auctionator: %s"):format(
		tostring(ns.source or "not yet"),
		vendors,
		root.HasAuctionator() and "yes" or "no"
	))
	local prof = ns.OpenProfession()
	if prof then
		print(("  open now: %s %d / %d (bonus %d)"):format(prof.name or "?", prof.lvl, prof.max or 0, prof.mod or 0))
	end
	if ns.last then
		print(("  last craft: recipe %d at %d, +%d (%s)"):format(ns.last.id, ns.last.before, ns.last.gain, tostring(ns.last.band)))
	end
end

function ns.OnSlash(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "options" or msg == "config" then
		root.OpenSettings(ns)
	elseif msg == "status" then
		PrintStatus()
	elseif msg == "panel" then
		root.SetOption(ns, "panel", not ns.db.panel)
	elseif msg == "help" then
		ns:Print("/kwu - the measured odds; /kwu status; /kwu panel shows or hides the Next Skill Point panel; /kwu options.")
	else
		PrintTable()
	end
end

function ns.HubStatus()
	local st = ns.Stats()
	local total = st.orange.n + st.grey.n
	for i = 1, ns.BINS do
		total = total + st.bins[i].n
	end
	if total == 0 then
		return "|cffff9955No crafts measured yet: craft a yellow or green recipe|r"
	end
	return ("%d crafts measured; odds ready in %d of %d ranges"):format(total, RangesReady(), ns.BINS)
end

-- -------------------------------------------------------------------- lifecycle

function ns.OnRecorded(last)
	if ns.justReady then
		local bin = ns.justReady
		ns.justReady = nil
		local c = ns.Stats().bins[bin]
		ns:Print(("measured odds now show at %s of a recipe's range: %d of %d crafts gave a point."):format(ns.BinRange(bin), c.up, c.n))
		if panel and panel:IsShown() then
			UI.Toast(panel, ("Odds ready at %s: %s"):format(ns.BinRange(bin), Pct(c.up / c.n)))
		end
	end
	ns.flashRecipe = last and last.id
	ns.ForgetProfession()
	ns.QueueRefresh()
end

function ns.OnLoad()
	ns.db.vendor = type(ns.db.vendor) == "table" and ns.db.vendor or {}
	ns.Stats()
	ns:RegisterEvent("UNIT_SPELLCAST_START", function(_, unit, guid, spellID)
		ns.OnCastStart(unit, guid, spellID)
	end)
	ns:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, guid, spellID)
		ns.OnCastSucceeded(unit, guid, spellID)
	end)
	ns:RegisterEvent("SKILL_LINES_CHANGED", function()
		ns.OnSkillChanged()
		ns.ForgetProfession()
		ns.QueueRefresh()
	end)
	ns:RegisterEvent("TRADE_SKILL_LIST_UPDATE", function()
		ns.OnSkillChanged()
		ns.ForgetProfession()
		ns.QueueRefresh()
	end)
	ns:RegisterEvent("ADDON_LOADED", function(_, name)
		if name == "Blizzard_Professions" then
			ns.SetupProfessions()
		end
	end)
	ns:RegisterEvent("TRADE_SKILL_SHOW", function()
		ns.SetupProfessions()
		ns.ForgetProfession()
		ns.UpdatePanel()
	end)
	ns:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED", function()
		ns.ForgetProfession()
		ns.QueueRefresh()
	end)
	ns:RegisterEvent("TRADE_SKILL_CLOSE", function()
		if panel then
			panel:Hide()
		end
	end)
	ns:RegisterEvent("BAG_UPDATE_DELAYED", function()
		if panel and panel:IsShown() then
			ns.QueueRefresh()
		end
	end)
	ns:RegisterEvent("MERCHANT_SHOW", function()
		if ns.LearnMerchant() > 0 then
			ns.QueueRefresh()
		end
	end)
end

function ns.OnEnable()
	ns.SetupProfessions()
	ns.UpdatePanel()
	ns.RedecorateRows()
end

function ns.OnDisable()
	ns.UpdatePanel()
	ns.RedecorateRows()
end

function ns.OnOptionChanged(key)
	if key == "list" then
		ns.RedecorateRows()
	elseif key == "panel" then
		ns.UpdatePanel()
	else
		ns.QueueRefresh()
		ns.RedecorateRows()
	end
end
