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

-- "1g 20s 5c" in coin colors.
function root.Money(copper)
	copper = math.floor((copper or 0) + 0.5)
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
