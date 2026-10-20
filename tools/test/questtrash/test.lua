-- Quest Trash behavior checks. Runs after stubs.lua and the whole bundle.

local failures, count = 0, 0
local function check(label, got, want)
	count = count + 1
	if got ~= want then
		failures = failures + 1
		print("FAIL: " .. label .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
	else
		print("ok:   " .. label)
	end
end
local function has(lines, needle)
	for _, l in ipairs(lines) do
		if l:find(needle, 1, true) then
			return true
		end
	end
	return false
end

local FQT = KroolWorldForever.QuestTrash
local QT = __ns.features.questtrash
local QUEST, TRADE = 12, 7

-- ---------------------------------------------------------------- fixtures

-- 1001 one-time collect quest, item 5001 (quest item)
Quests[1001] = { name = "Plain Collect", objectives = { nil, nil, { { 5001 } } } }
ItemClass[5001] = QUEST
-- 1002 repeatable (specialFlags), item 5002
Quests[1002] = { name = "Turn-in Farm", specialFlags = 1, objectives = { nil, nil, { { 5002 } } } }
ItemClass[5002] = QUEST
-- 1003 daily (questFlags 4096), item 5003
Quests[1003] = { name = "Daily", questFlags = 4096 + 8, objectives = { nil, nil, { { 5003 } } } }
ItemClass[5003] = QUEST
-- 16 is on the cmangos/Turtle extra-repeatable list, item 5004
Quests[16] = { name = "Old Repeatable", objectives = { nil, nil, { { 5004 } } } }
ItemClass[5004] = QUEST
-- 1005 Midsummer quest, item 5005
Quests[1005] = { name = "Midsummer", zoneOrSort = -369, objectives = { nil, nil, { { 5005 } } } }
ItemClass[5005] = QUEST
-- 1006 Horde-only (Orc bit), item 5006
Quests[1006] = { name = "Orc Only", requiredRaces = 2, objectives = { nil, nil, { { 5006 } } } }
ItemClass[5006] = QUEST
-- 1007 Mage-only, item 5007
Quests[1007] = { name = "Mage Only", requiredClasses = 128, objectives = { nil, nil, { { 5007 } } } }
ItemClass[5007] = QUEST
-- 1008 Human + Alliance Skyborne mask (above 32 bits), item 5008
Quests[1008] = { name = "Wide Mask", requiredRaces = 4294967296 + 1, objectives = { nil, nil, { { 5008 } } } }
ItemClass[5008] = QUEST
-- 1009/1010 mutually exclusive, both use item 5009
Quests[1009] = { name = "Variant", exclusiveTo = { 1010 }, objectives = { nil, nil, { { 5009 } } } }
Quests[1010] = { name = "Variant", exclusiveTo = { 1009 }, objectives = { nil, nil, { { 5009 } } } }
ItemClass[5009] = QUEST
-- 1011 breadcrumb started by item 5011, leads to 1012
Quests[1011] = { name = "Breadcrumb Note", breadcrumbForQuestId = 1012 }
Quests[1012] = { name = "Real Quest" }
Items[5011] = { startQuest = 1011 }
ItemClass[5011] = QUEST
-- 1013 provides item 5013 on accept (quest-side link only)
Quests[1013] = { name = "Provider", sourceItemId = 5013 }
ItemClass[5013] = QUEST
-- 5014 used by a done quest and an open one
Quests[1014] = { name = "Done Half", objectives = { nil, nil, { { 5014 } } } }
Quests[1015] = { name = "Open Half", objectives = { nil, nil, { { 5014 } } } }
ItemClass[5014] = QUEST
-- 5015 tradable mat used by a done quest
Quests[1016] = { name = "Cloth Turn-in", objectives = { nil, nil, { { 5015 } } } }
ItemClass[5015] = TRADE
-- 5016 quest item no quest references; 5017 ordinary item no quest references
ItemClass[5016] = QUEST
ItemClass[5017] = TRADE
-- 5018 linked only through ItemDB.relatedQuests
Quests[1018] = { name = "Related Only" }
Items[5018] = { relatedQuests = { 1018 } }
ItemClass[5018] = QUEST
-- 5019 used for a spell objective
Quests[1019] = { name = "Use On Target", objectives = { nil, nil, nil, nil, nil, { { 999, "Use", 5019 } } } }
ItemClass[5019] = QUEST
ItemClass[16309] = QUEST -- Drakefire Amulet

Completed[1001], Completed[1002], Completed[1003], Completed[16], Completed[1005] = true, true, true, true, true
Completed[1010], Completed[1012], Completed[1014], Completed[1016], Completed[1018] = true, true, true, true, true

-- ---------------------------------------------------------------- lifecycle

check("no tooltip hook before login", TooltipCallbacks[Enum.TooltipDataType.Item], nil)
FireEvent("ADDON_LOADED", "KroolWorldForever")
local DB = KroolWorldForeverDB.features.questtrash
check("defaults applied", DB.tooltip, true)
check("enabled by default", DB.enabled, true)
FireEvent("PLAYER_LOGIN")
check("tooltip hook registered at login", type(TooltipCallbacks[Enum.TooltipDataType.Item]), "function")
check("background scan started", #Tickers, 1)

-- before the quest scan finishes, nothing may be called deletable
check("pending before scan: completed objective item", FQT.GetVerdict(5001), "pending")
check("pending tooltip wording", has(HoverItem(5001), "Checking quest data"), true)
check("active verdict needs no scan", (function()
	QuestLog[1018] = true
	FQT.ClearCache()
	local v = FQT.GetVerdict(5018)
	QuestLog[1018] = nil
	FQT.ClearCache()
	return v
end)(), "active")

RunTickers()
check("scan finished", QT.scan.done, true)
check("scan covered every quest", QT.scan.position, QT.scan.total)

-- ---------------------------------------------------------------- verdicts

check("completed one-time quest -> safe", FQT.GetVerdict(5001), "safe")
check("safe quest item says Can be deleted", has(HoverItem(5001), "Can be deleted"), true)
check("repeatable specialFlags -> farm", FQT.GetVerdict(5002), "farm")
check("daily questFlags -> farm", FQT.GetVerdict(5003), "farm")
check("extra repeatable list -> farm", FQT.GetVerdict(5004), "farm")
check("holiday sort -> farm", FQT.GetVerdict(5005), "farm")
check("other race quest -> notyours", FQT.GetVerdict(5006), "notyours")
check("notyours wording is honest", has(HoverItem(5006), "race/class-locked"), true)
check("other class quest -> notyours", FQT.GetVerdict(5007), "notyours")
check("mask above 32 bits keeps Human eligible", FQT.GetVerdict(5008), "maybe")
check("exclusive variant closed by the other -> safe", FQT.GetVerdict(5009), "safe")
check("breadcrumb to a done quest -> safe", FQT.GetVerdict(5011), "safe")
check("provided item, quest not taken -> maybe", FQT.GetVerdict(5013), "maybe")
check("done + open links -> maybe (most protective)", FQT.GetVerdict(5014), "maybe")
check("tradable item never told delete", has(HoverItem(5015), "sell or AH"), true)
check("tradable item no Can be deleted", has(HoverItem(5015), "Can be deleted"), false)
check("unlinked quest item -> unknown", FQT.GetVerdict(5016), "unknown")
check("unlinked ordinary item -> no verdict", FQT.GetVerdict(5017), nil)
check("ordinary item tooltip untouched", #HoverItem(5017), 0)
check("relatedQuests link counts", FQT.GetVerdict(5018), "safe")
check("spell objective item is linked", FQT.GetVerdict(5019), "maybe")
check("never-delete list wins", FQT.GetVerdict(16309), "keep")

-- ---------------------------------------------------------------- state changes

QuestLog[1013] = true
FireEvent("QUEST_LOG_UPDATE")
check("accepting the quest -> active", FQT.GetVerdict(5013), "active")
QuestLog[1013] = nil
Completed[1013] = true
FireEvent("QUEST_TURNED_IN", 1013)
check("turning it in -> safe", FQT.GetVerdict(5013), "safe")

Player.raceID = 95 -- Alliance Skyborne: race masks not trusted yet
FQT.InitPlayer()
FQT.ClearCache()
check("Skyborne skips race test (keeps item)", FQT.GetVerdict(5006), "maybe")
Player.raceID = 1
FQT.InitPlayer()
FQT.ClearCache()

check("HasBit high bit", FQT._HasBit(8589934592 + 4294967296, 4294967296), true)
check("HasBit absent bit", FQT._HasBit(8589934592, 4294967296), false)
check("HasBit zero mask", FQT._HasBit(0, 1), false)

-- ---------------------------------------------------------------- tooltip robustness

DB.questList = false
check("quest list off -> one line", #HoverItem(5001), 1)
DB.questList = true
check("quest list on -> verdict + quest", #HoverItem(5001), 2)

issecretvalue = function(v)
	return v == 5001
end
check("secret item id -> no lines", #HoverItem(5001), 0)
issecretvalue = nil

local otherTip = { lines = {}, AddLine = GameTooltip.AddLine }
TooltipCallbacks[Enum.TooltipDataType.Item](otherTip, { id = 5001 })
check("other tooltip frames ignored", #otherTip.lines, 0)

local realGetAll = QuestDB.GetAll
QuestDB.GetAll = function()
	error("provider blew up")
end
FQT.ClearCache()
local okHover = pcall(HoverItem, 5001)
check("provider error degrades silently", okHover, true)
QuestDB.GetAll = realGetAll
FQT.ClearCache()

DB.tooltip = false
check("tooltip toggle off", #HoverItem(5001), 0)
DB.tooltip = true

-- ---------------------------------------------------------------- scan / slash / provider

Bags[0] = { 5001, 5002, 5017 }
local printed, realPrint = {}, print
print = function(s)
	printed[#printed + 1] = s
end
SlashCmdList.KROOLWORLDFOREVER_QUESTTRASH("")
print = realPrint
check("scan lists the deletable item", has(printed, "Item5001"), true)
check("scan groups it under Deletable", has(printed, "Deletable"), true)
check("scan lists the repeatable item as keep", has(printed, "Repeatable/seasonal demand"), true)
check("scan skips items with no verdict", has(printed, "Item5017"), false)

local realLib = LibQuestieDB
LibQuestieDB = nil
check("missing provider reported", select(1, FQT.ProviderStatus()), false)
LibQuestieDB = realLib
realLib.contractVersion = 3
check("old contract rejected", select(1, FQT.ProviderStatus()), false)
realLib.contractVersion = 4

-- ---------------------------------------------------------------- bundle on/off switch

local function Capture(fn)
	local out, real = {}, print
	print = function(s)
		out[#out + 1] = s
	end
	fn()
	print = real
	return out
end

check("enabled after login", QT.enabled, true)
SlashCmdList.KROOLWORLDFOREVER("questtrash off")
check("/kwf questtrash off disables", QT.enabled, false)
check("off state is saved", DB.enabled, false)
check("disabled feature adds no tooltip lines", #HoverItem(5001), 0)
check("feature slash says it is off", has(Capture(function()
	SlashCmdList.KROOLWORLDFOREVER_QUESTTRASH("")
end), "is off"), true)
SettingsSet("KroolWorldForever_questtrash_enabled", true)
check("settings checkbox turns it back on", QT.enabled, true)
check("tooltip works again", has(HoverItem(5001), "Can be deleted"), true)
check("/kwf list names the feature", has(Capture(function()
	SlashCmdList.KROOLWORLDFOREVER("list")
end), "Quest Trash"), true)
SlashCmdList.KROOLWORLDFOREVER("questtrash")
check("/kwf <feature> opens its settings page", OpenedCategory, "Quest Trash")
SettingsSet("KroolWorldForever_questtrash_questList", false)
check("option checkbox writes the feature slice", DB.questList, false)
check("option takes effect", #HoverItem(5001), 1)
DB.questList = true

print(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
