-- VoidcoreAdvisor: Reminder
-- Popup shown when entering a current-season mythic dungeon if the player's
-- loot spec is not the best match for their selected items.
--
-- Trigger:
--   PLAYER_ENTERING_WORLD fires after each loading screen.  After a short
--   delay (to let instance data settle), the module checks whether:
--     1. The player is inside a current-season M+ dungeon (difficultyID 8 or 23).
--     2. The player has items selected for this dungeon.
--     3. A different loot spec gives better odds for those selected items.
--   If all three conditions are met, a dialog-style popup is shown offering
--   to change the loot specialization.

local _, VCA = ...
local L = VCA.L

VCA.Reminder = {}
local Reminder = VCA.Reminder

-- ── State ─────────────────────────────────────────────────────────────────────

local lastShownInstanceID = nil   -- prevents re-showing for the same dungeon
local pendingSpecID       = nil   -- specID to switch to if user clicks "Yes"

-- ── Main frame ────────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame", "VoidcoreAdvisorReminder", UIParent, "BackdropTemplate")
frame:SetSize(360, 290)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:Hide()

frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true,
    tileSize = 32,
    edgeSize = 32,
    insets   = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:SetBackdropColor(0.05, 0.02, 0.12, 0.95)
frame:SetBackdropBorderColor(0.58, 0.0, 0.82, 1)

-- ESC key closes the popup via the global UISpecialFrames mechanism.
tinsert(UISpecialFrames, "VoidcoreAdvisorReminder")

-- ── Title ─────────────────────────────────────────────────────────────────────

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -14)
title:SetText(L["REMINDER_TITLE"])

local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
subtitle:SetText("|cff888888" .. L["REMINDER_SUBTITLE"] .. "|r")

local voidcoreCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
voidcoreCount:SetPoint("TOP", subtitle, "BOTTOM", 0, -3)

local divider = frame:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(0.58, 0.0, 0.82, 0.4)
divider:SetPoint("TOPLEFT",  frame, "TOPLEFT",  16, -56)
divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -56)
divider:SetHeight(1)

-- ── Current loot spec row ─────────────────────────────────────────────────────

local curHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
curHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -68)
curHeader:SetText("|cff888888" .. L["REMINDER_CURRENT_SPEC"] .. "|r")

local curIcon = frame:CreateTexture(nil, "ARTWORK")
curIcon:SetSize(28, 28)
curIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -88)
curIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local curName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
curName:SetPoint("LEFT", curIcon, "RIGHT", 8, 0)

-- ── Recommended loot spec row ─────────────────────────────────────────────────

local recHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
recHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -130)
recHeader:SetText("|cff00ff00" .. L["REMINDER_RECOMMENDED"] .. "|r")

local recIcon = frame:CreateTexture(nil, "ARTWORK")
recIcon:SetSize(28, 28)
recIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -150)
recIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local recName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
recName:SetPoint("LEFT", recIcon, "RIGHT", 8, 0)

local recStats = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
recStats:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -184)

-- ── Prompt ────────────────────────────────────────────────────────────────────

local prompt = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
prompt:SetPoint("LEFT",  frame, "LEFT",  20, 0)
prompt:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
prompt:SetPoint("BOTTOM", frame, "BOTTOM", 0, 56)
prompt:SetJustifyH("CENTER")

-- ── Buttons ───────────────────────────────────────────────────────────────────

local yesBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
yesBtn:SetSize(140, 28)
yesBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 30, 18)
yesBtn:SetText(L["REMINDER_YES"])

yesBtn:SetScript("OnClick", function()
    if pendingSpecID then
        SetLootSpecialization(pendingSpecID)
    end
    frame:Hide()
end)

local noBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
noBtn:SetSize(140, 28)
noBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 18)
noBtn:SetText(L["REMINDER_NO"])

noBtn:SetScript("OnClick", function()
    frame:Hide()
end)

-- ── Show / Hide ───────────────────────────────────────────────────────────────

