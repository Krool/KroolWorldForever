-- Setups window. Left: saved setups, then one automatic snapshot per character. Right: the selected
-- setup as a "this setup -> this character" card, the parts to copy (after an apply each row shows
-- how it went), and the actions along the bottom. The window opens by itself in two cases: in "new
-- character" mode on a character's first login when other setups exist, and on the result after the
-- automatic apply to a brand-new character. That apply runs from a timer, where the client blocks
-- C_UI.Reload, so the window carries the Reload Now button. Built on first open, never at file scope.

local _, root = ...
local ns = root.Feature("setups")
local unpack = unpack or table.unpack -- the client's Lua 5.1 global; table.unpack in the test runner

local W, H, LIST_W, ROW_H, PART_H = 720, 520, 250, 40, 28
local frame -- built on first open
local selected, onboarding
local applyParts = {} -- part key -> checked
local result -- { setupId, report, auto, undo }: the last apply or undo, shown until the selection changes
local needReload = false -- an apply changed Edit Mode or the addon list; the reload itself clears it
local ready = false -- true once bars, macros and bindings have loaded after login

-- Art. The atlases and interface textures are all used by Blizzard's own UI on the forever branch
-- (build 70790); the icons are classic-era icon files.
local ART = {
	addon = "Interface\\Icons\\INV_Misc_Bag_10",
	classes = "Interface\\TargetingFrame\\UI-Classes-Circles",
	unknown = "Interface\\Icons\\INV_Misc_QuestionMark",
	arrow = "Interface\\MoneyFrame\\Arrow-Right-Up",
	warn = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew",
	refresh = "Interface\\Buttons\\UI-RefreshButton",
	delete = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}
local ATLAS = {
	ok = "groupfinder-icon-greencheckmark",
	fail = "groupfinder-icon-redx",
	star = "collections-icon-favorites",
	undo = "common-icon-undo",
	plus = "communities-icon-addgroupplus",
}
local PART_ICON = {
	bars = "Interface\\Icons\\Spell_Fire_FlameBolt",
	bindings = "Interface\\Icons\\INV_Misc_Key_03",
	macros = "Interface\\Icons\\INV_Misc_QuestionMark",
	editmode = "Interface\\Icons\\INV_Misc_Map_01",
	cvars = "Interface\\Icons\\INV_Misc_Gear_01",
	addons = "Interface\\Icons\\INV_Box_01",
	kwf = ART.addon,
}
-- What each part holds and what applying it does: the row's tooltip.
local PART_TIP = {
	bars = "Spells, items, macros and mounts on your bars, and which extra bars are on. Spells this character does not know are skipped.",
	bindings = "Every keybinding. Replaces this character's.",
	macros = "Creates the setup's macros this character does not have. Never changes or deletes yours.",
	editmode = "Where your HUD sits. Added as a new layout for this character.",
	cvars = "Interface options Blizzard saves on its servers. Not graphics or sound.",
	addons = "Which addons are on for this character.",
	kwf = "This addon's own switches and options. These are account-wide.",
}
local LEVEL_COLOR = { ok = { 0.55, 0.9, 0.55 }, warn = { 1, 0.82, 0 }, fail = { 1, 0.4, 0.35 } }
local DIM = 0.5

