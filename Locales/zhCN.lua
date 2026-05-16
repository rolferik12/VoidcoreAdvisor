-- VoidcoreAdvisor: Locale – Chinese (Simplified)
if GetLocale() ~= "zhCN" then
    return
end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"] = "|cffb048f8虚空核心|r|cffdddddd助手|r"

L["COL_LOOT"] = "拾取"
L["COL_SPEC_RANKING"] = "专精排名"
L["COL_SPEC_FIT"] = "专精适配"
L["COL_LOOT_FILTERED"] = "拾取（已筛选）"
L["COL_LOOT_FILTERED_N"] = "拾取（已筛选 %d 个专精）"

L["CONTENT_RAID_BOSS"] = "团队首领"
L["CONTENT_MP_DUNGEON"] = "史诗钥石地下城"
L["NEBULOUS_VOIDCORE"] = "星云虚空核心"
L["NEBULOUS_VOIDCORES"] = "星云虚空核心"

L["NO_ITEMS_FOR_SPEC"] = "该专精没有可用物品"

L["LOOT_SPEC_LABEL"] = "拾取："
L["ALL_OBTAINED"] = "✓ 全部"

L["DETECTED_OBTAINED"] = "已自动检测到 %s 通过星云虚空核心获取。"

L["CLEAR_SELECTED"] = "清除选择"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"] = "所有已获取物品数据已重置。"
L["COUNT_FORMAT"] = "已标记 %d 件物品为通过虚空核心获取。"
L["SPEC_FORMAT"] = "当前拾取专精 ID：%s%s"
L["FOLLOWS_ACTIVE_SPEC"] = "（跟随当前专精）"
L["SOURCE_FORMAT"] = "当前来源 - 类型：%s  来源ID：%s  难度：%s"
L["NO_ACTIVE_SOURCE"] = "未设置活动来源。"
L["VERSION_FORMAT"] = "版本 %s"
L["HELP_HEADER"] = "命令："
L["HELP_RESET"] = "  /vca reset    – 重置所有已获取物品数据"
L["HELP_COUNT"] = "  /vca count    – 显示已获取物品总数"
L["HELP_SPEC"] = "  /vca spec     – 显示拾取专精 ID"
L["HELP_SOURCE"] = "  /vca source   – 显示当前检测来源"
L["HELP_VERSION"] = "  /vca version  – 显示插件版本"

-- ── 面板 UI（补充）────────────────────────────────────────────────────────────

L["LFR_NOT_ELIGIBLE"] = "在寻找团队中不可用"

L["TOGGLE_SHOW"] = "点击显示顾问面板。"
L["TOGGLE_HIDE"] = "点击隐藏顾问面板。"
L["TOGGLE_OVERVIEW_SHOW"] = "点击显示地下城概览。"
L["TOGGLE_OVERVIEW_HIDE"] = "点击隐藏地下城概览。"

-- ── 提醒弹窗（Reminder.lua）──────────────────────────────────────────────────

L["REMINDER_TITLE"] = "|cffb048f8虚空核心|r|cffdddddd助手|r"
L["REMINDER_SUBTITLE"] = "优化你的拾取专精以获得星云虚空核心奖励！"
L["REMINDER_VOIDCORE_COUNT"] = "你有 |cffffff00%d|r 个星云虚空核心"
L["REMINDER_CURRENT_SPEC"] = "当前拾取专精："
L["REMINDER_RECOMMENDED"] = "推荐专精："
L["REMINDER_ITEMS_SELECTED"] = "已选择 %d 件物品"
L["REMINDER_SELECTED_CHANCE"] = "选中物品的概率 %d%%"
L["REMINDER_CHANGE_PROMPT"] = "将拾取专精更改为 |cffffff00%s|r？"
L["REMINDER_YES"] = "是，更改"
L["REMINDER_NO"] = "不，谢谢"
L["REMINDER_WARNING_ONE_ITEM"] =
    "|cffff8000警告：|r 该专精在本地下城中|cffff0000只剩1件物品|r。以该专精使用星云虚空核心将|cffff0000重置本地下城所有专精的战利品池|r！"
L["REMINDER_SPEC_LIST_HEADER"] = "各专精剩余物品："
L["REMINDER_SPEC_REMAINING"] = "剩余 %d 件"
L["REMINDER_SPEC_NONE"] = "无剩余"

-- ── 战利品池重置警告弹窗（Reminder.lua）─────────────────────────────────────

L["WARNING_TITLE"] = "|cffb048f8虚空核心|r|cffdddddd助手|r"
L["WARNING_SUBTITLE"] = "战利品池重置风险"
L["WARNING_VOIDCORE_COUNT"] = "你有 |cffffff00%d|r 个星云虚空核心"
L["WARNING_FAVORED_SPEC"] = "你正在使用首选拾取专精："
L["WARNING_ONE_ITEM"] =
    "|cffff8000警告：|r 该专精在本地下城中|cffff0000只剩 %d 件物品|r。使用星云虚空核心将|cffff0000重置本地下城所有专精的战利品池|r！"
