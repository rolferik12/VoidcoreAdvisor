-- VoidcoreAdvisor: Panel
-- The side panel frame.  Anchors to the right edge of EncounterJournal and
-- shows context for the currently-viewed boss or dungeon.
--
-- Layout:
--   ┌────────────────────────────────────────────────────┐
--   │  VoidcoreAdvisor                               [X] │  header
--   │  <source name>                                     │
--   │  Raid Boss  •  2 Nebulous Voidcores                │
--   ├─────────────────────┬──────────────────────────────┤  divider
--   │ LOOT                │ SPEC RANKING                 │  column headers
--   │ ┌──┐ [Item name]  □ │ #1 [icon] SpecName  3/8 37% │
--   │ ┌──┐ [Item name]  □ │ #2 [icon] SpecName  5/8 37% │  rows
--   │ ...                 │ ...                          │
--   └─────────────────────┴──────────────────────────────┘

local _, VCA = ...
local L = VCA.L

VCA.Panel = {}
local Panel = VCA.Panel

-- ── Selection state ──────────────────────────────────────────────────────────
-- Tracks which itemIDs the user has clicked to highlight.
-- Ctrl+click toggles an item; plain click is single-select.
local selectedItemIDs = {}  -- set: { [itemID] = true }
-- Tracks which specIDs the user has clicked to filter the loot column.
local selectedSpecIDs = {}  -- set: { [specID] = true }
local RefreshSpecColumn     -- forward declaration; defined after PopulateSpecColumn
local RefreshItemColumn     -- forward declaration; defined after PopulateItemColumn
local SaveItemSelections     -- forward declaration; defined after Panel.SetContext

-- ── Sizing ────────────────────────────────────────────────────────────────────

local PANEL_WIDTH   = 600
local HEADER_H      = 76    -- title + source label + info label + divider
local COL_HEADER_H  = 20    -- "LOOT" / "SPEC RANKING" label row
local PADDING       = 12    -- inner horizontal padding
local ROW_H         = 26    -- height of one item / spec row
local ICON_SIZE     = 20    -- inline icon size in rows
local COL_SPLIT     = 0.52  -- left column fraction of content width

-- ── Main frame ────────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame", "VoidcoreAdvisorPanel", UIParent, "BackdropTemplate")
Panel.frame = frame

frame:SetWidth(PANEL_WIDTH)
frame:SetFrameStrata("HIGH")
frame:SetClampedToScreen(true)
frame:Hide()

frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true,
    tileSize = 32,
    edgeSize = 32,
    insets   = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:SetBackdropColor(0.05, 0.02, 0.12, 0.95)    -- dark void-purple
frame:SetBackdropBorderColor(0.58, 0.0, 0.82, 1)  -- purple glow border

-- ── Anchor helper ─────────────────────────────────────────────────────────────

-- Positions the panel flush against the right edge of EncounterJournal.
-- Safe to call multiple times (ClearAllPoints before re-anchoring).
function Panel.AnchorToEJ()
    local ej = EncounterJournal
    if not ej then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",    ej, "TOPRIGHT",    52, 0)
    frame:SetPoint("BOTTOMLEFT", ej, "BOTTOMRIGHT", 52, 0)
end

-- ── Header widgets ────────────────────────────────────────────────────────────

-- Title
local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOPLEFT", 18, -16)
titleText:SetText(L["PANEL_TITLE"])

-- X close button (uses the standard Blizzard close button template)
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function() frame:Hide() end)

-- Persist item selections when the panel hides (close, navigate away, logout).
frame:SetScript("OnHide", function()
    SaveItemSelections()
end)

-- Source name (boss or dungeon)
local sourceLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
sourceLabel:SetPoint("TOPLEFT",  18,  -42)
sourceLabel:SetPoint("TOPRIGHT", -40, -42)
sourceLabel:SetJustifyH("LEFT")
sourceLabel:SetWordWrap(false)
sourceLabel:SetText("")
Panel.sourceLabel = sourceLabel

-- Content type + Voidcore cost
local infoLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
infoLabel:SetPoint("TOPLEFT", 18, -60)
infoLabel:SetJustifyH("LEFT")
infoLabel:SetText("")
Panel.infoLabel = infoLabel

-- Horizontal divider
local divider = frame:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(0.58, 0.0, 0.82, 0.4)
divider:SetPoint("TOPLEFT",  frame, "TOPLEFT",  16, -HEADER_H)
divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -HEADER_H)
divider:SetHeight(1)

-- ── Content area ─────────────────────────────────────────────────────────────
-- Two side-by-side columns below the divider.

local contentArea = CreateFrame("Frame", nil, frame)
contentArea:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0, -(HEADER_H + 1))
contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 11)
Panel.contentArea = contentArea

-- ── Column widths ─────────────────────────────────────────────────────────────

-- Recomputed each Refresh so dynamic resizing (future) is easy.
local function ContentWidth()
    return frame:GetWidth() - PADDING * 2
end

local function LeftColWidth()
    return math.floor(ContentWidth() * COL_SPLIT)
end

local function RightColWidth()
    return ContentWidth() - LeftColWidth() - 1  -- 1px for the vertical separator
end

-- ── Column header labels ──────────────────────────────────────────────────────

local lootColHeader = contentArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lootColHeader:SetPoint("TOPLEFT", contentArea, "TOPLEFT", PADDING, -6)
lootColHeader:SetJustifyH("LEFT")
lootColHeader:SetText("|cffb048f8LOOT|r")

