// Kill Value data generator (Krool World Forever, feature "killvalue").
//
// Reads the cmangos classic-db full dump (github.com/cmangos/classic-db,
// Full_DB/ClassicDB_1_12_1_z2815.sql.gz: the vanilla 1.12 world database) and bakes Data.lua:
// per-creature coin range, expected item quantities (drop chance x average stack, fully
// resolved through group and reference loot semantics), skinning yields, and vendor price /
// quality / bonding for every item that can drop. Forever may have rebalanced loot, so the
// addon labels this layer "Era baseline" and blends it with what the player really loots.
//
// Usage:  node tools\killvalue-data\gen-data.js   (downloads the dump into
//         tools\killvalue-data\sqlcache on first run; delete ClassicDB.sql.gz there to refresh)
//
// The incremental Updates\*.sql files in the classic-db repo are NOT applied: they are
// arbitrary UPDATE/DELETE scripts and the full dump is the project's tested release.
//
// Loot semantics follow cmangos LootMgr:
//  * groupid 0 rows roll independently at ChanceOrQuestChance %.
//  * rows sharing a groupid > 0 yield at most ONE item: explicit-chance rows are tried in
//    turn (P = chance/100), the leftover probability is split evenly among the zero-chance
//    rows of the group.
//  * mincountOrRef < 0 references reference_loot_template entry -mincountOrRef, processed
//    maxcount times when its row is hit.
//  * negative chance = quest-conditional drop; skipped (quest items are worth 0 to us).
//  * item count is uniform in [mincountOrRef, maxcount] -> avg (min+max)/2.
"use strict";
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const { execFileSync } = require("child_process");

const CACHE = path.join(__dirname, "sqlcache");
const OUT = path.join(__dirname, "..", "..", "KroolWorldForever", "Features", "KillValue", "Data.lua");
const URL = "https://github.com/cmangos/classic-db/raw/master/Full_DB/ClassicDB_1_12_1_z2815.sql.gz";
const SOURCE_NAME = "cmangos classic-db Full_DB/ClassicDB_1_12_1_z2815 (vanilla 1.12 world db)";

fs.mkdirSync(CACHE, { recursive: true });
const gz = path.join(CACHE, "ClassicDB.sql.gz");
const sqlFile = path.join(CACHE, "ClassicDB.sql");
if (!fs.existsSync(sqlFile)) {
  if (!fs.existsSync(gz)) {
    console.log("downloading " + URL);
    execFileSync("curl", ["-sL", "-o", gz, URL], { stdio: "inherit" });
  }
  fs.writeFileSync(sqlFile, zlib.gunzipSync(fs.readFileSync(gz)));
}
const SQL = fs.readFileSync(sqlFile, "utf8");

