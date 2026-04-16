-- VoidcoreAdvisor: Locale – Portuguese (Brazil)
if GetLocale() ~= "ptBR" then return end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"]             = "|cffb048f8Voidcore|r|cffddddddAdvisor|r"

L["COL_LOOT"]                = "SAQUE"
L["COL_SPEC_RANKING"]        = "RANKING DE ESPEC."
L["COL_SPEC_FIT"]            = "AJUSTE DE ESPEC."
L["COL_LOOT_FILTERED"]       = "SAQUE (filtrado)"
L["COL_LOOT_FILTERED_N"]     = "SAQUE (filtrado %d espec.)"

L["CONTENT_RAID_BOSS"]       = "Chefe de raide"
L["CONTENT_MP_DUNGEON"]      = "Masmorra M+"
L["NEBULOUS_VOIDCORE"]       = "Núcleo do Vazio Nebuloso"
L["NEBULOUS_VOIDCORES"]      = "Núcleos do Vazio Nebulosos"

L["NO_ITEMS_FOR_SPEC"]       = "Nenhum item para esta especialização"

L["LOOT_SPEC_LABEL"]         = "Saque:"
L["ALL_OBTAINED"]            = "✓ todos"

L["DETECTED_OBTAINED"]       = "%s detectado automaticamente como obtido via Núcleo do Vazio Nebuloso."

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"]           = "Todos os dados de itens obtidos foram redefinidos."
L["COUNT_FORMAT"]            = "%d item(ns) marcado(s) como obtido(s) via Núcleo do Vazio."
L["SPEC_FORMAT"]             = "ID de especialização de saque ativa: %s%s"
L["FOLLOWS_ACTIVE_SPEC"]     = " (segue a especialização ativa)"
L["SOURCE_FORMAT"]           = "Fonte ativa — tipo: %s  IDfonte: %s  dificuldade: %s"
L["NO_ACTIVE_SOURCE"]        = "Nenhuma fonte ativa definida."
L["VERSION_FORMAT"]          = "Versão %s"
L["HELP_HEADER"]             = "Comandos:"
L["HELP_RESET"]              = "  /vca reset    – redefinir dados de itens obtidos"
L["HELP_COUNT"]              = "  /vca count    – mostrar total de itens marcados como obtidos"
L["HELP_SPEC"]               = "  /vca spec     – mostrar ID de especialização de saque"
L["HELP_SOURCE"]             = "  /vca source   – mostrar fonte de detecção ativa"
L["HELP_VERSION"]            = "  /vca version  – mostrar versão do addon"
