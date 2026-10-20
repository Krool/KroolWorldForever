-- Kill Value behavior checks. Runs after stubs.lua and the whole bundle.

local failures, count = 0, 0
local realPrint = print
local function check(label, got, want)
	count = count + 1
	if got ~= want then
		failures = failures + 1
		realPrint("FAIL: " .. label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
	else
		realPrint("ok:   " .. label)
	end
end
local function near(label, got, want, eps)
	count = count + 1
	if type(got) ~= "number" or math.abs(got - want) > (eps or 1e-9) then
		failures = failures + 1
		realPrint("FAIL: " .. label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
	else
		realPrint("ok:   " .. label)
	end
end
local function has(list, needle)
	for _, l in ipairs(list) do
		if tostring(l):find(needle, 1, true) then
			return true
		end
	end
	return false
end

local ns = __ns.features.killvalue
local FKV = KroolWorldForever.KillValue
local SV = "KroolWorldForever_killvalue_"

local function G(id, spawn)
	return "Creature-0-4170-0-0-" .. id .. "-" .. (spawn or "0000A1B2")
end

local Printed = {}
local function capture(fn)
	Printed = {}
	print = function(...)
		local t = {}
		for i = 1, select("#", ...) do
			t[#t + 1] = tostring((select(i, ...)))
		end
		Printed[#Printed + 1] = table.concat(t, " ")
	end
	local ok, err = pcall(fn)
	print = realPrint
	if not ok then
		error(err)
	end
	return Printed
end

local function fresh()
	FKV.AttachDB({})
	FKV.ClearCaches()
	Clock = 1000
	InInstance = false
	ItemCache = {}
	LoadRequests = {}
	Auctionator = nil
	Units = {}
	Loot = { slots = {}, fishing = false }
	TooltipUnitToken = "mouseover"
end

-- ---------------------------------------------------------------- shipped data sentinels

do
	local D = ns.Data
	check("Data.lua loaded", type(D), "table")
	check("baseline covers thousands of creatures", D.creatures > 3000, true)
	check("baseline has item meta", D.items > 3000, true)
	check("Forest Spider (30) has baseline loot", D.mob[30] ~= nil, true)
	check("baseline has vendor prices", next(D.sell) ~= nil, true)
	check("baseline labels its source", D.source:find("Era baseline", 1, true) ~= nil, true)
end

-- ---------------------------------------------------------------- lifecycle

do
	FireEvent("ADDON_LOADED", "SomeOtherAddon")
	check("other addon's ADDON_LOADED ignored", KroolWorldForeverDB, nil)
	FireEvent("ADDON_LOADED", "KroolWorldForever")
	check("SavedVariables table created", type(KroolWorldForeverDB), "table")
	local slice = KroolWorldForeverDB.features.killvalue
	check("feature slice created", type(slice), "table")
	check("feature slice is ns.db", ns.db, slice)
	check("defaults filled", slice.detail, 3)
	check("feature enabled by default", slice.enabled, true)
	check("learned store created", type(slice.learned), "table")
	check("public API exposed", KroolWorldForever.KillValue, FKV)
	check("settings panel registered", RegisteredSettings[SV .. "enabled"] ~= nil, true)
	check("detail slider registered", RegisteredSettings[SV .. "detail"] ~= nil, true)
	check("cut slider registered", RegisteredSettings[SV .. "cut"] ~= nil, true)
	local toggles = 0
	for _, key in ipairs({ "learn", "vendor", "ah", "skin", "friendly", "hello" }) do
		if RegisteredSettings[SV .. key] then
			toggles = toggles + 1
		end
	end
	check("six toggle options registered", toggles, 6)
	check("no standalone master switch option", RegisteredSettings[SV .. "enabled"].label, "Enabled")
	check("not enabled before login", ns.enabled, false)
	check("tooltip hook not installed before login", TooltipCallbacks[Enum.TooltipDataType.Unit], nil)
	FireEvent("PLAYER_LOGIN")
	check("enabled after login", ns.enabled, true)
	check("unit tooltip hook installed", type(TooltipCallbacks[Enum.TooltipDataType.Unit]), "function")
	for _, e in ipairs({ "LOOT_READY", "LOOT_OPENED", "GET_ITEM_INFO_RECEIVED" }) do
		local found = false
		for _, f in ipairs(CreatedFrames) do
			found = found or f.events[e] == true
		end
		check("registered for " .. e, found, true)
	end
	check("slash registered", type(SlashCmdList.KROOLWORLDFOREVER_KILLVALUE), "function")
	check("/fkv alias", SLASH_KROOLWORLDFOREVER_KILLVALUE1, "/fkv")
	check("compartment click defined", type(KroolWorldForever_OnCompartmentClick), "function")
	KroolWorldForever_OnCompartmentClick()
	check("compartment click opens the bundle settings category", OpenedCategory, "Krool World Forever")
end

-- ---------------------------------------------------------------- GUID parsing

do
	check("creature guid -> npc id", (FKV.ParseGUID("Creature-0-4170-0-0-1234-00005678")), 1234)
	check("obfuscated server/spawn fields still parse", (FKV.ParseGUID("Creature-0-zzQ9-Xx-77-2345-ab!cd")), 2345)
	check("empty obfuscated fields keep positions", (FKV.ParseGUID("Creature-0--0-0-77-")), 77)
	check("vehicle guid parses", (FKV.ParseGUID("Vehicle-0-1-2-3-555-4")), 555)
	local id, kind = FKV.ParseGUID("Pet-0-1-2-3-555-4")
	check("pet guid ignored", id, nil)
	check("pet kind reported", kind, "Pet")
	check("player guid ignored", (FKV.ParseGUID("Player-1234-0ABCDEF0")), nil)
	check("game object ignored", (FKV.ParseGUID("GameObject-0-1-2-3-555-4")), nil)
	check("too few fields", (FKV.ParseGUID("Creature-0-1")), nil)
	check("non-numeric npc field", (FKV.ParseGUID("Creature-0-1-2-3-abc-4")), nil)
	check("zero npc id", (FKV.ParseGUID("Creature-0-1-2-3-0-4")), nil)
	check("nil guid", (FKV.ParseGUID(nil)), nil)
	check("number is not a guid", (FKV.ParseGUID(12345)), nil)
	check("secret guid ignored", (FKV.ParseGUID(Secret())), nil)
	check("secret string guid ignored even though it looks valid", (FKV.ParseGUID(SecretGuid)), nil)
end

-- ---------------------------------------------------------------- blending math

do
	local est, src = FKV.Blend(0, 0, 0.5)
	near("no kills: pure baseline", est, 0.5)
	check("no kills: source baseline", src, "baseline")
	est, src = FKV.Blend(10, 10, 0.5)
	near("10 kills of 1.0 against baseline 0.5: (10+5)/20", est, 0.75)
	check("source blended", src, "blended")
	est = FKV.Blend(10, 10, 0)
	near("item the baseline lacks, seen 10/10: 10/20", est, 0.5)
	est = FKV.Blend(0, 90, 1)
	near("90 kills never dropping it pulls 1.0 down to 0.1", est, 0.1)
	est, src = FKV.Blend(5, 2, nil)
	check("no baseline, 2 kills: not enough", est, nil)
	check("no source either", src, nil)
	est, src = FKV.Blend(6, 3, nil)
	near("no baseline, 3 kills: observed only", est, 2)
	check("source learned", src, "learned")
end

-- ---------------------------------------------------------------- prices

local function price(id)
	FKV.ClearPriceCache()
	return FKV.Price(id)
end

do
	fresh()
	ItemCache[1] = { sell = 100, quality = 1 }
	local p, s = price(1)
	check("vendor price from client info", p, 100)
	check("vendor source", s, "vendor")

	Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(caller, id)
		return id == 1 and 1000 or nil
	end } } }
	p, s = price(1)
	near("AH price minus the 5% cut", p, 950)
	check("AH source", s, "ah")

	local seenCaller
	Auctionator.API.v1.GetAuctionPriceByItemID = function(caller)
		seenCaller = caller
		return 1000
	end
	price(1)
	check("Auctionator called with the addon name", seenCaller, "KroolWorldForever")

	Auctionator.API.v1.GetAuctionPriceByItemID = function()
		return 90
	end
	p, s = price(1)
	check("AH below vendor: vendor wins", p, 100)
	check("vendor source when it wins", s, "vendor")

	Auctionator.API.v1.GetAuctionPriceByItemID = function()
		error("boom")
	end
	p, s = price(1)
	check("erroring Auctionator falls back to vendor", p, 100)

	Auctionator = { API = {} }
	p = price(1)
	check("Auctionator without v1 falls back", p, 100)
	Auctionator = nil

	-- guards
	Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function()
		return 100000
	end } } }
	ItemCache[2] = { sell = 50, quality = 3, bind = 1 }
	p, s = price(2)
	check("bind-on-pickup never uses the AH", p, 50)
	check("bind-on-pickup source vendor", s, "vendor")
	ItemCache[3] = { sell = 7, quality = 0 }
	p, s = price(3)
	check("grey item never uses the AH", p, 7)
	ItemCache[4] = { sell = 900, quality = 1, bind = 4 }
	p, s = price(4)
	check("quest item (bind 4) is worth 0", p, 0)
	check("quest source", s, "quest")
	ItemCache[5] = { sell = 900, quality = 1, class = 12 }
	p, s = price(5)
	check("quest-class item is worth 0", p, 0)
	ItemCache[6] = { sell = 50, quality = 1 }
	p = price(6)
	near("normal item takes the AH price", p, 95000)

	FKV.cfg.ah = false
	p = price(6)
	check("AH switched off: vendor only", p, 50)
	FKV.cfg.ah = true
	FKV.cfg.vendor = false
	ItemCache[7] = { sell = 50, quality = 1 }
	Auctionator = nil
	p = price(7)
	check("no vendor, no AH: unknown", p, nil)
	FKV.cfg.vendor = true
	FKV.cfg.cut = 10
	Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function()
		return 1000
	end } } }
	p = price(6)
	near("cut setting is honoured", p, 900)
	FKV.cfg.cut = 5
