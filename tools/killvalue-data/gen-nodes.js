// Kill Value node data generator (Krool World Forever, feature "killvalue").
//
// Bakes Features/KillValue/Nodes.lua: the expected yield of every herb, mining vein and fishing
// pool, keyed by the name its world tooltip shows. Loot comes from the cmangos classic-db vanilla
// world database (the same "Era baseline" as Data.lua); the skill a node needs comes from
// Forever's own Lock table for the given build (wago.tools db2 CSV, cached in
// tools/killvalue-data/cache/<build>, git-ignored).
//
// Usage:  node tools\killvalue-data\gen-nodes.js <build>      e.g. 1.60.1.70959
//
// Per node:
//  * gameobject type 3 (chest): data0 lock, data1 loot, data4..data5 successful opens. Veins
//    open 2 to 4 times (cmangos: the minimum is certain, each further mine is a roll), herbs once.
//  * gameobject type 25 (fishing hole): data1 loot, data2..data3 catches, data4 lock.
//  * expected quantity per node = loot expanded (same rules as gen-data.js) x average opens.
//  * Lock rows of type 2 (skill) with index 2 = Herbalism, 3 = Mining give the kind and the
//    skill. A chest whose lock says neither is not a node (lockboxes, quest objects).
//  * Several templates share one name (Copper Vein has five). They are averaged, weighted by
//    their spawns in the world database; a name with no spawns averages its templates evenly.
//  * Nodes whose loot is only quest items are dropped (quest gatherables such as Doom Weed).
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const { load, SOURCE_NAME } = require("./classicdb");

const build = process.argv[2];
if (!/^\d+\.\d+\.\d+\.\d+$/.test(build || "")) {
  console.error("usage: node gen-nodes.js <build>   (e.g. 1.60.1.70959)");
  process.exit(1);
}
const OUT = path.join(__dirname, "..", "..", "KroolWorldForever", "Features", "KillValue", "Nodes.lua");

// ---- Forever's Lock table --------------------------------------------------
function lockTable() {
  const dir = path.join(__dirname, "cache", build);
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, "Lock.csv");
  if (!fs.existsSync(file)) {
    const url = `https://wago.tools/db2/Lock/csv?build=${build}`;
    console.log("downloading " + url);
    execFileSync("curl", ["-sfL", "-o", file, url], { stdio: "inherit" });
  }
  const lines = fs.readFileSync(file, "utf8").split(/\r?\n/).filter(Boolean);
  const head = lines.shift().split(",");
  if (head[0] !== "ID" || !head.includes("Skill_0")) throw new Error("Lock.csv: unexpected header (wrong build?)");
  const col = (name) => head.indexOf(name);
  const locks = new Map();
  for (const line of lines) {
    const f = line.split(",");
    const slots = [];
    for (let i = 0; i < 8; i++) {
      slots.push({ index: +f[col("_Index_" + i)], skill: +f[col("Skill_" + i)], type: +f[col("Type_" + i)] });
    }
    locks.set(+f[0], slots);
  }
  return locks;
}
const locks = lockTable();
console.log("Lock rows (" + build + "):", locks.size);

const LOCK_KIND = { 2: "H", 3: "M" }; // LockType: 2 Herbalism, 3 Mining
function lockKind(lockId) {
  for (const s of locks.get(lockId) || []) {
    if (s.type === 2 && LOCK_KIND[s.index]) return { kind: LOCK_KIND[s.index], skill: s.skill };
  }
  return null;
}

// ---- world database ---------------------------------------------------------
const { columns, rows, loadLoot } = load();
const goLoot = loadLoot("gameobject_loot_template");
const refLoot = loadLoot("reference_loot_template");

// Expected quantity per item for one processing of a template, references flattened.
// Same rules as gen-data.js (cmangos LootMgr).
function expand(entries, depth) {
  const items = new Map();
  const add = (k, v) => items.set(k, (items.get(k) || 0) + v);
  const hit = (row, p) => {
    if (p <= 0) return;
    if (row.minOrRef < 0) {
      const sub = refLoot.get(-row.minOrRef);
      if (!sub || depth > 8) return;
      const times = Math.max(1, row.max);
      for (const [it, q] of expand(sub, depth + 1)) add(it, p * times * q);
    } else add(row.item, p * (row.minOrRef + row.max) / 2);
  };
  const groups = new Map();
  for (const row of entries) {
    if (row.chance < 0) continue; // quest-conditional
    if (row.group === 0) {
      if (row.chance > 0) hit(row, Math.min(row.chance, 100) / 100);
    } else {
      if (!groups.has(row.group)) groups.set(row.group, []);
      groups.get(row.group).push(row);
    }
  }
  for (const g of groups.values()) {
    let used = 0;
    const equal = [];
    for (const row of g) {
      if (row.chance > 0) {
        const p = Math.min(row.chance / 100, Math.max(0, 1 - used));
        used += p;
        hit(row, p);
      } else equal.push(row);
    }
    if (equal.length && used < 1) for (const row of equal) hit(row, (1 - used) / equal.length);
  }
  return items;
}

const spawns = new Map();
const gc = columns("gameobject");
for (const r of rows("gameobject")) spawns.set(+r[gc.id], (spawns.get(+r[gc.id]) || 0) + 1);

const iti = columns("item_template");
const itemRows = new Map();
for (const r of rows("item_template")) itemRows.set(+r[iti.entry], r);
const isQuest = (id) => {
  const r = itemRows.get(id);
  return !r || +r[iti.class] === 12 || +r[iti.bonding] === 4;
};

