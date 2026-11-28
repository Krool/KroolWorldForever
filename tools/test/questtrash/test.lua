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
-- 16 is on the cmangos extra-repeatable list, item 5004
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

-- Closed for good. 1020 is capped at level 10 (the player is 20): item 5020
Quests[1020] = { name = "Low Cap", requiredMaxLevel = 10, objectives = { nil, nil, { { 5020 } } } }
ItemClass[5020] = QUEST
-- 1021 is offered until 1022 is done, and it is: item 5021
Quests[1021] = { name = "Window Shut", availableUntilCompleted = 1022, objectives = { nil, nil, { { 5021 } } } }
Quests[1022] = { name = "Window Closer" }
ItemClass[5021] = QUEST
-- 1023 needs 1009, closed by its done variant 1010: item 5023
Quests[1023] = { name = "Lost Branch", preQuestGroup = { 1009 }, objectives = { nil, nil, { { 5023 } } } }
ItemClass[5023] = QUEST
-- 1024 needs one of 1009 (closed) or 1011 (a breadcrumb whose target is done): item 5024
Quests[1024] = { name = "Both Doors Shut", preQuestSingle = { 1009, 1011 }, objectives = { nil, nil, { { 5024 } } } }
ItemClass[5024] = QUEST
-- 1025 needs one of 1009 (closed) or 1015 (open): item 5025
Quests[1025] = { name = "One Door Open", preQuestSingle = { 1009, 1015 }, objectives = { nil, nil, { { 5025 } } } }
ItemClass[5025] = QUEST
-- 1026 needs 1006, which is Orc only: a race lock on a prerequisite does not close it. Item 5026
Quests[1026] = { name = "After Orc Quest", preQuestGroup = { 1006 }, objectives = { nil, nil, { { 5026 } } } }
ItemClass[5026] = QUEST
-- 1027 and 1028 need each other (bad data): item 5027
Quests[1027] = { name = "Loop A", preQuestGroup = { 1028 }, objectives = { nil, nil, { { 5027 } } } }
Quests[1028] = { name = "Loop B", preQuestGroup = { 1027 } }
ItemClass[5027] = QUEST
-- 1029 needs 1031, which needs 1023 (closed): item 5029
Quests[1029] = { name = "Far Down The Chain", preQuestGroup = { 1031 }, objectives = { nil, nil, { { 5029 } } } }
Quests[1031] = { name = "Middle Step", preQuestGroup = { 1023 } }
ItemClass[5029] = QUEST
-- 5030 links only to a quest QuestieDB does not have
Items[5030] = { relatedQuests = { 9999 } }
ItemClass[5030] = QUEST
-- 5032 starts 1032 (done) by the client's word only: QuestieDB has no entry for the item
Quests[1032] = { name = "Client Start" }
ItemClass[5032] = QUEST
ClientStarts[5032] = 1032
-- 5040 a key (item class Key) whose only quest is done; 5043 a key whose quest is still open
Quests[1040] = { name = "Jail Break", objectives = { nil, nil, { { 5040 } } } }
ItemClass[5040] = 13
Quests[1043] = { name = "Locked Chest", objectives = { nil, nil, { { 5043 } } } }
ItemClass[5043] = 13
-- 5041 and 5042 are handed out by done quests and bind when picked up: one a vendor buys, one not
Quests[1041] = { name = "Borrowed Tool", sourceItemId = 5041 }
ItemClass[5041] = TRADE
ItemBind[5041] = 1
SellPrice[5041] = 250
Quests[1042] = { name = "Worthless Token", sourceItemId = 5042 }
ItemClass[5042] = TRADE
ItemBind[5042] = 1
-- 5044 a trade good of a done quest whose details the client has not loaded
Quests[1044] = { name = "Uncached Mat", objectives = { nil, nil, { { 5044 } } } }
ItemClass[5044] = TRADE
NoItemInfo[5044] = true
-- Open quests that ask something of the player (level 20): 1050 a level 14 quest, 1051 opens at
-- level 30, 1052 needs Engineering 150, 1053 needs Timbermaw Hold reputation
Quests[1050] = { name = "Skipped Long Ago", questLevel = 14, requiredLevel = 10, objectives = { nil, nil, { { 5050 } } } }
ItemClass[5050] = QUEST
Quests[1051] = { name = "Still Ahead", questLevel = 32, requiredLevel = 30, objectives = { nil, nil, { { 5051 } } } }
ItemClass[5051] = QUEST
Quests[1052] = { name = "Gnomish Gadget", questLevel = 30, requiredSkill = { 202, 150 }, objectives = { nil, nil, { { 5052 } } } }
ItemClass[5052] = QUEST
Quests[1053] = { name = "Furbolg Friend", requiredMinRep = { 576, 3000 }, objectives = { nil, nil, { { 5053 } } } }
ItemClass[5053] = QUEST
-- 1060 is turned in during the test: 5060 its quest item, 5061 a trade good it used.
-- 1061 is offered only until 1060 is done: its item 5062 closes with the same turn-in.
Quests[1060] = { name = "Hand It In", objectives = { nil, nil, { { 5060 }, { 5061 } } } }
ItemClass[5060] = QUEST
ItemClass[5061] = TRADE
Quests[1061] = { name = "Other Road", availableUntilCompleted = 1060, objectives = { nil, nil, { { 5062 } } } }
ItemClass[5062] = QUEST

