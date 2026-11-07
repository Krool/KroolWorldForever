-- Skill-Up Odds: the real chance a craft gives a skill point, measured from your own crafts, and
-- which learned recipe gets your next point for the least gold.
--
-- The client knows each recipe's yellow and grey skill (Data.lua, Forever's SkillLineAbility) but
-- not the chance: the server rolls it and Blizzard has never published the rule. So it is
-- measured. Every craft records the skill before it and the points it gave, pooled across the
-- account by where that skill sat between the recipe's yellow and grey (BINS equal ranges). A range
-- shows a rate once it holds MIN_SHOWN crafts. Orange always gives a point and grey never does
-- (the game's rule); both are measured as well, and a measured orange rate replaces the rule.

local _, root = ...
local ns = root.Feature("skillup")

local BINS = 10
ns.BINS = BINS
ns.MIN_SHOWN = 10 -- crafts in a range before its rate is shown
ns.LOG_MAX = 4000 -- raw crafts kept for later analysis
local RESOLVE_DELAY = 1.5 -- seconds after a craft before its result is read
local CUT = 0.05 -- auction house cut on the crafted item
local MAX_VENDOR = 3000
local TRADE_GOODS, REAGENT = 7, 5 -- item classes worth learning vendor prices for

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

local function Num(v)
	if Secret(v) or type(v) ~= "number" then
		return nil
	end
	return v
end
ns.Num = Num

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a = pcall(fn, ...)
	if ok then
		return a
	end
	return nil
end
ns.Call = Call

-- -------------------------------------------------------------------- recipe data

local index -- recipe id -> { y, g, line, child }

function ns.Recipe(id)
	if Secret(id) or type(id) ~= "number" or not ns.Data then
		return nil
	end
	if not index then
		index = {}
		for line, L in pairs(ns.Data.lines) do
			for rid, v in pairs(L.recipes) do
				index[rid] = { y = v[1], g = v[2], line = line, child = v[3] or L.child }
			end
		end
	end
	return index[id]
end

function ns.Green(r)
	return math.floor((r.y + r.g) / 2)
end

-- "orange", "yellow", "green" or "grey" for a skill against a recipe's thresholds.
function ns.Band(skill, r)
	if skill >= r.g then
		return "grey"
	end
	if skill < r.y then
		return "orange"
	end
	if skill < ns.Green(r) then
		return "yellow"
	end
	return "green"
end

-- 1..BINS: where the skill sits between yellow (start of bin 1) and grey. nil outside that span.
function ns.Bin(skill, r)
	if not skill or r.g <= r.y or skill < r.y or skill >= r.g then
		return nil
	end
	return math.min(BINS, math.floor((skill - r.y) / (r.g - r.y) * BINS) + 1)
end

-- "40-50%": the part of the yellow-to-grey span a bin covers.
function ns.BinRange(bin)
	return ("%d-%d%%"):format((bin - 1) * 100 / BINS, bin * 100 / BINS)
end

-- The client's arrow (Enum.TradeskillRelativeDifficulty) as a band.
function ns.BandOf(relative)
	local E = Enum and Enum.TradeskillRelativeDifficulty
	if relative == nil or Secret(relative) or not E then
		return nil
	end
	if relative == E.Optimal then
		return "orange"
	elseif relative == E.Medium then
		return "yellow"
	elseif relative == E.Easy then
		return "green"
	elseif relative == E.Trivial then
		return "grey"
	end
	return nil
end

-- The skill the game compares with the thresholds: the base skill, or base plus bonus (racials),
-- whichever gives the band the client shows. nil when neither does: such a craft is not put in a
-- range. Without the client's band the base skill counts only when there is no bonus to doubt.
function ns.EffectiveSkill(r, lvl, mod, clientBand)
	mod = mod or 0
	if not clientBand then
		return mod == 0 and lvl or nil
	end
	if ns.Band(lvl, r) == clientBand then
		return lvl
	end
	if mod ~= 0 and ns.Band(lvl + mod, r) == clientBand then
		return lvl + mod
	end
	return nil
end

-- -------------------------------------------------------------------- reading the skill

local function FromInfo(info)
	if type(info) ~= "table" then
		return nil
	end
	local lvl = Num(info.skillLevel)
	if not lvl or lvl <= 0 then
		return nil
	end
	return lvl, Num(info.skillModifier) or 0, Num(info.maxSkillLevel) or 0
end
ns.FromInfo = FromInfo

-- The player's skill in a recipe's profession: level, bonus, cap and the API that answered.
function ns.ReadSkill(id)
	local r = ns.Recipe(id)
	if not r then
		return nil
	end
	local T = C_TradeSkillUI
	if T then
		local lvl, mod, max = FromInfo(Call(T.GetProfessionInfoByRecipeID, id))
		if lvl then
			return lvl, mod, max, "recipe"
		end
		if r.child and r.child > 0 then
			lvl, mod, max = FromInfo(Call(T.GetProfessionInfoBySkillLineID, r.child))
			if lvl then
				return lvl, mod, max, "line"
			end
		end
	end
	local S = C_SkillInfo
	if S then
		local best
		for _, line in ipairs({ r.child or 0, r.line }) do
			if line > 0 then
				local info = Call(S.GetSkillLineInfoByID, line)
				local rank = type(info) == "table" and Num(info.rank) or nil
				if rank and rank > 0 and (not best or rank > best.rank) then
					best = { rank = rank, mod = Num(info.modifier) or 0, max = Num(info.maxRank) or 0 }
				end
			end
		end
		if best then
			return best.rank, best.mod, best.max, "skillinfo"
		end
	end
	return nil
end

function ns.ClientBand(id)
	local T = C_TradeSkillUI
	local info = T and Call(T.GetRecipeInfo, id)
	return type(info) == "table" and ns.BandOf(info.relativeDifficulty) or nil
end

-- -------------------------------------------------------------------- measured data

local function Counter()
	return { n = 0, up = 0, pts = 0 }
end

-- The account's measurements (learned data: kept out of ns.options).
function ns.Stats()
	local db = ns.db
	local st = db.stats
	if type(st) ~= "table" then
		st = {}
		db.stats = st
	end
	st.orange = st.orange or Counter()
	st.grey = st.grey or Counter()
	st.bins = st.bins or {}
	for i = 1, BINS do
		st.bins[i] = st.bins[i] or Counter()
	end
	st.recipes = st.recipes or {}
	st.log = st.log or {}
	st.skipped = st.skipped or 0
	st.mismatch = st.mismatch or 0
	st.build = st.build or (ns.Data and ns.Data.build)
	return st
end

local function Add(c, gain)
	c.n = c.n + 1
	if gain > 0 then
		c.up = c.up + 1
	end
	c.pts = c.pts + gain
end

local LETTER = { orange = "o", yellow = "y", green = "g", grey = "x" }

-- Counts one craft: skill before it (and the bonus), the points it gave, the client's band at the
-- time and the skill cap. Returns the band it was counted under, "capped", "mismatch" or nil.
function ns.Record(id, before, mod, gain, clientBand, max)
	local st = ns.Stats()
	local r = ns.Recipe(id)
	if not r or type(gain) ~= "number" or gain < 0 or gain > 5 then
		st.skipped = st.skipped + 1
		return nil
	end
	if max and max > 0 and before >= max then
		st.skipped = st.skipped + 1 -- at the cap nothing can skill up
		return "capped"
	end
	local log = st.log
	log[#log + 1] = ("%d:%d:%d:%d:%s:%d"):format(id, before, mod or 0, gain, LETTER[clientBand] or "-", time and time() or 0)
	while #log > ns.LOG_MAX do
		table.remove(log, 1)
	end
	local eff = ns.EffectiveSkill(r, before, mod, clientBand)
	if not eff then
		st.mismatch = st.mismatch + 1
		return "mismatch"
	end
	local band = ns.Band(eff, r)
	local c
	if band == "orange" then
		c = st.orange
	elseif band == "grey" then
		c = st.grey
	else
		local bin = ns.Bin(eff, r)
		c = st.bins[bin]
		local rc = st.recipes[id] or Counter()
		st.recipes[id] = rc
		Add(rc, gain)
		ns.lastBin = bin
	end
	Add(c, gain)
	if band ~= "orange" and band ~= "grey" and c.n == ns.MIN_SHOWN then
		ns.justReady = ns.lastBin -- a range just got enough crafts to show its rate
	end
	return band
end

-- -------------------------------------------------------------------- following crafts

local snap -- the skill read when a craft's cast started
local pending -- a craft that finished, waiting for its skill-up to arrive

local function Snapshot(id, guid)
	local lvl, mod, max, source = ns.ReadSkill(id)
	if not lvl then
		return nil
	end
	ns.source = source
	return { guid = guid, id = id, lvl = lvl, mod = mod, max = max, band = ns.ClientBand(id) }
end

-- Reads the skill after the pending craft and counts it. Returns the band counted, or nil.
function ns.Resolve()
	local p = pending
	if not p then
		return nil
	end
	pending = nil
	local lvl = ns.ReadSkill(p.id)
	if not lvl then
		local st = ns.Stats()
		st.skipped = st.skipped + 1
		return nil
	end
	local gain = lvl - p.lvl
	local band = ns.Record(p.id, p.lvl, p.mod, gain, p.band, p.max)
	ns.last = { id = p.id, before = p.lvl, gain = gain, band = band }
	if ns.OnRecorded then
		pcall(ns.OnRecorded, ns.last)
	end
	return band
end

function ns.Pending()
	return pending
end

local function Ours(unit, guid, spellID)
	if Secret(unit) or Secret(guid) or Secret(spellID) then
		return false
	end
	return unit == "player" and ns.db and ns.db.learn and ns.Recipe(spellID) ~= nil
end

function ns.OnCastStart(unit, guid, spellID)
	if not Ours(unit, guid, spellID) then
		return
	end
	if pending then
		ns.Resolve() -- the previous craft's point has arrived by now
	end
	snap = Snapshot(spellID, guid)
end

function ns.OnCastSucceeded(unit, guid, spellID)
	if not Ours(unit, guid, spellID) then
		return
	end
	if pending then
		ns.Resolve()
	end
	local s = snap
	snap = nil
	if not (s and s.guid == guid and s.id == spellID) then
		local st = ns.Stats()
		st.skipped = st.skipped + 1 -- no reading from before the cast (an instant craft)
		return
	end
	pending = s
	if not (C_Timer and C_Timer.After) then
		return -- the next cast or skill change counts it
	end
	C_Timer.After(RESOLVE_DELAY, function()
		if pending == s then
			pcall(ns.Resolve)
		end
	end)
end

-- A skill change while a craft waits: count it now rather than at the timer.
function ns.OnSkillChanged()
	local p = pending
	if not p then
		return
	end
	local lvl = ns.ReadSkill(p.id)
	if lvl and lvl > p.lvl then
		ns.Resolve()
	end
end

-- -------------------------------------------------------------------- odds

function ns.Wilson(k, n)
	if n <= 0 then
		return 0, 1
	end
	local z2 = 1.96 * 1.96
	local p = k / n
	local den = 1 + z2 / n
	local center = (p + z2 / (2 * n)) / den
	local half = 1.96 * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n)) / den
	return math.max(0, center - half), math.min(1, center + half)
