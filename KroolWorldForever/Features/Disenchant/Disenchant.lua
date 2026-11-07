-- Disenchant Value: on weapon and armor tooltips, what the item disenchants into, what that is
-- worth at Auctionator's prices, and whether disenchanting it (yourself or through a
-- disenchanter) pays more than auctioning or vendoring it.
--
-- The tables are the 1.12 ones from the classic database (Data.lua): every classic item is
-- listed with its own table, and anything the 1.12 data does not know (Forever's new items) goes
-- by quality, weapon or armor and item level.
-- Without Auctionator the tooltip still names the materials. Auctionator has a disenchant line
-- of its own, but on Forever it loads its retail tables (Warlords of Draenor onward), so items
-- of classic levels get none.

local _, root = ...
local ns = root.Feature("disenchant")

local WEAPON, ARMOR = 2, 4
local CUT = 0.05 -- auction house cut, counted when comparing with the vendor
local MAIN_SHARE = 0.1 -- a material at least this likely with no price leaves the value unknown

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

-- The disenchant table an item uses, or nil when it cannot be disenchanted.
function ns.TableFor(itemId, quality, classID, itemLevel)
	local D = ns.Data
	local known = D.items[itemId]
	if known ~= nil then
		return known > 0 and known or nil
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

-- { entry, rows = { {id, p, min, max, price}, ... }, value, missing, hasAH }. value is the
-- expected auction worth of one disenchant in copper; nil without Auctionator or when a main
-- material (missing names it) has no price. Rare materials without a price count as 0.
function ns.Evaluate(itemId, quality, classID, itemLevel)
	local entry = ns.TableFor(itemId, quality, classID, itemLevel)
	if not entry then
		return nil
	end
	local hasAH = root.HasAuctionator()
	local rows, value, missing = {}, 0, nil
	for _, r in ipairs(ns.Data.tables[entry]) do
		local price = hasAH and root.AuctionPrice(r[1]) or nil
		rows[#rows + 1] = { id = r[1], p = r[2], min = r[3], max = r[4], price = price }
		if price then
			value = value + r[2] * (r[3] + r[4]) / 2 * price
		elseif r[2] >= MAIN_SHARE and not missing then
			missing = MatName(r[1])
		end
	end
	if not hasAH or missing then
		value = nil
	end
	return { entry = entry, rows = rows, value = value, missing = missing, hasAH = hasAH }
end

-- What pays most: "vendor", "auction" or "disenchant" (ties go to the less work). Auction and
-- disenchant values are auction prices, so the cut comes off them before the vendor compare.
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
	return best
end

-- -------------------------------------------------------------------- tooltip

local BEST_TEXT = {
	disenchant = "|cff33ff99Best: disenchant it|r",
	auction = "|cffffcc00Best: sell it at auction|r",
	vendor = "|cffaaaaaaBest: sell it to a vendor|r",
}

local function BestLine(best, disenchant, auction, vendor, bound)
	local others = {}
	if best ~= "disenchant" then
		others[#others + 1] = "disenchant " .. root.Money(disenchant)
	end
	if best ~= "auction" then
		if auction then
			others[#others + 1] = "auction " .. root.Money(auction)
		elseif not bound then
			others[#others + 1] = "no auction price"
		end
	end
	if best ~= "vendor" and vendor then
		others[#others + 1] = "vendor " .. root.Money(vendor)
	end
	local tail = #others > 0 and (" |cffaaaaaa(" .. table.concat(others, ", ") .. ")|r") or ""
	return BEST_TEXT[best] .. tail
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
		if text ~= nil and not Secret(text) and type(text) == "string" then
			for _, mark in pairs(marks) do
				if text == mark then
					return true
				end
			end
		end
	end
	return false
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
	local e = ns.Evaluate(itemId, quality, classID, itemLevel)
	if not e then
		return
	end

	local label = root.UI.InlineIcon(ns.icon, 14) .. " |cffb48cffDisenchant|r"
	if e.value then
		tooltip:AddDoubleLine(label, root.Money(e.value))
	elseif not e.hasAH then
		tooltip:AddDoubleLine(label, "|cffaaaaaaneeds Auctionator prices|r")
	else
		tooltip:AddDoubleLine(label, "|cffaaaaaano price for " .. e.missing .. "|r")
	end

	if ns.db.best and e.value then
		local bound = bindType == 1 or SaysBound(data)
		if not bound or CanDisenchant() then
			local auction = not bound and root.AuctionPrice(link or itemId) or nil
			local vendor = type(sellPrice) == "number" and sellPrice > 0 and sellPrice or nil
			local best = ns.Best(e.value, auction, vendor)
			if best then
				tooltip:AddLine(BestLine(best, e.value, auction, vendor, bound))
			end
		end
	end

	if ns.db.mats or (IsShiftKeyDown and IsShiftKeyDown()) then
		for _, r in ipairs(e.rows) do
			local count = CountText(r)
			tooltip:AddDoubleLine(
				"  " .. root.UI.ItemIcon(r.id, 12) .. "|cffaaaaaa" .. MatName(r.id) .. (count ~= "" and (" " .. count) or "") .. ", " .. PctText(r.p) .. "|r",
				r.price and (root.Money(r.price) .. " |cffaaaaaaeach|r") or "|cffaaaaaano price|r"
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
	local itemId = type(data) == "table" and data.id or nil
	if itemId == nil or Secret(itemId) then
		return
	end
	pcall(Annotate, tooltip, data)
end
ns.OnItemTooltip = OnItemTooltip -- test seam

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

local function PricedCount()
	local n, total = 0, 0
	for id in pairs(ns.Data.mats) do
		total = total + 1
		if root.AuctionPrice(id) then
			n = n + 1
		end
	end
	return n, total
end

local function PrintPrices()
	if not root.HasAuctionator() then
		ns:Print("Auctionator is not installed: tooltips list the materials without prices.")
		return
	end
	ns:Print("material prices from Auctionator:")
	for _, id in ipairs(MatOrder()) do
		local price = root.AuctionPrice(id)
		print("  " .. root.UI.ItemIcon(id) .. MatName(id) .. ": " .. (price and root.Money(price) or "|cffaaaaaano price|r"))
	end
end

function ns.OnSlash(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "options" or msg == "config" then
		root.OpenSettings(ns)
	elseif msg == "help" then
		ns:Print("/kwd - material prices; /kwd options. Hover a weapon or armor piece for its value; hold Shift for the materials.")
	else
		PrintPrices()
	end
end

function ns.HubStatus()
	if not root.HasAuctionator() then
		return "|cffff9955Needs Auctionator for prices|r"
	end
	local n, total = PricedCount()
	if n == 0 then
		return "|cffff9955No material prices yet: scan the auction house|r"
	end
	return ("Prices for %d of %d materials"):format(n, total)
end

-- Tooltip hooks cannot be removed, so the hook is added once and checks ns.enabled each time.
function ns.OnEnable()
	if not ns.hooked and TooltipDataProcessor and Enum and Enum.TooltipDataType then
		ns.hooked = true
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
	end
end
