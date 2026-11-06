// Disenchant Value data generator (Krool World Forever, feature "disenchant").
//
// Reads the same cmangos classic-db dump as Kill Value (see classicdb.js) and bakes
// KroolWorldForever/Features/Disenchant/Data.lua:
//  * every disenchant_loot_template entry as { material, probability, min, max } rows, with the
//    cmangos LootMgr group rules resolved (rows sharing a groupid > 0 yield one item: explicit
//    chances are tried in turn, the leftover is split evenly among the zero-chance rows);
//  * bands: the table an item gets from its quality, class (weapon or armor) and item level,
//    taken as the most common DisenchantID at each item level. Forever's new items are not in
//    the 1.12 database, so the addon falls back to these;
//  * items: every 1.12 weapon and armor piece (green to purple) and every item with a
//    DisenchantID, with its entry (0 = cannot be disenchanted). Classic items stay exact even if
//    Forever reports other item levels;
//  * mats: material names, for when the client has not loaded the item yet.
//
// Usage:  node tools\killvalue-data\gen-disenchant.js
"use strict";
const fs = require("fs");
const path = require("path");
const { load, SOURCE_NAME } = require("./classicdb");

const OUT = path.join(__dirname, "..", "..", "KroolWorldForever", "Features", "Disenchant", "Data.lua");
const { columns, rows, loadLoot } = load();

const WEAPON = 2, ARMOR = 4;
const eligible = (q, cls) => (cls === WEAPON || cls === ARMOR) && q >= 2 && q <= 4;

// ---- tables ------------------------------------------------------------------
const deLoot = loadLoot("disenchant_loot_template");
const tables = new Map(); // entry -> [{item, p, min, max}]
const matIds = new Set();
for (const [entry, list] of deLoot) {
  const out = [];
  const groups = new Map();
  for (const row of list) {
    if (row.minOrRef < 0) throw new Error("reference in disenchant entry " + entry);
    if (row.group === 0) {
      if (row.chance > 0) out.push({ item: row.item, p: Math.min(row.chance, 100) / 100, min: row.minOrRef, max: row.max });
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
        if (p > 0) out.push({ item: row.item, p, min: row.minOrRef, max: row.max });
      } else equal.push(row);
    }
    if (equal.length && used < 1) {
      const p = (1 - used) / equal.length;
      for (const row of equal) out.push({ item: row.item, p, min: row.minOrRef, max: row.max });
    }
  }
  out.sort((a, b) => b.p - a.p || a.item - b.item);
  for (const r of out) matIds.add(r.item);
  tables.set(entry, out);
}
// Data fix: entry 50 (blue items of item level 69+) lists only the 0.5% Nexus Crystal and drops
// the Large Brilliant Shard the other 99.5% of the time, which entry 49 (and the classic
// disenchant tables) has. Use 49's rows.
if (tables.has(49) && tables.has(50) && tables.get(50).reduce((s, r) => s + r.p, 0) < 0.5) {
  tables.set(50, tables.get(49));
}

// ---- items and bands -----------------------------------------------------------
const it = columns("item_template");
const items = []; // {id, q, cls, il, de}
const names = new Map();
for (const r of rows("item_template")) {
  const id = +r[it.entry];
  if (matIds.has(id)) names.set(id, r[it.name]);
  const q = +r[it.quality], cls = +r[it.class], il = +r[it.itemlevel], de = +r[it.disenchantid];
  if (de && !tables.has(de)) throw new Error("item " + id + " points at missing disenchant entry " + de);
  if (eligible(q, cls) || de) items.push({ id, q, cls, il, de });
}