Completed[1001], Completed[1002], Completed[1003], Completed[16], Completed[1005] = true, true, true, true, true
Completed[1010], Completed[1012], Completed[1014], Completed[1016], Completed[1018] = true, true, true, true, true
Completed[1022], Completed[1032] = true, true
Completed[1040], Completed[1041], Completed[1042], Completed[1044] = true, true, true, true

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
check("never-delete list: its own wording", has(HoverItem(16309), "key/attunement item"), true)

-- ---------------------------------------------------------------- keys and what else no quest needs

check("a key whose quests are done -> keep", FQT.GetVerdict(5040), "keep")
check("a key is never told to sell or delete", has(HoverItem(5040), "sell or AH") or has(HoverItem(5040), "Can be deleted"), false)
check("a key says why it is kept", has(HoverItem(5040), "Keep - a key"), true)
check("a key still lists its quest", has(HoverItem(5040), "Jail Break"), true)
check("a key with an open quest keeps that verdict", FQT.GetVerdict(5043), "maybe")
check("advice: a quest item", FQT.Advice(5001), "delete")
check("advice: a trade good", FQT.Advice(5015), "trade")
check("advice: soulbound with a vendor price", FQT.Advice(5041), "vendor")
check("advice: the vendor price comes with it", select(2, FQT.Advice(5041)), 250)
check("advice: soulbound, no vendor price", FQT.Advice(5042), "bound")
check("advice: details not loaded", FQT.Advice(5044), "wait")
check("advice: class not loaded", FQT.Advice(599999), "wait")
check("a soulbound item is not called tradable", has(HoverItem(5041), "tradable"), false)
check("a soulbound item a vendor buys says so", has(HoverItem(5041), "soulbound - a vendor pays"), true)
check("with the price", has(HoverItem(5041), "2s"), true)
check("a soulbound item no vendor buys says so", has(HoverItem(5042), "soulbound, no vendor value"), true)
check("a soulbound item is never told delete", has(HoverItem(5042), "Can be deleted"), false)
check("details not loaded: hover again", has(HoverItem(5044), "not cached yet"), true)

-- ---------------------------------------------------------------- what an open quest asks

check("an open quest says its level", has(HoverItem(5050), "not done yet: level 14"), true)
check("a quest above you says when it opens", has(HoverItem(5051), "not done yet: from level 30"), true)
check("a profession you lack is named with its rank", has(HoverItem(5052), "level 30, needs Engineering 150"), true)
SkillRanks[202] = 120
check("a rank too low still says so", has(HoverItem(5052), "needs Engineering 150"), true)
SkillRanks[202] = 200
check("a profession you have is not mentioned", has(HoverItem(5052), "needs Engineering"), false)
SkillRanks[202] = nil
check("a reputation you lack is named", has(HoverItem(5053), "needs Timbermaw Hold reputation"), true)
Factions[576].currentStanding = 3000
check("a reputation you have is not mentioned", has(HoverItem(5053), "Timbermaw"), false)
Factions[576].currentStanding = 0
check("the notes never change a verdict", FQT.GetVerdict(5052), "maybe")
check("a quest with nothing to note reads as before", has(HoverItem(5014), "(not done yet)"), true)
check("a done quest gets no notes", has(HoverItem(5001), "level"), false)

