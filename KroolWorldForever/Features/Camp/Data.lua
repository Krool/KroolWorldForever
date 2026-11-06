-- Camp Guide data: what each camp object gives. No game calls here.
--
-- Spell ids: forever.warcraftdb.com (Forever client data); each name was checked there.
-- Level bands: the objects' own tooltips in client 1.60.1.70790, as Endgame Tools lists them
-- ("WoW Forever campfire buffs: every object's value by level", updated 2026-11-05). A band is
-- { from level, value(s) }; the last band at or below the player's level applies.
-- Objects from skill 140 and 300 are placed over the profession's first object and keep its
-- buff, with a workstation or a service on top.

local _, root = ...
local ns = root.Feature("camp")

local D = {}
ns.Data = D

D.CAMP_BENEFITS = 1229741 -- "Gained the following camp benefits:", an hour
D.NEARBY = 1283391 -- Campfire Nearby: an area aura on everyone close to a campfire
D.WELCOMING = { 1229739, 1289723 } -- Welcoming Campfire: the minute spent sitting (or crafting)
D.BOOSTED_REST = 1229451 -- no more rested experience from a Camp Tent for an hour

-- The buffs, by the first object that gives it. notWith: the class buffs it does not stack with
-- (English aura names, every rank shares one).
D.BONUSES = {
	kit = {
		object = "First Aid Kit",
		prof = "First Aid",
		spell = 1230124,
		text = "+%d Stamina",
		bands = { { 1, 3 }, { 12, 8 }, { 24, 21 }, { 36, 34 }, { 48, 45 }, { 60, 56 } },
		notWith = { "Power Word: Fortitude", "Prayer of Fortitude" },
	},
	bowl = {
		object = "Fish Bowl",
		prof = "Fishing",
		spell = 1230098,
		fixed = "+8% all stats",
		notWith = { "Blessing of Kings", "Greater Blessing of Kings" },
	},
	well = {
		object = "Mana Well",
		prof = "Alchemy",
		spell = 1230587,
		text = "+%d mana every 5 seconds",
		bands = { { 1, 10 }, { 24, 15 }, { 34, 20 }, { 44, 24 }, { 54, 29 } },
		notWith = { "Blessing of Wisdom", "Greater Blessing of Wisdom" },
	},
	wheel = {
		object = "Sharpening Wheel",
		prof = "Blacksmithing",
		spell = 1230172,
		text = "+%d Strength",
		bands = { { 1, 6 }, { 24, 11 }, { 38, 20 }, { 52, 34 } },
		notWith = { "Strength of Earth" },
	},
	lodestone = {
		object = "Lodestone",
		prof = "Mining",
		spell = 1230164,
		text = "+%d melee attack power",
		bands = { { 1, 12 }, { 12, 20 }, { 22, 32 }, { 32, 49 }, { 42, 67 }, { 52, 90 } },
		notWith = { "Blessing of Might", "Greater Blessing of Might" },
	},
	lute = {
		object = "Enchanted Lute",
		prof = "Enchanting",
		spell = 1230653,
		lute = true, -- armor, then all stats, then all resistances
		bands = {
			{ 1, 28, 0, 0 },
			{ 10, 71, 2, 0 },
			{ 20, 114, 4, 0 },
			{ 30, 163, 7, 6 },
			{ 40, 211, 9, 12 },
			{ 50, 260, 12, 16 },
			{ 60, 308, 13, 22 },
		},
		notWith = { "Mark of the Wild", "Gift of the Wild" },
	},
	candle = {
		object = "Incense Candle",
		prof = "Herbalism",
		spell = 1229513,
		text = "+%d Intellect",
		bands = { { 1, 2 }, { 14, 6 }, { 28, 12 }, { 42, 18 }, { 56, 25 } },
		notWith = { "Arcane Intellect", "Arcane Brilliance" },
	},
	chair = {
		object = "Camp Chair",
		prof = "Skinning",
		spell = 1229519,
		fixed = "+2% critical strike, attacks and spells",
		notWith = { "Moonkin Aura", "Leader of the Pack" },
		say = "Moonkin Aura or Leader of the Pack",
	},
	banner = {
		object = "Faction Banner",
		prof = "Tailoring",
		spell = 1229718,
		text = "+%d Spirit, your faction only",
		bands = { { 1, 14 }, { 40, 19 }, { 50, 27 }, { 60, 32 } },
		notWith = { "Divine Spirit", "Prayer of Spirit" },
	},
	tent = {
		object = "Camp Tent",
		prof = "Leatherworking",
		tent = true, -- rested experience, not a stat buff
	},
}

