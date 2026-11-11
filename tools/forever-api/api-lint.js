// Checks an addon folder against the Forever API allowlist (forever-api.json):
//   - every C_Namespace.Function reference must exist, called or not (pcall(C_X.Fn) counts)
//   - the same through a local alias: after `local T = C_TradeSkillUI`, every T.Name is checked
//     until the name T is declared again in that file
//   - every RegisterEvent("NAME") / RegisterUnitEvent("NAME") must be a real event; in feature
//     files an event name passed as a variable must come from a literal list a few lines up
//     (`for _, event in ipairs({ "A", "B" }) do`), which is checked the same way
//   - every Enum.Name must exist (Enum.TooltipDataType etc.)
// Blizzard FrameXML globals (CreateFrame, Settings, TooltipDataProcessor...) and widget methods
// are not in the generated docs and are not checked. Usage: node api-lint.js <addon folder> [more]
const fs = require("fs");
const path = require("path");

const api = JSON.parse(fs.readFileSync(path.join(__dirname, "forever-api.json"), "utf8"));
const fns = new Set(api.functions);
const evs = new Set(api.events);
const ens = new Set(api.enums);
const namespaces = new Set(api.functions.map((f) => f.split(".")[0]));

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

// The line without its comment: a "--" inside a string is not a comment.
function stripComment(line) {
  let quote = null;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (quote) {
      if (ch === "\\") i++;
      else if (ch === quote) quote = null;
    } else if (ch === '"' || ch === "'") quote = ch;
    else if (ch === "-" && line[i + 1] === "-") return line.slice(0, i);
  }
  return line;
}
// The code with its string contents blanked, so text inside a string is never read as code.
function blankStrings(code) {
  return code.replace(/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'/g, (s) => s[0] + " ".repeat(s.length - 2) + s[0]);
}

let problems = 0;
for (const dir of process.argv.slice(2)) {
  for (const file of luaFiles(dir)) {
    const lines = fs.readFileSync(file, "utf8").split("\n").map(stripComment);
    const rel = path.relative(process.cwd(), file);
    const isFeature = /[\\/]Features[\\/]/.test(file);
    const alias = {}; // local name -> C_ namespace, as of the current line
    const report = (i, msg) => {
      console.log(`${rel}:${i + 1}: ${msg}`);
      problems++;
    };
    lines.forEach((code, i) => {
      const bare = blankStrings(code);
      // Aliases this line uses were set on earlier lines; then note what this line declares.
      for (const [name, nsName] of Object.entries(alias)) {
        for (const m of bare.matchAll(new RegExp(`(?<![\\w.:])${name}\\.(\\w+)`, "g"))) {
          if (!fns.has(`${nsName}.${m[1]}`)) report(i, `unknown API ${nsName}.${m[1]} (through the alias ${name})`);
        }
      }
      const decl = bare.match(/\blocal\s+(\w+)\s*=\s*(.*?)\s*$/);
      if (decl) {
        if (/^C_\w+$/.test(decl[2])) {
          alias[decl[1]] = decl[2];
          if (!namespaces.has(decl[2])) report(i, `unknown API namespace ${decl[2]}`);
        } else delete alias[decl[1]]; // the name means something else from here on
      }

      for (const m of bare.matchAll(/\b(C_\w+)\.(\w+)/g)) {
        if (!fns.has(`${m[1]}.${m[2]}`)) report(i, `unknown API ${m[1]}.${m[2]}`);
      }
      for (const m of code.matchAll(/Register(?:Unit)?Event\(\s*"(\w+)"/g)) {
        if (!evs.has(m[1])) report(i, `unknown event ${m[1]}`);
      }
      if (isFeature) {
        for (const m of bare.matchAll(/:Register(?:Unit)?Event\(\s*([A-Za-z_]\w*)\s*[,)]/g)) {
          let list = null;
          for (let j = i; j >= Math.max(0, i - 5) && !list; j--) {
            const loop = lines[j].match(new RegExp(`\\bfor\\s+\\w+\\s*,\\s*${m[1]}\\s+in\\s+ipairs\\(\\s*\\{(.*)\\}\\s*\\)`));
            if (loop) list = { text: loop[1], line: j };
          }
          if (!list) {
            report(i, `event name from the variable ${m[1]}: use a literal, or a literal list in the loop just above`);
            continue;
          }
          for (const ev of list.text.matchAll(/"(\w+)"/g)) {
            if (!evs.has(ev[1])) report(list.line, `unknown event ${ev[1]}`);
          }
        }
      }
      for (const m of bare.matchAll(/\bEnum\.(\w+)/g)) {
        if (!ens.has(m[1])) report(i, `unknown enum Enum.${m[1]}`);
      }
    });
  }
}
console.log(problems ? `api-lint: ${problems} problem(s) against Forever ${api.version}` : `api-lint: clean against Forever ${api.version}`);
process.exit(problems ? 1 : 0);
