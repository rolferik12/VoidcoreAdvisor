-- VoidcoreAdvisor: Locale – Chinese (Simplified)
if GetLocale() ~= "zhCN" then return end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"]             = "|cffb048f8虚空核心|r|cffdddddd助手|r"

L["COL_LOOT"]                = "拾取"
L["COL_SPEC_RANKING"]        = "专精排名"
L["COL_SPEC_FIT"]            = "专精适配"
L["COL_LOOT_FILTERED"]       = "拾取（已筛选）"
L["COL_LOOT_FILTERED_N"]     = "拾取（已筛选 %d 个专精）"

L["CONTENT_RAID_BOSS"]       = "团队首领"
L["CONTENT_MP_DUNGEON"]      = "史诗钥石地下城"
L["NEBULOUS_VOIDCORE"]       = "星云虚空核心"
L["NEBULOUS_VOIDCORES"]      = "星云虚空核心"

L["NO_ITEMS_FOR_SPEC"]       = "该专精没有可用物品"

L["LOOT_SPEC_LABEL"]         = "拾取："
L["ALL_OBTAINED"]            = "✓ 全部"

L["DETECTED_OBTAINED"]       = "已自动检测到 %s 通过星云虚空核心获取。"

L["CLEAR_SELECTED"]          = "清除选择"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"]           = "所有已获取物品数据已重置。"
L["COUNT_FORMAT"]            = "已标记 %d 件物品为通过虚空核心获取。"
L["SPEC_FORMAT"]             = "当前拾取专精 ID：%s%s"
L["FOLLOWS_ACTIVE_SPEC"]     = "（跟随当前专精）"
L["SOURCE_FORMAT"]           = "当前来源 - 类型：%s  来源ID：%s  难度：%s"
L["NO_ACTIVE_SOURCE"]        = "未设置活动来源。"
L["VERSION_FORMAT"]          = "版本 %s"
L["HELP_HEADER"]             = "命令："
L["HELP_RESET"]              = "  /vca reset    – 重置所有已获取物品数据"
L["HELP_COUNT"]              = "  /vca count    – 显示已获取物品总数"
L["HELP_SPEC"]               = "  /vca spec     – 显示拾取专精 ID"
L["HELP_SOURCE"]             = "  /vca source   – 显示当前检测来源"
L["HELP_VERSION"]            = "  /vca version  – 显示插件版本"
