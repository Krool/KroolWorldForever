-- Loaded before every suite's stubs.lua: what all the stub clients share.

-- Secret values. In the client a secret errors when addon code compares it, does math on it,
-- indexes it or calls it; the one safe thing is issecretvalue(v). Secret() errors the same way
-- wherever Lua lets a value object: an index, an assignment into it, a call, arithmetic,
-- concatenation, ordering, and equality against another table.
--
-- What Lua cannot trap, so the suites cannot see it: a truth test (`if v`, `v and x`), equality
-- against a number, string or nil, and use as a table key. Those error in the client too. The
-- rule in feature code stays: issecretvalue first, then anything else.
local secrets = setmetatable({}, { __mode = "k" })
local function Deny(what)
	return function()
		error("a secret value was " .. what .. " (check issecretvalue first)", 2)
	end
end
local SecretMeta = {
	__index = Deny("indexed"),
	__newindex = Deny("written to"),
	__call = Deny("called"),
	__eq = Deny("compared"),
	__lt = Deny("compared"),
	__le = Deny("compared"),
	__concat = Deny("concatenated"),
	__len = Deny("measured"),
	__unm = Deny("used in math"),
	__add = Deny("used in math"),
	__sub = Deny("used in math"),
	__mul = Deny("used in math"),
	__div = Deny("used in math"),
	__mod = Deny("used in math"),
	__pow = Deny("used in math"),
	__tostring = function()
		return "<secret>"
	end,
}
function Secret()
	local s = setmetatable({}, SecretMeta)
	secrets[s] = true
	return s
end
function issecretvalue(v)
	return type(v) == "table" and secrets[v] == true
end
