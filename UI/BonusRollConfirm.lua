-- VoidcoreAdvisor: BonusRollConfirm
-- Replaces BonusRollFrame with a custom VCA window positioned at the same
-- screen location (+small offset so the original is still visible behind it).
--
-- Frame level 7 + EnableMouse(true) prevents accidental clicks on the original
-- Roll/Pass buttons (which sit at level 5-6).
--
-- Roll button requires TWO clicks (confirm) â€” this is intentional and critical.
-- Pass button fires immediately (no confirmation).
local addonName, VCA = ...
local L = VCA.L

VCA.BonusRollConfirm = {}
local BRC = VCA.BonusRollConfirm

local isPreview = false
local cachedItemLink = nil -- item link for icon tooltip
local cachedDisplayItemID = nil -- numeric item ID from EJLinkButton.displayItemID

-- â”€â”€ Guard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

local function IsEnabled()
    local gdb = _G[VCA.GLOBAL_DB_NAME]
    return gdb and gdb.bonusRollConfirmEnabled == true
end

local function IsSpecListEnabled()
    local gdb = _G[VCA.GLOBAL_DB_NAME]
    return gdb and gdb.bonusRollConfirmSpecListEnabled ~= false
end

-- Reverse lookup: Voidcache itemID -> { sourceType, sourceID }
-- Built lazily on first call after Constants are loaded.
local cacheItemSourceMap
local function GetSourceFromDisplayItemID(itemID)
    if not itemID then
        return nil
    end
    if not cacheItemSourceMap then
        cacheItemSourceMap = {}
        for instanceID, cid in pairs(VCA.DungeonVoidcacheIDs or {}) do
            cacheItemSourceMap[cid] = {
                sourceType = VCA.ContentType.MYTHIC_PLUS,
                sourceID = instanceID
            }
        end
        for encounterID, cid in pairs(VCA.RaidEncounterCacheIDs or {}) do
            cacheItemSourceMap[cid] = {
                sourceType = VCA.ContentType.RAID,
                sourceID = encounterID
            }
        end
    end
    return cacheItemSourceMap[itemID]
end

-- â”€â”€ Texture-sync helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Copies Normal/Pushed/Highlight/Disabled textures from src onto dst so an
-- interceptor button looks identical to the real Blizzard button.

local function SyncButtonAppearance(src, dst)
    local t
    t = src:GetNormalTexture();
    dst:SetNormalTexture(t and t:GetTexture() or nil)
    t = src:GetPushedTexture();
    dst:SetPushedTexture(t and t:GetTexture() or nil)
    t = src:GetHighlightTexture();
    if t then
        dst:SetHighlightTexture(t:GetTexture())
    end
    t = src:GetDisabledTexture();
    if t then
        dst:SetDisabledTexture(t:GetTexture())
    end
end

-- â”€â”€ Custom window â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- Offset from BonusRollFrame TOPLEFT so the original peeks from behind.

local WIN_GAP_Y = -6 -- gap between BonusRollFrame bottom and our window top

local win = CreateFrame("Frame", "VCARollWindow", UIParent, "BackdropTemplate")
win:SetFrameStrata("DIALOG")
win:SetFrameLevel(7)
win:EnableMouse(true) -- blocks clicks falling through to BonusRollFrame (level 5)
win:Hide()
win:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = {
        left = 11,
        right = 12,
        top = 12,
        bottom = 11
    }
})
win:SetBackdropColor(0.05, 0.02, 0.12, 0.95)
win:SetBackdropBorderColor(0.58, 0.0, 0.82, 1)

-- Title – hidden in compact layout
local winTitle = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
winTitle:SetPoint("TOP", win, "TOP", 0, -14)
winTitle:SetText("|cffb048f8VoidcoreAdvisor|r")
winTitle:Hide()

-- Subtitle – hidden in compact layout
local winSubtitle = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
winSubtitle:SetPoint("TOP", winTitle, "BOTTOM", 0, -2)
winSubtitle:SetText("|cff888888" .. L["BONUS_ROLL_CONFIRM_SUBTITLE"] .. "|r")
winSubtitle:Hide()

-- Header divider – hidden in compact layout
local winHeaderDiv = win:CreateTexture(nil, "ARTWORK")
winHeaderDiv:SetColorTexture(0.58, 0.0, 0.82, 0.4)
winHeaderDiv:SetHeight(1)
winHeaderDiv:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -62)
winHeaderDiv:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, -62)
winHeaderDiv:Hide()

