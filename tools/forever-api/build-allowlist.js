// Builds forever-api.json from a checkout of Gethe/wow-ui-source (branch "forever").
// Only the generated API documentation is read, so a sparse checkout is enough:
//   git clone --depth 1 --filter=blob:none --sparse -b forever https://github.com/Gethe/wow-ui-source ui
//   git -C ui sparse-checkout set Interface/AddOns/Blizzard_APIDocumentationGenerated
//   node tools/forever-api/build-allowlist.js <path-to-ui>
// The list is what api-lint.js checks addon code against.
const fs = require("fs");
const path = require("path");

const uiRoot = process.argv[2];
if (!uiRoot) {
  console.error("usage: node build-allowlist.js <wow-ui-source checkout>");
  process.exit(1);
}
const docDir = path.join(uiRoot, "Interface", "AddOns", "Blizzard_APIDocumentationGenerated");
const versionFile = path.join(uiRoot, "version.txt");

const functions = new Set(); // "C_QuestLog.IsQuestFlaggedCompleted" or bare "UnitGUID"
const events = new Set(); // "QUEST_LOG_UPDATE"
const enums = new Set(); // "ItemClass"

for (const file of fs.readdirSync(docDir)) {
  if (!file.endsWith(".lua")) continue;
  const src = fs.readFileSync(path.join(docDir, file), "utf8");
  const ns = (src.match(/Namespace = "(\w+)"/) || [])[1];
  const fnBlock = src.split(/\n\tEvents =|\n\tTables =/)[0];
  for (const m of fnBlock.matchAll(/Name = "(\w+)",\s*\n\s*Type = "Function"/g)) {
    functions.add(ns ? `${ns}.${m[1]}` : m[1]);
  }
  for (const m of src.matchAll(/LiteralName = "(\w+)"/g)) events.add(m[1]);
  for (const m of src.matchAll(/Name = "(\w+)",\s*\n\s*Type = "Enumeration"/g)) enums.add(m[1]);
}

const version = fs.existsSync(versionFile) ? fs.readFileSync(versionFile, "utf8").trim() : "unknown";
const out = {
  source: "Gethe/wow-ui-source forever branch, Blizzard_APIDocumentationGenerated",
  version,
  functions: [...functions].sort(),
  events: [...events].sort(),
  enums: [...enums].sort(),
};
fs.writeFileSync(path.join(__dirname, "forever-api.json"), JSON.stringify(out, null, 1) + "\n");
console.log(`forever-api.json: build ${version}, ${out.functions.length} functions, ${out.events.length} events, ${out.enums.length} enums`);
