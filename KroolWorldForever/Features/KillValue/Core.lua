-- Kill Value: expected gold per kill on creature tooltips, for WoW Forever.
-- Built for the Forever Mainline client (Interface 16001).
--
-- value(npc) = average coin drop + sum(drop chance x average stack x item price)
--
-- Two data layers, blended per item:
--   baseline  Data.lua, generated from the cmangos classic-db vanilla world database
--             ("Era baseline": Forever may have rebalanced loot and has creatures it lacks).
--   learned   the feature's saved slice (db.learned), recorded from the loot windows you open on corpses.
--     estimate = (observed + K * baseline) / (corpses + K)        K = PSEUDO_KILLS
--   With no baseline, observed-only estimates are used once MIN_OBSERVED corpses are looted.
--
-- Prices: best of vendor (client item info, else the baseline price) and, when Auctionator is
-- installed, its price minus the auction house cut. Never an AH price for bind-on-pickup or
-- poor-quality (grey) items; quest items are worth 0.
--
-- Gathering (Skinning, Herbalism, Mining on creatures) comes from the baseline only. It joins the
-- total when the player knows the profession with enough skill; a gathering loot window is
-- never learned as corpse loot.
--
-- Midnight restrictions: any value that might be secret is checked with issecretvalue before it
-- is read, and every entry point that touches game data is wrapped in pcall by its caller.

local _, root = ...
local ns = root.Feature("killvalue")

local FKV = {}
root.public.KillValue = FKV -- public API: KroolWorldForever.KillValue.GetKillValue(npcID)
ns.FKV = FKV

local PSEUDO_KILLS = 10 -- weight of the baseline, in corpses
local MIN_OBSERVED = 3 -- corpses needed to trust observed-only data
local CACHE_MAX = 64 -- per-NPC breakdowns held
local CACHE_TTL = 600 -- seconds a breakdown or price stays valid
local REPORT_TOP, REPORT_RARE = 10, 5 -- contributor rows kept per breakdown
local MAX_NPCS = 2500 -- learned creatures kept
local MAX_ITEMS = 100 -- learned item rows kept per creature
local RECENT_MAX = 200 -- looted corpse GUIDs remembered for dedupe
local SKILL_TTL = 60 -- seconds before gathering skills are read again (SKILL_LINES_CHANGED also does)
-- Skill lines per gathering kind: the profession and its Forever child line (SkillLine, 1.60.1.70790).
local GATHER_SKILLS = { S = { 393, 2947 }, H = { 182, 2944 }, M = { 186, 2946 } }

FKV.PSEUDO_KILLS, FKV.MIN_OBSERVED = PSEUDO_KILLS, MIN_OBSERVED

FKV.DEFAULTS = {
	detail = 3, -- top-N contributor lines under the total (0 = none)
	vendor = true, -- vendor sell price as fallback and floor
	ah = true, -- use Auctionator prices when it is installed
	cut = 5, -- auction house cut in percent, taken off AH values
	rare = 0.001, -- drops with expected quantity below this (0.1%) go to a "rare drops" line
	gather = true, -- add the gathering value to the total when the player can gather the creature
	skin = false, -- also show the gathering value of creatures the player cannot gather (not in the total)
	friendly = false, -- show the line on friendly (non-attackable) creatures too
	learn = true, -- record loot from corpses you open
	hello = true, -- login message
}
-- (the tooltip line's on/off is the bundle's per-feature Enabled switch)

local cfg = {}
for k, v in pairs(FKV.DEFAULTS) do
	cfg[k] = v
end
FKV.cfg = cfg

local function Now()
	return GetTime and GetTime() or 0
end

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- -------------------------------------------------------------------- guid

