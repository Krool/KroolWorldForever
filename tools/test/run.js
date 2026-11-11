// Krool World Forever test runner.
// 1. Syntax-checks every file the TOC loads (Lua 5.1 grammar, the client's dialect).
// 2. For each feature folder here (tools/test/<feature>/ with stubs.lua + test.lua): a fresh
//    fengari state loads that folder's stubs, then the WHOLE bundle in TOC order (each file gets
//    the ("KroolWorldForever", root) varargs the client passes), then runs test.lua. Loading
//    every feature under every stub set also proves no feature does game work at file scope.
//    common.lua loads before each stubs.lua (the shared Secret() stub); a stubs.lua may build on
//    another suite's with __include("camp/stubs.lua").
// 3. A suite must report its checks ("N checks, M failed") and N must be above zero: a test.lua
//    that returns early cannot pass. Every feature must have a "/kw <key> off" check somewhere.
// Usage: node run.js [suite] [--verbose]. Passing lines ("ok: ...") print only with --verbose.
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

const args = process.argv.slice(2);
const verbose = args.includes("--verbose");
const only = args.find((a) => !a.startsWith("--"));
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

  const shown = () => output.filter((l) => verbose || !/^ok:\s/.test(l)).join("\n");
  const fail = (label) => {
    console.log(shown());
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

  lua.lua_register(L, to_luastring("__include"), (L) => {
    const rel = lua.lua_tojsstring(L, 1);
    if (!exec(rel, fs.readFileSync(path.join(__dirname, rel), "utf8"))) lauxlib.luaL_error(L, to_luastring("include failed: " + rel));
    return 0;
  });
  if (!exec("common.lua", fs.readFileSync(path.join(__dirname, "common.lua"), "utf8"))) return false;
  if (!exec(name + "/stubs.lua", fs.readFileSync(path.join(dir, "stubs.lua"), "utf8"))) return false;
  lua.lua_newtable(L);
  lua.lua_setglobal(L, to_luastring("__ns"));
  for (const f of files) if (!exec(f, sources[f], true)) return false;
  let ok = exec(name + "/test.lua", fs.readFileSync(path.join(dir, "test.lua"), "utf8"));
  if (ok) {
    console.log(shown());
    const m = output.join("\n").match(/(\d+) checks, (\d+) failed/);
    if (!m || Number(m[1]) === 0) {
      console.log(`[${name}] ran no checks: test.lua must end by printing "N checks, M failed"`);
      ok = false;
    }
  }
  console.log(ok ? `[${name}] PASSED` : `[${name}] FAILED`);
  return ok;
}

let allOk = true;
for (const s of suites) allOk = runSuite(s) && allOk;

// Every feature the bundle declares needs a check that switching it off silences it.
if (!only) {
  const keys = new Set();
  for (const f of files) for (const m of sources[f].matchAll(/root\.Feature\("(\w+)"\)/g)) keys.add(m[1]);
  const tests = suites.map((s) => fs.readFileSync(path.join(__dirname, s, "test.lua"), "utf8")).join("\n");
  for (const key of keys) {
    if (!tests.includes(key + " off")) {
      console.log(`no suite checks "/kw ${key} off": a feature must go quiet when it is switched off`);
      allOk = false;
    }
  }
}
console.log(allOk ? "ALL TESTS PASSED" : "TESTS FAILED");
process.exit(allOk ? 0 : 1);
