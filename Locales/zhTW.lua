-- VoidcoreAdvisor: Locale – Chinese (Traditional)
if GetLocale() ~= "zhTW" then
    return
end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"] = "|cffb048f8虛無核心|r|cffdddddd助手|r"

L["COL_LOOT"] = "拾取"
L["COL_SPEC_RANKING"] = "專精排名"
L["COL_SPEC_FIT"] = "專精適配"
L["COL_LOOT_FILTERED"] = "拾取（已篩選）"
L["COL_LOOT_FILTERED_N"] = "拾取（已篩選 %d 個專精）"

L["CONTENT_RAID_BOSS"] = "團隊首領"
L["CONTENT_MP_DUNGEON"] = "傳奇鑰石地城"
L["NEBULOUS_VOIDCORE"] = "星雲虛無核心"
L["NEBULOUS_VOIDCORES"] = "星雲虛無核心"

L["NO_ITEMS_FOR_SPEC"] = "此專精沒有可用物品"

L["LOOT_SPEC_LABEL"] = "拾取："
L["ALL_OBTAINED"] = "✓ 全部"

L["DETECTED_OBTAINED"] = "已自動偵測到 %s 透過星雲虛無核心取得。"

L["CLEAR_SELECTED"] = "清除選擇"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"] = "所有已取得物品資料已重設。"
L["COUNT_FORMAT"] = "已標記 %d 件物品為透過虛無核心取得。"
L["SPEC_FORMAT"] = "目前拾取專精 ID：%s%s"
L["FOLLOWS_ACTIVE_SPEC"] = "（跟隨目前專精）"
L["SOURCE_FORMAT"] = "目前來源 - 類型：%s  來源ID：%s  難度：%s"
L["NO_ACTIVE_SOURCE"] = "未設定活動來源。"
L["VERSION_FORMAT"] = "版本 %s"
L["HELP_HEADER"] = "指令："
L["HELP_RESET"] = "  /vca reset    – 重設所有已取得物品資料"
L["HELP_COUNT"] = "  /vca count    – 顯示已取得物品總數"
L["HELP_SPEC"] = "  /vca spec     – 顯示拾取專精 ID"
L["HELP_SOURCE"] = "  /vca source   – 顯示目前偵測來源"
L["HELP_VERSION"] = "  /vca version  – 顯示插件版本"

-- ── 面板 UI（補充）────────────────────────────────────────────────────────────

L["LFR_NOT_ELIGIBLE"] = "在尋找團隊中不可用"

L["TOGGLE_SHOW"] = "點擊顯示顧問面板。"
L["TOGGLE_HIDE"] = "點擊隱藏顧問面板。"
L["TOGGLE_OVERVIEW_SHOW"] = "點擊顯示地城概覽。"
L["TOGGLE_OVERVIEW_HIDE"] = "點擊隱藏地城概覽。"

-- ── 提醒彈窗（Reminder.lua）──────────────────────────────────────────────────

L["REMINDER_TITLE"] = "|cffb048f8虛無核心|r|cffdddddd助手|r"
L["REMINDER_SUBTITLE"] = "優化您的拾取專精以獲得星雲虛無核心獎勵！"
L["REMINDER_VOIDCORE_COUNT"] = "您有 |cffffff00%d|r 個星雲虛無核心"
L["REMINDER_CURRENT_SPEC"] = "目前拾取專精："
L["REMINDER_RECOMMENDED"] = "推薦專精："
L["REMINDER_ITEMS_SELECTED"] = "已選擇 %d 件物品"
L["REMINDER_SELECTED_CHANCE"] = "選中物品的機率 %d%%"
L["REMINDER_CHANGE_PROMPT"] = "將拾取專精更改為 |cffffff00%s|r？"
L["REMINDER_YES"] = "是，更改"
L["REMINDER_NO"] = "不，謝謝"

-- ── 選項面板（Options.lua）───────────────────────────────────────────────────

L["OPTIONS_REMINDER_ENABLE"] = "拾取專精提醒"
L["OPTIONS_REMINDER_TOOLTIP"] =
    "當進入當前賽季傳奇鑰石地城時，如果其他拾取專精能為選定物品提供更好的機率，則顯示彈出視窗。"
L["OPTIONS_PREVIEW_REMINDER"] = "預覽"

-- ── 地城概覽面板（DungeonOverview.lua）───────────────────────────────────────

L["DUNGEON_OVERVIEW_SUBTITLE"] = "傳奇鑰石地城 — 拾取機率"
L["DUNGEON_OVERVIEW_COL_DUNGEON"] = "地城"
L["DUNGEON_OVERVIEW_COL_SPEC"] = "專精"
L["DUNGEON_OVERVIEW_COL_LOOTED"] = "已取得"
L["DUNGEON_OVERVIEW_COL_CHANCE"] = "機率"
L["DUNGEON_OVERVIEW_ALL_DONE"] = "所有地城物品均已取得！"
L["DUNGEON_OVERVIEW_NO_DATA"] = "賽季地城資料暫不可用。"

L["RAID_OVERVIEW_SUBTITLE"] = "團隊首領 — 拾取機率"
L["RAID_OVERVIEW_COL_BOSS"] = "首領"
L["RAID_OVERVIEW_NO_DATA"] = "沒有團隊遭遇資料可用。"

-- ── 專精選擇彈窗（PanelColumns.lua）──────────────────────────────────────────

L["SPEC_PICKER_TITLE"] = "取得方式："
L["SPEC_PICKER_OK"] = "確定"
L["OBTAINED_UNKNOWN_SPEC"] = "已取得（專精未知）"
