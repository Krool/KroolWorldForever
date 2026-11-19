# Krool World UI (the bundle)

- **Folder:** KroolWorldForever
- **CurseForge:** project 1804317, https://www.curseforge.com/wow/addons/krool-world-ui
- **Relations:** none to the KW addons. CurseForge's relation types (required, optional, embedded
  library, tool, incompatible) all misdescribe "the same feature, packaged alone", so the links live
  in the descriptions instead. Each feature name below links its KW addon, and every KW
  addon's description links back here.

## Summary

Thirteen small WoW Forever addons in one, each with an on/off switch: which quest items to delete, kill and item values, disenchant value, cheapest skill-ups, rare spawn alerts, one-key fishing, copying bars between characters, camp buffs, Sayge's timer.

## Description

Krool World Forever is thirteen small addons for WoW Forever in one. Hover an enemy for its gold per kill, a green for its disenchant value, a quest item for keep or delete, a campfire for its buffs. Each feature has its own on/off switch, and all are on by default. Type /kw for the overview.

- [Quest Trash](https://www.curseforge.com/wow/addons/kw-quest-trash): shows which quest items you can delete. /fqt sorts your bags and bank into Can Delete, Keep and Still Checking. Needs QuestieDB: the CurseForge app installs it with Questie.
- [Kill Value](https://www.curseforge.com/wow/addons/kw-kill-value): expected gold per kill on enemy tooltips, counting coin, drops and skinning. It learns real drop rates from what you loot.
- [Setups](https://www.curseforge.com/wow/addons/kw-setups): copy action bars, keybindings, macros, Edit Mode layout, chat text size and per-character settings from one character to another, with Undo. A new character can start from a saved setup.
- [Rare Alert](https://www.curseforge.com/wow/addons/kw-rare-alert): a sound, a screen message and a chat line when a rare enemy is near, with its value and best drops. A button or key targets and marks it. It sees rares through enemy nameplates, which Forever starts with off: /kwr nameplates turns them on.
- [Disenchant Value](https://www.curseforge.com/wow/addons/kw-disenchant-value): what a green or better item disenchants into, and what that is worth.
- [Camp Guide](https://www.curseforge.com/wow/addons/kw-camp-guide): the buff each camp object gives at your level, and whether one of your class buffs already covers it.
- [Skill-Up Odds](https://www.curseforge.com/wow/addons/kw-skill-up-odds): each recipe's chance to give a skill point, and which recipe gives the cheapest next point.
- [Sayge's Fortune](https://www.curseforge.com/wow/addons/kw-sayges-fortune): tracks Sayge's hidden 4-hour fortune timer on every character.
- [Least Valuable](https://www.curseforge.com/wow/addons/kw-least-valuable): marks your cheapest bag item. When your bags are full, it tells you whether the loot is worth making room for.
- [Quest Reward Value](https://www.curseforge.com/wow/addons/kw-quest-reward-value): marks the quest reward worth the most.
- [One-Button Fishing](https://www.curseforge.com/wow/addons/kw-one-button-fishing): one key casts and reels in (bind it under Key Bindings > AddOns > Krool World). With a fishing pole equipped, a double right-click does the same.
- [Reagent Uses](https://www.curseforge.com/wow/addons/reagent-uses): hold Ctrl (or the key you choose) over a crafting material to see every recipe that uses it, colored by your skill, with where it is learned and which of your characters know it.
- [Market Movers](https://www.curseforge.com/wow/addons/kw-market-movers): after Auctionator scans the auction house, what rose or fell against its usual price, bargains under the vendor price, and how the items in your bags stand. /kwm

**Only want one or two?** Every feature above is also its own addon, named "KW" plus the feature: click a name to get just that one. Install the bundle or the single ones, not both. Next to the bundle, a single one switches itself off and says so in chat.

Recommended: Auctionator. Disenchant Value needs it to price materials, and Market Movers needs its scans. Kill Value, Rare Alert, Least Valuable, Quest Reward Value and Skill-Up Odds work without it, but use vendor prices only.

Nothing here deletes, sells, loots or picks anything for you. Setups changes your bars and bindings only when you apply a setup, never in combat, and keeps an undo point. Rare Alert and One-Button Fishing act only on your own key press or click.

**Good to know**

- Rare Alert needs enemy nameplates on (/kwr nameplates).
- Camp Guide adds its lines while you are at a camp, with Campfire Nearby on you.
- Least Valuable's coin shows in the default bags. With a bag addon, /kwl lists the slots instead.
- Reagent Uses names another character once that character has opened its profession window.
- Kill Value shows nothing inside instances: the game hides creature data from addons there.

Open source (MIT): https://github.com/Krool/KroolWorldForever

[Donate](https://ko-fi.com/kroolworld)
