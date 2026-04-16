-- VoidcoreAdvisor: Locale – Italian
if GetLocale() ~= "itIT" then return end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"]             = "|cffb048f8Voidcore|r|cffddddddAdvisor|r"

L["COL_LOOT"]                = "BOTTINO"
L["COL_SPEC_RANKING"]        = "CLASSIFICA SPEC."
L["COL_SPEC_FIT"]            = "COMPAT. SPEC."
L["COL_LOOT_FILTERED"]       = "BOTTINO (filtrato)"
L["COL_LOOT_FILTERED_N"]     = "BOTTINO (filtrate %d spec.)"

L["CONTENT_RAID_BOSS"]       = "Boss dell'incursione"
L["CONTENT_MP_DUNGEON"]      = "Spedizione M+"
L["NEBULOUS_VOIDCORE"]       = "Nucleo del Vuoto nebuloso"
L["NEBULOUS_VOIDCORES"]      = "Nuclei del Vuoto nebulosi"

L["NO_ITEMS_FOR_SPEC"]       = "Nessun oggetto per questa specializzazione"

L["LOOT_SPEC_LABEL"]         = "Bottino:"
L["ALL_OBTAINED"]            = "✓ tutti"

L["DETECTED_OBTAINED"]       = "%s rilevato automaticamente come ottenuto tramite Nucleo del Vuoto nebuloso."

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"]           = "Tutti i dati degli oggetti ottenuti sono stati reimpostati."
L["COUNT_FORMAT"]            = "%d oggetto/i contrassegnato/i come ottenuto/i tramite Nucleo del Vuoto."
L["SPEC_FORMAT"]             = "ID specializzazione bottino attiva: %s%s"
L["FOLLOWS_ACTIVE_SPEC"]     = " (segue la specializzazione attiva)"
L["SOURCE_FORMAT"]           = "Fonte attiva — tipo: %s  IDfonte: %s  difficoltà: %s"
L["NO_ACTIVE_SOURCE"]        = "Nessuna fonte attiva impostata."
L["VERSION_FORMAT"]          = "Versione %s"
L["HELP_HEADER"]             = "Comandi:"
L["HELP_RESET"]              = "  /vca reset    – reimposta dati degli oggetti ottenuti"
L["HELP_COUNT"]              = "  /vca count    – mostra il totale degli oggetti ottenuti"
L["HELP_SPEC"]               = "  /vca spec     – mostra l'ID della specializzazione bottino"
L["HELP_SOURCE"]             = "  /vca source   – mostra la fonte di rilevamento attiva"
L["HELP_VERSION"]            = "  /vca version  – mostra la versione dell'addon"
