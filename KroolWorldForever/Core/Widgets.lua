-- Shared window pieces for the hub and feature windows (root.UI). Same templates and art as the
-- Setups window: ButtonFrameTemplate, InsetFrameTemplate, UIPanelButtonTemplate,
-- UICheckButtonTemplate and UIPanelScrollFrameTemplate, all used by Blizzard's own UI on the
-- forever branch (build 70790). Nothing here runs at file scope; windows build on first open.
--
-- Polish lives here so every window gets it: an open animation and the open/close sounds Blizzard's
-- panels use, a click sound on buttons, an on/off sound on check buttons, pressed icons, list
-- highlights, a toast for "done", and small flash, pulse and pop effects. Every animation is an
-- AnimationGroup (no OnUpdate scripts, no timers), and every effect quietly does nothing where the
-- client (or a test stub) has no animation support.

local _, root = ...

local UI = {}
root.UI = UI

UI.ADDON_ICON = "Interface\\Icons\\INV_Misc_Bag_10"
UI.GEAR_ICON = "Interface\\Icons\\INV_Misc_Gear_01"
UI.WARN_ICON = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew" -- Blizzard_UIPanels_Game PVPFrame.xml

-- Atlases. Each is in the forever client's atlas list (Ketho/BlizzardInterfaceResources forever,
-- AtlasInfo.lua) and used by Blizzard's own forever UI where noted.
UI.ATLAS = {
	hoverRow = "Options_List_Hover", -- Blizzard_Settings_Shared/Blizzard_CategoryList.lua
	hoverCard = "PetList-ButtonHighlight", -- Blizzard_Collections/Classic/Blizzard_MountCollection.xml
	selected = "PetList-ButtonSelect", -- same file, the selected mount
	divider = "Options_HorizontalDivider", -- Blizzard_HousingHouseSettings.xml
	ok = "common-icon-checkmark", -- Blizzard_UIPanels_Game/Mainline/DressUpFrames.lua
	fail = "groupfinder-icon-redx", -- already on the Setups window since 0.5.0
	glow = "GarrLanding-CircleGlow", -- Blizzard_Minimap/Mainline/Minimap.xml, a looping glow
	search = "common-search-magnifyingglass", -- Blizzard_SharedXML InputBoxTemplates.xml
}

-- -------------------------------------------------------------------- basics

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

-- Inline art for chat and tooltip text: "|T...|t" for a file or file id, "|A...|a" for an atlas.
-- size 0 follows the font. An Interface\Icons file has its border trimmed; raw = true shows any
-- other texture (a raid marker) whole. Returns "" for nothing.
function UI.InlineIcon(file, size, raw)
	if file == nil or file == "" then
		return ""
	end
	size = size or 0
	if raw then
		return ("|T%s:%d:%d|t"):format(tostring(file), size, size)
	end
	return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(tostring(file), size, size)
end

function UI.InlineAtlas(atlas, size)
	size = size or 14
	return ("|A:%s:%d:%d|a"):format(atlas, size, size)
end

-- An item's icon as inline text ("" when the client cannot say yet).
function UI.ItemIcon(id, size)
	if not (C_Item and C_Item.GetItemIconByID) or not id then
		return ""
	end
	local ok, file = pcall(C_Item.GetItemIconByID, id)
	if ok and file ~= nil and (type(file) == "number" or type(file) == "string") then
		return UI.InlineIcon(file, size) .. " "
	end
	return ""
end

-- -------------------------------------------------------------------- sound

-- Blizzard's panel sounds (SoundKitConstants.lua on the forever branch); the number is the fallback.
local SOUNDS = {
	open = { "IG_CHARACTER_INFO_OPEN", 839 },
	close = { "IG_CHARACTER_INFO_CLOSE", 840 },
	click = { "IG_MAINMENU_OPTION", 852 },
	on = { "IG_MAINMENU_OPTION_CHECKBOX_ON", 856 },
	off = { "IG_MAINMENU_OPTION_CHECKBOX_OFF", 857 },
}

function UI.Sound(kind)
	local s = SOUNDS[kind]
	if not s or type(PlaySound) ~= "function" then
		return
	end
	local id = (type(SOUNDKIT) == "table" and SOUNDKIT[s[1]]) or s[2]
	pcall(PlaySound, id)
