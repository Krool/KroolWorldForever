-- Quest Reward Value: a copper coin on the quest reward choice worth the most. Each choice is
-- worth its stack (vendor price times the count) at the best of the vendor's price, the auction
-- house's and the disenchant value, priced the way Least Valuable does (Disenchant Value's
-- Evaluate and Best, so the 5% auction cut comes off the last two). A reward that binds when
-- picked up (bind type 1, or 4 for a quest item) has no auction price, and its disenchant counts
-- only when you can disenchant it yourself. Advice only: it never selects or accepts a reward.
--
-- No mark with fewer than two choices, while any choice is still loading, when every choice is
-- worth nothing, or when the top two are worth the same.
--
-- Where the buttons are (Blizzard's Mainline QuestInfo.lua, forever branch; read from memory,
-- not re-fetched on 2026-11-12): QuestInfo_ShowRewards lays out QuestInfoFrame.rewardsFrame
-- (global QuestInfoRewardsFrame), taking each button from QuestInfo_GetRewardButton, which keeps
-- them in rewardsFrame.RewardButtons (globals QuestInfoRewardsFrameQuestInfoItem<n>). A choice
-- button has .type == "choice" and :GetID() the choice index; its tooltip is
-- GameTooltip:SetQuestItem("choice", index), owned by that button.

local _, root = ...
local ns = root.Feature("rewardvalue")

-- Blizzard's coin art, as Least Valuable uses it (MoneyFrame.xml; in the forever atlas list).
local MARK_ATLAS = "coin-copper"
local MARK_SIZE = 15
local GREY, OLD, GOLD = "|cffaaaaaa", "|cffff9955", "|cffffd27f"
local HOW = { vendor = "vendor", auction = "Auction House", disenchant = "disenchanted" }
local BIND_ON_PICKUP = { [1] = true, [4] = true } -- BoP, quest item

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- pcall for a function that may be missing: false when it is.
local function Call(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, ...)
end

-- -------------------------------------------------------------------- value

