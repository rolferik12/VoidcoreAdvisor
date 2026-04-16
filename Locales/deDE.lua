-- VoidcoreAdvisor: Locale – German
if GetLocale() ~= "deDE" then return end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"]             = "|cffb048f8Voidcore|r|cffddddddBerater|r"

L["COL_LOOT"]                = "BEUTE"
L["COL_SPEC_RANKING"]        = "SPEZ.-RANKING"
L["COL_SPEC_FIT"]            = "SPEZ.-EIGNUNG"
L["COL_LOOT_FILTERED"]       = "BEUTE (gefiltert)"
L["COL_LOOT_FILTERED_N"]     = "BEUTE (gefiltert %d Spez.)"

L["CONTENT_RAID_BOSS"]       = "Raidboss"
L["CONTENT_MP_DUNGEON"]      = "M+-Dungeon"
L["NEBULOUS_VOIDCORE"]       = "Nebulöser Leerenkern"
L["NEBULOUS_VOIDCORES"]      = "Nebulöse Leerenkerne"

L["NO_ITEMS_FOR_SPEC"]       = "Keine Gegenstände für diese Spezialisierung"

L["LOOT_SPEC_LABEL"]         = "Beute:"
L["ALL_OBTAINED"]            = "✓ alle"

L["DETECTED_OBTAINED"]       = "%s automatisch als über Nebulösen Leerenkern erhalten erkannt."

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"]           = "Alle erhaltenen Gegenstände wurden zurückgesetzt."
L["COUNT_FORMAT"]            = "%d Gegenstand/Gegenstände als über Leerenkern erhalten markiert."
L["SPEC_FORMAT"]             = "Aktive Beutespezialisierungs-ID: %s%s"
L["FOLLOWS_ACTIVE_SPEC"]     = " (folgt aktiver Spezialisierung)"
L["SOURCE_FORMAT"]           = "Aktive Quelle — Typ: %s  QuellenID: %s  Schwierigkeit: %s"
L["NO_ACTIVE_SOURCE"]        = "Keine aktive Quelle gesetzt."
L["VERSION_FORMAT"]          = "Version %s"
L["HELP_HEADER"]             = "Befehle:"
L["HELP_RESET"]              = "  /vca reset    – alle erhaltenen Gegenstände zurücksetzen"
L["HELP_COUNT"]              = "  /vca count    – Gesamtzahl erhaltener Gegenstände anzeigen"
L["HELP_SPEC"]               = "  /vca spec     – aktive Beutespezialisierungs-ID anzeigen"
L["HELP_SOURCE"]             = "  /vca source   – aktive Erkennungsquelle anzeigen"
L["HELP_VERSION"]            = "  /vca version  – Addon-Version anzeigen"
