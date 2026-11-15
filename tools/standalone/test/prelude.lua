-- Loaded after a suite's stubs and before any addon file: records what the standalone tests need to
-- see (settings categories, named frames, SlashCmdList and StaticPopupDialogs writes) and gives
-- C_AddOns.IsAddOnLoaded a state the test sets.

LoadedAddons = {}
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = function(name)
	return LoadedAddons[name] == true
end

Cats, Subcats, AddOnCats = {}, {}, {}
do
	local S = Settings
	local rc, rs, ra = S.RegisterVerticalLayoutCategory, S.RegisterVerticalLayoutSubcategory, S.RegisterAddOnCategory
	S.RegisterVerticalLayoutCategory = function(name, ...)
		Cats[#Cats + 1] = name
		return rc(name, ...)
	end
	S.RegisterVerticalLayoutSubcategory = function(parent, name, ...)
		Subcats[#Subcats + 1] = name
		return rs(parent, name, ...)
	end
	S.RegisterAddOnCategory = function(c, ...)
		AddOnCats[#AddOnCats + 1] = c
		return ra(c, ...)
	end
end

-- Who is running: set by the collision test around each addon's work (nil elsewhere).
CurrentAddon = nil
WrittenBy = {} -- name -> { [addon] = true }: globals, slash ids, popup names, frame names
function NoteWrite(kind, name)
	local key = kind .. ":" .. tostring(name)
	WrittenBy[key] = WrittenBy[key] or {}
	WrittenBy[key][CurrentAddon or "?"] = true
end

-- SlashCmdList and StaticPopupDialogs through proxies that note each key written.
StaticPopupDialogs = StaticPopupDialogs or {}
RealSlashCmdList, RealPopups = SlashCmdList, StaticPopupDialogs
local function Proxy(real, kind)
	return setmetatable({}, {
		__index = real,
		__newindex = function(_, k, v)
			NoteWrite(kind, k)
			real[k] = v
		end,
		__pairs = function()
			return pairs(real)
		end,
	})
end
SlashCmdList = Proxy(RealSlashCmdList, "slash")
StaticPopupDialogs = Proxy(RealPopups, "popup")

local createFrame = CreateFrame
FrameNames = {}
function CreateFrame(kind, name, ...)
	if name then
		FrameNames[#FrameNames + 1] = name
		NoteWrite("frame", name)
	end
	return createFrame(kind, name, ...)
end