end

-- -------------------------------------------------------------------- animation

-- What the kit keeps per region (its animations, its toast), outside the region itself: nothing is
-- written onto Blizzard's frames, and an unknown field never reads as something it is not.
local state = setmetatable({}, { __mode = "k" })
local function State(region)
	local s = state[region]
	if not s then
		s = {}
		state[region] = s
	end
	return s
end

-- An AnimationGroup on `region` (frame or texture), or nil where there is no animation support.
local function Group(region)
	if not region or type(region.CreateAnimationGroup) ~= "function" then
		return nil
	end
	local ok, ag = pcall(region.CreateAnimationGroup, region)
	if ok and type(ag) == "table" and type(ag.CreateAnimation) == "function" then
		return ag
	end
	return nil
end

local function Anim(ag, kind, duration, order)
	local ok, a = pcall(ag.CreateAnimation, ag, kind)
	if not (ok and type(a) == "table") then
		return nil
	end
	a:SetDuration(duration)
	if order then
		a:SetOrder(order)
	end
	return a
end

local function Fade(ag, from, to, duration, order)
	local a = Anim(ag, "Alpha", duration, order)
	if a then
		a:SetFromAlpha(from)
		a:SetToAlpha(to)
	end
	return a
end

local function Play(ag)
	if ag then
		pcall(ag.Restart, ag)
	end
end

-- The region's animation group named `key`, built once by build(ag); false when there is none.
local function Cached(region, key, build)
	local s = State(region)
	local ag = s[key]
	if ag == nil then
		ag = Group(region) or false
		s[key] = ag
		if ag then
			build(ag, s)
		end
	end
	return ag or nil, s
end

-- Fades a window in while it grows from 96% to full size: the open animation.
function UI.Intro(frame)
	return Cached(frame, "intro", function(ag)
		local fade = Fade(ag, 0, 1, 0.16)
		if fade then
			fade:SetSmoothing("OUT")
		end
		local grow = Anim(ag, "Scale", 0.16)
		if grow then
			grow:SetScaleFrom(0.96, 0.96)
			grow:SetScaleTo(1, 1)
			grow:SetSmoothing("OUT")
		end
	end)
end

-- Fades in after `delay` seconds: staggered rows and cards. The wait is part of the animation (held
-- at alpha 0), so the region's own alpha is never touched and a stopped animation leaves it visible.
function UI.FadeIn(region, delay)
	local ag, s = Cached(region, "fadeIn", function(g, s)
		s.wait = Fade(g, 0, 0, 0.01, 1)
		local a = Fade(g, 0, 1, 0.2, 2)
		if a then
			a:SetSmoothing("OUT")
		end
	end)
	if ag then
		if s.wait then
			s.wait:SetDuration(math.max(0.01, delay or 0))
		end
		Play(ag)
	end
end

-- A quick dip and return: draws the eye to something that just changed.
function UI.Flash(region)
	Play((Cached(region, "flash", function(ag)
		Fade(ag, 1, 0.3, 0.1, 1)
		Fade(ag, 0.3, 1, 0.3, 2)
	end)))
end

-- Grows from small to full size, overshooting a little: something that just appeared.
function UI.Pop(region)
	Play((Cached(region, "pop", function(ag)
		local up = Anim(ag, "Scale", 0.14, 1)
		if up then
			up:SetScaleFrom(0.5, 0.5)
			up:SetScaleTo(1.15, 1.15)
			up:SetSmoothing("OUT")
		end
		local down = Anim(ag, "Scale", 0.1, 2)
		if down then
			down:SetScaleFrom(1.15, 1.15)
			down:SetScaleTo(1, 1)
			down:SetSmoothing("IN")
		end
	end)))
end

-- A slow breathing glow between two alphas until stopped. Returns a control: :Start(), :Stop().
function UI.Pulse(region, low, high, period)
	local ag = Group(region)
	if ag then
		pcall(ag.SetLooping, ag, "BOUNCE")
		local a = Fade(ag, low or 0.25, high or 0.9, period or 0.8)
		if a then
			a:SetSmoothing("IN_OUT")
		end
	end
	local pulse = {}
	function pulse.Start()
		region:Show()
		if ag and not ag:IsPlaying() then
			pcall(ag.Play, ag)
		end
	end
	function pulse.Stop()
		if ag then
			pcall(ag.Stop, ag)
		end
		region:Hide()
	end
	return pulse
