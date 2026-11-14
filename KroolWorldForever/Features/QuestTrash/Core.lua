-- Quest Trash: tells you when a quest item can be safely deleted.
-- Built for WoW Forever (Mainline client, Interface 16001).
--
-- Data: QuestieDB (LibQuestieDB / QuestDB / ItemDB globals) for item-to-quest links and quest
-- facts; the client itself (C_QuestLog.IsQuestFlaggedCompleted) for completion. The native
-- completion flag is authoritative, so there is no history to backfill or repair.
--
-- Item links (role):
--   ItemDB.startQuest            "start"  item begins the quest
--   ItemDB.relatedQuests         "related" any quest QuestieDB ties to the item
--   QuestDB.objectives[3]        "obj"    collect objective
--   QuestDB.objectives[6][3]     "use"    item used for a spell objective
--   QuestDB.requiredSourceItems  "req"    carried, not an objective
--   QuestDB.sourceItemId         "prov"   handed out when the quest is accepted
--   C_Container.GetContainerItemQuestInfo "start" the quest a bag item starts, as the client
--                                reports it (the "!" on its slot); learned from the bags
-- The quest-side links need a full quest scan, which runs in slices after login. Until it
-- finishes, a verdict that would allow deletion is reported as "pending" instead.
--
-- Quest state, first match wins: active > repeat > event > done > never > closed > nodata > open.
-- "closed" means out of reach for good, for a reason the player's own progress proves: an
-- exclusive variant done, a breadcrumb's target taken, its window ended (availableUntilCompleted
-- done), over its level cap (requiredMaxLevel), or a prerequisite closed for one of those reasons.
-- A prerequisite that is only race/class-locked ("never") does not close the quest after it: that
-- would rest on the race masks alone.
-- Item verdict, most protective wins: active > farm > maybe > unknown > safe > notyours.
-- Everything unknown fails toward keep.

local _, root = ...
local ns = root.Feature("questtrash")

local FQT = {}
root.public.QuestTrash = FQT -- for bag addons: KroolWorldForever.QuestTrash.GetVerdict(itemID)
ns.FQT = FQT

local QUESTIEDB_CONTRACT = 4 -- Enum.raceMaskById (3) and Enum.classKeys (4)
local SCAN_SLICE = 250 -- quests indexed per frame during the background scan

-- Items never to advise deleting even if the data links them to completed quests:
-- keys, attunements, portal items, quintessences.
local NEVER_DELETE = {
	[17333] = true, -- Aqual Quintessence
	[22754] = true, -- Eternal Quintessence
	[17191] = true, -- Scepter of Celebras
	[12344] = true, -- Seal of Ascension
	[16309] = true, -- Drakefire Amulet
	[9240] = true, -- Mallet of Zul'Farrak
	[13704] = true, -- Skeleton Key (Scholomance)
	[11000] = true, -- Shadowforge Key
	[6893] = true, -- Workshop Key
	[5396] = true, -- Key to Searing Gorge
	[18249] = true, -- Crescent Key
	[12846] = true, -- Argent Dawn Commission
	[11511] = true, -- Cenarion Beacon
}

-- QuestSort ids (negative zoneOrSort) of holidays and recurring events. Their quests come
-- back every year (and Darkmoon turn-ins every month), so their items are never "done".
local EVENT_SORTS = {
	[-404] = true, -- Winter Veil
	[-402] = true, -- Harvest Festival
	[-378] = true, -- Children's Week
	[-376] = true, -- Love is in the Air
	[-375] = true, -- Pilgrim's Bounty
	[-374] = true, -- Noblegarden
	[-370] = true, -- Brewfest
	[-369] = true, -- Midsummer
	[-366] = true, -- Lunar Festival
	[-364] = true, -- Darkmoon Faire
	[-41] = true, -- Day of the Dead
	[-22] = true, -- Seasonal
	[-21] = true, -- Hallow's End
}

local SPECIAL_REPEATABLE = 1 -- QuestieDB specialFlags
local QUEST_FLAG_DAILY, QUEST_FLAG_WEEKLY, QUEST_FLAG_MONTHLY = 4096, 32768, 65536

-- Skyborne (95/96) quest masks are not live-validated in QuestieDB yet; a wrong mask would
-- read "not for your race" and advise deletion. Skip the race test for them until it is.
local UNVERIFIED_RACE_IDS = { [95] = true, [96] = true }

local CLASS_KEY = { DEATHKNIGHT = "DEATH_KNIGHT", DEMONHUNTER = "DEMON_HUNTER" }

-- -------------------------------------------------------------------- helpers

-- Masks can exceed 32 bits (Skyborne uses bits 32/33), so no bit library: plain arithmetic
-- is exact up to 2^53. bitValue must be a power of two.
local function HasBit(mask, bitValue)
	return mask ~= 0 and math.floor(mask / bitValue) % 2 == 1
end
FQT._HasBit = HasBit

local function Provider()
	return LibQuestieDB
end

