# Quest Trash (feature)

**Know which quest items you can safely delete.**

Hover any item. Quest items, and items any quest uses, get a verdict line:

| Verdict | Meaning |
|---|---|
| **Can be deleted** (red) | Every quest that uses it is completed or closed to you for good, and none of them is repeatable or seasonal. |
| **Keep - needed for an active quest** (green) | A quest in your log wants it. |
| **Keep - a quest still wants this** (yellow) | A quest you have not done yet needs it. |
| **Keep - a repeatable/seasonal quest wants this** (blue) | Turn-in farms, dailies, holiday and Darkmoon quests. Never flagged deletable. |
| **No use to you** | Only quests your race/class can never take use it. Stated as that, not as "completed". |
| **No quest data - keep to be safe** (gray) | Quest item the database has no link for, or whose only quests it does not have. |
| **Checking quest data... keep for now** (gray) | Shown for a few seconds after login while the quest index builds. |

Tradable items are **never** told "delete". The strongest advice they get is "sell or AH it". Up to
four quests and their status are listed under the verdict.

`/fqt` (or `/questtrash`, `/kw questtrash`, the hub card) opens the **Quest Trash window** (0.7.0):
every quest item in your bags, and the bank while it is open, one row per item with its icon,
stack total and a few words of why, grouped into Can Delete, Keep and Still Checking. Hovering a
row shows the item's tooltip with the verdict and its quests. It refreshes on bag, bank and quest
changes while open. Advice only: it deletes nothing. `/fqt print` lists the same in chat,
`/fqt status` shows the data source state, `/fqt options` opens the settings.

## Requires

**QuestieDB** (the database addon Questie uses; install Questie or QuestieDB on its own). Without it
the feature says so at login and `/fqt status` reports it; the rest of the bundle is unaffected.

## How it decides

- **Completion comes from the client** (`C_QuestLog.IsQuestFlaggedCompleted`), so there is no
  history to backfill or repair.
- **Quest links come from QuestieDB**: collect objectives, spell-objective items,
  required carried items, items handed out on accept, quest-starting items, and QuestieDB's own
  `relatedQuests`. The client fills in quest-starting items QuestieDB has no entry for: the quest
  a bag item starts (`C_Container.GetContainerItemQuestInfo`, the "!" on its slot) is learned when
  the window, the hub or a bag-slot tooltip reads the bags (0.18.0). The quest itself must still be
  in QuestieDB, or the item reads "No quest data".
- **Closed for good** (0.18.0): a quest you can never take counts like a completed one. Each reason
  rests on your own progress, and the tooltip names it:
  - a mutually exclusive version is done (`exclusiveTo`);
  - it is a breadcrumb and you took or finished the quest it leads to (`breadcrumbForQuestId`);
  - it was offered only until another quest is done, and that one is (`availableUntilCompleted`);
  - you are over its level cap (`requiredMaxLevel`; levels only go up);
  - a quest it needs (`preQuestGroup`), or every one it could use (`preQuestSingle`), is closed for
    one of these reasons, followed up to six steps back. A prerequisite that is only race/class-locked
    does not close the quest after it, so a wrong race mask cannot spread down a chain.
- **Grey quests stay Keep** (owner's call, 2026-11-13): a quest you have outleveled but not done is
  still "a quest still wants this".
- **Repeatables:** QuestieDB's repeatable/daily/weekly/monthly flags plus a list of
  repeatable quest ids from cmangos classic-db as an extra guard. Holiday and Darkmoon quest categories count as seasonal.
- **Bag addons** can call `KroolWorldForever.QuestTrash.GetVerdict(itemID)`, which returns a verdict string and the quest links.

## Honest limits

- **Forever's new content** (Skyborne zones, new dungeons and quests) is only as complete as
  QuestieDB's Forever data. QuestieDB 1.1.0 (2026-11-12) rebuilt Forever's quest relations from
  players' QuestieTrace uploads, so keep QuestieDB current. Items with no link read
  "No quest data - keep", never "delete".
- **Skyborne characters** skip the race test: QuestieDB has not live-validated Skyborne race masks yet, and a
  wrong mask would read "not for your race". This errs toward keep.
- **Quest rewards** (keys, attunement items) have no quest that consumes them, so they get no
  verdict. A built-in never-delete list guards the famous ones.
- The addon only advises. Nothing is ever deleted automatically.
- Running on live since launch (2026-11-04) with no errors logged. Tests run against a stubbed
  client and the Forever API allowlist (build 1.60.1.70938).

## Development

```
cd tools\test
npm install
npm test
```

`tools/test/run.js` syntax-checks the bundle (Lua 5.1 grammar), then the `questtrash` suite loads the whole
bundle under fengari with a stubbed Forever client and a fake QuestieDB (`tools/test/questtrash/stubs.lua`)
and runs `test.lua` (112 checks, including the bundle on/off switch).
Then `tools/forever-api/api-lint.js` (repo root) checks every `C_*` call, event and `Enum` name
against Forever's generated API docs.

Design rules (keep them when changing things):

- Every unknown fails toward keep. A verdict that permits deletion is never issued before the quest
  index is complete (`pending`).
- Most protective verdict wins: active > farm > maybe > unknown > safe > notyours.
- "Closed" needs proof from the player's own progress (a done quest, a level). Never close a quest
  on static data alone.
- Race/class masks can exceed 32 bits (Skyborne). Use `HasBit` (arithmetic), never `bit.band`.
- QuestieDB numeric fields read `0`, not nil. Test `~= 0`.
- Tooltip work runs under `pcall` and skips secret values.

Data credits: [QuestieDB](https://github.com/Questie/QuestieDB) (Questie team; read at runtime, not
bundled) and [cmangos classic-db](https://github.com/cmangos/classic-db) (GPL-3.0; the repeatable quest
ids in `Repeatables.lua`). The addon code is MIT licensed.
