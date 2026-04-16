-- VoidcoreAdvisor: Locale – English (base / fallback)
-- All user-facing strings live here.  Other locale files override individual
-- keys; any key left nil falls back to this table via __index.

local _, VCA = ...

local L = {}
VCA.L = L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"]             = "|cffb048f8Voidcore|r|cffddddddAdvisor|r"

L["COL_LOOT"]                = "LOOT"
L["COL_SPEC_RANKING"]        = "SPEC RANKING"
L["COL_SPEC_FIT"]            = "SPEC FIT"
L["COL_LOOT_FILTERED"]       = "LOOT (filtered)"
L["COL_LOOT_FILTERED_N"]     = "LOOT (filtered %d specs)"

L["CONTENT_RAID_BOSS"]       = "Raid Boss"
L["CONTENT_MP_DUNGEON"]      = "M+ Dungeon"
L["NEBULOUS_VOIDCORE"]       = "Nebulous Voidcore"
L["NEBULOUS_VOIDCORES"]      = "Nebulous Voidcores"

L["NO_ITEMS_FOR_SPEC"]       = "No items for this spec"

L["LOOT_SPEC_LABEL"]         = "Loot:"
L["ALL_OBTAINED"]            = "✓ all"

L["DETECTED_OBTAINED"]       = "Auto-detected %s as obtained via Nebulous Voidcore."

L["CLEAR_SELECTED"]          = "Clear selected"

-- ── Slash commands (Init.lua) ─────────────────────────────────────────────────

L["RESET_CONFIRM"]           = "All obtained-item data has been reset."
L["COUNT_FORMAT"]            = "%d item(s) marked as obtained via Voidcore."
L["SPEC_FORMAT"]             = "Effective loot spec ID: %s%s"
L["FOLLOWS_ACTIVE_SPEC"]     = " (follows active spec)"
L["SOURCE_FORMAT"]           = "Active source — type: %s  sourceID: %s  difficulty: %s"
L["NO_ACTIVE_SOURCE"]        = "No active source set."
L["VERSION_FORMAT"]          = "Version %s"
L["HELP_HEADER"]             = "Commands:"
L["HELP_RESET"]              = "  /vca reset    – clear all obtained-item data"
L["HELP_COUNT"]              = "  /vca count    – show total items marked as obtained"
L["HELP_SPEC"]               = "  /vca spec     – show effective loot spec ID"
L["HELP_SOURCE"]             = "  /vca source   – show active detection source"
L["HELP_VERSION"]            = "  /vca version  – show addon version"