-- Item icon
local winItemIcon = win:CreateTexture(nil, "ARTWORK")
winItemIcon:SetSize(40, 40)
winItemIcon:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -14)
winItemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
winItemIcon:Hide()

-- Transparent button over the icon for tooltip hit-testing
local winIconBtn = CreateFrame("Button", nil, win)
winIconBtn:SetAllPoints(winItemIcon)
winIconBtn:SetScript("OnEnter", function(self)
    -- Try item link first, then bare item ID (covers both live and preview mode)
    local link = cachedItemLink or (cachedDisplayItemID and ("item:" .. cachedDisplayItemID))
    if link then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
        return
    end
    -- Delegate to EJLinkButton's own OnEnter if available
    local pf = BonusRollFrame and BonusRollFrame.PromptFrame
    local ejBtn = pf and pf.EncounterJournalLinkButton
    if ejBtn then
        local onEnter = ejBtn:GetScript("OnEnter")
        if onEnter then
            onEnter(ejBtn)
        end
    end
end)
winIconBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Item name label
local winItemName = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
winItemName:SetPoint("TOPLEFT", winItemIcon, "TOPRIGHT", 8, -2)
winItemName:SetWidth(280)
winItemName:SetJustifyH("LEFT")
winItemName:SetWordWrap(true)

-- Voidcore count + cost line (shown below item name text)
local winVoidcoreInfo = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
winVoidcoreInfo:SetPoint("TOPLEFT", winItemName, "BOTTOMLEFT", 0, -4)

-- Timer bar  (value mirrored from BonusRollFrame.PromptFrame.Timer.Bar via OnUpdate)
local timerBar = CreateFrame("StatusBar", nil, win)
timerBar:SetHeight(8)
timerBar:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -62)
timerBar:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, -62)
timerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
timerBar:SetStatusBarColor(0.58, 0.0, 0.82, 1)
timerBar:SetMinMaxValues(0, 1)
timerBar:SetValue(1)
local timerBg = timerBar:CreateTexture(nil, "BACKGROUND")
timerBg:SetAllPoints()
timerBg:SetColorTexture(0.12, 0.04, 0.20, 0.8)

-- Separator between timer and spec row
local topSep = win:CreateTexture(nil, "ARTWORK")
topSep:SetColorTexture(0.58, 0.0, 0.82, 0.35)
topSep:SetHeight(1)
topSep:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -78)
topSep:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, -78)

-- "Current loot spec:" label + icon (same line, no name)
local specLabel = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
specLabel:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -90)
specLabel:SetText("|cff888888" .. L["REMINDER_CURRENT_SPEC"] .. "|r")

local specIcon = win:CreateTexture(nil, "ARTWORK")
specIcon:SetSize(16, 16)
specIcon:SetPoint("LEFT", specLabel, "RIGHT", 8, 0)
specIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local specName = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
specName:SetPoint("LEFT", specIcon, "RIGHT", 6, 0)

-- Dynamic loot section (only shown when Detection recognises the source)
local lootSep = win:CreateTexture(nil, "ARTWORK")
lootSep:SetColorTexture(0.58, 0.0, 0.82, 0.35)
lootSep:SetHeight(1)
lootSep:Hide()

local lootLine = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lootLine:SetWidth(320)
lootLine:SetJustifyH("CENTER")
lootLine:Hide()

local lootCountLine = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lootCountLine:SetWidth(320)
lootCountLine:SetJustifyH("CENTER")
lootCountLine:Hide()

local warnText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
warnText:SetWidth(320)
warnText:SetJustifyH("CENTER")
warnText:Hide()

-- Per-spec remaining item counts section
local specListSep = win:CreateTexture(nil, "ARTWORK")
specListSep:SetColorTexture(0.58, 0.0, 0.82, 0.35)
specListSep:SetHeight(1)
specListSep:Hide()

local specListHeader = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
specListHeader:SetText("|cff888888" .. L["REMINDER_SPEC_LIST_HEADER"] .. "|r")
specListHeader:Hide()

local specListRows = {}
for i = 1, 4 do
    local row = {}
    row.icon = win:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.label = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.icon:Hide()
    row.label:Hide()
    specListRows[i] = row
end

-- â”€â”€ Roll button â€” 2-click confirmation (EXTREMELY IMPORTANT) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

