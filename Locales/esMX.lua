-- VoidcoreAdvisor: Locale – Spanish (Mexico)
if GetLocale() ~= "esMX" then return end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"]             = "|cffb048f8Voidcore|r|cffddddddAdvisor|r"

L["COL_LOOT"]                = "BOTÍN"
L["COL_SPEC_RANKING"]        = "RANKING DE ESPEC."
L["COL_SPEC_FIT"]            = "AJUSTE DE ESPEC."
L["COL_LOOT_FILTERED"]       = "BOTÍN (filtrado)"
L["COL_LOOT_FILTERED_N"]     = "BOTÍN (filtrado %d espec.)"

L["CONTENT_RAID_BOSS"]       = "Jefe de banda"
L["CONTENT_MP_DUNGEON"]      = "Calabozo M+"
L["NEBULOUS_VOIDCORE"]       = "Núcleo del Vacío nebuloso"
L["NEBULOUS_VOIDCORES"]      = "Núcleos del Vacío nebulosos"

L["NO_ITEMS_FOR_SPEC"]       = "No hay objetos para esta especialización"

L["LOOT_SPEC_LABEL"]         = "Botín:"
L["ALL_OBTAINED"]            = "✓ todos"

L["DETECTED_OBTAINED"]       = "%s detectado automáticamente como obtenido mediante Núcleo del Vacío nebuloso."

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"]           = "Se han restablecido todos los datos de objetos obtenidos."
L["COUNT_FORMAT"]            = "%d objeto(s) marcado(s) como obtenido(s) mediante Núcleo del Vacío."
L["SPEC_FORMAT"]             = "ID de especialización de botín activa: %s%s"
L["FOLLOWS_ACTIVE_SPEC"]     = " (sigue la especialización activa)"
L["SOURCE_FORMAT"]           = "Fuente activa — tipo: %s  IDfuente: %s  dificultad: %s"
L["NO_ACTIVE_SOURCE"]        = "No hay ninguna fuente activa."
L["VERSION_FORMAT"]          = "Versión %s"
L["HELP_HEADER"]             = "Comandos:"
L["HELP_RESET"]              = "  /vca reset    – restablecer todos los datos de objetos obtenidos"
L["HELP_COUNT"]              = "  /vca count    – mostrar total de objetos marcados como obtenidos"
L["HELP_SPEC"]               = "  /vca spec     – mostrar ID de especialización de botín activa"
L["HELP_SOURCE"]             = "  /vca source   – mostrar fuente de detección activa"
L["HELP_VERSION"]            = "  /vca version  – mostrar versión del addon"
