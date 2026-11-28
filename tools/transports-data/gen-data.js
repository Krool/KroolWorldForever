// Builds KroolWorldForever/Features/Transports/Data.lua from Forever's TaxiPathNode and TaxiNodes
// tables: where every boat and zeppelin stops, how long it waits there, and the flight master
// beside the dock, which names the town and says whose town it is.
//
//   Invoke-WebRequest "https://wago.tools/db2/TaxiPathNode/csv?build=1.60.1.71139" -OutFile tpn.csv
//   Invoke-WebRequest "https://wago.tools/db2/TaxiNodes/csv?build=1.60.1.71139" -OutFile tn.csv
//   node tools/transports-data/gen-data.js tpn.csv 1.60.1.71139 tn.csv
//
// A transport rides a taxi path like a flight does. Its stops are the nodes with the stop flag (2)
// and a Delay: the seconds it waits at the dock. A flight path has none. TaxiPathNode columns
// used: PathID, NodeIndex, ContinentID, Loc_0..2 (world x, y, z), Flags, Delay.
//
// The transports' own TaxiNodes rows say nothing of use ("Transport, Menethil Ships", no faction,
// and Forever's new paths have none). A flight master's row does: Name_lang ("Booty Bay,
// Stranglethorn"), Pos_0..1, ContinentID and Flags (1 Alliance, 2 Horde). A stop takes the town of
// the nearest flight master within TOWN yards. Its side is the one side every flight master in
// that range belongs to; a town with both (Booty Bay, Ratchet) has none.
//
// What the tables cannot say: whether the server runs a path, how fast a transport sails, and who
// may ride. A route that turns out not to exist goes in SKIP below, with the date and who saw it.
const fs = require("fs");
const path = require("path");

const [csvPath, build, nodesPath] = process.argv.slice(2);
if (!csvPath || !build || !nodesPath) {
  console.error("usage: node gen-data.js <TaxiPathNode.csv> <build, e.g. 1.60.1.71139> <TaxiNodes.csv>");
  process.exit(1);
}

// Paths left out on purpose: { [PathID]: "why" }.
const SKIP = {};

const SAME_STOP = 30; // yards: one dock listed twice on a path (a round trip's start and end)
const TOWN = 550; // yards: a flight master this close names the dock's town

// A dock farther than TOWN from its town's flight master: { path, continent, name (TaxiNodes) }.
const TOWN_BY_HAND = [
  // Stormwind's harbor, 884 yards from the flight master. The owner named the route, 2026-11-18.
  { path: 11616, continent: 0, name: "Stormwind, Elwynn" },
];

// A CSV with quoted fields (TaxiNodes names hold commas).
function readCsv(file) {
  const text = fs.readFileSync(file, "utf8");
  const rows = [];
  let row = [];
  let cur = "";
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') {
        cur += '"';
        i++;
      } else if (c === '"') quoted = false;
      else cur += c;
    } else if (c === '"') quoted = true;
    else if (c === ",") {
      row.push(cur);
      cur = "";
    } else if (c === "\n") {
      row.push(cur);
      rows.push(row);
      row = [];
      cur = "";
    } else if (c !== "\r") cur += c;
  }
  if (cur !== "" || row.length) {
    row.push(cur);
    rows.push(row);
  }
  const header = rows.shift();
  const col = (name) => {
    const i = header.indexOf(name);
    if (i < 0) throw new Error(path.basename(file) + " has no column " + name);
    return i;
  };
  return { rows: rows.filter((r) => r.length === header.length), col };
}

// Flight masters: the rows a faction can fly from. "zzOLD" rows are leftovers.
const tn = readCsv(nodesPath);
const N = { name: tn.col("Name_lang"), x: tn.col("Pos_0"), y: tn.col("Pos_1"), id: tn.col("ID"), continent: tn.col("ContinentID"), flags: tn.col("Flags") };
const masters = tn.rows
  .map((r) => ({ id: +r[N.id], name: r[N.name], continent: +r[N.continent], x: +r[N.x], y: +r[N.y], side: +r[N.flags] & 3 }))
  .filter((n) => n.side !== 0 && !/^zzOLD/i.test(n.name));

const tpn = readCsv(csvPath);
const C = {
  path: tpn.col("PathID"),
  index: tpn.col("NodeIndex"),
  continent: tpn.col("ContinentID"),
  x: tpn.col("Loc_0"),
  y: tpn.col("Loc_1"),
  z: tpn.col("Loc_2"),
  flags: tpn.col("Flags"),
  delay: tpn.col("Delay"),
};