-- Pre-built button label strings (atlas markup evaluated once at load time).
local ROLL_BTN_TEXT = CreateAtlasMarkup("lootroll-icon-need", 14, 14) .. " " .. L["BONUS_ROLL_CONFIRM_ROLL"]
local PASS_BTN_TEXT = CreateAtlasMarkup("lootroll-icon-pass", 14, 14) .. " " .. L["BONUS_ROLL_CONFIRM_PASS"]

-- Confirmation question above buttons
local winRollPrompt = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
winRollPrompt:SetText(L["BONUS_ROLL_CONFIRM_QUESTION"])
winRollPrompt:Hide()

local rollBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
rollBtn:SetHeight(22)
rollBtn:SetNormalTexture("")
rollBtn:SetPushedTexture("")
rollBtn:SetHighlightTexture("")
rollBtn:SetDisabledTexture("")
rollBtn:SetText(ROLL_BTN_TEXT)
rollBtn:SetScript("OnClick", function()
    StaticPopup_Show("VOIDCORE_BONUS_ROLL", L["BONUS_ROLL_POPUP_ROLL"])
end)

-- â”€â”€ Pass button â€” 2-click confirmation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

local passBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
passBtn:SetHeight(22)
passBtn:SetNormalTexture("")
passBtn:SetPushedTexture("")
passBtn:SetHighlightTexture("")
passBtn:SetDisabledTexture("")
passBtn:SetText(PASS_BTN_TEXT)
passBtn:SetScript("OnClick", function()
    BRC.Hide()
    if not isPreview and BonusRollFrame and BonusRollFrame.PromptFrame and BonusRollFrame.PromptFrame.PassButton then
        BonusRollFrame.PromptFrame.PassButton:Click()
    end
end)

-- â”€â”€ Timer mirroring â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

win:SetScript("OnUpdate", function()
    -- Timer is the StatusBar widget itself; .Bar is its fill Texture (no GetValue)
    if not (BonusRollFrame and BonusRollFrame.PromptFrame and BonusRollFrame.PromptFrame.Timer) then
        return
    end
    local src = BonusRollFrame.PromptFrame.Timer
    if not src.GetValue then
        return
    end
    local lo, hi = src:GetMinMaxValues()
    timerBar:SetMinMaxValues(lo, hi)
    timerBar:SetValue(src:GetValue())
end)

-- Hides per-spec list separator, header and all row widgets.
local function HideSpecList()
    specListSep:Hide()
    specListHeader:Hide()
    for i = 1, 4 do
        specListRows[i].icon:Hide()
        specListRows[i].label:Hide()
    end
end