end

local function Measured(c, band)
	local lo, hi = ns.Wilson(c.up, c.n)
	return { band = band, chance = c.up / c.n, perCraft = c.pts / c.n, n = c.n, up = c.up, pts = c.pts, lo = lo, hi = hi }
end

-- One craft's prospects at a skill: { band, chance, perCraft, n, up, lo, hi, bin, rule }.
-- chance and perCraft stay nil while the range is still being measured. rule: the game's rule
-- (orange 100%, grey 0%), not yet replaced by a measurement.
function ns.Odds(r, eff, band)
	local st = ns.Stats()
	if band == "grey" then
		return { band = band, chance = 0, perCraft = 0, rule = true, n = st.grey.n, up = st.grey.up }
	end
	if band == "orange" then
		local c = st.orange
		if c.n >= ns.MIN_SHOWN then
			return Measured(c, band)
		end
		return { band = band, chance = 1, perCraft = 1, n = c.n, up = c.up, rule = true }
	end
	local bin = ns.Bin(eff, r)
	local c = bin and st.bins[bin]
	if not c then
		return { band = band }
	end
	local o = c.n >= ns.MIN_SHOWN and Measured(c, band) or { band = band, n = c.n, up = c.up }
	o.bin = bin
	return o
end

-- -------------------------------------------------------------------- prices