// ---- SQL parsing -----------------------------------------------------------
// Column names (lower-cased) -> index for one table.
function columns(table) {
  const head = "CREATE TABLE `" + table + "` (";
  const at = SQL.indexOf(head);
  if (at === -1) throw new Error("no CREATE TABLE for " + table);
  const end = SQL.indexOf("\n)", at);
  const idx = {};
  let n = 0;
  for (const line of SQL.slice(at + head.length, end).split("\n")) {
    const c = line.match(/^\s*`([^`]+)`/);
    if (c) idx[c[1].toLowerCase()] = n++;
  }
  return idx;
}

// Yields one row (array of raw strings) per VALUES tuple.
function* rows(table) {
  const marker = "INSERT INTO `" + table + "` VALUES ";
  let pos = 0;
  while ((pos = SQL.indexOf(marker, pos)) !== -1) {
    pos += marker.length;
    for (;;) {
      while (SQL[pos] === "," || SQL[pos] === " " || SQL[pos] === "\n") pos++;
      if (SQL[pos] === ";") { pos++; break; }
      if (SQL[pos] !== "(") throw new Error("parse error at " + pos + " in " + table);
      pos++;
      const row = [];
      let cur = "";
      for (;;) {
        const ch = SQL[pos];
        if (ch === "'") {
          pos++;
          let s = "";
          for (;;) {
            const c = SQL[pos];
            if (c === "\\") { s += SQL[pos + 1]; pos += 2; continue; }
            if (c === "'") { if (SQL[pos + 1] === "'") { s += "'"; pos += 2; continue; } pos++; break; }
            s += c; pos++;
          }
          cur = s;
        } else if (ch === "," || ch === ")") {
          row.push(cur);
          cur = "";
          pos++;
          if (ch === ")") break;
        } else {
          cur += ch; pos++;
        }
      }
      yield row;
    }
  }
}

// ---- loot templates --------------------------------------------------------
function loadLoot(table) {
  const idx = columns(table);
  const tpl = new Map(); // entry -> [{item, chance, group, minOrRef, max}]
  for (const r of rows(table)) {
    const e = +r[idx.entry];
    const row = {
      item: +r[idx.item], chance: +r[idx.chanceorquestchance], group: +r[idx.groupid],
      minOrRef: +r[idx.mincountorref], max: +r[idx.maxcount],
    };
    if (!tpl.has(e)) tpl.set(e, []);
    tpl.get(e).push(row);
  }
  return tpl;
}

const creatureLoot = loadLoot("creature_loot_template");
const refLoot = loadLoot("reference_loot_template");
const skinLoot = loadLoot("skinning_loot_template");
console.log("loot templates: creature", creatureLoot.size, "reference", refLoot.size, "skinning", skinLoot.size);

// Expected quantity per item for one processing of a template.
// Returns Map(item -> expected count) plus Map(ref -> expected times) when flattenRefs is
// false (creature templates keep refs as pointers so shared world-drop pools are stored once).
function expand(entries, flattenRefs, depth) {
  const items = new Map();
  const refs = new Map();
  const add = (map, k, v) => map.set(k, (map.get(k) || 0) + v);
  const hit = (row, p) => {
    if (p <= 0) return;
    if (row.minOrRef < 0) {
      const ref = -row.minOrRef;
      const times = Math.max(1, row.max);
      if (flattenRefs) {
        const sub = refLoot.get(ref);
        if (!sub || depth > 8) return;
        const r = expand(sub, true, depth + 1);
        for (const [it, q] of r.items) add(items, it, p * times * q);
      } else {
        add(refs, ref, p * times);
      }
    } else {
      const avg = (row.minOrRef + row.max) / 2;
      add(items, row.item, p * avg);
    }
  };
  const groups = new Map();
  for (const row of entries) {
    if (row.chance < 0) continue; // quest-conditional drop
    if (row.group === 0) {
      if (row.chance === 0) continue; // invalid per LootMgr
      hit(row, Math.min(row.chance, 100) / 100);
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
    if (equal.length && used < 1) {
      const p = (1 - used) / equal.length;
      for (const row of equal) hit(row, p);
    }
  }
  return { items, refs };
}

// ---- creatures -------------------------------------------------------------
const cti = columns("creature_template");
const mobs = new Map(); // entry -> {gmin, gmax, lootId, skinId, lvl, rank, hp}
for (const r of rows("creature_template")) {
  const entry = +r[cti.entry];
  mobs.set(entry, {
    gmin: +r[cti.minlootgold], gmax: +r[cti.maxlootgold],
    lootId: +r[cti.lootid],
    skinId: +r[cti.skinninglootid],
    lvl: +r[cti.maxlevel], rank: +r[cti.rank],
    hp: Math.round(+r[cti.maxlevelhealth] * (+r[cti.healthmultiplier] || 1)),
  });
}
console.log("creatures:", mobs.size);

// ---- item classes (for gather-type detection) ------------------------------
// Classify a skinning template by what it yields: trade goods subclass 9 = Herb,
// 7 = Metal & Stone, anything else (leather, scales, bone) = skinning.
const iti = columns("item_template");
const itemRows = new Map(); // entry -> raw row, only filled for droppable items later
const itemKind = new Map();
for (const r of rows("item_template")) {
  const id = +r[iti.entry];
  itemRows.set(id, r);
  if (+r[iti.class] === 7) itemKind.set(id, +r[iti.subclass]);
}
function gatherPrefix(items) {
  let herb = 0, ore = 0, other = 0;
  for (const [id, q] of items) {
    const k = itemKind.get(id);
    if (k === 9) herb += q; else if (k === 7) ore += q; else other += q;
  }
  if (herb > ore && herb > other) return "H:";
  if (ore > herb && ore > other) return "M:";
  return "";
}

// ---- assemble --------------------------------------------------------------
function fmt(n) {
  if (n >= 1) return String(Math.round(n * 10000) / 10000);
  return n.toPrecision(4).replace(/\.?0+$/, "").replace(/e-(\d)$/, "e-0$1");
}
function encodeItems(map, min) {
  const parts = [];
  for (const [it, q] of [...map].sort((a, b) => b[1] - a[1] || a[0] - b[0])) {
    if (q >= min) parts.push(it + ":" + fmt(q));
  }
  return parts.join(",");
}
const MIN_Q = 1e-6;

const usedItems = new Set();
const usedRefs = new Set();
const mobLines = [];
let mobsWithData = 0;
for (const [entry, m] of [...mobs].sort((a, b) => a[0] - b[0])) {
  let drops = "", refs = "", skin = "";
  if (m.lootId && creatureLoot.has(m.lootId)) {
    const ex = expand(creatureLoot.get(m.lootId), false, 0);
    drops = encodeItems(ex.items, MIN_Q);
    for (const it of ex.items.keys()) usedItems.add(it);
    const rp = [];
    for (const [ref, t] of [...ex.refs].sort((a, b) => b[1] - a[1] || a[0] - b[0])) {
      if (t >= MIN_Q && refLoot.has(ref)) { rp.push(ref + ":" + fmt(t)); usedRefs.add(ref); }
    }
    refs = rp.join(",");
  }
  if (m.skinId && skinLoot.has(m.skinId)) {
    const ex = expand(skinLoot.get(m.skinId), true, 0);
    skin = encodeItems(ex.items, MIN_Q);
    for (const it of ex.items.keys()) usedItems.add(it);
    if (skin) skin = gatherPrefix(ex.items) + skin;
  }
  const gold = m.gmin || m.gmax ? m.gmin + ":" + m.gmax : "";
  if (!gold && !drops && !refs && !skin) continue;
  mobsWithData++;
  mobLines.push("[" + entry + "]=\"" + gold + "|" + drops + "|" + refs + "|" + skin + "|" + m.lvl + ":" + m.rank + ":" + m.hp + "\",");
}

const refLines = [];
for (const ref of [...usedRefs].sort((a, b) => a - b)) {
  const ex = expand(refLoot.get(ref), true, 0);
  for (const it of ex.items.keys()) usedItems.add(it);
  refLines.push("[" + ref + "]=\"" + encodeItems(ex.items, MIN_Q) + "\",");
}

// Per droppable item: vendor sell price (copper), and meta = quality * 16 + bonding
// (bonding 0 none, 1 pickup, 2 equip, 3 use, 4 quest).
const sellLines = [], metaLines = [];
let sellCount = 0, bopCount = 0;
for (const id of [...usedItems].sort((a, b) => a - b)) {
  const r = itemRows.get(id);
  if (!r) continue;
  const sell = +r[iti.sellprice];
  if (sell) { sellLines.push("[" + id + "]=" + sell + ","); sellCount++; }
  const bonding = +r[iti.bonding], quality = +r[iti.quality];
  if (bonding === 1) bopCount++;
  metaLines.push("[" + id + "]=" + (quality * 16 + bonding) + ",");
}

const header = [
  "-- Kill Value baseline: GENERATED by tools/killvalue-data/gen-data.js - do not edit by hand.",
  "-- Source: " + SOURCE_NAME + ".",
  "-- This is the \"Era baseline\": WoW Forever may have rebalanced loot or added creatures.",
  "-- Data.mob[creatureEntry] = \"coinMin:coinMax|item:expQty,...|refId:expTimes,...|skinItem:expQty,...|level:rank:maxHealth\"",
  "--                           rank: 0 normal, 1 elite, 2 rare elite, 3 boss, 4 rare",
  "-- Data.ref[refId]  = \"item:expQty,...\"   (reference_loot_template, fully flattened)",
  "-- Data.sell[item]  = vendor sell price in copper (only items that can drop)",
  "-- Data.meta[item]  = quality * 16 + bonding (bonding 1 pickup, 2 equip, 3 use, 4 quest)",
  "-- skin segment prefix H: / M: = gathered with Herbalism / Mining, not Skinning",
  "-- expQty = drop probability x average stack size, per kill.",
  "-- Generated " + new Date().toISOString().slice(0, 10) + ": " + mobsWithData + " creatures, " +
    refLines.length + " reference pools, " + metaLines.length + " items, " + sellCount + " sell prices, " + bopCount + " bind-on-pickup.",
  "",
  "local _, root = ...",
  "local ns = root.Feature(\"killvalue\")",
  "",
];
const out = header.join("\n") +
  "local mob = {\n" + mobLines.join("\n") + "\n}\n" +
  "local ref = {\n" + refLines.join("\n") + "\n}\n" +
  "local sell = {\n" + sellLines.join("\n") + "\n}\n" +
  "local meta = {\n" + metaLines.join("\n") + "\n}\n" +
  "ns.Data = { mob = mob, ref = ref, sell = sell, meta = meta, source = \"Era baseline (" + SOURCE_NAME + ")\", creatures = " + mobsWithData + ", items = " + metaLines.length + " }\n";
fs.writeFileSync(OUT, out);
console.log("wrote " + OUT + ": " + mobsWithData + " creatures, " + refLines.length + " refs, " +
  metaLines.length + " items, " + sellCount + " sell prices, " + bopCount + " BoP, " +
  (out.length / 1024 / 1024).toFixed(2) + " MB");
