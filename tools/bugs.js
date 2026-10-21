// Prints the Lua errors BugGrabber saved for Forever, newest first.
// BugGrabber writes WTF\Account\<account>\SavedVariables\!BugGrabber.lua on /reload, logout and exit,
// so /reload in-game before running this to flush the current session.
//   node tools\bugs.js                      errors from the latest session
//   node tools\bugs.js KroolWorldForever    only errors whose message or stack mentions that text
//   node tools\bugs.js --all [filter]       every saved session
//   node tools\bugs.js --locals [filter]    also print each error's local variables
// Needs the test deps (cd tools\test; npm install) for fengari.
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(require.resolve("fengari", {
  paths: [path.join(__dirname, "test")],
}));

const args = process.argv.slice(2);
const all = args.includes("--all");
const showLocals = args.includes("--locals");
const filter = args.find((a) => !a.startsWith("--"));
const wtf = process.env.FOREVER_WTF || "C:\\Program Files (x86)\\World of Warcraft\\_forever_\\WTF\\Account";

function findSaved() {
  if (!fs.existsSync(wtf)) return [];
  const out = [];
  for (const acct of fs.readdirSync(wtf, { withFileTypes: true })) {
    if (!acct.isDirectory()) continue;
    const f = path.join(wtf, acct.name, "SavedVariables", "!BugGrabber.lua");
    if (fs.existsSync(f)) out.push({ file: f, mtime: fs.statSync(f).mtimeMs });
  }
  return out.sort((a, b) => b.mtime - a.mtime);
}

const saved = findSaved();
if (!saved.length) {
  console.log(`No !BugGrabber.lua under ${wtf}. Is !BugGrabber enabled, and did you /reload or log out?`);
  process.exit(0);
}
const { file, mtime } = saved[0];

// The SavedVariables file is a plain Lua assignment; run it, then flatten the errors in Lua.
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const flatten = `
local db = BugGrabberDB or {}
local errs, out = db.errors or {}, {}
local function s(v) return v == nil and "" or tostring(v) end
for _, e in ipairs(errs) do
  out[#out + 1] = table.concat({ s(e.session), s(e.time), s(e.counter), s(e.message), s(e.stack), s(e.locals) }, "\\31")
end
return s(db.session) .. "\\30" .. table.concat(out, "\\30")
`;
const src = fs.readFileSync(file, "utf8");
if (lauxlib.luaL_dostring(L, to_luastring(src)) !== lua.LUA_OK || lauxlib.luaL_dostring(L, to_luastring(flatten)) !== lua.LUA_OK) {
  console.log("Could not read " + file + ": " + to_jsstring(lua.lua_tostring(L, -1)));
  process.exit(1);
}
const [current, ...rows] = to_jsstring(lua.lua_tostring(L, -1)).split("\x1e");
let errors = rows.filter(Boolean).map((r) => {
  const [session, time, counter, message, stack, locals] = r.split("\x1f");
  return { session: +session, time: +time, counter: +counter, message, stack, locals };
});
const latest = Math.max(0, ...errors.map((e) => e.session));
if (!all) errors = errors.filter((e) => e.session === latest);
if (filter) errors = errors.filter((e) => (e.message + "\n" + e.stack).includes(filter));
errors.sort((a, b) => b.time - a.time);

console.log(`${file}\nsaved ${new Date(mtime).toLocaleString()}, current session ${current}, showing ${all ? "all sessions" : "session " + latest}${filter ? `, filter "${filter}"` : ""}: ${errors.length} error(s)\n`);
for (const e of errors) {
  console.log(`--- session ${e.session}, ${new Date(e.time * 1000).toLocaleString()}, x${e.counter}`);
  console.log(e.message);
  if (e.stack) console.log(e.stack.trim());
  if (showLocals && e.locals) console.log("locals:\n" + e.locals.trim());
  console.log();
}
