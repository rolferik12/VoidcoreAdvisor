-- VoidcoreAdvisor: Locale – Italian
if GetLocale() ~= "itIT" then
    return
end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"] = "|cffb048f8Voidcore|r|cffddddddAdvisor|r"

L["COL_LOOT"] = "BOTTINO"
L["COL_SPEC_RANKING"] = "CLASSIFICA SPEC."
L["COL_SPEC_FIT"] = "COMPAT. SPEC."
L["COL_LOOT_FILTERED"] = "BOTTINO (filtrato)"
L["COL_LOOT_FILTERED_N"] = "BOTTINO (filtrate %d spec.)"

L["CONTENT_RAID_BOSS"] = "Boss dell'incursione"
L["CONTENT_MP_DUNGEON"] = "Spedizione M+"
L["NEBULOUS_VOIDCORE"] = "Nucleo del Vuoto nebuloso"
L["NEBULOUS_VOIDCORES"] = "Nuclei del Vuoto nebulosi"

L["NO_ITEMS_FOR_SPEC"] = "Nessun oggetto per questa specializzazione"

L["LOOT_SPEC_LABEL"] = "Bottino:"
L["ALL_OBTAINED"] = "✓ tutti"

L["DETECTED_OBTAINED"] = "%s rilevato automaticamente come ottenuto tramite Nucleo del Vuoto nebuloso."

L["CLEAR_SELECTED"] = "Cancella selezione"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"] = "Tutti i dati degli oggetti ottenuti sono stati reimpostati."
L["COUNT_FORMAT"] = "%d oggetto/i contrassegnato/i come ottenuto/i tramite Nucleo del Vuoto."
L["SPEC_FORMAT"] = "ID specializzazione bottino attiva: %s%s"
L["FOLLOWS_ACTIVE_SPEC"] = " (segue la specializzazione attiva)"
L["SOURCE_FORMAT"] = "Fonte attiva — tipo: %s  IDfonte: %s  difficoltà: %s"
L["NO_ACTIVE_SOURCE"] = "Nessuna fonte attiva impostata."
L["VERSION_FORMAT"] = "Versione %s"
L["HELP_HEADER"] = "Comandi:"
L["HELP_RESET"] = "  /vca reset    – reimposta dati degli oggetti ottenuti"
L["HELP_COUNT"] = "  /vca count    – mostra il totale degli oggetti ottenuti"
L["HELP_SPEC"] = "  /vca spec     – mostra l'ID della specializzazione bottino"
L["HELP_SOURCE"] = "  /vca source   – mostra la fonte di rilevamento attiva"
L["HELP_VERSION"] = "  /vca version  – mostra la versione dell'addon"

-- ── Panel UI (aggiunte) ───────────────────────────────────────────────────────

L["LFR_NOT_ELIGIBLE"] = "Non disponibile nel Cercatore di incursione"

L["TOGGLE_SHOW"] = "Clic per mostrare il pannello di consigli."
L["TOGGLE_HIDE"] = "Clic per nascondere il pannello di consigli."
L["TOGGLE_OVERVIEW_SHOW"] = "Clic per mostrare il riepilogo delle spedizioni."
L["TOGGLE_OVERVIEW_HIDE"] = "Clic per nascondere il riepilogo delle spedizioni."

-- ── Popup di promemoria (Reminder.lua) ───────────────────────────────────────

L["REMINDER_TITLE"] = "|cffb048f8Voidcore|r|cffddddddAdvisor|r"
L["REMINDER_SUBTITLE"] = "Ottimizza la tua specializzazione bottino per le ricompense del Nucleo del Vuoto nebuloso!"
L["REMINDER_VOIDCORE_COUNT"] = "Hai |cffffff00%d|r Nucleo/i del Vuoto nebuloso"
L["REMINDER_CURRENT_SPEC"] = "Spec. bottino corrente:"
L["REMINDER_RECOMMENDED"] = "Spec. consigliata:"
L["REMINDER_ITEMS_SELECTED"] = "%d oggetto/i selezionato/i"
L["REMINDER_SELECTED_CHANCE"] = "%d%% di probabilità per oggetti selezionati"
L["REMINDER_CHANGE_PROMPT"] = "Cambiare specializzazione bottino in |cffffff00%s|r?"
L["REMINDER_YES"] = "Sì, cambia"
L["REMINDER_NO"] = "No grazie"

-- ── Pannello opzioni (Options.lua) ────────────────────────────────────────────

L["OPTIONS_REMINDER_ENABLE"] = "Promemoria specializzazione bottino"
L["OPTIONS_REMINDER_TOOLTIP"] =
    "Mostra un popup quando si entra in una spedizione mitica della stagione corrente se una specializzazione bottino diversa darebbe migliori probabilità per gli oggetti selezionati."
L["OPTIONS_PREVIEW_REMINDER"] = "Anteprima"

-- ── Pannello riepilogo spedizioni (DungeonOverview.lua) ───────────────────────

L["DUNGEON_OVERVIEW_SUBTITLE"] = "Spedizioni M+ — Probabilità bottino"
L["DUNGEON_OVERVIEW_COL_DUNGEON"] = "SPEDIZIONE"
L["DUNGEON_OVERVIEW_COL_SPEC"] = "SPEC."
L["DUNGEON_OVERVIEW_COL_LOOTED"] = "SACCHEGGIATO"
L["DUNGEON_OVERVIEW_COL_CHANCE"] = "CHANCE"
L["DUNGEON_OVERVIEW_ALL_DONE"] = "Tutti gli oggetti della spedizione ottenuti!"
L["DUNGEON_OVERVIEW_NO_DATA"] = "Dati stagionali delle spedizioni non ancora disponibili."

L["RAID_OVERVIEW_SUBTITLE"] = "Boss dell'incursione — Probabilità bottino"
L["RAID_OVERVIEW_COL_BOSS"] = "BOSS"
L["RAID_OVERVIEW_NO_DATA"] = "Nessun dato di scontro nell'incursione disponibile."

-- ── Popup selezione specializzazione (PanelColumns.lua) ──────────────────────

L["SPEC_PICKER_TITLE"] = "Ottenuto come:"
L["SPEC_PICKER_OK"] = "OK"
L["OBTAINED_UNKNOWN_SPEC"] = "Ottenuto (specializzazione sconosciuta)"