function Reminder.Show(currentSpecID, bestEntry, selectedCount)
    -- Voidcore count
    local currInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(VCA.VOIDCORE_CURRENCY_ID)
    local owned = currInfo and currInfo.quantity or 0
    voidcoreCount:SetText(string.format(L["REMINDER_VOIDCORE_COUNT"], owned))

    -- Current spec info
    local _, curSpecName, _, curSpecIcon = GetSpecializationInfoByID(currentSpecID)
    curIcon:SetTexture(curSpecIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    curName:SetText("|cffdddddd" .. (curSpecName or "Unknown") .. "|r")

    -- Recommended spec info
    recIcon:SetTexture(bestEntry.specIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    recName:SetText("|cffffff00" .. (bestEntry.specName or "Unknown") .. "|r")

    local pct = math.floor((bestEntry.selectedOdds or 0) * 100 + 0.5)
    recStats:SetText(
        string.format(L["REMINDER_ITEMS_SELECTED"], selectedCount) ..
        "  |cff888888\226\128\162|r  " ..
        "|cffffff00" .. string.format(L["REMINDER_SELECTED_CHANCE"], pct) .. "|r"
    )

    prompt:SetText(string.format(L["REMINDER_CHANGE_PROMPT"], bestEntry.specName or "?"))

    pendingSpecID = bestEntry.specID
    frame:Show()
end

function Reminder.Hide()
    frame:Hide()
end

-- ── Evaluation ────────────────────────────────────────────────────────────────

function Reminder.Evaluate()
    -- Check if the reminder is disabled in settings.
    local db = _G[VCA.GLOBAL_DB_NAME]
    if db and db.reminderEnabled == false then return end

    local instanceName, instanceType, difficultyID = GetInstanceInfo()

    -- Reset tracking when not inside a 5-man dungeon.
    if instanceType ~= "party" then
        lastShownInstanceID = nil
        return
    end

    -- Only mythic difficulties: 23 = Mythic 0, 8 = Mythic Keystone (M+).
    if difficultyID ~= 23 and difficultyID ~= 8 then return end

    -- Don't remind if the player has no Voidcores to spend.
    local currInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(VCA.VOIDCORE_CURRENCY_ID)
    local owned = currInfo and currInfo.quantity or 0
    if owned < 1 then return end

    -- Season filter may have been built too early (before C_ChallengeMode
    -- data was available).  Force a rebuild if the list is still empty.
    if #VCA.LootPool.GetSeasonDungeonInstanceIDs() == 0 then
        VCA.LootPool.BuildSeasonFilter()
    end

    -- Map the in-game instance name to the EJ instanceID.
    local ejInstanceID = VCA.LootPool.GetSeasonDungeonByName(instanceName)
    if not ejInstanceID then return end  -- not a current-season dungeon

    -- Don't re-show for the same dungeon until the player leaves.
    if lastShownInstanceID == ejInstanceID then return end

    -- Check if the player has selected items for this dungeon.
    local selectedSet = VCA.Data.GetSelectedItems(
        VCA.ContentType.MYTHIC_PLUS, ejInstanceID, VCA.MythicPlusEJDifficulty)
    if not next(selectedSet) then return end

    local selectedList = {}
    for id in pairs(selectedSet) do
        selectedList[#selectedList + 1] = id
    end

    -- Rank all player specs by probability for the selected items.
    local rankings = VCA.Probability.RankCurrentPlayerSpecsForItems(
        selectedList, VCA.ContentType.MYTHIC_PLUS, ejInstanceID, VCA.MythicPlusEJDifficulty)

    if not rankings or #rankings == 0 then return end

    local bestSpec = rankings[1]
    if not bestSpec or bestSpec.noItems or bestSpec.allObtained then return end
    if (bestSpec.selectedOdds or 0) <= 0 then return end

    -- Already on the best spec — no reminder needed.
    local currentLootSpecID = VCA.SpecInfo.GetEffectiveLootSpecID()
    if currentLootSpecID == bestSpec.specID then return end

    lastShownInstanceID = ejInstanceID
    Reminder.Show(currentLootSpecID, bestSpec, #selectedList)
end

-- ── Event handler ─────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, isInitialLogin, isReloadingUi)
    -- Skip UI reloads to avoid repeated popups.
    if isReloadingUi then return end
    -- Short delay so instance info and loot pool caches are ready.
    C_Timer.After(2, function()
        Reminder.Evaluate()
    end)
end)
