-- The material tooltip. While the chosen key is held (Ctrl by default), an item that a recipe uses
-- lists those recipes, grouped by profession:
--
--   Tailoring 152                               10 recipes
--     Bolt of Silk Cloth x4 (used in 52)             Known
--     Azure Silk Pants x4                     Trainer 140
--   Engineering                                  7 recipes
--     Solid Dynamite                       Bob, Trainer 175
--
-- Recipe names take the crafting window's colors for this character's skill (orange, yellow, green,
-- grey; red while the skill is below what the recipe needs to be learned). The right side names who
-- knows it, else where it is learned and at what skill. Professions this character has come first,
-- then ones another character has, then the rest.

local _, root = ...
local ns = root.Feature("reagents")
local Secret = ns.Secret

local COLOR = { orange = "ff8040", yellow = "ffff00", green = "40bf40", grey = "808080", red = "ff1a1a" }
local GOLD, WHITE, DIM, SOURCE_COLOR, KNOWN = "ffd100", "ffffff", "8c8c8c", "56b59d", "20ff20"
local SOURCE = { S = "Starter", T = "Trainer", V = "Vendor", D = "Drop", F = "Fishing", Q = "Quest", R = "Recipe" }
local ALTS_SHOWN = 3

local function Hex(color, s)
	return "|cff" .. color .. s .. "|r"
end

-- The crafting-window color of a recipe at a skill: orange, yellow, green, grey, or red when the skill
-- is below the level the recipe is learned at (never for one already known). nil without a skill or
-- without thresholds.
function ns.Band(rank, r, known)
	if type(rank) ~= "number" then
		return nil
	end
	local yellow, grey, learn = r[2], r[3], r[6]
	if learn > 0 and rank < learn and not known then
		return "red"
	end
	if yellow <= 0 or grey <= 0 then
		return nil
	end
	if rank < yellow then
		return "orange"
	end
	if rank < math.floor((yellow + grey) / 2) then
		return "yellow"
	end
	if rank < grey then
		return "green"
	end
	return "grey"
end

local names = {}
function ns.RecipeName(id)
	local n = names[id]
	if n == nil then
		n = false
		local S = C_Spell
		if S then
			n = ns.Str(ns.Call(S.GetSpellName, id)) or false
		end
		names[id] = n
	end
	return n or nil
end

local lineNames = {}
function ns.LineName(line)
	local n = lineNames[line]
	if not n then
		local T = C_TradeSkillUI
		n = T and ns.Str(ns.Call(T.GetTradeSkillDisplayName, line))
		if not n then
			local d = ns.Data.lines[line]
			n = d and d[1] or ("Profession " .. line)
		end
		lineNames[line] = n
	end
	return n
end

