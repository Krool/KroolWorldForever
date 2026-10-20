// Rewrites the settings tables in README.md (between <!-- settings:begin --> and
// <!-- settings:end -->) from the features' own declarations (ns.title, ns.description,
// ns.options, ns.slash). Loads the bundle in fengari under the Quest Trash stub client, which
// only needs to survive file scope. Never hand-edit the generated block.
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring } = require(path.join(__dirname, "test", "node_modules", "fengari"));

const repo = path.join(__dirname, "..");
const addonDir = path.join(repo, "KroolWorldForever");
const toc = fs.readFileSync(path.join(addonDir, "KroolWorldForever_Forever.toc"), "utf8");
const files = toc.split(/\r?\n/).map((l) => l.trim()).filter((l) => l && !l.startsWith("#")).map((l) => l.replace(/\\/g, "/"));

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
function run(label, src, varargs) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring("@" + label)) !== lua.LUA_OK) die(label);
  if (varargs) {
    lua.lua_pushstring(L, to_luastring("KroolWorldForever"));
    lua.lua_getglobal(L, to_luastring("__ns"));
  }
  if (lua.lua_pcall(L, varargs ? 2 : 0, varargs ? 0 : 1, 0) !== lua.LUA_OK) die(label);
}
function die(label) {
  console.error("settings-doc: " + label + ": " + lua.lua_tojsstring(L, -1));
  process.exit(1);
}

run("stubs", "print = function() end\n" + fs.readFileSync(path.join(__dirname, "test", "questtrash", "stubs.lua"), "utf8") + "\nreturn true");
lua.lua_pop(L, 1);
lua.lua_newtable(L);
lua.lua_setglobal(L, to_luastring("__ns"));
for (const f of files) run(f, fs.readFileSync(path.join(addonDir, f), "utf8"), true);

// Serialize the declarations as tab-separated lines: F <key> <title> <description> <slash>
// and O <type> <label> <default> <range> <tooltip>.
run(
  "collect",
  `local out = {}
  local function s(v) return (tostring(v == nil and "" or v):gsub("[\\t\\n]", " ")) end
  for _, key in ipairs(__ns.featureOrder) do
    local F = __ns.features[key]
    out[#out + 1] = table.concat({ "F", key, s(F.title or key), s(F.description), s(table.concat(F.slash or {}, ", ")), s(F.defaultEnabled ~= false) }, "\\t")
    for _, o in ipairs(F.options) do
      local range = o.type == "range" and (o.min .. " to " .. o.max) or ""
      out[#out + 1] = table.concat({ "O", s(o.type), s(o.label), s(o.default), s(range), s(o.tooltip) }, "\\t")
    end
  end
  return table.concat(out, "\\n")`
);
const lines = lua.lua_tojsstring(L, -1).split("\n");

const md = [];
for (const line of lines) {
  const p = line.split("\t");
  if (p[0] === "F") {
    md.push("", `### ${p[2]}`, "", p[3], "");
    md.push(`On by default: ${p[5] === "true" ? "yes" : "no"}. Toggle: \`/kwf ${p[1]} on|off\`.${p[4] ? ` Commands: \`${p[4]}\`.` : ""}`, "");
    md.push("| Setting | Default | What it does |", "|---|---|---|");
  } else if (p[0] === "O") {
    const def = p[1] === "toggle" ? (p[3] === "true" ? "On" : "Off") : `${p[3]} (${p[4]})`;
    md.push(`| ${p[2]} | ${def} | ${p[5]} |`);
  }
}

const readmePath = path.join(repo, "README.md");
const readme = fs.readFileSync(readmePath, "utf8");
const begin = "<!-- settings:begin -->";
const end = "<!-- settings:end -->";
const a = readme.indexOf(begin);
const b = readme.indexOf(end);
if (a < 0 || b < a) {
  console.error("settings-doc: README.md has no settings:begin/end markers");
  process.exit(1);
}
const next = readme.slice(0, a + begin.length) + "\n" + md.join("\n").trim() + "\n" + readme.slice(b);
if (next !== readme) {
  fs.writeFileSync(readmePath, next);
  console.log("settings-doc: README.md settings tables updated");
} else {
  console.log("settings-doc: README.md settings tables already current");
}
