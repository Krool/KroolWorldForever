// Tests the generated standalone addons (tools/standalone/build.js) under the fengari stubs.
//   node run.js [--verbose]
// 1. Generates every standalone into <repo>/build/standalone (the API lint reads them there too).
// 2. Manifest checks: the bundle's Core/Identity.lua family matches the manifest, no file is missing.
// 3. Each standalone alone in a fresh Lua state (stubs from tools/test/<key>/stubs.lua), loaded by
//    its generated TOC: single.lua.
// 4. The bundle and all standalones in ONE state, both load orders: collision.lua.
const fs = require("fs");
const path = require("path");
const testDir = path.join(__dirname, "..", "..", "test");
const luaparse = require(path.join(testDir, "node_modules", "luaparse"));
const { lua, lauxlib, lualib, to_luastring } = require(path.join(testDir, "node_modules", "fengari"));
const { build } = require("../build.js");

const repo = path.join(__dirname, "..", "..", "..");
const outDir = path.join(repo, "build", "standalone");
const verbose = process.argv.includes("--verbose");
const manifest = JSON.parse(fs.readFileSync(path.join(repo, "standalone", "addons.json"), "utf8"));
const bundleDir = path.join(repo, "KroolWorldForever");

let allOk = true;
const fail = (msg) => {
  console.log("FAIL: " + msg);
  allOk = false;
};

function tocFiles(dir, name) {
  return fs
    .readFileSync(path.join(dir, name + "_Forever.toc"), "utf8")
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith("#"))
    .map((l) => l.replace(/\\/g, "/"));
}

function luaLiteral(v) {
  if (Array.isArray(v)) return "{" + v.map(luaLiteral).join(",") + "}";
  if (v && typeof v === "object") return "{" + Object.entries(v).map(([k, x]) => `[${JSON.stringify(k)}]=${luaLiteral(x)}`).join(",") + "}";
  return JSON.stringify(v);
}

// One Lua state with the print shim and the helpers run.js gives every suite.
function newState(label) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const output = [];
  lua.lua_register(L, to_luastring("__rawprint"), (L) => {
    output.push(lua.lua_tojsstring(L, 1));
    return 0;
  });
  lauxlib.luaL_dostring(
    L,
    to_luastring("print = function(...) local t = {} for i = 1, select('#', ...) do t[#t + 1] = tostring((select(i, ...))) end __rawprint(table.concat(t, '\\t')) end")
  );
  lua.lua_register(L, to_luastring("__readfile"), (L) => {
    lua.lua_pushstring(L, to_luastring(fs.readFileSync(lua.lua_tojsstring(L, 1), "utf8")));
    return 1;
  });
  const st = { L, output, label };
  st.fail = (what) => {
    console.log(st.shown());
    console.log(`[${label}] LUA FAIL in ${what}: ${lua.lua_tojsstring(L, -1)}`);
    return false;
  };
  st.shown = () => output.filter((l) => verbose || !/^ok:\s/.test(l)).join("\n");
  // Runs a chunk; vararg is the addon folder name and the private root table __ns, as the client passes.
  st.exec = (what, src, folder) => {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring("@" + what)) !== lua.LUA_OK) return st.fail(what);
    let nargs = 0;
    if (folder) {
      lua.lua_pushstring(L, to_luastring(folder));
      lua.lua_getglobal(L, to_luastring("__ns"));
      nargs = 2;
    }
    return lua.lua_pcall(L, nargs, 0, 0) === lua.LUA_OK ? true : st.fail(what);
  };
  lua.lua_register(L, to_luastring("__include"), (L) => {
    const rel = lua.lua_tojsstring(L, 1);
    if (!st.exec(rel, fs.readFileSync(path.join(testDir, rel), "utf8"))) lauxlib.luaL_error(L, to_luastring("include failed: " + rel));
    return 0;
  });
  st.setGlobal = (name, value) => lauxlib.luaL_dostring(L, to_luastring(`${name} = ${luaLiteral(value)}`));
  st.finish = (ok) => {
    if (ok) {
      console.log(st.shown());
      const m = output.join("\n").match(/(\d+) checks, (\d+) failed/);
      if (!m || Number(m[1]) === 0) {
        console.log(`[${label}] ran no checks`);
        ok = false;
      } else if (Number(m[2]) > 0) ok = false;
    }
    console.log(ok ? `[${label}] PASSED` : `[${label}] FAILED`);
    return ok;
  };
  return st;
}

function loadStubs(st, stubsDir) {
  return (
    st.exec("common.lua", fs.readFileSync(path.join(testDir, "common.lua"), "utf8")) &&
    st.exec(stubsDir + "/stubs.lua", fs.readFileSync(path.join(testDir, stubsDir, "stubs.lua"), "utf8")) &&
    st.exec("prelude.lua", fs.readFileSync(path.join(__dirname, "prelude.lua"), "utf8"))
  );
}

// ---------------------------------------------------------------------- generate and check
build({ src: repo, out: outDir, version: null, only: null });

