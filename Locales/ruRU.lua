-- VoidcoreAdvisor: Locale – Russian
if GetLocale() ~= "ruRU" then
    return
end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"] = "|cffb048f8Voidcore|r|cffddddddСоветник|r"

L["COL_LOOT"] = "ДОБЫЧА"
L["COL_SPEC_RANKING"] = "РЕЙТИНГ СПЕКОВ"
L["COL_SPEC_FIT"] = "СОВМЕСТИМОСТЬ"
L["COL_LOOT_FILTERED"] = "ДОБЫЧА (фильтр)"
L["COL_LOOT_FILTERED_N"] = "ДОБЫЧА (фильтр %d спек.)"

L["CONTENT_RAID_BOSS"] = "Босс рейда"
L["CONTENT_MP_DUNGEON"] = "Подземелье М+"
L["NEBULOUS_VOIDCORE"] = "Туманное ядро Бездны"
L["NEBULOUS_VOIDCORES"] = "Туманные ядра Бездны"

L["NO_ITEMS_FOR_SPEC"] = "Нет предметов для этого спека"

L["LOOT_SPEC_LABEL"] = "Добыча:"
L["ALL_OBTAINED"] = "✓ все"

L["DETECTED_OBTAINED"] =
    "%s автоматически учтен как полученный через Туманное ядро Бездны."

L["CLEAR_SELECTED"] = "Очистить выбор"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"] = "Все данные о полученных предметах сброшены."
L["COUNT_FORMAT"] =
    "%d предмет(ов) отмечено как полученных через ядро Бездны."
L["SPEC_FORMAT"] = "ID спека добычи: %s%s"
L["FOLLOWS_ACTIVE_SPEC"] = " (следует за активным спеком)"
L["SOURCE_FORMAT"] =
    "Активный источник — тип: %s  ID источника: %s  сложность: %s"
L["NO_ACTIVE_SOURCE"] = "Активный источник не задан."
L["VERSION_FORMAT"] = "Версия %s"
L["HELP_HEADER"] = "Команды:"
L["HELP_RESET"] = "  /vca reset    – сбросить данные о полученных предметах"
L["HELP_COUNT"] = "  /vca count    – показать кол-во отмеченных предметов"
L["HELP_SPEC"] = "  /vca spec     – показать ID спека добычи"
L["HELP_SOURCE"] = "  /vca source   – показать активный источник обнаружения"
L["HELP_VERSION"] = "  /vca version  – показать версию аддона"

-- ── Панель UI (дополнения) ────────────────────────────────────────────────────

L["LFR_NOT_ELIGIBLE"] = "Недоступно в поиске рейда"

L["TOGGLE_SHOW"] = "Нажмите, чтобы показать панель советника."
L["TOGGLE_HIDE"] = "Нажмите, чтобы скрыть панель советника."
L["TOGGLE_OVERVIEW_SHOW"] = "Нажмите, чтобы показать обзор подземелий."
L["TOGGLE_OVERVIEW_HIDE"] = "Нажмите, чтобы скрыть обзор подземелий."

-- ── Всплывающее напоминание (Reminder.lua) ───────────────────────────────────

L["REMINDER_TITLE"] = "|cffb048f8Voidcore|r|cffddddddСоветник|r"
L["REMINDER_SUBTITLE"] =
    "Оптимизируйте специализацию добычи для наград Туманного ядра Бездны!"
L["REMINDER_VOIDCORE_COUNT"] = "У вас |cffffff00%d|r Туманное/ых ядер Бездны"
L["REMINDER_CURRENT_SPEC"] = "Текущая специализация добычи:"
L["REMINDER_RECOMMENDED"] = "Рекомендуемая специализация:"
L["REMINDER_ITEMS_SELECTED"] = "Выбрано предметов: %d"
L["REMINDER_SELECTED_CHANCE"] = "%d%% шанс на выбранные предметы"
L["REMINDER_CHANGE_PROMPT"] = "Сменить специализацию добычи на |cffffff00%s|r?"
L["REMINDER_YES"] = "Да, сменить"
L["REMINDER_NO"] = "Нет, спасибо"

-- ── Панель настроек (Options.lua) ─────────────────────────────────────────────

L["OPTIONS_REMINDER_ENABLE"] = "Напоминание о специализации добычи"
L["OPTIONS_REMINDER_TOOLTIP"] =
    "Показывает всплывающее окно при входе в мифическое подземелье текущего сезона, если другая специализация добычи даст лучшие шансы на выбранные предметы."
L["OPTIONS_PREVIEW_REMINDER"] = "Предпросмотр"

-- ── Панель обзора подземелий (DungeonOverview.lua) ───────────────────────────

L["DUNGEON_OVERVIEW_SUBTITLE"] = "Подземелья М+ — Шанс добычи"
L["DUNGEON_OVERVIEW_COL_DUNGEON"] = "ПОДЗЕМЕЛЬЕ"
L["DUNGEON_OVERVIEW_COL_SPEC"] = "СПЕК"
L["DUNGEON_OVERVIEW_COL_LOOTED"] = "ПОЛУЧЕНО"
L["DUNGEON_OVERVIEW_COL_CHANCE"] = "ШАНС"
L["DUNGEON_OVERVIEW_ALL_DONE"] = "Все предметы подземелья получены!"
L["DUNGEON_OVERVIEW_NO_DATA"] = "Данные о подземельях сезона пока недоступны."

L["RAID_OVERVIEW_SUBTITLE"] = "Боссы рейда — Шанс добычи"
L["RAID_OVERVIEW_COL_BOSS"] = "БОСС"
L["RAID_OVERVIEW_NO_DATA"] = "Нет данных о встречах в рейде."

-- ── Всплывающий выбор специализации (PanelColumns.lua) ───────────────────────

L["SPEC_PICKER_TITLE"] = "Получено как:"
L["SPEC_PICKER_OK"] = "OK"
L["OBTAINED_UNKNOWN_SPEC"] = "Получено (специализация неизвестна)"