end

-- -------------------------------------------------------------------- controls

function UI.Button(parent, text, width, onClick, atlas)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	local handler = UI.Safe(onClick)
	b:SetScript("OnClick", function(...)
		UI.Sound("click")
		handler(...)
	end)
	b.kwfIcon = false
	if atlas then
		-- A small icon before the label.
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

-- Pressed look for an icon: it sinks a pixel and darkens while the mouse button is down.
function UI.Press(button, icon)
	if type(button.HookScript) ~= "function" then
		return
	end
	button:HookScript("OnMouseDown", function(self)
		if self.IsEnabled and not self:IsEnabled() then
			return
		end
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
		icon:SetVertexColor(0.75, 0.75, 0.75)
	end)
	button:HookScript("OnMouseUp", function()
		icon:ClearAllPoints()
		icon:SetAllPoints()
		icon:SetVertexColor(1, 1, 1)
	end)
end

-- A bare icon that glows under the mouse and sinks when pressed.
-- iconFile: an Interface\Icons file (border trimmed) or another texture (raw = true).
function UI.IconButton(parent, size, file, onClick, raw)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.kwfIcon = b:CreateTexture(nil, "ARTWORK")
	b.kwfIcon:SetAllPoints()
	local glow = b:CreateTexture(nil, "HIGHLIGHT")
	glow:SetAllPoints()
	if raw then
		b.kwfIcon:SetTexture(file)
		glow:SetTexture(file)
	else
		UI.SetIcon(b.kwfIcon, file)
		UI.SetIcon(glow, file)
	end
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.5)
	local handler = UI.Safe(onClick)
	b:SetScript("OnClick", function(...)
		UI.Sound("click")
		handler(...)
	end)
	UI.Press(b, b.kwfIcon)
	return b
end

-- Enables or greys out a button, and its icon with it.
function UI.Enable(b, on)
	on = on and true or false
	b:SetEnabled(on)
	if b.kwfIcon then -- set by Button and IconButton; false when there is none
		b.kwfIcon:SetDesaturated(not on)
		b.kwfIcon:SetAlpha(on and 1 or 0.45)
	end
end

-- A UICheckButtonTemplate check box that makes Blizzard's on/off sound. onClick(self, checked).
function UI.Check(parent, size, onClick)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(size or 26, size or 26)
	local handler = UI.Safe(onClick)
	cb:SetScript("OnClick", function(self, ...)
		local on = self:GetChecked() and true or false
		UI.Sound(on and "on" or "off")
		handler(self, on, ...)
	end)
	return cb
end

-- The highlight for clickable rows: Blizzard's list hover ("row") or its larger list button
-- highlight ("card").
function UI.Hover(parent, style)
	local hl = parent:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetAtlas(style == "card" and UI.ATLAS.hoverCard or UI.ATLAS.hoverRow)
	hl:SetAlpha(style == "card" and 0.6 or 0.8)
	return hl
end

-- The look of a selected row (hidden until shown).
function UI.Selected(parent)
	local sel = parent:CreateTexture(nil, "BACKGROUND")
	sel:SetAllPoints()
	sel:SetAtlas(UI.ATLAS.selected)
	sel:SetAlpha(0.8)
	sel:Hide()
	return sel
end

-- A thin divider line under a section header.
function UI.Divider(parent, width)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetAtlas(UI.ATLAS.divider)
	line:SetSize(width or 200, 1)
	line:SetAlpha(0.6)
	return line
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
		widget:SetMotionScriptsWhileDisabled(true) -- a disabled button still says why
	end
end

-- -------------------------------------------------------------------- toast

local TOAST = {
	ok = { atlas = UI.ATLAS.ok, color = { 0.2, 1, 0.6 } },
	fail = { atlas = UI.ATLAS.fail, color = { 1, 0.4, 0.35 } },
	warn = { file = UI.WARN_ICON, color = { 1, 0.82, 0 } },
}

