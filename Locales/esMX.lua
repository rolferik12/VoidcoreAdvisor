-- VoidcoreAdvisor: Locale – Spanish (Mexico)
if GetLocale() ~= "esMX" then
    return
end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"] = "|cffb048f8Voidcore|r|cffddddddAdvisor|r"

L["COL_LOOT"] = "BOTÍN"
L["COL_SPEC_RANKING"] = "RANKING DE ESPEC."
L["COL_SPEC_FIT"] = "AJUSTE DE ESPEC."
L["COL_LOOT_FILTERED"] = "BOTÍN (filtrado)"
L["COL_LOOT_FILTERED_N"] = "BOTÍN (filtrado %d espec.)"

L["CONTENT_RAID_BOSS"] = "Jefe de banda"
L["CONTENT_MP_DUNGEON"] = "Calabozo M+"
L["NEBULOUS_VOIDCORE"] = "Núcleo del Vacío nebuloso"
L["NEBULOUS_VOIDCORES"] = "Núcleos del Vacío nebulosos"

L["NO_ITEMS_FOR_SPEC"] = "No hay objetos para esta especialización"

L["LOOT_SPEC_LABEL"] = "Botín:"
L["ALL_OBTAINED"] = "✓ todos"

L["DETECTED_OBTAINED"] = "%s detectado automáticamente como obtenido mediante Núcleo del Vacío nebuloso."

L["CLEAR_SELECTED"] = "Borrar selección"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"] = "Se han restablecido todos los datos de objetos obtenidos."
L["COUNT_FORMAT"] = "%d objeto(s) marcado(s) como obtenido(s) mediante Núcleo del Vacío."
L["SPEC_FORMAT"] = "ID de especialización de botín activa: %s%s"
L["FOLLOWS_ACTIVE_SPEC"] = " (sigue la especialización activa)"
L["SOURCE_FORMAT"] = "Fuente activa — tipo: %s  IDfuente: %s  dificultad: %s"
L["NO_ACTIVE_SOURCE"] = "No hay ninguna fuente activa."
L["VERSION_FORMAT"] = "Versión %s"
L["HELP_HEADER"] = "Comandos:"
L["HELP_RESET"] = "  /vca reset    – restablecer todos los datos de objetos obtenidos"
L["HELP_COUNT"] = "  /vca count    – mostrar total de objetos marcados como obtenidos"
L["HELP_SPEC"] = "  /vca spec     – mostrar ID de especialización de botín activa"
L["HELP_SOURCE"] = "  /vca source   – mostrar fuente de detección activa"
L["HELP_VERSION"] = "  /vca version  – mostrar versión del addon"

-- ── Panel UI (adiciones) ──────────────────────────────────────────────────────

L["LFR_NOT_ELIGIBLE"] = "No disponible en el Buscador de banda"

L["TOGGLE_SHOW"] = "Haz clic para mostrar el panel de consejos."
L["TOGGLE_HIDE"] = "Haz clic para ocultar el panel de consejos."
L["TOGGLE_OVERVIEW_SHOW"] = "Haz clic para mostrar el resumen de calabozos."
L["TOGGLE_OVERVIEW_HIDE"] = "Haz clic para ocultar el resumen de calabozos."

-- ── Ventana de recordatorio (Reminder.lua) ────────────────────────────────────

L["REMINDER_TITLE"] = "|cffb048f8Voidcore|r|cffddddddAdvisor|r"
L["REMINDER_SUBTITLE"] =
    "¡Optimiza tu especialización de botín para las recompensas del Núcleo del Vacío nebuloso!"
L["REMINDER_VOIDCORE_COUNT"] = "Tienes |cffffff00%d|r Núcleo(s) del Vacío nebuloso"
L["REMINDER_CURRENT_SPEC"] = "Especialización de botín actual:"
L["REMINDER_RECOMMENDED"] = "Especialización recomendada:"
L["REMINDER_ITEMS_SELECTED"] = "%d objeto(s) seleccionado(s)"
L["REMINDER_SELECTED_CHANCE"] = "%d%% de probabilidad para objeto(s) seleccionado(s)"
L["REMINDER_CHANGE_PROMPT"] = "¿Cambiar especialización de botín a |cffffff00%s|r?"
L["REMINDER_YES"] = "Sí, cambiar"
L["REMINDER_NO"] = "No, gracias"

-- ── Panel de opciones (Options.lua) ──────────────────────────────────────────

L["OPTIONS_REMINDER_ENABLE"] = "Recordatorio de especialización de botín"
L["OPTIONS_REMINDER_TOOLTIP"] =
    "Muestra un popup al entrar en un calabozo mítico de la temporada actual si una especialización de botín diferente daría mejores probabilidades para los objetos seleccionados."
L["OPTIONS_PREVIEW_REMINDER"] = "Vista previa"

-- ── Panel de resumen de calabozos (DungeonOverview.lua) ───────────────────────

L["DUNGEON_OVERVIEW_SUBTITLE"] = "Calabozos M+ — Probabilidad de botín"
L["DUNGEON_OVERVIEW_COL_DUNGEON"] = "CALABOZO"
L["DUNGEON_OVERVIEW_COL_SPEC"] = "ESPEC."
L["DUNGEON_OVERVIEW_COL_LOOTED"] = "SAQUEADO"
L["DUNGEON_OVERVIEW_COL_CHANCE"] = "PROB."
L["DUNGEON_OVERVIEW_ALL_DONE"] = "¡Todos los objetos de calabozo obtenidos!"
L["DUNGEON_OVERVIEW_NO_DATA"] = "Datos de calabozos de temporada aún no disponibles."

L["RAID_OVERVIEW_SUBTITLE"] = "Jefes de banda — Probabilidad de botín"
L["RAID_OVERVIEW_COL_BOSS"] = "JEFE"
L["RAID_OVERVIEW_NO_DATA"] = "No hay datos de encuentros de banda disponibles."

-- ── Ventana de selección de especialización (PanelColumns.lua) ───────────────

L["SPEC_PICKER_TITLE"] = "Obtenido como:"
L["SPEC_PICKER_OK"] = "Aceptar"
L["OBTAINED_UNKNOWN_SPEC"] = "Obtenido (especialización desconocida)"
