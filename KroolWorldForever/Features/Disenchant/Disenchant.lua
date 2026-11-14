-- Disenchant Value: on weapon and armor tooltips, what the item disenchants into, what that is
-- worth at Auctionator's prices, and whether disenchanting it (yourself or through a
-- disenchanter) pays more than auctioning or vendoring it.
--
-- The tables are the 1.12 ones from the classic database (Data.lua): every classic item is
-- listed with its own table, and anything the 1.12 data does not know (Forever's new items) goes
-- by quality, weapon or armor and item level. A classic item Forever changed (another quality in
-- the client, or another quality or item level in Forever's ItemSparse when Data.lua was built)
-- goes by its Forever values the same way. Each disenchant you do is recorded, to check all this.
-- Without Auctionator the tooltip still names the materials. Auctionator has a disenchant line
-- of its own, but on Forever it loads its retail tables (Warlords of Draenor onward), so items
-- of classic levels get none.

local _, root = ...
local ns = root.Feature("disenchant")

local WEAPON, ARMOR = 2, 4
local CUT = 0.05 -- auction house cut, counted when comparing with the vendor
local MAIN_SHARE = 0.1 -- a material at least this likely with no price leaves the value unknown
local LOW_BLUE = 20 -- blue items up to this item level use Forever's new, unmeasured brackets

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

local function MatName(id)
	if C_Item and C_Item.GetItemNameByID then
		local ok, name = pcall(C_Item.GetItemNameByID, id)
		if ok and type(name) == "string" and name ~= "" then
			return name
		end
	end
	return ns.Data.mats[id] or ("item " .. id)
end

-- -------------------------------------------------------------------- tables

-- The quality a table is for: 1-31 green, 41-50 blue, 61-65 epic. Every 1.12 item uses a table
-- of its own quality (all 6648 with a DisenchantID, checked 2026-11-10).
local function TableQuality(entry)
	return entry <= 31 and 2 or entry <= 50 and 3 or 4
end

-- The disenchant table an item uses, or nil when it cannot be disenchanted. A classic item keeps
-- its 1.12 table unless Forever gave it another quality (some dungeon greens became blue): then
-- its Forever quality and item level choose, through the bands.
function ns.TableFor(itemId, quality, classID, itemLevel)
	local D = ns.Data
	local known = D.items[itemId]
	if known == 0 then
		return nil
	elseif known and (type(quality) ~= "number" or TableQuality(known) == quality) then
		return known
	end
	if (classID ~= WEAPON and classID ~= ARMOR) or type(quality) ~= "number" or quality < 2 or quality > 4 then
		return nil
	end
	local runs = D.bands[quality * 10 + classID]
	if not runs then
		return nil
	end
	for _, run in ipairs(runs) do
		if (itemLevel or 0) <= run[1] then
			return run[2]
		end
	end
	return runs[#runs][2]
end

-- { entry, rows = { {id, p, min, max, price, age}, ... }, value, missing, hasAH, stale }. value is
-- the expected auction worth of one disenchant in copper; nil without Auctionator or when a main
-- material (missing names it) has no price. Rare materials without a price count as 0. age is the
-- days since Auctionator last saw the material; stale is the oldest age of a main material priced
-- from data over root.STALE_DAYS old.
function ns.Evaluate(itemId, quality, classID, itemLevel)
	local entry = ns.TableFor(itemId, quality, classID, itemLevel)
	if not entry then
		return nil
	end
	local hasAH = root.HasAuctionator()
	local rows, value, missing, stale = {}, 0, nil, nil
	for _, r in ipairs(ns.Data.tables[entry]) do
		local price = hasAH and root.AuctionPrice(r[1]) or nil
		local age = price and root.AuctionAge(r[1]) or nil
		rows[#rows + 1] = { id = r[1], p = r[2], min = r[3], max = r[4], price = price, age = age }
		if price then
			value = value + r[2] * (r[3] + r[4]) / 2 * price
			if r[2] >= MAIN_SHARE and root.AuctionStale(age) then
				stale = math.max(stale or 0, age)
			end
		elseif r[2] >= MAIN_SHARE and not missing then
			missing = MatName(r[1])
		end
	end
	if not hasAH or missing then
		value, stale = nil, nil
	end
	-- Forever added disenchant brackets for blue items of item level 5-20 (ItemDisenchantLoot
	-- 335-338, build 1.60.1.70888; 1.12 has none). What they yield is server-side and unmeasured,
	-- so these show the 1.12 Small Glimmering Shard, marked unconfirmed.
	local unsure = quality == 3 and type(itemLevel) == "number" and itemLevel <= LOW_BLUE or nil
	return { entry = entry, rows = rows, value = value, missing = missing, hasAH = hasAH, stale = stale, unsure = unsure }
end

-- What pays most: "vendor", "auction" or "disenchant" (ties go to the less work), and what that
-- pays in copper. Auction and disenchant values are auction prices, so the cut comes off them
-- before the vendor compare (and off the amount returned).
function ns.Best(disenchant, auction, vendor)
	local best, bestNet
	local function Try(kind, gross, net)
		if gross and gross > 0 and (not bestNet or net > bestNet) then
			best, bestNet = kind, net
		end
	end
	Try("vendor", vendor, vendor)
	Try("auction", auction, auction and auction * (1 - CUT))
	Try("disenchant", disenchant, disenchant and disenchant * (1 - CUT))
	return best, bestNet
end

-- -------------------------------------------------------------------- tooltip

local BEST_TEXT = {
	disenchant = "|cff33ff99Best: disenchant it|r",
	auction = "|cffffcc00Best: sell it at auction|r",
	vendor = "|cffaaaaaaBest: sell it to a vendor|r",
}

local OLD = "|cffff9955"

-- auctionAge: days since Auctionator last saw the item itself. An old price still competes; the
-- line says how old it is.
local function BestLine(best, disenchant, auction, vendor, bound, auctionAge)
	local old = auction and root.AuctionStale(auctionAge) and root.SeenText(auctionAge) or nil
	local others = {}
	if best ~= "disenchant" then
		others[#others + 1] = "disenchant " .. root.Money(disenchant)
	end
	if best ~= "auction" then
		if auction then
			others[#others + 1] = "auction " .. root.Money(auction) .. (old and (" " .. OLD .. old .. "|cffaaaaaa") or "")
		elseif not bound then
			others[#others + 1] = "no auction price"
		end
	end
	if best ~= "vendor" and vendor then
		others[#others + 1] = "vendor " .. root.Money(vendor)
	end
	local head = BEST_TEXT[best]
	if best == "auction" and old then
		head = head .. " " .. OLD .. "(price " .. old .. ")|r"
	end
	local tail = #others > 0 and (" |cffaaaaaa(" .. table.concat(others, ", ") .. ")|r") or ""
	return head .. tail
end

local function CountText(r)
	if r.min == r.max then
		return r.min > 1 and ("x" .. r.min) or ""
	end
	return r.min .. "-" .. r.max
end

local function PctText(p)
	if p >= 0.01 then
		return ("%d%%"):format(math.floor(p * 100 + 0.5))
	end
	return ("%.1f%%"):format(p * 100)
end

local function CanDisenchant()
	local fn = C_SpellBook and C_SpellBook.ContainsAnyDisenchantSpell
	if not fn then
		return false
	end
	local ok, yes = pcall(fn)
	return ok and yes == true
end
ns.CanDisenchant = CanDisenchant -- Least Valuable counts a bound item's disenchant only for you

-- A bag item that was equipped (or is account bound) says so on its tooltip; the item info only
-- knows the bind type.
local function SaysBound(data)
	local lines = type(data) == "table" and data.lines
	if type(lines) ~= "table" then
		return false
	end
	local marks = { ITEM_SOULBOUND, ITEM_ACCOUNTBOUND, ITEM_BNETACCOUNTBOUND }
	for _, line in ipairs(lines) do
		local text = type(line) == "table" and line.leftText or nil
		if not Secret(text) and type(text) == "string" then
			for _, mark in pairs(marks) do
				if text == mark then
					return true
				end
			end
		end
	end
	return false
end

-- A classic item the client shows with another quality than its 1.12 table's (ns.db.changed,
-- up to CHANGED_MAX): evidence of what Forever changed, for the generator and the docs.
local CHANGED_MAX = 500
local function NoteChanged(itemId, quality, itemLevel, pin)
	local changed = ns.db.changed
	if changed[itemId] or (ns.changedCount or 0) >= CHANGED_MAX then
		return
	end
	changed[itemId] = { q = quality, il = itemLevel, was = pin }
	ns.changedCount = (ns.changedCount or 0) + 1
end

local function Annotate(tooltip, data)
	local itemId = data.id
	local link
	if tooltip.GetItem then
		local ok, _, l = pcall(tooltip.GetItem, tooltip)
		if ok and type(l) == "string" and not Secret(l) then
			link = l
		end
	end
	local ok, name, _, quality, itemLevel, _, _, _, _, _, _, sellPrice, classID, _, bindType =
		pcall(C_Item.GetItemInfo, link or itemId)
	if not (ok and name) then
		return
	end
	local pin = ns.Data.items[itemId]
	if pin and pin > 0 and type(quality) == "number" and TableQuality(pin) ~= quality then
		NoteChanged(itemId, quality, itemLevel, pin)
	end
	local e = ns.Evaluate(itemId, quality, classID, itemLevel)
	if not e then
		return
	end

	local label = root.UI.InlineIcon(ns.icon, 14) .. " |cffb48cffDisenchant|r"
	if e.unsure then
		label = label .. " " .. OLD .. "(unconfirmed on Forever)|r"
	end
	if e.value then
		tooltip:AddDoubleLine(label, root.Money(e.value) .. (e.stale and (" " .. OLD .. "(old prices)|r") or ""))
	elseif not e.hasAH then
		tooltip:AddDoubleLine(label, "|cffaaaaaaneeds Auctionator prices|r")
	else
		tooltip:AddDoubleLine(label, "|cffaaaaaano price for " .. e.missing .. "|r")
	end

	if ns.db.best and e.value then
		local bound = bindType == 1 or SaysBound(data)
		if not bound or CanDisenchant() then
			local auction = not bound and root.AuctionPrice(link or itemId) or nil
			local auctionAge = auction and root.AuctionAge(link or itemId) or nil
			local vendor = type(sellPrice) == "number" and sellPrice > 0 and sellPrice or nil
			local best = ns.Best(e.value, auction, vendor)
			if best then
				tooltip:AddLine(BestLine(best, e.value, auction, vendor, bound, auctionAge))
			end
		end
	end

	if ns.db.mats or (IsShiftKeyDown and IsShiftKeyDown()) then
		for _, r in ipairs(e.rows) do
			local count = CountText(r)
			tooltip:AddDoubleLine(
				"  " .. root.UI.ItemIcon(r.id, 12) .. "|cffaaaaaa" .. MatName(r.id) .. (count ~= "" and (" " .. count) or "") .. ", " .. PctText(r.p) .. "|r",
				r.price and (root.Money(r.price) .. " |cffaaaaaaeach|r" .. (root.AuctionStale(r.age) and (", " .. OLD .. root.SeenText(r.age) .. "|r") or ""))
					or "|cffaaaaaano price|r"
			)
		end
	end
end

-- Runs on every item tooltip; any failure must degrade to no line, never an error popup.
local function OnItemTooltip(tooltip, data)
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
		return
	end
	if not (ns.enabled and ns.db and ns.db.tooltip) then
		return
	end
	-- Secret first: even a truth test on a secret value errors, and this runs outside TryQuiet.
	local itemId
	if type(data) == "table" then
		itemId = data.id
	end
	if Secret(itemId) or itemId == nil then
		return
	end
	root.TryQuiet(ns, "tooltip", Annotate, tooltip, data)
end
ns.OnItemTooltip = OnItemTooltip -- test seam

-- -------------------------------------------------------------------- what disenchanting gives

-- Checks the tables against the game. Each disenchant you do is kept (ns.db.seen, the last
-- SEEN_MAX): the item with its quality and item level as the client reports them, the table this
-- feature used, and what came out. It only reads the loot window that opens; /kwd seen lists them.
-- The item is the bag item that locked as Disenchant was cast on it (ITEM_LOCK_CHANGED), else the
-- loot window's source item. Any secret value drops that disenchant.
local DISENCHANT = 13262 -- Disenchant (SpellName, build 1.60.1.70888)
local SEEN_MAX = 300
local lockedLink, lockedAt -- the last bag item that locked
local castAt, castLink -- a Disenchant that just succeeded, waiting for its loot window

local function Clock()
	local ok, t = pcall(GetTime)
	return ok and not Secret(t) and type(t) == "number" and t or nil
end

local function OnLock(_, bag, slot)
	if Secret(bag) or Secret(slot) or type(bag) ~= "number" or type(slot) ~= "number" then
		return -- an equipped slot (no bag slot), or unreadable
	end
	local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
	if not (ok and type(info) == "table") then
		return
	end
	local link, isLocked = info.hyperlink, info.isLocked
	if not Secret(link) and not Secret(isLocked) and isLocked == true and type(link) == "string" then
		lockedLink, lockedAt = link, Clock()
	end
end

local function OnCast(_, unit, _, spellID)
	if Secret(unit) or Secret(spellID) or unit ~= "player" or spellID ~= DISENCHANT then
		return
	end
	local now = Clock()
	castAt = now
	castLink = (now and lockedAt and now - lockedAt < 15) and lockedLink or nil
end

-- The loot window after a Disenchant: what came out, and from which item.
local function OnLoot()
	local now = Clock()
	if not (castAt and now and now - castAt < 10 and GetNumLootItems) then
		return
	end
	castAt = nil -- once: LOOT_READY and LOOT_OPENED both come
	local num = GetNumLootItems()
	if Secret(num) or type(num) ~= "number" or num < 1 then
		return
	end
	local mats, link = {}, castLink
	for slot = 1, num do
		local okL, mat = pcall(GetLootSlotLink, slot)
		if not okL or Secret(mat) then
			return
		end
		local src = { pcall(GetLootSourceInfo, slot) }
		if not src[1] then
			return
		end
		local count = 0
		for i = 2, #src, 2 do
			local guid, q = src[i], src[i + 1]
			if Secret(guid) or Secret(q) then
				return
			end
			count = count + (type(q) == "number" and q or 0)
			if not link and type(guid) == "string" and guid:find("^Item%-") and C_Item.GetItemLinkByGUID then
				local okI, l = pcall(C_Item.GetItemLinkByGUID, guid)
				if okI and not Secret(l) and type(l) == "string" then
					link = l
				end
			end
		end
		local matId = type(mat) == "string" and tonumber(mat:match("item:(%d+)")) or nil
		if matId then
			mats[matId] = (mats[matId] or 0) + math.max(count, 1)
		end
	end
	if not next(mats) then
		return
	end
	local itemId = link and tonumber(link:match("item:(%d+)")) or nil
	local quality, itemLevel, classID
	if link then
		local ok, name, _, q, il, _, _, _, _, _, _, _, cls = pcall(C_Item.GetItemInfo, link)
		if ok and name then
			quality, itemLevel, classID = q, il, cls
		end
	end
	local okT, t = pcall(time)
	local seen = ns.db.seen
	seen[#seen + 1] = {
		t = okT and not Secret(t) and t or nil,
		item = itemId,
		link = link,
		q = quality,
		il = itemLevel,
		pinned = itemId and ns.Data.items[itemId] or nil,
		de = itemId and ns.TableFor(itemId, quality, classID, itemLevel) or nil,
		mats = mats,
	}
	while #seen > SEEN_MAX do
		table.remove(seen, 1)
	end
end
ns.OnLock, ns.OnCast, ns.OnLoot = OnLock, OnCast, OnLoot -- test seams

-- Whether one disenchant matches the table this feature used: every material it gave is in it.
function ns.SeenMatches(rec)
	local rows = rec.de and ns.Data.tables[rec.de]
	if not rows then
		return nil
	end
	local inTable = {}
	for _, r in ipairs(rows) do
		inTable[r[1]] = true
	end
	for id in pairs(rec.mats or {}) do
		if not inTable[id] then
			return false
		end
	end
	return true
end

-- -------------------------------------------------------------------- definition

ns.title = "Disenchant Value"
ns.description = "On weapon and armor tooltips: what the item disenchants into, what that is worth at Auctionator's prices, "
	.. "and whether disenchanting pays more than the auction house or a vendor."
ns.icon = "Interface\\Icons\\INV_Enchant_Disenchant"
ns.blurb = "What a green is worth disenchanted"
ns.options = {
	{
		key = "tooltip",
		type = "toggle",
		label = "Show On Item Tooltips",
		tooltip = "Adds the disenchant value to weapon and armor tooltips (green, blue and purple).",
		default = true,
	},
	{
		key = "best",
		type = "toggle",
		label = "Say What Pays Best",
		tooltip = "Compares disenchanting with the item's own auction price and its vendor price, after the 5% auction cut. "
			.. "Bound items are compared only when you can disenchant them yourself.",
		default = true,
	},
	{
		key = "mats",
		type = "toggle",
		label = "Always List The Materials",
		tooltip = "Lists each material with its chance and price. Off: hold Shift over the item to see them.",
		default = false,
	},
}
ns.slash = { "/kwd", "/disenchantvalue" }

local function MatOrder()
	local ids = {}
	for id in pairs(ns.Data.mats) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return ids
end

-- Materials with a price, materials in all, and priced ones last seen over root.STALE_DAYS ago.
local function PricedCount()
	local n, total, old = 0, 0, 0
	for id in pairs(ns.Data.mats) do
		total = total + 1
		if root.AuctionPrice(id) then
			n = n + 1
			if root.AuctionStale(root.AuctionAge(id)) then
				old = old + 1
			end
		end
	end
	return n, total, old
end

local function PrintPrices()
	if not root.HasAuctionator() then
		ns:Print("Auctionator is not installed: tooltips list the materials without prices.")
		return
	end
	ns:Print("material prices from Auctionator:")
	for _, id in ipairs(MatOrder()) do
		local price = root.AuctionPrice(id)
		local text = "|cffaaaaaano price|r"
		if price then
			local age = root.AuctionAge(id)
			local seen = root.SeenText(age)
			text = root.Money(price) .. (seen and (", " .. (root.AuctionStale(age) and OLD or "|cffaaaaaa") .. seen .. "|r") or "")
		end
		print("  " .. root.UI.ItemIcon(id) .. MatName(id) .. ": " .. text)
	end
end

-- The disenchants recorded, the last ten in full, and how many matched the tables.
local function PrintSeen()
	local seen = ns.db.seen
	if #seen == 0 then
		ns:Print("no disenchants recorded yet. Each one you do is kept, to check these tables against the game.")
		return
	end
	local match, differ = 0, 0
	for _, r in ipairs(seen) do
		local m = ns.SeenMatches(r)
		match = match + (m == true and 1 or 0)
		differ = differ + (m == false and 1 or 0)
	end
	ns:Print(("%d disenchants recorded: %d match the tables, %d gave something they do not list."):format(#seen, match, differ))
	for i = math.max(1, #seen - 9), #seen do
		local r = seen[i]
		local parts = {}
		for id, n in pairs(r.mats) do
			parts[#parts + 1] = n .. "x " .. root.UI.ItemIcon(id) .. MatName(id)
		end
		table.sort(parts)
		local m = ns.SeenMatches(r)
		local verdict = m == true and "|cff33ff99as listed|r" or m == false and (OLD .. "not in the table|r") or "|cffaaaaaano table|r"
		print(("  %s, item level %s: %s, %s"):format(r.link or ("item " .. tostring(r.item or "?")), tostring(r.il or "?"), table.concat(parts, ", "), verdict))
	end
	if (ns.changedCount or 0) > 0 then
		print(("  |cffaaaaaa%d classic items seen with another quality on Forever (their Forever quality is used).|r"):format(ns.changedCount))
	end
end

function ns.OnSlash(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "options" or msg == "config" then
		root.OpenSettings(ns)
	elseif msg == "seen" then
		PrintSeen()
	elseif msg == "help" then
		ns:Print("/kwd - material prices; /kwd seen - your disenchants against the tables; /kwd options. Hover a weapon or armor piece for its value; hold Shift for the materials.")
	else
		PrintPrices()
	end
end

function ns.HubStatus()
	if not root.HasAuctionator() then
		return "|cffff9955Needs Auctionator for prices|r"
	end
	local n, total, old = PricedCount()
	if n == 0 then
		return "|cffff9955No material prices yet: scan the auction house|r"
	end
	local text = ("Prices for %d of %d materials"):format(n, total)
	if old > 0 then
		text = text .. (", " .. OLD .. "%d over %d days old|r"):format(old, root.STALE_DAYS)
	end
	return text
end

-- Tooltip hooks cannot be removed, so the hook is added once and checks ns.enabled each time.
function ns.OnEnable()
	if not ns.hooked and TooltipDataProcessor and Enum and Enum.TooltipDataType then
		ns.hooked = true
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
	end
end

function ns.OnLoad()
	ns.db.seen = type(ns.db.seen) == "table" and ns.db.seen or {}
	ns.db.changed = type(ns.db.changed) == "table" and ns.db.changed or {}
	local n = 0
	for _ in pairs(ns.db.changed) do
		n = n + 1
	end
	ns.changedCount = n
end

ns:RegisterEvent("ITEM_LOCK_CHANGED", OnLock)
ns:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", OnCast)
ns:RegisterEvent("LOOT_READY", OnLoot)
ns:RegisterEvent("LOOT_OPENED", OnLoot)
