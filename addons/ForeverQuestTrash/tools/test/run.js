// ForeverQuestTrash test runner.
// 1. Syntax-checks every addon Lua file with the Lua 5.1 grammar (the client's dialect).
// 2. Loads stubs.lua, then the addon files in TOC order, each with the (addonName, ns) varargs
//    the client passes, into one fengari state.
// 3. Runs the behavior checks in test.lua.
const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const root = path.join(__dirname, "..", "..");
const toc = fs.readFileSync(path.join(root, "ForeverQuestTrash_Forever.toc"), "utf8");
const addonFiles = toc.split(/\r?\n/).filter((l) => l.trim() && !l.startsWith("#"));

let failed = false;
for (const f of addonFiles) {
  try {
    luaparse.parse(fs.readFileSync(path.join(root, f), "utf8"), { luaVersion: "5.1" });
    console.log("syntax ok: " + f);
  } catch (e) {
    console.log("SYNTAX FAIL: " + f + ": " + e.message);
    failed = true;
  }
}
if (failed) process.exit(1);

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

const output = [];
lua.lua_register(L, to_luastring("__rawprint"), (L) => {
  output.push(lua.lua_tojsstring(L, 1));
  return 0;
});
const printShim =
  "print = function(...) local t = {} for i = 1, select('#', ...) do t[#t + 1] = tostring((select(i, ...))) end __rawprint(table.concat(t, '\\t')) end";
if (lauxlib.luaL_dostring(L, to_luastring(printShim)) !== lua.LUA_OK) {
  console.log("print shim failed");
  process.exit(1);
}

function fail(label) {
  console.log(output.join("\n"));
  console.log("LUA FAIL in " + label + ": " + lua.lua_tojsstring(L, -1));
  process.exit(1);
}

function load(label, src) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring("@" + label)) !== lua.LUA_OK) fail(label);
}

load("stubs.lua", fs.readFileSync(path.join(__dirname, "stubs.lua"), "utf8"));
if (lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) fail("stubs.lua");

// addon files receive ("ForeverQuestTrash", ns) like the client passes them
lua.lua_newtable(L);
lua.lua_setglobal(L, to_luastring("__ns"));
for (const f of addonFiles) {
  load(f, fs.readFileSync(path.join(root, f), "utf8"));
  lua.lua_pushstring(L, to_luastring("ForeverQuestTrash"));
  lua.lua_getglobal(L, to_luastring("__ns"));
  if (lua.lua_pcall(L, 2, 0, 0) !== lua.LUA_OK) fail(f);
}

load("test.lua", fs.readFileSync(path.join(__dirname, "test.lua"), "utf8"));
const ok = lua.lua_pcall(L, 0, 0, 0) === lua.LUA_OK;
console.log(output.join("\n"));
if (!ok) {
  console.log("BEHAVIOR TESTS FAILED: " + lua.lua_tojsstring(L, -1));
  process.exit(1);
}
console.log("ALL TESTS PASSED");