function FQT.ProviderStatus()
	local lib = Provider()
	if not lib then
		return false, "QuestieDB is not loaded."
	end
	local ok, message = lib.RequireContract(QUESTIEDB_CONTRACT)
	if not ok then
		return false, message or "QuestieDB is too old."
	end
	return true, lib.readMode
end

-- -------------------------------------------------------------------- index

local reverseIndex = {} -- [itemID] = { {qid, role}, ... } from the quest scan
local scan = { done = false, position = 0, total = 0 }
ns.scan = scan

local function AddLink(list, qid, role)
	if not qid or qid == 0 then
		return
	end
	for _, link in ipairs(list) do
		if link[1] == qid then
			return -- one link per quest is enough; the first role found wins
		end
	end
	list[#list + 1] = { qid, role }
end

local function AddReverse(itemID, qid, role)
	if not itemID or itemID == 0 then
		return
	end
	local list = reverseIndex[itemID]
	if not list then
		list = {}
		reverseIndex[itemID] = list
	end
	AddLink(list, qid, role)
end

local QUEST_SCAN_FIELDS = { "objectives", "requiredSourceItems", "sourceItemId" }

local function IndexQuest(qid)
	local v = QuestDB.GetAll(qid, QUEST_SCAN_FIELDS)
	if not v then
		return
	end
	local objectives, required, provided = v[1], v[2], v[3]
	if objectives then
		for _, o in ipairs(objectives[3] or {}) do
			AddReverse(o[1], qid, "obj")
		end
		for _, o in ipairs(objectives[6] or {}) do
			AddReverse(o[3], qid, "use")
		end
	end
	for _, itemID in ipairs(required or {}) do
		AddReverse(itemID, qid, "req")
	end
	AddReverse(provided, qid, "prov")
end

-- Runs one slice of the background scan. Returns true when the scan is complete.
function FQT.ScanStep(sliceSize)
	if scan.done then
		return true
	end
	if not scan.ids then
		scan.ids = QuestDB.GetAllIds() -- shared, read-only list
		scan.total = #scan.ids
	end
	local last = math.min(scan.position + (sliceSize or SCAN_SLICE), scan.total)
	for i = scan.position + 1, last do
		IndexQuest(scan.ids[i])
	end
	scan.position = last
	if last >= scan.total then
		scan.done = true
		scan.ids = nil
		FQT.ClearCache()
	end
	return scan.done
end

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- The quest each bag item starts, as the client reports it: [itemID] = questID. It fills in for
-- items QuestieDB has no starter link for (new Forever items). Learned per session from the bags.
local clientStarts = {}
local cache = {} -- verdicts, [itemID] = { verdict, links }

function FQT.LearnSlot(bag, slot, itemID)
	if not (C_Container and C_Container.GetContainerItemQuestInfo) or type(itemID) ~= "number" then
		return
	end
	local ok, info = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
	if not ok or type(info) ~= "table" then
		return
	end
	local qid = info.questID
	if Secret(qid) or type(qid) ~= "number" or qid <= 0 then
		return
	end
	if clientStarts[itemID] ~= qid then
		clientStarts[itemID] = qid
		cache[itemID] = nil
	end
end

local function LinksFor(itemID)
	local links = {}
	AddLink(links, ItemDB.startQuest(itemID), "start")
	AddLink(links, clientStarts[itemID], "start")
	for _, l in ipairs(reverseIndex[itemID] or {}) do
		AddLink(links, l[1], l[2])
	end
	for _, qid in ipairs(ItemDB.relatedQuests(itemID) or {}) do
		AddLink(links, qid, "related")
	end
	return links
end

-- -------------------------------------------------------------------- state

local player = {}

function FQT.InitPlayer()
	local enum = LibQuestieDB.Enum
	local _, _, raceID = UnitRace("player")
	local _, classFile = UnitClass("player")
	player.raceMask = (raceID and not UNVERIFIED_RACE_IDS[raceID]) and enum.raceMaskById[raceID] or nil
	player.classMask = classFile and enum.classKeys[CLASS_KEY[classFile] or classFile] or nil
end

local function IsCompleted(qid)
	return C_QuestLog.IsQuestFlaggedCompleted(qid) == true
end

local function IsActive(qid)
	return C_QuestLog.GetLogIndexForQuestID(qid) ~= nil
end

local function PlayerLevel()
	local level = UnitLevel("player")
	if Secret(level) or type(level) ~= "number" then
		return nil
	end
	return level
end

local QUEST_STATE_FIELDS = {
	"specialFlags",
	"questFlags",
	"zoneOrSort",
	"requiredRaces",
	"requiredClasses",
	"exclusiveTo",
	"breadcrumbForQuestId",
	"requiredMaxLevel",
	"availableUntilCompleted",
	"preQuestGroup",
	"preQuestSingle",
}

local PREREQ_DEPTH = 6 -- how far back a chain is followed to find a closed prerequisite

-- state, why. why says what closed it: exclusive | breadcrumb | expired | maxlevel | prereq.
local function StateOf(qid, depth, seen)
	if IsActive(qid) then
		return "active"
	end
	local v = QuestDB.GetAll(qid, QUEST_STATE_FIELDS)
	if not v then
		return "nodata" -- not in the database: assume it still matters
	end
	local special, flags, sort, races, classes, exclusive, breadcrumbFor = v[1], v[2], v[3], v[4], v[5], v[6], v[7]
	local maxLevel, untilDone, group, single = v[8], v[9], v[10], v[11]
	if
		ns.EXTRA_REPEATABLE[qid]
		or HasBit(special, SPECIAL_REPEATABLE)
		or HasBit(flags, QUEST_FLAG_DAILY)
		or HasBit(flags, QUEST_FLAG_WEEKLY)
		or HasBit(flags, QUEST_FLAG_MONTHLY)
	then
		return "repeat"
	end
	if EVENT_SORTS[sort] then
		return "event"
	end
	if IsCompleted(qid) then
		return "done"
	end
	if races ~= 0 and player.raceMask and not HasBit(races, player.raceMask) then
		return "never"
	end
	if classes ~= 0 and player.classMask and not HasBit(classes, player.classMask) then
		return "never"
	end
	-- Mutually exclusive variants: completing one closes the rest for good.
	for _, other in ipairs(exclusive or {}) do
		if other ~= qid and IsCompleted(other) then
			return "closed", "exclusive"
		end
	end
	-- A breadcrumb is dead once the quest it leads to is taken or done.
	if breadcrumbFor and breadcrumbFor ~= 0 and (IsCompleted(breadcrumbFor) or IsActive(breadcrumbFor)) then
		return "closed", "breadcrumb"
	end
	-- Offered only until another quest is done, and that one is.
	if untilDone and untilDone ~= 0 and IsCompleted(untilDone) then
		return "closed", "expired"
	end
	-- A level cap: levels only go up.
	local level = PlayerLevel()
	if maxLevel and maxLevel ~= 0 and level and level > maxLevel then
		return "closed", "maxlevel"
	end
	-- Prerequisites: closed when one the quest needs (group) or every one it could use (single)
	-- is closed. Unknown, open, race/class-locked and repeat prerequisites leave it open.
	if depth < PREREQ_DEPTH then
		seen[qid] = true
		for _, p in ipairs(group or {}) do
			if not seen[p] and StateOf(p, depth + 1, seen) == "closed" then
				seen[qid] = nil
				return "closed", "prereq"
			end
		end
		if type(single) == "table" and #single > 0 then
			local allClosed = true
			for _, p in ipairs(single) do
				if seen[p] or StateOf(p, depth + 1, seen) ~= "closed" then
					allClosed = false
					break
				end
			end
			if allClosed then
				seen[qid] = nil
				return "closed", "prereq"
			end
		end
		seen[qid] = nil
	end
	return "open"
end

-- "active" | "repeat" | "event" | "done" | "never" | "closed" | "nodata" | "open", and for
-- "closed" why (exclusive | breadcrumb | expired | maxlevel | prereq).
function FQT.QuestState(qid)
	return StateOf(qid, 0, {})
end

-- -------------------------------------------------------------------- verdict

function FQT.ClearCache()
	wipe(cache)
end

local function ItemClassOf(itemID)
	return select(6, C_Item.GetItemInfoInstant(itemID))
end

-- true / false / nil (nil = the client does not know the item yet)
function FQT.IsQuestItem(itemID)
	local classID = ItemClassOf(itemID)
	if classID == nil then
		return nil
	end
	return classID == Enum.ItemClass.Questitem
end

-- Returns verdict, links ({ {qid, role, state, why}, ... }); nil for items no quest uses that
-- are not quest items. Verdicts: keep, active, farm, maybe, pending, safe, notyours, unknown.
function FQT.GetVerdict(itemID)
	local hit = cache[itemID]
	if hit then
		return hit[1], hit[2]
	end
	local verdict, out
	if NEVER_DELETE[itemID] then
		verdict, out = "keep", {}
	else
		local links = LinksFor(itemID)
		if #links == 0 then
			if FQT.IsQuestItem(itemID) then
				verdict, out = scan.done and "unknown" or "pending", {}
			end
		else
			local has = {}
			out = {}
			for _, link in ipairs(links) do
				local state, why = FQT.QuestState(link[1])
				out[#out + 1] = { link[1], link[2], state, why }
				has[state] = true
			end
			if has.active then
				verdict = "active"
			elseif has["repeat"] or has.event then
				verdict = "farm"
			elseif has.open then
				verdict = "maybe"
			elseif has.nodata then
				verdict = "unknown" -- a quest QuestieDB does not have: keep
			elseif not scan.done then
				verdict = "pending" -- a quest-side link may still turn up
			elseif has.done or has.closed then
				verdict = "safe"
			else
				verdict = "notyours"
			end
		end
	end
	if verdict then
		cache[itemID] = { verdict, out }
	end
	return verdict, out
end

function FQT.QuestName(qid)
	local name = QuestDB.name(qid)
	if not name or name == "" then
		name = C_QuestLog.GetTitleForQuestID(qid)
	end
	return name or ("quest #" .. qid)
end
