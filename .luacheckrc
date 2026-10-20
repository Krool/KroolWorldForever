std = "lua51"
max_line_length = false
exclude_files = { "**/Libs/", ".release/" }
ignore = {
	"212/self", -- unused self
	"211/_.*", -- unused locals prefixed with _
}

-- Globals our addons define. Add per-addon names here.
globals = {
	"SlashCmdList",
	"HelloForeverDB",
	"SLASH_HELLOFOREVER1",
	"HelloForever_OnCompartmentClick",
}

-- WoW API globals we read. LuaLS + ketho.wow-api covers the editor; this list is for CI.
read_globals = {
	"CreateFrame", "UIParent", "GetBuildInfo", "C_Timer", "C_AddOns", "C_GameRules", "C_SkillInfo",
	"Settings", "Enum", "LibStub", "print", "strsplit", "strtrim", "wipe", "format",
	"WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "WOW_PROJECT_CAMELOT",
	"UnitName", "UnitClass", "UnitLevel", "UnitPower", "UnitUsesAmmo", "InCombatLockdown",
	"issecretvalue",
}