const avgOpens = (min, max) => {
  if (max < min) max = min;
  return Math.max(1, (min + max) / 2);
};

const gi = columns("gameobject_template");
const byName = new Map(); // name -> { kind, skill, templates: [{entry, weight, opens, items}] }
let skipped = 0;
for (const r of rows("gameobject_template")) {
  const type = +r[gi.type];
  const d = (i) => +r[gi["data" + i]];
  let kind, skill, lootId, opens;
  if (type === 3) {
    const k = lockKind(d(0));
    if (!k) continue;
    kind = k.kind; skill = k.skill; lootId = d(1); opens = avgOpens(d(4), d(5));
  } else if (type === 25) {
    kind = "F"; skill = 0; lootId = d(1); opens = avgOpens(d(2), d(3));
  } else continue;
  const loot = goLoot.get(lootId);
  if (!loot) continue;
  const items = expand(loot, 0);
  if (![...items.keys()].some((id) => !isQuest(id))) { skipped++; continue; }
  const name = r[gi.name];
  if (!byName.has(name)) byName.set(name, { kind, skill, templates: [] });
  const n = byName.get(name);
  if (n.kind !== kind) throw new Error(name + ": templates of two kinds (" + n.kind + ", " + kind + ")");
  n.skill = Math.max(n.skill, skill);
  n.templates.push({ entry: +r[gi.entry], spawns: spawns.get(+r[gi.entry]) || 0, opens, items });
}

// ---- assemble ----------------------------------------------------------------
function fmt(n) {
  if (n >= 1) return String(Math.round(n * 10000) / 10000);
  return n.toPrecision(4).replace(/\.?0+$/, "").replace(/e-(\d)$/, "e-0$1");
}
const MIN_Q = 1e-6;
const nodeLines = [], idLines = [];
const usedItems = new Set();
const counts = { H: 0, M: 0, F: 0 };
const lua = (s) => '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
for (const [name, n] of [...byName].sort((a, b) => (a[0] < b[0] ? -1 : 1))) {
  const total = n.templates.reduce((s, t) => s + t.spawns, 0);
  const weight = (t) => (total > 0 ? t.spawns / total : 1 / n.templates.length);
  const qty = new Map();
  let opens = 0;
  for (const t of n.templates) {
    const w = weight(t);
    if (w === 0) continue;
    opens += w * t.opens;
    for (const [id, q] of t.items) qty.set(id, (qty.get(id) || 0) + w * q * t.opens);
  }
  const parts = [];
  for (const [id, q] of [...qty].sort((a, b) => b[1] - a[1] || a[0] - b[0])) {
    if (q >= MIN_Q && !isQuest(id)) { parts.push(id + ":" + fmt(q)); usedItems.add(id); }
  }
  counts[n.kind]++;
  nodeLines.push("[" + lua(name) + "]=\"" + n.kind + ":" + n.skill + ":" + fmt(opens) + "|" + parts.join(",") + "\",");
  for (const t of n.templates.sort((a, b) => a.entry - b.entry)) idLines.push("[" + t.entry + "]=" + lua(name) + ",");
}

const sellLines = [], metaLines = [];
for (const id of [...usedItems].sort((a, b) => a - b)) {
  const r = itemRows.get(id);
  const sell = +r[iti.sellprice];
  if (sell) sellLines.push("[" + id + "]=" + sell + ",");
  metaLines.push("[" + id + "]=" + (+r[iti.quality] * 16 + +r[iti.bonding]) + ",");
}

const header = [
  "-- Kill Value node baseline: GENERATED by tools/killvalue-data/gen-nodes.js - do not edit by hand.",
  "-- Loot: " + SOURCE_NAME + ". Skills: Forever's Lock table, build " + build + " (wago.tools).",
  "-- Nodes.node[name] = \"kind:skill:opens|item:expQty,...\"  kind H herb, M vein, F fishing pool;",
  "--   skill = Herbalism or Mining needed (0 = none); opens = average loots per node (veins 2 to 4,",
  "--   pools by their catches); expQty = expected quantity per node, all opens counted.",
  "-- Nodes.id[gameobjectEntry] = name, for a GameObject GUID's 6th field.",
  "-- Nodes.sell / Nodes.meta: vendor price and quality * 16 + bonding for every node item.",
  "-- " + counts.H + " herbs, " + counts.M + " veins, " + counts.F + " pools, " + usedItems.size + " items.",
  "",
  "local _, root = ...",
  "local ns = root.Feature(\"killvalue\")",
  "",
];
const out = header.join("\n") +
  "local node = {\n" + nodeLines.join("\n") + "\n}\n" +
  "local id = {\n" + idLines.join("\n") + "\n}\n" +
  "local sell = {\n" + sellLines.join("\n") + "\n}\n" +
  "local meta = {\n" + metaLines.join("\n") + "\n}\n" +
  "ns.Nodes = { node = node, id = id, sell = sell, meta = meta, build = \"" + build + "\", herbs = " + counts.H +
  ", veins = " + counts.M + ", pools = " + counts.F + " }\n";
fs.writeFileSync(OUT, out);
console.log("wrote " + OUT + ": " + counts.H + " herbs, " + counts.M + " veins, " + counts.F + " pools, " +
  usedItems.size + " items (" + skipped + " quest-only templates skipped), " + (out.length / 1024).toFixed(1) + " KB");
