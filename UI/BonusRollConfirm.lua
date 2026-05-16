-- VoidcoreAdvisor: BonusRollConfirm
-- Replaces BonusRollFrame with a custom VCA window positioned at the same
-- screen location (+small offset so the original is still visible behind it).
--
-- Frame level 7 + EnableMouse(true) prevents accidental clicks on the original
-- Roll/Pass buttons (which sit at level 5-6).
--
-- Roll button requires TWO clicks (confirm) â€” this is intentional and critical.
-- Pass button also requires two clicks.
local addonName, VCA = ...
local L = VCA.L

VCA.BonusRollConfirm = {}
local BRC = VCA.BonusRollConfirm

local isActive = false
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

-- Title (large, centred)
local winTitle = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
winTitle:SetPoint("TOP", win, "TOP", 0, -14)
winTitle:SetText("|cffb048f8VoidcoreAdvisor|r")

-- Subtitle
local winSubtitle = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
winSubtitle:SetPoint("TOP", winTitle, "BOTTOM", 0, -2)
winSubtitle:SetText("|cff888888" .. L["BONUS_ROLL_CONFIRM_SUBTITLE"] .. "|r")

-- Voidcore count + cost line
local winVoidcoreInfo = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
winVoidcoreInfo:SetPoint("TOP", winSubtitle, "BOTTOM", 0, -2)

-- Header divider
local winHeaderDiv = win:CreateTexture(nil, "ARTWORK")
winHeaderDiv:SetColorTexture(0.58, 0.0, 0.82, 0.4)
winHeaderDiv:SetHeight(1)
winHeaderDiv:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -62)
winHeaderDiv:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, -62)

-- Item icon
local winItemIcon = win:CreateTexture(nil, "ARTWORK")
winItemIcon:SetSize(40, 40)
winItemIcon:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -74)
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

-- Timer bar  (value mirrored from BonusRollFrame.PromptFrame.Timer.Bar via OnUpdate)
local timerBar = CreateFrame("StatusBar", nil, win)
timerBar:SetHeight(8)
timerBar:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -122)
timerBar:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, -122)
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
topSep:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -138)
topSep:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, -138)

-- Spec icon + name
local specIcon = win:CreateTexture(nil, "ARTWORK")
specIcon:SetSize(22, 22)
specIcon:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -148)
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
lootLine:SetJustifyH("LEFT")
lootLine:Hide()