local function ItemName(id)
	local name = C_Item and Call(C_Item.GetItemNameByID, id)
	if type(name) == "string" and name ~= "" and not Secret(name) then
		return name
	end
	return "item " .. id
end
ns.ItemName = ItemName

local function SellPrice(id)
	if not (C_Item and C_Item.GetItemInfo) then
		return nil
	end
	local ok, name, _, _, _, _, _, _, _, _, _, sell = pcall(C_Item.GetItemInfo, id)
	if ok and name then
		return Num(sell)
	end
	return nil
end

-- Copper for one of an item and where it came from ("vendor" or "ah"): the cheaper of a vendor
-- price seen at a merchant and Auctionator's price. nil when neither is known.
function ns.UnitCost(itemID)
	local v = ns.db.vendor and ns.db.vendor[itemID]
	local a = root.AuctionPrice(itemID)
	if v and a then
		if v <= a then
			return v, "vendor"
		end
		return a, "ah"
	end
	if v then
		return v, "vendor"
	end
	if a then
		return a, "ah"
	end
	return nil
end

-- What one craft costs: { cost, missing, reagents = { {id, qty, unit, source} }, out, outQty,
-- resale, resaleSource, net }. cost (and net) are nil when a reagent has no price; missing names it.
function ns.CraftCost(id)
	local T = C_TradeSkillUI
	local sch = T and Call(T.GetRecipeSchematic, id, false)
	if type(sch) ~= "table" then
		return nil
	end
	local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
	local res = { cost = 0, reagents = {}, resale = 0 }
	for _, slot in ipairs(type(sch.reagentSlotSchematics) == "table" and sch.reagentSlotSchematics or {}) do
		local qty = Num(slot.quantityRequired)
		if qty and qty > 0 and (basic == nil or slot.reagentType == nil or slot.reagentType == basic) then
			local bestId, bestUnit, bestSrc
			for _, rg in ipairs(type(slot.reagents) == "table" and slot.reagents or {}) do
				local rid = Num(rg.itemID)
				if rid and rid > 0 then
					local unit, src = ns.UnitCost(rid)
					if not bestId or (unit and (not bestUnit or unit < bestUnit)) then
						bestId, bestUnit, bestSrc = rid, unit, src
					end
				end
			end
			if bestId then
				res.reagents[#res.reagents + 1] = { id = bestId, qty = qty, unit = bestUnit, source = bestSrc }
				if bestUnit then
					res.cost = res.cost + qty * bestUnit
				elseif not res.missing then
					res.missing = ItemName(bestId)
				end
			end
		end
	end
	if res.missing then
		res.cost = nil
	end
	local out = Num(sch.outputItemID)
	if out and out > 0 then
		local qmin = Num(sch.quantityMin) or 1
		local qmax = Num(sch.quantityMax) or qmin
		res.out, res.outQty = out, (qmin + qmax) / 2
		if ns.db.resale then
			local each, src = SellPrice(out) or 0, "vendor"
			if ns.db.resaleAH then
				local ah = root.AuctionPrice(out)
				if ah and ah * (1 - CUT) > each then
					each, src = ah * (1 - CUT), "ah"
				end
			end
			res.resale, res.resaleSource = each * res.outQty, each > 0 and src or nil
		end
	end
	if res.cost then
		res.net = res.cost - res.resale
	end
	return res
end

local function IsReagentClass(id)
	if not (C_Item and C_Item.GetItemInfoInstant) then
		return true
	end
	local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, id)
	classID = ok and Num(classID) or nil
	return classID == TRADE_GOODS or classID == REAGENT