-- X button to clear all spec selections (near the center divider in loot column header)
local clearSpecBtn = CreateFrame("Button", nil, contentArea)
clearSpecBtn:SetSize(14, 14)
clearSpecBtn:SetNormalFontObject("GameFontNormal")
clearSpecBtn:SetText("|cffff4444x|r")
clearSpecBtn:SetScript("OnClick", function()
    wipe(selectedSpecIDs)
    RefreshItemColumn()
end)
clearSpecBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["CLEAR_SELECTED"])
    GameTooltip:Show()
end)
clearSpecBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
clearSpecBtn:Hide()

-- ── Key level dropdown (M+ only) ─────────────────────────────────────────────
local selectedKeyLevel = 10  -- default to 10+

local keyLevelButton = CreateFrame("Button", nil, contentArea)
keyLevelButton:SetSize(50, 16)
keyLevelButton:SetPoint("LEFT", lootColHeader, "RIGHT", 6, 0)
keyLevelButton:Hide()

local keyLevelText = keyLevelButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
keyLevelText:SetAllPoints(keyLevelButton)
keyLevelText:SetJustifyH("LEFT")

local function GetKeyLevelLabel(level)
    return "+" .. level
end

local function GetRewardForKeyLevel(level)
    return VCA.MythicPlusVaultRewards[math.min(level, 10)]
end

local function UpdateKeyLevelText()
    local reward = GetRewardForKeyLevel(selectedKeyLevel)
    local track = reward and reward.track or "?"
    keyLevelText:SetText("|cffdddddd" .. GetKeyLevelLabel(selectedKeyLevel) .. "|r |cff888888(" .. track .. ")|r")
    -- Resize button to fit text
    keyLevelButton:SetWidth(keyLevelText:GetStringWidth() + 8)
end

local keyLevelMenu = CreateFrame("Frame", "VCAKeyLevelMenu", keyLevelButton, "BackdropTemplate")
keyLevelMenu:SetFrameStrata("TOOLTIP")
keyLevelMenu:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
keyLevelMenu:SetBackdropColor(0.05, 0.02, 0.12, 0.95)
keyLevelMenu:SetBackdropBorderColor(0.58, 0.0, 0.82, 1)
keyLevelMenu:Hide()

local keyLevelOptions = { 2, 3, 4, 5, 6, 7, 8, 9, 10 }
local menuButtons = {}
for i, level in ipairs(keyLevelOptions) do
    local btn = CreateFrame("Button", nil, keyLevelMenu)
    btn:SetSize(70, 16)
    btn:SetPoint("TOPLEFT", keyLevelMenu, "TOPLEFT", 4, -(4 + (i - 1) * 16))
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetAllPoints(btn)
    label:SetJustifyH("LEFT")
    btn.label = label
    btn.level = level

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(btn)
    highlight:SetColorTexture(0.58, 0.0, 0.82, 0.3)

    btn:SetScript("OnClick", function(self)
        selectedKeyLevel = self.level
        UpdateKeyLevelText()
        keyLevelMenu:Hide()
        Panel.Refresh()
    end)
    menuButtons[i] = btn
end
keyLevelMenu:SetSize(78, 8 + #keyLevelOptions * 16)

local function ShowKeyLevelMenu()
    for i, btn in ipairs(menuButtons) do
        local level = btn.level
        local reward = GetRewardForKeyLevel(level)
        local track = reward and reward.track or "?"
        local lbl = GetKeyLevelLabel(level) .. "  |cff888888" .. track .. "|r"
        if level == selectedKeyLevel then
            lbl = "|cffffff00" .. lbl .. "|r"
        end
        btn.label:SetText(lbl)
    end
    keyLevelMenu:ClearAllPoints()
    keyLevelMenu:SetPoint("TOPLEFT", keyLevelButton, "BOTTOMLEFT", 0, -2)
    keyLevelMenu:Show()
end

keyLevelButton:SetScript("OnClick", function()
    if keyLevelMenu:IsShown() then
        keyLevelMenu:Hide()
    else
        ShowKeyLevelMenu()
    end
end)

-- Close menu when clicking elsewhere
keyLevelMenu:SetScript("OnShow", function(self)
    self:SetPropagateKeyboardInput(true)
end)
keyLevelMenu:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        self:Hide()
        self:SetPropagateKeyboardInput(false)
    else
        self:SetPropagateKeyboardInput(true)
    end
end)

local specColHeader = contentArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
specColHeader:SetJustifyH("LEFT")
specColHeader:SetText("|cffb048f8" .. L["COL_SPEC_RANKING"] .. "|r")

-- X button to clear all item selections (near the center divider in spec column header)
local clearItemBtn = CreateFrame("Button", nil, contentArea)
clearItemBtn:SetSize(14, 14)
clearItemBtn:SetNormalFontObject("GameFontNormal")
clearItemBtn:SetText("|cffff4444x|r")
clearItemBtn:SetScript("OnClick", function()
    wipe(selectedItemIDs)
    SaveItemSelections()
    RefreshSpecColumn()
    RefreshItemColumn()
end)
clearItemBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["CLEAR_SELECTED"])
    GameTooltip:Show()
end)
clearItemBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
clearItemBtn:Hide()

local lootSpecLabel = contentArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lootSpecLabel:SetJustifyH("RIGHT")
lootSpecLabel:SetText("")

-- Vertical separator between columns
local colSep = contentArea:CreateTexture(nil, "ARTWORK")
colSep:SetColorTexture(0.58, 0.0, 0.82, 0.3)
colSep:SetWidth(1)

-- Horizontal rule below column headers
local colHeaderRule = contentArea:CreateTexture(nil, "ARTWORK")
colHeaderRule:SetColorTexture(0.4, 0.4, 0.4, 0.3)
colHeaderRule:SetPoint("TOPLEFT",  contentArea, "TOPLEFT",  PADDING, -(COL_HEADER_H + 2))
colHeaderRule:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -PADDING, -(COL_HEADER_H + 2))
colHeaderRule:SetHeight(1)

