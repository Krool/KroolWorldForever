local _, root = ...
local ns = root.Feature("killvalue")
local FKV = ns.FKV

local LINE_LABEL = "Kill value"
local Money, FmtQty = FKV.Money, FKV.FmtQty

local function Print(msg)
	ns:Print(msg)
end

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

local SRC_TAG = { vendor = " (vendor)", quest = " (quest)", ah = " (AH)" }
local GATHER = { S = "skinning", H = "herbalism", M = "mining" }
local RANK_TAG = { [1] = " elite", [2] = " rare-elite", [3] = " BOSS", [4] = " rare" }

local function ItemName(id)
	local ok, name = pcall(C_Item.GetItemNameByID, id)
	if ok and name then
		return name
	end
	return "item:" .. id
end

-- -------------------------------------------------------------------- tooltip

local function TooltipUnit(tooltip)
	if tooltip.GetUnit then
		local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
		if ok and type(unit) == "string" and not Secret(unit) then
			return unit
		end
	end
	return "mouseover"
end

local function IsAttackable(unit)
	if FKV.cfg.friendly then
		return true
	end
	local ok, dead = pcall(UnitIsDead, unit)
	if ok and not Secret(dead) and dead then
		return true -- corpses always show
	end
	local ok2, can = pcall(UnitCanAttack, "player", unit)
	if ok2 and not Secret(can) then
		return can and true or false
	end
	return true
end

