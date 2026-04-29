-- VoidcoreAdvisor: Locale – Portuguese (Brazil)
if GetLocale() ~= "ptBR" then
    return
end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"] = "|cffb048f8Voidcore|r|cffddddddAdvisor|r"

L["COL_LOOT"] = "SAQUE"
L["COL_SPEC_RANKING"] = "RANKING DE ESPEC."
L["COL_SPEC_FIT"] = "AJUSTE DE ESPEC."
L["COL_LOOT_FILTERED"] = "SAQUE (filtrado)"
L["COL_LOOT_FILTERED_N"] = "SAQUE (filtrado %d espec.)"

L["CONTENT_RAID_BOSS"] = "Chefe de raide"
L["CONTENT_MP_DUNGEON"] = "Masmorra M+"
L["NEBULOUS_VOIDCORE"] = "Núcleo do Vazio Nebuloso"
L["NEBULOUS_VOIDCORES"] = "Núcleos do Vazio Nebulosos"

L["NO_ITEMS_FOR_SPEC"] = "Nenhum item para esta especialização"

L["LOOT_SPEC_LABEL"] = "Saque:"
L["ALL_OBTAINED"] = "✓ todos"

L["DETECTED_OBTAINED"] = "%s detectado automaticamente como obtido via Núcleo do Vazio Nebuloso."

L["CLEAR_SELECTED"] = "Limpar seleção"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"] = "Todos os dados de itens obtidos foram redefinidos."
L["COUNT_FORMAT"] = "%d item(ns) marcado(s) como obtido(s) via Núcleo do Vazio."
L["SPEC_FORMAT"] = "ID de especialização de saque ativa: %s%s"
L["FOLLOWS_ACTIVE_SPEC"] = " (segue a especialização ativa)"
L["SOURCE_FORMAT"] = "Fonte ativa — tipo: %s  IDfonte: %s  dificuldade: %s"
L["NO_ACTIVE_SOURCE"] = "Nenhuma fonte ativa definida."
L["VERSION_FORMAT"] = "Versão %s"
L["HELP_HEADER"] = "Comandos:"
L["HELP_RESET"] = "  /vca reset    – redefinir dados de itens obtidos"
L["HELP_COUNT"] = "  /vca count    – mostrar total de itens marcados como obtidos"
L["HELP_SPEC"] = "  /vca spec     – mostrar ID de especialização de saque"
L["HELP_SOURCE"] = "  /vca source   – mostrar fonte de detecção ativa"
L["HELP_VERSION"] = "  /vca version  – mostrar versão do addon"

-- ── Panel UI (adições) ────────────────────────────────────────────────────────

L["LFR_NOT_ELIGIBLE"] = "Não disponível no Buscador de raide"

L["TOGGLE_SHOW"] = "Clique para mostrar o painel de conselhos."
L["TOGGLE_HIDE"] = "Clique para ocultar o painel de conselhos."
L["TOGGLE_OVERVIEW_SHOW"] = "Clique para mostrar o resumo das masmorras."
L["TOGGLE_OVERVIEW_HIDE"] = "Clique para ocultar o resumo das masmorras."

-- ── Popup de lembrete (Reminder.lua) ─────────────────────────────────────────

L["REMINDER_TITLE"] = "|cffb048f8Voidcore|r|cffddddddAdvisor|r"
L["REMINDER_SUBTITLE"] = "Otimize sua especialização de saque para as recompensas do Núcleo do Vazio Nebuloso!"
L["REMINDER_VOIDCORE_COUNT"] = "Você tem |cffffff00%d|r Núcleo(s) do Vazio Nebuloso"
L["REMINDER_CURRENT_SPEC"] = "Especialização de saque atual:"
L["REMINDER_RECOMMENDED"] = "Especialização recomendada:"
L["REMINDER_ITEMS_SELECTED"] = "%d item(ns) selecionado(s)"
L["REMINDER_SELECTED_CHANCE"] = "%d%% de chance para item(ns) selecionado(s)"
L["REMINDER_CHANGE_PROMPT"] = "Alterar especialização de saque para |cffffff00%s|r?"
L["REMINDER_YES"] = "Sim, alterar"
L["REMINDER_NO"] = "Não, obrigado"

-- ── Painel de opções (Options.lua) ────────────────────────────────────────────

L["OPTIONS_REMINDER_ENABLE"] = "Lembrete de especialização de saque"
L["OPTIONS_REMINDER_TOOLTIP"] =
    "Exibe um popup ao entrar em uma masmorra mítica da temporada atual se uma especialização de saque diferente ofereceria melhores chances para os itens selecionados."
L["OPTIONS_PREVIEW_REMINDER"] = "Pré-visualizar"

-- ── Painel de resumo de masmorras (DungeonOverview.lua) ───────────────────────

L["DUNGEON_OVERVIEW_SUBTITLE"] = "Masmorras M+ — Chance de saque"
L["DUNGEON_OVERVIEW_COL_DUNGEON"] = "MASMORRA"
L["DUNGEON_OVERVIEW_COL_SPEC"] = "ESPEC."
L["DUNGEON_OVERVIEW_COL_LOOTED"] = "SAQUEADO"
L["DUNGEON_OVERVIEW_COL_CHANCE"] = "CHANCE"
L["DUNGEON_OVERVIEW_ALL_DONE"] = "Todos os itens de masmorra obtidos!"
L["DUNGEON_OVERVIEW_NO_DATA"] = "Dados de masmorras da temporada ainda não disponíveis."

L["RAID_OVERVIEW_SUBTITLE"] = "Chefes de raide — Chance de saque"
L["RAID_OVERVIEW_COL_BOSS"] = "CHEFE"
L["RAID_OVERVIEW_NO_DATA"] = "Nenhum dado de encontro de raide disponível."

-- ── Popup de seleção de especialização (PanelColumns.lua) ────────────────────

L["SPEC_PICKER_TITLE"] = "Obtido como:"
L["SPEC_PICKER_OK"] = "OK"
L["OBTAINED_UNKNOWN_SPEC"] = "Obtido (especialização desconhecida)"
