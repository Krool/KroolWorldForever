local _, root = ...
local ns = root.Feature("questtrash")
local FQT = ns.FQT

local function Print(msg)
	ns:Print(msg)
end

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
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
	nodata = "|cffaaaaaa",
	open = "|cffffcc00",
}

local STATE_TEXT = {
	active = "in your log",
	["repeat"] = "repeatable",
	event = "seasonal",
	done = "completed",
	never = "not for your race/class",
	closed = "closed to you",
	nodata = "not in QuestieDB",
	open = "not done yet",
}

-- What closed a quest, for its line under the verdict.
local CLOSED_TEXT = {
	exclusive = "closed: you did another version",
	breadcrumb = "closed: you took the quest it leads to",
	expired = "no longer offered to you",
	maxlevel = "closed: you are over its level cap",
	prereq = "closed: a quest it needs is closed",
}

-- "done", "closed" or "mixed": what made a safe item safe.
function FQT.SafeReason(links)
	local done, closed = false, false
	for _, link in ipairs(links or {}) do
		done = done or link[3] == "done"
		closed = closed or link[3] == "closed"
	end
	if closed and not done then
		return "closed"
	end
	return closed and "mixed" or "done"
end

local VERDICT_LINE = {
	active = "|cff33ff99Keep - needed for an active quest|r",
	farm = "|cff88bbffKeep - a repeatable/seasonal quest wants this|r",
	maybe = "|cffffcc00Keep - a quest still wants this|r",
	keep = "|cff33ff99Keep - key/attunement item|r",
	pending = "|cffaaaaaaChecking quest data... keep for now|r",
	unknown = "|cffaaaaaaNo quest data - keep to be safe|r",
}
-- A key whose quests are over (it comes with its quest links; the never-delete list has none).
local KEY_LINE = "|cff33ff99Keep - a key|r |cffaaaaaa(its quests are over, but it may still open a lock)|r"

-- Deletion advice only applies to true quest items. Anything else no quest needs is told what the
-- client knows of it: tradable, or bound to you with or without a vendor price.
local SAFE_REASON = { done = "quests completed", closed = "quests closed to you", mixed = "quests completed or closed" }

local function VerdictLine(verdict, itemID, links)
	if verdict == "keep" and links and #links > 0 then
		return KEY_LINE
	end
	if verdict ~= "safe" and verdict ~= "notyours" then
		return VERDICT_LINE[verdict]
	end
	local reason = verdict == "safe" and SAFE_REASON[FQT.SafeReason(links)] or "only race/class-locked quests use it"
	local advice, price = FQT.Advice(itemID)
	if advice == "delete" then
		return "|cffff5555Can be deleted|r |cffaaaaaa(" .. reason .. ")|r"
	end
	local head = "|cffff9955" .. (verdict == "safe" and "No quest needs this anymore" or "No use to you") .. "|r |cffaaaaaa("
	if advice == "trade" then
		return head .. "tradable - sell or AH it)|r"
	elseif advice == "vendor" then
		return head .. "soulbound - a vendor pays|r " .. root.Money(price) .. "|cffaaaaaa)|r"
	elseif advice == "bound" then
		return head .. "soulbound, no vendor value)|r"
	end
	return head .. "item not cached yet - hover again)|r"
end

-- The words after a quest's name: its state, and for a quest not done yet what it asks of you.
local function StateText(qid, state, why)
	if state == "closed" then
		return CLOSED_TEXT[why]
	end
	local text = STATE_TEXT[state]
	if state == "open" then
		local notes = FQT.QuestNotes(qid)
		if #notes > 0 then
			text = text .. ": " .. table.concat(notes, ", ")
		end
	end
	return text
end

-- A bag slot's tooltip: learn the quest the client says the item starts.
local function LearnFromOwner(tooltip, itemID)
	local owner = tooltip.GetOwner and tooltip:GetOwner()
	if type(owner) ~= "table" or type(owner.GetBagID) ~= "function" or type(owner.GetID) ~= "function" then
		return
	end
	local okB, bag = pcall(owner.GetBagID, owner)
	local okS, slot = pcall(owner.GetID, owner)
	if not (okB and okS) or Secret(bag) or Secret(slot) then
		return
	end
	if type(bag) == "number" and type(slot) == "number" then
		FQT.LearnSlot(bag, slot, itemID)
	end
end