end

-- Notes the price of every trade good the open merchant sells. Returns how many changed.
function ns.LearnMerchant()
	if not (GetMerchantNumItems and GetMerchantItemID and C_MerchantFrame and C_MerchantFrame.GetItemInfo) then
		return 0
	end
	local n = Num(Call(GetMerchantNumItems))
	if not n then
		return 0
	end
	local vendor, changed = ns.db.vendor, 0
	local count = 0
	for _ in pairs(vendor) do
		count = count + 1
	end
	for i = 1, n do
		local id = Num(Call(GetMerchantItemID, i))
		local info = Call(C_MerchantFrame.GetItemInfo, i)
		if id and type(info) == "table" and not info.hasExtendedCost then
			local price, stack = Num(info.price), Num(info.stackCount)
			if price and price > 0 and stack and stack > 0 and IsReagentClass(id) then
				local unit = price / stack
				local known = vendor[id]
				if (known == nil and count < MAX_VENDOR) or (known and unit < known) then
					if known == nil then
						count = count + 1
					end
					vendor[id] = unit
					changed = changed + 1
				end
			end
		end
	end
	return changed
end

-- -------------------------------------------------------------------- ranking

-- The profession open in the crafting window: { line, lvl, mod, max, name } or nil.
-- Cached for the current frame: every recipe row asks.
local profCache
function ns.OpenProfession()
	local now = GetTime and GetTime() or 0
	if profCache and profCache.t == now then
		return profCache.p
	end
	local p
	local T = C_TradeSkillUI
	if T and ns.Data then
		local base, child = Call(T.GetBaseProfessionInfo), Call(T.GetChildProfessionInfo)
		local bid = type(base) == "table" and Num(base.professionID) or nil
		local cid = type(child) == "table" and Num(child.professionID) or nil
		local line = bid and ns.Data.lines[bid] and bid or nil
		if not line and cid then
			for l, d in pairs(ns.Data.lines) do
				if d.child == cid or l == cid then
					line = l
					break
				end
			end
		end
		if line then
			local lvl, mod, max = FromInfo(child)
			if not lvl then
				lvl, mod, max = FromInfo(base)
			end
			if lvl then
				local name = type(child) == "table" and child.professionName or nil
				if Secret(name) or type(name) ~= "string" or name == "" then
					name = type(base) == "table" and base.professionName or nil
				end
				p = { line = line, lvl = lvl, mod = mod, max = max, name = type(name) == "string" and not Secret(name) and name or nil }
			end
		end
	end
	profCache = { t = now, p = p }
	return p
