-- VoidcoreAdvisor: Locale – French
if GetLocale() ~= "frFR" then
    return
end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"] = "|cffb048f8Voidcore|r|cffddddddConseiller|r"

L["COL_LOOT"] = "BUTIN"
L["COL_SPEC_RANKING"] = "CLASSEMENT SPÉC."
L["COL_SPEC_FIT"] = "COMPAT. SPÉC."
L["COL_LOOT_FILTERED"] = "BUTIN (filtré)"
L["COL_LOOT_FILTERED_N"] = "BUTIN (filtré %d spéc.)"

L["CONTENT_RAID_BOSS"] = "Boss de raid"
L["CONTENT_MP_DUNGEON"] = "Donjon M+"
L["NEBULOUS_VOIDCORE"] = "Noyau du Vide nébuleux"
L["NEBULOUS_VOIDCORES"] = "Noyaux du Vide nébuleux"

L["NO_ITEMS_FOR_SPEC"] = "Aucun objet pour cette spécialisation"

L["LOOT_SPEC_LABEL"] = "Butin :"
L["ALL_OBTAINED"] = "✓ tous"

L["DETECTED_OBTAINED"] = "%s détecté automatiquement comme obtenu via un Noyau du Vide nébuleux."

L["CLEAR_SELECTED"] = "Effacer la sélection"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"] = "Toutes les données d'objets obtenus ont été réinitialisées."
L["COUNT_FORMAT"] = "%d objet(s) marqué(s) comme obtenu(s) via Noyau du Vide."
L["SPEC_FORMAT"] = "ID de spécialisation de butin active : %s%s"
L["FOLLOWS_ACTIVE_SPEC"] = " (suit la spécialisation active)"
L["SOURCE_FORMAT"] = "Source active — type : %s  IDsource : %s  difficulté : %s"
L["NO_ACTIVE_SOURCE"] = "Aucune source active définie."
L["VERSION_FORMAT"] = "Version %s"
L["HELP_HEADER"] = "Commandes :"
L["HELP_RESET"] = "  /vca reset    – réinitialiser les données d'objets obtenus"
L["HELP_COUNT"] = "  /vca count    – afficher le nombre total d'objets obtenus"
L["HELP_SPEC"] = "  /vca spec     – afficher l'ID de spécialisation de butin"
L["HELP_SOURCE"] = "  /vca source   – afficher la source de détection active"
L["HELP_VERSION"] = "  /vca version  – afficher la version de l'addon"

-- ── Panel UI (ajouts) ─────────────────────────────────────────────────────────

L["LFR_NOT_ELIGIBLE"] = "Indisponible en Recherche de raid"

L["TOGGLE_SHOW"] = "Cliquer pour afficher le panneau de conseils."
L["TOGGLE_HIDE"] = "Cliquer pour masquer le panneau de conseils."
L["TOGGLE_OVERVIEW_SHOW"] = "Cliquer pour afficher la vue d'ensemble des donjons."
L["TOGGLE_OVERVIEW_HIDE"] = "Cliquer pour masquer la vue d'ensemble des donjons."

-- ── Popup de rappel (Reminder.lua) ───────────────────────────────────────────

L["REMINDER_TITLE"] = "|cffb048f8Voidcore|r|cffddddddConseiller|r"
L["REMINDER_SUBTITLE"] = "Optimisez votre spécialisation de butin pour les récompenses du Noyau du Vide nébuleux !"
L["REMINDER_VOIDCORE_COUNT"] = "Vous avez |cffffff00%d|r Noyau(x) du Vide nébuleux"
L["REMINDER_CURRENT_SPEC"] = "Spécialisation de butin actuelle :"
L["REMINDER_RECOMMENDED"] = "Spécialisation recommandée :"
L["REMINDER_ITEMS_SELECTED"] = "%d objet(s) sélectionné(s)"
L["REMINDER_SELECTED_CHANCE"] = "%d%% de chance pour l'objet sélectionné"
L["REMINDER_CHANGE_PROMPT"] = "Changer la spécialisation de butin pour |cffffff00%s|r ?"
L["REMINDER_YES"] = "Oui, changer"
L["REMINDER_NO"] = "Non merci"

-- ── Panneau d'options (Options.lua) ──────────────────────────────────────────

L["OPTIONS_REMINDER_ENABLE"] = "Rappel de spécialisation de butin"
L["OPTIONS_REMINDER_TOOLTIP"] =
    "Affiche un popup lors de l'entrée dans un donjon mythique de la saison actuelle si une spécialisation de butin différente donnerait de meilleures chances pour vos objets sélectionnés."
L["OPTIONS_PREVIEW_REMINDER"] = "Aperçu"

-- ── Panneau de vue d'ensemble des donjons (DungeonOverview.lua) ──────────────

L["DUNGEON_OVERVIEW_SUBTITLE"] = "Donjons M+ — Chance de butin"
L["DUNGEON_OVERVIEW_COL_DUNGEON"] = "DONJON"
L["DUNGEON_OVERVIEW_COL_SPEC"] = "SPÉC."
L["DUNGEON_OVERVIEW_COL_LOOTED"] = "PILLÉ"
L["DUNGEON_OVERVIEW_COL_CHANCE"] = "CHANCE"
L["DUNGEON_OVERVIEW_ALL_DONE"] = "Tous les objets du donjon obtenus !"
L["DUNGEON_OVERVIEW_NO_DATA"] = "Données de donjon saisonnières pas encore disponibles."

L["RAID_OVERVIEW_SUBTITLE"] = "Boss de raid — Chance de butin"
L["RAID_OVERVIEW_COL_BOSS"] = "BOSS"
L["RAID_OVERVIEW_NO_DATA"] = "Aucune donnée d'affrontement de raid disponible."

-- ── Popup de sélection de spécialisation (PanelColumns.lua) ──────────────────

L["SPEC_PICKER_TITLE"] = "Obtenu en tant que :"
L["SPEC_PICKER_OK"] = "OK"
L["OBTAINED_UNKNOWN_SPEC"] = "Obtenu (spécialisation inconnue)"