-- One choice's facts from its link: { index, id, link, name, count, unit, value, how, stale } or
-- { index, pending = true } while the item is not cached.
local function Price(i, ctx)
	-- A currency choice has no item link: skip it, or it would wait for an item that never loads.
	-- Loot type 1 is LOOT_LIST_CURRENCY (Blizzard's forever QuestInfo.lua, QuestInfo_ShowRewards).
	local okT, lootType = Call(GetQuestItemInfoLootType, "choice", i)
	if okT and not Secret(lootType) and lootType == 1 then
		return { index = i, currency = true, value = 0 }
	end
	local ok, link = Call(GetQuestItemLink, "choice", i)
	if not ok or Secret(link) or type(link) ~= "string" then
		return { index = i, pending = true }
	end
	local okI, _, _, count = Call(GetQuestItemInfo, "choice", i)
	if not okI or Secret(count) or type(count) ~= "number" or count < 1 then
		count = 1
	end
	local okG, name, _, quality, itemLevel, _, _, _, _, _, _, sell, classID, _, bindType =
		Call(C_Item and C_Item.GetItemInfo, link)
	if not (okG and type(name) == "string") then
		return { index = i, link = link, pending = true }
	end
	local id = tonumber(link:match("item:(%d+)"))
	local bound = BIND_ON_PICKUP[bindType] == true
	local vendor = type(sell) == "number" and sell > 0 and sell or nil
	local auction, age, de, deStale
	if not bound then
		auction = root.AuctionPrice(link)
		age = auction and root.AuctionAge(link) or nil
	end
	if ctx.DE and ctx.DE.Evaluate and (not bound or ctx.canDE) then
		local e = ctx.DE.Evaluate(id, quality, classID, itemLevel)
		de = e and e.value or nil
		deStale = e and e.stale or nil
	end
	local how, unit
	if ctx.DE and ctx.DE.Best then
		how, unit = ctx.DE.Best(de, auction, vendor)
	elseif vendor then
		how, unit = "vendor", vendor
	end
	local r = { index = i, id = id, link = link, name = name, count = count }
	if how then
		r.how, r.unit, r.value = how, unit, unit * count
		if how == "auction" and root.AuctionStale(age) then
			r.stale = age
		elseif how == "disenchant" then
			r.stale = deStale
		end
	else
		r.value = 0
	end
	return r
end

-- Prices every choice. Returns the list (index order), the best choice or nil, and the ids of
-- items still loading. The best is nil unless it is the only one at its value and above zero.
function ns.Scan()
	local list, best, waiting = {}, nil, {}
	local okN, n = Call(GetNumQuestChoices)
	if not okN or Secret(n) or type(n) ~= "number" or n < 1 then
		return list, nil, waiting
	end
	local DE = root.features.disenchant
	local ctx = { DE = DE, canDE = DE and DE.CanDisenchant and DE.CanDisenchant() or false }
	local tie, anyPending = false, false
	for i = 1, n do
		local r = Price(i, ctx)
		list[i] = r
		if r.pending then
			anyPending = true
			local id = r.link and tonumber(r.link:match("item:(%d+)"))
			if id then
				waiting[id] = true
			end
		elseif not best or r.value > best.value then
			best, tie = r, false
		elseif r.value == best.value then
			tie = true
		end
	end
	if n < 2 or anyPending or tie or not best or best.value <= 0 then
		best = nil
	end
	return list, best, waiting
end

-- -------------------------------------------------------------------- the coin

-- The reward button for a choice index, or nil.
local function FindButton(i)
	local rf = type(QuestInfoFrame) == "table" and QuestInfoFrame.rewardsFrame or QuestInfoRewardsFrame
	local buttons = type(rf) == "table" and rf.RewardButtons
	local function Match(b)
		return type(b) == "table" and b.type == "choice" and b:GetID() == i
	end
	if type(buttons) == "table" then
		for _, b in ipairs(buttons) do
			if Match(b) then
				return b
			end
		end
	end
	for n = 1, 12 do
		local b = _G["QuestInfoRewardsFrameQuestInfoItem" .. n]
		if Match(b) then
			return b
		end
	end
	return nil
end

local coin -- our frame, false when it could not be made
local function Coin()
	if coin == nil then
		coin = false
		local f = CreateFrame("Frame")
		f:Hide()
		local tex = f:CreateTexture(nil, "OVERLAY")
		tex:SetAtlas(MARK_ATLAS)
		tex:SetSize(MARK_SIZE, MARK_SIZE)
		tex:SetPoint("TOPRIGHT", -2, -2)
		coin = f
	end
	return coin or nil
end
ns.Coin = function()
	return coin or nil
end -- test seam

-- Puts the coin on the marked choice's button, or takes it away. It takes no mouse.
function ns.Place()
	local m = ns.enabled and ns.db and ns.db.mark and ns.best or nil
	local button = m and FindButton(m.index) or nil
	if not button then
		if coin then
			coin:Hide()
		end
		ns.markButton = nil
		return
	end
	local c = Coin()
	if not c then
		return
	end
	if ns.markButton ~= button then
		c:SetParent(button)
		c:ClearAllPoints()
		c:SetAllPoints(button)
		ns.markButton = button
	end
	local ok, level = Call(button.GetFrameLevel, button)
	if ok and type(level) == "number" then
		c:SetFrameLevel(level + 2)
	end
	c:Show()
end

local pending = {} -- item ids a re-price waits on

local function Refresh()
	local list, best, waiting = ns.Scan()
	ns.list, ns.best, pending = list, best, waiting
	ns.Place()
end
ns.Refresh = Refresh

local function Clear()
	ns.list, ns.best, pending = nil, nil, {}
	ns.Place()
end

-- -------------------------------------------------------------------- tooltip

local function Annotate(tooltip, data)
	local owner = tooltip.GetOwner and tooltip:GetOwner()
	if type(owner) ~= "table" or owner.type ~= "choice" or type(owner.GetID) ~= "function" then
		return
	end
	local i = owner:GetID()
	if Secret(i) or type(i) ~= "number" then
		return
	end
	local list, best = ns.Scan()
	local r = list[i]
	if not r or r.pending or r.id ~= data.id or not r.how then
		return
	end
	local what = root.Money(r.value) .. GREY .. " (" .. HOW[r.how] .. ")|r"
	local text
	if best and best.index == i then
		text = root.UI.InlineIcon(ns.icon, 14) .. " " .. GOLD .. "Best value:|r " .. what
	else
		text = GREY .. "Worth|r " .. what
	end
	if r.stale then
		text = text .. " " .. OLD .. "(price " .. root.SeenText(r.stale) .. ")|r"
	end
	if not root.HasAuctionator() then
		text = text .. " " .. OLD .. "(no Auctionator: vendor only)|r"
	end
	tooltip:AddLine(text)
end

local function OnItemTooltip(tooltip, data)
	if tooltip ~= GameTooltip or not (ns.enabled and ns.db and ns.db.tooltip) then
		return
	end
	-- Secret first: even a truth test on a secret value errors, and this runs outside TryQuiet.
	local id
	if type(data) == "table" then
		id = data.id
	end
	if Secret(id) or id == nil then
		return
	end
	root.TryQuiet(ns, "tooltip", Annotate, tooltip, data)
end
ns.OnItemTooltip = OnItemTooltip -- test seam

-- -------------------------------------------------------------------- definition

ns.title = "Quest Reward Value"
ns.description = "Marks the quest reward choice worth the most, with a coin on its button: each choice at the "
	.. "best of its vendor price, Auction House price (Auctionator) and disenchant value. It only marks; "
	.. "you still pick the reward. Without Auctionator it counts vendor prices only."
ns.icon = "Interface\\Icons\\INV_Misc_Coin_02"
ns.blurb = "Marks the quest reward worth the most"
ns.options = {
	{
		key = "mark",
		type = "toggle",
		label = "Mark Best Reward",
		tooltip = "A copper coin on the reward choice worth the most, counting the whole stack at its best price "
			.. "(vendor, Auction House or disenchant). Nothing is marked when choices tie or are worth nothing.",
		default = true,
	},
	{
		key = "tooltip",
		type = "toggle",
		label = "Value On Reward Tooltips",
		tooltip = "Adds what a reward choice is worth, and at which price, to its tooltip while you choose.",
		default = true,
	},
}

function ns.HubStatus()
	if ns.best then
		return "Best reward: " .. root.UI.ItemIcon(ns.best.id, 0) .. ns.best.name .. ", " .. root.Money(ns.best.value)
	end
	local text = GREY .. "Marks the best reward when you choose one|r"
	if not root.HasAuctionator() then
		text = text .. " " .. OLD .. "(vendor prices only)|r"
	end
	return text
end

-- -------------------------------------------------------------------- lifecycle

local function Shown()
	if ns.enabled then
		root.Try(ns, "rewards", Refresh)
	end
end

-- Tooltip and layout hooks cannot be removed, so they are added once and check ns.enabled.
function ns.OnEnable()
	if not ns.tooltipHooked and TooltipDataProcessor and Enum and Enum.TooltipDataType then
		ns.tooltipHooked = true
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
	end
	-- The buttons are set up after QUEST_COMPLETE fires, when QuestInfo_ShowRewards runs.
	if not ns.layoutHooked and type(hooksecurefunc) == "function" and type(QuestInfo_ShowRewards) == "function" then
		ns.layoutHooked = pcall(hooksecurefunc, "QuestInfo_ShowRewards", Shown)
	end
	Shown()
end

function ns.OnDisable()
	Clear()
end

function ns.OnOptionChanged()
	ns.Place()
end

ns:RegisterEvent("QUEST_DETAIL", Shown)
ns:RegisterEvent("QUEST_COMPLETE", Shown)
ns:RegisterEvent("QUEST_ITEM_UPDATE", Shown)
ns:RegisterEvent("QUEST_FINISHED", Clear)
ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemId)
	if not Secret(itemId) and pending[itemId] then -- the secret check first: testing a secret errors
		Shown()
	end
end)
