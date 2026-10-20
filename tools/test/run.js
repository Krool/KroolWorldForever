// Krool World Forever test runner.
// 1. Syntax-checks every file the TOC loads (Lua 5.1 grammar, the client's dialect).
// 2. For each feature folder here (tools/test/<feature>/ with stubs.lua + test.lua): a fresh
//    fengari state loads that folder's stubs, then the WHOLE bundle in TOC order (each file gets
//    the ("KroolWorldForever", root) varargs the client passes), then runs test.lua. Loading
//    every feature under every stub set also proves no feature does game work at file scope.
const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const addonDir = path.join(__dirname, "..", "..", "KroolWorldForever");
const toc = fs.readFileSync(path.join(addonDir, "KroolWorldForever_Forever.toc"), "utf8");
const files = toc
  .split(/\r?\n/)
  .map((l) => l.trim())
  .filter((l) => l && !l.startsWith("#"))
  .map((l) => l.replace(/\\/g, "/"));

let failed = false;
const sources = {};
for (const f of files) {
  sources[f] = fs.readFileSync(path.join(addonDir, f), "utf8");
  try {
    luaparse.parse(sources[f], { luaVersion: "5.1" });
  } catch (e) {
    console.log("SYNTAX FAIL: " + f + ": " + e.message);
    failed = true;
  }
}
if (failed) process.exit(1);
console.log(`syntax ok: ${files.length} files`);

const only = process.argv[2];
const suites = fs
  .readdirSync(__dirname, { withFileTypes: true })
  .filter((d) => d.isDirectory() && d.name !== "node_modules" && (!only || d.name === only))
  .map((d) => d.name);

function runSuite(name) {
  const dir = path.join(__dirname, name);
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const output = [];
  lua.lua_register(L, to_luastring("__rawprint"), (L) => {
    output.push(lua.lua_tojsstring(L, 1));
    return 0;
  });
  const shim =
    "print = function(...) local t = {} for i = 1, select('#', ...) do t[#t + 1] = tostring((select(i, ...))) end __rawprint(table.concat(t, '\\t')) end";
  lauxlib.luaL_dostring(L, to_luastring(shim));

  const fail = (label) => {
    console.log(output.join("\n"));
    console.log(`[${name}] LUA FAIL in ${label}: ${lua.lua_tojsstring(L, -1)}`);
    return false;
  };
  const exec = (label, src, withVarargs) => {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring("@" + label)) !== lua.LUA_OK) return fail(label);
    let nargs = 0;
    if (withVarargs) {
      lua.lua_pushstring(L, to_luastring("KroolWorldForever"));
      lua.lua_getglobal(L, to_luastring("__ns"));
      nargs = 2;
    }
    if (lua.lua_pcall(L, nargs, 0, 0) !== lua.LUA_OK) return fail(label);
    return true;
  };

  if (!exec(name + "/stubs.lua", fs.readFileSync(path.join(dir, "stubs.lua"), "utf8"))) return false;
  lua.lua_newtable(L);
  lua.lua_setglobal(L, to_luastring("__ns"));
  for (const f of files) if (!exec(f, sources[f], true)) return false;
  const ok = exec(name + "/test.lua", fs.readFileSync(path.join(dir, "test.lua"), "utf8"));
  console.log(output.join("\n"));
  console.log(ok ? `[${name}] PASSED` : `[${name}] FAILED`);
  return ok;
}

let allOk = true;
for (const s of suites) allOk = runSuite(s) && allOk;
console.log(allOk ? "ALL TESTS PASSED" : "TESTS FAILED");
process.exit(allOk ? 0 : 1);
