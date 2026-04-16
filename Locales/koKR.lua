-- VoidcoreAdvisor: Locale – Korean
if GetLocale() ~= "koKR" then return end
local _, VCA = ...
local L = VCA.L

-- ── Panel UI ──────────────────────────────────────────────────────────────────

L["PANEL_TITLE"]             = "|cffb048f8공허핵|r|cffdddddd도우미|r"

L["COL_LOOT"]                = "전리품"
L["COL_SPEC_RANKING"]        = "전문화 순위"
L["COL_SPEC_FIT"]            = "전문화 적합도"
L["COL_LOOT_FILTERED"]       = "전리품 (필터됨)"
L["COL_LOOT_FILTERED_N"]     = "전리품 (전문화 %d개 필터)"

L["CONTENT_RAID_BOSS"]       = "공격대 우두머리"
L["CONTENT_MP_DUNGEON"]      = "쐐기돌 던전"
L["NEBULOUS_VOIDCORE"]       = "성운의 공허핵"
L["NEBULOUS_VOIDCORES"]      = "성운의 공허핵"

L["NO_ITEMS_FOR_SPEC"]       = "이 전문화에 해당하는 아이템이 없습니다"

L["LOOT_SPEC_LABEL"]         = "전리품:"
L["ALL_OBTAINED"]            = "✓ 전부"

L["DETECTED_OBTAINED"]       = "%s|1을;를; 성운의 공허핵으로 획득한 것으로 자동 감지했습니다."

L["CLEAR_SELECTED"]          = "선택 해제"

-- ── Slash commands ────────────────────────────────────────────────────────────

L["RESET_CONFIRM"]           = "획득한 아이템 데이터가 모두 초기화되었습니다."
L["COUNT_FORMAT"]            = "공허핵으로 획득한 아이템 %d개가 표시되어 있습니다."
L["SPEC_FORMAT"]             = "현재 전리품 전문화 ID: %s%s"
L["FOLLOWS_ACTIVE_SPEC"]     = " (활성 전문화를 따름)"
L["SOURCE_FORMAT"]           = "활성 출처 — 유형: %s  출처ID: %s  난이도: %s"
L["NO_ACTIVE_SOURCE"]        = "활성 출처가 설정되지 않았습니다."
L["VERSION_FORMAT"]          = "버전 %s"
L["HELP_HEADER"]             = "명령어:"
L["HELP_RESET"]              = "  /vca reset    – 획득 아이템 데이터 초기화"
L["HELP_COUNT"]              = "  /vca count    – 획득한 아이템 총 수 표시"
L["HELP_SPEC"]               = "  /vca spec     – 전리품 전문화 ID 표시"
L["HELP_SOURCE"]             = "  /vca source   – 활성 감지 출처 표시"
L["HELP_VERSION"]            = "  /vca version  – 애드온 버전 표시"
