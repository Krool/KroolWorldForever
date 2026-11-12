-- Quest Reward Value behavior checks. Runs after stubs.lua and the whole bundle.

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
local function capture(fn)
	local out = {}
	print = function(...)
		local t = {}
		for i = 1, select("#", ...) do
			t[#t + 1] = tostring((select(i, ...)))
		end
		out[#out + 1] = table.concat(t, " ")
	end
	local ok, err = pcall(fn)
	print = realPrint
	if not ok then
		error(err)
	end
	return out
end

local root = __ns
local ns = root.features.rewardvalue

-- ---------------------------------------------------------------- fixtures

local SWORD, DAGGER, RING, JUNK, CHEST, BOP = 900201, 900202, 900203, 900204, 900120, 900206
Items[SWORD] = { name = "Rusty Sword", quality = 1, sell = 100, class = 2 }
Items[DAGGER] = { name = "Plain Dagger", quality = 1, sell = 350, class = 2 }
Items[RING] = { name = "Odd Ring", quality = 1, sell = 50, class = 4 }
Items[JUNK] = { name = "Grey Thing", quality = 0, sell = 0, class = 15 }
Items[CHEST] = { name = "Forever Chestguard", quality = 2, ilvl = 28, sell = 500, class = 4 }
Items[BOP] = { name = "Soulbound Bracer", quality = 1, sell = 20, class = 4, bind = 1 }
local SOUL, ASTRAL, GLIMMER = 11083, 11082, 11084
local function MatPrices()
	Prices[SOUL], Prices[ASTRAL], Prices[GLIMMER] = 1000, 5000, 3000
end

local function Choose(...)
	Choices = {}
	for _, c in ipairs({ ... }) do
		Choices[#Choices + 1] = type(c) == "table" and c or { id = c }
	end
end
-- The choice index carrying the coin, or nil.
local function Marked()
	if not (ns.Coin() and ns.Coin():IsVisible()) then
		return nil
	end
	for i = 1, 3 do
		if ns.Coin():GetParent() == _G["QuestInfoRewardsFrameQuestInfoItem" .. i] then
			return i
		end
	end
end
-- Hover choice i (or any owner): the lines our feature added.
local function Hover(id, owner)
	TooltipOwner = owner
	local tt = ShowItem(id)
	TooltipOwner = nil
	return tt.lines
end
local function Says(lines, needle)
	for _, l in ipairs(lines) do
		if tostring(l):find(needle, 1, true) then
			return true
		end
	end
	return false
end
local function Button(i)
	return _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
end

-- ---------------------------------------------------------------- lifecycle

FireEvent("ADDON_LOADED", "KroolWorldForever")
local db = KroolWorldForeverDB.features.rewardvalue
check("feature slice created", type(db), "table")
check("on by default", db.enabled, true)
check("mark on by default", db.mark, true)
check("tooltip on by default", db.tooltip, true)
capture(function()
	FireEvent("PLAYER_LOGIN")
end)
check("enabled after login", ns.enabled, true)
check("hub icon", ns.icon, "Interface\\Icons\\INV_Misc_Coin_02")
check("hub blurb", ns.blurb, "Marks the quest reward worth the most")
check("hub status is a string", type(ns.HubStatus()), "string")
local hooks = #TooltipChains[Enum.TooltipDataType.Item]
ns.OnEnable()
check("tooltip hooked once only", #TooltipChains[Enum.TooltipDataType.Item], hooks)
check("/kwf rewardvalue registered", type(root.features.rewardvalue.OnSlash), "nil")

-- ---------------------------------------------------------------- marking

AuctionatorOn(true)
Choose(SWORD, DAGGER, RING)
OpenQuest()
check("highest vendor value gets the coin", Marked(), 2)
check("the best choice is the dagger", ns.best.id, DAGGER)

-- A stack counts whole: 4 x 100 beats one 350.
Choose({ id = SWORD, count = 4 }, DAGGER, RING)
OpenQuest()
check("the stack counts: 4 x 100 beats 350", Marked(), 1)

-- The auction price beats the vendor's (net of the 5% cut): 5000 * 0.95 = 4750.
Choose(SWORD, DAGGER, RING)
Prices[RING] = 5000
OpenQuest()
check("auction value beats vendor", Marked(), 3)
check("how: auction", ns.best.how, "auction")
Prices[RING] = nil

-- The disenchant value beats the vendor's.
MatPrices()
Choose(SWORD, CHEST, DAGGER)
OpenQuest()
check("disenchant value beats vendor", Marked(), 2)
check("how: disenchant", ns.best.how, "disenchant")
for _, id in ipairs({ SOUL, ASTRAL, GLIMMER }) do
	Prices[id] = nil
end

-- A reward that binds on pickup has no auction price.
Prices[BOP] = 99999
Choose(BOP, SWORD)
OpenQuest()
check("a bound reward's auction price does not count", Marked(), 2)
Prices[BOP] = nil

-- ---------------------------------------------------------------- no mark

Choose(DAGGER)
OpenQuest()
check("a single choice: no mark", Marked(), nil)
Choose(SWORD, { id = DAGGER, count = 1 }, SWORD)
Items[SWORD].sell = 350
OpenQuest()
check("a tie for the top: no mark", Marked(), nil)
Items[SWORD].sell = 100
Choose(JUNK, JUNK)
OpenQuest()
check("all unpriced: no mark", Marked(), nil)
check("all unpriced: no best", ns.best, nil)

-- A currency choice has no item link: it is skipped, not waited on, so the items still get a mark.
Choose({ currency = true }, SWORD, DAGGER)
OpenQuest()
check("a currency choice does not block the mark", Marked(), 3)
local _, _, waitingFor = ns.Scan()
check("a currency choice is not waited on", next(waitingFor), nil)
check("a currency choice is not pending", ns.Scan()[1].pending, nil)

-- ---------------------------------------------------------------- uncached items

local LATE = 900210
Choose(SWORD, LATE)
OpenQuest()
check("an uncached choice: no mark yet", Marked(), nil)
Items[LATE] = { name = "Late Blade", quality = 1, sell = 900, class = 2 }
FireEvent("GET_ITEM_INFO_RECEIVED", 12345)
check("another item's info changes nothing", Marked(), nil)
FireEvent("GET_ITEM_INFO_RECEIVED", LATE)
check("the uncached item is re-priced when it arrives", Marked(), 2)

-- ---------------------------------------------------------------- clearing

CloseQuest()
check("the coin goes when the quest frame closes", Marked(), nil)
Choose(SWORD, DAGGER)
OpenQuest("QUEST_DETAIL")
check("QUEST_DETAIL marks too", Marked(), 2)
Choose(DAGGER, SWORD)
OpenQuest()
check("another quest moves the coin", Marked(), 1)
Button(1).shown = false
check("a hidden button hides the coin", Marked(), nil)
Button(1).shown = true

-- ---------------------------------------------------------------- tooltip

Choose(SWORD, DAGGER, RING)
OpenQuest()
local lines = Hover(DAGGER, Button(2))
check("best choice: Best value line", Says(lines, "Best value:"), true)
check("best choice: names the price source", Says(lines, "(vendor)"), true)
lines = Hover(SWORD, Button(1))
check("other choice: Worth line", Says(lines, "Worth"), true)
check("other choice: not Best value", Says(lines, "Best value:"), false)
check("other items' tooltips untouched: bag item", #Hover(DAGGER, nil), 0)
local reward = Button(3)
reward.type = "reward"
check("a non-choice reward button: nothing", #Hover(RING, reward), 0)
reward.type = "choice"
check("item that is not that choice: nothing", #Hover(DAGGER, Button(3)), 0)
check("a bag slot owner: nothing", #Hover(DAGGER, { GetBagID = function() return 0 end, GetID = function() return 1 end }), 0)
Prices[SWORD] = 3000
Ages[SWORD] = 9
Choose(SWORD, DAGGER)
OpenQuest()
lines = Hover(SWORD, Button(1))
check("old auction price is dated", Says(lines, "seen 9 days ago"), true)
Prices[SWORD], Ages[SWORD] = nil, nil
AuctionatorOn(false)
OpenQuest()
lines = Hover(DAGGER, Button(2))
check("without Auctionator the tooltip says vendor only", Says(lines, "vendor only"), true)
check("without Auctionator it still marks by vendor", Marked(), 2)
AuctionatorOn(true)
check("hub status names the best reward", ns.HubStatus():find("Plain Dagger", 1, true) ~= nil, true)

-- Options.
root.SetOption(ns, "tooltip", false)
check("tooltip option off: silent", #Hover(DAGGER, Button(2)), 0)
root.SetOption(ns, "tooltip", true)
root.SetOption(ns, "mark", false)
check("mark option off: coin gone", Marked(), nil)
root.SetOption(ns, "mark", true)
OpenQuest()
check("mark option on: coin back", Marked(), 2)

-- ---------------------------------------------------------------- advice only

check("no reward was ever chosen", GetQuestRewardCalls, 0)

-- ---------------------------------------------------------------- off

capture(function()
	SlashCmdList.KROOLWORLDFOREVER("rewardvalue off")
end)
check("/kwf rewardvalue off", ns.enabled, false)
check("off: coin gone", Marked(), nil)
check("off: tooltip silent", #Hover(DAGGER, Button(2)), 0)
OpenQuest()
check("off: a new quest is not marked", Marked(), nil)
capture(function()
	SlashCmdList.KROOLWORLDFOREVER("rewardvalue on")
end)
check("/kwf rewardvalue on", ns.enabled, true)
check("on: coin back", Marked(), 2)
check("on: tooltip back", Says(Hover(DAGGER, Button(2)), "Best value:"), true)

local mine = 0
for _, err in ipairs(KroolWorldForeverDB.errors or {}) do
	if err.feature == "rewardvalue" then
		mine = mine + 1
		realPrint("  caught: " .. tostring(err.where) .. ": " .. tostring(err.message))
	end
end
check("no errors caught in Quest Reward Value", mine, 0)

realPrint(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
