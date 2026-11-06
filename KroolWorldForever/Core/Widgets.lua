-- Shared window pieces for the hub and feature windows (root.UI). Same templates and art as the
-- Setups window: ButtonFrameTemplate, InsetFrameTemplate, UIPanelButtonTemplate,
-- UICheckButtonTemplate and UIPanelScrollFrameTemplate, all used by Blizzard's own UI on the
-- forever branch (build 70790). Nothing here runs at file scope; windows build on first open.

local _, root = ...

local UI = {}
root.UI = UI

UI.ADDON_ICON = "Interface\\Icons\\INV_Misc_Bag_10"
UI.GEAR_ICON = "Interface\\Icons\\INV_Misc_Gear_01"

-- Wraps a script handler so an error prints a line instead of reaching the client.
-- F: the feature to print as (optional).
function UI.Safe(fn, F)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			local msg = "|cffff5555error|r: " .. tostring(err)
			if F then
				F:Print(msg)
			else
				root.Print(msg)
			end
		end
	end
end

function UI.Text(parent, font, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	fs:SetJustifyH(justify or "LEFT")
	return fs
end

-- An Interface\Icons file with its border trimmed.
function UI.SetIcon(tex, file)
	tex:SetTexture(file)
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

function UI.Button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	b:SetScript("OnClick", UI.Safe(onClick))
	return b
end

-- A bare icon that glows under the mouse.
function UI.IconButton(parent, size, file, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.kwfIcon = b:CreateTexture(nil, "ARTWORK")
	b.kwfIcon:SetAllPoints()
	UI.SetIcon(b.kwfIcon, file)
	local glow = b:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	UI.SetIcon(glow, file)
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.5)
	b:SetScript("OnClick", UI.Safe(onClick))
	return b
end

-- A faint highlight for clickable rows.
function UI.Hover(parent)
	local hl = parent:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.06)
	return hl
end

-- fn(widget) returns the tooltip's title and its lines (or nothing for no tooltip).
function UI.Tip(widget, fn)
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
	if widget.SetMotionScriptsWhileDisabled then
		widget:SetMotionScriptsWhileDisabled(true)
	end
end

-- A movable ButtonFrameTemplate window that Escape closes. Hidden until shown.
function UI.Window(name, title, w, h, portrait)
	local f = CreateFrame("Frame", name, UIParent, "ButtonFrameTemplate")
	f:SetSize(w, h)
	f:SetPoint("CENTER")
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
	f:Hide()
	table.insert(UISpecialFrames, name) -- Escape closes it
	if f.SetTitle then
		f:SetTitle(title)
	end
	if f.SetPortraitToAsset then
		pcall(f.SetPortraitToAsset, f, portrait or UI.ADDON_ICON)
	end
	return f
end

-- A vertical scroll list filling the window's inset; returns the scroll child.
function UI.ScrollList(f, top, bottom)
	local inset = f.Inset
	if type(inset) == "table" then
		inset:ClearAllPoints()
		inset:SetPoint("TOPLEFT", 4, top)
		inset:SetPoint("BOTTOMRIGHT", -6, bottom)
	end
	local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, top - 6)
	scroll:SetPoint("BOTTOMRIGHT", -30, bottom + 6)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(10, 10)
	scroll:SetScrollChild(content)
	f.scroll = scroll
	return content
end