const identity = fs.readFileSync(path.join(bundleDir, "Core", "Identity.lua"), "utf8");
const family = [...identity.match(/family = \{([\s\S]*?)\}/)[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]);
const wantFamily = ["KroolWorldForever", ...manifest.addons.map((a) => a.folder)];
if (JSON.stringify(family) !== JSON.stringify(wantFamily)) {
  fail(`KroolWorldForever/Core/Identity.lua family is\n  ${family.join(", ")}\nthe manifest wants\n  ${wantFamily.join(", ")}`);
} else console.log(`family ok: ${family.length} addon folders in the bundle's Identity.lua`);

for (const a of manifest.addons) {
  const dir = path.join(outDir, a.folder);
  const files = tocFiles(dir, a.folder);
  for (const f of files) {
    if (!fs.existsSync(path.join(dir, f))) fail(`${a.folder}: TOC lists ${f}, which was not generated`);
    else {
      try {
        luaparse.parse(fs.readFileSync(path.join(dir, f), "utf8"), { luaVersion: "5.1" });
      } catch (e) {
        fail(`${a.folder}: syntax error in ${f}: ${e.message}`);
      }
    }
  }
  if (files.some((f) => /Hub\.lua$/.test(f))) fail(`${a.folder}: the hub must not be in a standalone`);
  const toc = fs.readFileSync(path.join(dir, a.folder + "_Forever.toc"), "utf8");
  if (!toc.includes("## SavedVariables: " + (a.db || a.folder + "DB"))) fail(`${a.folder}: wrong SavedVariables`);
  if (!toc.includes("## AddonCompartmentFunc: " + a.folder + "_OnCompartmentClick")) fail(`${a.folder}: wrong compartment function`);
  if (a.bindings && !fs.existsSync(path.join(dir, "Bindings.xml"))) fail(`${a.folder}: Bindings.xml missing`);
  if (!a.bindings && fs.existsSync(path.join(dir, "Bindings.xml"))) fail(`${a.folder}: unexpected Bindings.xml`);
}
if (allOk) console.log(`generated ok: ${manifest.addons.length} standalones in ${path.relative(repo, outDir)}`);

// A release build leaves out every "held" entry (on the owner's install only) and nothing else.
{
  const releaseDir = path.join(repo, "build", "standalone-release");
  const shipped = build({ src: repo, out: releaseDir, version: null, only: null, release: true });
  const want = manifest.addons.filter((a) => !a.held).map((a) => a.folder);
  if (JSON.stringify(shipped) !== JSON.stringify(want)) fail(`release build made ${shipped.join(", ")}; want ${want.join(", ")}`);
  for (const a of manifest.addons.filter((x) => x.held)) {
    if (fs.existsSync(path.join(releaseDir, a.folder))) fail(`release build wrote held ${a.folder}`);
  }
  fs.rmSync(releaseDir, { recursive: true, force: true });
  console.log(`release build ok: ${shipped.length} shipped, held: ${manifest.addons.filter((a) => a.held).map((a) => a.folder).join(", ") || "none"}`);
}

// ---------------------------------------------------------------------- each alone
for (const a of manifest.addons) {
  const dir = path.join(outDir, a.folder);
  const suite = fs.existsSync(path.join(testDir, a.key, "stubs.lua")) ? a.key : "core";
  const st = newState(`standalone ${a.folder}`);
  let ok = loadStubs(st, suite);
  if (ok) {
    st.setGlobal("FOLDER", a.folder);
    st.setGlobal("KEY", a.key);
    lauxlib.luaL_dostring(st.L, to_luastring("__ns = {}"));
    for (const f of tocFiles(dir, a.folder)) {
      ok = st.exec(a.folder + "/" + f, fs.readFileSync(path.join(dir, f), "utf8"), a.folder);
      if (!ok) break;
    }
  }
  ok = ok && st.exec("single.lua", fs.readFileSync(path.join(__dirname, "single.lua"), "utf8"));
  allOk = st.finish(ok) && allOk;
}

// ---------------------------------------------------------------------- all together
for (const order of ["bundle first", "bundle last"]) {
  const st = newState(`collision, ${order}`);
  let ok = loadStubs(st, "setups");
  if (ok) {
    const addons = [{ folder: "KroolWorldForever", dir: bundleDir, files: tocFiles(bundleDir, "KroolWorldForever") }];
    for (const a of manifest.addons) {
      const dir = path.join(outDir, a.folder);
      addons.push({ folder: a.folder, dir, files: tocFiles(dir, a.folder) });
    }
    st.setGlobal("__addons", addons);
    st.setGlobal("ORDER", order);
    ok = st.exec("collision.lua", fs.readFileSync(path.join(__dirname, "collision.lua"), "utf8"));
  }
  allOk = st.finish(ok) && allOk;
}

console.log(allOk ? "STANDALONE TESTS PASSED" : "STANDALONE TESTS FAILED");
process.exit(allOk ? 0 : 1);