local function Split(s, sep)
	local parts, pos = {}, 1
	while true do
		local at = s:find(sep, pos, true)
		if not at then
			parts[#parts + 1] = s:sub(pos)
			return parts
		end
		parts[#parts + 1] = s:sub(pos, at - 1)
		pos = at + #sep
	end
end

-- "Creature-0-<server>-<instance>-<zone>-<npcID>-<spawn>". Forever obfuscates the server and
-- spawn parts, so only the kind and the 6th field are read. Returns npcID (or nil) and the
-- kind word. Pets, players, objects, secret and malformed values all give nil.
function FKV.ParseGUID(guid)
	if guid == nil or Secret(guid) or type(guid) ~= "string" then
		return nil
	end
	local parts = Split(guid, "-")
	local kind = parts[1]
	if kind ~= "Creature" and kind ~= "Vehicle" then
		return nil, kind
	end
	local field = parts[6]
	if not field or not field:match("^%d+$") then
		return nil, kind
	end
	local id = tonumber(field)
	if not id or id <= 0 then
		return nil, kind
	end
	return id, kind
end

-- -------------------------------------------------------------------- formatting

FKV.Money = root.Money -- Core/Prices.lua

function FKV.FmtQty(q)
	if q >= 1 then
		return ("x%.1f"):format(q)
	elseif q >= 0.01 then
		return ("%.0f%%"):format(q * 100)
	end
	return ("%.2f%%"):format(q * 100)
end

-- -------------------------------------------------------------------- baseline data

local mobCache, refCache = {}, {}

local function ParsePairs(s)
	local list = {}
	if not s or s == "" then
		return list
	end
	for id, q in s:gmatch("(%d+):([%d%.e%-]+)") do
		list[#list + 1] = { tonumber(id), tonumber(q) }
	end
	return list
end

local function GetRef(refId)
	local r = refCache[refId]
	if r then
		return r
	end
	r = ParsePairs(ns.Data and ns.Data.ref and ns.Data.ref[refId])
	refCache[refId] = r
	return r
end

local function ParseMob(s)
	local coin, drops, refs, skin, info = s:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|?(.*)$")
	if not coin then
		return nil
	end
	local gather = "S"
	local g, rest = skin:match("^([HM]):(.*)$")
	if g then
		gather, skin = g, rest
	end
	local cmin, cmax = coin:match("^(%d+):(%d+)$")
	local lvl, rank, hp = info:match("^(%d+):(%d+):(%d+)$")
	return {
		coinMin = tonumber(cmin) or 0,
		coinMax = tonumber(cmax) or 0,
		drops = ParsePairs(drops),
		refs = ParsePairs(refs),
		skin = ParsePairs(skin),
		gather = gather,
		lvl = tonumber(lvl),
		rank = tonumber(rank),
		hp = tonumber(hp),
	}
end

local function GetMob(npcId)
	local m = mobCache[npcId]
	if m ~= nil then
		return m or nil
	end
	local s = ns.Data and ns.Data.mob and ns.Data.mob[npcId]
	m = s and ParseMob(s) or nil
	mobCache[npcId] = m or false
	return m
end

-- -------------------------------------------------------------------- gathering

local gatherItems -- itemId -> "S" | "H" | "M": what any baseline creature yields to gathering

local function GatherItems()
	if gatherItems then
		return gatherItems
	end
	gatherItems = {}
	for _, s in pairs((ns.Data and ns.Data.mob) or {}) do
		local seg = type(s) == "string" and s:match("^[^|]*|[^|]*|[^|]*|([^|]*)")
		if seg and seg ~= "" then
			local kind, rest = seg:match("^([HM]):(.*)$")
			kind, seg = kind or "S", rest or seg
			for id in seg:gmatch("(%d+):") do
				id = tonumber(id)
				gatherItems[id] = gatherItems[id] or kind
			end
		end
	end
	return gatherItems
end

-- Items the creature's baseline lists as corpse loot (direct drops and reference pools).
local function LootSet(npcId)
	local set, base = {}, GetMob(npcId)
	if base then
		for _, d in ipairs(base.drops) do
			set[d[1]] = true
		end
		for _, r in ipairs(base.refs) do
			for _, d in ipairs(GetRef(r[1])) do
				set[d[1]] = true
			end
		end
	end
	return set
end

-- A gathering yield, not loot: some creature gathers into it and this one does not drop it.
-- Checked against every creature, because the baseline lacks some creatures' gathering lists.
local function GatherKind(itemId, loot)
	local kind = GatherItems()[itemId]
	if kind and not loot[itemId] then
		return kind
	end
	return nil
end

-- A loot window from Skinning, Herbalism or Mining on a corpse: no coins, and every item is a
-- gathering yield of the kind. Returns the kind, or nil for corpse loot.
local function GatherWindow(npcId, e)
	if e.coin > 0 then
		return nil
	end
	local loot, kind = LootSet(npcId), nil
	for id in pairs(e.items) do
		local k = GatherKind(id, loot)
		if not k or (kind and k ~= kind) then
			return nil
		end
		kind = k
	end
	return kind
end

local skills, skillsAt, skillSig = nil, nil, "" -- kind -> effective skill, 0 = not learned

local function ReadSkill(ids)
	local best = 0
	for _, id in ipairs(ids) do
		local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, id)
		if ok and type(info) == "table" and not Secret(info.rank) and type(info.rank) == "number" then
			local mod = info.modifier
			if Secret(mod) or type(mod) ~= "number" then
				mod = 0
			end
			best = math.max(best, info.rank + mod)
		end
	end
	return best
end

-- Reads the player's gathering skills. Without C_SkillInfo they stay unknown (nil).
function FKV.RefreshSkills()
	skillsAt = Now()
	if not (C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID) then
		skills, skillSig = nil, ""
		return
	end
	skills = {}
	for kind, ids in pairs(GATHER_SKILLS) do
		skills[kind] = ReadSkill(ids)
	end
	skillSig = skills.S .. ":" .. skills.H .. ":" .. skills.M
end

local function SkillSig()
	if not skillsAt or Now() - skillsAt > SKILL_TTL then
		FKV.RefreshSkills()
	end
	return skillSig
end

-- Effective skill (rank plus bonuses) in the profession that gathers `kind` ("S", "H", "M"):
-- 0 = not learned, nil = unknown.
function FKV.GatherSkill(kind)
	SkillSig()
	return skills and skills[kind]
end

-- Skill a creature of `level` needs, by the classic rule (cmangos): (level - 10) x 10 below
-- level 20, level x 5 from 20 on. A level 25 beast needs 125.
function FKV.GatherNeed(level)
	level = level or 1
	if level < 20 then
		return math.max(1, (level - 10) * 10)
	end
	return level * 5
end

-- Before 0.6.0 a corpse gathered before it was looted had the gathering yield recorded as its
-- loot. Strips those items once. The corpse count stays: such a corpse had nothing to loot.
-- Returns the number of creatures cleaned.
local function CleanGatherLoot(db)
	if db.gatherClean or not (ns.Data and ns.Data.mob) then
		return 0
	end
	db.gatherClean = true
	local cleaned = 0
	for npcId, rec in pairs(db.learned) do
		if type(rec) == "table" and type(rec.items) == "table" then
			local loot, hit = LootSet(npcId), false
			for id in pairs(rec.items) do
				if GatherKind(id, loot) then
					rec.items[id] = nil
					hit = true
				end
			end
			if hit then
				cleaned = cleaned + 1 -- AttachDB has just emptied the breakdown cache
			end
		end
	end
	return cleaned
end

-- -------------------------------------------------------------------- learned data

local recentList, recentSet = {}, {}

-- Called with the feature's saved slice once it exists (and by tests after swapping it).
function FKV.AttachDB(db)
	ns.db = db
	for k, v in pairs(FKV.DEFAULTS) do
		if db[k] == nil then
			db[k] = v
		end
	end
	cfg = db -- the generic settings panel writes into this table, so it is the live config
	FKV.cfg = db
	FKV.ClearPriceCache()
	db.learned = db.learned or {}
	db.recent = db.recent or {}
	recentList, recentSet = db.recent, {}
	for _, g in ipairs(recentList) do
		recentSet[g] = true
	end
	FKV.cleaned = CleanGatherLoot(db) -- creatures cleaned now (reported at login)
end

local function Learned(npcId)
	local rec = ns.db and ns.db.learned and ns.db.learned[npcId]
	if rec and rec.n and rec.n > 0 then
		return rec
	end
	return nil
end
FKV.GetLearned = Learned

local function EvictNPCs(keep)
	local count, worst, worstN = 0, nil, nil
	for id, rec in pairs(ns.db.learned) do
		count = count + 1
		if id ~= keep and (not worstN or rec.n < worstN) then
			worst, worstN = id, rec.n
		end
	end
	if count > MAX_NPCS and worst then
		ns.db.learned[worst] = nil
	end
end

local function TrimItems(rec, keep)
	local count, worst, worstQ = 0, nil, nil
	for id, q in pairs(rec.items) do
		count = count + 1
		if id ~= keep and (not worstQ or q < worstQ) then
			worst, worstQ = id, q
		end
	end
	if count > MAX_ITEMS and worst then
		rec.items[worst] = nil
	end
end

-- Counts one looted corpse. Returns false when the GUID was already counted (reopened window,
-- LOOT_READY plus LOOT_OPENED, skinning after looting) or there is nowhere to store it.
function FKV.RecordCorpse(npcId, guid, coin, items)
	if not (ns.db and ns.db.learned) or not npcId or type(guid) ~= "string" then
		return false
	end
	if recentSet[guid] then
		return false
	end
	recentSet[guid] = true
	recentList[#recentList + 1] = guid
	while #recentList > RECENT_MAX do
		recentSet[table.remove(recentList, 1)] = nil
	end
	local rec = ns.db.learned[npcId]
	if not rec then
		rec = { n = 0, coin = 0, items = {} }
		ns.db.learned[npcId] = rec
		EvictNPCs(npcId)
	end
	rec.n = rec.n + 1
	rec.coin = rec.coin + (coin or 0)
	for id, q in pairs(items or {}) do
		rec.items[id] = (rec.items[id] or 0) + q
		TrimItems(rec, id)
	end
	FKV.Invalidate(npcId)
	return true
end

-- A loot window opened on a live creature is a pickpocket, not a corpse.
local function IsLiveUnit(guid)
	for _, token in ipairs({ "target", "mouseover", "focus" }) do
		local ok, g = pcall(UnitGUID, token)
		if ok and g ~= nil and not Secret(g) and g == guid then
			local ok2, dead = pcall(UnitIsDead, token)
			if ok2 and not Secret(dead) and dead == false then
				return true
			end
		end
	end
	return false
end

-- Reads the open loot window and attributes every slot to its source corpse. Only creature
-- GUIDs count (fishing, objects and item containers have other kinds). Any secret value
-- aborts the whole capture. A gathering window is skipped when the player knows that
-- gathering profession (or it cannot be told): skinning after looting is already deduped, and
-- skinning first means the corpse had nothing to loot, or someone else looted it.
-- Returns the number of corpses newly recorded.
function FKV.CaptureLoot()
	if not (ns.db and cfg.learn) then
		return 0
	end
	if IsFishingLoot and IsFishingLoot() then
		return 0
	end
	local num = GetNumLootItems()
	if Secret(num) or type(num) ~= "number" or num < 1 then
		return 0
	end
	local per, order = {}, {}
	local function entry(guid)
		local e = per[guid]
		if not e then
			e = { coin = 0, items = {} }
			per[guid] = e
			order[#order + 1] = guid
		end
		return e
	end
	local Slot = Enum.LootSlotType
	for slot = 1, num do
		local kind = GetLootSlotType(slot)
		if Secret(kind) then
			return 0
		end
		if kind == Slot.Item or kind == Slot.Money then
			local src = { GetLootSourceInfo(slot) }
			local itemId
			if kind == Slot.Item then
				local link = GetLootSlotLink(slot)
				if Secret(link) then
					return 0
				end
				itemId = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
			end
			for i = 1, #src, 2 do
				local guid, q = src[i], src[i + 1]
				if Secret(guid) or Secret(q) then
					return 0
				end
				if type(guid) == "string" then
					local e = entry(guid)
					q = type(q) == "number" and q or 0
					if kind == Slot.Money then
						e.coin = e.coin + q
					elseif itemId then
						e.items[itemId] = (e.items[itemId] or 0) + math.max(q, 1)
					end
				end
			end
		end
	end
	local recorded = 0
	for _, guid in ipairs(order) do
		local npcId = FKV.ParseGUID(guid)
		if npcId and not IsLiveUnit(guid) then
			local e = per[guid]
			local kind = GatherWindow(npcId, e)
			local gathered = kind ~= nil and FKV.GatherSkill(kind) ~= 0
			if not gathered and FKV.RecordCorpse(npcId, guid, e.coin, e.items) then
				recorded = recorded + 1
			end
		end
	end
	return recorded
end

-- -------------------------------------------------------------------- blending

-- Estimated quantity per kill. `baseline` is nil when the creature has no baseline entry.
-- Returns the estimate and a source word: "baseline", "blended", "learned" or nil (not enough data).
function FKV.Blend(observed, corpses, baseline)
	corpses = corpses or 0
	if baseline ~= nil then
		local est = ((observed or 0) + PSEUDO_KILLS * baseline) / (corpses + PSEUDO_KILLS)
		return est, corpses > 0 and "blended" or "baseline"
	end
	if corpses >= MIN_OBSERVED then
		return (observed or 0) / corpses, "learned"
	end
	return nil, nil
end

-- -------------------------------------------------------------------- prices

local priceCache = {} -- itemId -> { t, sig, price, src }
local requested, pending = {}, {} -- item load requests already sent / still outstanding

local function Sig()
	return table.concat({
		tostring(cfg.vendor),
		tostring(cfg.ah),
		tostring(cfg.cut),
		tostring(cfg.rare),
		tostring(cfg.detail),
		tostring(cfg.skin),
		tostring(cfg.gather),
		SkillSig(),
	}, "|")
end

-- Auctionator is optional (Core/Prices.lua checks every step).
function FKV.AuctionPrice(itemId)
	return root.AuctionPrice(itemId)
end

-- Quality, bonding, vendor price, quest flag. Client item info when cached; otherwise ask the
-- client to load it and fall back to the baseline tables.
local function ItemFacts(itemId)
	local ok, name, _, quality, _, _, _, _, _, _, _, sellPrice, classID, _, bindType =
		pcall(C_Item.GetItemInfo, itemId)
	if ok and name then
		return quality, bindType or 0, sellPrice or 0, classID == 12
	end
	if not requested[itemId] then
		requested[itemId] = true
		pending[itemId] = true
		pcall(C_Item.RequestLoadItemDataByID, itemId)
	end
	local D = ns.Data
	local meta = D and D.meta and D.meta[itemId]
	local sell = D and D.sell and D.sell[itemId]
	if meta then
		return math.floor(meta / 16), meta % 16, sell or 0, false
	end
	return nil, nil, sell, false
end

-- Unit price in copper and its source ("ah", "vendor", "quest"), or nil when unknown.
local function PriceUncached(itemId)
	local quality, bind, vendor, isQuest = ItemFacts(itemId)
	if bind == 4 or isQuest then
		return 0, "quest"
	end
	local best, src
	if cfg.ah and bind ~= 1 and quality ~= 0 then
		local ah = FKV.AuctionPrice(itemId)
		if ah then
			best, src = ah * (1 - (cfg.cut or 0) / 100), "ah"
		end
	end
	if cfg.vendor and vendor and vendor > 0 and (not best or vendor > best) then
		best, src = vendor, "vendor"
	end
	return best, src
end

function FKV.Price(itemId)
	local sig, now = Sig(), Now()
	local hit = priceCache[itemId]
	if hit and hit.sig == sig and now - hit.t < CACHE_TTL then
		return hit.price, hit.src
	end
	local price, src = PriceUncached(itemId)
	priceCache[itemId] = { t = now, sig = sig, price = price, src = src }
	return price, src
end

-- -------------------------------------------------------------------- compute

local computeCache, computeCount = {}, 0

function FKV.Invalidate(npcId)
	if computeCache[npcId] then
		computeCache[npcId] = nil
		computeCount = computeCount - 1
	end
end

function FKV.ClearPriceCache()
	priceCache = {}
	computeCache, computeCount = {}, 0
end

function FKV.ClearCaches()
	FKV.ClearPriceCache()
	mobCache, refCache, gatherItems = {}, {}, nil
	skillsAt = nil
end

-- Called when the client delivers item data we asked for: prices that fell back to the
-- baseline may now differ, so drop the caches once per outstanding item.
function FKV.ItemLoaded(itemId)
	if pending[itemId] then
		pending[itemId] = nil
		FKV.ClearPriceCache()
	end
end

local function AddQty(acc, id, qty)
	local c = acc.byItem[id]
	if c then
		c.qty = c.qty + qty
	else
		c = { id = id, qty = qty }
		acc.byItem[id] = c
		acc.all[#acc.all + 1] = c
	end
end

local function ByValue(a, b)
	if a.value ~= b.value then
		return a.value > b.value
	end
	return a.id < b.id
end

-- Returns nil (nothing known) or a breakdown:
--   { total, gold, loot, rare, skin, gather, need, canGather, skinCounted, known, unknown,
--     kills, source, top = { {id, qty, value, src}... }, raretop = { same, below the rare threshold } }
-- source: "baseline" | "blended" | "learned" | "learning" (then total is nil).
-- total = gold + loot, plus skin when skinCounted (the player can gather it and the option is on).
-- need/canGather are set when the player knows the profession; rare drops stay outside the total.
function FKV.Compute(npcId)
	local sig, now = Sig(), Now()
	local hit = computeCache[npcId]
	if hit and hit.sig == sig and now - hit.t < CACHE_TTL then
		return hit.acc
	end
	local base = GetMob(npcId)
	local L = Learned(npcId)
	local n = L and L.n or 0
	local acc
	if not base and n < MIN_OBSERVED then
		if n == 0 then
			return nil
		end
		acc = { learning = true, source = "learning", kills = n, known = 0, unknown = 0, top = {}, raretop = {} }
	else
		acc = {
			rare = 0,
			loot = 0,
			skin = 0,
			known = 0,
			unknown = 0,
			kills = n,
			top = {},
			raretop = {},
			all = {},
			byItem = {},
			gather = base and base.gather or "S",
			lvl = base and base.lvl,
			rank = base and base.rank,
			hp = base and base.hp,
		}
		-- baseline quantities per item (an item can arrive via several pools)
		local baseQty = {}
		if base then
			for _, d in ipairs(base.drops) do
				baseQty[d[1]] = (baseQty[d[1]] or 0) + d[2]
			end
			for _, r in ipairs(base.refs) do
				for _, d in ipairs(GetRef(r[1])) do
					baseQty[d[1]] = (baseQty[d[1]] or 0) + d[2] * r[2]
				end
			end
		end
		local source
		local coinBase = base and (base.coinMin + base.coinMax) / 2 or nil
		acc.gold, source = FKV.Blend(L and L.coin or 0, n, coinBase)
		acc.source = source
		local ids = {}
		for id in pairs(baseQty) do
			ids[id] = true
		end
		if L then
			for id in pairs(L.items) do
				ids[id] = true
			end
		end
		for id in pairs(ids) do
			local est = FKV.Blend(L and L.items[id] or 0, n, base and (baseQty[id] or 0) or nil)
			if est and est > 0 then
				AddQty(acc, id, est)
			end
		end
		for _, c in ipairs(acc.all) do
			local price, src = FKV.Price(c.id)
			if price then
				c.value, c.src = c.qty * price, src
				acc.known = acc.known + 1
				if c.qty < cfg.rare then
					acc.rare = acc.rare + c.value
					acc.raretop[#acc.raretop + 1] = c
				else
					acc.loot = acc.loot + c.value
					acc.top[#acc.top + 1] = c
				end
			else
				acc.unknown = acc.unknown + 1
			end
		end
		if base then
			for _, d in ipairs(base.skin) do
				local price = FKV.Price(d[1])
				if price then
					acc.skin = acc.skin + d[2] * price
				end
			end
		end
		acc.total = acc.gold + acc.loot
		if acc.skin > 0 then
			local skill = FKV.GatherSkill(acc.gather)
			if skill and skill > 0 then
				acc.need = FKV.GatherNeed(acc.lvl)
				acc.canGather = skill >= acc.need
				if acc.canGather and cfg.gather then
					acc.skinCounted = true
					acc.total = acc.total + acc.skin
				end
			end
		end
		table.sort(acc.top, ByValue)
		table.sort(acc.raretop, ByValue)
		acc.byItem, acc.all = nil, nil
		local keepTop = math.max(REPORT_TOP, cfg.detail or 0)
		while #acc.top > keepTop do
			table.remove(acc.top)
		end
		while #acc.raretop > REPORT_RARE do
			table.remove(acc.raretop)
		end
	end
	if not computeCache[npcId] then
		if computeCount >= CACHE_MAX then
			computeCache, computeCount = {}, 0
		end
		computeCount = computeCount + 1
	end
	computeCache[npcId] = { t = now, sig = sig, acc = acc }
	return acc
end

function FKV.CacheStats()
	return computeCount
end

-- Public: expected copper per kill, or nil.
function FKV.GetKillValue(npcId)
	local ok, acc = pcall(FKV.Compute, npcId)
	return ok and acc and acc.total or nil
end

function FKV.SourceTag(acc)
	if acc.source == "baseline" then
		return "baseline"
	elseif acc.source == "learned" then
		return ("learned, %d kills"):format(acc.kills or 0)
	elseif acc.source == "blended" then
		return "blended"
	end
	return ("learning (%d kills)"):format(acc.kills or 0)
end