const byPath = new Map();
for (const f of tpn.rows) {
  const node = {
    path: +f[C.path],
    index: +f[C.index],
    continent: +f[C.continent],
    x: +f[C.x],
    y: +f[C.y],
    z: +f[C.z],
    wait: +f[C.delay],
    stop: (+f[C.flags] & 2) !== 0 && +f[C.delay] > 0,
  };
  if (!byPath.has(node.path)) byPath.set(node.path, []);
  byPath.get(node.path).push(node);
}

// The town a stop stands in, and whose it is.
function townOf(stop) {
  const near = masters
    .filter((m) => m.continent === stop.continent)
    .map((m) => ({ m, d: Math.hypot(m.x - stop.x, m.y - stop.y) }))
    .sort((a, b) => a.d - b.d);
  const hand = TOWN_BY_HAND.find((h) => h.path === stop.path && h.continent === stop.continent);
  if (hand) {
    const m = masters.find((n) => n.name === hand.name);
    if (!m) throw new Error("TOWN_BY_HAND: TaxiNodes has no flight master named " + hand.name);
    return { node: m.id, name: m.name, side: masters.filter((n) => n.name === hand.name).reduce((s, n) => s | n.side, 0) };
  }
  const close = near.filter((o) => o.d <= TOWN);
  if (close.length === 0) return null;
  return { node: close[0].m.id, name: close[0].m.name, side: close.reduce((s, o) => s | o.m.side, 0) };
}

const routes = [];
for (const id of [...byPath.keys()].sort((a, b) => a - b)) {
  if (SKIP[id]) continue;
  const stops = [];
  for (const n of byPath.get(id).sort((a, b) => a.index - b.index)) {
    if (!n.stop) continue;
    const seen = stops.find((s) => s.continent === n.continent && Math.hypot(s.x - n.x, s.y - n.y) < SAME_STOP);
    if (seen) seen.wait += n.wait; // a round trip's start and end: one wait, split in two
    else stops.push(n);
  }
  if (stops.length >= 2) routes.push({ id, stops }); // one stop is not a trip (Naxxramas' path)
}

const num = (v) => String(Math.round(v * 10) / 10);
const str = (v) => '"' + v.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
const SIDE = { 1: "A", 2: "H" };
const out = [];
out.push("-- Generated by tools/transports-data/gen-data.js from Forever's TaxiPathNode and TaxiNodes");
out.push(`-- (wago.tools, build ${build}). Do not edit by hand.`);
out.push("-- routes[n] = { path = the taxi path the transport rides, stops = { { continent, x, y, z,");
out.push("--   wait =, node =, town =, side = }, ... } }");
out.push("-- A stop is where it waits at a dock, in world coordinates. z is the deck's height: sea level");
out.push("-- for a boat, a tower's for a zeppelin. wait: the seconds it stays. node: the flight master");
out.push("-- beside the dock (TaxiNodes id), town: that flight master's town in English, for when the");
out.push('-- client names none. side: "A" or "H" when every flight master there is that side\'s.');
out.push("");
out.push("local _, root = ...");
out.push('local ns = root.Feature("transports")');
out.push("");
out.push("ns.Data = {");
out.push(`\tbuild = "${build}",`);
out.push("\troutes = {");
let towns = 0;
for (const r of routes) {
  out.push(`\t\t{ path = ${r.id}, stops = {`);
  for (const s of r.stops) {
    const fields = [s.continent, num(s.x), num(s.y), num(s.z), `wait = ${s.wait}`];
    const town = townOf(s);
    if (town) {
      towns++;
      fields.push(`node = ${town.node}`, `town = ${str(town.name.split(",")[0].trim())}`);
      if (SIDE[town.side]) fields.push(`side = "${SIDE[town.side]}"`);
    }
    out.push(`\t\t\t{ ${fields.join(", ")} },`);
  }
  out.push("\t\t} },");
}
out.push("\t},");
out.push("}");
out.push("");

const target = path.join(__dirname, "..", "..", "KroolWorldForever", "Features", "Transports", "Data.lua");
fs.mkdirSync(path.dirname(target), { recursive: true });
fs.writeFileSync(target, out.join("\n"));
const total = routes.reduce((n, r) => n + r.stops.length, 0);
console.log(`wrote ${routes.length} routes, ${total} stops (${towns} with a town) to ${target}`);
