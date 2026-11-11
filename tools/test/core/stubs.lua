-- The Core suite's client: the Camp Guide stubs (enough to load the whole bundle), plus an
-- Auctionator that knows how old a price is and calls back after a scan.

__include("camp/stubs.lua")

Ages = {} -- item id -> days since Auctionator saw it
ScanCallbacks = {}
local function IdOf(item)
	if type(item) == "number" then
		return item
	end
	return tonumber(tostring(item):match("item:(%d+)"))
end
function AuctionatorOn(on)
	if on == false then
		Auctionator = nil
		return
	end
	Auctionator = {
		API = {
			v1 = {
				GetAuctionPriceByItemID = function(_, id)
					return Prices[id]
				end,
				GetAuctionPriceByItemLink = function(_, link)
					return LinkPrices[link] or Prices[IdOf(link)]
				end,
				GetAuctionAgeByItemID = function(_, id)
					return Ages[id]
				end,
				GetAuctionAgeByItemLink = function(_, link)
					return Ages[IdOf(link)]
				end,
				RegisterForDBUpdate = function(_, fn)
					ScanCallbacks[#ScanCallbacks + 1] = fn
				end,
			},
		},
	}
end
AuctionatorOn(true)
function AuctionatorScan()
	for _, fn in ipairs(ScanCallbacks) do
		fn()
	end
end
