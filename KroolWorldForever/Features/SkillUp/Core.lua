-- Skill-Up Odds: the chance a craft gives a skill point, and which learned recipe gets your next
-- point for the least gold.
--
-- The client knows each recipe's yellow and grey skill (Data.lua, Forever's SkillLineAbility) but
-- not the chance: the server rolls it and Blizzard has never published the rule. The odds are the
-- community's straight line, 100% at yellow down to 0% at grey, scaled by the account's own crafts:
-- every yellow or green craft adds the line's chance to "expected" and its point (if any) to
-- "got", and the scale is got over expected, damped by PRIOR. The owner chose this on 2026-11-09
-- after 174 crafts fit the line (68 points where it expected 63); before that the odds were ten
-- separately measured ranges, which swung with every craft. The ranges are still counted, as the
-- check on the line (/kwu). Orange always gives a point and grey never does (the game's rule);
-- both are measured as well, and a measured orange rate replaces the rule.

local _, root = ...
local ns = root.Feature("skillup")

local BINS = 10
ns.BINS = BINS
ns.MIN_SHOWN = 10 -- orange crafts before their measured rate replaces the rule
ns.PRIOR = 10 -- expected points the line is trusted for before your crafts move it
ns.STEADY = 0.10 -- the panel swaps two recipes only when one's point is this much cheaper
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

-- The straight line's chance at a skill: 1 at yellow, falling to 1 / (grey - yellow) on the last
-- point before grey. nil outside yellow-to-grey.
function ns.Line(skill, r)
	if not skill or r.g <= r.y or skill < r.y or skill >= r.g then
		return nil
	end
	return (r.g - skill) / (r.g - r.y)
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

-- n crafts, up of them gave a point, pts points in all, exp the line's chances added up (the points
-- it expected).
local function Counter()
	return { n = 0, up = 0, pts = 0, exp = 0 }
end

local LETTER = { orange = "o", yellow = "y", green = "g", grey = "x" }
local BAND_OF_LETTER = { o = "orange", y = "yellow", g = "green", x = "grey" }

-- Stats before 0.13.0 had no exp. Rebuild it once from the raw log, which holds every craft so far
-- (it keeps LOG_MAX); a range with crafts older than the log takes its log average for those, or the
-- line at its middle when the log has none of it.
local function BackfillExp(st)
	local sum, cnt = {}, {}
	for _, e in ipairs(st.log) do
		local id, before, mod, _, letter = tostring(e):match("^(%d+):(%d+):(%-?%d+):(%d+):(.)")
		local r = id and ns.Recipe(tonumber(id))
		if r then
			local eff = ns.EffectiveSkill(r, tonumber(before), tonumber(mod), BAND_OF_LETTER[letter])
			local bin = eff and ns.Bin(eff, r)
			if bin then
				sum[bin] = (sum[bin] or 0) + ns.Line(eff, r)
				cnt[bin] = (cnt[bin] or 0) + 1
			end
		end
	end
	for i = 1, BINS do
		local c = st.bins[i]
		local avg = cnt[i] and sum[i] / cnt[i] or (1 - (i - 0.5) / BINS)
		c.exp = c.n * avg
	end
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
	if st.v ~= 2 then
		BackfillExp(st)
		st.v = 2
	end
	return st
end

local function Add(c, gain, expect)
	c.n = c.n + 1
	if gain > 0 then
		c.up = c.up + 1
	end
	c.pts = c.pts + gain
	c.exp = (c.exp or 0) + (expect or 0)
end

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
	local c, line
	if band == "orange" then
		c = st.orange
	elseif band == "grey" then
		c = st.grey
	else
		line = ns.Line(eff, r)
		c = st.bins[ns.Bin(eff, r)]
		local rc = st.recipes[id] or Counter()
		st.recipes[id] = rc
		Add(rc, gain, line)
	end
	Add(c, gain, line)
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

-- How the account's yellow and green crafts sit against the line: { k, n, up, exp, ptsPerUp }.
-- k = (got + PRIOR) / (expected + PRIOR): 1 with no crafts, the measured ratio once there are many.
function ns.Scale()
	local st = ns.Stats()
	local n, up, pts, exp = 0, 0, 0, 0
	for i = 1, BINS do
		local c = st.bins[i]
		n, up, pts, exp = n + c.n, up + c.up, pts + c.pts, exp + (c.exp or 0)
	end
	return {
		k = (up + ns.PRIOR) / (exp + ns.PRIOR),
		n = n,
		up = up,
		exp = exp,
		ptsPerUp = up > 0 and pts / up or 1,
	}
end

