-- Camp Guide: what a campfire gives you. Hovering a campfire or a camp object (the chair, the
-- lodestone and the rest) shows its buff at your level and whether a class buff you already have
-- covers it; the campfire lists the objects you have hovered around it. The Camp Benefits buff
-- names any bonus in it that does not stack with a class buff you have.
--
-- The game has no camping API: an addon cannot list the objects around a fire. It knows a camp
-- object by the name its world tooltip shows, and only while you have Campfire Nearby (the aura
-- everyone close to a fire gets), so a chair in an inn is left alone.

local _, root = ...
local ns = root.Feature("camp")

local LABEL = "|cff66ccffCamp:|r "
local GREY, ORANGE, GREEN = "|cffaaaaaa", "|cffff9955", "|cff33ff99"
local SEEN_FOR = 15 * 60 -- a campfire burns about this long
local TENT_SHARE = 0.05 -- a Camp Tent tops rested experience up to 5% of a level

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- v when it is a readable value of that type, else nil.
local function Plain(v, kind)
	if Secret(v) or type(v) ~= kind then
		return nil
	end
	return v
end

local function PlayerAura(spellId)
	local fn = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	if not fn or root.AurasSecret() then
		return nil
	end
	local ok, aura = pcall(fn, spellId)
	return ok and Plain(aura, "table") or nil
end

-- A class buff on you, by its aura name (every rank shares it).
local function HasBuff(name)
	local fn = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
	if not fn or root.AurasSecret() then
		return false
	end
	local ok, aura = pcall(fn, "player", name, "HELPFUL")
	return ok and Plain(aura, "table") ~= nil
end

local function MinutesLeft(aura)
	local ends = aura and Plain(aura.expirationTime, "number")
	if not ends or ends <= 0 then
		return nil
	end
	return math.max(0, math.ceil((ends - GetTime()) / 60))
end

local function Level()
	local ok, level = pcall(UnitLevel, "player")
	level = ok and Plain(level, "number") or nil
	return level and level > 0 and level or nil
end

-- -------------------------------------------------------------------- values

