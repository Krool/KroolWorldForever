local _, root = ...
local ns = root.Feature("questtrash")
local FQT = ns.FQT

local function Print(msg)
	ns:Print(msg)
end

-- -------------------------------------------------------------------- text

local ROLE_TEXT = {
	start = "starts",
	obj = "needed for",
	use = "used in",
	req = "used in",
	prov = "given by",
	related = "linked to",
}

local STATE_COLOR = {
	active = "|cff33ff99",
	["repeat"] = "|cff88bbff",
	event = "|cff88bbff",
	done = "|cffff5555",
	never = "|cff888888",
	closed = "|cff888888",
	open = "|cffffcc00",
}

local STATE_TEXT = {
	active = "in your log",
	["repeat"] = "repeatable",
	event = "seasonal",
	done = "completed",
	never = "not for your race/class",
	closed = "closed by an alternate version",
	open = "not done yet",
}

local VERDICT_LINE = {
	active = "|cff33ff99Keep - needed for an active quest|r",
	farm = "|cff88bbffKeep - a repeatable/seasonal quest wants this|r",
	maybe = "|cffffcc00Keep - a quest still wants this|r",
	keep = "|cff33ff99Keep - key/attunement item|r",
	pending = "|cffaaaaaaChecking quest data... keep for now|r",
	unknown = "|cffaaaaaaNo quest data - keep to be safe|r",
}

-- Deletion advice only applies to true quest items; anything else (tradable mats,
-- class-locked drops, keys) gets sell/AH wording instead of "delete".
local function VerdictLine(verdict, itemID)
	if verdict ~= "safe" and verdict ~= "notyours" then
		return VERDICT_LINE[verdict]
	end
	local reason = verdict == "safe" and "quests completed" or "only race/class-locked quests use it"
	local isQuest = FQT.IsQuestItem(itemID)
	if isQuest then
		return "|cffff5555Can be deleted|r |cffaaaaaa(" .. reason .. ")|r"
	end
	local head = verdict == "safe" and "No quest needs this anymore" or "No use to you"
	if isQuest == nil then
		return "|cffff9955" .. head .. "|r |cffaaaaaa(item not cached yet - hover again)|r"
	end
	return "|cffff9955" .. head .. "|r |cffaaaaaa(tradable - sell or AH it)|r"
end

