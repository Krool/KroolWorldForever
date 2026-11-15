-- The Characters suite's client: the Setups stubs (widgets, events, timers, bars) plus the realm's
-- display name, which keeps its spaces where the normalized name (GetNormalizedRealmName) drops them.

__include("setups/stubs.lua")

function GetRealmName()
	return Player.realmName or Player.realm
end
