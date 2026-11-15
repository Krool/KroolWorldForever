// Builds KroolWorldForever/Features/ReagentUses/Data.lua: every Forever recipe, what it uses, what it makes, and where it is
// learned.
//
//   node tools/reagents-data/gen-data.js 1.60.1.70938
//
// Two sources:
// - Forever's own client tables for that build (wago.tools db2 CSVs, cached in tools/reagents-data/cache, git-ignored):
//   SkillLineAbility (recipe -> profession, yellow and grey skill), TradeSkillCategory (which
//   recipes the profession window lists), SpellReagents (materials), SpellEffect (created item,
//   learn effects), ItemEffect + ItemXItemEffect (recipe items), ItemSparse (item exists, recipe
//   item's required skill), SkillLine (profession names), SpellName (drops unnamed and test spells).
// - The cmangos classic-db dump (classicdb.js) for what the client does not hold: trainer learn
//   levels, and whether a recipe item is sold, dropped, fished or a quest reward. Vanilla data, so it
//   only fills gaps; Forever's own numbers win wherever both exist.
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const classicdb = require("../killvalue-data/classicdb.js"); // its sqlcache/ is shared with the Kill Value generators

const build = process.argv[2];
if (!/^\d+\.\d+\.\d+\.\d+$/.test(build || "")) {
  console.error("usage: node tools/reagents-data/gen-data.js <build, e.g. 1.60.1.70938>");
  process.exit(1);
}

const TABLES = [
  "SkillLineAbility", "TradeSkillCategory", "SpellReagents", "SpellEffect",
  "ItemEffect", "ItemXItemEffect", "ItemSparse", "SkillLine", "SpellName",
];
const CACHE = path.join(__dirname, "cache", build);
fs.mkdirSync(CACHE, { recursive: true });

// RFC 4180-ish: quoted fields may hold commas, doubled quotes and newlines.
function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = "";
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ",") { row.push(field); field = ""; }
    else if (c === "\n" || c === "\r") {
      if (c === "\r" && text[i + 1] === "\n") i++;
      row.push(field); rows.push(row); row = []; field = "";
    } else field += c;
  }
  if (field !== "" || row.length) { row.push(field); rows.push(row); }
  return rows;
}

function table(name, fromBuild = build) {
  const dir = path.join(__dirname, "cache", fromBuild);
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, name + ".csv");
  if (!fs.existsSync(file)) {
    const url = `https://wago.tools/db2/${name}/csv?build=${fromBuild}`;
    console.log("downloading " + url);
    execFileSync("curl", ["-sfL", "-o", file, url], { stdio: "inherit" });
  }
  const rows = parseCsv(fs.readFileSync(file, "utf8"));
  const head = rows.shift();
  if (!head || head.length < 2) throw new Error(name + ": empty table (wrong build?)");
  return rows
    .filter((r) => r.length >= head.length)
    .map((r) => {
      const o = {};
      head.forEach((k, i) => (o[k] = r[i]));
      return o;
    });
}

const T = {};
for (const name of TABLES) T[name] = table(name);
const num = (v) => Number(v) || 0;

// Classic Era's thresholds: Forever moved many recipes' yellow (and their learn level with it, as its
// recipe items show), so a vanilla trainer level is shifted by the same amount.
const ERA_BUILD = "1.15.9.70576";
const eraYellow = new Map();
for (const r of table("SkillLineAbility", ERA_BUILD)) {
  const y = num(r.TrivialSkillLineRankLow);
  if (y > 0 && !eraYellow.has(num(r.Spell))) eraYellow.set(num(r.Spell), y);
}

// ------------------------------------------------------------------ Forever: which recipes exist

const items = new Map(); // item id -> ItemSparse row (only items the client knows)
for (const r of T.ItemSparse) if (r.Display_lang) items.set(num(r.ID), r);

const categories = new Map(T.TradeSkillCategory.map((r) => [num(r.ID), r]));
const lineNames = new Map(T.SkillLine.map((r) => [num(r.ID), r.DisplayName_lang]));
const spellNames = new Map(T.SpellName.map((r) => [num(r.ID), r.Name_lang]));
// Blizzard's internal markers: "[DNT]" (do not translate), "(Test)".
const TEST = /\[DNT\]|\(Test\)|^Test /;