-- One craft's prospects at a skill: { band, chance, perCraft, rule, n, up, lo, hi } for orange and
-- grey; for yellow and green { band, chance, perCraft, line, scale = Scale(), bin, here = that
-- range's counter }. chance stays nil when the skill is unknown (the arrow matched neither the base
-- skill nor base plus bonus). rule: the game's rule (orange 100%, grey 0%), not yet replaced by a
-- measurement.
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
	local line = ns.Line(eff, r)
	if not line then
		return { band = band }
	end
	local S = ns.Scale()
	local chance = math.min(1, S.k * line)
	local bin = ns.Bin(eff, r)
	return { band = band, chance = chance, perCraft = chance * S.ptsPerUp, line = line, scale = S, bin = bin, here = st.bins[bin] }
end

-- -------------------------------------------------------------------- a steady ranking

local function Tier(o)
	if o.perPoint then
		return 1 -- odds and cost known
	elseif o.craft and o.craft.net then
		return 2 -- cost known, no odds
	end
	return 3
end

local function TierCost(o, tier)
	if tier == 1 then
		return o.perPoint
	elseif tier == 2 then
		return o.craft.net
	end
	return nil
end

-- The strict order for a fresh ranking: tier, then the cheaper point (or craft), then the name.
function ns.Better(a, b)
	local ta, tb = Tier(a), Tier(b)
	if ta ~= tb then
		return ta < tb
	end
	local ca, cb = TierCost(a, ta), TierCost(b, tb)
	if ca and cb and ca ~= cb then
		return ca < cb
	end
	return (a.name or "") < (b.name or "")
end

-- a has earned the place above b: a better tier, or a point (or craft) cheaper by more than STEADY.
function ns.Clearly(a, b)
	local ta, tb = Tier(a), Tier(b)
	if ta ~= tb then
		return ta < tb
	end
	local ca, cb = TierCost(a, ta), TierCost(b, tb)
	if not (ca and cb) then
		return false
	end
	return ca < cb - math.max(math.abs(cb) * ns.STEADY, 1)
end

-- A fresh ranking (list, best first) put in the previous order (prev: recipe id -> place), new
-- recipes after the known ones, then each recipe moved up past every one it clearly beats. Small
-- swings in odds or prices leave the list alone. Returns the list and its id -> place map.
function ns.Steady(list, prev)
	local out, fresh = {}, {}
	for i, o in ipairs(list) do
		out[i], fresh[o] = o, i
	end
	if prev then
		local function key(o)
			return prev[o.id] or (100000 + fresh[o])
		end
		table.sort(out, function(a, b)
			return key(a) < key(b)
		end)
		for i = 2, #out do
			local j = i
			while j > 1 and ns.Clearly(out[j], out[j - 1]) do
				out[j], out[j - 1] = out[j - 1], out[j]
				j = j - 1
			end
		end
	end
	local place = {}
	for i, o in ipairs(out) do
		place[o.id] = i
	end
	return out, place
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

-- An auction price older than root.STALE_DAYS (3) is flagged and loses to a vendor price.
function ns.Stale(age)
	return root.AuctionStale(age)
end

-- Copper for one of an item, where it came from ("vendor" or "ah") and, for an auction price, its
-- age in days: the cheaper of a vendor price seen at a merchant and Auctionator's price, except that
-- a stale auction price never beats a vendor price. nil when neither is known.
function ns.UnitCost(itemID)
	local v = ns.db.vendor and ns.db.vendor[itemID]
	local a = root.AuctionPrice(itemID)
	local age = a and root.AuctionAge(itemID)
	if v and a then
		if v <= a or ns.Stale(age) then
			return v, "vendor"
		end
		return a, "ah", age
	end
	if v then
		return v, "vendor"
	end
	if a then
		return a, "ah", age
	end
	return nil
end

-- What one craft costs: { cost, missing, reagents = { {id, qty, unit, source, age} }, out, outQty,
-- resale, resaleSource, net, stale }. cost (and net) are nil when a reagent has no price; missing
-- names it. stale: the oldest stale auction price used, in days.
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
			local bestId, bestUnit, bestSrc, bestAge
			for _, rg in ipairs(type(slot.reagents) == "table" and slot.reagents or {}) do
				local rid = Num(rg.itemID)
				if rid and rid > 0 then
					local unit, src, age = ns.UnitCost(rid)
					if not bestId or (unit and (not bestUnit or unit < bestUnit)) then
						bestId, bestUnit, bestSrc, bestAge = rid, unit, src, age
					end
				end
			end
			if bestId then
				res.reagents[#res.reagents + 1] = { id = bestId, qty = qty, unit = bestUnit, source = bestSrc, age = bestAge }
				if ns.Stale(bestAge) and (not res.stale or bestAge > res.stale) then
					res.stale = bestAge
				end
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
				if ah and ns.Stale(root.AuctionAge(out)) then
					ah = nil -- an old price is no promise the result still sells for it
				end
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
	table.sort(list, ns.Better)
	return list, prof
end
