-- The Characters window (/kw chars, the hub's Characters button): every character the addon has
-- seen, with a Track check box. Untracked characters are left out of every character list.
-- Built on first open, never at file scope.

local _, root = ...
local UI = root.UI

local W, H, ROW_H = 470, 400, 28
local frame -- built on first open

local function ClassText(classFile, text)
	local ok, color = pcall(C_ClassColor.GetClassColor, classFile or "")
	if ok and color and color.WrapTextInColorCode then
		return color:WrapTextInColorCode(text)
	end
	return text
end

-- "today", "3d ago", "?" for a record that was never stamped.
function root.CharsAgo(seen, now)
	if type(seen) ~= "number" or seen <= 0 or type(now) ~= "number" then
		return "?"
	end
	local days = math.floor(math.max(0, now - seen) / 86400)
	return days == 0 and "today" or (days .. "d ago")
end

local function Row(i)
	local row = frame.rows[i]
	if row then
		return row
	end
	row = CreateFrame("Frame", nil, frame.content)
	row:SetSize(W - 56, ROW_H)
	row.check = UI.Check(row, 26, function(_, on)
		if row.key then
			root.SetTracked(row.key, on) -- the change listener refreshes the list
		end
	end)
	row.check:SetPoint("LEFT", 2, 0)
	UI.Tip(row.check, function()
		return "Track", { "On: this character appears in Reagent Uses, Sayge's Fortune and the Setups character list. Off: it is left out. Nothing is deleted." }
	end)
	row.name = UI.Text(row, "GameFontNormal")
	row.name:SetPoint("LEFT", 34, 0)
	row.name:SetWidth(140)
	row.name:SetWordWrap(false)
	row.realm = UI.Text(row, "GameFontDisableSmall")
	row.realm:SetPoint("LEFT", 180, 0)
	row.realm:SetWidth(100)
	row.realm:SetWordWrap(false)
	row.level = UI.Text(row, "GameFontHighlightSmall")
	row.level:SetPoint("LEFT", 284, 0)
	row.level:SetWidth(40)
	row.seen = UI.Text(row, "GameFontDisableSmall")
	row.seen:SetPoint("LEFT", 328, 0)
	row.seen:SetWidth(70)
	row.seen:SetWordWrap(false)
	frame.rows[i] = row
	return row
end

local function Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	local list, now, mine = root.CharList(), time(), root.CharKey()
	local tracked = 0
	for i, e in ipairs(list) do
		local rec, row = e.rec, Row(i)
		row.key = e.key
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
		local on = rec.track ~= false
		tracked = tracked + (on and 1 or 0)
		row.check:SetChecked(on)
		local text = rec.name .. (e.key == mine and " (you)" or "")
		row.name:SetText(on and ClassText(rec.class, text) or ("|cff888888" .. text .. "|r"))
		row.realm:SetText(rec.realm)
		row.level:SetText(rec.level > 0 and ("Lv " .. rec.level) or "")
		row.seen:SetText(e.key == mine and "today" or root.CharsAgo(rec.seen, now))
		row:Show()
	end
	for i = #list + 1, #frame.rows do
		frame.rows[i]:Hide()
	end
	frame.empty:SetShown(#list == 0)
	frame.content:SetSize(W - 56, math.max(10, #list * ROW_H))
	frame.count:SetText(("%d of %d tracked"):format(tracked, #list))
end

local function Build()
	frame = UI.Window("KroolWorldForeverCharacters", "Characters", W, H)
	frame.rows = {}
	frame.intro = UI.Text(frame, "GameFontHighlightSmall")
	frame.intro:SetPoint("TOPLEFT", 68, -32)
	frame.intro:SetWidth(W - 84)
	frame.intro:SetText("Untracked characters are left out of Reagent Uses, Sayge's Fortune and the Setups character list. Nothing is deleted.")
	frame.content = UI.ScrollList(frame, -74, 28)
	frame.empty = UI.Empty(frame.content, UI.ATLAS.ok, W - 100)
	frame.empty:SetText("No characters yet.\n\nThey are added as you log in.")
	frame.count = UI.Text(frame, "GameFontDisableSmall")
	frame.count:SetPoint("BOTTOMLEFT", 14, 10)
	root.OnCharsChanged(Refresh)
end

-- Opens the window, or closes it when it is open.
function root.OpenCharacters()
	if not frame then
		Build()
	end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		Refresh()
	end
end

function root.CharactersFrame()
	return frame
end