// Most common DisenchantID per (quality, class, item level), compressed into runs:
// bands[quality * 10 + class] = [[maxItemLevel, entry], ...]; the last run covers everything above.
const counts = new Map(); // key -> Map(il -> Map(de -> n))
for (const x of items) {
  if (!x.de || !eligible(x.q, x.cls)) continue;
  const key = x.q * 10 + x.cls;
  if (!counts.has(key)) counts.set(key, new Map());
  const byIl = counts.get(key);
  if (!byIl.has(x.il)) byIl.set(x.il, new Map());
  const m = byIl.get(x.il);
  m.set(x.de, (m.get(x.de) || 0) + 1);
}
const bands = new Map();
for (const [key, byIl] of counts) {
  const runs = [];
  for (const il of [...byIl.keys()].sort((a, b) => a - b)) {
    const best = [...byIl.get(il)].sort((a, b) => b[1] - a[1] || a[0] - b[0])[0][0];
    const last = runs[runs.length - 1];
    if (last && last[1] === best) last[0] = il;
    else runs.push([il, best]);
  }
  bands.set(key, runs);
}
function bandFor(q, cls, il) {
  const runs = bands.get(q * 10 + cls);
  if (!runs) return 0;
  for (const [max, de] of runs) if (il <= max) return de;
  return runs[runs.length - 1][1];
}

let exact = 0;
for (const x of items) {
  if ((eligible(x.q, x.cls) ? bandFor(x.q, x.cls, x.il) : 0) === x.de) exact++;
}
const listed = items.map((x) => [x.id, x.de]).sort((a, b) => a[0] - b[0]);

// ---- write ---------------------------------------------------------------------
function fmt(n) {
  return String(Math.round(n * 100000) / 100000);
}
const tableLines = [...tables].sort((a, b) => a[0] - b[0]).map(([e, list]) =>
  "[" + e + "]={" + list.map((r) => "{" + r.item + "," + fmt(r.p) + "," + r.min + "," + r.max + "}").join(",") + "},");
const bandLines = [...bands].sort((a, b) => a[0] - b[0]).map(([k, runs]) =>
  "[" + k + "]={" + runs.map((r) => "{" + r[0] + "," + r[1] + "}").join(",") + "},");
const itemLines = [];
for (let i = 0; i < listed.length; i += 12) {
  itemLines.push(listed.slice(i, i + 12).map(([id, de]) => "[" + id + "]=" + de + ",").join(""));
}
const matLines = [...names].sort((a, b) => a[0] - b[0]).map(([id, n]) => "[" + id + "]=\"" + n.replace(/"/g, '\\"') + "\",");

const header = [
  "-- Disenchant Value data: GENERATED by tools/killvalue-data/gen-disenchant.js - do not edit by hand.",
  "-- Source: " + SOURCE_NAME + ".",
  "-- WoW Forever may have changed disenchanting; this is the 1.12 baseline.",
  "-- Data.tables[entry] = { {material, probability, min, max}, ... }   (count is uniform in min..max)",
  "-- Data.bands[quality * 10 + class] = { {maxItemLevel, entry}, ... }  class 2 weapon, 4 armor;",
  "--                                   the last band covers every higher item level",
  "-- Data.items[item] = the 1.12 item's entry (0 = cannot be disenchanted); items not listed use the bands",
  "-- Data.mats[item] = material name",
  "-- Generated " + new Date().toISOString().slice(0, 10) + ": " + tables.size + " tables, " + bands.size + " band sets, " +
    items.length + " items (" + exact + " follow their band), " + names.size + " materials.",
  "",
  "local _, root = ...",
  "local ns = root.Feature(\"disenchant\")",
  "",
];
const out = header.join("\n") +
  "local tables = {\n" + tableLines.join("\n") + "\n}\n" +
  "local bands = {\n" + bandLines.join("\n") + "\n}\n" +
  "local items = {\n" + itemLines.join("\n") + "\n}\n" +
  "local mats = {\n" + matLines.join("\n") + "\n}\n" +
  "ns.Data = { tables = tables, bands = bands, items = items, mats = mats, source = \"" + SOURCE_NAME + "\" }\n";
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, out);
console.log("wrote " + OUT + ": " + tables.size + " tables, " + bands.size + " band sets, " + items.length + " items, " +
  exact + " follow their band, " + names.size + " materials, " +
  (out.length / 1024).toFixed(1) + " KB");
for (const [k, runs] of [...bands].sort((a, b) => a[0] - b[0])) console.log("  band " + k + ": " + runs.map((r) => r[0] + ":" + r[1]).join(" "));
