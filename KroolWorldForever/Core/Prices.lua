-- Shared price helpers for features: Auctionator lookups and money text.
-- Auctionator is optional: every step is checked and each call is pcall-wrapped.

local _, root = ...

local CALLER = "KroolWorldForever"

local function AuctionatorAPI()
	local A = Auctionator
	local api = type(A) == "table" and type(A.API) == "table" and A.API.v1
	return type(api) == "table" and api or nil
end

function root.HasAuctionator()
	return AuctionatorAPI() ~= nil
end

-- Auctionator's price in copper for an item id or an item link (a link tells apart random
-- suffixes and item levels), or nil when Auctionator is missing or has no price.
function root.AuctionPrice(item)
	local api = AuctionatorAPI()
	if not api then
		return nil
	end
	local fn = type(item) == "string" and api.GetAuctionPriceByItemLink or api.GetAuctionPriceByItemID
	if type(fn) ~= "function" then
		return nil
	end
	local ok, price = pcall(fn, CALLER, item)
	if ok and type(price) == "number" and price > 0 then
		return price
	end
	return nil
end

-- Days since Auctionator last saw the item on the auction house (0: today's scan), or nil when it
-- cannot say (no Auctionator, an older one without the call, or no record of when).
function root.AuctionAge(item)
	local api = AuctionatorAPI()
	if not api then
		return nil
	end
	local fn = type(item) == "string" and api.GetAuctionAgeByItemLink or api.GetAuctionAgeByItemID
	if type(fn) ~= "function" then
		return nil
	end
	local ok, age = pcall(fn, CALLER, item)
	if ok and type(age) == "number" and age >= 0 then
		return age
	end
	return nil
end

-- An auction price older than this many days is called old: features mark it, and Skill-Up Odds
-- lets a vendor price beat it. An unknown age is never old (an Auctionator without the age call).
root.STALE_DAYS = 3
function root.AuctionStale(age)
	return age ~= nil and age > root.STALE_DAYS
end

-- "seen today", "seen yesterday", "seen 5 days ago"; nil for an unknown age.
function root.SeenText(age)
	if age == nil then
		return nil
	elseif age == 0 then
		return "seen today"
	elseif age == 1 then
		return "seen yesterday"
	end
	return ("seen %d days ago"):format(age)
end

-- fn runs after every Auctionator scan that updated its prices. Auctionator is an OptionalDep, so
-- it has loaded by our OnLoad; the first successful call registers with it once and fans out.
-- Returns whether Auctionator will call back.
local listeners, hooked = {}, false
function root.OnAuctionPrices(fn)
	listeners[#listeners + 1] = fn
	if hooked then
		return true
	end
	local api = AuctionatorAPI()
	if not (api and type(api.RegisterForDBUpdate) == "function") then
		return false
	end
	hooked = pcall(api.RegisterForDBUpdate, CALLER, function()
		for _, f in ipairs(listeners) do
			pcall(f)
		end
	end)
	return hooked
end

-- "1g 20s 5c" in coin colors. A negative amount gets a minus sign in front.
function root.Money(copper)
	copper = math.floor((copper or 0) + 0.5)
	if copper < 0 then
		return "-" .. root.Money(-copper)
	end
	local g = math.floor(copper / 10000)
	local s = math.floor((copper % 10000) / 100)
	local c = copper % 100
	local out = ""
	if g > 0 then
		out = out .. "|cffffd700" .. g .. "g|r "
	end
	if g > 0 or s > 0 then
		out = out .. "|cffc7c7cf" .. s .. "s|r "
	end
	return out .. "|cffeda55f" .. c .. "c|r"
end