L["WARNING_SPEC_LIST_HEADER"] = "各专精剩余物品："
L["WARNING_CLOSE"] = "关闭"

-- ── 选项面板（Options.lua）───────────────────────────────────────────────────

L["OPTIONS_REMINDER_ENABLE"] = "拾取专精提醒"
L["OPTIONS_REMINDER_TOOLTIP"] =
    "当进入当前赛季史诗钥石地下城时，如果其他拾取专精能为选定物品提供更好的概率，则显示弹出窗口。"
L["OPTIONS_PREVIEW_REMINDER"] = "预览"

-- ── 地下城概览面板（DungeonOverview.lua）─────────────────────────────────────

L["DUNGEON_OVERVIEW_SUBTITLE"] = "史诗钥石地下城 — 拾取概率"
L["DUNGEON_OVERVIEW_COL_DUNGEON"] = "地下城"
L["DUNGEON_OVERVIEW_COL_SPEC"] = "专精"
L["DUNGEON_OVERVIEW_COL_LOOTED"] = "已获取"
L["DUNGEON_OVERVIEW_COL_CHANCE"] = "概率"
L["DUNGEON_OVERVIEW_ALL_DONE"] = "所有地下城物品均已获取！"
L["DUNGEON_OVERVIEW_NO_DATA"] = "赛季地下城数据暂不可用。"

L["RAID_OVERVIEW_SUBTITLE"] = "团队首领 — 拾取概率"
L["RAID_OVERVIEW_COL_BOSS"] = "首领"
L["RAID_OVERVIEW_NO_DATA"] = "没有团队遭遇数据可用。"

-- ── 专精选择弹窗（PanelColumns.lua）──────────────────────────────────────────

L["SPEC_PICKER_TITLE"] = "获取方式："
L["SPEC_PICKER_OK"] = "确定"
L["OBTAINED_UNKNOWN_SPEC"] = "已获取（专精未知）"
L["UNKNOWN_KEYLEVEL"] = "未知钥石等级"
L["MANUAL_ENTRY"] = "手动输入"

-- ── 槽位抽屉（DungeonOverview.lua）──────────────────────────────────────────

L["SLOT_FILTER_TOGGLE"] = "按部位筛选"
L["SLOT_FILTER_CLEAR"] = "取消选择所有部位物品"
L["SLOT_FILTER_CLEAR_CONFIRM"] = "清除所有物品选择？"
L["SLOT_FILTER_CLEAR_CONFIRM_BODY"] = "所有已选择的物品将被取消选择。"

L["SLOT_head"] = "头部"
L["SLOT_neck"] = "颈部"
L["SLOT_shoulder"] = "肩部"
L["SLOT_back"] = "背部"
L["SLOT_chest"] = "胸部"
L["SLOT_wrist"] = "手腕"
L["SLOT_hands"] = "手部"
L["SLOT_waist"] = "腰部"
L["SLOT_legs"] = "腿部"
L["SLOT_feet"] = "脚部"
L["SLOT_finger"] = "指环"
L["SLOT_trinket"] = "饰品"
L["SLOT_SELECT_ALL"] = "全选"
L["SLOT_DESELECT_ALL"] = "取消全选"
L["SLOT_NONE_SELECTED"] = "未选择任何内容"
L["SLOT_weapon"] = "武器"
L["SLOT_offhand"] = "副手"

-- ── 虚空缓存扫描 (VoidcacheScan.lua / DungeonOverview.lua) ────────────────────

L["SCAN_BTN"] = "扫描拾取专精"
L["SCAN_PROGRESS"] = "扫描中 %d/%d..."
L["SCAN_COMPLETE"] = "✓ 扫描完成"
L["SCAN_ABORTED"] = "扫描已取消"
L["SCAN_CONFIRM_TITLE"] = "扫描拾取专精？"
L["SCAN_CONFIRM_BODY"] =
    "将扫描本赛季所有副本中每个拾取专精的星云虚空缓存提示。\n\n现有副本已获得数据将被重置。\n\n扫描期间请勿进入战斗或副本。"
L["SCAN_UNAVAILABLE_COMBAT"] = "战斗中无法扫描。"
L["SCAN_UNAVAILABLE_INSTANCE"] = "副本中无法扫描。"
L["RAID_SCAN_CONFIRM_TITLE"] = "扫描团队副本拾取专精？"
L["RAID_SCAN_CONFIRM_BODY"] =
    "将扫描所有神话团队副本遭遇中每个拾取专精的星云虚空缓存提示。\n\n现有神话团队副本已获得数据将被重置。\n\n扫描期间请勿进入战斗。"
