-- The character roster: every character that has logged in with this addon, saved account-wide at
-- chars["Name-Realm"] = { name, realm, class (classFilename), level, seen (time()), track }.
-- Features that list characters (Setups, Sayge's Fortune, later Reagent Uses) show only tracked
-- ones. Every character is tracked by default, level 1 bank alts included; the player opts one out
-- by hand (/kw untrack, the Characters window). Untracking hides, it never deletes anything.
--
--   root.CharKey()                  "Name-Realm" of the logged-in character
--   root.Chars()                    the roster table, key -> record
--   root.CharList()                 { { key =, rec = }, ... }: tracked first, then newest seen
--   root.Tracked(key)               true unless the player opted that character out
--   root.SetTracked(key, on)        opt a character in or out
--   root.ForgetChar(key)            drop the roster record (and tell OnForgetChar listeners)
--   root.FindChar(nameOrKey)        key, rec; or nil and a list of candidate keys when ambiguous
--   root.OnCharsChanged(fn)         fn() after SetTracked or ForgetChar
--   root.OnForgetChar(fn)           fn(key) so a feature drops its own record of that character
--
-- Core/Init.lua hands over the saved table (root.InitChars) and its event frame calls
-- root.CharsOnEvent. File scope stays free of game calls.

local _, root = ...

local chars = {} -- the saved roster; replaced by InitChars
local changedFns, forgetFns = {}, {}

local function Secret(v)
	return issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- v when it is a readable value of that type, else nil.
local function Plain(v, kind)
	if Secret(v) or type(v) ~= kind then
		return nil
	end
	return v
end

-- "Name-Realm" for the logged-in character; the realm is the normalized one (no spaces), "?" when
-- the client does not say. The same key Setups has always used.
function root.CharKey()
	local ok, name, realm = pcall(UnitFullName, "player")
	if not ok then
		name, realm = nil, nil
	end
	name, realm = Plain(name, "string"), Plain(realm, "string")
	if not realm or realm == "" then
		local okR, normalized = pcall(GetNormalizedRealmName)
		realm = okR and Plain(normalized, "string") or nil
	end
	return (name or "?") .. "-" .. ((realm and realm ~= "") and realm or "?")
end

local function Split(key)
	local name, realm = key:match("^([^-]*)-(.*)$")
	return name or key, realm or ""
end

-- Coerces one saved record. Returns nil for what is not a record.
local function Clean(key, rec)
	if type(key) ~= "string" or key == "" or type(rec) ~= "table" then
		return nil
	end
	local name, realm = Split(key)
	rec.name = type(rec.name) == "string" and rec.name ~= "" and rec.name or name
	rec.realm = type(rec.realm) == "string" and rec.realm or realm
	rec.class = type(rec.class) == "string" and rec.class or nil
	rec.level = math.max(0, math.floor(tonumber(rec.level) or 0))
	rec.seen = tonumber(rec.seen) or 0
	rec.track = rec.track ~= false
	return rec
end

-- Takes the saved table (Init's Load calls it with the one it owns) and validates the roster.
function root.InitChars(sv)
	if type(sv.chars) ~= "table" then
		sv.chars = {}
	end
	local drop = {}
	for key, rec in pairs(sv.chars) do
		if not Clean(key, rec) then
			drop[#drop + 1] = key
		end
	end
	for _, key in ipairs(drop) do
		sv.chars[key] = nil
	end
	chars = sv.chars
end

function root.Chars()
	return chars
end

function root.Tracked(key)
	local rec = chars[key]
	return not (type(rec) == "table" and rec.track == false)
end

local function Notify(list, ...)
	for _, fn in ipairs(list) do
		root.Try(nil, "characters", fn, ...)
	end
end

function root.OnCharsChanged(fn)
	changedFns[#changedFns + 1] = fn
end

function root.OnForgetChar(fn)
	forgetFns[#forgetFns + 1] = fn
end

function root.SetTracked(key, on)
	local rec = chars[key]
	if type(rec) ~= "table" then
		return false
	end
	rec.track = on and true or false
	Notify(changedFns)
	return true
end

function root.ForgetChar(key)
	if type(chars[key]) ~= "table" then
		return false
	end
	chars[key] = nil
	Notify(forgetFns, key)
	Notify(changedFns)
	return true
end

-- Tracked first, then the most recently seen, then by key so the order is stable.
function root.CharList()
	local list = {}
	for key, rec in pairs(chars) do
		list[#list + 1] = { key = key, rec = rec }
	end
	table.sort(list, function(a, b)
		local ta, tb = a.rec.track ~= false, b.rec.track ~= false
		if ta ~= tb then
			return ta
		end
		if a.rec.seen ~= b.rec.seen then
			return a.rec.seen > b.rec.seen
		end
		return a.key < b.key
	end)
	return list
end

-- An exact key, else a unique case-insensitive match on the key or the name. Ambiguous: nil and the
-- candidate keys (sorted); no match: nil and an empty list.
function root.FindChar(text)
	text = type(text) == "string" and strtrim(text) or ""
	if text == "" then
		return nil, {}
	end
	if type(chars[text]) == "table" then
		return text, chars[text]
	end
	local lower, found = text:lower(), {}
	for key in pairs(chars) do
		if key:lower() == lower then
			found[#found + 1] = key
		end
	end
	if #found == 0 then
		for key, rec in pairs(chars) do
			if tostring(rec.name):lower() == lower then
				found[#found + 1] = key
			end
		end
	end
	table.sort(found)
	if #found == 1 then
		return found[1], chars[found[1]]
	end
	return nil, found
end

-- Notes the logged-in character. level: a value the event gave (UnitLevel can lag a level-up).
local function Record(level)
	local key = root.CharKey()
	if key:sub(1, 2) == "?-" then
		return -- the client did not say who this is
	end
	local rec = chars[key]
	if type(rec) ~= "table" then
		rec = { track = true }
		chars[key] = rec
	end
	local name, realm = Split(key)
	rec.name, rec.realm = name, realm
	local ok, _, classFile = pcall(UnitClass, "player")
	classFile = ok and Plain(classFile, "string") or nil
	rec.class = classFile or rec.class
	level = Plain(level, "number")
	if not level then
		local okL, current = pcall(UnitLevel, "player")
		level = okL and Plain(current, "number") or nil
	end
	rec.level = level and level > 0 and math.floor(level) or rec.level
	local okT, now = pcall(time)
	rec.seen = okT and Plain(now, "number") or rec.seen
	Clean(key, rec)
end

-- Called by Init's event frame for every event it gets.
function root.CharsOnEvent(event, ...)
	if event == "PLAYER_LOGIN" or event == "PLAYER_LOGOUT" then
		Record()
	elseif event == "PLAYER_LEVEL_UP" then
		Record((...))
	end
end

-- /kw track [name], /kw untrack [name], /kw forget <name>. No name: the logged-in character
-- (forget refuses it: it would only come back at the next login).
function root.CharsCommand(cmd, arg)
	arg = strtrim(arg or "")
	local key, rec
	if arg == "" then
		if cmd == "forget" then
			root.Print("/kw forget <name>: drops a character from the list. Nothing else is deleted.")
			return
		end
		key = root.CharKey()
		rec = chars[key]
		if not rec then
			root.Print("this character is not on the list yet; it is added at login")
			return
		end
	else
		local found
		key, found = root.FindChar(arg)
		if not key then
			if #found > 0 then
				root.Print(("%d characters match '%s'; use Name-Realm:"):format(#found, arg))
				for _, k in ipairs(found) do
					print("  " .. k)
				end
			else
				root.Print(("no character called '%s'. /kw chars lists them"):format(arg))
			end
			return
		end
		rec = found
	end
	if cmd == "forget" then
		if key == root.CharKey() then
			root.Print(key .. " is the character you are playing, and would be back at the next login. /kw untrack leaves it out of the lists instead")
			return
		end
		root.ForgetChar(key)
		root.Print(key .. " forgotten (saved setups and snapshots are kept)")
	else
		local on = cmd == "track"
		root.SetTracked(key, on)
		root.Print(("%s %s"):format(key, on and "is tracked" or "is left out of character lists (/kw track brings it back)"))
	end
end
