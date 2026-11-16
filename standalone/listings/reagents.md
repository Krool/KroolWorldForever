# KW Reagent Uses

- **Folder:** ReagentUses (kept from before it joined the bundle, so first users update in place)
- **CurseForge:** project 1804597, slug `reagent-uses` (the one KW page without "kw-" in its address)
- **Main category:** Professions. **More:** Tooltip.
- **Relations:** none.
- **Logo:** the one made for the old ReagentUses repo, already on the CurseForge page (none in `standalone/logos/`).

## Summary

Hold Ctrl over a crafting material to see every recipe that uses it, colored by your skill, with where each recipe is learned and which of your characters know it. Built from WoW Forever's own recipe data.

## Description

Hold Ctrl over a crafting material and its tooltip lists every recipe that uses it, grouped by profession. Your own professions come first.

- Recipe names take the crafting window's colors for your skill: orange, yellow, green, grey. Red means your skill is still below the level the recipe is learned at.
- The right side says who knows the recipe: you, and your other characters. Otherwise it says where the recipe is learned (Trainer, Vendor, Drop, Fishing, Quest, Recipe) and at what skill.
- "x4" is how many of the material a recipe takes. "(used in 95)" means what the recipe makes goes into 95 more recipes, so Silk Cloth leads you to Bolt of Silk Cloth.
- A clicked chat link shows the list without the key.

**Settings** (Esc > Options > AddOns > KW Reagent Uses, or /ru)

- **Show With:** Ctrl, Alt, Shift, or Always Show.
- **Show Hint:** a one-line hint while the key is up.
- **Show Other Characters:** name your other characters who know each recipe.
- **Hide Grey Recipes:** leave out recipes that give no skill points.
- **Recipes Shown:** how many recipes to list.

Your other characters show up after each one opens its own profession window once.

The recipe data comes from WoW Forever's own game files, including the roughly 900 recipes Forever added to the Vanilla set. Trainer levels and recipe sources come from the cmangos classic database. A recipe whose source isn't known yet shows as "Recipe".

Inspired by MasterTradeSkills for Vanilla and Turtle WoW. This is a fresh write for Forever.

Part of Krool World Forever, which has every KW addon in one: https://www.curseforge.com/wow/addons/krool-world-ui. Install one or the other: next to the bundle, this copy switches itself off.

Open source (MIT): https://github.com/Krool/KroolWorldForever

[Donate](https://ko-fi.com/kroolworld)