-- How many recipes use an item (0 when none).
function ns.UseCount(item)
	local uses = ns.Data.uses[item]
	return uses and math.floor(#uses / 2) or 0
end

-- The recipes using an item, grouped by profession and sorted for display:
-- { { line, rank, list = { { id, r, count, name, mine, band, alts } } } }, and the recipe count.
function ns.Collect(item)
	local uses = ns.Data.uses[item]
	if not uses then
		return nil, 0
	end
	local myKnown = ns.MyRecords()
	local opt = ns.db
	local others = opt.alts and ns.OtherChars() or {}
	local groups, byLine = {}, {}
	for i = 1, #uses, 2 do
		local id, count = uses[i], uses[i + 1]
		local r = ns.Data.recipes[id]
		local name = r and ns.RecipeName(id)
		if name then
			local line = r[1]
			local g = byLine[line]
			if not g then
				local rank = ns.MySkill(line)
				g = { line = line, rank = rank, list = {}, seen = {}, tier = rank and 1 or (ns.AltHasLine(others, line) and 2 or 3) }
				byLine[line] = g
				groups[#groups + 1] = g
			end
			local mine = myKnown and type(myKnown[line]) == "table" and myKnown[line][id] == true or false
			local alts = opt.alts and ns.AltsKnowing(others, line, id) or nil
			local e = g.seen[name]
			if e then
				-- Two recipes with one name (faction versions): one row, either one's knowledge.
				e.mine = e.mine or mine
				e.alts = e.alts or alts
				e.band = ns.Band(g.rank, e.r, e.mine)
			else
				e = { id = id, r = r, count = count, name = name, mine = mine, alts = alts }
				e.band = ns.Band(g.rank, r, mine)
				g.seen[name] = e
				if not (opt.hideGrey and e.band == "grey") then
					g.list[#g.list + 1] = e
				end
			end
		end
	end
	local total = 0
	local kept = {}
	for _, g in ipairs(groups) do
		if #g.list > 0 then
			table.sort(g.list, function(a, b)
				local ka = (a.mine or a.alts) and 0 or 1
				local kb = (b.mine or b.alts) and 0 or 1
				if ka ~= kb then
					return ka < kb
				end
				if a.r[2] ~= b.r[2] then
					return a.r[2] > b.r[2] -- higher skill first, like the crafting window
				end
				return a.name < b.name
			end)
			total = total + #g.list
			kept[#kept + 1] = g
		end
	end
	table.sort(kept, function(a, b)
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		if a.tier == 1 and a.rank ~= b.rank then
			return a.rank > b.rank
		end
		return ns.LineName(a.line) < ns.LineName(b.line)
	end)
	return kept, total
end

function ns.LeftText(e)
	local s = "  " .. Hex(e.band and COLOR[e.band] or WHITE, e.name)
	if e.count > 1 then
		s = s .. Hex(DIM, " x" .. e.count)
	end
	local made = e.r[4]
	local n = made > 0 and ns.UseCount(made) or 0
	if n > 0 then
		s = s .. Hex(DIM, " (used in " .. n .. ")")
	end
	return s
end

function ns.SourceText(e, rank)
	local src, learn = e.r[5], e.r[6]
	local words = {}
	for i = 1, #src do
		local w = SOURCE[src:sub(i, i)]
		if w then
			words[#words + 1] = w
		end
	end
	local s = #words > 0 and Hex(SOURCE_COLOR, table.concat(words, ", ")) or ""
	if learn > 0 then
		local color = (rank and rank < learn) and COLOR.red or SOURCE_COLOR
		s = s .. (s ~= "" and " " or "") .. Hex(color, tostring(learn))
	end
	return s
end

function ns.RightText(e, rank)
	local parts = {}
	if e.mine then
		parts[#parts + 1] = Hex(KNOWN, "Known")
	end
	if e.alts then
		local myRealm = select(2, (root.CharKey()):match("^([^-]*)-(.*)$"))
		for i, a in ipairs(e.alts) do
			if i > ALTS_SHOWN then
				parts[#parts + 1] = Hex(DIM, "+" .. (#e.alts - ALTS_SHOWN))
				break
			end
			local band = ns.Band(a.rank, e.r, true)
			local label = a.name
			if a.realm and myRealm and a.realm ~= myRealm then
				label = label .. "-" .. a.realm
			end
			parts[#parts + 1] = Hex(band and COLOR[band] or WHITE, label)
		end
	end
	if #parts > 0 then
		return table.concat(parts, ", ")
	end
	return ns.SourceText(e, rank)
end

function ns.Render(tooltip, groups)
	local left = ns.db.maxRecipes
	for _, g in ipairs(groups) do
		local title = Hex(GOLD, ns.LineName(g.line)) .. (g.rank and Hex(WHITE, " " .. g.rank) or "")
		local n = #g.list
		tooltip:AddDoubleLine(title, Hex(DIM, n == 1 and "1 recipe" or (n .. " recipes")))
		local shown = 0
		for _, e in ipairs(g.list) do
			if left <= 0 then
				break
			end
			tooltip:AddDoubleLine(ns.LeftText(e), ns.RightText(e, g.rank))
			shown = shown + 1
			left = left - 1
		end
		if shown > 0 and shown < n then
			tooltip:AddLine(Hex(DIM, "  +" .. (n - shown) .. " more"))
		end
	end
end

local MODIFIER_DOWN = {
	CTRL = function()
		return IsControlKeyDown and IsControlKeyDown()
	end,
	ALT = function()
		return IsAltKeyDown and IsAltKeyDown()
	end,
	SHIFT = function()
		return IsShiftKeyDown and IsShiftKeyDown()
	end,
}

function ns.ModifierDown()
	local want = ns.db.modifier
	if want == "NONE" then
		return true
	end
	local fn = MODIFIER_DOWN[want]
	local ok, down = pcall(fn)
	return ok and not Secret(down) and (down == true or down == 1)
end

-- The label of a modifier choice ("Ctrl"), as the settings dropdown shows it.
function ns.KeyLabel(value)
	for _, c in ipairs(ns.MODIFIERS) do
		if c.value == value then
			return c.label
		end
	end
	return tostring(value)
end

function ns.Annotate(tooltip, item)
	-- A clicked chat link (ItemRefTooltip) always shows the list: Ctrl-click there is the dressing room.
	if tooltip == GameTooltip and not ns.ModifierDown() then
		if ns.db.hint and ns.db.modifier ~= "NONE" then
			local n = ns.UseCount(item)
			tooltip:AddLine(Hex(DIM, "Hold " .. ns.KeyLabel(ns.db.modifier) .. ": " .. n .. (n == 1 and " recipe uses this" or " recipes use this")))
		end
		return
	end
	local groups, total = ns.Collect(item)
	if groups and total > 0 then
		ns.Render(tooltip, groups)
	end
end

local function OnItemTooltip(tooltip, data)
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
		return
	end
	if not ns.enabled or type(data) ~= "table" then
		return
	end
	-- Secret first: even a truth test on a secret value errors, and this runs outside TryQuiet.
	local item = data.id
	if Secret(item) or type(item) ~= "number" or not ns.Data.uses[item] then
		return
	end
	root.TryQuiet(ns, "tooltip", ns.Annotate, tooltip, item)
end
ns.OnItemTooltip = OnItemTooltip -- test seam

-- Tooltip hooks cannot be removed: added once, and OnItemTooltip checks ns.enabled.
function ns.HookTooltips()
	if ns.hooked then
		return
	end
	if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
		ns.hooked = true
	end
end

-- Pressing or releasing the key redraws a material tooltip that is up. An owner with UpdateTooltip
-- (bag, bank and merchant slots) redraws itself every 0.2 s, its own extra lines included, so it is
-- left alone. Other tooltips are rebuilt through RefreshData, but never in combat or an instance:
-- the rebuild runs as this addon (tainted), and tooltip data is secret there. Elsewhere, hovering the
-- item again shows the list.
function ns.OnModifier(key)
	if not ns.enabled or Secret(key) or type(key) ~= "string" then
		return
	end
	local want = ns.db.modifier
	if want == "NONE" or not key:find(want, 1, true) then
		return
	end
	local tt = GameTooltip
	if not (tt and tt.IsShown and tt:IsShown() and tt.GetItem and tt.RefreshData) then
		return
	end
	if (InCombatLockdown and InCombatLockdown()) or (IsInInstance and IsInInstance()) then
		return
	end
	local owner = tt.GetOwner and tt:GetOwner()
	if type(owner) == "table" and owner.UpdateTooltip then
		return
	end
	local ok, _, _, item = pcall(tt.GetItem, tt)
	if not ok or Secret(item) or type(item) ~= "number" or not ns.Data.uses[item] then
		return
	end
	tt:RefreshData()
end
