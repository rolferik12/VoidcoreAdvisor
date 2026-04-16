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

VCA.Panel = {}
local Panel = VCA.Panel

-- ── Selection state ──────────────────────────────────────────────────────────
-- Tracks which itemIDs the user has clicked to highlight.
-- Ctrl+click toggles an item; plain click is single-select.
local selectedItemIDs = {}  -- set: { [itemID] = true }
local RefreshSpecColumn     -- forward declaration; defined after PopulateSpecColumn

-- ── Sizing ────────────────────────────────────────────────────────────────────

local PANEL_WIDTH   = 600
local HEADER_H      = 76    -- title + source label + info label + divider
local COL_HEADER_H  = 20    -- "LOOT" / "SPEC RANKING" label row
local PADDING       = 12    -- inner horizontal padding
local ROW_H         = 22    -- height of one item / spec row
local ICON_SIZE     = 16    -- inline icon size in rows
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
titleText:SetText("|cffb048f8Voidcore|r|cffddddddAdvisor|r")

-- X close button (uses the standard Blizzard close button template)
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function() frame:Hide() end)

-- Source name (boss or dungeon)
local sourceLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
sourceLabel:SetPoint("TOPLEFT",  18,  -42)
sourceLabel:SetPoint("TOPRIGHT", -40, -42)
sourceLabel:SetJustifyH("LEFT")
sourceLabel:SetWordWrap(false)
sourceLabel:SetText("")
Panel.sourceLabel = sourceLabel

-- Content type + Voidcore cost
local infoLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
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

local lootColHeader = contentArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lootColHeader:SetPoint("TOPLEFT", contentArea, "TOPLEFT", PADDING, -6)
lootColHeader:SetJustifyH("LEFT")
lootColHeader:SetText("|cffb048f8LOOT|r")