-- The band for a level; without a level, the top one.
function ns.Band(bands, level)
	if not level then
		return bands[#bands]
	end
	local pick = bands[1]
	for _, band in ipairs(bands) do
		if level >= band[1] then
			pick = band
		end
	end
	return pick
end

-- What a bonus gives at a level, e.g. "+49 melee attack power" ("up to ..." without a level).
function ns.BonusText(key, level)
	local b = ns.Data.BONUSES[key]
	if b.fixed then
		return b.fixed
	end
	if b.tent then
		return "Rested experience, up to 5% of a level"
	end
	local band = ns.Band(b.bands, level)
	local prefix = level and "" or "up to "
	if b.lute then
		local parts = { ("+%d armor"):format(band[2]) }
		if band[3] > 0 then
			parts[#parts + 1] = ("+%d all stats"):format(band[3])
		end
		if band[4] > 0 then
			parts[#parts + 1] = ("+%d all resistances"):format(band[4])
		end
		return prefix .. table.concat(parts, ", ")
	end
	return prefix .. b.text:format(band[2])
end

-- The class buff you have that this bonus does not stack with, or nil.
function ns.Blocker(key)
	local b = ns.Data.BONUSES[key]
	for _, name in ipairs(b.notWith or {}) do
		if HasBuff(name) then
			return name
		end
	end
	return nil
end

-- Whether the bonus is in your Camp Benefits now (each has an aura of its own).
function ns.HaveBonus(key)
	local spell = ns.Data.BONUSES[key].spell
	return spell ~= nil and PlayerAura(spell) ~= nil
end

function ns.Nearby()
	return PlayerAura(ns.Data.NEARBY) ~= nil
end

local function Sitting()
	for _, id in ipairs(ns.Data.WELCOMING) do
		if PlayerAura(id) then
			return true
		end
	end
	return false
end

-- Why a Camp Tent would give you nothing now, or nil.
local function TentNote()
	local boosted = PlayerAura(ns.Data.BOOSTED_REST)
	if boosted then
		local m = MinutesLeft(boosted)
		return ORANGE .. "You have Boosted Rest: no more from a tent" .. (m and (" for " .. m .. " min") or "") .. "|r"
	end
	local okR, rested = pcall(GetXPExhaustion)
	local okM, perLevel = pcall(UnitXPMax, "player")
	rested = okR and Plain(rested, "number") or nil
	perLevel = okM and Plain(perLevel, "number") or nil
	if rested and perLevel and perLevel > 0 and rested >= TENT_SHARE * perLevel then
		return ORANGE .. "You already have 5% of a level rested: the tent adds none|r"
	end
	return nil
end

-- -------------------------------------------------------------------- the camp you are at

-- Camp objects hovered while near this fire: key (bonus, or the name) -> { name, bonus, at }.
local seen = {}

local function Remember(name, obj)
	seen[obj.bonus or name] = { name = name, bonus = obj.bonus, at = GetTime() }
end

function ns.Seen()
	local now, list = GetTime(), {}
	for key, s in pairs(seen) do
		if now - s.at > SEEN_FOR then
			seen[key] = nil
		else
			list[#list + 1] = s
		end
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

function ns.Forget()
	wipe(seen)
end

-- -------------------------------------------------------------------- tooltips

local function AddWrapped(tooltip, text)
	tooltip:AddLine(text, nil, nil, nil, true)
end

local function NotWithText(b)
	return b.say or b.notWith[1]
end

local function AddBonusLines(tooltip, key, level)
	local b = ns.Data.BONUSES[key]
	tooltip:AddLine(LABEL .. ns.BonusText(key, level))
	if b.tent then
		local note = TentNote()
		if note then
			AddWrapped(tooltip, note)
		end
		return
	end
	local blocker = ns.Blocker(key)
	if blocker then
		AddWrapped(tooltip, ORANGE .. "Does not stack with your " .. blocker .. "|r")
	elseif b.notWith then
		AddWrapped(tooltip, GREY .. "Does not stack with " .. NotWithText(b) .. "|r")
	end
	if ns.HaveBonus(key) then
		tooltip:AddLine(GREEN .. "In your Camp Benefits now|r")
	end
end

local function AddFireLines(tooltip, name, level)
	local D = ns.Data
	local slots = D.FIRES[name]
	if slots then
		tooltip:AddLine(LABEL .. ("holds %d camp objects"):format(slots))
	end
	local benefits = PlayerAura(D.CAMP_BENEFITS)
	if benefits then
		local m = MinutesLeft(benefits)
		tooltip:AddLine(GREEN .. "Your Camp Benefits: " .. (m and (m .. " min left") or "on") .. "|r")
	end
	AddWrapped(tooltip, GREY .. "Sit near it for 1 minute (or craft without moving): every camp object here adds its buff, for an hour.|r")
	AddWrapped(tooltip, GREY .. "Objects placed after you sat count when you sit again.|r")
	local list = ns.Seen()
	if #list == 0 then
		AddWrapped(tooltip, GREY .. "Hover the objects around it to list them here.|r")
		return
	end
	tooltip:AddLine(LABEL .. "objects you have hovered here")
	for _, s in ipairs(list) do
		local right
		if s.bonus then
			right = ns.BonusText(s.bonus, level)
			local blocker = D.BONUSES[s.bonus].notWith and ns.Blocker(s.bonus)
			if blocker then
				right = right .. " " .. ORANGE .. "(not with your " .. blocker .. ")|r"
			end
		else
			right = GREY .. (D.OBJECTS[s.name].also or "") .. "|r"
		end
		tooltip:AddDoubleLine("  " .. s.name, right, 1, 1, 1, 1, 1, 1)
	end
end

local function ObjectName(data)
	local lines = type(data) == "table" and Plain(data.lines, "table")
	local first = lines and Plain(lines[1], "table")
	local text = first and Plain(first.leftText, "string")
	if not text then
		return nil
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return strtrim(text)
end

local function AnnotateObject(tooltip, data)
	local D = ns.Data
	local name = ObjectName(data)
	if not name then
		return
	end
	local isFire = D.FIRES[name] ~= nil
	local obj = D.OBJECTS[name]
	if not (isFire or obj) then
		return
	end
	if not ns.Nearby() then
		ns.Forget() -- away from the camp: what was hovered there no longer applies
		return
	end
	local level = Level()
	if isFire then
		AddFireLines(tooltip, name, level)
		return
	end
	Remember(name, obj)
	if obj.bonus then
		AddBonusLines(tooltip, obj.bonus, level)
	end
	if obj.also then
		AddWrapped(tooltip, GREY .. obj.also .. "|r")
	end
end

-- The bonuses in Camp Benefits: by their own auras, and by the "Object: effect" lines of its
-- tooltip (in case an aura is not readable).
local function BonusesIn(data)
	local D, found, keys = ns.Data, {}, {}
	for _, key in ipairs(D.ORDER) do
		if ns.HaveBonus(key) then
			found[key] = true
		end
	end
	local lines = Plain(data.lines, "table") or {}
	for i = 2, #lines do
		local line = Plain(lines[i], "table")
		local text = line and Plain(line.leftText, "string")
		if text then
			for row in text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gmatch("[^\n]+") do
				local label = row:match("^%s*(.-)%s*:")
				local obj = label and D.OBJECTS[label]
				if obj and obj.bonus then
					found[obj.bonus] = true
				end
			end
		end
	end
	for _, key in ipairs(D.ORDER) do
		if found[key] then
			keys[#keys + 1] = key
		end
	end
	return keys
end

local function AnnotateBenefits(tooltip, data)
	local id = Plain(data.id, "number")
	if id ~= ns.Data.CAMP_BENEFITS then
		return
	end
	local keys = BonusesIn(data)
	local clash = false
	for _, key in ipairs(keys) do
		local b = ns.Data.BONUSES[key]
		local blocker = b.notWith and ns.Blocker(key)
		if blocker then
			clash = true
			AddWrapped(tooltip, ORANGE .. b.object .. ": does not stack with your " .. blocker .. "|r")
		end
	end
	if #keys > 0 and not clash then
		AddWrapped(tooltip, GREY .. "None of these overlap a class buff you have.|r")
	end
end

-- Both run on every tooltip of their kind; any failure must degrade to no line.
local function OnObjectTooltip(tooltip, data)
	if tooltip ~= GameTooltip or not (ns.enabled and ns.db and ns.db.tooltip) or type(data) ~= "table" then
		return
	end
	pcall(AnnotateObject, tooltip, data)
end
ns.OnObjectTooltip = OnObjectTooltip -- test seam

local function OnAuraTooltip(tooltip, data)
	if tooltip ~= GameTooltip or not (ns.enabled and ns.db and ns.db.benefits) or type(data) ~= "table" then
		return
	end
	pcall(AnnotateBenefits, tooltip, data)
end
ns.OnAuraTooltip = OnAuraTooltip -- test seam

-- -------------------------------------------------------------------- definition

ns.title = "Camp Guide"
ns.description = "Hover a campfire or a camp object (the chair, the lodestone and the rest) for the buff it gives at your level, "
	.. "and whether a class buff you already have covers it. The campfire lists the objects you have hovered around it."
ns.icon = "Interface\\Icons\\Spell_Fire_Fire"
ns.blurb = "What a campfire's objects give you"
ns.options = {
	{
		key = "tooltip",
		type = "toggle",
		label = "Show On Camp Objects",
		tooltip = "Adds each camp object's buff at your level to its tooltip, and on the campfire how its buffs work and the "
			.. "objects you have hovered there. Only while the game says a campfire is nearby.",
		default = true,
	},
	{
		key = "benefits",
		type = "toggle",
		label = "Notes On Camp Benefits",
		tooltip = "On the Camp Benefits buff, names any camp bonus in it that does not stack with a class buff you have, "
			.. "such as the Lodestone with Blessing of Might.",
		default = true,
	},
}
ns.slash = { "/kwc", "/campguide" }

local function StatusLine()
	local benefits = PlayerAura(ns.Data.CAMP_BENEFITS)
	if benefits then
		local m = MinutesLeft(benefits)
		return GREEN .. "Camp Benefits: " .. (m and (m .. " min left") or "on") .. "|r"
	end
	if Sitting() then
		return "Sitting by a campfire: buffs after a minute"
	end
	if ns.Nearby() then
		return "A campfire is nearby: sit by it for 1 minute"
	end
	return GREY .. "No camp buffs|r"
end

local function PrintTable()
	local level = Level()
	local D = ns.Data
	ns:Print("camp buffs" .. (level and (" at level " .. level) or "") .. ":")
	for _, key in ipairs(D.ORDER) do
		local b = D.BONUSES[key]
		local tail = ""
		local blocker = b.notWith and ns.Blocker(key)
		if blocker then
			tail = " " .. ORANGE .. "(not with your " .. blocker .. ")|r"
		elseif ns.HaveBonus(key) then
			tail = " " .. GREEN .. "(yours now)|r"
		end
		print(("  %s %s(%s)|r: %s%s"):format(b.object, GREY, b.prof, ns.BonusText(key, level), tail))
	end
	print("  " .. StatusLine())
end

function ns.OnSlash(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "options" or msg == "config" then
		root.OpenSettings(ns)
	elseif msg == "help" then
		ns:Print("/kwc - every camp buff at your level; /kwc options. Hover a campfire or a camp object near you for more.")
	else
		PrintTable()
	end
end

function ns.HubStatus()
	return StatusLine()
end

-- Tooltip hooks cannot be removed, so they are added once and check ns.enabled each time.
function ns.OnEnable()
	local kinds = TooltipDataProcessor and Enum and Enum.TooltipDataType
	if ns.hooked or not kinds or not kinds.Object or not kinds.UnitAura then
		return
	end
	ns.hooked = true
	TooltipDataProcessor.AddTooltipPostCall(kinds.Object, OnObjectTooltip)
	TooltipDataProcessor.AddTooltipPostCall(kinds.UnitAura, OnAuraTooltip)
end
