// Shared reader for the cmangos classic-db full dump (github.com/cmangos/classic-db,
// Full_DB/ClassicDB_1_12_1_z2815.sql.gz: the vanilla 1.12 world database). Used by the Kill
// Value and Disenchant Value data generators. Downloads the dump into sqlcache on first use;
// delete ClassicDB.sql.gz there to refresh.
"use strict";
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const { execFileSync } = require("child_process");

const CACHE = path.join(__dirname, "sqlcache");
const URL = "https://github.com/cmangos/classic-db/raw/master/Full_DB/ClassicDB_1_12_1_z2815.sql.gz";
const SOURCE_NAME = "cmangos classic-db Full_DB/ClassicDB_1_12_1_z2815 (vanilla 1.12 world db)";

function load() {
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

  // entry -> [{item, chance, group, minOrRef, max}] for a *_loot_template table.
  function loadLoot(table) {
    const idx = columns(table);
    const tpl = new Map();
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

  return { columns, rows, loadLoot };
}

module.exports = { load, SOURCE_NAME };
