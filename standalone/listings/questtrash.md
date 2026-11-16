# KW Quest Trash

- **Folder:** KW_QuestTrash
- **Main category:** Quests & Leveling. **More:** Bags & Inventory, Tooltip.
- **Relations:** QuestieDB, required.
- **Logo:** `standalone/logos/questtrash.png`

## Summary

Tells you which quest items in your bags are safe to delete. A keep or delete verdict on quest item tooltips, and a window that sorts your bags and bank. Needs QuestieDB.

## Description

Quest items pile up, and the game never says which ones you still need. KW Quest Trash checks each one against QuestieDB's quest data and the quests your character has done.

- Every quest item's tooltip says Can be deleted, Keep, or that it is still checking, with the quest it belongs to and why.
- An item you could sell or trade is never told to delete, and items for repeatable or seasonal quests always read Keep.
- An item can be deleted when every quest that uses it is done, or closed to you for good: you are over its level cap, another version of it is done, or a quest it needs is closed to you.
- `/fqt` opens a window that sorts your bags (and your bank while it is open) into Can Delete, Keep and Still Checking.
- It never deletes anything. You decide.

Needs QuestieDB. The CurseForge app installs it with this addon and with Questie; installed by hand, it is its own download. Settings: Esc > Options > AddOns > KW Quest Trash.

Part of Krool World Forever, which has every KW addon in one: https://www.curseforge.com/wow/addons/krool-world-ui. Install one or the other: next to the bundle, this copy switches itself off.

Open source (MIT): https://github.com/Krool/KroolWorldForever

[Donate](https://ko-fi.com/kroolworld)
