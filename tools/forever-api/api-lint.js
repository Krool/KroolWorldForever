// Checks an addon folder against the Forever API allowlist (forever-api.json):
//   - every C_Namespace.Function(...) reference must exist
//   - every RegisterEvent("NAME") / RegisterUnitEvent("NAME") must be a real event
//   - every Enum.Name must exist (Enum.TooltipDataType etc.)
// Blizzard FrameXML globals (CreateFrame, Settings, TooltipDataProcessor...) are not in the
// generated docs and are not checked. Usage: node api-lint.js <addon folder> [more folders]
const fs = require("fs");
const path = require("path");

const api = JSON.parse(fs.readFileSync(path.join(__dirname, "forever-api.json"), "utf8"));
const fns = new Set(api.functions);
const evs = new Set(api.events);
const ens = new Set(api.enums);

function luaFiles(dir) {
  const out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (e.name !== "tools" && e.name !== "Libs" && e.name !== "node_modules") out.push(...luaFiles(p));
    } else if (e.name.endsWith(".lua")) out.push(p);
  }
  return out;
}

let problems = 0;
for (const dir of process.argv.slice(2)) {
  for (const file of luaFiles(dir)) {
    const lines = fs.readFileSync(file, "utf8").split("\n");
    lines.forEach((line, i) => {
      const code = line.replace(/--.*$/, "");
      const where = `${path.relative(process.cwd(), file)}:${i + 1}`;
      for (const m of code.matchAll(/\b(C_\w+)\.(\w+)\s*\(/g)) {
        if (!fns.has(`${m[1]}.${m[2]}`)) { console.log(`${where}: unknown API ${m[1]}.${m[2]}`); problems++; }
      }
      for (const m of code.matchAll(/Register(?:Unit)?Event\(\s*"(\w+)"/g)) {
        if (!evs.has(m[1])) { console.log(`${where}: unknown event ${m[1]}`); problems++; }
      }
      for (const m of code.matchAll(/\bEnum\.(\w+)/g)) {
        if (!ens.has(m[1])) { console.log(`${where}: unknown enum Enum.${m[1]}`); problems++; }
      }
    });
  }
}
console.log(problems ? `api-lint: ${problems} problem(s) against Forever ${api.version}` : `api-lint: clean against Forever ${api.version}`);
process.exit(problems ? 1 : 0);
