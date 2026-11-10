// Prints the Lua errors saved for Forever, newest first: BugGrabber's, then the ones Krool World
// Forever caught itself (it never lets an error reach the client, so BugSack cannot see those; they
// are logged in KroolWorldForeverDB.errors). Both files are written on /reload, logout and exit,
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

// The newest copy of a SavedVariables file across accounts.
function findSaved(name) {
  if (!fs.existsSync(wtf)) return null;
  const out = [];
  for (const acct of fs.readdirSync(wtf, { withFileTypes: true })) {
    if (!acct.isDirectory()) continue;
    const f = path.join(wtf, acct.name, "SavedVariables", name);
    if (fs.existsSync(f)) out.push({ file: f, mtime: fs.statSync(f).mtimeMs });
  }
  return out.sort((a, b) => b.mtime - a.mtime)[0] || null;
}

// Runs a SavedVariables file (a plain Lua assignment), then `flatten`, which returns one string.
function readSaved(file, flatten) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const src = fs.readFileSync(file, "utf8");
  if (lauxlib.luaL_dostring(L, to_luastring(src)) !== lua.LUA_OK || lauxlib.luaL_dostring(L, to_luastring(flatten)) !== lua.LUA_OK) {
    console.log("Could not read " + file + ": " + to_jsstring(lua.lua_tostring(L, -1)));
    return null;
  }
  return to_jsstring(lua.lua_tostring(L, -1));
}

const matches = (text) => !filter || text.includes(filter);

// ---------------------------------------------------------------- BugGrabber
const bug = findSaved("!BugGrabber.lua");
if (!bug) {
  console.log(`No !BugGrabber.lua under ${wtf}. Is !BugGrabber enabled, and did you /reload or log out?\n`);
} else {
  const flat = readSaved(bug.file, `
local db = BugGrabberDB or {}
local errs, out = db.errors or {}, {}
local function s(v) return v == nil and "" or tostring(v) end
for _, e in ipairs(errs) do
  out[#out + 1] = table.concat({ s(e.session), s(e.time), s(e.counter), s(e.message), s(e.stack), s(e.locals) }, "\\31")
end
return s(db.session) .. "\\30" .. table.concat(out, "\\30")
`);
  if (flat !== null) {
    const [current, ...rows] = flat.split("\x1e");
    let errors = rows.filter(Boolean).map((r) => {
      const [session, time, counter, message, stack, locals] = r.split("\x1f");
      return { session: +session, time: +time, counter: +counter, message, stack, locals };
    });
    // BugGrabber counts a session per load; the saved number is the load that wrote the file.
    const latest = +current || Math.max(0, ...errors.map((e) => e.session));
    if (!all) errors = errors.filter((e) => e.session === latest);
    errors = errors.filter((e) => matches(e.message + "\n" + e.stack));
    errors.sort((a, b) => b.time - a.time);
    console.log(`${bug.file}\nsaved ${new Date(bug.mtime).toLocaleString()}, current session ${current}, showing ${all ? "all sessions" : "session " + latest}${filter ? `, filter "${filter}"` : ""}: ${errors.length} error(s)\n`);
    for (const e of errors) {
      console.log(`--- session ${e.session}, ${new Date(e.time * 1000).toLocaleString()}, x${e.counter}`);
      console.log(e.message);
      if (e.stack) console.log(e.stack.trim());
      if (showLocals && e.locals) console.log("locals:\n" + e.locals.trim());
      console.log();
    }
  }
}

// ---------------------------------------------------------------- caught by Krool World Forever
const kw = findSaved("KroolWorldForever.lua");
if (kw) {
  const flat = readSaved(kw.file, `
local db = KroolWorldForeverDB or {}
local errs, out = type(db.errors) == "table" and db.errors or {}, {}
local function s(v) return v == nil and "" or tostring(v) end
for _, e in ipairs(errs) do
  if type(e) == "table" then
    out[#out + 1] = table.concat({ s(e.session), s(e.first), s(e.last), s(e.count), s(e.feature), s(e.where), s(e.version), s(e.message), s(e.stack) }, "\\31")
  end
end
return s(db.session) .. "\\30" .. table.concat(out, "\\30")
`);
  if (flat !== null) {
    const [current, ...rows] = flat.split("\x1e");
    let errors = rows.filter(Boolean).map((r) => {
      const [session, first, last, count, feature, where, version, message, stack] = r.split("\x1f");
      return { session: +session, first: +first, last: +last, count: +count, feature, where, version, message, stack };
    });
    // The file's session is the load that wrote it: the one that just ended.
    if (!all) errors = errors.filter((e) => e.session === +current);
    errors = errors.filter((e) => matches(`${e.feature} ${e.where}\n${e.message}\n${e.stack}`));
    errors.sort((a, b) => b.last - a.last);
    const when = (t) => (t ? new Date(t * 1000).toLocaleString() : "?");
    const label = all ? "all sessions" : current ? "session " + current : "no session yet (saved before 0.15.0)";
    console.log(`${kw.file}\nsaved ${new Date(kw.mtime).toLocaleString()}, caught by the bundle, showing ${label}${filter ? `, filter "${filter}"` : ""}: ${errors.length} error(s)\n`);
    for (const e of errors) {
      console.log(`--- ${e.feature} in ${e.where}, v${e.version || "?"}, session ${e.session}, x${e.count}, last ${when(e.last)}${e.first && e.first !== e.last ? `, first ${when(e.first)}` : ""}`);
      console.log(e.message);
      if (e.stack) console.log(e.stack.trim());
      console.log();
    }
  }
}
