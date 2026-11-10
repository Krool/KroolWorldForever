-- The Krool World hub (/kw, the minimap addon button): one card per feature with its icon, what it
-- is doing right now, an on/off switch, and the way in (its own window when it has one, and its
-- settings page). Features describe themselves for it with ns.icon, ns.blurb and ns.HubStatus().
-- Built on first open, never at file scope.

local _, root = ...
local UI = root.UI

local W, CARD_H, GAP, TOP = 470, 62, 6, -32
local hub -- built on first open

local Version = root.Version

local function StatusText(F)
	if not F.db.enabled then
		return "|cff888888Off|r"
	end
	if F.HubStatus then
		local ok, text = root.TryQuiet(F, "hub status", F.HubStatus)
		if ok and text then
			return text
		end
	end
	return ""
end

-- The way into a feature: its own window when it has one (and is on), else its settings page.
-- The hub steps aside quietly: the window that opens makes the sound.
local function Enter(F)
	UI.HandOff(hub)
	if F.OnOpen and F.enabled then
		F.OnOpen()
	else
		root.OpenSettings(F)
	end
end

local function Settings(F)
	UI.HandOff(hub)
	root.OpenSettings(F)
end

local Refresh -- forward

local ON_COLOR, OFF_COLOR = { 0.2, 1, 0.6 }, { 0.45, 0.45, 0.45 }

