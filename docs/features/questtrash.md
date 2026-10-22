# Quest Trash (feature)

**Know which quest items you can safely delete.** WoW Forever port of OctoQuestTrash.

Hover any item. Quest items, and items any quest uses, get a verdict line:

| Verdict | Meaning |
|---|---|
| **Can be deleted** (red) | Every quest that uses it is completed, and none of them is repeatable or seasonal. |
| **Keep - needed for an active quest** (green) | A quest in your log wants it. |
| **Keep - a quest still wants this** (yellow) | A quest you have not done yet needs it. |
| **Keep - a repeatable/seasonal quest wants this** (blue) | Turn-in farms, dailies, holiday and Darkmoon quests. Never flagged deletable. |
| **No use to you** | Only quests your race/class can never take use it. Stated as that, not as "completed". |
| **No quest data - keep to be safe** (gray) | Quest item the database has no link for. |
| **Checking quest data... keep for now** (gray) | Shown for a few seconds after login while the quest index builds. |

Tradable items are **never** told "delete". The strongest advice they get is "sell or AH it". Up to
four quests and their status are listed under the verdict.

`/fqt` (or `/questtrash`) scans your bags (and the bank while it is open) and prints every verdict,
deletables first. `/fqt status` shows the data source state. `/fqt options` opens the settings.

## Requires

**QuestieDB** (the database addon Questie uses; install Questie or QuestieDB on its own). Without it
the feature says so at login and `/fqt status` reports it; the rest of the bundle is unaffected.

## What changed from OctoQuestTrash

- **Completion comes from the client** (`C_QuestLog.IsQuestFlaggedCompleted`). No pfQuest history,
  no `/db query` backfill, no polluted-history caveat.
- **Data comes from QuestieDB** instead of pfQuest: collect objectives, spell-objective items,
  required carried items, items handed out on accept, quest-starting items, and QuestieDB's own
  `relatedQuests`.
- **Breadcrumbs** are recognized: a breadcrumb note is dead once its target quest is taken or done.
- **Repeatables:** QuestieDB's repeatable/daily/weekly/monthly flags plus the old cmangos/Turtle list
  (classic ids only) as an extra guard. Holiday and Darkmoon quest categories count as seasonal.
- **Bagshui hook dropped** (Bagshui is a 1.12 addon). Bag addons can call
  `KroolWorldForever.QuestTrash.GetVerdict(itemID)`, which returns a verdict string and the quest links.

## Honest limits

- **Forever's new content** (Skyborne zones, new dungeons and quests) is only as complete as
  QuestieDB's Forever data. Its own notes call Zephras Isle a content gap. Items with no link read
  "No quest data - keep", never "delete".
- **Skyborne characters** skip the race test: QuestieDB has not live-validated Skyborne race masks yet, and a
  wrong mask would read "not for your race". This errs toward keep.
- **Quest rewards** (keys, attunement items) have no quest that consumes them, so they get no
  verdict. A built-in never-delete list guards the famous ones.
- The addon only advises. Nothing is ever deleted automatically.
- **Not yet run in the live game.** Verified by tests against a stubbed client and the Forever API
  allowlist (build 1.60.1.70450).

## Development

```
cd tools\test
npm install
npm test
```

`tools/test/run.js` syntax-checks the bundle (Lua 5.1 grammar), then the `questtrash` suite loads the whole
bundle under fengari with a stubbed Forever client and a fake QuestieDB (`tools/test/questtrash/stubs.lua`)
and runs `test.lua` (61 checks, including the bundle on/off switch).
Then `tools/forever-api/api-lint.js` (repo root) checks every `C_*` call, event and `Enum` name
against Forever's generated API docs.

Design rules (keep them when changing things):

- Every unknown fails toward keep. A verdict that permits deletion is never issued before the quest
  index is complete (`pending`).
- Most protective quest state wins: active > farm > maybe > safe > notyours.
- Race/class masks can exceed 32 bits (Skyborne). Use `HasBit` (arithmetic), never `bit.band`.
- QuestieDB numeric fields read `0`, not nil. Test `~= 0`.
- Tooltip work runs under `pcall` and skips secret values.

Data credits: [QuestieDB](https://github.com/Questie/QuestieDB) (Questie team; read at runtime, not
bundled) and [cmangos classic-db](https://github.com/cmangos/classic-db) (GPL-3.0; the repeatable quest
ids in `Repeatables.lua`). The addon code is MIT licensed.
