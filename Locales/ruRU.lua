-- VoidcoreAdvisor: Locale – Russian
if GetLocale() ~= "ruRU" then return end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"]             = "|cffb048f8Voidcore|r|cffddddddСоветник|r"

L["COL_LOOT"]                = "ДОБЫЧА"
L["COL_SPEC_RANKING"]        = "РЕЙТИНГ СПЕКОВ"
L["COL_SPEC_FIT"]            = "СОВМЕСТИМОСТЬ"
L["COL_LOOT_FILTERED"]       = "ДОБЫЧА (фильтр)"
L["COL_LOOT_FILTERED_N"]     = "ДОБЫЧА (фильтр %d спек.)"

L["CONTENT_RAID_BOSS"]       = "Босс рейда"
L["CONTENT_MP_DUNGEON"]      = "Подземелье М+"
L["NEBULOUS_VOIDCORE"]       = "Туманное ядро Бездны"
L["NEBULOUS_VOIDCORES"]      = "Туманные ядра Бездны"

L["NO_ITEMS_FOR_SPEC"]       = "Нет предметов для этого спека"

L["LOOT_SPEC_LABEL"]         = "Добыча:"
L["ALL_OBTAINED"]            = "✓ все"

L["DETECTED_OBTAINED"]       = "%s автоматически учтен как полученный через Туманное ядро Бездны."

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"]           = "Все данные о полученных предметах сброшены."
L["COUNT_FORMAT"]            = "%d предмет(ов) отмечено как полученных через ядро Бездны."
L["SPEC_FORMAT"]             = "ID спека добычи: %s%s"
L["FOLLOWS_ACTIVE_SPEC"]     = " (следует за активным спеком)"
L["SOURCE_FORMAT"]           = "Активный источник — тип: %s  ID источника: %s  сложность: %s"
L["NO_ACTIVE_SOURCE"]        = "Активный источник не задан."
L["VERSION_FORMAT"]          = "Версия %s"
L["HELP_HEADER"]             = "Команды:"
L["HELP_RESET"]              = "  /vca reset    – сбросить данные о полученных предметах"
L["HELP_COUNT"]              = "  /vca count    – показать кол-во отмеченных предметов"
L["HELP_SPEC"]               = "  /vca spec     – показать ID спека добычи"
L["HELP_SOURCE"]             = "  /vca source   – показать активный источник обнаружения"
L["HELP_VERSION"]            = "  /vca version  – показать версию аддона"