local function Annotate(tooltip, itemID)
	LearnFromOwner(tooltip, itemID)
	local verdict, links = FQT.GetVerdict(itemID)
	if not verdict then
		return
	end
	tooltip:AddLine(VerdictLine(verdict, itemID, links))
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
		local qid, role, state, why = link[1], link[2], link[3], link[4]
		local stateText = StateText(qid, state, why)
		tooltip:AddLine(
			"|cffaaaaaa  "
				.. ROLE_TEXT[role]
				.. "|r "
				.. FQT.QuestName(qid)
				.. " "
				.. STATE_COLOR[state]
				.. "("
				.. stateText
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
	-- Secret first: even a truth test on a secret value errors, and this runs outside TryQuiet.
	local itemID
	if type(data) == "table" then
		itemID = data.id
	end
	if (issecretvalue and issecretvalue(itemID)) or not itemID then
		return
	end
	root.TryQuiet(ns, "tooltip", Annotate, tooltip, itemID)
end
ns.OnItemTooltip = OnItemTooltip -- test seam

-- -------------------------------------------------------------------- scan

local VERDICT_HEAD = {
	delete = "|cffff5555Deletable quest items:|r",
	spare = "|cffff9955No quest needs these (sell, trade or keep):|r",
	farm = "|cff88bbffRepeatable/seasonal demand (keep):|r",
	maybe = "|cffffcc00Quest not done yet (keep):|r",
	pending = "|cffaaaaaaStill checking (keep for now):|r",
	unknown = "|cffaaaaaaQuest items with no data (keep):|r",
}
local SCAN_ORDER = { "delete", "spare", "farm", "maybe", "pending", "unknown" }

-- Where an item is listed: "delete" (a quest item no quest needs), "spare" (anything else no
-- quest needs), or its verdict.
function FQT.Group(e)
	if e.verdict == "safe" or e.verdict == "notyours" then
		return e.advice == "delete" and "delete" or "spare"
	end
	return e.verdict
end

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

function FQT.BankOpen()
	return bankOpen
end

-- Every distinct item in the bags (and the open bank) that has a verdict:
-- { { id, verdict, links, count, name, icon }, ... } in bag order.
function FQT.Collect()
	local list, byId = {}, {}
	for _, bag in ipairs(ContainersToScan()) do
		local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
		for slot = 1, (ok and slots or 0) do
			local itemID = C_Container.GetContainerItemID(bag, slot)
			if itemID then
				if byId[itemID] == nil then
					FQT.LearnSlot(bag, slot, itemID) -- before its verdict, which may need it
				end
				local e = byId[itemID]
				if e == nil then
					local verdict, links = FQT.GetVerdict(itemID)
					e = false
					if verdict then
						local name = C_Item.GetItemNameByID(itemID) or ItemDB.name(itemID) or ("item #" .. itemID)
						e = { id = itemID, verdict = verdict, links = links, count = 0, name = name }
						if verdict == "safe" or verdict == "notyours" then
							e.advice, e.price = FQT.Advice(itemID)
							end
						list[#list + 1] = e
					end
					byId[itemID] = e
				end
				if e then
					local okInfo, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
					info = okInfo and type(info) == "table" and info or nil
					e.count = e.count + (info and tonumber(info.stackCount) or 1)
					e.icon = e.icon or (info and info.iconFileID)
				end
			end
		end
	end
	return list
end

function FQT.Scan()
	local groups = {}
	for _, key in ipairs(SCAN_ORDER) do
		groups[key] = {}
	end
	for _, e in ipairs(FQT.Collect()) do
		local group = groups[FQT.Group(e)]
		if group then
			local why = e.links[1] and (" |cffaaaaaa- " .. FQT.QuestName(e.links[1][1]) .. "|r") or ""
			table.insert(group, "  " .. e.name .. why)
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
ns.icon = "Interface\\Icons\\INV_Misc_Note_01"
ns.blurb = "Which quest items you can delete"
ns.options = {
	{
		key = "tooltip",
		type = "toggle",
		label = "Show Verdict On Tooltips",
		tooltip = "Adds a keep or delete line to quest item tooltips.",
		default = true,
	},
	{
		key = "questList",
		type = "toggle",
		label = "List The Quests Involved",
		tooltip = "Shows up to four quests and their status under the verdict. A quest not done yet also says its level, and a profession or reputation it needs that you do not have.",
		default = true,
	},
	{
		key = "turnIn",
		type = "toggle",
		label = "Tell Me After A Turn-In",
		tooltip = "After you hand in a quest, says in chat which items in your bags no quest needs anymore.",
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
		Print("/fqt - the Quest Trash window (bags, and the bank while open); /fqt print - the same in chat; /fqt status; /fqt options")
	elseif msg == "print" or msg == "list" then
		if ns.ready then
			FQT.Scan()
		else
			Status()
		end
	else
		ns.OnOpen()
	end
end

-- The hub card: what is in the bags right now.
function ns.HubStatus()
	if not ns.ready then
		local ok, info = FQT.ProviderStatus()
		return ok and "|cffaaaaaaReading quest data...|r" or ("|cffff5555" .. tostring(info) .. "|r")
	end
	local n, spare = 0, 0
	for _, e in ipairs(FQT.Collect()) do
		local group = FQT.Group(e)
		if group == "delete" then
			n = n + 1
		elseif group == "spare" then
			spare = spare + 1
		end
	end
	if n > 0 then
		return ("|cffff5555%d %s you can delete|r"):format(n, n == 1 and "item" or "items")
	end
	if spare > 0 then
		return ("|cffff9955%d %s no quest needs|r"):format(spare, spare == 1 and "item" or "items")
	end
	return "|cff33ff99Nothing to delete in your bags|r"
end

-- -------------------------------------------------------------------- after a turn-in

-- The items in the bags no quest needs, by id: what the player has been told of, or had at login.
-- A turn-in is announced by what joined this set since, so a quest it closed counts too.
local known

local function Unneeded()
	local out = {}
	for _, e in ipairs(FQT.Collect()) do
		local group = FQT.Group(e)
		if group == "delete" or group == "spare" then
			out[e.id] = e
		end
	end
	return out
end

-- Takes the bags as they are for what is already known, and says nothing.
function FQT.Baseline()
	known = {}
	for id in pairs(Unneeded()) do
		known[id] = true
	end
end

local function Names(list)
	table.sort(list)
	if #list > 3 then
		return ("%s, %s and %d more"):format(list[1], list[2], #list - 2)
	end
	return table.concat(list, ", ")
end

-- Says which bag items no quest needs since the last look. Returns how many it named.
function FQT.TellTurnIn()
	ns.telling = false
	if not (ns.enabled and ns.ready and ns.scan.done) then
		return 0
	end
	FQT.ClearCache()
	local now = Unneeded()
	local delete, spare = {}, {}
	for id, e in pairs(now) do
		if not (known and known[id]) then
			local list = FQT.Group(e) == "delete" and delete or spare
			list[#list + 1] = e.name
		end
	end
	known = {}
	for id in pairs(now) do
		known[id] = true
	end
	if not ns.db.turnIn then
		return 0
	end
	if #delete > 0 then
		Print("|cffff5555Can be deleted now:|r " .. Names(delete) .. ". |cffaaaaaa" .. ns.slash[1] .. " lists them.|r")
	end
	if #spare > 0 then
		Print("|cffff9955No quest needs these now:|r " .. Names(spare) .. ". |cffaaaaaaSell, trade or keep them.|r")
	end
	return #delete + #spare
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
			root.Try(ns, "baseline", FQT.Baseline)
		end
	end)
end

-- Tooltip hooks cannot be removed, so they are added once and check ns.enabled each time.
function ns.OnEnable()
	FQT.ClearCache() -- quest events are not delivered while off, so cached verdicts may be stale
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

-- The window (Window.lua) refreshes on the same events while it is shown.
local function WindowChanged()
	if ns.RefreshWindow then
		ns.RefreshWindow()
	end
end
local function ClearCache()
	FQT.ClearCache()
	WindowChanged()
end
ns:RegisterEvent("QUEST_LOG_UPDATE", ClearCache)
-- The client marks the quest done and takes its items a moment after the event: look then.
ns:RegisterEvent("QUEST_TURNED_IN", function()
	ClearCache()
	if ns.telling or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	ns.telling = true
	C_Timer.After(1.5, function()
		root.Try(ns, "turn-in", FQT.TellTurnIn)
	end)
end)
ns:RegisterEvent("PLAYER_LEVEL_UP", ClearCache) -- a level cap can close a quest
ns:RegisterEvent("BAG_UPDATE_DELAYED", WindowChanged)
ns:RegisterEvent("BANKFRAME_OPENED", function()
	bankOpen = true
	WindowChanged()
end)
ns:RegisterEvent("BANKFRAME_CLOSED", function()
	bankOpen = false
	WindowChanged()
end)