-- ---------------------------------------------------------------- closed for good

check("over the level cap -> safe", FQT.GetVerdict(5020), "safe")
check("level cap reason on the tooltip", has(HoverItem(5020), "over its level cap"), true)
check("closed-only item: closed wording", has(HoverItem(5020), "quests closed to you"), true)
Player.level = 10
FQT.ClearCache()
check("at the level cap -> maybe", FQT.GetVerdict(5020), "maybe")
Player.level = 11
FireEvent("PLAYER_LEVEL_UP", 11)
check("levelling past the cap rechecks -> safe", FQT.GetVerdict(5020), "safe")
Player.level = 20
FQT.ClearCache()
check("its window ended -> safe", FQT.GetVerdict(5021), "safe")
check("window reason on the tooltip", has(HoverItem(5021), "no longer offered"), true)
check("a quest it needs is closed -> safe", FQT.GetVerdict(5023), "safe")
check("prerequisite reason on the tooltip", has(HoverItem(5023), "a quest it needs is closed"), true)
check("every alternative prerequisite closed -> safe", FQT.GetVerdict(5024), "safe")
check("one alternative still open -> maybe", FQT.GetVerdict(5025), "maybe")
check("a race-locked prerequisite does not close it", FQT.GetVerdict(5026), "maybe")
check("a prerequisite loop stays open", FQT.GetVerdict(5027), "maybe")
check("a closed quest two steps up the chain -> safe", FQT.GetVerdict(5029), "safe")
check("breadcrumb reason on the tooltip", has(HoverItem(5011), "you took the quest it leads to"), true)
check("done and closed variants: mixed wording", has(HoverItem(5009), "quests completed or closed"), true)
check("a quest QuestieDB lacks -> unknown", FQT.GetVerdict(5030), "unknown")
check("a quest QuestieDB lacks says so", has(HoverItem(5030), "not in QuestieDB"), true)

-- The client's own "starts a quest" flag, read from the bag slot.
check("client-only starter before a bag read -> unknown", FQT.GetVerdict(5032), "unknown")
Bags[0] = { 5032 }
FQT.Collect()
check("client-only starter, quest done -> safe after a bag read", FQT.GetVerdict(5032), "safe")
check("client-only starter names its quest", has(HoverItem(5032), "Client Start"), true)
Bags[0] = nil

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
SlashCmdList.KROOLWORLDFOREVER_QUESTTRASH("print")
print = realPrint
check("/fqt print lists the deletable item", has(printed, "Item5001"), true)
check("scan groups it under Deletable", has(printed, "Deletable"), true)
check("scan lists the repeatable item as keep", has(printed, "Repeatable/seasonal demand"), true)
check("scan skips items with no verdict", has(printed, "Item5017"), false)

-- ---------------------------------------------------------------- the window

