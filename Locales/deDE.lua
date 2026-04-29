-- VoidcoreAdvisor: Locale – German
if GetLocale() ~= "deDE" then
    return
end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"] = "|cffb048f8Voidcore|r|cffddddddBerater|r"

L["COL_LOOT"] = "BEUTE"
L["COL_SPEC_RANKING"] = "SPEZ.-RANKING"
L["COL_SPEC_FIT"] = "SPEZ.-EIGNUNG"
L["COL_LOOT_FILTERED"] = "BEUTE (gefiltert)"
L["COL_LOOT_FILTERED_N"] = "BEUTE (gefiltert %d Spez.)"

L["CONTENT_RAID_BOSS"] = "Raidboss"
L["CONTENT_MP_DUNGEON"] = "M+-Dungeon"
L["NEBULOUS_VOIDCORE"] = "Nebulöser Leerenkern"
L["NEBULOUS_VOIDCORES"] = "Nebulöse Leerenkerne"

L["NO_ITEMS_FOR_SPEC"] = "Keine Gegenstände für diese Spezialisierung"

L["LOOT_SPEC_LABEL"] = "Beute:"
L["ALL_OBTAINED"] = "✓ alle"

L["DETECTED_OBTAINED"] = "%s automatisch als über Nebulösen Leerenkern erhalten erkannt."

L["CLEAR_SELECTED"] = "Auswahl aufheben"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"] = "Alle erhaltenen Gegenstände wurden zurückgesetzt."
L["COUNT_FORMAT"] = "%d Gegenstand/Gegenstände als über Leerenkern erhalten markiert."
L["SPEC_FORMAT"] = "Aktive Beutespezialisierungs-ID: %s%s"
L["FOLLOWS_ACTIVE_SPEC"] = " (folgt aktiver Spezialisierung)"
L["SOURCE_FORMAT"] = "Aktive Quelle — Typ: %s  QuellenID: %s  Schwierigkeit: %s"
L["NO_ACTIVE_SOURCE"] = "Keine aktive Quelle gesetzt."
L["VERSION_FORMAT"] = "Version %s"
L["HELP_HEADER"] = "Befehle:"
L["HELP_RESET"] = "  /vca reset    – alle erhaltenen Gegenstände zurücksetzen"
L["HELP_COUNT"] = "  /vca count    – Gesamtzahl erhaltener Gegenstände anzeigen"
L["HELP_SPEC"] = "  /vca spec     – aktive Beutespezialisierungs-ID anzeigen"
L["HELP_SOURCE"] = "  /vca source   – aktive Erkennungsquelle anzeigen"
L["HELP_VERSION"] = "  /vca version  – Addon-Version anzeigen"

-- ── Panel UI (Ergänzungen) ────────────────────────────────────────────────────

L["LFR_NOT_ELIGIBLE"] = "Im Schlachtzugssucher nicht verfügbar"

L["TOGGLE_SHOW"] = "Klicken, um das Beraterpanel anzuzeigen."
L["TOGGLE_HIDE"] = "Klicken, um das Beraterpanel zu verbergen."
L["TOGGLE_OVERVIEW_SHOW"] = "Klicken, um die Dungeon-Übersicht anzuzeigen."
L["TOGGLE_OVERVIEW_HIDE"] = "Klicken, um die Dungeon-Übersicht zu verbergen."

-- ── Erinnerungs-Popup (Reminder.lua) ─────────────────────────────────────────

L["REMINDER_TITLE"] = "|cffb048f8Voidcore|r|cffddddddBerater|r"
L["REMINDER_SUBTITLE"] = "Optimiere deine Beutespezialisierung für Nebulöse Leerenkerne!"
L["REMINDER_VOIDCORE_COUNT"] = "Du hast |cffffff00%d|r Nebulösen Leerenkern(e)"
L["REMINDER_CURRENT_SPEC"] = "Aktuelle Beutespezialisierung:"
L["REMINDER_RECOMMENDED"] = "Empfohlene Spezialisierung:"
L["REMINDER_ITEMS_SELECTED"] = "%d Gegenstand/Gegenstände ausgewählt"
L["REMINDER_SELECTED_CHANCE"] = "%d%% Chance für ausgewählte Gegenstände"
L["REMINDER_CHANGE_PROMPT"] = "Beutespezialisierung zu |cffffff00%s|r wechseln?"
L["REMINDER_YES"] = "Ja, wechseln"
L["REMINDER_NO"] = "Nein danke"

-- ── Optionspanel (Options.lua) ────────────────────────────────────────────────

L["OPTIONS_REMINDER_ENABLE"] = "Beutespezialisierungs-Erinnerung"
L["OPTIONS_REMINDER_TOOLTIP"] =
    "Zeigt ein Popup beim Betreten eines aktuellen saisonalen mythischen Dungeons, wenn eine andere Beutespezialisierung bessere Chancen für deine ausgewählten Gegenstände bietet."
L["OPTIONS_PREVIEW_REMINDER"] = "Vorschau"

-- ── Dungeon-Übersichtspanel (DungeonOverview.lua) ────────────────────────────

L["DUNGEON_OVERVIEW_SUBTITLE"] = "M+-Dungeons — Beutechance"
L["DUNGEON_OVERVIEW_COL_DUNGEON"] = "DUNGEON"
L["DUNGEON_OVERVIEW_COL_SPEC"] = "SPEZ."
L["DUNGEON_OVERVIEW_COL_LOOTED"] = "GEPLÜNDERT"
L["DUNGEON_OVERVIEW_COL_CHANCE"] = "CHANCE"
L["DUNGEON_OVERVIEW_ALL_DONE"] = "Alle Dungeon-Gegenstände erhalten!"
L["DUNGEON_OVERVIEW_NO_DATA"] = "Saisonale Dungeon-Daten noch nicht verfügbar."

L["RAID_OVERVIEW_SUBTITLE"] = "Raidbosse — Beutechance"
L["RAID_OVERVIEW_COL_BOSS"] = "BOSS"
L["RAID_OVERVIEW_NO_DATA"] = "Keine Raidbegegnungsdaten verfügbar."

-- ── Spezialisierungsauswahl-Popup (PanelColumns.lua) ─────────────────────────

L["SPEC_PICKER_TITLE"] = "Erhalten als:"
L["SPEC_PICKER_OK"] = "OK"
L["OBTAINED_UNKNOWN_SPEC"] = "Erhalten (Spezialisierung unbekannt)"