local warnText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
warnText:SetWidth(320)
warnText:SetJustifyH("LEFT")
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
rollBtn:SetText(L["BONUS_ROLL_CONFIRM_ROLL"])
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
passBtn:SetText(L["BONUS_ROLL_CONFIRM_PASS"])
passBtn:SetScript("OnClick", function()
    StaticPopup_Show("VOIDCORE_BONUS_PASS", L["BONUS_ROLL_POPUP_PASS"])
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
    if source and source.sourceType and source.sourceID then
        local prob = VCA.Probability.CalculateForSpec(source.sourceType, source.sourceID, source.difficultyID,
            VCA.SpecInfo.GetPlayerClassID(), specID, nil)

        lootSep:ClearAllPoints()
        lootSep:SetPoint("TOPLEFT", win, "TOPLEFT", 16, dynY)
        lootSep:SetPoint("TOPRIGHT", win, "TOPRIGHT", -16, dynY)
        lootSep:Show()
        dynY = dynY - 10

        lootLine:ClearAllPoints()
        lootLine:SetPoint("TOPLEFT", win, "TOPLEFT", 16, dynY)
        if prob.noItems then
            lootLine:SetText("|cff888888" .. L["BONUS_ROLL_CONFIRM_NO_ITEMS"] .. "|r")
        elseif prob.allObtained then
            lootLine:SetText("|cff00ff00" .. L["BONUS_ROLL_CONFIRM_ALL_OBTAINED"] .. "|r")
        else
            local pct = math.floor((prob.remainingOdds or 0) * 100 + 0.5)
            lootLine:SetText(string.format(L["BONUS_ROLL_CONFIRM_POOL"], prob.remainingCount) ..
                                 "  |cff888888\226\128\162|r  " .. "|cffffff00" ..
                                 string.format(L["BONUS_ROLL_CONFIRM_CHANCE"], pct) .. "|r")
        end
        lootLine:Show()
        dynY = dynY - 22

        if prob.remainingCount == 1 then
            warnText:ClearAllPoints()
            warnText:SetPoint("TOPLEFT", win, "TOPLEFT", 16, dynY)
            warnText:SetText(L["BONUS_ROLL_CONFIRM_WARNING"])
            warnText:Show()
            dynY = dynY - 44
        else
            warnText:Hide()
        end
    else
        lootSep:Hide()
        lootLine:Hide()
        warnText:Hide()
    end

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
                local remaining = 0
                local total = #(items or {})
                for _, itemID in ipairs(items or {}) do
                    if not VCA.Data.IsObtained(source.sourceType, source.sourceID, source.difficultyID, spec.specID,
                        itemID) then
                        remaining = remaining + 1
                    end
                end
                local row = specListRows[rowsUsed + 1]
                row.icon:ClearAllPoints()
                row.icon:SetPoint("TOPLEFT", win, "TOPLEFT", 24, dynY)
                row.icon:SetTexture(spec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.icon:Show()
                local remainStr
                if total == 0 then
                    remainStr = "|cff888888" .. L["REMINDER_SPEC_NONE"] .. "|r"
                elseif remaining == 0 then
                    remainStr = "|cff00ff00" .. L["ALL_OBTAINED"] .. "|r"
                else
                    remainStr = "|cffdddddd" .. string.format(L["REMINDER_SPEC_REMAINING"], remaining) .. "|r"
                end
                local warnPrefix = (remaining == 1) and (CreateAtlasMarkup("Ping_Wheel_Icon_Warning", 14, 14) .. " ") or
                                       ""
                row.label:ClearAllPoints()
                row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
                row.label:SetText(warnPrefix .. "|cffa0a0a0" .. (spec.name or "?") .. "|r: " .. remainStr)
                row.label:Show()
                dynY = dynY - 22
                rowsUsed = rowsUsed + 1
            end
            for i = rowsUsed + 1, 4 do
                specListRows[i].icon:Hide()
                specListRows[i].label:Hide()
            end
            dynY = dynY - 4
        else
            HideSpecList()
        end
    else
        HideSpecList()
    end

    dynY = dynY - 6
    winRollPrompt:ClearAllPoints()
    winRollPrompt:SetPoint("TOP", win, "TOP", 0, dynY)
    winRollPrompt:Show()
    dynY = dynY - 22

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

    rollBtn:SetText(L["BONUS_ROLL_CONFIRM_ROLL"])
    passBtn:SetText(L["BONUS_ROLL_CONFIRM_PASS"])

    -- Dynamic loot odds section
    -- dynY cursor: top of spec row = -108, row height = 22, gap = 8  â†’  -138
    -- Source from Voidcache item ID (displayItemID on EJLinkButton)
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

    local dynY = LayoutDynamicSection(source, specID, -178)
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
    isActive = true
    win:Show()
end

-- â”€â”€ BRC.Hide / Uninject â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function BRC.Uninject()
    if BonusRollFrame then
        BonusRollFrame:SetAlpha(1)
    end
    win:Hide()
    StaticPopup_Hide("VOIDCORE_BONUS_ROLL")
    StaticPopup_Hide("VOIDCORE_BONUS_PASS")
    isActive = false
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
        if BonusRollFrame and BonusRollFrame.PromptFrame and BonusRollFrame.PromptFrame.RollButton then
            BonusRollFrame.PromptFrame.RollButton:Click()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

StaticPopupDialogs["VOIDCORE_BONUS_PASS"] = {
    text = "%s",
    button1 = L["BONUS_ROLL_CONFIRM_PASS"],
    button2 = CANCEL,
    OnAccept = function()
        BRC.Hide()
        if BonusRollFrame and BonusRollFrame.PromptFrame and BonusRollFrame.PromptFrame.PassButton then
            BonusRollFrame.PromptFrame.PassButton:Click()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}

BRC.Hide = BRC.Uninject

function BRC.ShowPreview()
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

    rollBtn:SetText(L["BONUS_ROLL_CONFIRM_ROLL"])
    passBtn:SetText(L["BONUS_ROLL_CONFIRM_PASS"])

    local currInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(VCA.VOIDCORE_CURRENCY_ID)
    local owned = currInfo and currInfo.quantity or 0
    winVoidcoreInfo:SetText(string.format(L["BONUS_ROLL_CONFIRM_COST"], VCA.VoidcoreCost.MYTHIC_PLUS, owned))

    local source = GetSourceFromDisplayItemID(cachedDisplayItemID)
    if source then
        source.difficultyID = VCA.MythicPlusEJDifficulty
    end

    local dynY = LayoutDynamicSection(source, specID, -178)
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
    end
end)