// A recipe is one the profession window lists: its category sits under a profession (Season of
// Discovery's leftover recipes have their own parentless "SEASON OF DISCOVERY" categories).
const recipes = new Map(); // spell -> { line, yellow, grey, cat, acquire }
const skipped = { noCategory: 0, seasonal: 0, dupe: 0, test: 0 };
for (const r of T.SkillLineAbility) {
  const spell = num(r.Spell);
  const cat = categories.get(num(r.TradeSkillCategoryID));
  if (!spell || !cat) { skipped.noCategory++; continue; }
  if (!num(cat.ParentTradeSkillCategoryID)) { skipped.seasonal++; continue; }
  if (recipes.has(spell)) { skipped.dupe++; continue; }
  const name = spellNames.get(spell);
  if (!name || TEST.test(name) || TEST.test(lineNames.get(num(r.SkillLine)) || "")) { skipped.test++; continue; }
  recipes.set(spell, {
    line: num(r.SkillLine),
    child: num(cat.SkillLineID),
    yellow: num(r.TrivialSkillLineRankLow),
    grey: num(r.TrivialSkillLineRankHigh),
    acquire: num(r.AcquireMethod),
    sources: new Set(),
    learn: 0,
    result: 0,
    reagents: [],
  });
}

const effects = new Map(); // spell -> SpellEffect rows
for (const r of T.SpellEffect) {
  const s = num(r.SpellID);
  if (!effects.has(s)) effects.set(s, []);
  effects.get(s).push(r);
}
const LEARN_SPELL = 36;
const CREATE_ITEM = 24;

// The recipe a spell teaches: itself, or what its learn effect points at.
function taughtBy(spell, effectsOf) {
  if (recipes.has(spell)) return [spell];
  const out = [];
  for (const e of effectsOf(spell)) if (recipes.has(e.learn)) out.push(e.learn);
  return out;
}
const foreverEffects = (s) =>
  (effects.get(s) || []).filter((e) => num(e.Effect) === LEARN_SPELL).map((e) => ({ learn: num(e.EffectTriggerSpell) }));

for (const [spell, rec] of recipes) {
  for (const e of effects.get(spell) || []) {
    if (num(e.Effect) === CREATE_ITEM && num(e.EffectItemType) > 0) {
      rec.result = num(e.EffectItemType);
      break;
    }
  }
}

const reagentRows = new Map();
for (const r of T.SpellReagents) {
  const s = num(r.SpellID);
  if (!recipes.has(s)) continue;
  const list = reagentRows.get(s) || new Map();
  for (let i = 0; i < 8; i++) {
    const item = num(r["Reagent_" + i]);
    const count = num(r["ReagentCount_" + i]);
    if (item > 0 && count > 0) list.set(item, Math.max(list.get(item) || 0, count));
  }
  reagentRows.set(s, list);
}
for (const [s, list] of reagentRows) recipes.get(s).reagents = [...list.entries()].sort((a, b) => a[0] - b[0]);

// Recipe items: an item effect that teaches (trigger 6), directly or through a learn spell.
const effectItem = new Map(T.ItemXItemEffect.map((r) => [num(r.ItemEffectID), num(r.ItemID)]));
const recipeItems = new Map(); // recipe -> Set(item ids the client knows)
const ghostItems = new Map(); // recipe -> count of teaching items the client does NOT know
for (const r of T.ItemEffect) {
  if (num(r.TriggerType) !== 6) continue;
  const item = effectItem.get(num(r.ID));
  if (!item) continue;
  for (const recipe of taughtBy(num(r.SpellID), foreverEffects)) {
    if (items.has(item)) {
      if (!recipeItems.has(recipe)) recipeItems.set(recipe, new Set());
      recipeItems.get(recipe).add(item);
    } else {
      ghostItems.set(recipe, (ghostItems.get(recipe) || 0) + 1);
    }
  }
}

// ------------------------------------------------------------------ classic: trainers and sources

const db = classicdb.load();
const col = db.columns;

const classicLearn = new Map(); // classic spell -> [recipe ids it teaches]
{
  const c = col("spell_template");
  for (const r of db.rows("spell_template")) {
    const id = +r[c.id];
    for (const n of [1, 2, 3]) {
      if (+r[c["effect" + n]] === LEARN_SPELL) {
        const learn = +r[c["effecttriggerspell" + n]];
        if (recipes.has(learn)) {
          if (!classicLearn.has(id)) classicLearn.set(id, []);
          classicLearn.get(id).push(learn);
        }
      }
    }
  }
}
const classicTaught = (spell) => (recipes.has(spell) ? [spell] : classicLearn.get(spell) || []);