-- Renders the loot-odds row, per-spec list, and the roll-prompt label onto the
-- window, advancing `dynY` for each section shown.  Returns the final dynY.
-- `source` must carry { sourceType, sourceID, difficultyID } or be nil.
local function LayoutDynamicSection(source, specID, dynY)
    local selectedSet = (source and source.sourceType and source.sourceID) and
                            VCA.Data.GetSelectedItems(source.sourceType, source.sourceID, source.difficultyID) or nil
    local hasSelection = selectedSet and next(selectedSet)

    local probFull = (source and source.sourceType and source.sourceID) and
                         VCA.Probability.CalculateForSpec(source.sourceType, source.sourceID, source.difficultyID,
            VCA.SpecInfo.GetPlayerClassID(), specID, nil) or nil

    if source and source.sourceType and source.sourceID then

        lootSep:ClearAllPoints()
        lootSep:SetPoint("TOPLEFT", win, "TOPLEFT", 16, dynY)
        lootSep:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, dynY)
        lootSep:Show()
        dynY = dynY - 10

        -- ── Loot probability (filtered by selection) ──────────────────────────
        lootLine:ClearAllPoints()
        lootLine:SetPoint("TOP", win, "TOP", 0, dynY)
        if not hasSelection then
            lootLine:SetText("|cff888888" .. L["BONUS_ROLL_CONFIRM_NO_SELECTED"] .. "|r")
            lootLine:Show()
            lootCountLine:Hide()
            dynY = dynY - 20
        else
            local prob = VCA.Probability.CalculateForSpec(source.sourceType, source.sourceID, source.difficultyID,
                VCA.SpecInfo.GetPlayerClassID(), specID, nil, selectedSet)
            if prob.noItems then
                lootLine:SetText("|cff888888" .. L["BONUS_ROLL_CONFIRM_NO_ITEMS"] .. "|r")
                lootLine:Show()
                lootCountLine:Hide()
                dynY = dynY - 20
            elseif prob.allObtained then
                lootLine:SetText("|cff00ff00" .. L["BONUS_ROLL_CONFIRM_ALL_OBTAINED"] .. "|r")
                lootLine:Show()
                lootCountLine:Hide()
                dynY = dynY - 20
            else
                local pct = math.floor((prob.remainingOdds or 0) * 100 + 0.5)
                lootLine:SetText("|cffffff00" .. string.format(L["BONUS_ROLL_CONFIRM_CHANCE"], pct) .. "|r")
                lootLine:Show()
                dynY = dynY - 20
                lootCountLine:ClearAllPoints()
                lootCountLine:SetPoint("TOP", win, "TOP", 0, dynY)
                lootCountLine:SetText("|cffaaaaaa" ..
                                          string.format(
                        prob.remainingCount == 1 and L["BONUS_ROLL_CONFIRM_WANTED_ONE"] or
                            L["BONUS_ROLL_CONFIRM_WANTED_MANY"], prob.remainingCount) .. "|r")
                lootCountLine:Show()
                dynY = dynY - 20
            end
        end
    else
        lootSep:Hide()
        lootLine:Hide()
        lootCountLine:Hide()
        warnText:Hide()
    end

    -- ── Per-spec remaining counts (shown whenever option is on) ───────────────
    if IsSpecListEnabled() and source and source.sourceType and source.sourceID then
        local specs = VCA.SpecInfo.GetPlayerSpecs()
        if specs and #specs > 0 then
            specListSep:ClearAllPoints()
            specListSep:SetPoint("TOPLEFT", win, "TOPLEFT", 16, dynY)
            specListSep:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, dynY)
            specListSep:Show()
            dynY = dynY - 10

            specListHeader:ClearAllPoints()
            specListHeader:SetPoint("TOPLEFT", win, "TOPLEFT", 16, dynY)
            specListHeader:Show()
            dynY = dynY - 20

            local specCount = math.min(#specs, 4)
            local approxRowWidth = specCount * 50 - 12
            local rowStartX = math.floor((360 - approxRowWidth) / 2)
            local rowsUsed = 0
            for _, spec in ipairs(specs) do
                if rowsUsed >= 4 then
                    break
                end
                local items = VCA.LootPool.GetCachedItemsForSpec(source.sourceType, source.sourceID,
                    source.difficultyID, spec.classID, spec.specID)
                if not items then
                    items = VCA.LootPool.GetItemsForSpec(source.sourceType, source.sourceID, source.difficultyID,
                        spec.classID, spec.specID)
                end
                local pool = items or {}
                local total = #pool
                local remaining = 0
                for _, itemID in ipairs(pool) do
                    if not VCA.Data.IsObtained(source.sourceType, source.sourceID, source.difficultyID, spec.specID,
                        itemID) then
                        remaining = remaining + 1
                    end
                end
                local row = specListRows[rowsUsed + 1]
                row.icon:ClearAllPoints()
                if rowsUsed == 0 then
                    row.icon:SetPoint("TOPLEFT", win, "TOPLEFT", rowStartX, dynY)
                else
                    row.icon:SetPoint("LEFT", specListRows[rowsUsed].label, "RIGHT", 12, 0)
                end
                row.icon:SetTexture(spec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.icon:Show()
                local countStr
                if total == 0 then
                    countStr = "|cff888888-|r"
                elseif remaining == 0 then
                    countStr = "|cff00ff00\226\156\147|r"
                elseif remaining == 1 then
                    countStr = "|cffff4444" .. remaining .. "|r"
                else
                    countStr = "|cffdddddd" .. remaining .. "|r"
                end
                row.label:ClearAllPoints()
                row.label:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
                row.label:SetText(countStr)
                row.label:Show()
                rowsUsed = rowsUsed + 1
            end
            dynY = dynY - 26
            for i = rowsUsed + 1, 4 do
                specListRows[i].icon:Hide()
                specListRows[i].label:Hide()
            end
        else
            HideSpecList()
        end
    else
        HideSpecList()
    end

    -- ── Warning (shown last, just above buttons) ──────────────────────────────
    if source and source.sourceType and source.sourceID then
        if probFull and probFull.remainingCount == 1 then
            dynY = dynY - 6 -- spacing above warning
            warnText:ClearAllPoints()
            warnText:SetPoint("TOP", win, "TOP", 0, dynY)
            warnText:SetText(L["BONUS_ROLL_CONFIRM_WARNING"])
            warnText:Show()
            dynY = dynY - 52 - 6 -- text height + spacing below
        else
            warnText:Hide()
        end
    else
        warnText:Hide()
    end

    return dynY
end

-- â”€â”€ BRC.Show â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function BRC.Show()
    if not (BonusRollFrame and BonusRollFrame.PromptFrame) then
        return
    end

    local pf = BonusRollFrame.PromptFrame

    cachedDisplayItemID = nil
    cachedItemLink = nil
    local ejBtn = pf.EncounterJournalLinkButton
    if ejBtn and ejBtn.displayItemID then
        cachedDisplayItemID = ejBtn.displayItemID
        cachedItemLink = select(2, GetItemInfo(ejBtn.displayItemID))
    end

    local iName, _, iQuality, _, _, _, _, _, _, iTexture = GetItemInfo(cachedDisplayItemID or 0)
    -- If GetItemInfo hasn't cached the item yet (common for delve voidcaches), fall back to
    -- the texture Blizzard already placed on the EncounterJournalLinkButton's NormalTexture.
    if not iTexture and ejBtn then
        local t = ejBtn:GetNormalTexture()
        iTexture = t and t:GetTexture()
    end
    if iTexture then
        winItemIcon:SetTexture(iTexture)
        winItemIcon:Show()
    else
        winItemIcon:Hide()
    end
    if iName then
        local _, _, _, hex = GetItemQualityColor(iQuality or 1)
        winItemName:SetText("|c" .. hex .. iName .. "|r")
    elseif pf.Name and pf.Name:GetText() and pf.Name:GetText() ~= "" then
        winItemName:SetText("|cffffffff" .. pf.Name:GetText() .. "|r")
    else
        winItemName:SetText("|cff888888Nebulous Voidcore Roll|r")
    end

    local specID = VCA.SpecInfo.GetEffectiveLootSpecID()
    local _, sName, _, sIcon = GetSpecializationInfoByID(specID)
    specIcon:SetTexture(sIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    specName:SetText("|cffdddddd" .. (sName or "?") .. "|r")

    rollBtn:SetText(ROLL_BTN_TEXT)
    passBtn:SetText(PASS_BTN_TEXT)

    -- Dynamic loot odds section

    local source = GetSourceFromDisplayItemID(cachedDisplayItemID)
    if source then
        if source.sourceType == VCA.ContentType.MYTHIC_PLUS then
            source.difficultyID = VCA.MythicPlusEJDifficulty
        else
            local _, _, diffID = GetInstanceInfo()
            source.difficultyID = (VCA.EligibleRaidDifficulties[diffID] and diffID) or VCA.Difficulty.RAID_NORMAL
        end
    end

    -- Voidcore count + cost
    local currInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(VCA.VOIDCORE_CURRENCY_ID)
    local owned = currInfo and currInfo.quantity or 0
    local cost = (source and source.sourceType == VCA.ContentType.RAID) and VCA.VoidcoreCost.RAID or
                     VCA.VoidcoreCost.MYTHIC_PLUS
    winVoidcoreInfo:SetText(string.format(L["BONUS_ROLL_CONFIRM_COST"], cost, owned))

    local dynY = LayoutDynamicSection(source, specID, -124)
    local btnW, btnH = 140, 28
    local winH = math.abs(dynY) + 8 + btnH + 16
    win:SetSize(360, winH)

    rollBtn:SetSize(btnW, btnH)
    passBtn:SetSize(btnW, btnH)
    rollBtn:ClearAllPoints()
    passBtn:ClearAllPoints()
    rollBtn:SetPoint("BOTTOM", win, "BOTTOM", -(btnW / 2 + 4), 12)
    passBtn:SetPoint("BOTTOM", win, "BOTTOM", (btnW / 2 + 4), 12)

    win:ClearAllPoints()
    win:SetPoint("TOP", BonusRollFrame, "BOTTOM", 0, WIN_GAP_Y)
    BonusRollFrame:SetAlpha(0)
    isPreview = false
    win:Show()
end

-- â”€â”€ BRC.Hide / Uninject â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function BRC.Uninject()
    if BonusRollFrame then
        BonusRollFrame:SetAlpha(1)
    end
    win:Hide()
    StaticPopup_Hide("VOIDCORE_BONUS_ROLL")
    cachedItemLink = nil
    cachedDisplayItemID = nil
end

-- ── Confirmation popups ──────────────────────────────────────────────────────────────────

StaticPopupDialogs["VOIDCORE_BONUS_ROLL"] = {
    text = "%s",
    button1 = L["BONUS_ROLL_CONFIRM_ROLL"],
    button2 = CANCEL,
    OnAccept = function()
        BRC.Hide()
        if not isPreview and BonusRollFrame and BonusRollFrame.PromptFrame and BonusRollFrame.PromptFrame.RollButton then
            BonusRollFrame.PromptFrame.RollButton:Click()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

BRC.Hide = BRC.Uninject

function BRC.ShowPreview()
    isPreview = true
    -- Algeth'ar Academy cache item as a live-data stand-in
    cachedDisplayItemID = 268465
    cachedItemLink = nil

    local iName, _, iQuality, _, _, _, _, _, _, iTexture = GetItemInfo(cachedDisplayItemID)
    if iTexture then
        winItemIcon:SetTexture(iTexture)
        winItemIcon:Show()
    else
        winItemIcon:Hide()
    end
    local iHex = iQuality and select(4, GetItemQualityColor(iQuality)) or "ffa335ee"
    winItemName:SetText("|c" .. iHex .. (iName or "Nebulous Voidcore Roll") .. "|r")

    local specID = VCA.SpecInfo.GetEffectiveLootSpecID()
    local _, sName, _, sIcon = GetSpecializationInfoByID(specID)
    specIcon:SetTexture(sIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    specName:SetText("|cffdddddd" .. (sName or "?") .. "|r")

    rollBtn:SetText(ROLL_BTN_TEXT)
    passBtn:SetText(PASS_BTN_TEXT)

    local currInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(VCA.VOIDCORE_CURRENCY_ID)
    local owned = currInfo and currInfo.quantity or 0
    winVoidcoreInfo:SetText(string.format(L["BONUS_ROLL_CONFIRM_COST"], VCA.VoidcoreCost.MYTHIC_PLUS, owned))

    local source = GetSourceFromDisplayItemID(cachedDisplayItemID)
    if source then
        source.difficultyID = VCA.MythicPlusEJDifficulty
    end

    local dynY = LayoutDynamicSection(source, specID, -124)
    local btnW, btnH = 140, 28
    local winH = math.abs(dynY) + 8 + btnH + 16
    win:SetSize(360, winH)

    rollBtn:SetSize(btnW, btnH)
    passBtn:SetSize(btnW, btnH)
    rollBtn:ClearAllPoints()
    passBtn:ClearAllPoints()
    rollBtn:SetPoint("BOTTOM", win, "BOTTOM", -(btnW / 2 + 4), 12)
    passBtn:SetPoint("BOTTOM", win, "BOTTOM", (btnW / 2 + 4), 12)

    win:ClearAllPoints()
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    win:Show()
end

-- â”€â”€ One-time hooks â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

local hooksDone = false
local function SetupHooks()
    if hooksDone or not BonusRollFrame then
        return
    end
    BonusRollFrame:HookScript("OnShow", function()
        if IsEnabled() then
            BRC.Show()
        end
    end)
    BonusRollFrame:HookScript("OnHide", BRC.Uninject)
    hooksDone = true
end

-- â”€â”€ Events â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("BONUS_ROLL_STARTED")
eventFrame:RegisterEvent("BONUS_ROLL_ACTIVATE")
eventFrame:RegisterEvent("BONUS_ROLL_RESULT")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        SetupHooks()
    elseif event == "ADDON_LOADED" then
        if (...) == "Blizzard_UIPanels_Game" then
            SetupHooks()
        end
    elseif event == "BONUS_ROLL_STARTED" then
        if IsEnabled() then
            SetupHooks()
            BRC.Show()
        end
    elseif event == "BONUS_ROLL_ACTIVATE" or event == "BONUS_ROLL_RESULT" then
        BRC.Uninject()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- If our window is open and the icon is still hidden, try again now the
        -- item data has arrived from the server.
        local itemID = ...
        if win:IsShown() and itemID == cachedDisplayItemID and not winItemIcon:IsShown() then
            local _, _, iQuality, _, _, _, _, _, _, iTexture = GetItemInfo(itemID)
            if iTexture then
                winItemIcon:SetTexture(iTexture)
                winItemIcon:Show()
                if not iQuality then
                    return
                end
                local _, _, _, hex = GetItemQualityColor(iQuality)
                if hex then
                    local iName = GetItemInfo(itemID)
                    if iName then
                        winItemName:SetText("|c" .. hex .. iName .. "|r")
                    end
                end
            end
        end
    end
end)