end

-- uncached items: request the load once, fall back to the baseline tables
do
	fresh()
	ns.Data.sell[9100010] = 321
	ns.Data.meta[9100010] = 1 * 16 + 0
	ns.Data.meta[9100011] = 0 * 16 + 0 -- grey, unbound
	ns.Data.sell[9100011] = 4
	ns.Data.meta[9100012] = 3 * 16 + 1 -- blue, bind on pickup
	ns.Data.sell[9100012] = 80
	ns.Data.meta[9100013] = 1 * 16 + 4 -- quest
	ns.Data.sell[9100013] = 80
	Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function()
		return 100000
	end } } }
	local p = FKV.Price(9100010)
	near("uncached white item: AH price minus cut", p, 95000)
	check("uncached item triggers one load request", #LoadRequests, 1)
	FKV.ClearPriceCache()
	FKV.Price(9100010)
	check("no second load request", #LoadRequests, 1)
	FKV.ClearPriceCache()
	check("uncached baseline grey: vendor only", (FKV.Price(9100011)), 4)
	FKV.ClearPriceCache()
	check("uncached baseline BoP: vendor only", (FKV.Price(9100012)), 80)
	FKV.ClearPriceCache()
	check("uncached baseline quest item: 0", (FKV.Price(9100013)), 0)
	Auctionator = nil
	FKV.ClearPriceCache()
	check("uncached item with baseline vendor price", (FKV.Price(9100010)), 321)
	-- client delivers the data: price now follows the client
	ItemCache[9100010] = { sell = 999, quality = 1 }
	FKV.ItemLoaded(9100010)
	check("price follows the client once item data arrives", (FKV.Price(9100010)), 999)
	check("unknown everywhere: no price", (FKV.Price(9199999)), nil)
end

-- ---------------------------------------------------------------- compute: baseline

local function setItems()
	ItemCache[9100001] = { sell = 50, quality = 1 }
	ItemCache[9100002] = { sell = 1000, quality = 2 }
	ItemCache[9100003] = { sell = 200, quality = 2 }
	ItemCache[9100004] = { sell = 1000000, quality = 4 }
end

do
	fresh()
	setItems()
	-- coin 100..200 (avg 150), 1.0 x item1 @50, 0.5 x item2 @1000, a ref pool: 2 x item3 per kill
	ns.Data.mob[9000001] = "100:200|9100001:1,9100002:0.5|8000001:1||12:1:900"
	ns.Data.ref[8000001] = "9100003:0.25"
	local acc = FKV.Compute(9000001)
	check("baseline-only source", acc.source, "baseline")
	near("coin average of min/max", acc.gold, 150)
	near("total = coin + 50 + 500 + 50", acc.total, 150 + 50 + 500 + 50)
	check("top sorted by value", acc.top[1].id, 9100002)
	check("tag text", FKV.SourceTag(acc), "baseline")
	check("level/rank/health parsed", acc.lvl .. ":" .. acc.rank .. ":" .. acc.hp, "12:1:900")
	check("GetKillValue public API", FKV.GetKillValue(9000001), acc.total)
	check("unknown creature", FKV.Compute(9999999), nil)

	-- rare split: 0.0005 x 1,000,000 = 500 copper outside the total
	ns.Data.mob[9000002] = "10:10|9100001:1,9100004:0.0005|||5:0:100"
	local a2 = FKV.Compute(9000002)
	near("rare drop excluded from total", a2.total, 10 + 50)
	near("rare drop reported separately", a2.rare, 500)
	check("rare drop in raretop", a2.raretop[1].id, 9100004)
	FKV.cfg.rare = 0.0001
	local a3 = FKV.Compute(9000002)
	near("lower threshold moves it into the total", a3.total, 10 + 50 + 500)
	check("settings change refreshes the cached breakdown", a3 ~= a2, true)
	FKV.cfg.rare = 0.001

	-- skinning
	ns.Data.mob[9000003] = "0:0|9100001:1||H:9100002:0.5|1:0:10"
	local a4 = FKV.Compute(9000003)
	check("gather type parsed", a4.gather, "H")
	near("skinning value kept out of the total", a4.skin, 500)
	near("total ignores skinning", a4.total, 50)

	-- unpriced drops
	ns.Data.mob[9000004] = "0:0|9100001:1,9188888:1|||1:0:10"
	local a5 = FKV.Compute(9000004)
	check("unpriced drop counted as unknown", a5.unknown, 1)
	near("unpriced drop adds nothing", a5.total, 50)
end

-- ---------------------------------------------------------------- compute: learned + blended

do
	fresh()
	setItems()
	ns.Data.mob[9000010] = "100:200|9100001:1,9100002:0.5|||5:0:100"
	-- 10 corpses: 300 coin each, item1 x1 each, new item3 on 5 of them
	for i = 1, 10 do
		local items = { [9100001] = 1 }
		if i <= 5 then
			items[9100003] = 1
		end
		check("corpse " .. i .. " recorded", FKV.RecordCorpse(9000010, G(9000010, "S" .. i), 300, items), true)
	end
	local acc = FKV.Compute(9000010)
	check("blended source", acc.source, "blended")
	check("blended tag", FKV.SourceTag(acc), "blended")
	check("kills carried", acc.kills, 10)
	near("coin blend (3000 + 10*150) / 20", acc.gold, 225)
	local by = {}
	for _, c in ipairs(acc.top) do
		by[c.id] = c
	end
	near("item1 blend (10 + 10*1) / 20", by[9100001].qty, 1.0)
	near("item2 never dropped: (0 + 10*0.5) / 20", by[9100002].qty, 0.25)
	near("new item3: (5 + 0) / 20", by[9100003].qty, 0.25)
	near("total", acc.total, 225 + 1.0 * 50 + 0.25 * 1000 + 0.25 * 200)

	-- creature without any baseline
	check("unseen creature", FKV.Compute(9000020), nil)
	for i = 1, 2 do
		FKV.RecordCorpse(9000020, G(9000020, "L" .. i), 40, { [9100001] = 2 })
	end
	local l2 = FKV.Compute(9000020)
	check("2 kills, no baseline: learning", l2.learning, true)
	check("learning has no total", l2.total, nil)
	check("learning tag", FKV.SourceTag(l2), "learning (2 kills)")
	FKV.RecordCorpse(9000020, G(9000020, "L3"), 40, { [9100001] = 2 })
	local l3 = FKV.Compute(9000020)
	check("3 kills: learned source", l3.source, "learned")
	check("learned tag", FKV.SourceTag(l3), "learned, 3 kills")
	near("observed-only coin", l3.gold, 40)
	near("observed-only total: 40 + 2 x 50", l3.total, 140)
	check("learned creature GetKillValue", FKV.GetKillValue(9000020), l3.total)
end

-- ---------------------------------------------------------------- corpse dedupe and caps

do
	fresh()
	local g = G(9000030, "DEDUP")
	check("first loot of a corpse counts", FKV.RecordCorpse(9000030, g, 10, { [1] = 1 }), true)
	check("same guid again does not", FKV.RecordCorpse(9000030, g, 10, { [1] = 1 }), false)
	local rec = FKV.GetLearned(9000030)
	check("corpse counted once", rec.n, 1)
	check("coin counted once", rec.coin, 10)
	check("items counted once", rec.items[1], 1)
	check("non-string guid rejected", FKV.RecordCorpse(9000030, 42, 1, {}), false)

	for i = 1, 300 do
		FKV.RecordCorpse(9000031, G(9000031, "R" .. i), 1, {})
	end
	check("recent guid list is bounded", #ns.db.recent <= 200, true)
	check("recent guids persisted", ns.db.recent[#ns.db.recent], G(9000031, "R300"))
	check("a very recent guid is still deduped", FKV.RecordCorpse(9000031, G(9000031, "R300"), 1, {}), false)

	-- item cap per creature
	local many = {}
	for i = 1, 130 do
		many[i] = i
	end
	many[1] = 50 -- the heavy item must survive trimming
	FKV.RecordCorpse(9000032, G(9000032, "M1"), 0, many)
	local n = 0
	for _ in pairs(FKV.GetLearned(9000032).items) do
		n = n + 1
	end
	check("learned items per creature capped", n <= 100, true)
	check("heaviest item survives the cap", FKV.GetLearned(9000032).items[1], 50)

	-- creature cap: keep the best-known one
	fresh()
	for i = 1, 3 do
		FKV.RecordCorpse(5000000, G(5000000, "K" .. i), 0, {})
	end
	for i = 1, 2600 do
		FKV.RecordCorpse(6000000 + i, G(6000000 + i, "X"), 0, {})
	end
	local npcs = 0
	for _ in pairs(ns.db.learned) do
		npcs = npcs + 1
	end
	check("learned creatures capped", npcs <= 2500, true)
	check("most-observed creature survives the cap", FKV.GetLearned(5000000) ~= nil, true)
end

-- ---------------------------------------------------------------- compute cache

do
	fresh()
	setItems()
	ns.Data.mob[9000040] = "10:10|9100001:1|||1:0:1"
	local a = FKV.Compute(9000040)
	check("breakdown cached", FKV.Compute(9000040), a)
	Clock = Clock + 599
	check("still cached inside ten minutes", FKV.Compute(9000040), a)
	Clock = Clock + 2
	check("expired after ten minutes", FKV.Compute(9000040) ~= a, true)
	local b = FKV.Compute(9000040)
	FKV.RecordCorpse(9000040, G(9000040, "N1"), 20, {})
	local c = FKV.Compute(9000040)
	check("learning a corpse flushes that creature", c ~= b, true)
	check("other creatures keep their cache", (function()
		ns.Data.mob[9000041] = "10:10||||1:0:1"
		local x = FKV.Compute(9000041)
		FKV.RecordCorpse(9000040, G(9000040, "N2"), 20, {})
		return FKV.Compute(9000041) == x
	end)(), true)
	for i = 1, 80 do
		ns.Data.mob[9100000 + i] = "5:5||||1:0:1"
		FKV.Compute(9100000 + i)
	end
	check("cache is bounded", FKV.CacheStats() <= 64, true)
end

-- ---------------------------------------------------------------- loot capture

do
	fresh()
	ItemCache[9100001] = { sell = 50, quality = 1 }
	local function slot(kind, link, ...)
		Loot.slots[#Loot.slots + 1] = { type = kind, link = link, sources = { ... } }
	end
	local I, M, C = Enum.LootSlotType.Item, Enum.LootSlotType.Money, Enum.LootSlotType.Currency
	local link1 = "|cffffffff|Hitem:9100001::::::::80:::::|h[Thing]|h|r"
	local g1 = G(9000050, "A")

	slot(M, nil, g1, 120)
	slot(I, link1, g1, 3)
	slot(I, link1, g1, 2)
	slot(C, nil, g1, 5)
	check("capture records one corpse", FKV.CaptureLoot(), 1)
	local rec = FKV.GetLearned(9000050)
	check("corpse counted", rec.n, 1)
	check("coin read from the money slot", rec.coin, 120)
	check("item quantities summed across slots", rec.items[9100001], 5)
	check("reopening the same corpse is ignored", FKV.CaptureLoot(), 0)
	check("still one corpse", FKV.GetLearned(9000050).n, 1)

	-- LOOT_READY then LOOT_OPENED for a new corpse count it once
	fresh()
	Loot.slots = {}
	local g2 = G(9000051, "B")
	slot(I, link1, g2, 1)
	FireEvent("LOOT_READY")
	FireEvent("LOOT_OPENED")
	check("both loot events -> one count", FKV.GetLearned(9000051).n, 1)

	-- area loot: two corpses, quantities attributed per source
	fresh()
	Loot.slots = {}
	local g3, g4 = G(9000052, "C"), G(9000053, "D")
	slot(M, nil, g3, 10, g4, 30)
	slot(I, link1, g3, 1, g4, 1)
	check("area loot records both corpses", FKV.CaptureLoot(), 2)
	check("coin attributed to its own source", FKV.GetLearned(9000053).coin, 30)
	check("other source coin", FKV.GetLearned(9000052).coin, 10)

	-- pickpocket: loot window on a live target
	fresh()
	Loot.slots = {}
	local g5 = G(9000054, "E")
	slot(M, nil, g5, 5)
	Units.target = { guid = g5, dead = false }
	check("pickpocket (live target) not recorded", FKV.CaptureLoot(), 0)
	check("nothing stored", FKV.GetLearned(9000054), nil)
	Units.target = { guid = g5, dead = true }
	check("dead target is a corpse", FKV.CaptureLoot(), 1)

	-- not a creature corpse
	fresh()
	Loot.slots = {}
	slot(I, link1, "GameObject-0-1-2-3-9000055-4", 1)
	slot(I, link1, "Item-4170-0-0000ABCD", 1)
	slot(M, nil, "Player-4170-0001", 7)
	check("objects, items and players ignored", FKV.CaptureLoot(), 0)

	-- fishing
	fresh()
	Loot.slots = {}
	slot(I, link1, G(9000056, "F"), 1)
	Loot.fishing = true
	check("fishing loot ignored", FKV.CaptureLoot(), 0)
	Loot.fishing = false

	-- secrets abort the whole capture
	fresh()
	Loot.slots = {}
	slot(I, link1, G(9000057, "G"), 1)
	slot(M, nil, Secret(), 10)
	check("a secret source guid aborts the capture", FKV.CaptureLoot(), 0)
	check("nothing stored from an aborted capture", FKV.GetLearned(9000057), nil)
	fresh()
	Loot.slots = {}
	slot(M, nil, G(9000058, "H"), Secret())
	check("a secret quantity aborts the capture", FKV.CaptureLoot(), 0)
	fresh()
	Loot.slots = {}
	slot(I, Secret(), G(9000059, "I"), 1)
	check("a secret item link aborts the capture", FKV.CaptureLoot(), 0)

	-- switch off
	fresh()
	Loot.slots = {}
	slot(I, link1, G(9000060, "J"), 1)
	FKV.cfg.learn = false
	check("learning switched off", FKV.CaptureLoot(), 0)
	FKV.cfg.learn = true

	-- empty window, error inside a loot event
	fresh()
	check("empty loot window", FKV.CaptureLoot(), 0)
	local saved = GetNumLootItems
	GetNumLootItems = function()
		error("api gone")
	end
	local ok = pcall(FireEvent, "LOOT_OPENED")
	GetNumLootItems = saved
	check("loot event swallows errors", ok, true)
end

-- ---------------------------------------------------------------- tooltip

do
	fresh()
	setItems()
	ns.Data.mob[9000070] = "100:200|9100001:1,9100002:0.5|||5:0:100"
	local g = G(9000070, "T")
	Units.mouseover = { guid = g, dead = false, canAttack = true }
	local left, right = Hover(g)
	check("hostile creature gets a kill value line", left[1], "Kill value")
	check("line shows the money", right[1]:find("g|r", 1, true) ~= nil or right[1]:find("c|r", 1, true) ~= nil, true)
	check("line is tagged baseline", right[1]:find("(baseline)", 1, true) ~= nil, true)
	check("coins line", has(left, "coins"), true)
	check("top contributors capped at detail (coins + 3 max)", #left <= 1 + 1 + 3, true)
	check("top contributor named", has(left, "Item9100002"), true)

	left = Hover(g)
	check("fresh tooltip data renders again", left[1], "Kill value")
	GameTooltip:Reset()
	local data = { guid = g }
	TooltipCallbacks[Enum.TooltipDataType.Unit](GameTooltip, data)
	local n = #GameTooltip.left
	TooltipCallbacks[Enum.TooltipDataType.Unit](GameTooltip, data)
	check("same tooltip data does not duplicate lines", #GameTooltip.left, n)

	FKV.cfg.detail = 0
	left = Hover(g)
	check("detail 0: only the total", #left, 1)
	FKV.cfg.detail = 3

	-- rare line
	ns.Data.mob[9000071] = "0:0|9100001:1,9100004:0.0005|||5:0:100"
	left = Hover(G(9000071))
	check("rare drops line present", has(left, "rare drops"), true)

	-- skin line is opt-in
	ns.Data.mob[9000072] = "0:0|9100001:1||9100002:0.5|5:0:100"
	left = Hover(G(9000072))
	check("skinning hidden by default", has(left, "skinning"), false)
	FKV.cfg.skin = true
	left = Hover(G(9000072))
	check("skinning shown when enabled", has(left, "skinning"), true)
	FKV.cfg.skin = false

	-- degrade silently
	left = Hover(G(9999998))
	check("creature with no data: no line", #left, 0)
	left = Hover("Pet-0-1-2-3-9000070-4")
	check("pet: no line", #left, 0)
	left = Hover("Player-1-2")
	check("player: no line", #left, 0)
	left = Hover(Secret())
	check("secret guid: no line", #left, 0)
	GameTooltip:Reset()
	TooltipCallbacks[Enum.TooltipDataType.Unit](GameTooltip, nil)
	check("nil data: no line", #GameTooltip.left, 0)

	InInstance = true
	left = Hover(G(9000070, "U"))
	check("inside an instance: no lookup", #left, 0)
	InInstance = false

	Units.mouseover = { guid = g, dead = false, canAttack = false }
	left = Hover(G(9000070, "V"))
	check("friendly creature: no line", #left, 0)
	FKV.cfg.friendly = true
	left = Hover(G(9000070, "W"))
	check("friendly creature with the setting on", left[1], "Kill value")
	FKV.cfg.friendly = false
	Units.mouseover = { guid = g, dead = true, canAttack = false }
	left = Hover(G(9000070, "X"))
	check("corpse always shows", left[1], "Kill value")
	Units.mouseover = { guid = g, dead = false, canAttack = true }

	ns.enabled = false
	left = Hover(G(9000070, "Y"))
	check("disabled: no line", #left, 0)
	ns.enabled = true

	-- an error anywhere in the lookup must not escape the post-call
	local savedMob = ns.Data.mob
	ns.Data.mob = setmetatable({}, { __index = function()
		error("data exploded")
	end })
	FKV.ClearCaches()
	local ok = pcall(Hover, G(9000070, "Z"))
	check("data error does not escape the tooltip hook", ok, true)
	check("and adds no line", #GameTooltip.left, 0)
	ns.Data.mob = savedMob
	FKV.ClearCaches()

	local savedCompute = FKV.Compute
	FKV.Compute = function()
		error("compute exploded")
	end
	ok = pcall(Hover, G(9000070, "Q"))
	FKV.Compute = savedCompute
	check("compute error does not escape either", ok, true)

	-- a throwing GetUnit / UnitCanAttack degrade gracefully
	local savedGetUnit = GameTooltip.GetUnit
	GameTooltip.GetUnit = function()
		error("secret unit")
	end
	left = Hover(G(9000070, "R"))
	check("GetUnit failure falls back to mouseover", left[1], "Kill value")
	GameTooltip.GetUnit = savedGetUnit

	-- learned tags on the tooltip
	for i = 1, 2 do
		FKV.RecordCorpse(9000073, G(9000073, "L" .. i), 10, { [9100001] = 1 })
	end
	left, right = Hover(G(9000073, "S"))
	check("learning creature shows its kill count", right[1]:find("learning (2 kills)", 1, true) ~= nil, true)
	FKV.RecordCorpse(9000073, G(9000073, "L3"), 10, { [9100001] = 1 })
	left, right = Hover(G(9000073, "S2"))
	check("learned creature tagged", right[1]:find("learned, 3 kills", 1, true) ~= nil, true)
	FKV.RecordCorpse(9000070, G(9000070, "LL"), 100, { [9100001] = 1 })
	left, right = Hover(G(9000070, "S3"))
	check("blended creature tagged", right[1]:find("(blended)", 1, true) ~= nil, true)
end

-- ---------------------------------------------------------------- slash commands

do
	fresh()
	setItems()
	ns.Data.mob[9000080] = "100:200|9100001:1,9100002:0.5|||5:0:100"
	local slash = ns.OnSlash
	local out = capture(function()
		slash("id 9000080")
	end)
	check("/fkv id prints a breakdown", has(out, "per kill"), true)
	check("breakdown names the source", has(out, "baseline"), true)
	check("breakdown lists coins", has(out, "coins"), true)
	out = capture(function()
		slash("id 9999997")
	end)
	check("/fkv id on unknown creature says so", has(out, "no loot data"), true)
	out = capture(function()
		slash("id abc")
	end)
	check("/fkv id needs a number", has(out, "usage"), true)

	Units.target = { guid = G(9000080, "TT"), name = "Test Mob" }
	out = capture(function()
		slash("")
	end)
	check("/fkv uses the target", has(out, "Test Mob"), true)
	Units.target = nil
	out = capture(function()
		slash("")
	end)
	check("/fkv without a target explains", has(out, "no creature targeted"), true)

	out = capture(function()
		slash("status")
	end)
	check("/fkv status shows the baseline", has(out, "Era baseline"), true)
	check("/fkv status shows learned counts", has(out, "learned:"), true)
	out = capture(function()
		slash("config")
	end)
	check("/fkv config lists settings", has(out, "detail"), true)
	out = capture(function()
		slash("help")
	end)
	check("/fkv help lists commands", has(out, "/fkv id"), true)
	out = capture(function()
		slash("bogus")
	end)
	check("unknown command is reported", has(out, "unknown command"), true)

	capture(function()
		slash("detail 5")
	end)
	check("/fkv detail", FKV.cfg.detail, 5)
	capture(function()
		slash("detail 99")
	end)
	check("/fkv detail is clamped", FKV.cfg.detail, 20)
	capture(function()
		slash("cut 12.5")
	end)
	check("/fkv cut", FKV.cfg.cut, 12.5)
	capture(function()
		slash("cut 500")
	end)
	check("/fkv cut is clamped", FKV.cfg.cut, 100)
	capture(function()
		slash("rare 1")
	end)
	near("/fkv rare takes a percent", FKV.cfg.rare, 0.01)
	capture(function()
		slash("learn")
	end)
	check("/fkv learn", FKV.cfg.learn, false)
	capture(function()
		slash("reset")
	end)
	check("/fkv reset restores defaults", FKV.cfg.detail, 3)
	check("/fkv reset leaves the feature switch alone", ns.enabled, true)

	FKV.RecordCorpse(9000081, G(9000081, "Z"), 1, {})
	capture(function()
		slash("reset")
	end)
	check("/fkv reset keeps learned data", FKV.GetLearned(9000081) ~= nil, true)
	capture(function()
		slash("reset learned")
	end)
	check("/fkv reset learned wipes it", FKV.GetLearned(9000081), nil)
	check("and the corpse memory", #ns.db.recent, 0)
	capture(function()
		slash("options")
	end)
	check("/fkv options opens the feature panel", OpenedCategory, "Kill Value")
	check("/killvalue alias registered", SLASH_KROOLWORLDFOREVER_KILLVALUE2, "/killvalue")

	-- an error inside a command is contained
	local savedCompute = FKV.Compute
	FKV.Compute = function()
		error("kaput")
	end
	local ok = pcall(slash, "id 9000080")
	FKV.Compute = savedCompute
	check("a failing report does not raise", ok, true)
end

-- ---------------------------------------------------------------- bundle switch and settings

do
	-- real saved slice again (earlier sections swapped ns.db for scratch tables)
	local slice = KroolWorldForeverDB.features.killvalue
	FKV.AttachDB(slice)
	FKV.ClearCaches()
	Clock, InInstance, Auctionator = 1000, false, nil
	ItemCache, Units, TooltipUnitToken = {}, {}, "mouseover"
	Loot = { slots = {}, fishing = false }
	setItems()
	ns.Data.mob[9000090] = "100:200|9100001:1,9100002:0.5|||5:0:100"
	local g = G(9000090, "SW")
	Units.mouseover = { guid = g, dead = false, canAttack = true }
	check("on: tooltip line", Hover(g)[1], "Kill value")

	local out = capture(function()
		SlashCmdList.KROOLWORLDFOREVER("killvalue off")
	end)
	check("/kwf killvalue off disables the feature", ns.enabled, false)
	check("and saves it", slice.enabled, false)
	check("off: no tooltip lines", #Hover(G(9000090, "SW2")), 0)
	local link = "|cffffffff|Hitem:9100001::::::::80:::::|h[Thing]|h|r"
	Loot.slots = { { type = Enum.LootSlotType.Item, link = link, sources = { G(9000091, "SWL"), 1 } } }
	FireEvent("LOOT_OPENED")
	check("off: no loot recorded", FKV.GetLearned(9000091), nil)
	out = capture(function()
		SlashCmdList.KROOLWORLDFOREVER_KILLVALUE("id 9000090")
	end)
	check("off: /fkv explains it is off", has(out, "is off"), true)

	SettingsSet("KroolWorldForever_killvalue_enabled", true)
	check("settings checkbox re-enables", ns.enabled, true)
	check("on again: tooltip line", Hover(G(9000090, "SW3"))[1], "Kill value")
	FireEvent("LOOT_OPENED")
	check("on again: loot recorded", FKV.GetLearned(9000091) ~= nil, true)
	local hooks = 0
	for _ in pairs(TooltipCallbacks) do
		hooks = hooks + 1
	end
	SettingsSet("KroolWorldForever_killvalue_enabled", false)
	SettingsSet("KroolWorldForever_killvalue_enabled", true)
	local hooks2 = 0
	for _ in pairs(TooltipCallbacks) do
		hooks2 = hooks2 + 1
	end
	check("tooltip hook registered once", hooks2, hooks)

	-- a range option change flushes the value cache
	local before = FKV.Compute(9000090)
	check("breakdown cached", FKV.Compute(9000090), before)
	SettingsSet("KroolWorldForever_killvalue_cut", 20)
	check("slider writes the saved slice", slice.cut, 20)
	check("slider change recomputes", FKV.Compute(9000090) ~= before, true)
	SettingsSet("KroolWorldForever_killvalue_cut", 5)
	local cached = FKV.Compute(9000090)
	check("cache cleared on option change", FKV.CacheStats(), 1)
	SettingsSet("KroolWorldForever_killvalue_detail", 0)
	check("detail slider change clears the cache", FKV.CacheStats(), 0)
	check("detail 0 shows only the total", #Hover(G(9000090, "SW4")), 1)
	SettingsSet("KroolWorldForever_killvalue_detail", 3)
	check("toggle option live in the slice", (function()
		SettingsSet("KroolWorldForever_killvalue_friendly", true)
		return FKV.cfg.friendly
	end)(), true)
	SettingsSet("KroolWorldForever_killvalue_friendly", false)
end

-- ---------------------------------------------------------------- real baseline sanity

do
	fresh()
	-- real Forest Spider data, items uncached so prices come from Data.lua
	local acc = FKV.Compute(30)
	check("real creature computes", acc ~= nil and acc.total ~= nil, true)
	check("real creature is baseline", acc.source, "baseline")
	check("real creature has a positive value", acc.total > 0, true)
	local ok = true
	for _, id in ipairs({ 1, 2, 3, 6, 30, 38, 46 }) do
		ok = ok and pcall(FKV.Compute, id)
	end
	check("real creatures compute without error", ok, true)
end

realPrint(("\n%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