local function Safe(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			ns:Print("|cffff5555error|r: " .. tostring(err))
		end
	end
end

local function Ago(t)
	if not t then
		return "?"
	end
	local d = math.max(0, time() - t)
	if d < 90 then
		return "just now"
	elseif d < 3600 then
		return math.floor(d / 60) .. "m ago"
	elseif d < 86400 then
		return math.floor(d / 3600) .. "h ago"
	elseif d < 14 * 86400 then
		return math.floor(d / 86400) .. "d ago"
	end
	return date("%b %d", t)
end

local function ClassText(classFile, text)
	local ok, color = pcall(C_ClassColor.GetClassColor, classFile or "")
	if ok and color and color.WrapTextInColorCode then
		return color:WrapTextInColorCode(text)
	end
	return text
end

-- An automatic snapshot is shown under its character's name.
local function Title(s)
	return tostring(s.auto and s.source or s.name)
end

local function Label(key)
	for _, p in ipairs(ns.PARTS) do
		if p.key == key then
			return p.label
		end
	end
	return key
end

local function PartCount(s, key)
	local n = s.counts and s.counts[key] or 0
	local unit = {
		bars = "slots",
		bindings = "keys",
		macros = "macros",
		cvars = "settings",
		addons = "addons",
		kwf = "features",
	}
	if key == "editmode" then
		local e = s.parts and s.parts.editmode
		if not e then
			return "not saved"
		end
		local which = e.preset == 1 and "built-in Modern" or e.preset == 2 and "built-in Classic"
			or e.preset and "built-in" or ('"' .. tostring(e.name) .. '"')
		local options = 0
		for _ in pairs(e.account or {}) do
			options = options + 1
		end
		return options > 0 and (which .. " + " .. options .. " options") or which
	end
	return n .. " " .. unit[key]
end

-- -------------------------------------------------------------------- art helpers

local function SetIcon(tex, file) -- an Interface\Icons file with its border trimmed
	tex:SetTexture(file)
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function ClassIcon(tex, classFile)
	local coords = CLASS_ICON_TCOORDS and classFile and CLASS_ICON_TCOORDS[classFile]
	if coords then
		tex:SetTexture(ART.classes)
		tex:SetTexCoord(unpack(coords))
	else
		SetIcon(tex, ART.unknown)
	end
end

local function Status(tex, level)
	if level == "warn" then
		tex:SetTexture(ART.warn)
		tex:SetTexCoord(0, 1, 0, 1)
	else
		tex:SetAtlas(ATLAS[level] or ATLAS.ok)
	end
end

-- fn(widget) returns the tooltip's title and its lines (or nothing for no tooltip).
local function Tip(widget, fn)
	widget:SetScript("OnEnter", function(self)
		local ok, title, lines = pcall(fn, self)
		if not ok or not title or not GameTooltip then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 0.82, 0)
		for _, line in ipairs(lines or {}) do
			GameTooltip:AddLine(line, 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	widget:SetMotionScriptsWhileDisabled(true) -- a disabled button still says why
end

-- -------------------------------------------------------------------- popups

local function Popups()
	if StaticPopupDialogs.KWF_SETUPS_NAME then
		return
	end
	local function EditBox(dialog)
		return (dialog.GetEditBox and dialog:GetEditBox()) or dialog.editBox
	end
	StaticPopupDialogs.KWF_SETUPS_NAME = {
		text = "%s",
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = true,
		maxLetters = 48,
		OnShow = function(dialog, data)
			local box = EditBox(dialog)
			if box then
				box:SetText(data and data.default or "")
				box:HighlightText()
			end
		end,
		OnAccept = function(dialog, data)
			local box = EditBox(dialog)
			local text = box and strtrim(box:GetText() or "") or ""
			if text ~= "" and data and data.fn then
				Safe(data.fn)(text)
			end
		end,
		EditBoxOnEnterPressed = function(box)
			local dialog = box:GetParent()
			local which = StaticPopupDialogs[dialog.which]
			if which and which.OnAccept then
				which.OnAccept(dialog, dialog.data)
			end
			dialog:Hide()
		end,
		EditBoxOnEscapePressed = function(box)
			box:GetParent():Hide()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
	StaticPopupDialogs.KWF_SETUPS_CONFIRM = {
		text = "%s",
		button1 = YES,
		button2 = NO,
		OnAccept = function(_, data)
			if data and data.fn then
				Safe(data.fn)()
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
end

local function AskName(prompt, default, fn)
	Popups()
	StaticPopup_Show("KWF_SETUPS_NAME", prompt, nil, { default = default, fn = fn })
end

local function Confirm(text, fn)
	Popups()
	StaticPopup_Show("KWF_SETUPS_CONFIRM", text, nil, { fn = fn })
end

-- -------------------------------------------------------------------- widgets

local function Text(parent, font, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

-- A standard red button; with an atlas, a small icon sits before its label.
local function Button(parent, text, width, onClick, atlas)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	b:SetScript("OnClick", Safe(onClick))
	b.kwfIcon = false
	if atlas then
		local icon = b:CreateTexture(nil, "ARTWORK")
		icon:SetSize(14, 14)
		icon:SetAtlas(atlas)
		local label = b:GetFontString()
		if label then
			label:ClearAllPoints()
			label:SetPoint("CENTER", 8, 0)
			icon:SetPoint("RIGHT", label, "LEFT", -4, 0)
		end
		b.kwfIcon = icon
	end
	return b
end

-- A bare icon that glows under the mouse.
local function IconButton(parent, size, file, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.kwfIcon = b:CreateTexture(nil, "ARTWORK")
	b.kwfIcon:SetAllPoints()
	b.kwfIcon:SetTexture(file)
	local glow = b:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	glow:SetTexture(file)
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.5)
	b:SetScript("OnClick", Safe(onClick))
	return b
end

local function Enable(b, on)
	on = on and true or false
	b:SetEnabled(on)
	if b.kwfIcon then -- set by Button and IconButton; false when there is none
		b.kwfIcon:SetDesaturated(not on)
		b.kwfIcon:SetAlpha(on and 1 or 0.45)
	end
end

local function Hover(parent) -- a faint highlight for clickable rows
	local hl = parent:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.06)
	return hl
end

-- -------------------------------------------------------------------- state

local Refresh -- forward

local function Select(id)
	selected = id
	if result and result.setupId ~= id then
		result = nil
	end
	wipe(applyParts)
	local s = ns.Get(id)
	if s then
		for _, p in ipairs(ns.PARTS) do
			applyParts[p.key] = s.parts and s.parts[p.key] ~= nil
		end
	end
	Refresh()
end

local function AnyChecked(s)
	for _, p in ipairs(ns.PARTS) do
		if applyParts[p.key] and s.parts and s.parts[p.key] ~= nil then
			return true
		end
	end
	return false
end

local function PrintReport(report)
	for _, line in ipairs(report.lines or {}) do
		print("  " .. line)
	end
end

local function Onboarded()
	local c = ns.db.chars[ns.CharKey()]
	if c then
		c.onboarded, c.askAgain = true, nil
	end
	onboarding = false
end

local function DoApply()
	local s = ns.Get(selected)
	if not s then
		return
	end
	if not ready then
		ns:Print("still loading this character; try again in a few seconds")
		return
	end
	Confirm(
		("Apply %s to %s?\nUndo puts back what it replaces."):format(Title(s), UnitName("player") or ns.CharKey()),
		function()
			local report = ns.Apply(s, applyParts, ns.db)
			result = { setupId = s.id, report = report }
			PrintReport(report)
			if report.ok then
				ns:Print("applied " .. Title(s))
				Onboarded()
				needReload = needReload or report.reload
				ns.ReloadIfNeeded(s, report) -- a click: the client allows the reload here
			end
			Refresh()
		end
	)
end

local function DoUndo()
	Confirm("Undo the last apply on this character?\nMacros it created stay.", function()
		local report = ns.Undo()
		if report then
			result = { setupId = selected, report = report, undo = true }
			PrintReport(report)
			needReload = needReload or report.reload
		end
		Refresh()
	end)
end

-- -------------------------------------------------------------------- building

local function PartTip(cb)
	local lines = {}
	local r = cb.result
	if r then
		local color = LEVEL_COLOR[r.level] or LEVEL_COLOR.ok
		local function hex(v)
			return math.floor(v * 255 + 0.5)
		end
		lines[1] = ("|cff%02x%02x%02x%s|r"):format(hex(color[1]), hex(color[2]), hex(color[3]), r.text)
		for i, d in ipairs(r.details) do
			if i > 14 then
				lines[#lines + 1] = ("|cffaaaaaa...and %d more in chat|r"):format(#r.details - 14)
				break
			end
			lines[#lines + 1] = "|cffcccccc" .. d .. "|r"
		end
	else
		lines[1] = PART_TIP[cb.key]
		if ns.RELOAD_PARTS[cb.key] then
			lines[2] = "|cffffd100Takes effect after a UI reload.|r"
		end
	end
	return Label(cb.key), lines
end

local function Build()
	frame = CreateFrame("Frame", "KroolWorldForeverSetupsFrame", UIParent, "ButtonFrameTemplate")
	frame:SetSize(W, H)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH") -- under the confirm popups (DIALOG)
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)
	frame:Hide()
	tinsert(UISpecialFrames, frame:GetName()) -- Escape closes it
	frame:SetScript("OnHide", function()
		if onboarding then
			-- Closed with X or Escape: same as Not Now.
			local c = ns.db.chars[ns.CharKey()]
			if c then
				c.askAgain = true
			end
			onboarding = false
		end
	end)
	if frame.SetTitle then
		frame:SetTitle("Krool World Setups")
	end
	if frame.SetPortraitToAsset then
		pcall(frame.SetPortraitToAsset, frame, ART.addon)
	end

	-- One line under the title: what to do now, or what just happened.
	frame.banner = Text(frame, "GameFontHighlight")
	frame.banner:SetPoint("TOPLEFT", 68, -35)
	frame.banner:SetWidth(W - 84)
	frame.banner:SetWordWrap(false)

	-- Left: the list, in the template's inset.
	local inset = frame.Inset
	if type(inset) == "table" then
		inset:ClearAllPoints()
		inset:SetPoint("TOPLEFT", 4, -60)
		inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", LIST_W, 26)
	end
	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -80)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", LIST_W - 26, 48)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(LIST_W - 36, 10)
	scroll:SetScrollChild(content)
	frame.content, frame.rows, frame.headers = content, {}, {}
	frame.empty = Text(content, "GameFontDisable", "CENTER")
	frame.empty:SetPoint("TOP", 0, -30)
	frame.empty:SetWidth(LIST_W - 50)

	-- Right: the selected setup.
	local x = LIST_W + 12
	local RW = W - x - 14
	local right = CreateFrame("Frame", nil, frame)
	right:SetPoint("TOPLEFT", x, -62)
	right:SetPoint("BOTTOMRIGHT", -14, 30)
	frame.right = right

	-- The card: this setup -> this character.
	local card = CreateFrame("Frame", nil, right, "InsetFrameTemplate")
	card:SetPoint("TOPLEFT")
	card:SetPoint("TOPRIGHT")
	card:SetHeight(64)
	frame.card = card
	card.src = card:CreateTexture(nil, "ARTWORK")
	card.src:SetSize(40, 40)
	card.src:SetPoint("LEFT", 12, 0)
	frame.name = Text(card, "GameFontNormalLarge")
	frame.name:SetPoint("TOPLEFT", card.src, "TOPRIGHT", 8, -3)
	frame.name:SetWidth(150)
	frame.name:SetWordWrap(false)
	frame.source = Text(card, "GameFontHighlightSmall")
	frame.source:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -5)
	frame.source:SetWidth(150)
	frame.source:SetWordWrap(false)
	frame.source:SetTextColor(0.7, 0.7, 0.7)
	card.arrow = card:CreateTexture(nil, "ARTWORK")
	card.arrow:SetSize(26, 26)
	card.arrow:SetPoint("CENTER", card, "LEFT", 226, 0)
	card.arrow:SetTexture(ART.arrow)
	card.dst = card:CreateTexture(nil, "ARTWORK")
	card.dst:SetSize(40, 40)
	card.dst:SetPoint("LEFT", 246, 0)
	card.dstName = Text(card, "GameFontNormalLarge")
	card.dstName:SetPoint("TOPLEFT", card.dst, "TOPRIGHT", 8, -3)
	card.dstName:SetWidth(RW - 302)
	card.dstName:SetWordWrap(false)
	card.dstInfo = Text(card, "GameFontHighlightSmall")
	card.dstInfo:SetPoint("TOPLEFT", card.dstName, "BOTTOMLEFT", 0, -5)
	card.dstInfo:SetTextColor(0.7, 0.7, 0.7)

	-- Click the name to rename it.
	frame.rename = CreateFrame("Button", nil, card)
	frame.rename:SetPoint("TOPLEFT", frame.name, "TOPLEFT", -3, 3)
	frame.rename:SetSize(156, 22)
	Hover(frame.rename)
	frame.rename:SetScript("OnClick", Safe(function()
		local s = ns.Get(selected)
		AskName("Rename this setup:", s.name, function(name)
			ns.Rename(s.id, name)
			Refresh()
		end)
	end))
	Tip(frame.rename, function()
		local s = ns.Get(selected)
		if not s then
			return
		end
		if s.auto then
			return Title(s), { "This character's automatic snapshot. It keeps itself up to date while you play." }
		end
		return s.name, { "Click to rename." }
	end)

	-- Tools under the card: the new-character star on the left, update and delete on the right.
	frame.default = CreateFrame("Button", nil, right)
	frame.default:SetSize(210, 22)
	frame.default:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 4, -6)
	Hover(frame.default)
	frame.default.icon = frame.default:CreateTexture(nil, "ARTWORK")
	frame.default.icon:SetSize(18, 18)
	frame.default.icon:SetPoint("LEFT", 2, 0)
	frame.default.icon:SetAtlas(ATLAS.star)
	frame.default.label = Text(frame.default, "GameFontHighlightSmall")
	frame.default.label:SetPoint("LEFT", frame.default.icon, "RIGHT", 5, 0)
	frame.default:SetScript("OnClick", Safe(function()
		ns.SetDefault(selected)
		Refresh()
	end))
	Tip(frame.default, function()
		local on = selected ~= nil and ns.db.default == selected
		return "Use For New Characters", {
			ns.db.autoDefault
					and "A brand-new character (level 1, first login) gets this setup by itself, and this window shows what changed."
				or "Preselected when this window opens on a new character.",
			on and "|cff33ff99On.|r Click to turn it off." or "Only one setup can have the star.",
		}
	end)

	frame.delete = IconButton(right, 20, ART.delete, function()
		local s = ns.Get(selected)
		local text = s.auto and "Delete %s? It comes back at that character's next login while Auto Snapshot is on."
			or "Delete %s? This cannot be undone."
		Confirm(text:format(Title(s)), function()
			ns.Delete(s.id)
			selected = nil
			Refresh()
		end)
	end)
	frame.delete:SetPoint("TOPRIGHT", card, "BOTTOMRIGHT", -4, -7)
	Tip(frame.delete, function()
		return "Delete", { "Removes this setup. Your characters are not changed." }
	end)

	frame.overwrite = IconButton(right, 18, ART.refresh, function()
		local s = ns.Get(selected)
		Confirm(("Update %s from %s?\nIts saved bars, keys and settings are replaced."):format(Title(s), ns.CharKey()), function()
			ns.Update(s.id)
			Refresh()
		end)
	end)
	frame.overwrite:SetPoint("RIGHT", frame.delete, "LEFT", -10, 0)
	Tip(frame.overwrite, function()
		local s = ns.Get(selected)
		if s and s.auto then
			return "Update", { "Automatic snapshots update themselves." }
		end
		return "Update From " .. (UnitName("player") or "This Character"), {
			"Replaces this setup with this character's current bars, keybindings, macros, layout and settings.",
		}
	end)

	-- What to copy: one row per part. After an apply, each row shows how that part went.
	local partsHeader = Text(right, "GameFontNormal")
	partsHeader:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 4, -40)
	partsHeader:SetText("What To Copy")
	frame.partsHeader = partsHeader
	frame.checks = {}
	for i, p in ipairs(ns.PARTS) do
		local row = CreateFrame("Button", nil, right)
		row:SetPoint("TOPLEFT", partsHeader, "BOTTOMLEFT", -4, -6 - (i - 1) * PART_H)
		row:SetSize(RW, PART_H - 2)
		Hover(row)
		local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		cb:SetSize(24, 24)
		cb:SetPoint("LEFT", 2, 0)
		cb.key, cb.row = p.key, row
		cb.status = row:CreateTexture(nil, "OVERLAY")
		cb.status:SetSize(18, 18)
		cb.status:SetPoint("CENTER", cb, "CENTER")
		cb.icon = row:CreateTexture(nil, "ARTWORK")
		cb.icon:SetSize(22, 22)
		cb.icon:SetPoint("LEFT", cb, "RIGHT", 4, 0)
		SetIcon(cb.icon, PART_ICON[p.key])
		cb.label = Text(row, "GameFontHighlight")
		cb.label:SetPoint("LEFT", cb.icon, "RIGHT", 8, 0)
		cb.label:SetText(p.label)
		cb.count = Text(row, "GameFontHighlightSmall", "RIGHT")
		cb.count:SetPoint("RIGHT", row, "RIGHT", -24, 0)
		cb.count:SetWidth(220)
		cb.count:SetWordWrap(false)
		if ns.RELOAD_PARTS[p.key] then
			cb.reload = row:CreateTexture(nil, "OVERLAY")
			cb.reload:SetSize(14, 14)
			cb.reload:SetPoint("RIGHT", -5, 0)
			cb.reload:SetTexture(ART.refresh)
		end
		cb:SetScript("OnClick", function(self)
			applyParts[p.key] = self:GetChecked() and true or false
			result = nil -- back from the result to choosing
			Refresh()
		end)
		row:SetScript("OnClick", function()
			if cb:IsShown() and cb:IsEnabled() then
				cb:Click()
			end
		end)
		local function tip()
			return PartTip(cb)
		end
		Tip(row, tip)
		Tip(cb, tip)
		frame.checks[i] = cb
	end

	frame.warnIcon = right:CreateTexture(nil, "ARTWORK")
	frame.warnIcon:SetSize(16, 16)
	frame.warnIcon:SetPoint("TOPLEFT", partsHeader, "BOTTOMLEFT", 0, -12 - #ns.PARTS * PART_H)
	frame.warnIcon:SetTexture(ART.warn)
	frame.warning = Text(right, "GameFontNormalSmall")
	frame.warning:SetPoint("LEFT", frame.warnIcon, "RIGHT", 4, 0)
	frame.warning:SetWidth(RW - 30)
	frame.warning:SetTextColor(1, 0.75, 0.3)

	-- Shown after an apply that changed Edit Mode or the addon list, until the UI reloads.
	local bar = CreateFrame("Frame", nil, right)
	bar:SetPoint("BOTTOMLEFT", 0, 4)
	bar:SetPoint("BOTTOMRIGHT", 0, 4)
	bar:SetHeight(34)
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(1, 0.82, 0, 0.12)
	bar.icon = bar:CreateTexture(nil, "ARTWORK")
	bar.icon:SetSize(20, 20)
	bar.icon:SetPoint("LEFT", 8, 0)
	bar.icon:SetTexture(ART.refresh)
	bar.text = Text(bar, "GameFontHighlight")
	bar.text:SetPoint("LEFT", bar.icon, "RIGHT", 6, 0)
	bar.text:SetText("Reload to finish Edit Mode and addons.")
	frame.reloadBar = bar
	frame.reload = Button(bar, "Reload Now", 110, function()
		C_UI.Reload()
	end)
	frame.reload:SetPoint("RIGHT", -6, 0)

	-- Bottom bar: New Setup on the left; Apply (and Undo, or the new-character choices) on the right.
	frame.saveNew = Button(frame, "New Setup", 130, function()
		AskName("Name this setup:", ns.CharKey() .. " " .. date("%b %d"), function(name)
			local s = ns.SaveNew(name)
			ns:Print("saved " .. name)
			Select(s.id)
		end)
	end, ATLAS.plus)
	frame.saveNew:SetPoint("BOTTOMLEFT", 6, 4)
	Tip(frame.saveNew, function()
		return "New Setup", {
			("Saves %s's bars, keybindings, macros, layout and settings as a new setup."):format(UnitName("player") or "this character"),
		}
	end)

	frame.apply = Button(frame, "Apply", 190, DoApply)
	frame.apply:SetPoint("BOTTOMRIGHT", -8, 4)
	Tip(frame.apply, function()
		local s = ns.Get(selected)
		if not s then
			return
		end
		if InCombatLockdown() then
			return "Apply", { "|cffff6060Not in combat.|r" }
		elseif not AnyChecked(s) then
			return "Apply", { "Tick at least one part to copy." }
		end
		return "Apply", {
			("Copies the ticked parts of %s onto %s. Undo puts back what it replaces."):format(Title(s), UnitName("player") or "this character"),
		}
	end)

	frame.undo = Button(frame, "Undo", 96, DoUndo, ATLAS.undo)
	frame.undo:SetPoint("RIGHT", frame.apply, "LEFT", -6, 0)
	Tip(frame.undo, function()
		local u = ns.db.undo and ns.db.undo[ns.CharKey()]
		if not u then
			return "Undo", { "Nothing to undo on this character." }
		end
		return "Undo", {
			("Puts back what applying %s replaced (%s)."):format(tostring(u.from), Ago(u.at)),
			"Macros it created stay.",
		}
	end)

	frame.notNow = Button(frame, "Not Now", 90, function()
		local c = ns.db.chars[ns.CharKey()]
		if c then
			c.askAgain = true -- offer again at the next login
		end
		onboarding = false
		frame:Hide()
	end)
	frame.notNow:SetPoint("RIGHT", frame.apply, "LEFT", -6, 0)
	Tip(frame.notNow, function()
		return "Not Now", { "Asks again at this character's next login." }
	end)
	frame.never = Button(frame, "Don't Ask Again", 120, function()
		Onboarded()
		frame:Hide()
	end)
	frame.never:SetPoint("RIGHT", frame.notNow, "LEFT", -6, 0)
	Tip(frame.never, function()
		return "Don't Ask Again", { "This character is not offered a setup again. /kws still opens this window." }
	end)
end

-- -------------------------------------------------------------------- the list

local function Row(i)
	local row = frame.rows[i]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, frame.content)
	row:SetSize(LIST_W - 36, ROW_H - 2)
	row.sel = row:CreateTexture(nil, "BACKGROUND")
	row.sel:SetAllPoints()
	row.sel:SetColorTexture(1, 0.82, 0, 0.16)
	Hover(row)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(28, 28)
	row.icon:SetPoint("LEFT", 4, 0)
	row.star = row:CreateTexture(nil, "OVERLAY")
	row.star:SetSize(16, 16)
	row.star:SetPoint("RIGHT", -4, 0)
	row.star:SetAtlas(ATLAS.star)
	row.line1 = Text(row, "GameFontNormal")
	row.line1:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 7, 0)
	row.line1:SetWidth(LIST_W - 100)
	row.line1:SetWordWrap(false) -- long names end in "..."
	row.line2 = Text(row, "GameFontDisableSmall")
	row.line2:SetPoint("TOPLEFT", row.line1, "BOTTOMLEFT", 0, -3)
	row.line2:SetWidth(LIST_W - 100)
	row.line2:SetWordWrap(false)
	row:SetScript("OnClick", function(self)
		Select(self.id)
	end)
	Tip(row, function(self)
		local s = ns.Get(self.id)
		if not s then
			return
		end
		local lines = {
			("%s, level %s"):format(tostring(s.source or "?"), tostring(s.level or "?")),
			"Saved " .. (s.updated and date("%b %d, %H:%M", s.updated) or "?"),
		}
		if s.auto then
			lines[#lines + 1] = "Automatic snapshot, kept up to date while you play."
		end
		if ns.db.default == s.id then
			lines[#lines + 1] = "|cffffd100Used for new characters.|r"
		end
		return ClassText(s.class, Title(s)), lines
	end)
	frame.rows[i] = row
	return row
end

local function Header(i)
	local h = frame.headers[i]
	if not h then
		h = Text(frame.content, "GameFontNormalSmall")
		frame.headers[i] = h
	end
	return h
end

local function RefreshList(list)
	local named, auto = {}, {}
	for _, s in ipairs(list) do
		if s.auto then
			auto[#auto + 1] = s
		else
			named[#named + 1] = s
		end
	end
	local y, r, h = 0, 0, 0
	local function header(text)
		h = h + 1
		local fs = Header(h)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", 4, y - 4)
		fs:SetText(text)
		fs:Show()
		y = y - 20
	end
	local function rows(group)
		for _, s in ipairs(group) do
			r = r + 1
			local row = Row(r)
			row.id = s.id
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, y)
			ClassIcon(row.icon, s.class)
			row.line1:SetText(ClassText(s.class, Title(s)))
			row.line2:SetText(("Lv %s · %s"):format(tostring(s.level or "?"), Ago(s.updated)))
			row.star:SetShown(ns.db.default == s.id)
			row.sel:SetShown(s.id == selected)
			row:Show()
			y = y - ROW_H
		end
	end
	if #named > 0 then
		header("Saved Setups")
		rows(named)
		y = y - 6
	end
	if #auto > 0 then
		header("Characters")
		rows(auto)
	end
	for i = r + 1, #frame.rows do
		frame.rows[i]:Hide()
	end
	for i = h + 1, #frame.headers do
		frame.headers[i]:Hide()
	end
	frame.empty:SetText(onboarding and "Nothing to offer yet." or "No setups yet.\n\nClick New Setup to save this character.")
	frame.empty:SetShown(#list == 0)
	frame.content:SetHeight(math.max(10, -y))
end

-- -------------------------------------------------------------------- refresh

local function BannerText(s)
	if result then
		local report = result.report
		if not report.ok then
			return "|cffff8040" .. tostring(report.lines[1]) .. "|r"
		elseif result.undo then
			return "|cff33ff99Undo finished.|r The full report is in chat."
		elseif s and result.setupId == s.id then
			return ("%s %s. Hover a row for details."):format(
				result.auto and "|cff33ff99New character:|r applied" or "|cff33ff99Applied|r",
				Title(s)
			)
		end
	end
	if onboarding then
		return "|cffffd100New character!|r Pick a setup to start from."
	elseif not s then
		return "Save this character as a setup, then apply it on your others."
	end
	return "Pick a setup, tick what to copy, then Apply."
end

local function RefreshCard(s, listEmpty)
	local card = frame.card
	local has = s ~= nil
	if has then
		ClassIcon(card.src, s.class)
	else
		SetIcon(card.src, ART.unknown)
	end
	frame.name:SetText(has and ClassText(s.class, Title(s)) or (listEmpty and "No setups yet" or ""))
	local source = ""
	if has then
		local bits = { s.auto and "Auto snapshot" or tostring(s.source or "?") }
		if s.level then
			bits[#bits + 1] = "Lv " .. tostring(s.level)
		end
		bits[#bits + 1] = Ago(s.updated)
		source = table.concat(bits, " · ")
	end
	frame.source:SetText(source)
	local _, myClass = UnitClass("player")
	ClassIcon(card.dst, myClass)
	card.dstName:SetText(ClassText(myClass, UnitName("player") or "?"))
	card.dstInfo:SetText(("You · Lv %s"):format(tostring(UnitLevel("player") or "?")))
	frame.rename:SetEnabled(has and not s.auto)

	local isDefault = has and ns.db.default == s.id
	frame.default:SetShown(has)
	frame.default.icon:SetDesaturated(not isDefault)
	frame.default.icon:SetAlpha(isDefault and 1 or 0.6)
	frame.default.label:SetText(isDefault and "|cffffd100Used for new characters|r" or "Use for new characters")
	frame.overwrite:SetShown(has)
	frame.delete:SetShown(has)
	Enable(frame.overwrite, has and not s.auto)
	Enable(frame.delete, has)
end

local function RefreshParts(s)
	local has = s ~= nil
	local showResult = has and result and not result.undo and result.setupId == s.id and result.report.ok
	frame.partsHeader:SetShown(has)
	frame.partsHeader:SetText(showResult and "What Changed" or "What To Copy")
	for _, cb in ipairs(frame.checks) do
		local key = cb.key
		local present = has and s.parts and s.parts[key] ~= nil
		local r = showResult and result.report.parts and result.report.parts[key] or nil
		cb.row:SetShown(has)
		cb.result = r or false
		if showResult then
			cb:Hide()
			cb.status:SetShown(r ~= nil)
			if r then
				Status(cb.status, r.level)
				cb.count:SetText(r.text)
				cb.count:SetTextColor(unpack(LEVEL_COLOR[r.level] or LEVEL_COLOR.ok))
			else
				cb.count:SetText("not copied")
				cb.count:SetTextColor(DIM, DIM, DIM)
			end
		else
			cb:SetShown(has)
			cb.status:Hide()
			cb:SetEnabled(present)
			cb:SetChecked(present and applyParts[key] or false)
			cb.count:SetText(present and PartCount(s, key) or "not saved")
			cb.count:SetTextColor(0.65, 0.65, 0.65)
		end
		local lit = (showResult and r ~= nil) or (not showResult and present)
		cb.label:SetTextColor(lit and 1 or DIM, lit and 1 or DIM, lit and 1 or DIM)
		cb.icon:SetDesaturated(not lit)
		if ns.RELOAD_PARTS[key] then
			cb.reload:SetShown(present and not showResult)
		end
	end

	local _, myClass = UnitClass("player")
	local warning = ""
	if has and not showResult and s.class and s.class ~= myClass and applyParts.bars then
		warning = "Different class: spells this character does not know are skipped."
	end
	frame.warning:SetText(warning)
	frame.warnIcon:SetShown(warning ~= "")
end

local function RefreshActions(s)
	local has = s ~= nil
	local inCombat = InCombatLockdown()
	frame.apply:SetText("Apply To " .. (UnitName("player") or "Me"))
	Enable(frame.apply, has and AnyChecked(s) and not inCombat)
	local undo = ns.db.undo and ns.db.undo[ns.CharKey()]
	frame.undo:SetShown(not onboarding)
	Enable(frame.undo, undo ~= nil and not inCombat)
	frame.notNow:SetShown(onboarding and true or false)
	frame.never:SetShown(onboarding and true or false)
	frame.reloadBar:SetShown(needReload)
	frame.reload:SetShown(needReload)
end

function Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	local list = onboarding and ns.Offers() or ns.List()
	if not ns.Get(selected) then
		selected = nil
		if onboarding and ns.Get(ns.db.default) then
			selected = ns.db.default
		elseif list[1] then
			selected = list[1].id
		end
		if selected then
			return Select(selected)
		end
	end
	local s = ns.Get(selected)
	RefreshList(list)
	RefreshCard(s, #list == 0)
	RefreshParts(s)
	RefreshActions(s)
	frame.banner:SetText(BannerText(s))
end
ns.Refresh = Refresh

-- Opens the window. asOnboarding: new-character mode (offers setups, Not Now / Don't Ask Again).
-- setupId and report: open on that setup showing the result of an apply that already ran.
function ns.Open(asOnboarding, setupId, report)
	if not frame then
		Build()
	end
	onboarding = asOnboarding and true or false
	result, selected = nil, nil
	if ready and ns.db.autosave and not InCombatLockdown() then
		pcall(ns.AutoSnapshot) -- show this character as it is right now
	end
	frame:Show()
	if setupId and ns.Get(setupId) then
		Select(setupId)
		if report then
			result = { setupId = setupId, report = report, auto = true }
		end
	end
	Refresh()
end

function ns.Toggle()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		ns.Open(false)
	end
end

-- -------------------------------------------------------------------- definition

ns.title = "Setups"
ns.description = "Save a character's action bars, keybindings, macros, Edit Mode layout, interface settings, "
	.. "addon list and Krool World settings, and apply them to another character. /kws opens the window."
ns.options = {
	{
		key = "picker",
		type = "toggle",
		label = "Offer A Setup On New Characters",
		tooltip = "The first time a character logs in with this addon, open the Setups window so you can start "
			.. "from a saved setup. Preselects the setup marked for new characters.",
		default = true,
	},
	{
		key = "autoDefault",
		type = "toggle",
		label = "Apply The Default Setup Automatically",
		tooltip = "When a setup is marked Use For New Characters, a brand-new character (level 1, first login) "
			.. "gets it a few seconds after logging in, and the Setups window shows what changed. Characters "
			.. "that are not brand-new get the picker instead. Off: the picker opens instead.",
		default = true,
	},
	{
		key = "autoReload",
		type = "toggle",
		label = "Reload Automatically After Apply",
		tooltip = "Edit Mode layouts and the addon list take effect after a UI reload. On: Apply reloads by "
			.. "itself when needed. Off, and after the automatic apply on a new character (the game allows a "
			.. "reload only from a click): a Reload Now button appears.",
		default = true,
	},
	{
		key = "autosave",
		type = "toggle",
		label = "Auto Snapshot Each Character",
		tooltip = "Keep one automatic setup per character, refreshed after login and shortly after you change "
			.. "bars, keybindings, macros, Edit Mode or settings, so any character can copy any other.",
		default = true,
	},
	{
		key = "perCharBinds",
		type = "toggle",
		label = "Applied Keybindings Are Per Character",
		tooltip = "On: applying a setup saves its keybindings for this character only. Off: for the whole "
			.. "account, which changes every character that uses account keybindings.",
		default = true,
	},
	{
		key = "clearEmpty",
		type = "toggle",
		label = "Clear Bar Slots The Setup Leaves Empty",
		tooltip = "On: an apply makes your bars match the setup exactly. Off: only fills slots, keeping "
			.. "anything already in a slot the setup leaves empty.",
		default = true,
	},
}
ns.slash = { "/kws", "/kwsetups" }

function ns.OnSlash(msg)
	local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()
	if cmd == "" then
		ns.Toggle()
	elseif cmd == "save" then
		local s = ns.SaveNew(rest ~= "" and rest or (ns.CharKey() .. " " .. date("%b %d")))
		ns:Print("saved " .. s.name)
		Refresh()
	elseif cmd == "list" then
		for _, s in ipairs(ns.List()) do
			print(("  %s (%s, %s)%s"):format(s.name, tostring(s.source), Ago(s.updated), ns.db.default == s.id and " default" or ""))
		end
	elseif cmd == "undo" then
		local report = ns.Undo()
		ns:Print(report and table.concat(report.lines, "; ") or "nothing to undo on this character")
		if report and report.reload then
			needReload = true
			ns:Print("type /reload to finish (Edit Mode, addon list)")
		end
		Refresh()
	else
		ns:Print("/kws opens the window; /kws save [name], /kws list, /kws undo")
	end
end

ns.OnOpen = function()
	ns.Open(false)
end

-- Edit Mode and the addon list only take effect after a reload. Keep the report across it so the
-- player still sees what changed (printed again after login). Call only from a click: anywhere else
-- the client blocks C_UI.Reload (ADDON_ACTION_BLOCKED, seen on live 2026-11-04).
function ns.ReloadIfNeeded(setup, report)
	if not (report and report.reload and ns.db.autoReload) then
		return false
	end
	ns.db.pendingReport = { name = setup.name, lines = report.lines, at = time() }
	ns:Print("reloading the UI to finish (Edit Mode, addon list)")
	C_UI.Reload()
	return true
end

-- Every part the setup holds.
local function AllParts(s)
	local which = {}
	for _, p in ipairs(ns.PARTS) do
		which[p.key] = s.parts and s.parts[p.key] ~= nil
	end
	return which
end

-- Positive evidence of a character's very first login: level 1 with no experience yet. A character
-- this addon has simply not seen before (installed later, played with Setups off, a default chosen
-- later) can have years of bars and bindings on it, so it gets the picker, never an apply.
local function BrandNew()
	local level, xp = UnitLevel("player"), UnitXP("player")
	if issecretvalue and (issecretvalue(level) or issecretvalue(xp)) then
		return false
	end
	return level == 1 and xp == 0
end

local function Settle(wasNew)
	ready = true
	local pending = ns.db.pendingReport
	if pending then
		ns.db.pendingReport = nil
		ns:Print(("applied %s:"):format(tostring(pending.name)))
		for _, line in ipairs(pending.lines or {}) do
			print("  " .. line)
		end
	end
	local c = ns.db.chars[ns.CharKey()]
	local fresh = c and not c.onboarded and (wasNew or c.askAgain)
	-- A brand-new character with a default chosen: apply it now, no picker. Choosing "Use For New
	-- Characters" is the player's standing OK for this. Snapshot first so the undo point is real.
	local default = ns.Get(ns.db.default)
	-- Compare by id, not name: an "(earlier character)" setup shares this name but is a fine default.
	if fresh and wasNew and ns.db.autoDefault and default and default.id ~= c.auto and BrandNew() then
		if InCombatLockdown() then
			c.askAgain = true
		else
			if ns.db.autosave then
				ns.AutoSnapshot()
			end
			local report = ns.Apply(default, AllParts(default), ns.db)
			if report.ok then
				c.onboarded, c.askAgain = true, nil
				ns:Print(("new character: applied your setup %s"):format(Title(default)))
				PrintReport(report)
				-- Show what changed. A reload it needs waits for the player's click on Reload Now:
				-- this runs from a timer, where the client blocks C_UI.Reload.
				needReload = needReload or report.reload
				if report.reload then
					ns:Print("click Reload Now in the Setups window to finish (Edit Mode, addon list)")
				end
				ns.Open(false, default.id, report)
				return
			end
		end
	end
	if ns.db.autosave then
		ns.AutoSnapshot()
	end
	if fresh and ns.db.picker and #ns.Offers() > 0 then
		if InCombatLockdown() then
			c.askAgain = true -- logged in fighting: offer next time instead of never
		else
			ns.Open(true)
		end
	end
	Refresh()
end
ns.Settle = Settle -- test seam: what runs a few seconds after login

local started = false
function ns.OnEnable()
	if started then
		return
	end
	started = true
	local wasNew = ns.Identify()
	-- Action bars, macros and bindings arrive from the server after login; wait before reading them.
	C_Timer.After(8, Safe(function()
		if ns.enabled then
			Settle(wasNew)
		end
	end))
end

-- Keep the auto snapshot current while playing. Not on logout: by PLAYER_LOGOUT the client has
-- already emptied the action bars and reset Edit Mode to a built-in layout (seen on the stress test).
local pending = false
local function SnapshotSoon()
	if not ready or pending or not ns.db.autosave then
		return
	end
	pending = true
	C_Timer.After(10, Safe(function()
		pending = false
		if ns.enabled and ready and ns.db.autosave and not InCombatLockdown() then
			ns.AutoSnapshot()
			Refresh()
		end
	end))
end
ns.SnapshotSoon = SnapshotSoon
for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS", "UPDATE_MACROS", "EDIT_MODE_LAYOUTS_UPDATED", "CVAR_UPDATE" }) do
	ns:RegisterEvent(event, SnapshotSoon)
end
ns:RegisterEvent("PLAYER_REGEN_DISABLED", function()
	Refresh() -- grey out Apply and Undo in combat
end)
ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	Refresh()
end)

root.public.Setups = {
	List = function()
		return ns.List()
	end,
	Open = function()
		ns.Open(false)
	end,
}