end

function ns.ForgetProfession()
	profCache = nil
end

-- Everything shown for one recipe at the open profession's skill. withCost adds the craft's cost
-- and the expected gold per skill point (perPoint).
function ns.Evaluate(id, info, prof, withCost)
	local r = ns.Recipe(id)
	prof = prof or ns.OpenProfession()
	if not (r and prof and prof.lvl) then
		return nil
	end
	if info == nil then
		info = C_TradeSkillUI and Call(C_TradeSkillUI.GetRecipeInfo, id)
	end
	local clientBand = type(info) == "table" and ns.BandOf(info.relativeDifficulty) or nil
	local eff = ns.EffectiveSkill(r, prof.lvl, prof.mod, clientBand)
	local band = clientBand or (eff and ns.Band(eff, r))
	if not band then
		return nil
	end
	local o = ns.Odds(r, eff, band)
	o.id, o.r, o.skill = id, r, eff or prof.lvl
	if prof.max and prof.max > 0 and prof.lvl >= prof.max then
		o.capped, o.chance, o.perCraft = true, 0, 0
	end
	if withCost then
		o.craft = ns.CraftCost(id)
		if o.craft and o.craft.net and o.perCraft and o.perCraft > 0 then
			o.perPoint = o.craft.net / o.perCraft
		end
	end
	return o
end

local function Tier(o)
	if o.perPoint then
		return 1 -- odds and cost known
	elseif o.craft and o.craft.net then
		return 2 -- cost known, odds still measuring
	end
	return 3
end

local function Better(a, b)
	local ta, tb = Tier(a), Tier(b)
	if ta ~= tb then
		return ta < tb
	end
	if ta == 1 and a.perPoint ~= b.perPoint then
		return a.perPoint < b.perPoint
	end
	if ta == 2 and a.craft.net ~= b.craft.net then
		return a.craft.net < b.craft.net
	end
	return (a.name or "") < (b.name or "")
end

-- Learned recipes of the open profession that can still give a point, cheapest point first.
function ns.Rank(prof)
	prof = prof or ns.OpenProfession()
	if not prof then
		return nil
	end
	local list = {}
	local T = C_TradeSkillUI
	for id in pairs(ns.Data.lines[prof.line].recipes) do
		local info = T and Call(T.GetRecipeInfo, id)
		if type(info) == "table" and info.learned and info.canSkillUp ~= false and not info.disabled then
			local o = ns.Evaluate(id, info, prof, true)
			if o and o.band ~= "grey" then
				o.name = not Secret(info.name) and info.name or ItemName(id)
				o.icon = Num(info.icon)
				list[#list + 1] = o
			end
		end
	end
	table.sort(list, Better)
	return list, prof
end
