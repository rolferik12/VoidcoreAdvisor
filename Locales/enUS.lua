-- VoidcoreAdvisor: Locale – English (base / fallback)
-- All user-facing strings live here.  Other locale files override individual
-- keys; any key left nil falls back to this table via __index.
local _, VCA = ...

local L = {}
VCA.L = L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"] = "|cffb048f8Voidcore|r|cffddddddAdvisor|r"

L["COL_LOOT"] = "LOOT"
L["COL_SPEC_RANKING"] = "SPEC RANKING"
L["COL_SPEC_FIT"] = "SPEC FIT"
L["COL_LOOT_FILTERED"] = "LOOT (filtered)"
L["COL_LOOT_FILTERED_N"] = "LOOT (filtered %d specs)"

L["CONTENT_RAID_BOSS"] = "Raid Boss"
L["CONTENT_MP_DUNGEON"] = "M+ Dungeon"
L["NEBULOUS_VOIDCORE"] = "Nebulous Voidcore"
L["NEBULOUS_VOIDCORES"] = "Nebulous Voidcores"

L["NO_ITEMS_FOR_SPEC"] = "No items for this spec"
L["LFR_NOT_ELIGIBLE"] = "Not available in Raid Finder"

L["LOOT_SPEC_LABEL"] = "Loot:"
L["ALL_OBTAINED"] = "✓ all"

L["DETECTED_OBTAINED"] = "Auto-detected %s as obtained via Nebulous Voidcore."

L["CLEAR_SELECTED"] = "Clear selected"

L["TOGGLE_SHOW"] = "Click to show the advisor panel."
L["TOGGLE_HIDE"] = "Click to hide the advisor panel."
L["TOGGLE_OVERVIEW_SHOW"] = "Click to show the dungeon overview."
L["TOGGLE_OVERVIEW_HIDE"] = "Click to hide the dungeon overview."

-- ── Slash commands (Init.lua) ─────────────────────────────────────────────────

L["RESET_CONFIRM"] = "All obtained-item data has been reset."
L["COUNT_FORMAT"] = "%d item(s) marked as obtained via Voidcore."
L["SPEC_FORMAT"] = "Effective loot spec ID: %s%s"
L["FOLLOWS_ACTIVE_SPEC"] = " (follows active spec)"
L["SOURCE_FORMAT"] = "Active source — type: %s  sourceID: %s  difficulty: %s"
L["NO_ACTIVE_SOURCE"] = "No active source set."
L["VERSION_FORMAT"] = "Version %s"
L["HELP_HEADER"] = "Commands:"
L["HELP_RESET"] = "  /vca reset    – clear all obtained-item data"
L["HELP_COUNT"] = "  /vca count    – show total items marked as obtained"
L["HELP_SPEC"] = "  /vca spec     – show effective loot spec ID"
L["HELP_SOURCE"] = "  /vca source   – show active detection source"
L["HELP_VERSION"] = "  /vca version  – show addon version"

-- ── Reminder popup (Reminder.lua) ─────────────────────────────────────────────

L["REMINDER_TITLE"] = "|cffb048f8Voidcore|r|cffddddddAdvisor|r"
L["REMINDER_SUBTITLE"] = "Optimize your loot spec for Nebulous Voidcore rewards!"
L["REMINDER_VOIDCORE_COUNT"] = "You have |cffffff00%d|r Nebulous Voidcore(s)"
L["REMINDER_CURRENT_SPEC"] = "Current loot spec:"
L["REMINDER_RECOMMENDED"] = "Recommended spec:"
L["REMINDER_ITEMS_SELECTED"] = "%d item(s) selected"
L["REMINDER_SELECTED_CHANCE"] = "%d%% chance for selected item(s)"
L["REMINDER_CHANGE_PROMPT"] = "Change loot spec to |cffffff00%s|r?"
L["REMINDER_YES"] = "Yes, Change"
L["REMINDER_NO"] = "No Thanks"

-- ── Options panel (Options.lua) ───────────────────────────────────────────────

L["OPTIONS_REMINDER_ENABLE"] = "Loot spec reminder"
L["OPTIONS_REMINDER_TOOLTIP"] =
    "Show a popup when entering a current-season mythic dungeon if a different loot specialization would give better odds for your selected items."
L["OPTIONS_PREVIEW_REMINDER"] = "Preview"

-- ── Dungeon Overview panel (DungeonOverview.lua) ─────────────────────────────

L["DUNGEON_OVERVIEW_SUBTITLE"] = "M+ Dungeons — Loot Chance"
L["DUNGEON_OVERVIEW_COL_DUNGEON"] = "DUNGEON"
L["DUNGEON_OVERVIEW_COL_SPEC"] = "SPEC"
L["DUNGEON_OVERVIEW_COL_LOOTED"] = "LOOTED"
L["DUNGEON_OVERVIEW_COL_CHANCE"] = "CHANCE"
L["DUNGEON_OVERVIEW_ALL_DONE"] = "All dungeon items obtained!"
L["DUNGEON_OVERVIEW_NO_DATA"] = "Season dungeon data not yet available."

L["RAID_OVERVIEW_SUBTITLE"] = "Raid Bosses — Loot Chance"
L["RAID_OVERVIEW_COL_BOSS"] = "BOSS"
L["RAID_OVERVIEW_NO_DATA"] = "No raid encounter data available."

-- ── Spec Picker Popup (PanelColumns.lua) ──────────────────────────────────────

L["SPEC_PICKER_TITLE"] = "Obtained as:"
L["SPEC_PICKER_OK"] = "OK"
L["OBTAINED_UNKNOWN_SPEC"] = "Obtained (spec unknown)"
