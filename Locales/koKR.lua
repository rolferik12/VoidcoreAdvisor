-- VoidcoreAdvisor: Locale – Korean
if GetLocale() ~= "koKR" then
    return
end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"] = "|cffb048f8공허핵|r|cffdddddd도우미|r"

L["COL_LOOT"] = "전리품"
L["COL_SPEC_RANKING"] = "전문화 순위"
L["COL_SPEC_FIT"] = "전문화 적합도"
L["COL_LOOT_FILTERED"] = "전리품 (필터됨)"
L["COL_LOOT_FILTERED_N"] = "전리품 (전문화 %d개 필터)"

L["CONTENT_RAID_BOSS"] = "공격대 우두머리"
L["CONTENT_MP_DUNGEON"] = "쐐기돌 던전"
L["NEBULOUS_VOIDCORE"] = "성운의 공허핵"
L["NEBULOUS_VOIDCORES"] = "성운의 공허핵"

L["NO_ITEMS_FOR_SPEC"] = "이 전문화에 해당하는 아이템이 없습니다"

L["LOOT_SPEC_LABEL"] = "전리품:"
L["ALL_OBTAINED"] = "✓ 전부"

L["DETECTED_OBTAINED"] = "%s|1을;를; 성운의 공허핵으로 획득한 것으로 자동 감지했습니다."

L["CLEAR_SELECTED"] = "선택 해제"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"] = "획득한 아이템 데이터가 모두 초기화되었습니다."
L["COUNT_FORMAT"] = "공허핵으로 획득한 아이템 %d개가 표시되어 있습니다."
L["SPEC_FORMAT"] = "현재 전리품 전문화 ID: %s%s"
L["FOLLOWS_ACTIVE_SPEC"] = " (활성 전문화를 따름)"
L["SOURCE_FORMAT"] = "활성 출처 — 유형: %s  출처ID: %s  난이도: %s"
L["NO_ACTIVE_SOURCE"] = "활성 출처가 설정되지 않았습니다."
L["VERSION_FORMAT"] = "버전 %s"
L["HELP_HEADER"] = "명령어:"
L["HELP_RESET"] = "  /vca reset    – 획득 아이템 데이터 초기화"
L["HELP_COUNT"] = "  /vca count    – 획득한 아이템 총 수 표시"
L["HELP_SPEC"] = "  /vca spec     – 전리품 전문화 ID 표시"
L["HELP_SOURCE"] = "  /vca source   – 활성 감지 출처 표시"
L["HELP_VERSION"] = "  /vca version  – 애드온 버전 표시"

-- ── 패널 UI (추가) ────────────────────────────────────────────────────────────

L["LFR_NOT_ELIGIBLE"] = "공격대 찾기에서는 사용 불가"

L["TOGGLE_SHOW"] = "클릭하여 어드바이저 패널을 표시합니다."
L["TOGGLE_HIDE"] = "클릭하여 어드바이저 패널을 숨깁니다."
L["TOGGLE_OVERVIEW_SHOW"] = "클릭하여 던전 개요를 표시합니다."
L["TOGGLE_OVERVIEW_HIDE"] = "클릭하여 던전 개요를 숨깁니다."

-- ── 알림 팝업 (Reminder.lua) ──────────────────────────────────────────────────

L["REMINDER_TITLE"] = "|cffb048f8공허핵|r|cffdddddd도우미|r"
L["REMINDER_SUBTITLE"] = "성운의 공허핵 보상을 위해 전리품 전문화를 최적화하세요!"
L["REMINDER_VOIDCORE_COUNT"] = "성운의 공허핵이 |cffffff00%d|r개 있습니다"
L["REMINDER_CURRENT_SPEC"] = "현재 전리품 전문화:"
L["REMINDER_RECOMMENDED"] = "권장 전문화:"
L["REMINDER_ITEMS_SELECTED"] = "%d개 아이템 선택됨"
L["REMINDER_SELECTED_CHANCE"] = "선택한 아이템 %d%% 확률"
L["REMINDER_CHANGE_PROMPT"] = "전리품 전문화를 |cffffff00%s|r(으)로 변경하시겠습니까?"
L["REMINDER_YES"] = "예, 변경"
L["REMINDER_NO"] = "아니요"

-- ── 옵션 패널 (Options.lua) ───────────────────────────────────────────────────

L["OPTIONS_REMINDER_ENABLE"] = "전리품 전문화 알림"
L["OPTIONS_REMINDER_TOOLTIP"] =
    "현재 시즌 쐐기돌 던전에 입장할 때 다른 전리품 전문화가 선택한 아이템에 더 나은 확률을 제공하면 팝업을 표시합니다."
L["OPTIONS_PREVIEW_REMINDER"] = "미리 보기"

-- ── 던전 개요 패널 (DungeonOverview.lua) ─────────────────────────────────────

L["DUNGEON_OVERVIEW_SUBTITLE"] = "쐐기돌 던전 — 전리품 확률"
L["DUNGEON_OVERVIEW_COL_DUNGEON"] = "던전"
L["DUNGEON_OVERVIEW_COL_SPEC"] = "전문화"
L["DUNGEON_OVERVIEW_COL_LOOTED"] = "획득됨"
L["DUNGEON_OVERVIEW_COL_CHANCE"] = "확률"
L["DUNGEON_OVERVIEW_ALL_DONE"] = "모든 던전 아이템을 획득했습니다!"
L["DUNGEON_OVERVIEW_NO_DATA"] = "시즌 던전 데이터를 아직 사용할 수 없습니다."

L["RAID_OVERVIEW_SUBTITLE"] = "공격대 우두머리 — 전리품 확률"
L["RAID_OVERVIEW_COL_BOSS"] = "우두머리"
L["RAID_OVERVIEW_NO_DATA"] = "공격대 조우 데이터를 사용할 수 없습니다."

-- ── 전문화 선택 팝업 (PanelColumns.lua) ──────────────────────────────────────

L["SPEC_PICKER_TITLE"] = "획득 방식:"
L["SPEC_PICKER_OK"] = "확인"
L["OBTAINED_UNKNOWN_SPEC"] = "획득 (전문화 알 수 없음)"
