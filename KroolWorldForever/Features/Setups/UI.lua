-- Setups window: list of saved setups on the left, the selected one on the right (what it holds,
-- which parts to apply, and the actions). The same window opens in "new character" mode on a
-- character's first login when other setups exist. Built on first open, never at file scope.

local _, root = ...
local ns = root.Feature("setups")

local W, H, LIST_W, ROW_H = 700, 470, 250, 36
local frame -- built on first open
local selected, onboarding
local applyParts = {} -- part key -> checked
local lastReport

local function Safe(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			ns:Print("|cffff5555error|r: " .. tostring(err))
		end
	end
end

local function When(t)
	return t and date("%b %d, %H:%M", t) or "?"
end

local function ClassText(classFile, text)
	local ok, color = pcall(C_ClassColor.GetClassColor, classFile or "")
	if ok and color and color.WrapTextInColorCode then
		return color:WrapTextInColorCode(text)
	end
	return text
end

local function PartCount(s, key)
	local n = s.counts and s.counts[key] or 0
	local unit = {
		bars = "slots",
		bindings = "keys",
		macros = "macros",
		editmode = "layout",
		cvars = "changed",
		addons = "addons",
	}
	if key == "editmode" then
		local e = s.parts and s.parts.editmode
		if not e then
			return "none"
		end
		return e.preset and "built-in" or ('"' .. tostring(e.name) .. '"')
	end
	return n .. " " .. unit[key]
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

-- -------------------------------------------------------------------- building

local function Button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	b:SetScript("OnClick", Safe(onClick))
	return b
end

local function Text(parent, font, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

local Refresh -- forward

local function Select(id)
	selected = id
	wipe(applyParts)
	local s = ns.Get(id)
	if s then
		for _, p in ipairs(ns.PARTS) do
			applyParts[p.key] = s.parts and s.parts[p.key] ~= nil
		end
	end
	Refresh()
end

local function Build()
	frame = CreateFrame("Frame", "KroolWorldForeverSetupsFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(W, H)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)
	frame:Hide()
	tinsert(UISpecialFrames, frame:GetName()) -- Escape closes it

	frame.title = Text(frame, "GameFontHighlight", "CENTER")
	frame.title:SetPoint("TOP", 0, -6)
	frame.title:SetText("Krool World Setups")

	-- Left: the list.
	local listHeader = Text(frame, "GameFontNormal")
	listHeader:SetPoint("TOPLEFT", 14, -32)
	listHeader:SetText("Saved setups")

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -52)
	scroll:SetSize(LIST_W - 24, H - 100)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(LIST_W - 24, 10)
	scroll:SetScrollChild(content)
	frame.content, frame.rows = content, {}

	frame.charLine = Text(frame, "GameFontDisableSmall")
	frame.charLine:SetPoint("BOTTOMLEFT", 16, 14)
	frame.charLine:SetWidth(LIST_W - 20)

	-- Right: the selected setup.
	local x = LIST_W + 12
	local right = CreateFrame("Frame", nil, frame)
	right:SetPoint("TOPLEFT", x, -30)
	right:SetPoint("BOTTOMRIGHT", -14, 12)
	frame.right = right

	frame.banner = Text(right, "GameFontNormal")
	frame.banner:SetPoint("TOPLEFT", 0, -2)
	frame.banner:SetWidth(W - x - 26)
	frame.banner:SetTextColor(0.4, 1, 0.6)

	frame.name = Text(right, "GameFontNormalLarge")
	frame.name:SetPoint("TOPLEFT", 0, -28)
	frame.name:SetWidth(W - x - 26)
	frame.source = Text(right, "GameFontHighlightSmall")
	frame.source:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -4)
	frame.source:SetWidth(W - x - 26)

	frame.checks = {}
	for i, p in ipairs(ns.PARTS) do
		local cb = CreateFrame("CheckButton", nil, right, "UICheckButtonTemplate")
		cb:SetSize(24, 24)
		cb:SetPoint("TOPLEFT", 0, -64 - (i - 1) * 24)
		cb.label = Text(cb, "GameFontHighlight")
		cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
		cb:SetScript("OnClick", function(self)
			applyParts[p.key] = self:GetChecked() and true or false
			Refresh()
		end)
		cb.key = p.key
		frame.checks[i] = cb
	end
	local belowChecks = -64 - #ns.PARTS * 24 - 4

	frame.warning = Text(right, "GameFontNormalSmall")
	frame.warning:SetPoint("TOPLEFT", 0, belowChecks)
	frame.warning:SetWidth(W - x - 26)
	frame.warning:SetTextColor(1, 0.6, 0.2)

	frame.apply = Button(right, "Apply", 200, function()
		local s = ns.Get(selected)
		if not s then
			return
		end
		Confirm(
			("Apply %s to %s?\nWhat it replaces is kept for Undo."):format(s.name, ns.CharKey()),
			function()
				lastReport = ns.Apply(s, applyParts, ns.db)
				if lastReport.ok then
					ns:Print("applied " .. s.name)
					local c = ns.db.chars[ns.CharKey()]
					if c then
						c.onboarded, c.askAgain = true, nil
					end
					onboarding = false
				end
				Refresh()
			end
		)
	end)
	frame.apply:SetPoint("TOPLEFT", 0, belowChecks - 20)

	frame.undo = Button(right, "Undo Last Apply", 140, function()
		Confirm("Put this character back the way it was before the last apply?", function()
			lastReport = ns.Undo()
			Refresh()
		end)
	end)
	frame.undo:SetPoint("LEFT", frame.apply, "RIGHT", 8, 0)

	local row2 = belowChecks - 48
	frame.saveNew = Button(right, "Save Current As New", 150, function()
		AskName("Name this setup:", ns.CharKey() .. " " .. date("%b %d"), function(name)
			local s = ns.SaveNew(name)
			ns:Print("saved " .. name)
			Select(s.id)
		end)
	end)
	frame.saveNew:SetPoint("TOPLEFT", 0, row2)

	frame.overwrite = Button(right, "Overwrite With Current", 160, function()
		local s = ns.Get(selected)
		Confirm(("Replace %s with %s's current setup?"):format(s.name, ns.CharKey()), function()
			ns.Update(s.id)
			Refresh()
		end)
	end)
	frame.overwrite:SetPoint("LEFT", frame.saveNew, "RIGHT", 6, 0)

	frame.rename = Button(right, "Rename", 90, function()
		local s = ns.Get(selected)
		AskName("New name:", s.name, function(name)
			ns.Rename(s.id, name)
			Refresh()
		end)
	end)
	frame.rename:SetPoint("LEFT", frame.overwrite, "RIGHT", 6, 0)

	local row3 = row2 - 28
	frame.default = Button(right, "Use For New Characters", 170, function()
		ns.SetDefault(selected)
		Refresh()
	end)
	frame.default:SetPoint("TOPLEFT", 0, row3)

	frame.delete = Button(right, "Delete", 90, function()
		local s = ns.Get(selected)
		local text = s.auto and ("Delete %s? It comes back at that character's next login while auto snapshots are on.")
			or "Delete %s? This cannot be undone."
		Confirm(text:format(s.name), function()
			ns.Delete(s.id)
			selected = nil
			Refresh()
		end)
	end)
	frame.delete:SetPoint("LEFT", frame.default, "RIGHT", 6, 0)

	frame.report = Text(right, "GameFontHighlightSmall")
	frame.report:SetPoint("TOPLEFT", 0, row3 - 34)
	frame.report:SetPoint("BOTTOMRIGHT", 0, 34)
	frame.report:SetJustifyV("TOP")

	frame.reload = Button(right, "Reload UI To Finish", 160, function()
		C_UI.Reload()
	end)
	frame.reload:SetPoint("BOTTOMLEFT", 0, 4)

	frame.notNow = Button(right, "Not Now", 90, function()
		local c = ns.db.chars[ns.CharKey()]
		if c then
			c.askAgain = true -- offer again at the next login
		end
		onboarding = false
		frame:Hide()
	end)
	frame.notNow:SetPoint("BOTTOMRIGHT", -110, 4)
	frame.never = Button(right, "Don't Ask Again", 110, function()
		local c = ns.db.chars[ns.CharKey()]
		if c then
			c.onboarded, c.askAgain = true, nil
		end
		onboarding = false
		frame:Hide()
	end)
	frame.never:SetPoint("BOTTOMRIGHT", 0, 4)
end

local function Row(i)
	local row = frame.rows[i]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, frame.content)
	row:SetSize(LIST_W - 28, ROW_H - 2)
	row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
	row.hl = row:CreateTexture(nil, "BACKGROUND")
	row.hl:SetAllPoints()
	row.hl:SetColorTexture(1, 1, 1, 0.08)
	row.line1 = Text(row, "GameFontHighlight")
	row.line1:SetPoint("TOPLEFT", 4, -3)
	row.line1:SetWidth(LIST_W - 36)
	row.line2 = Text(row, "GameFontDisableSmall")
	row.line2:SetPoint("TOPLEFT", 4, -19)
	row.line2:SetWidth(LIST_W - 36)
	row:SetScript("OnClick", function(self)
		Select(self.id)
	end)
	frame.rows[i] = row
	return row
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

	for i, s in ipairs(list) do
		local row = Row(i)
		row.id = s.id
		local badges = {}
		if ns.db.default == s.id then
			badges[#badges + 1] = "|cff33ff99default|r"
		end
		if s.auto then
			badges[#badges + 1] = "auto"
		end
		row.line1:SetText(ClassText(s.class, s.name))
		row.line2:SetText(("lvl %s, %s%s"):format(tostring(s.level or "?"), When(s.updated), #badges > 0 and ("  " .. table.concat(badges, " ")) or ""))
		row.hl:SetShown(s.id == selected)
		row:Show()
	end
	for i = #list + 1, #frame.rows do
		frame.rows[i]:Hide()
	end
	frame.content:SetHeight(math.max(10, #list * ROW_H))

	local me = ns.CharKey()
	local undo = ns.db.undo and ns.db.undo[me]
	frame.charLine:SetText("This character: " .. me .. (undo and ("\nUndo available (" .. When(undo.at) .. ")") or ""))

	frame.banner:SetText(onboarding and "New character. Pick a setup to start from, or close this." or "")
	frame.notNow:SetShown(onboarding and true or false)
	frame.never:SetShown(onboarding and true or false)

	local s = ns.Get(selected)
	local has = s ~= nil
	frame.name:SetText(has and ClassText(s.class, s.name) or (#list == 0 and "No setups yet" or ""))
	frame.source:SetText(has and ("From %s, level %s. Saved %s.%s"):format(
		tostring(s.source),
		tostring(s.level or "?"),
		When(s.updated),
		s.auto and " Updated automatically on login and logout." or ""
	) or (#list == 0 and "Save Current As New stores this character's setup." or ""))

	local any = false
	for _, cb in ipairs(frame.checks) do
		local present = has and s.parts and s.parts[cb.key] ~= nil
		cb:SetShown(has)
		cb:SetEnabled(present)
		cb:SetChecked(present and applyParts[cb.key] or false)
		any = any or (present and applyParts[cb.key])
		local label = ""
		for _, p in ipairs(ns.PARTS) do
			if p.key == cb.key then
				label = p.label
			end
		end
		cb.label:SetText(has and (label .. "  |cffaaaaaa" .. PartCount(s, cb.key) .. "|r") or "")
		cb.label:SetTextColor(present and 1 or 0.5, present and 1 or 0.5, present and 1 or 0.5)
	end

	local _, myClass = UnitClass("player")
	local warn = {}
	if has and s.class and s.class ~= myClass and applyParts.bars then
		warn[#warn + 1] = "Different class: bar spells this character does not know are skipped."
	end
	if has and (applyParts.editmode or applyParts.addons) then
		warn[#warn + 1] = "Edit Mode and the addon list finish after a UI reload."
	end
	frame.warning:SetText(table.concat(warn, "\n"))

	local inCombat = InCombatLockdown()
	frame.apply:SetText(has and ("Apply To " .. (UnitName("player") or "Me")) or "Apply")
	frame.apply:SetEnabled(has and any and not inCombat)
	frame.undo:SetEnabled(undo ~= nil and not inCombat)
	frame.saveNew:SetEnabled(true)
	frame.overwrite:SetEnabled(has and not s.auto)
	frame.rename:SetEnabled(has and not s.auto)
	frame.delete:SetEnabled(has)
	frame.default:SetEnabled(has)
	frame.default:SetText(has and ns.db.default == s.id and "Stop Using For New Characters" or "Use For New Characters")
	frame.default:SetWidth(has and ns.db.default == s.id and 200 or 170)

	frame.report:SetText(lastReport and table.concat(lastReport.lines, "\n") or "")
	frame.reload:SetShown(lastReport and lastReport.reload and true or false)
end
ns.Refresh = Refresh

function ns.Open(asOnboarding)
	if not frame then
		Build()
	end
	onboarding = asOnboarding and true or false
	lastReport = nil
	selected = nil
	frame:Show()
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
ns.description = "Save a character's action bars, keybindings, macros, Edit Mode layout, interface settings "
	.. "and addon list, and apply them to another character. /kws opens the window."
ns.options = {
	{
		key = "picker",
		type = "toggle",
		label = "Offer A Setup On New Characters",
		tooltip = "The first time a character logs in, open the Setups window so you can start from a saved "
			.. "setup. Preselects the setup marked for new characters.",
		default = true,
	},
	{
		key = "autosave",
		type = "toggle",
		label = "Auto Snapshot Each Character",
		tooltip = "Keep one automatic setup per character, refreshed on login and logout, so any character "
			.. "can copy any other.",
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
			print(("  %s (%s, %s)%s"):format(s.name, tostring(s.source), When(s.updated), ns.db.default == s.id and " default" or ""))
		end
	elseif cmd == "undo" then
		local report = ns.Undo()
		ns:Print(report and table.concat(report.lines, "; ") or "nothing to undo on this character")
	else
		ns:Print("/kws opens the window; /kws save [name], /kws list, /kws undo")
	end
end

ns.OnOpen = function()
	ns.Open(false)
end

local ready = false

local function Settle(wasNew)
	ready = true
	if ns.db.autosave then
		ns.AutoSnapshot()
	end
	local c = ns.db.chars[ns.CharKey()]
	local fresh = c and not c.onboarded and (wasNew or c.askAgain)
	if fresh and ns.db.picker and #ns.Offers() > 0 and not InCombatLockdown() then
		ns.Open(true)
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
	local wasNew = ns.db.chars[ns.CharKey()] == nil
	ns.db.chars[ns.CharKey()] = ns.db.chars[ns.CharKey()] or { first = time() }
	-- Action bars, macros and bindings arrive from the server after login; wait before reading them.
	C_Timer.After(8, Safe(function()
		if ns.enabled then
			Settle(wasNew)
		end
	end))
end

ns:RegisterEvent("PLAYER_LOGOUT", function()
	if ready and ns.db.autosave then
		ns.AutoSnapshot()
	end
end)
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