local specColHeader = contentArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
specColHeader:SetJustifyH("LEFT")
specColHeader:SetText("|cffb048f8SPEC RANKING|r")

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

    local icon = rowFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- trim default icon border

    local nameLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetPoint("LEFT",  icon, "RIGHT", 4, 0)
    nameLabel:SetPoint("RIGHT", rowFrame, "RIGHT", -20, 0)
    nameLabel:SetWordWrap(false)

    local checkbox = CreateFrame("CheckButton", nil, rowFrame, "UICheckButtonTemplate")
    checkbox:SetSize(16, 16)
    checkbox:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
    -- Prevent the checkbox click from also firing the row Button's OnClick.
    -- In WoW, Button clicks do not bubble up through the frame hierarchy, so
    -- this is already handled correctly by default — no extra work needed.

    local row = {
        frame        = rowFrame,
        flash        = flash,
        selHighlight = selHighlight,
        icon         = icon,
        nameLabel    = nameLabel,
        checkbox     = checkbox,
    }

    -- Wire the selection click once at creation time so it is never lost when
    -- rows are recycled from the pool.
    rowFrame:SetScript("OnClick", function(self, btn)
        local id = self.itemID
        if not id then return end
        if IsControlKeyDown() then
            if selectedItemIDs[id] then
                selectedItemIDs[id] = nil
            else
                selectedItemIDs[id] = true
            end
        else
            wipe(selectedItemIDs)
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
    local rowFrame = CreateFrame("Frame", nil, parent)
    rowFrame:SetHeight(ROW_H)

    local rankLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rankLabel:SetJustifyH("RIGHT")
    rankLabel:SetWidth(16)
    rankLabel:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)

    local icon = rowFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", rankLabel, "RIGHT", 3, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local nameLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetPoint("LEFT",  icon, "RIGHT", 4, 0)
    nameLabel:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
    nameLabel:SetWordWrap(false)

    local statsLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsLabel:SetJustifyH("RIGHT")
    statsLabel:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)

    local row = {
        frame      = rowFrame,
        rankLabel  = rankLabel,
        icon       = icon,
        nameLabel  = nameLabel,
        statsLabel = statsLabel,
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

-- ── Item quality color escape sequence ───────────────────────────────────────
-- Uses |cnIQn: syntax (added in 11.1.5).

local function QualityColor(quality)
    return "|cnIQ" .. (quality or 1) .. ":"
end

-- ── Populate item column ──────────────────────────────────────────────────────

local itemScrollChild = CreateFrame("Frame", nil, contentArea)
local itemScrollFrame = CreateFrame("ScrollFrame", nil, contentArea)
itemScrollFrame:SetScrollChild(itemScrollChild)

local function PopulateItemColumn(sourceType, sourceID, difficultyID)
    HideAllItemRows()

    local classID = VCA.SpecInfo.GetPlayerClassID()
    -- Fetch enriched item data with class filter so the EJ returns only items
    -- relevant to this class (all specs).  Using the class filter ensures the
    -- client has cached data (name, icon) for every item returned.
    local displayItems
    if sourceType == VCA.ContentType.RAID then
        displayItems = VCA.LootPool.GetEncounterItems(sourceID, difficultyID, classID)
    else
        displayItems = VCA.LootPool.GetInstanceItems(sourceID, difficultyID, classID).all
    end

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
        row.frame.itemID = item.itemID
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
        local itemName, _, quality = GetItemInfo(item.itemID)
        local ejName = (item.name ~= "" and item.name) or nil
        itemName = itemName or ejName or ("Item " .. item.itemID)
        quality  = quality  or 1
        local slotText = item.slot ~= "" and (" |cff888888[" .. item.slot .. "]|r") or ""
        row.nameLabel:SetText(QualityColor(quality) .. itemName .. "|r" .. slotText)

        -- Obtained checkbox
        row.checkbox:SetChecked(obtained)
        row.checkbox.itemID     = item.itemID
        row.checkbox.sourceType = sourceType
        row.checkbox.sourceID   = sourceID
        row.checkbox.diffID     = difficultyID
        row.checkbox:SetScript("OnClick", function(self)
            local now = self:GetChecked()
            VCA.Data.SetObtained(self.sourceType, self.sourceID, self.diffID, self.itemID, now)
            Panel.Refresh()
        end)

        -- Dim row if obtained
        if obtained then
            row.nameLabel:SetAlpha(0.4)
            row.icon:SetAlpha(0.4)
        else
            row.nameLabel:SetAlpha(1)
            row.icon:SetAlpha(1)
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
        noRow.nameLabel:SetText("|cff888888No items for this spec|r")
        noRow.nameLabel:SetAlpha(1)
        noRow.icon:SetAlpha(0.3)
        noRow.checkbox:Hide()
        itemScrollChild:SetHeight(ROW_H)
    end
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
        local statsText
        if entry.noItems then
            statsText = "|cff888888—|r"
        elseif entry.allObtained then
            statsText = "|cff44ff44✓ all|r"
        else
            local pct = math.floor(entry.remainingOdds * 100 + 0.5)
            statsText = "|cffaaaaaa" .. entry.remainingCount .. "/" ..
                        entry.baseCount .. "|r  " ..
                        "|cffffff00" .. pct .. "%|r"
        end
        row.statsLabel:SetText(statsText)

        -- Indicate if this is the active loot spec
        if VCA.SpecInfo.IsActiveLootSpec(entry.specID) then
            row.nameLabel:SetText(nameColor .. "► " .. (entry.specName or "?") .. "|r")
        end

        rowTop = rowTop + ROW_H + 2
    end

    specScrollChild:SetHeight(math.max(rowTop, 1))
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
        local label = count == 1 and "SPEC FIT" or ("SPEC FIT  |cff888888(" .. count .. ")|r")
        specColHeader:SetText("|cffb048f8" .. label .. "|r")
        PopulateSpecColumn(Panel.sourceType, Panel.sourceID, Panel.difficultyID, selectedList)
    else
        specColHeader:SetText("|cffb048f8SPEC RANKING|r")
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

    -- Spec column header position (left col header is already anchored)
    specColHeader:ClearAllPoints()
    specColHeader:SetPoint("TOPLEFT", contentArea, "TOPLEFT", splitX + PADDING, -6)

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

function Panel.SetContext(sourceType, sourceID, difficultyID, sourceName, isRaid)
    -- Clear any item selection when switching to a new boss/dungeon.
    wipe(selectedItemIDs)
    HideAllItemRows()
    HideAllSpecRows()

    Panel.sourceType   = sourceType
    Panel.sourceID     = sourceID
    Panel.difficultyID = difficultyID

    sourceLabel:SetText(sourceName or "")

    local cost       = VCA.Probability.GetVoidcoreCost(sourceType)
    local contentTag = isRaid and "Raid Boss" or "M+ Dungeon"
    local costColor  = cost == 2 and "|cffffff00" or "|cff00ff00"
    local coreWord   = cost == 1 and "Nebulous Voidcore" or "Nebulous Voidcores"
    infoLabel:SetText(contentTag .. "  •  " .. costColor .. cost .. " " .. coreWord .. "|r")

    Panel.Refresh()
end

-- ── Refresh ───────────────────────────────────────────────────────────────────

function Panel.Refresh()
    if not frame:IsShown() then return end
    if not Panel.sourceID  then return end

    DoLayout()
    PopulateItemColumn(Panel.sourceType, Panel.sourceID, Panel.difficultyID)
    RefreshSpecColumn()
end

-- ── Detection callback ────────────────────────────────────────────────────────
-- Wired to Detection module: flash the detected item row green, print to chat.

VCA.Detection.SetOnItemDetectedCallback(function(itemID, source)
    -- Chat message
    local itemName = C_Item.GetItemNameByID(itemID) or tostring(itemID)
    print("|cffb048f8VoidcoreAdvisor:|r Auto-detected " ..
          "|cnIQ4:" .. itemName .. "|r as obtained via Nebulous Voidcore.")

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
specChangeFrame:SetScript("OnEvent", function()
    Panel.Refresh()
end)