local function Card(parent, F, i)
	local card = CreateFrame("Button", nil, parent, "InsetFrameTemplate")
	card:SetPoint("TOPLEFT", 10, TOP - 30 - (i - 1) * (CARD_H + GAP))
	card:SetSize(W - 20, CARD_H)
	card.feature = F
	UI.Hover(card, "card")
	if card.RegisterForClicks then
		card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	end
	card:SetScript("OnClick", UI.Safe(function(_, which)
		UI.Sound("click")
		if which == "RightButton" then
			Settings(F)
		else
			Enter(F)
		end
	end))
	UI.Tip(card, function()
		local lines = { F.description }
		if F.slash and F.slash[1] then
			lines[#lines + 1] = "|cffaaaaaaCommand: " .. F.slash[1] .. "|r"
		end
		lines[#lines + 1] = "|cff33ff99" .. ((F.OnOpen and F.enabled) and "Click to open." or "Click for its settings.") .. "|r"
		if F.OnOpen and F.enabled then
			lines[#lines + 1] = "|cffaaaaaaRight-click for its settings.|r"
		end
		return F.title or F.key, lines
	end)

	-- A thin bar down the left edge: green while the feature is on.
	card.accent = card:CreateTexture(nil, "ARTWORK")
	card.accent:SetPoint("TOPLEFT", 3, -4)
	card.accent:SetPoint("BOTTOMLEFT", 3, 4)
	card.accent:SetWidth(3)

	-- The icon sits on a dark tile, like a spell in the spellbook.
	card.iconBack = card:CreateTexture(nil, "BACKGROUND", nil, 1)
	card.iconBack:SetSize(44, 44)
	card.iconBack:SetPoint("LEFT", 9, 0)
	card.iconBack:SetColorTexture(0, 0, 0, 0.55)
	card.icon = card:CreateTexture(nil, "ARTWORK")
	card.icon:SetSize(40, 40)
	card.icon:SetPoint("CENTER", card.iconBack, "CENTER")
	UI.SetIcon(card.icon, F.icon or UI.ADDON_ICON)

	card.title = UI.Text(card, "GameFontNormalLarge")
	card.title:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, 0)
	card.title:SetText(F.title or F.key)
	card.blurb = UI.Text(card, "GameFontHighlightSmall")
	card.blurb:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
	card.blurb:SetWidth(W - 266)
	card.blurb:SetWordWrap(false)
	card.blurb:SetTextColor(0.8, 0.8, 0.8)
	card.blurb:SetText(F.blurb or "")
	card.status = UI.Text(card, "GameFontHighlightSmall")
	card.status:SetPoint("TOPLEFT", card.blurb, "BOTTOMLEFT", 0, -3)
	card.status:SetWidth(W - 266)
	card.status:SetWordWrap(false)

	-- Right side: on/off, then the way in.
	card.gear = UI.IconButton(card, 20, UI.GEAR_ICON, function()
		Settings(F)
	end)
	card.gear:SetPoint("RIGHT", -10, 0)
	UI.Tip(card.gear, function()
		return "Settings", { (F.title or F.key) .. "'s options." }
	end)
	card.action = false
	if F.OnOpen then
		card.open = UI.Button(card, "Open", 64, function()
			Enter(F)
		end)
		card.open:SetPoint("RIGHT", card.gear, "LEFT", -8, 0)
	else
		card.open = false
		if F.HubAction then
			-- A feature without a window may offer one fix-it button in the same place.
			card.action = UI.Button(card, "", 80, function()
				local a = F.HubAction()
				if a and a.fn then
					a.fn()
				end
				Refresh()
				UI.Flash(card.status)
			end)
			card.action:SetPoint("RIGHT", card.gear, "LEFT", -8, 0)
			UI.Tip(card.action, function()
				local a = F.HubAction()
				return a and a.label, a and { a.tip }
			end)
		end
	end
	card.toggle = UI.Check(card, 26, function()
		root.SetOption(F, "enabled", not F.db.enabled)
		Refresh()
		UI.Flash(card.status)
		UI.Pop(card.accent)
		UI.Toast(hub, ("%s %s"):format(F.title or F.key, F.db.enabled and "on" or "off"), F.db.enabled and "ok" or "warn")
	end)
	-- One column on every card: clear of the widest right side (gear 20 at -10, an 80-wide action
	-- button 8 left of it) plus room for the On label, whether or not this card has a button.
	card.toggle:SetPoint("RIGHT", card, "RIGHT", -(10 + 20 + 8 + 80 + 34), 0)
	card.toggle.label = UI.Text(card, "GameFontHighlightSmall")
	card.toggle.label:SetPoint("LEFT", card.toggle, "RIGHT", 0, 1)
	UI.Tip(card.toggle, function()
		return F.db.enabled and "On" or "Off", { "Turns " .. (F.title or F.key) .. " on or off. Saved for every character." }
	end)
	return card
end

local function Build()
	hub = UI.Window("KroolWorldForeverHub", "Krool World", W, 10)
	if type(hub.Inset) == "table" then
		hub.Inset:Hide() -- each card is its own inset
	end
	hub.cards = {}
	for i, key in ipairs(root.featureOrder) do
		hub.cards[i] = Card(hub, root.features[key], i)
	end
	local n = #root.featureOrder
	local bottom = -TOP + 30 + n * (CARD_H + GAP) + 36
	hub:SetHeight(bottom)

	hub.intro = UI.Text(hub, "GameFontHighlight")
	hub.intro:SetPoint("TOPLEFT", 68, -35)
	hub.intro:SetWidth(W - 84)
	hub.intro:SetWordWrap(false)
	hub.intro:SetText("Each feature has its own switch. Click one to open it.")
	hub.divider = UI.Divider(hub, W - 84)
	hub.divider:SetPoint("TOPLEFT", hub.intro, "BOTTOMLEFT", 0, -6)

	hub.version = UI.Text(hub, "GameFontDisableSmall")
	hub.version:SetPoint("BOTTOMLEFT", 14, 10)
	local v = Version()
	hub.version:SetText(v and ("v" .. v .. "  ·  /kw") or "/kw")

	hub.settings = UI.Button(hub, "All Settings", 110, function()
		Settings(nil)
	end)
	hub.settings:SetPoint("BOTTOMRIGHT", -8, 4)
	UI.Tip(hub.settings, function()
		return "All Settings", { "Every feature's options on one page (Options > AddOns > Krool World Forever)." }
	end)
end

function Refresh()
	if not hub then
		return
	end
	for _, card in ipairs(hub.cards) do
		local F = card.feature
		local on = F.db.enabled and true or false
		card.toggle:SetChecked(on)
		card.toggle.label:SetText(on and "On" or "Off")
		card.toggle.label:SetTextColor(on and ON_COLOR[1] or 0.6, on and ON_COLOR[2] or 0.6, on and ON_COLOR[3] or 0.6)
		local c = on and ON_COLOR or OFF_COLOR
		card.accent:SetColorTexture(c[1], c[2], c[3], on and 0.85 or 0.5)
		card.icon:SetDesaturated(not on)
		card.icon:SetAlpha(on and 1 or 0.6)
		card.title:SetTextColor(on and 1 or 0.6, on and 0.82 or 0.6, on and 0 or 0.6)
		card.status:SetText(StatusText(F))
		if card.open then
			card.open:SetEnabled(F.enabled and true or false)
		end
		if card.action then
			local ok, a = root.TryQuiet(F, "hub button", F.HubAction)
			a = ok and F.enabled and a or nil
			card.action:SetShown(a ~= nil)
			card.action:SetText(a and a.label or "")
		end
	end
end
root.RefreshHub = Refresh

-- Opens the hub, or closes it when it is already open.
function root.OpenHub()
	if not hub then
		Build()
	end
	if hub:IsShown() then
		hub:Hide()
	else
		hub:Show()
		Refresh()
		for i, card in ipairs(hub.cards) do
			UI.FadeIn(card, 0.04 * i) -- the cards arrive one after another
		end
	end
end

function root.HubFrame()
	return hub
end
