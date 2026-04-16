-- VoidcoreAdvisor: Locale – French
if GetLocale() ~= "frFR" then return end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"]             = "|cffb048f8Voidcore|r|cffddddddConseiller|r"

L["COL_LOOT"]                = "BUTIN"
L["COL_SPEC_RANKING"]        = "CLASSEMENT SPÉC."
L["COL_SPEC_FIT"]            = "COMPAT. SPÉC."
L["COL_LOOT_FILTERED"]       = "BUTIN (filtré)"
L["COL_LOOT_FILTERED_N"]     = "BUTIN (filtré %d spéc.)"

L["CONTENT_RAID_BOSS"]       = "Boss de raid"
L["CONTENT_MP_DUNGEON"]      = "Donjon M+"
L["NEBULOUS_VOIDCORE"]       = "Noyau du Vide nébuleux"
L["NEBULOUS_VOIDCORES"]      = "Noyaux du Vide nébuleux"

L["NO_ITEMS_FOR_SPEC"]       = "Aucun objet pour cette spécialisation"

L["LOOT_SPEC_LABEL"]         = "Butin :"
L["ALL_OBTAINED"]            = "✓ tous"

L["DETECTED_OBTAINED"]       = "%s détecté automatiquement comme obtenu via un Noyau du Vide nébuleux."

L["CLEAR_SELECTED"]          = "Effacer la sélection"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"]           = "Toutes les données d'objets obtenus ont été réinitialisées."
L["COUNT_FORMAT"]            = "%d objet(s) marqué(s) comme obtenu(s) via Noyau du Vide."
L["SPEC_FORMAT"]             = "ID de spécialisation de butin active : %s%s"
L["FOLLOWS_ACTIVE_SPEC"]     = " (suit la spécialisation active)"
L["SOURCE_FORMAT"]           = "Source active — type : %s  IDsource : %s  difficulté : %s"
L["NO_ACTIVE_SOURCE"]        = "Aucune source active définie."
L["VERSION_FORMAT"]          = "Version %s"
L["HELP_HEADER"]             = "Commandes :"
L["HELP_RESET"]              = "  /vca reset    – réinitialiser les données d'objets obtenus"
L["HELP_COUNT"]              = "  /vca count    – afficher le nombre total d'objets obtenus"
L["HELP_SPEC"]               = "  /vca spec     – afficher l'ID de spécialisation de butin"
L["HELP_SOURCE"]             = "  /vca source   – afficher la source de détection active"
L["HELP_VERSION"]            = "  /vca version  – afficher la version de l'addon"