Bags[0] = { 5001, 5002, 5017, 5001, 5014 }
Stacks[5001] = 3
SlashCmdList.KROOLWORLDFOREVER_QUESTTRASH("")
local win = QT.WindowFrame()
check("/fqt opens the window", win ~= nil and win:IsShown(), true)
local function rowsShown()
	local out = {}
	for _, r in ipairs(win.rows) do
		if r.shown then
			out[#out + 1] = r
		end
	end
	return out
end
local function headersShown()
	local out = {}
	for gi = 1, 4 do -- by group: one never shown has no header yet
		local h = win.headers[gi]
		if h and h.shown then
			out[#out + 1] = h.text
		end
	end
	return out
end
local rows = rowsShown()
check("one row per distinct item with a verdict", #rows, 3)
check("deletable group first", headersShown()[1], "Can Delete (1)")
check("keep group", headersShown()[2], "Keep (2)")
check("stacks across slots are summed", rows[1].name.text:find("x6", 1, true) ~= nil, true)
check("deletable row says why", rows[1].why.text, "Quests done")
check("banner counts what you can delete", win.banner.text:find("1 item you can delete", 1, true) ~= nil, true)
check("note says the bank is not included", win.note.text:find("Open your bank", 1, true) ~= nil, true)
-- polish
check("polish: the window has its intro animation (played on show; see the setups suite)", #AnimationsOn(win) >= 1, true)
check("polish: rows fade in when the window opens", (AnimationsOn(rows[1])[1] or {}).plays, 1)
check("polish: Can Delete has the red X", win.headers[1].icon.atlas, "groupfinder-icon-redx")
check("polish: Keep has the check mark", win.headers[3].icon.atlas, "common-icon-checkmark")
check("polish: headers carry a divider", win.headers[1].line.shown, true)
win.refresh:Click()
local toast = __ns.UI.ToastOf(win)
check("polish: Refresh says what it found", toast and toast.text.text, "Rechecked: 1 to delete")
check("polish: as a warning while something can go", toast and toast.kind, "warn")
FinishAnimations()
check("polish: the toast fades away by itself", toast.shown, false)
rows = rowsShown()
GameTooltip.lines = {}
rows[1].scripts.OnEnter(rows[1])
check("hovering a row shows the item tooltip", GameTooltip.item, 5001)
check("with the verdict from the tooltip hook", has(GameTooltip.lines, "Can be deleted"), true)

FireEvent("BANKFRAME_OPENED")
check("opening the bank refreshes the window", win.note.text, "Bags and bank.")
Bags[-1] = { 5003 }
FireEvent("BAG_UPDATE_DELAYED")
check("bag changes refresh it", #rowsShown(), 4)
FireEvent("BANKFRAME_CLOSED")
Bags[-1] = nil
check("closing the bank drops bank items", #rowsShown(), 3)

Bags[0] = { 5017 }
FireEvent("BAG_UPDATE_DELAYED")
check("nothing to sort: empty text", win.empty.shown, true)
check("nothing to sort: banner", win.banner.text, "Nothing to sort.")
win:Hide()
Bags[0] = { 5001 }
FireEvent("BAG_UPDATE_DELAYED")
check("a closed window is not rebuilt", win.empty.shown, true)
Bags[0] = { 5021 }
QT.RefreshWindow(true)
check("a row for a closed quest says why", rowsShown()[1].why.text, "Quests closed")
Bags[0] = { 5001 }

check("hub status counts deletable items", QT.HubStatus():find("1 item you can delete", 1, true) ~= nil, true)
Bags[0] = {}
check("hub status when nothing to delete", QT.HubStatus():find("Nothing to delete", 1, true) ~= nil, true)
Bags[0] = { 5001, 5002, 5017 }
Stacks[5001] = nil

-- What no quest needs but is not a quest item has its own group: never under Can Delete.
Bags[0] = { 5001, 5015, 5041, 5042, 5040, 5002 }
QT.RefreshWindow(true)
check("four groups: delete, no quest needs it, keep", table.concat(headersShown(), " | "), "Can Delete (1) | No Quest Needs It (3) | Keep (2)")
check("the new group has the junk coin", win.headers[2].icon.atlas, "bags-junkcoin")
local function whyOf(name)
	for _, r in ipairs(rowsShown()) do
		if r.name.text:find(name, 1, true) then
			return r.why.text
		end
	end
	return nil
end
check("a trade good: sell or trade", whyOf("Item5015"), "Sell or trade")
check("a soulbound item with a price: vendor", whyOf("Item5041"):find("Vendor: ", 1, true) ~= nil, true)
check("a soulbound item without: says so", whyOf("Item5042"), "Soulbound, no value")
check("a key is under Keep", whyOf("Item5040"), "A key")
check("the banner counts quest items only", win.banner.text:find("1 item you can delete", 1, true) ~= nil, true)
check("the hub counts quest items only", QT.HubStatus():find("1 item you can delete", 1, true) ~= nil, true)
Bags[0] = { 5015, 5041 }
QT.RefreshWindow(true)
check("nothing to delete, two to sell: the banner", win.banner.text:find("Nothing to delete.|r 2 no quest needs", 1, true) ~= nil, true)
check("nothing to delete, two to sell: the hub", QT.HubStatus():find("2 items no quest needs", 1, true) ~= nil, true)
check("a header of an emptied group is hidden", table.concat(headersShown(), " | "), "No Quest Needs It (2)")
Bags[0] = { 5002 }
QT.RefreshWindow(true)
check("only Keep left: the other headers are gone", table.concat(headersShown(), " | "), "Keep (1)")
local listed = {}
do
	local real = print
	print = function(s)
		listed[#listed + 1] = s
	end
	Bags[0] = { 5001, 5015 }
	SlashCmdList.KROOLWORLDFOREVER_QUESTTRASH("print")
	print = real
end
check("/fqt print: the trade good is not under Deletable", has(listed, "No quest needs these"), true)

-- ---------------------------------------------------------------- after a turn-in

local function Told(fn)
	local out, real = {}, print
	print = function(s)
		out[#out + 1] = s
	end
	fn()
	print = real
	return out
end
RunAfters() -- the turn-ins fired above
Bags[0] = { 5001, 5060, 5061, 5062, 5002 }
QuestLog[1060] = true
FQT.ClearCache()
FQT.Baseline() -- as at login: 5001 is old junk and is not announced
check("before the turn-in its item is kept", FQT.GetVerdict(5060), "active")
QuestLog[1060] = nil
Completed[1060] = true
local told = Told(function()
	FireEvent("QUEST_TURNED_IN", 1060)
end)
check("nothing is said at the event itself", #told, 0)
check("it waits a moment for the client", #Afters, 1)
FireEvent("QUEST_TURNED_IN", 1060)
check("a second turn-in in that moment asks once", #Afters, 1)
told = Told(RunAfters)
check("after a turn-in: the quest item can go", has(told, "Can be deleted now:"), true)
check("it names the item", has(told, "Item5060"), true)
check("an item of a quest the turn-in closed is named too", has(told, "Item5062"), true)
check("a trade good is not told delete", has(told, "No quest needs these now:|r Item5061"), true)
check("old junk is not announced again", has(told, "Item5001"), false)
check("two lines, no more", #told, 2)
FireEvent("QUEST_TURNED_IN", 1060)
check("the same items are not announced twice", #Told(RunAfters), 0)
DB.turnIn = false
Completed[1050] = true
Bags[0] = { 5050 }
FireEvent("QUEST_TURNED_IN", 1050)
check("the option off: nothing is said", #Told(RunAfters), 0)
DB.turnIn = true
FireEvent("QUEST_TURNED_IN", 1050)
check("turned on again: what was passed over stays quiet", #Told(RunAfters), 0)
Completed[1050], Completed[1060] = nil, nil
Bags[0] = { 5001, 5002, 5017 }
FQT.ClearCache()

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
check("open quest item before turning off", FQT.GetVerdict(5019), "maybe")
SlashCmdList.KROOLWORLDFOREVER("questtrash off")
check("/kwf questtrash off disables", QT.enabled, false)
Completed[1019] = true
FireEvent("QUEST_TURNED_IN", 1019) -- not delivered: events reach a feature only while it is on
check("off state is saved", DB.enabled, false)
check("disabled feature adds no tooltip lines", #HoverItem(5001), 0)
check("feature slash says it is off", has(Capture(function()
	SlashCmdList.KROOLWORLDFOREVER_QUESTTRASH("")
end), "is off"), true)
SettingsSet("KroolWorldForever_questtrash_enabled", true)
check("settings checkbox turns it back on", QT.enabled, true)
check("tooltip works again", has(HoverItem(5001), "Can be deleted"), true)
check("a quest turned in while off is seen after turning back on", FQT.GetVerdict(5019), "safe")
Completed[1019] = nil
FQT.ClearCache()
check("/kwf list names the feature", has(Capture(function()
	SlashCmdList.KROOLWORLDFOREVER("list")
end), "Quest Trash"), true)
QT.WindowFrame():Hide()
SlashCmdList.KROOLWORLDFOREVER("questtrash")
check("/kw questtrash opens its window", QT.WindowFrame():IsShown(), true)
SlashCmdList.KROOLWORLDFOREVER_QUESTTRASH("options")
check("/fqt options opens its settings page", OpenedCategory, "Quest Trash")
SettingsSet("KroolWorldForever_questtrash_questList", false)
check("option checkbox writes the feature slice", DB.questList, false)
check("option takes effect", #HoverItem(5001), 1)
DB.questList = true

print(("%d checks, %d failed"):format(count, failures))
if failures > 0 then
	error(failures .. " check(s) failed")
end
