-- VoidcoreAdvisor: Locale – Chinese (Traditional)
if GetLocale() ~= "zhTW" then return end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"]             = "|cffb048f8虛無核心|r|cffdddddd助手|r"

L["COL_LOOT"]                = "拾取"
L["COL_SPEC_RANKING"]        = "專精排名"
L["COL_SPEC_FIT"]            = "專精適配"
L["COL_LOOT_FILTERED"]       = "拾取（已篩選）"
L["COL_LOOT_FILTERED_N"]     = "拾取（已篩選 %d 個專精）"

L["CONTENT_RAID_BOSS"]       = "團隊首領"
L["CONTENT_MP_DUNGEON"]      = "傳奇鑰石地城"
L["NEBULOUS_VOIDCORE"]       = "星雲虛無核心"
L["NEBULOUS_VOIDCORES"]      = "星雲虛無核心"

L["NO_ITEMS_FOR_SPEC"]       = "此專精沒有可用物品"

L["LOOT_SPEC_LABEL"]         = "拾取："
L["ALL_OBTAINED"]            = "✓ 全部"

L["DETECTED_OBTAINED"]       = "已自動偵測到 %s 透過星雲虛無核心取得。"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"]           = "所有已取得物品資料已重設。"
L["COUNT_FORMAT"]            = "已標記 %d 件物品為透過虛無核心取得。"
L["SPEC_FORMAT"]             = "目前拾取專精 ID：%s%s"
L["FOLLOWS_ACTIVE_SPEC"]     = "（跟隨目前專精）"
L["SOURCE_FORMAT"]           = "目前來源 - 類型：%s  來源ID：%s  難度：%s"
L["NO_ACTIVE_SOURCE"]        = "未設定活動來源。"
L["VERSION_FORMAT"]          = "版本 %s"
L["HELP_HEADER"]             = "指令："
L["HELP_RESET"]              = "  /vca reset    – 重設所有已取得物品資料"
L["HELP_COUNT"]              = "  /vca count    – 顯示已取得物品總數"
L["HELP_SPEC"]               = "  /vca spec     – 顯示拾取專精 ID"
L["HELP_SOURCE"]             = "  /vca source   – 顯示目前偵測來源"
L["HELP_VERSION"]            = "  /vca version  – 顯示插件版本"