local function Annotate(tooltip, itemID)
	local verdict, links = FQT.GetVerdict(itemID)
	if not verdict then
		return
	end
	tooltip:AddLine(VerdictLine(verdict, itemID))
	if not ns.db.questList then
		return
	end

	-- A closed variant sharing its title with another listed quest is the same quest to
	-- the player: list it once, under the real state.
	local titles = {}
	for _, link in ipairs(links) do
		if link[3] ~= "closed" then
			titles[FQT.QuestName(link[1])] = true
		end
	end
	local lines, seen = {}, {}
	for _, link in ipairs(links) do
		local name = FQT.QuestName(link[1])
		local key = name .. "|" .. link[3]
		if not ((link[3] == "closed" and titles[name]) or seen[key]) then
			seen[key] = true
			lines[#lines + 1] = link
		end
	end
	for i, link in ipairs(lines) do
		if i > 4 then
			tooltip:AddLine("|cffaaaaaa  ...and " .. (#lines - 4) .. " more|r")
			break
		end
		local qid, role, state = link[1], link[2], link[3]
		tooltip:AddLine(
			"|cffaaaaaa  "
				.. ROLE_TEXT[role]
				.. "|r "
				.. FQT.QuestName(qid)
				.. " "
				.. STATE_COLOR[state]
				.. "("
				.. STATE_TEXT[state]
				.. ")|r"
		)
	end
end

-- Runs on every item tooltip; any failure must degrade to "no line", never an error popup.
local function OnItemTooltip(tooltip, data)
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
		return
	end
	if not (ns.enabled and ns.ready and ns.db.tooltip) then
		return
	end
	local itemID = data and data.id
	if not itemID or (issecretvalue and issecretvalue(itemID)) then
		return
	end
	pcall(Annotate, tooltip, itemID)
end
ns.OnItemTooltip = OnItemTooltip -- test seam

-- -------------------------------------------------------------------- scan

local VERDICT_HEAD = {
	safe = "|cffff5555Deletable / no longer needed:|r",
	notyours = "|cffff9955Race/class-locked (no use to you):|r",
	farm = "|cff88bbffRepeatable/seasonal demand (keep):|r",
	maybe = "|cffffcc00Quest not done yet (keep):|r",
	pending = "|cffaaaaaaStill checking (keep for now):|r",
	unknown = "|cffaaaaaaQuest items with no data (keep):|r",
}
local SCAN_ORDER = { "safe", "notyours", "farm", "maybe", "pending", "unknown" }

local bankOpen = false

local function ContainersToScan()
	local bags = {}
	local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	for bag = 0, last do
		bags[#bags + 1] = bag
	end
	if bankOpen and Enum.BagIndex then
		-- Bank containers differ between client generations (bank bags vs bank tabs);
		-- take every BagIndex whose name says Bank and let empty ones fall out.
		for name, index in pairs(Enum.BagIndex) do
			if name:find("Bank") and not name:find("Account") then
				bags[#bags + 1] = index
			end
		end
	end
	return bags
end

function FQT.Scan()
	local groups = {}
	for _, key in ipairs(SCAN_ORDER) do
		groups[key] = {}
	end
	local seen = {}
	for _, bag in ipairs(ContainersToScan()) do
		local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
		for slot = 1, (ok and slots or 0) do
			local itemID = C_Container.GetContainerItemID(bag, slot)
			if itemID and not seen[itemID] then
				seen[itemID] = true
				local verdict, links = FQT.GetVerdict(itemID)
				if verdict and groups[verdict] then
					local name = C_Item.GetItemNameByID(itemID) or ItemDB.name(itemID) or ("item #" .. itemID)
					local why = links[1] and (" |cffaaaaaa- " .. FQT.QuestName(links[1][1]) .. "|r") or ""
					table.insert(groups[verdict], "  " .. name .. why)
				end
			end
		end
	end
	local total = 0
	for _, key in ipairs(SCAN_ORDER) do
		if #groups[key] > 0 then
			Print(VERDICT_HEAD[key])
			for _, line in ipairs(groups[key]) do
				print(line)
				total = total + 1
			end
		end
	end
	if total == 0 then
		Print("no quest items needing a verdict in your bags" .. (bankOpen and " or bank." or "."))
	elseif not bankOpen then
		Print("|cffaaaaaaopen your bank and run /fqt again to include it.|r")
	end
end

local function Status()
	local ok, info = FQT.ProviderStatus()
	if not ok then
		Print("|cffff5555" .. info .. "|r Verdicts are off.")
		return
	end
	local s = ns.scan
	Print(
		("QuestieDB %s mode, contract ok. Quest index: %s (%d/%d)."):format(
			tostring(info),
			s.done and "ready" or "building",
			s.position,
			s.total
		)
	)
end


-- -------------------------------------------------------------------- definition

ns.title = "Quest Trash"
ns.description = "Marks quest items you can safely delete on their tooltips. Needs QuestieDB."
ns.options = {
	{
		key = "tooltip",
		type = "toggle",
		label = "Show Verdict on Tooltips",
		tooltip = "Adds a keep or delete line to quest item tooltips.",
		default = true,
	},
	{
		key = "questList",
		type = "toggle",
		label = "List the Quests Involved",
		tooltip = "Shows up to four quests and their status under the verdict.",
		default = true,
	},
}
ns.slash = { "/fqt", "/questtrash" }

function ns.OnSlash(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "status" then
		Status()
	elseif msg == "options" or msg == "config" then
		root.OpenSettings(ns)
	elseif msg == "help" then
		Print("/fqt - scan bags (and bank when open); /fqt status; /fqt options")
	elseif not ns.ready then
		Status()
	else
		FQT.Scan()
	end
end

-- -------------------------------------------------------------------- lifecycle

local function StartBackgroundScan()
	local ticker
	ticker = C_Timer.NewTicker(0, function()
		local ok, done = pcall(FQT.ScanStep)
		if not ok then
			ticker:Cancel()
			Print("|cffff5555quest index failed|r: " .. tostring(done))
		elseif done then
			ticker:Cancel()
		end
	end)
end

-- Tooltip hooks cannot be removed, so they are added once and check ns.enabled each time.
function ns.OnEnable()
	if ns.ready then
		return
	end
	local ok, info = FQT.ProviderStatus()
	if not ok then
		Print("|cffff5555" .. info .. "|r Verdicts are off.")
		return
	end
	FQT.InitPlayer()
	ns.ready = true
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
	StartBackgroundScan()
end

local function ClearCache()
	FQT.ClearCache()
end
ns:RegisterEvent("QUEST_LOG_UPDATE", ClearCache)
ns:RegisterEvent("QUEST_TURNED_IN", ClearCache)
ns:RegisterEvent("BANKFRAME_OPENED", function()
	bankOpen = true
end)
ns:RegisterEvent("BANKFRAME_CLOSED", function()
	bankOpen = false
end)