-- ── Item quality color escape sequence ───────────────────────────────────────
-- Uses |cnIQn: syntax (added in 11.1.5).

local function QualityColor(quality)
    return "|cnIQ" .. (quality or 1) .. ":"
end

-- ── Tooltip: M+ bonus ID injection ──────────────────────────────────────────
-- Builds a modified item hyperlink string with bonus IDs matching the
-- selected key level so the tooltip renders at the correct item level.

local function BuildMythicPlusTooltipLink(itemLink)
    local reward = GetRewardForKeyLevel(selectedKeyLevel)
    if not reward then return nil end

    local itemString = itemLink:match("item[%-?%d:]+")
    if not itemString then return nil end

    local fields = {}
    for field in (itemString .. ":"):gmatch("([^:]*):" ) do
        fields[#fields + 1] = field
    end
    -- Ensure at least 14 fields (up to numBonusIDs position)
    while #fields < 14 do
        fields[#fields + 1] = ""
    end
    -- Field 13 = context (35 = M+ context)
    fields[13] = "35"

    local numBonuses = tonumber(fields[14]) or 0
    -- Collect existing bonus IDs, stripping 3524 if present
    local newBonuses = {}
    for bi = 15, 14 + numBonuses do
        if fields[bi] ~= "3524" then
            newBonuses[#newBonuses + 1] = fields[bi]
        end
    end

    -- Append the M+ base bonus IDs and the key-level-specific track bonus
    for _, b in ipairs(VCA.MythicPlusBonusIDs) do
        newBonuses[#newBonuses + 1] = tostring(b)
    end
    newBonuses[#newBonuses + 1] = tostring(reward.bonusID)

    -- Remove old bonus entries from fields, insert new ones
    for _ = 1, numBonuses do
        table.remove(fields, 15)
    end
    fields[14] = tostring(#newBonuses)
    for i, b in ipairs(newBonuses) do
        table.insert(fields, 14 + i, b)
    end

    return table.concat(fields, ":")
end

-- ── Row pool helpers ──────────────────────────────────────────────────────────
-- We maintain two pools of recycled row frames so we never create more widgets
-- than necessary.

local itemRows  = {}   -- { frame, icon, nameLabel, checkbox }
local specRows  = {}   -- { frame, icon, nameLabel, statsLabel }

local function GetOrCreateItemRow(pool, parent)
    for _, row in ipairs(pool) do
        if not row.frame:IsShown() then
            return row
        end
    end
    -- Create a new row.  Use Button so WoW always delivers mouse events even
    -- when nested inside a ScrollFrame, where plain Frame hit-testing can be
    -- unreliable.
    local rowFrame = CreateFrame("Button", nil, parent)
    rowFrame:SetHeight(ROW_H)
    rowFrame:RegisterForClicks("LeftButtonUp")

    -- Flash texture (used for detection highlight)
    local flash = rowFrame:CreateTexture(nil, "HIGHLIGHT")
    flash:SetAllPoints(rowFrame)
    flash:SetColorTexture(0, 1, 0, 0)

    -- Selection highlight (golden tint when the user clicks the row)
    local selHighlight = rowFrame:CreateTexture(nil, "BACKGROUND")
    selHighlight:SetAllPoints(rowFrame)
    selHighlight:SetColorTexture(1, 0.75, 0, 0)
    selHighlight:Hide()

    -- Icon housed in its own Button so the tooltip fires only on icon hover.
    local iconButton = CreateFrame("Button", nil, rowFrame)
    iconButton:SetSize(ICON_SIZE, ICON_SIZE)
    iconButton:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)

    local icon = iconButton:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(iconButton)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- trim default icon border

    local iconBorder = iconButton:CreateTexture(nil, "OVERLAY")
    iconBorder:SetTexture("Interface/Common/WhiteIconFrame")
    iconBorder:SetAllPoints(iconButton)
    iconBorder:Hide()

    local nameLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetPoint("LEFT",  iconButton, "RIGHT", 4, 0)
    nameLabel:SetPoint("RIGHT", rowFrame, "RIGHT", -20, 0)
    nameLabel:SetWordWrap(false)

    local checkbox = CreateFrame("CheckButton", nil, rowFrame, "UICheckButtonTemplate")
    checkbox:SetSize(16, 16)
    checkbox:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)

    -- Tooltip on icon hover only
    iconButton:SetScript("OnEnter", function(self)
        local rf   = self:GetParent()
        local link = rf.itemLink
        local id   = rf.itemID
        if not (link or id) then return end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        -- For M+ dungeons, inject Myth 1/6 bonus IDs so the tooltip shows
        -- the correct Voidcore reward item level.
        if Panel.sourceType == VCA.ContentType.MYTHIC_PLUS
           and link and link ~= ""
           and rf.itemSlot ~= ""
        then
            local modified = BuildMythicPlusTooltipLink(link)
            if modified then
                local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, modified)
                if ok and GameTooltip:NumLines() and GameTooltip:NumLines() > 0 then
                    GameTooltip:Show()
                    return
                end
                GameTooltip:ClearLines()
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            end
        end

        -- Default path: raids use the link as-is (already at the EJ difficulty).
        if link and link ~= "" then
            GameTooltip:SetHyperlink(link)
        elseif id then
            GameTooltip:SetItemByID(id)
        end
        GameTooltip:Show()
    end)
    iconButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local row = {
        frame        = rowFrame,
        flash        = flash,
        selHighlight = selHighlight,
        iconButton   = iconButton,
        icon         = icon,
        iconBorder   = iconBorder,
        nameLabel    = nameLabel,
        checkbox     = checkbox,
    }

    -- Wire the selection click once at creation time so it is never lost when
    -- rows are recycled from the pool.
    rowFrame:SetScript("OnClick", function(self, btn)
        local id = self.itemID
        if not id then return end
        if self.dimmed then return end
        -- Toggle: click selects, click again deselects.
        if selectedItemIDs[id] then
            selectedItemIDs[id] = nil
        else
            selectedItemIDs[id] = true
        end
        -- Refresh highlight visuals on all visible rows immediately.
        for _, r in ipairs(pool) do
            if r.frame:IsShown() and r.frame.itemID then
                if selectedItemIDs[r.frame.itemID] then
                    r.selHighlight:SetColorTexture(1, 0.75, 0, 0.18)
                    r.selHighlight:Show()
                else
                    r.selHighlight:Hide()
                end
            end
        end
        RefreshSpecColumn()
        RefreshItemColumn()
        SaveItemSelections()
    end)

    pool[#pool + 1] = row
    return row
end

local function GetOrCreateSpecRow(pool, parent)
    for _, row in ipairs(pool) do
        if not row.frame:IsShown() then
            return row
        end
    end
    local rowFrame = CreateFrame("Button", nil, parent)
    rowFrame:SetHeight(ROW_H)
    rowFrame:RegisterForClicks("LeftButtonUp")

    -- Selection highlight (purple tint when spec is selected)
    local selHighlight = rowFrame:CreateTexture(nil, "BACKGROUND")
    selHighlight:SetAllPoints(rowFrame)
    selHighlight:SetColorTexture(0.69, 0.28, 0.97, 0)
    selHighlight:Hide()

    local rankLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rankLabel:SetJustifyH("RIGHT")
    rankLabel:SetWidth(24)
    rankLabel:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)

    local icon = rowFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", rankLabel, "RIGHT", 3, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local nameLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetPoint("LEFT",  icon, "RIGHT", 4, 0)
    nameLabel:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
    nameLabel:SetWordWrap(false)

    local statsLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsLabel:SetJustifyH("RIGHT")
    statsLabel:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)

    -- Spec selection click
    rowFrame:SetScript("OnClick", function(self, btn)
        local specID = self.specID
        if not specID then return end
        -- Toggle: click selects, click again deselects.
        if selectedSpecIDs[specID] then
            selectedSpecIDs[specID] = nil
        else
            selectedSpecIDs[specID] = true
        end
        -- Update spec highlight visuals
        for _, r in ipairs(pool) do
            if r.frame:IsShown() and r.frame.specID then
                if selectedSpecIDs[r.frame.specID] then
                    r.selHighlight:SetColorTexture(0.69, 0.28, 0.97, 0.18)
                    r.selHighlight:Show()
                else
                    r.selHighlight:Hide()
                end
            end
        end
        RefreshItemColumn()
    end)

    local row = {
        frame        = rowFrame,
        selHighlight = selHighlight,
        rankLabel    = rankLabel,
        icon         = icon,
        nameLabel    = nameLabel,
        statsLabel   = statsLabel,
    }
    pool[#pool + 1] = row
    return row
end

-- ── Row hide helpers ──────────────────────────────────────────────────────────

local function HideAllItemRows()
    for _, row in ipairs(itemRows) do row.frame:Hide() end
end

local function HideAllSpecRows()
    for _, row in ipairs(specRows) do row.frame:Hide() end
end

-- ── Slot sort order ───────────────────────────────────────────────────────────
-- Maps INVTYPE_* equip-location strings to a numeric sort priority so the item
-- list reads like the character sheet: head first, trinkets last.
-- Finger/Ring and all weapon sub-types are collapsed into single categories.

local SLOT_SORT_ORDER = {
    INVTYPE_HEAD            = 1,
    INVTYPE_NECK            = 2,
    INVTYPE_SHOULDER        = 3,
    INVTYPE_CLOAK           = 4,
    INVTYPE_CHEST           = 5,
    INVTYPE_ROBE            = 5,
    INVTYPE_WRIST           = 6,
    INVTYPE_HAND            = 7,
    INVTYPE_WAIST           = 8,
    INVTYPE_LEGS            = 9,
    INVTYPE_FEET            = 10,
    INVTYPE_FINGER          = 11,
    -- All weapon / off-hand types grouped together
    INVTYPE_WEAPON          = 12,
    INVTYPE_2HWEAPON        = 12,
    INVTYPE_WEAPONMAINHAND  = 12,
    INVTYPE_WEAPONOFFHAND   = 12,
    INVTYPE_HOLDABLE        = 12,
    INVTYPE_SHIELD          = 12,
    INVTYPE_RANGED          = 12,
    INVTYPE_RANGEDRIGHT     = 12,
    -- Trinkets last
    INVTYPE_TRINKET         = 13,
}

local function GetSlotSortOrder(itemID)
    if not itemID then return 99 end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
    if not equipLoc or equipLoc == "" then return 99 end
    return SLOT_SORT_ORDER[equipLoc] or 99
end

-- ── Populate item column ──────────────────────────────────────────────────────

local itemScrollChild = CreateFrame("Frame", nil, contentArea)
local itemScrollFrame = CreateFrame("ScrollFrame", nil, contentArea)
itemScrollFrame:SetScrollChild(itemScrollChild)

-- Mouse wheel scrolling
itemScrollFrame:EnableMouseWheel(true)
itemScrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local current = self:GetVerticalScroll()
    local maxScroll = math.max(0, itemScrollChild:GetHeight() - self:GetHeight())
    local step = ROW_H * 3
    local newScroll = math.max(0, math.min(maxScroll, current - delta * step))
    self:SetVerticalScroll(newScroll)
end)

-- Thin scrollbar track + thumb
local scrollTrack = itemScrollFrame:CreateTexture(nil, "BACKGROUND")
scrollTrack:SetWidth(4)
scrollTrack:SetColorTexture(0.1, 0.1, 0.1, 0.4)
scrollTrack:SetPoint("TOPRIGHT", itemScrollFrame, "TOPRIGHT", 0, 0)
scrollTrack:SetPoint("BOTTOMRIGHT", itemScrollFrame, "BOTTOMRIGHT", 0, 0)
scrollTrack:Hide()

local scrollThumb = itemScrollFrame:CreateTexture(nil, "OVERLAY")
scrollThumb:SetWidth(4)
scrollThumb:SetColorTexture(0.6, 0.6, 0.6, 0.6)
scrollThumb:Hide()

local function UpdateScrollbar()
    local childH = itemScrollChild:GetHeight()
    local frameH = itemScrollFrame:GetHeight()
    if childH <= frameH or frameH <= 0 then
        scrollTrack:Hide()
        scrollThumb:Hide()
        return
    end
    scrollTrack:Show()
    scrollThumb:Show()
    local thumbRatio = frameH / childH
    local thumbH = math.max(20, frameH * thumbRatio)
    scrollThumb:SetHeight(thumbH)
    local scrollRange = childH - frameH
    local current = itemScrollFrame:GetVerticalScroll()
    local trackSpace = frameH - thumbH
    local offset = (current / scrollRange) * trackSpace
    scrollThumb:ClearAllPoints()
    scrollThumb:SetPoint("TOPRIGHT", itemScrollFrame, "TOPRIGHT", 0, -offset)
end

itemScrollFrame:HookScript("OnMouseWheel", function() UpdateScrollbar() end)

local function PopulateItemColumn(sourceType, sourceID, difficultyID)
    HideAllItemRows()

    local classID = VCA.SpecInfo.GetPlayerClassID()

    -- Build set of item IDs lootable by selected specs (if any).
    local specFilterSet  -- nil when no spec filter is active
    if next(selectedSpecIDs) then
        specFilterSet = {}
        for specID in pairs(selectedSpecIDs) do
            local specItemIDs = VCA.LootPool.GetItemsForSpec(
                sourceType, sourceID, difficultyID, classID, specID)
            for _, id in ipairs(specItemIDs) do
                specFilterSet[id] = true
            end
        end
    end

    -- When items are selected, find which specs can loot ALL of them,
    -- then build a lootable set from those specs to grey out the rest.
    local itemImpliedFilter  -- nil when no item selection filter is active
    if next(selectedItemIDs) then
        local specs = VCA.SpecInfo.GetPlayerSpecs()
        -- Find specs that can loot every selected item
        local qualifyingSpecs = {}
        for _, spec in ipairs(specs) do
            local specItemIDs = VCA.LootPool.GetItemsForSpec(
                sourceType, sourceID, difficultyID, classID, spec.specID)
            local idSet = {}
            for _, id in ipairs(specItemIDs) do
                idSet[id] = true
            end
            local coversAll = true
            for selID in pairs(selectedItemIDs) do
                if not idSet[selID] then
                    coversAll = false
                    break
                end
            end
            if coversAll then
                qualifyingSpecs[#qualifyingSpecs + 1] = spec.specID
            end
        end
        -- Build the union of items lootable by qualifying specs
        if #qualifyingSpecs > 0 then
            itemImpliedFilter = {}
            for _, specID in ipairs(qualifyingSpecs) do
                local specItemIDs = VCA.LootPool.GetItemsForSpec(
                    sourceType, sourceID, difficultyID, classID, specID)
                for _, id in ipairs(specItemIDs) do
                    itemImpliedFilter[id] = true
                end
            end
        else
            -- No single spec covers all selected items — only keep selected
            itemImpliedFilter = {}
            for id in pairs(selectedItemIDs) do
                itemImpliedFilter[id] = true
            end
        end
    end
    -- Fetch enriched item data with class filter so the EJ returns only items
    -- relevant to this class (all specs).  Using the class filter ensures the
    -- client has cached data (name, icon) for every item returned.
    local displayItems
    if sourceType == VCA.ContentType.RAID then
        displayItems = VCA.LootPool.GetEncounterItems(sourceID, difficultyID, classID)
    else
        displayItems = VCA.LootPool.GetInstanceItems(sourceID, difficultyID, classID).all
    end

    -- Sort by equipment slot: head first, trinkets last.
    table.sort(displayItems, function(a, b)
        local oa = GetSlotSortOrder(a.itemID)
        local ob = GetSlotSortOrder(b.itemID)
        if oa ~= ob then return oa < ob end
        return (a.name or "") < (b.name or "")
    end)

    local colW      = LeftColWidth()
    local rowTop    = 0
    for _, item in ipairs(displayItems) do
        local obtained = VCA.Data.IsObtained(sourceType, sourceID, difficultyID, item.itemID)
        local row      = GetOrCreateItemRow(itemRows, itemScrollChild)
        row.frame:SetWidth(colW - PADDING)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", itemScrollChild, "TOPLEFT", 0, -rowTop)
        row.frame:Show()

        -- Selection highlight
        row.frame.itemID   = item.itemID
        row.frame.itemLink = item.link or ""
        row.frame.itemSlot = item.slot or ""
        if selectedItemIDs[item.itemID] then
            row.selHighlight:SetColorTexture(1, 0.75, 0, 0.18)
            row.selHighlight:Show()
        else
            row.selHighlight:Hide()
        end

        -- (OnClick is wired once at row creation inside GetOrCreateItemRow.)

        -- Icon (info.icon is a fileID number in the current EJ API)
        if item.icon and item.icon ~= 0 and item.icon ~= "" then
            row.icon:SetTexture(item.icon)
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        -- Name with quality color and slot.
        -- GetItemInfo returns quality as the 3rd value; fall back to Uncommon
        -- if the item isn't in the cache yet (rare for EJ items).
        -- For M+ dungeons, quality depends on the selected key level's track.
        local itemName, _, quality = GetItemInfo(item.itemID)
        local ejName = (item.name ~= "" and item.name) or nil
        itemName = itemName or ejName or ("Item " .. item.itemID)
        quality  = quality  or 1
        if sourceType == VCA.ContentType.MYTHIC_PLUS then
            local reward = GetRewardForKeyLevel(selectedKeyLevel)
            if reward and reward.bonusID >= 12793 then
                quality = 4  -- Hero/Myth track → Epic
            end
        end
        local slotText = item.slot ~= "" and (" |cff888888[" .. item.slot .. "]|r") or ""
        row.nameLabel:SetText(QualityColor(quality) .. itemName .. "|r" .. slotText)

        -- Quality border on the icon
        if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
            local c = ITEM_QUALITY_COLORS[quality]
            row.iconBorder:SetVertexColor(c.r, c.g, c.b)
            row.iconBorder:Show()
        else
            row.iconBorder:Hide()
        end

        -- Obtained checkbox
        row.checkbox:SetChecked(obtained)
        row.checkbox.itemID     = item.itemID
        row.checkbox.sourceType = sourceType
        row.checkbox.sourceID   = sourceID
        row.checkbox.diffID     = difficultyID
        row.checkbox:SetScript("OnClick", function(self)
            local now = self:GetChecked()
            VCA.Data.SetObtained(self.sourceType, self.sourceID, self.diffID, self.itemID, now)
            -- If item was just marked obtained, deselect it.
            if now and selectedItemIDs[self.itemID] then
                selectedItemIDs[self.itemID] = nil
                SaveItemSelections()
            end
            Panel.Refresh()
        end)

        -- Dim row if obtained, filtered out by spec selection, or
        -- not lootable by the specs implied by the item selection.
        local specFiltered = specFilterSet and not specFilterSet[item.itemID]
        local itemFiltered = itemImpliedFilter and not itemImpliedFilter[item.itemID]
        local dimmed = obtained or specFiltered or itemFiltered
        row.frame.dimmed = dimmed
        if dimmed then
            local alpha = (specFiltered or itemFiltered) and 0.25 or 0.4
            row.nameLabel:SetAlpha(alpha)
            row.iconButton:SetAlpha(alpha)
        else
            row.nameLabel:SetAlpha(1)
            row.iconButton:SetAlpha(1)
        end

        rowTop = rowTop + ROW_H + 2
    end

    itemScrollChild:SetHeight(math.max(rowTop, 1))

    if #displayItems == 0 then
        -- Show a "no items" notice
        local noRow = GetOrCreateItemRow(itemRows, itemScrollChild)
        noRow.frame:SetWidth(colW - PADDING)
        noRow.frame:ClearAllPoints()
        noRow.frame:SetPoint("TOPLEFT", itemScrollChild, "TOPLEFT", 0, 0)
        noRow.frame:Show()
        noRow.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        noRow.nameLabel:SetText("|cff888888" .. L["NO_ITEMS_FOR_SPEC"] .. "|r")
        noRow.nameLabel:SetAlpha(1)
        noRow.iconButton:SetAlpha(0.3)
        noRow.iconBorder:Hide()
        noRow.checkbox:Hide()
        itemScrollChild:SetHeight(ROW_H)
    end

    -- Reset scroll position and update scrollbar
    itemScrollFrame:SetVerticalScroll(0)
    UpdateScrollbar()
end

-- ── Populate spec column ──────────────────────────────────────────────────────

local specScrollChild = CreateFrame("Frame", nil, contentArea)
local specScrollFrame = CreateFrame("ScrollFrame", nil, contentArea)
specScrollFrame:SetScrollChild(specScrollChild)

local function PopulateSpecColumn(sourceType, sourceID, difficultyID, filterItemIDs)
    HideAllSpecRows()

    local rankings
    if filterItemIDs and #filterItemIDs > 0 then
        rankings = VCA.Probability.RankCurrentPlayerSpecsForItems(
            filterItemIDs, sourceType, sourceID, difficultyID)
    else
        rankings = VCA.Probability.RankCurrentPlayerSpecs(sourceType, sourceID, difficultyID)
    end
    local colW     = RightColWidth()
    local rowTop   = 0

    for _, entry in ipairs(rankings) do
        local row = GetOrCreateSpecRow(specRows, specScrollChild)
        row.frame:SetWidth(colW - PADDING)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", specScrollChild, "TOPLEFT", 0, -rowTop)
        row.frame:Show()

        -- Store specID for click selection
        row.frame.specID = entry.specID

        -- Selection highlight
        if selectedSpecIDs[entry.specID] then
            row.selHighlight:SetColorTexture(0.69, 0.28, 0.97, 0.18)
            row.selHighlight:Show()
        else
            row.selHighlight:Hide()
        end

        -- Rank #
        local rankColor = entry.rank == 1 and "|cffffff00" or "|cffaaaaaa"
        row.rankLabel:SetText(rankColor .. "#" .. entry.rank .. "|r")

        -- Spec icon
        if entry.specIcon then
            row.icon:SetTexture(entry.specIcon)
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        -- Spec name (left part of nameLabel)
        local nameColor = entry.allObtained and "|cff44ff44" or
                          (entry.noItems    and "|cff888888" or "|cffdddddd")
        row.nameLabel:SetPoint("LEFT",  row.icon, "RIGHT", 4, 0)
        row.nameLabel:SetPoint("RIGHT", row.frame, "RIGHT", -90, 0)
        row.nameLabel:SetText(nameColor .. (entry.specName or "?") .. "|r")

        -- Stats: remaining/total + percentage (right side)
        -- When items are selected, show the chance to get any selected item
        -- (selectedOdds).  When nothing is selected, show only the pool counts
        -- with no percentage.
        local hasSelection = filterItemIDs and #filterItemIDs > 0
        local statsText
        if entry.noItems then
            statsText = "|cff888888—|r"
        elseif entry.allObtained then
            statsText = "|cff44ff44" .. L["ALL_OBTAINED"] .. "|r"
        elseif hasSelection and entry.selectedOdds then
            local pct = math.floor(entry.selectedOdds * 100 + 0.5)
            statsText = "|cffaaaaaa" .. entry.remainingCount .. "/" ..
                        entry.baseCount .. "|r  " ..
                        "|cffffff00" .. pct .. "%|r"
        else
            statsText = "|cffaaaaaa" .. entry.remainingCount .. "/" ..
                        entry.baseCount .. "|r"
        end
        row.statsLabel:SetText(statsText)

        rowTop = rowTop + ROW_H + 2
    end

    specScrollChild:SetHeight(math.max(rowTop, 1))
end
-- ── Refresh item column ───────────────────────────────────────────────────────────
-- Updates the item column when spec selection changes.
-- Updates the loot header to indicate spec filtering.
RefreshItemColumn = function()
    PopulateItemColumn(Panel.sourceType, Panel.sourceID, Panel.difficultyID)
    local count = 0
    for _ in pairs(selectedSpecIDs) do count = count + 1 end
    if count > 0 then
        local label = count == 1 and L["COL_LOOT_FILTERED"] or string.format(L["COL_LOOT_FILTERED_N"], count)
        lootColHeader:SetText("|cffb048f8" .. label .. "|r")
        clearSpecBtn:Show()
    else
        lootColHeader:SetText("|cffb048f8" .. L["COL_LOOT"] .. "|r")
        clearSpecBtn:Hide()
    end
end
-- ── Refresh spec column ───────────────────────────────────────────────────────────
-- Updates the spec column based on current item selection:
--   * Items selected  → header shows “SPEC FIT” and ranks by intersection
--   * Nothing selected → normal full-pool rankings
RefreshSpecColumn = function()
    local selectedList = {}
    for id in pairs(selectedItemIDs) do
        selectedList[#selectedList + 1] = id
    end
    if #selectedList > 0 then
        local count = #selectedList
        local label = count == 1 and L["COL_SPEC_FIT"] or (L["COL_SPEC_FIT"] .. "  |cff888888(" .. count .. ")|r")
        specColHeader:SetText("|cffb048f8" .. label .. "|r")
        clearItemBtn:Show()
        PopulateSpecColumn(Panel.sourceType, Panel.sourceID, Panel.difficultyID, selectedList)
    else
        specColHeader:SetText("|cffb048f8" .. L["COL_SPEC_RANKING"] .. "|r")
        clearItemBtn:Hide()
        PopulateSpecColumn(Panel.sourceType, Panel.sourceID, Panel.difficultyID)
    end
end
-- ── Layout pass ───────────────────────────────────────────────────────────────
-- Recalculates all column/scroll frame positions.  Called on Refresh and on
-- frame resize (if we ever make it resizable).

local function DoLayout()
    local contentH  = contentArea:GetHeight() - COL_HEADER_H - 10
    local leftW     = LeftColWidth()
    local rightW    = RightColWidth()
    local splitX    = PADDING + leftW

    -- Column separator
    colSep:ClearAllPoints()
    colSep:SetPoint("TOP",    contentArea, "TOPLEFT", splitX, -2)
    colSep:SetPoint("BOTTOM", contentArea, "BOTTOMLEFT", splitX, 2)

    -- Clear-spec-selection button (near center divider, inside loot column)
    clearSpecBtn:ClearAllPoints()
    clearSpecBtn:SetPoint("RIGHT", contentArea, "TOPLEFT", splitX - 4, -6 - (COL_HEADER_H / 2) + 4)

    -- Spec column header position (left col header is already anchored)
    specColHeader:ClearAllPoints()
    specColHeader:SetPoint("TOPLEFT", contentArea, "TOPLEFT", splitX + PADDING, -6)

    -- Clear-item-selection button (just left of center divider)
    clearItemBtn:ClearAllPoints()
    clearItemBtn:SetPoint("RIGHT", contentArea, "TOPLEFT", splitX - 22, -6 - (COL_HEADER_H / 2) + 4)

    -- Loot spec label (right-aligned in the spec column header row)
    lootSpecLabel:ClearAllPoints()
    lootSpecLabel:SetPoint("RIGHT", contentArea, "TOPRIGHT", -PADDING, -6 - (COL_HEADER_H / 2) + 4)

    -- Item scroll frame
    itemScrollFrame:ClearAllPoints()
    itemScrollFrame:SetPoint("TOPLEFT",     contentArea, "TOPLEFT", PADDING, -(COL_HEADER_H + 8))
    itemScrollFrame:SetPoint("BOTTOMLEFT",  contentArea, "BOTTOMLEFT", PADDING, 4)
    itemScrollFrame:SetWidth(leftW - PADDING)

    itemScrollChild:SetWidth(leftW - PADDING)

    -- Spec scroll frame
    specScrollFrame:ClearAllPoints()
    specScrollFrame:SetPoint("TOPLEFT",    contentArea, "TOPLEFT", splitX + PADDING, -(COL_HEADER_H + 8))
    specScrollFrame:SetPoint("BOTTOMRIGHT",contentArea, "BOTTOMRIGHT", -PADDING, 4)
    specScrollFrame:SetWidth(rightW - PADDING)

    specScrollChild:SetWidth(rightW - PADDING)
end

-- ── Context update ────────────────────────────────────────────────────────────

-- Persist the current item selection to the char DB.
SaveItemSelections = function()
    if Panel.sourceType and Panel.sourceID and Panel.difficultyID then
        VCA.Data.SaveSelectedItems(Panel.sourceType, Panel.sourceID,
            Panel.difficultyID, selectedItemIDs)
    end
end

function Panel.SetContext(sourceType, sourceID, difficultyID, sourceName, isRaid)
    -- Persist outgoing selections before switching context.
    SaveItemSelections()

    -- Restore saved item selection for this source (spec selection is transient).
    wipe(selectedItemIDs)
    wipe(selectedSpecIDs)
    local saved = VCA.Data.GetSelectedItems(sourceType, sourceID, difficultyID)
    for id in pairs(saved) do
        selectedItemIDs[id] = true
    end
    HideAllItemRows()
    HideAllSpecRows()

    Panel.sourceType   = sourceType
    Panel.sourceID     = sourceID
    Panel.difficultyID = difficultyID

    sourceLabel:SetText(sourceName or "")
    Panel.isRaid = isRaid

    -- Show key level dropdown only for M+ dungeons
    if sourceType == VCA.ContentType.MYTHIC_PLUS then
        UpdateKeyLevelText()
        keyLevelButton:Show()
    else
        keyLevelButton:Hide()
        keyLevelMenu:Hide()
    end

    Panel.Refresh()
end

-- ── Refresh ───────────────────────────────────────────────────────────────────

function Panel.Refresh()
    if not frame:IsShown() then return end
    if not Panel.sourceID  then return end

    -- Update loot spec label
    local lootSpecID = VCA.SpecInfo.GetEffectiveLootSpecID()
    if lootSpecID and lootSpecID > 0 then
        local _, name, _, icon = GetSpecializationInfoByID(lootSpecID)
        if name then
            lootSpecLabel:SetText("|cff888888" .. L["LOOT_SPEC_LABEL"] .. "|r |cffdddddd" .. name .. "|r")
        else
            lootSpecLabel:SetText("")
        end
    else
        lootSpecLabel:SetText("")
    end

    -- Update info label with voidcore cost; turn red when the player cannot afford it.
    local cost       = VCA.Probability.GetVoidcoreCost(Panel.sourceType)
    local contentTag = Panel.isRaid and L["CONTENT_RAID_BOSS"] or L["CONTENT_MP_DUNGEON"]
    local coreWord   = cost == 1 and L["NEBULOUS_VOIDCORE"] or L["NEBULOUS_VOIDCORES"]
    local currInfo   = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(VCA.VOIDCORE_CURRENCY_ID)
    local owned      = currInfo and currInfo.quantity or 0
    local costColor
    if owned < cost then
        costColor = "|cffff3333"  -- red: cannot afford
    elseif cost == 2 then
        costColor = "|cffffff00"  -- yellow for raids
    else
        costColor = "|cff00ff00"  -- green for M+
    end
    infoLabel:SetText(contentTag .. "  •  " .. costColor .. cost .. " " .. coreWord .. "|r")

    DoLayout()
    PopulateItemColumn(Panel.sourceType, Panel.sourceID, Panel.difficultyID)
    RefreshSpecColumn()
end

-- ── Detection callback ────────────────────────────────────────────────────────
-- Wired to Detection module: flash the detected item row green, print to chat.

VCA.Detection.SetOnItemDetectedCallback(function(itemID, source)
    -- Chat message
    local itemName = C_Item.GetItemNameByID(itemID) or tostring(itemID)
    print("|cffb048f8VoidcoreAdvisor:|r " .. string.format(L["DETECTED_OBTAINED"],
          "|cnIQ4:" .. itemName .. "|r"))

    -- Remove from saved selections now that it's obtained.
    VCA.Data.RemoveSelectedItem(source.sourceType, source.sourceID,
        source.difficultyID, itemID)
    selectedItemIDs[itemID] = nil

    -- Flash the item row if panel is open for this source
    if Panel.sourceID == source.sourceID and
       Panel.sourceType == source.sourceType and
       Panel.difficultyID == source.difficultyID then
        for _, row in ipairs(itemRows) do
            if row.checkbox.itemID == itemID and row.frame:IsShown() then
                row.flash:SetColorTexture(0, 1, 0, 0.35)
                -- Fade out over ~1.5 s using OnUpdate
                local age = 0
                row.frame:SetScript("OnUpdate", function(self, elapsed)
                    age = age + elapsed
                    local alpha = math.max(0, 0.35 - age * 0.23)
                    row.flash:SetColorTexture(0, 1, 0, alpha)
                    if age >= 1.5 then
                        row.flash:SetColorTexture(0, 1, 0, 0)
                        self:SetScript("OnUpdate", nil)
                    end
                end)
                break
            end
        end
        Panel.Refresh()
    end
end)

-- ── Visibility helpers ────────────────────────────────────────────────────────

function Panel.Show()
    Panel.AnchorToEJ()
    frame:Show()
    Panel.Refresh()
end

function Panel.Hide()
    frame:Hide()
end

function Panel.IsShown()
    return frame:IsShown()
end

-- ── Live spec-change / loot-data update ───────────────────────────────────────
-- When the player changes their loot spec setting, or when the EJ finishes
-- loading loot data for a newly selected instance, refresh both columns.

local specChangeFrame = CreateFrame("Frame")
specChangeFrame:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
specChangeFrame:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
specChangeFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
specChangeFrame:SetScript("OnEvent", function()
    Panel.Refresh()
end)