const trainerLevel = new Map(); // recipe -> lowest trainer skill requirement
for (const t of ["npc_trainer", "npc_trainer_template"]) {
  const c = col(t);
  for (const r of db.rows(t)) {
    for (const recipe of classicTaught(+r[c.spell])) {
      const lvl = +r[c.reqskillvalue] || 1;
      if (!trainerLevel.has(recipe) || lvl < trainerLevel.get(recipe)) trainerLevel.set(recipe, lvl);
    }
  }
}

const questSpells = new Set();
const itemSources = new Map(); // item -> Set of letters
const mark = (item, letter) => {
  if (!itemSources.has(item)) itemSources.set(item, new Set());
  itemSources.get(item).add(letter);
};
{
  const c = col("quest_template");
  for (const r of db.rows("quest_template")) {
    for (const k of ["rewspell", "rewspellcast"]) {
      for (const recipe of classicTaught(+r[c[k]])) questSpells.add(recipe);
    }
    for (const k of ["rewitemid1", "rewitemid2", "rewitemid3", "rewitemid4",
      "rewchoiceitemid1", "rewchoiceitemid2", "rewchoiceitemid3", "rewchoiceitemid4", "rewchoiceitemid5", "rewchoiceitemid6"]) {
      const item = +r[c[k]];
      if (item > 0) mark(item, "Q");
    }
  }
}
for (const t of ["npc_vendor", "npc_vendor_template"]) {
  const c = col(t);
  for (const r of db.rows(t)) mark(+r[c.item], "V");
}
const LOOT = {
  creature_loot_template: "D", reference_loot_template: "D", gameobject_loot_template: "D",
  item_loot_template: "D", pickpocketing_loot_template: "D", fishing_loot_template: "F",
};
for (const [t, letter] of Object.entries(LOOT)) {
  const c = col(t);
  for (const r of db.rows(t)) {
    if (+r[c.mincountorref] < 0) continue; // a reference row: "item" is a reference id
    mark(+r[c.item], letter);
  }
}

// ------------------------------------------------------------------ merge

// Source letters, in display order: S starter (known with the profession), T trainer, V vendor,
// D drop, F fishing, Q quest, R recipe item from an unknown place.
const ORDER = "STVDFQR";
const dropped = { ghostOnly: 0, noReagents: 0 };
const droppedNames = [];
let hiddenResults = 0;
let shifted = 0;
for (const [spell, rec] of [...recipes]) {
  const known = recipeItems.get(spell);
  // Every item that teaches it is gone from the client, and nothing else does: never obtainable
  // (vanilla's Green Woolen Robe and friends), or a Forever addition not out yet.
  if (!known && ghostItems.has(spell) && !trainerLevel.has(spell) && !questSpells.has(spell) && rec.acquire === 0) {
    recipes.delete(spell);
    dropped.ghostOnly++;
    droppedNames.push(spellNames.get(spell) + " (" + spell + ")");
    continue;
  }
  // Forever hides some crafted items (its new set pieces) while their recipe items are out: keep the
  // recipe, without the item it makes.
  if (rec.result && !items.has(rec.result)) {
    rec.result = 0;
    hiddenResults++;
  }
  if (rec.acquire === 1 || rec.acquire === 2) rec.sources.add("S");
  if (trainerLevel.has(spell)) rec.sources.add("T");
  if (questSpells.has(spell)) rec.sources.add("Q");
  let itemLearn = 0;
  for (const item of known || []) {
    const from = itemSources.get(item);
    if (from && from.size) for (const l of from) rec.sources.add(l);
    else rec.sources.add("R");
    const req = num(items.get(item).RequiredSkillRank);
    if (req > 0 && (!itemLearn || req < itemLearn)) itemLearn = req;
  }
  // Forever's recipe item wins. A vanilla trainer level moves by as much as Forever moved the yellow
  // threshold, and is kept only when it still fits under Forever's yellow.
  let learn = itemLearn;
  if (!learn && trainerLevel.has(spell)) {
    learn = trainerLevel.get(spell);
    const eraY = eraYellow.get(spell);
    if (eraY && rec.yellow && eraY !== rec.yellow) {
      learn = Math.max(1, learn - (eraY - rec.yellow));
      shifted++;
    }
  }
  if (rec.sources.has("S")) learn = 0;
  if (learn && rec.yellow && learn > rec.yellow) learn = 0;
  rec.learn = learn > 1 ? learn : 0;
  if (!rec.reagents.length) {
    recipes.delete(spell); // uses nothing, so no material's tooltip can list it
    dropped.noReagents++;
  }
}