-- The order /kwc lists them in.
D.ORDER = { "kit", "bowl", "well", "wheel", "lodestone", "lute", "candle", "chair", "banner", "tent" }

-- Campfires: how many camp objects each holds. "Campfire" is the plain name some show.
D.FIRES = {
	["Basic Campfire"] = 3,
	["Journeyman Campfire"] = 5,
	["Expert Campfire"] = 10,
	["Campfire"] = false,
}

-- World names of camp objects -> { bonus = key of D.BONUSES or nil, also = what else it does }.
-- "Chair" and "Tent" are what some of them show in the world.
D.OBJECTS = {
	["First Aid Kit"] = { bonus = "kit" },
	["Toxin Study"] = { bonus = "kit", also = "Healing potions and anti-venom" },
	["Plague Doctor's Laboratory"] = { bonus = "kit", also = "Healing potions and poultices" },
	["Fish Bowl"] = { bonus = "bowl" },
	["Fishing Rack"] = { bonus = "bowl", also = "Better fishing nearby: lures and uncommon fish" },
	["Fishing Hut"] = { bonus = "bowl", also = "Better fishing nearby: lures and rare fish" },
	["Mana Well"] = { bonus = "well" },
	["Fermenter"] = { bonus = "well", also = "Workstation for some Alchemy reagents" },
	["Alchemy Laboratory"] = { bonus = "well", also = "Workstation for some Alchemy recipes" },
	["Sharpening Wheel"] = { bonus = "wheel" },
	["Anvil"] = { bonus = "wheel", also = "An anvil for Blacksmithing plans" },
	["Master Forge"] = { bonus = "wheel", also = "Workstation for some Blacksmithing plans" },
	["Lodestone"] = { bonus = "lodestone" },
	["Rock Garden"] = { bonus = "lodestone", also = "Grows a common mining node now and then" },
	["Molten Foundry"] = { bonus = "lodestone", also = "Workstation for some smelting" },
	["Enchanted Lute"] = { bonus = "lute" },
	["Arcane Salvager"] = { bonus = "lute", also = "Better disenchanting while you are near it" },
	["Arcane Forge"] = { bonus = "lute", also = "Workstation for some Enchanting formulas" },
	["Incense Candle"] = { bonus = "candle" },
	["Greenhouse"] = { bonus = "candle", also = "Plant seeds and grow them into herbs" },
	["Seed Hybridizer"] = { bonus = "candle", also = "Multiplies seeds or turns them into rarer ones" },
	["Camp Chair"] = { bonus = "chair", also = "You can sit on it" },
	["Chair"] = { bonus = "chair", also = "You can sit on it" },
	["Field Guide"] = { bonus = "chair", also = "Track Beasts on the minimap" },
	["Trapper's Workbench"] = { bonus = "chair", also = "Has a trap" },
	["Faction Banner"] = { bonus = "banner" },
	["Spinning Wheel"] = { bonus = "banner", also = "Workstation for some Tailoring materials" },
	["Loom"] = { bonus = "banner", also = "Workstation for some Tailoring patterns" },
	["Camp Tent"] = { bonus = "tent" },
	["Tent"] = { bonus = "tent" },
	["Tanning Rack"] = { bonus = "tent", also = "Workstation for some Leatherworking materials" },
	["Sewing Machine"] = { bonus = "tent", also = "Workstation for some Leatherworking patterns" },
	["Cookie's Feast"] = { also = "Food that gives Stamina" },
	["Iron Oven"] = { also = "Workstation for some Cooking recipes" },
	["Reagent Bot"] = { also = "A vendor: buys your items, sells reagents" },
	["Repair Bot"] = { also = "A vendor: reagents, selling and repairs" },
	["Anarchist's Workbench"] = { also = "Workstation for some Engineering schematics" },
}
