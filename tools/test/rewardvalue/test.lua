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
check("a classic green: not unsure", ns.best.unsure, nil)

-- A low blue's disenchant value is unmeasured on Forever: the tooltip says so.
local LOWBLUE = 900077
Items[LOWBLUE] = { name = "Forever Shoulders", quality = 3, ilvl = 18, sell = 400, class = 4 }
Prices[10978] = 3000 -- Small Glimmering Shard, the low blue bracket
Choose(SWORD, LOWBLUE, DAGGER)
OpenQuest()
check("low blue wins by disenchant", ns.best.index .. ":" .. ns.best.how, "2:disenchant")
check("low blue: unsure carried", ns.best.unsure, true)
check("low blue: tooltip says unconfirmed", Says(Hover(LOWBLUE, Button(2)), "(unconfirmed)"), true)
check("a vendor-priced choice: no unconfirmed", Says(Hover(SWORD, Button(1)), "unconfirmed"), false)
Choose(SWORD, CHEST, DAGGER)
OpenQuest()
check("a classic green's tooltip: no unconfirmed", Says(Hover(CHEST, Button(2)), "unconfirmed"), false)
Prices[10978] = nil
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

-- ---------------------------------------------------------------- quest log

-- The quest log and the map view display through QuestInfo_Display too (a template with
-- questLog = true). Their choices are the selected quest's, not the quest giver's.
local function LogChoose(...)
	LogChoices = {}
	for _, c in ipairs({ ... }) do
		LogChoices[#LogChoices + 1] = type(c) == "table" and c or { id = c }
	end
end
local function MapButton(i)
	return _G["MapQuestInfoRewardsFrameQuestInfoItem" .. i]
end
local function MarkedMap()
	if not (ns.Coin() and ns.Coin():IsVisible()) then
		return nil
	end
	for i = 1, 3 do
		if ns.Coin():GetParent() == MapButton(i) then
			return i
		end
	end
end

CloseQuest()
Choose(DAGGER, SWORD) -- the quest giver's last offer: not the log's business
LogChoose(SWORD, DAGGER)
OpenQuestLog()
check("quest log: the best choice gets the coin", Marked(), 2)
check("quest log: it is the log's choice, not the quest giver's", ns.best.id, DAGGER)
check("quest log: Best value on the tooltip", Says(Hover(DAGGER, Button(2)), "Best value:"), true)
check("quest log: Worth on the other choice", Says(Hover(SWORD, Button(1)), "Worth"), true)
check("quest log: hub status names the best reward", ns.HubStatus():find("Plain Dagger", 1, true) ~= nil, true)
LogChoose({ id = SWORD, count = 4 }, DAGGER)
OpenQuestLog()
check("quest log: the stack counts", Marked(), 1)

-- Another quest is selected: the panel is laid out again.
LogChoose(DAGGER, SWORD, RING)
OpenQuestLog()
check("quest log: another quest moves the coin", Marked(), 1)
LogChoose(DAGGER)
OpenQuestLog()
check("quest log: a single choice: no mark", Marked(), nil)

-- The map's quest view has its own rewards frame.
LogChoose(SWORD, RING, DAGGER)
OpenQuestLog(true)
check("map view: the coin is on the map's button", MarkedMap(), 3)
check("map view: not on the quest frame's", Marked(), nil)
check("map view: tooltip", Says(Hover(DAGGER, MapButton(3)), "Best value:"), true)
OpenQuestLog()
check("back in the log frame: the coin follows", Marked(), 3)

-- In the log a currency choice and an item choice can carry the same button id: items and
-- currencies are numbered apart. The coin goes on the item.
LogChoose({ currency = true }, DAGGER, SWORD)
OpenQuestLog()
check("quest log: currency first, the item button gets the coin", Marked(), 2)
check("quest log: the best keeps its choice index", ns.best.index, 2)
check("quest log: and the item's button id", ns.best.button, 1)
check("quest log: the item's tooltip", Says(Hover(DAGGER, Button(2)), "Best value:"), true)
check("quest log: a currency button's tooltip: nothing", #Hover(DAGGER, Button(1)), 0)

-- An item whose link is not ready is waited on by the id the log gives.
local LATELOG = 900211
LogChoose(SWORD, { id = LATELOG, nolink = true })
OpenQuestLog()
check("quest log: no link yet: no mark", Marked(), nil)
local _, _, logWaiting = ns.Scan()
check("quest log: the item is waited on by id", logWaiting[LATELOG], true)
Items[LATELOG] = { name = "Late Log Blade", quality = 1, sell = 900, class = 2 }
LogChoices[2].nolink = nil
FireEvent("GET_ITEM_INFO_RECEIVED", LATELOG)
check("quest log: marked when the item arrives", Marked(), 2)

-- Neither a link nor an id yet: the next item to arrive, whichever it is, prompts another look.
LogChoose(SWORD, { nolink = true })
OpenQuestLog()
check("quest log: no link and no id: no mark", Marked(), nil)
LogChoices[2] = { id = LATELOG }
FireEvent("GET_ITEM_INFO_RECEIVED", 12345)
check("quest log: looked again when an item arrived", Marked(), 2)

-- Nothing to read: no selected quest, rewards hidden by the client, a secret quest id.
LogChoose(SWORD, DAGGER)
LogQuestID = 0
OpenQuestLog()
check("quest log: no selected quest: no mark", Marked(), nil)
check("quest log: no selected quest: no best", ns.best, nil)
LogQuestID = 4711
LogShowRewards = false
OpenQuestLog()
check("quest log: rewards not shown: no mark", Marked(), nil)
LogShowRewards = true
local realSelected = C_QuestLog.GetSelectedQuest
C_QuestLog.GetSelectedQuest = function()
	return Secret()
end
OpenQuestLog()
check("quest log: a secret quest id: no mark", Marked(), nil)
C_QuestLog.GetSelectedQuest = realSelected
OpenQuestLog()
check("quest log: marks again", Marked(), 2)

-- The quest giver's window closing does not take the log's mark, and the log closing has no
-- event: the hub stops naming the reward once its button is off screen.
CloseQuest()
check("quest log: QUEST_FINISHED leaves the log's mark", Marked(), 2)
CloseQuestLog()
check("quest log closed: the coin is hidden with its button", Marked(), nil)
check("quest log closed: hub status names no reward", ns.HubStatus():find("Plain Dagger", 1, true), nil)

-- Back at a quest giver: its own choices again.
Choose(SWORD, DAGGER)
LogChoose(DAGGER, SWORD)
OpenQuest()
check("the quest dialog display marks its own choices", Marked(), 2)
OpenQuestLog()
check("the log again: the log's choices", Marked(), 1)
OpenQuest("QUEST_DETAIL")
check("QUEST_DETAIL after the log: the quest giver's choices", Marked(), 2)
CloseQuest()
check("the quest giver's window closing clears its mark", Marked(), nil)
check("and its best", ns.best, nil)

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
OpenQuestLog()
check("off: the quest log is not marked", Marked(), nil)
check("off: the quest log's tooltip is silent", #Hover(DAGGER, Button(1)), 0)
OpenQuest()
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