local function AddLines(tooltip, data)
	local cfg = FKV.cfg
	local npcId = FKV.ParseGUID(data and data.guid)
	if not npcId or not IsAttackable(TooltipUnit(tooltip)) then
		return
	end
	local acc = FKV.Compute(npcId)
	if not acc then
		return
	end
	local tag = "|cff888888(" .. FKV.SourceTag(acc) .. ")|r"
	if acc.learning then
		tooltip:AddDoubleLine(LINE_LABEL, tag, 0.2, 1, 0.6, 1, 1, 1)
		return
	end
	if acc.known == 0 and acc.unknown > 0 and acc.gold <= 0 then
		tag = "|cff888888(no prices)|r"
	end
	tooltip:AddDoubleLine(LINE_LABEL, Money(acc.total) .. " " .. tag, 0.2, 1, 0.6, 1, 1, 1)
	if cfg.detail > 0 then
		if acc.gold > 0 then
			tooltip:AddDoubleLine("  coins", Money(acc.gold), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
		end
		local n = 0
		for _, c in ipairs(acc.top) do
			if n >= cfg.detail or c.value < 1 then
				break
			end
			tooltip:AddDoubleLine(
				"  " .. ItemName(c.id) .. " " .. FmtQty(c.qty) .. (SRC_TAG[c.src] or ""),
				Money(c.value),
				0.7,
				0.7,
				0.7,
				0.8,
				0.8,
				0.8
			)
			n = n + 1
		end
		if acc.rare >= 100 then
			tooltip:AddDoubleLine(
				"  rare drops (<" .. (cfg.rare * 100) .. "%)",
				"+" .. Money(acc.rare),
				0.6,
				0.6,
				0.6,
				0.7,
				0.7,
				0.7
			)
		end
	end
	if cfg.skin and acc.skin > 0 then
		tooltip:AddDoubleLine("  " .. GATHER[acc.gather], "+" .. Money(acc.skin), 0.7, 0.7, 0.7, 0.8, 0.8, 0.8)
	end
end

local lastData

-- Runs on every unit tooltip; any failure must degrade to "no line", never an error popup.
-- Inside instances unit tooltip data is secret, so nothing is looked up there.
local function OnUnitTooltip(tooltip, data)
	if tooltip ~= GameTooltip or not (ns.enabled and ns.db) then
		return
	end
	if type(data) ~= "table" or data == lastData then
		return -- the same tooltip data processed twice would repeat our lines
	end
	local inInstance = IsInInstance()
	if Secret(inInstance) or inInstance then
		return
	end
	lastData = data
	pcall(AddLines, tooltip, data)
end
ns.OnUnitTooltip = OnUnitTooltip -- test seam

-- -------------------------------------------------------------------- reports

local function Report(npcId, label)
	local ok, acc = pcall(FKV.Compute, npcId)
	if not ok then
		Print("|cffff5555failed|r: " .. tostring(acc))
		return
	end
	if not acc then
		Print("no loot data for " .. label .. " (creature " .. npcId .. "), baseline or learned")
		return
	end
	local cfg = FKV.cfg
	if acc.learning then
		Print(("%s (creature %d): %s"):format(label, npcId, FKV.SourceTag(acc)))
		return
	end
	Print(
		label
			.. " (creature "
			.. npcId
			.. "): "
			.. Money(acc.total)
			.. " per kill "
			.. "|cff888888("
			.. FKV.SourceTag(acc)
			.. ")|r"
			.. (acc.lvl and (" [L" .. acc.lvl .. (RANK_TAG[acc.rank or 0] or "") .. ", " .. (acc.hp or "?") .. " hp]") or "")
	)
	if acc.gold > 0 then
		Print("  coins: " .. Money(acc.gold))
	end
	local n = 0
	for _, c in ipairs(acc.top) do
		if n >= 10 or c.value < 1 then
			break
		end
		Print("  " .. ItemName(c.id) .. " " .. FmtQty(c.qty) .. (SRC_TAG[c.src] or "") .. ": " .. Money(c.value))
		n = n + 1
	end
	if acc.rare > 0 then
		Print("  rare drops (<" .. (cfg.rare * 100) .. "%, not in total): +" .. Money(acc.rare))
		n = 0
		for _, c in ipairs(acc.raretop) do
			if n >= 5 or c.value < 1 then
				break
			end
			Print("    " .. ItemName(c.id) .. " " .. FmtQty(c.qty) .. (SRC_TAG[c.src] or "") .. ": " .. Money(c.value))
			n = n + 1
		end
	end
	if acc.skin > 0 then
		Print("  " .. GATHER[acc.gather] .. " (not in total): +" .. Money(acc.skin))
	end
	if acc.unknown > 0 then
		Print("  " .. acc.unknown .. " drop(s) have no known price")
	end
end

local function Status()
	local D = ns.Data or {}
	local npcs, corpses = 0, 0
	for _, rec in pairs((ns.db and ns.db.learned) or {}) do
		npcs = npcs + 1
		corpses = corpses + (rec.n or 0)
	end
	local hasAH = type(Auctionator) == "table" and type(Auctionator.API) == "table"
	Print(
		("baseline: %s creatures, %s items. Source: %s"):format(
			tostring(D.creatures or 0),
			tostring(D.items or 0),
			tostring(D.source or "none")
		)
	)
	Print(("learned: %d creatures, %d corpses looted (learning %s)"):format(npcs, corpses, FKV.cfg.learn and "on" or "off"))
	Print("Auctionator prices: " .. (hasAH and "available" or "not installed (vendor prices only)"))
end

-- -------------------------------------------------------------------- options
-- Declarative: the bundle's core builds the settings panel from this. The tooltip line's
-- on/off is the feature's own Enabled checkbox.

ns.title = "Kill Value"
ns.description = "Adds the expected gold per kill to creature tooltips: coins plus drop table times vendor or Auctionator prices."
ns.options = {
	{ key = "learn", type = "toggle", label = "Learn From My Loot", tooltip = "Records what corpses drop so new or rebalanced creatures get real numbers.", default = FKV.DEFAULTS.learn },
	{ key = "vendor", type = "toggle", label = "Use Vendor Prices", tooltip = "Vendor sell price as fallback and floor.", default = FKV.DEFAULTS.vendor },
	{ key = "ah", type = "toggle", label = "Use Auctionator Prices", tooltip = "If Auctionator is installed, price drops from the auction house minus the cut.", default = FKV.DEFAULTS.ah },
	{ key = "skin", type = "toggle", label = "Show Skinning Value", tooltip = "Adds a skinning/gathering line (not part of the total).", default = FKV.DEFAULTS.skin },
	{ key = "friendly", type = "toggle", label = "Show On Friendly Creatures", tooltip = "Also adds the line to creatures you cannot attack.", default = FKV.DEFAULTS.friendly },
	{ key = "hello", type = "toggle", label = "Login Message", tooltip = "Prints one line at login.", default = FKV.DEFAULTS.hello },
	{ key = "detail", type = "range", label = "Contributor Lines", tooltip = "Top drops listed under the total (0 = none).", default = FKV.DEFAULTS.detail, min = 0, max = 10, step = 1 },
	{ key = "cut", type = "range", label = "Auction House Cut %", tooltip = "Taken off Auctionator prices.", default = FKV.DEFAULTS.cut, min = 0, max = 100, step = 1 },
}

function ns.OnOptionChanged()
	FKV.ClearPriceCache() -- every option feeds the cached values
end

local TOGGLES = {
	learn = { "learn", "learning from loot" },
	vendor = { "vendor", "vendor price fallback/floor" },
	ah = { "ah", "Auctionator prices" },
	skin = { "skin", "skinning line" },
	friendly = { "friendly", "line on friendly creatures" },
	hello = { "hello", "login message" },
}

local CONFIG_ORDER = { "detail", "cut", "rare", "learn", "vendor", "ah", "skin", "friendly", "hello" }
local CONFIG_HELP = {
	detail = "contributor lines under the total",
	cut = "auction house cut %",
	rare = "drops below this go to the rare line",
	learn = "record loot from corpses",
	vendor = "vendor price as fallback/floor",
	ah = "use Auctionator prices",
	skin = "skinning line (not in total)",
	friendly = "show on friendly creatures",
	hello = "login message",
}

local function TargetNpc()
	local ok, guid = pcall(UnitGUID, "target")
	if not ok or guid == nil or Secret(guid) then
		return nil
	end
	return FKV.ParseGUID(guid)
end

local function Help()
	Print("commands:")
	Print("  /fkv                    breakdown for your target")
	Print("  /fkv id <npcId>         breakdown for any creature")
	Print("  /fkv status | config | options | reset [learned] | help")
	Print("  /fkv detail <n> | cut <pct> | rare <pct>")
	Print("  /fkv learn | vendor | ah | skin | friendly | hello    (on/off switches)")
	Print("  turn the whole feature on or off with /kwf killvalue on|off")
end

function ns.OnSlash(msg)
	msg = strtrim(msg or ""):lower()
	local cmd, arg = msg:match("^(%S*)%s*(.*)$")
	local cfg = FKV.cfg
	if not ns.db then
		Print("not loaded yet")
	elseif TOGGLES[cmd] then
		local key = TOGGLES[cmd][1]
		cfg[key] = not cfg[key]
		FKV.ClearPriceCache()
		Print(TOGGLES[cmd][2] .. " " .. (cfg[key] and "on" or "off"))
	elseif cmd == "detail" then
		local n = tonumber(arg)
		if n then
			cfg.detail = math.max(0, math.min(20, math.floor(n)))
		elseif arg ~= "" then
			Print("usage: /fkv detail <0-20>")
		end
		Print("detail lines: " .. cfg.detail)
	elseif cmd == "cut" then
		local pct = tonumber(arg)
		if pct then
			cfg.cut = math.max(0, math.min(100, pct))
		elseif arg ~= "" then
			Print("usage: /fkv cut <0-100>")
		end
		Print("auction house cut: " .. cfg.cut .. "%")
	elseif cmd == "rare" then
		local pct = tonumber(arg)
		if pct then
			cfg.rare = math.max(0, math.min(100, pct)) / 100
		end
		Print("drops below " .. (cfg.rare * 100) .. "% are listed as rare, outside the total")
	elseif cmd == "status" then
		Status()
	elseif cmd == "config" then
		for _, k in ipairs(CONFIG_ORDER) do
			local v = cfg[k]
			if type(v) == "boolean" then
				v = v and "on" or "off"
			elseif k == "rare" then
				v = (cfg.rare * 100) .. "%"
			end
			Print(("  %-9s %-6s %s"):format(k, tostring(v), CONFIG_HELP[k] or ""))
		end
	elseif cmd == "options" then
		root.OpenSettings(ns)
	elseif cmd == "reset" then
		if arg == "learned" then
			ns.db.learned = {}
			ns.db.recent = {}
			FKV.AttachDB(ns.db)
			Print("learned loot data erased")
		else
			for k, v in pairs(FKV.DEFAULTS) do
				cfg[k] = v
			end
			FKV.ClearPriceCache()
			Print("settings restored to defaults (/fkv reset learned erases learned loot)")
		end
	elseif cmd == "id" then
		local id = tonumber(arg)
		if id then
			Report(id, "creature")
		else
			Print("usage: /fkv id <npcId>")
		end
	elseif cmd == "help" then
		Help()
	elseif cmd == "" or cmd == "target" then
		local npcId = TargetNpc()
		if npcId then
			Report(npcId, UnitName("target") or "target")
		else
			Print("no creature targeted (or its id is unreadable here); /fkv help")
		end
	else
		Print("unknown command '" .. cmd .. "'; /fkv help")
	end
end
ns.Slash = ns.OnSlash -- test seam

ns.slash = { "/fkv", "/killvalue" }

-- -------------------------------------------------------------------- lifecycle

function ns.OnLoad()
	FKV.AttachDB(ns.db)
end

-- The tooltip hook cannot be removed, so it is registered once and checks ns.enabled itself.
local hooked, greeted = false, false
function ns.OnEnable()
	if not hooked then
		hooked = true
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
	end
	if not greeted then
		greeted = true
		if ns.db and FKV.cfg.hello then
			Print("loaded. Hover a creature for its kill value; /fkv help for commands.")
		end
	end
end

function ns.OnDisable()
	FKV.ClearPriceCache()
end

ns:RegisterEvent("LOOT_READY", function()
	pcall(FKV.CaptureLoot)
end)
ns:RegisterEvent("LOOT_OPENED", function()
	pcall(FKV.CaptureLoot)
end)
ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemId)
	if itemId and not Secret(itemId) then
		FKV.ItemLoaded(itemId)
	end
end)
ns:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
	FKV.ClearPriceCache()
end)