-- A short message that rises in at the bottom of a window and fades away by itself: "Saved",
-- "Applied". kind: "ok" (default), "warn" or "fail". One per window, reused.
function UI.Toast(parent, text, kind)
	local style = TOAST[kind or "ok"] or TOAST.ok
	local s = State(parent)
	local t = s.toast
	if not t then
		t = CreateFrame("Frame", nil, parent)
		t:SetSize(260, 30)
		t:SetPoint("BOTTOM", parent, "BOTTOM", s.toastX or 0, s.toastY or 34)
		if t.SetFrameLevel and parent.GetFrameLevel then
			local level = parent:GetFrameLevel()
			if type(level) == "number" then
				t:SetFrameLevel(level + 30)
			end
		end
		t.bg = t:CreateTexture(nil, "BACKGROUND")
		t.bg:SetAllPoints()
		t.bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)
		t.edge = t:CreateTexture(nil, "BORDER")
		t.edge:SetPoint("TOPLEFT")
		t.edge:SetPoint("TOPRIGHT")
		t.edge:SetHeight(2)
		t.icon = t:CreateTexture(nil, "ARTWORK")
		t.icon:SetSize(16, 16)
		t.icon:SetPoint("LEFT", 10, 0)
		t.text = UI.Text(t, "GameFontHighlight")
		t.text:SetPoint("LEFT", t.icon, "RIGHT", 6, 0)
		t.text:SetWordWrap(false)
		local ag = Group(t)
		if ag then
			Fade(ag, 0, 1, 0.18, 1)
			local rise = Anim(ag, "Translation", 0.18, 1)
			if rise then
				rise:SetOffset(0, 8)
				rise:SetSmoothing("OUT")
			end
			Fade(ag, 1, 1, 1.8, 2) -- hold
			Fade(ag, 1, 0, 0.5, 3)
			ag:SetScript("OnFinished", function()
				t:Hide()
			end)
		end
		t.anim = ag or false
		s.toast = t
	end
	if style.atlas then
		t.icon:SetTexCoord(0, 1, 0, 1)
		t.icon:SetAtlas(style.atlas)
	else
		t.icon:SetTexture(style.file)
		t.icon:SetTexCoord(0, 1, 0, 1)
	end
	t.edge:SetColorTexture(style.color[1], style.color[2], style.color[3], 0.9)
	t.text:SetText(text)
	t.kind = kind or "ok"
	local w = t.text.GetStringWidth and t.text:GetStringWidth()
	if type(w) == "number" and w > 0 then
		t:SetWidth(math.min(math.max(w + 46, 140), 460))
	end
	t:Show()
	Play(t.anim or nil)
	return t
end

-- The toast a window last showed (nil before the first): for tests and for chaining.
function UI.ToastOf(parent)
	return state[parent] and state[parent].toast or nil
end

-- Where a window's toast sits, from the middle of its bottom edge (default 0, 34): for windows
-- whose bottom holds something the toast must not cover. Call before the first toast.
function UI.ToastAt(parent, x, y)
	local s = State(parent)
	s.toastX, s.toastY = x, y
end

-- -------------------------------------------------------------------- windows

-- The open animation and Blizzard's open/close sounds for a window built elsewhere (Setups).
function UI.Polish(frame)
	local intro = UI.Intro(frame)
	if type(frame.HookScript) ~= "function" then
		return
	end
	frame:HookScript("OnShow", function()
		UI.Sound("open")
		Play(intro)
	end)
	frame:HookScript("OnHide", function(self)
		if State(self).quiet then
			return -- handing over to another window: that one makes the sound
		end
		UI.Sound("close")
	end)
end

-- Hides a window without its close sound, when another window opens in its place.
function UI.HandOff(frame)
	if frame and frame:IsShown() then
		local s = State(frame)
		s.quiet = true
		frame:Hide()
		s.quiet = nil
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
	UI.Polish(f)
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

-- An empty-list message with a faded picture above it. Returns the text; the picture is .art.
function UI.Empty(parent, atlas, width)
	local art = parent:CreateTexture(nil, "ARTWORK")
	art:SetSize(48, 48)
	art:SetPoint("TOP", 0, -36)
	if atlas then
		art:SetAtlas(atlas)
	end
	art:SetAlpha(0.35)
	local fs = UI.Text(parent, "GameFontDisable", "CENTER")
	fs:SetPoint("TOP", art, "BOTTOM", 0, -8)
	fs:SetWidth(width or 300)
	fs.art = art
	return fs
end