// ------------------------------------------------------------------ write

const lines = new Map(); // base line -> { name, child counts }
for (const rec of recipes.values()) {
  if (!lines.has(rec.line)) lines.set(rec.line, { name: lineNames.get(rec.line) || "", child: new Map() });
  const L = lines.get(rec.line);
  L.child.set(rec.child, (L.child.get(rec.child) || 0) + 1);
}
const uses = new Map(); // reagent -> [[recipe, count]]
for (const [spell, rec] of recipes) {
  for (const [item, count] of rec.reagents) {
    if (!uses.has(item)) uses.set(item, []);
    uses.get(item).push([spell, count]);
  }
}

const lua = (s) => JSON.stringify(s);
let out = "";
out += "-- Generated by tools/reagents-data/gen-data.js from Forever's client tables (wago.tools, build " + build + ")\n";
out += "-- and the cmangos classic-db (trainer levels, where recipe items come from). Do not edit by hand.\n";
out += "--\n";
out += "-- lines[profession skill line] = { English name, Forever child skill line }\n";
out += "-- recipes[recipe spell] = { line, yellow, grey, created item or 0, sources, learn skill or 0 }\n";
out += "--   Green starts halfway: floor((yellow + grey) / 2). Sources, one letter each: S known with the\n";
out += "--   profession, T trainer, V vendor, D drop, F fishing, Q quest, R recipe item (source unknown).\n";
out += "-- uses[material item] = { recipe, count, recipe, count, ... }\n\n";
out += 'local _, root = ...\nlocal ns = root.Feature("reagents")\n\n';
out += "ns.Data = {\n";
out += `\tbuild = ${lua(build)},\n`;
out += "\tlines = {\n";
for (const [line, L] of [...lines].sort((a, b) => a[0] - b[0])) {
  let child = 0, best = -1;
  for (const [c, n] of L.child) if (c && n > best) { child = c; best = n; }
  out += `\t\t[${line}] = { ${lua(L.name)}, ${child} },\n`;
}
out += "\t},\n\trecipes = {\n";
for (const [spell, r] of [...recipes].sort((a, b) => a[0] - b[0])) {
  const src = ORDER.split("").filter((l) => r.sources.has(l)).join("");
  out += `\t\t[${spell}] = { ${r.line}, ${r.yellow}, ${r.grey}, ${r.result}, ${lua(src)}, ${r.learn} }, -- ${spellNames.get(spell)}\n`;
}
out += "\t},\n\tuses = {\n";
for (const [item, list] of [...uses].sort((a, b) => a[0] - b[0])) {
  out += `\t\t[${item}] = { ${list.map(([s, c]) => s + ", " + c).join(", ")} },\n`;
}
out += "\t},\n}\n";

const dest = path.join(__dirname, "..", "..", "KroolWorldForever", "Features", "ReagentUses", "Data.lua");
fs.writeFileSync(dest, out);

const bySource = {};
for (const r of recipes.values()) {
  const k = r.sources.size ? [...r.sources].sort().join("") : "?";
  bySource[k] = (bySource[k] || 0) + 1;
}
const withLearn = [...recipes.values()].filter((r) => r.learn).length;
console.log(`Data.lua: ${recipes.size} recipes in ${lines.size} professions, ${uses.size} materials, build ${build}`);
console.log("skipped", JSON.stringify(skipped), "dropped", JSON.stringify(dropped));
console.log(`kept ${hiddenResults} recipes whose crafted item the client hides; shifted ${shifted} trainer levels by Forever's threshold change`);
console.log("dropped as unobtainable (no teaching item in the client): " + droppedNames.join(", "));
console.log(`learn level known for ${withLearn}; sources ${JSON.stringify(bySource)}`);
