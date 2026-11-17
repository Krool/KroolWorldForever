-- Who this copy of the code is. Every feature ships twice: in the bundle (this file, as written)
-- and as its own standalone addon, whose Core/Identity.lua tools/standalone/build.js generates
-- from standalone/addons.json. Nothing else hard-wires a global, saved variable, slash id or frame
-- name: they all come from root.ID, so two copies loaded side by side never write the same name.
--
--   addon      the addon folder name (also its public API global and Compartment function prefix)
--   db         the SavedVariables global
--   slashId    SlashCmdList key (and BINDING_HEADER_<slashId>); per-feature ids add _<KEY>
--   popup      start of the StaticPopupDialogs names
--   mainSlash  the slash words that open the hub (none in a standalone)
--   prefix     start of every named frame, secure button and Settings variable
--   title      the name players see (settings category, chat lines, "is off" notice)
--   chat       the chat line prefix, colored
--   bundle     the bundle's folder name: a standalone stays off while it is loaded
--   family     every addon folder this code ships as (Setups never toggles them)
--   standalone true in a generated standalone
--   embedded   feature keys carried only as a data provider (loaded, never enabled, no UI)
--
-- Keep `family` equal to the bundle plus every folder in standalone/addons.json (a test checks).

local _, root = ...

root.ID = {
	addon = "KroolWorldForever",
	db = "KroolWorldForeverDB",
	slashId = "KROOLWORLDFOREVER",
	popup = "KWF",
	mainSlash = { "/kw", "/kwf", "/kroolworld" },
	prefix = "KroolWorldForever",
	title = "Krool World Forever",
	chat = "|cff33ffccKrool|cffffffffWorld|r",
	bundle = "KroolWorldForever",
	family = {
		"KroolWorldForever",
		"KW_QuestTrash",
		"KW_KillValue",
		"KW_Setups",
		"KW_RareAlert",
		"KW_DisenchantValue",
		"KW_CampGuide",
		"KW_SkillUpOdds",
		"KW_SaygesFortune",
		"KW_LeastValuable",
		"KW_QuestRewardValue",
		"KW_OneButtonFishing",
		"ReagentUses",
		"KW_MarketMovers",
	},
	standalone = false,
	embedded = {},
}
