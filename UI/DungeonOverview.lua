-- VoidcoreAdvisor: DungeonOverview
-- Shown when the Encounter Journal is on the dungeon/instance list view.
-- Displays all current-season M+ dungeons sorted descending by loot percentage,
-- showing the best spec's stats for each dungeon.
--
-- A dungeon is omitted when its best spec has no remaining items to obtain.
-- Sorted by: remainingOdds descending (highest single-item chance first).

local _, VCA = ...
local L = VCA.L

VCA.DungeonOverview = {}
local Overview = VCA.DungeonOverview

-- ── Sizing ────────────────────────────────────────────────────────────────────

local PANEL_WIDTH  = 480
local HEADER_H     = 56    -- title + subtitle + divider
local COL_HEADER_H = 20    -- column label row
local PADDING      = 12    -- inner horizontal padding
local ROW_H        = 26    -- height of one dungeon row
local ICON_SIZE    = 20    -- spec icon size

-- ── Column layout (positions relative to row frame LEFT) ─────────────────────
--   [DUNGEON name ........... 200px] [icon 20] [SPEC name .. 100px] [...] [LOOTED 53] [CHANCE 50]

local COL_DUNGEON_X = 0
local COL_DUNGEON_W = 200
local COL_SPEC_ICON_X = 204          -- COL_DUNGEON_W + 4px gap
local COL_SPEC_NAME_X = 228          -- COL_SPEC_ICON_X + ICON_SIZE + 4
local COL_SPEC_NAME_W = 100
-- Right-side columns (offsets from row RIGHT edge):
local COL_LOOTED_R = -(64 + 4)       -- pct width + gap; RIGHT edge of obtained label
local COL_LOOTED_W = 53
local COL_PCT_R    = 0               -- RIGHT edge of pct label flush with row right
local COL_PCT_W    = 64

-- ── Main frame ────────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
Overview.frame = frame

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
frame:SetBackdropColor(0.05, 0.02, 0.12, 0.95)
frame:SetBackdropBorderColor(0.58, 0.0, 0.82, 1)

-- ── Anchor helper ─────────────────────────────────────────────────────────────

-- Positions the panel flush against the right edge of EncounterJournal.
function Overview.AnchorToEJ()
    local ej = EncounterJournal
    if not ej then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT",    ej, "TOPRIGHT",    52, 0)
    frame:SetPoint("BOTTOMLEFT", ej, "BOTTOMRIGHT", 52, 0)
end

-- ── Header ────────────────────────────────────────────────────────────────────

local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOPLEFT", 18, -16)
titleText:SetText(L["PANEL_TITLE"])

local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function() frame:Hide() end)

local subtitleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
subtitleText:SetPoint("TOPLEFT", 18, -40)
subtitleText:SetText("|cff888888" .. L["DUNGEON_OVERVIEW_SUBTITLE"] .. "|r")

local divider = frame:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(0.58, 0.0, 0.82, 0.4)
divider:SetPoint("TOPLEFT",  frame, "TOPLEFT",  16, -HEADER_H)
divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -HEADER_H)
divider:SetHeight(1)

-- ── Content area ─────────────────────────────────────────────────────────────

local contentArea = CreateFrame("Frame", nil, frame)
contentArea:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0, -(HEADER_H + 1))
contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 11)

-- ── Column headers ────────────────────────────────────────────────────────────
-- Positioned to align with their corresponding row widgets.
-- Row widgets live inside the scrollFrame which is offset PADDING from contentArea left.
-- Therefore contentArea x = PADDING + row x.

local hdrDungeon = contentArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hdrDungeon:SetPoint("TOPLEFT", contentArea, "TOPLEFT", PADDING + COL_DUNGEON_X, -6)
hdrDungeon:SetText("|cffb048f8" .. L["DUNGEON_OVERVIEW_COL_DUNGEON"] .. "|r")

local hdrSpec = contentArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hdrSpec:SetPoint("TOPLEFT", contentArea, "TOPLEFT", PADDING + COL_SPEC_NAME_X, -6)
hdrSpec:SetText("|cffb048f8" .. L["DUNGEON_OVERVIEW_COL_SPEC"] .. "|r")

-- Right-side headers mirror the row right-anchoring.
-- Row frame right = scrollFrame right = contentArea right - PADDING.
-- So contentArea offset = -PADDING + COL_*_R.

local hdrLooted = contentArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hdrLooted:SetJustifyH("RIGHT")
hdrLooted:SetWidth(COL_LOOTED_W)
hdrLooted:SetWordWrap(false)
hdrLooted:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -PADDING + COL_LOOTED_R, -6)
hdrLooted:SetText("|cffb048f8" .. L["DUNGEON_OVERVIEW_COL_LOOTED"] .. "|r")

local hdrChance = contentArea:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hdrChance:SetJustifyH("RIGHT")
hdrChance:SetWidth(COL_PCT_W)
hdrChance:SetWordWrap(false)
hdrChance:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -PADDING + COL_PCT_R, -6)
hdrChance:SetText("|cffb048f8" .. L["DUNGEON_OVERVIEW_COL_CHANCE"] .. "|r")

-- Horizontal rule below column headers
local colHeaderRule = contentArea:CreateTexture(nil, "ARTWORK")
colHeaderRule:SetColorTexture(0.4, 0.4, 0.4, 0.3)
colHeaderRule:SetPoint("TOPLEFT",  contentArea, "TOPLEFT",  PADDING, -(COL_HEADER_H + 2))
colHeaderRule:SetPoint("TOPRIGHT", contentArea, "TOPRIGHT", -PADDING, -(COL_HEADER_H + 2))
colHeaderRule:SetHeight(1)

-- ── Row pool ──────────────────────────────────────────────────────────────────

local dungeonRows = {}

local function GetOrCreateDungeonRow(parent)
    for _, row in ipairs(dungeonRows) do
        if not row.frame:IsShown() then
            return row
        end
    end

    local rowFrame = CreateFrame("Frame", nil, parent)
    rowFrame:SetHeight(ROW_H)

    -- Dungeon name (left side)
    local dungeonLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungeonLabel:SetJustifyH("LEFT")
    dungeonLabel:SetPoint("LEFT", rowFrame, "LEFT", COL_DUNGEON_X, 0)
    dungeonLabel:SetWidth(COL_DUNGEON_W)
    dungeonLabel:SetWordWrap(false)

    -- Spec icon
    local specIcon = rowFrame:CreateTexture(nil, "ARTWORK")
    specIcon:SetSize(ICON_SIZE, ICON_SIZE)
    specIcon:SetPoint("LEFT", rowFrame, "LEFT", COL_SPEC_ICON_X, 0)
    specIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Spec name (immediately right of icon)
    local specLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    specLabel:SetJustifyH("LEFT")
    specLabel:SetPoint("LEFT", rowFrame, "LEFT", COL_SPEC_NAME_X, 0)
    specLabel:SetWidth(COL_SPEC_NAME_W)
    specLabel:SetWordWrap(false)

    -- Looted / total (right side, second from right)
    local obtainedLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    obtainedLabel:SetJustifyH("RIGHT")
    obtainedLabel:SetWidth(COL_LOOTED_W)
    obtainedLabel:SetWordWrap(false)
    obtainedLabel:SetPoint("RIGHT", rowFrame, "RIGHT", COL_LOOTED_R, 0)

    -- Chance percentage (rightmost)
    local pctLabel = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pctLabel:SetJustifyH("RIGHT")
    pctLabel:SetWidth(COL_PCT_W)
    pctLabel:SetWordWrap(false)
    pctLabel:SetPoint("RIGHT", rowFrame, "RIGHT", COL_PCT_R, 0)

    -- Hover highlight texture
    local hoverHighlight = rowFrame:CreateTexture(nil, "HIGHLIGHT")
    hoverHighlight:SetAllPoints(rowFrame)
    hoverHighlight:SetColorTexture(0.58, 0.0, 0.82, 0.12)

    local row = {
        frame         = rowFrame,
        dungeonLabel  = dungeonLabel,
        specIcon      = specIcon,
        specLabel     = specLabel,
        obtainedLabel = obtainedLabel,
        pctLabel      = pctLabel,
    }
    dungeonRows[#dungeonRows + 1] = row
    return row
end

local function HideAllRows()
    for _, row in ipairs(dungeonRows) do row.frame:Hide() end
end

-- ── Scroll frame ──────────────────────────────────────────────────────────────

local scrollChild = CreateFrame("Frame", nil, contentArea)
local scrollFrame = CreateFrame("ScrollFrame", nil, contentArea)
scrollFrame:SetScrollChild(scrollChild)

scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local current   = self:GetVerticalScroll()
    local maxScroll = math.max(0, scrollChild:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(maxScroll, current - delta * ROW_H * 3)))
end)

-- ── Populate ──────────────────────────────────────────────────────────────────

local function Populate()
    HideAllRows()

    local contentW = frame:GetWidth() - PADDING * 2

    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT",     contentArea, "TOPLEFT",     PADDING, -(COL_HEADER_H + 8))
    scrollFrame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -PADDING, 4)
    scrollChild:SetWidth(contentW)

    -- ── Collect and rank ──────────────────────────────────────────────────────

    local instanceIDs = VCA.LootPool.GetSeasonDungeonInstanceIDs()

    if #instanceIDs == 0 then
        -- Season filter not ready yet (edge case at early login)
        local row = GetOrCreateDungeonRow(scrollChild)
        row.frame:SetWidth(contentW)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        row.frame:Show()
        row.dungeonLabel:SetText("|cff888888" .. L["DUNGEON_OVERVIEW_NO_DATA"] .. "|r")
        row.specIcon:Hide()
        row.specLabel:SetText("")
        row.obtainedLabel:SetText("")
        row.pctLabel:SetText("")
        scrollChild:SetHeight(ROW_H)
        return
    end

    local entries = {}

    for _, instanceID in ipairs(instanceIDs) do
        local name = EJ_GetInstanceInfo(instanceID)
        if name then
            local selectedItems = VCA.Data.GetSelectedItems(
                VCA.ContentType.MYTHIC_PLUS,
                instanceID,
                VCA.MythicPlusEJDifficulty
            )

            local selectedList = {}
            for itemID in pairs(selectedItems) do
                selectedList[#selectedList + 1] = itemID
            end

            local hasSelected = #selectedList > 0
            if hasSelected then
                -- CHANCE should reflect selected-item odds for this dungeon.
                local rankings = VCA.Probability.RankCurrentPlayerSpecsForItems(
                    selectedList,
                    VCA.ContentType.MYTHIC_PLUS,
                    instanceID,
                    VCA.MythicPlusEJDifficulty
                )

                -- rankings[1] is the best spec by the module sort policy.
                local best = rankings and rankings[1]
                if best and not best.noItems and best.remainingCount > 0 then
                    entries[#entries + 1] = {
                        name           = name,
                        specName       = best.specName,
                        specIcon       = best.specIcon,
                        baseCount      = best.baseCount,
                        remainingCount = best.remainingCount,
                        remainingOdds  = best.remainingOdds,
                        hasSelected    = true,
                        selectedOdds   = best.selectedOdds,
                    }
                end
            else
                entries[#entries + 1] = {
                    name           = name,
                    specName       = nil,
                    specIcon       = nil,
                    baseCount      = 0,
                    remainingCount = 0,
                    remainingOdds  = 0,
                    hasSelected    = false,
                    selectedOdds   = nil,
                }
            end
        end
    end

    -- Sort descending by remaining odds (highest single-item chance first).
    -- Tiebreak alphabetically by dungeon name for a stable display.
    table.sort(entries, function(a, b)
        -- Dungeons with selected items sort first.
        if a.hasSelected ~= b.hasSelected then
            return a.hasSelected
        end
        -- Selected dungeons are ordered by selected-item chance descending.
        if a.hasSelected and b.hasSelected then
            local aOdds = a.selectedOdds or 0
            local bOdds = b.selectedOdds or 0
            if aOdds ~= bOdds then
                return aOdds > bOdds
            end
        else
            -- Unselected dungeons: keep existing descending full-pool chance.
            if a.remainingOdds ~= b.remainingOdds then
                return a.remainingOdds > b.remainingOdds
            end
        end
        return (a.name or "") < (b.name or "")
    end)

    -- ── Render rows ───────────────────────────────────────────────────────────

    if #entries == 0 then
        local row = GetOrCreateDungeonRow(scrollChild)
        row.frame:SetWidth(contentW)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        row.frame:Show()
        row.dungeonLabel:SetText("|cff44ff44" .. L["DUNGEON_OVERVIEW_ALL_DONE"] .. "|r")
        row.specIcon:Hide()
        row.specLabel:SetText("")
        row.obtainedLabel:SetText("")
        row.pctLabel:SetText("")
        scrollChild:SetHeight(ROW_H)
        return
    end

    local rowTop = 0
    for _, entry in ipairs(entries) do
        local row = GetOrCreateDungeonRow(scrollChild)
        row.frame:SetWidth(contentW)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -rowTop)
        row.frame:Show()

        -- Dungeon name
        row.dungeonLabel:SetText("|cffdddddd" .. entry.name .. "|r")

        -- Spec icon/name: only show when this dungeon has selected items.
        if entry.hasSelected then
            if entry.specIcon then
                row.specIcon:SetTexture(entry.specIcon)
                row.specIcon:Show()
            else
                row.specIcon:Hide()
            end
            row.specLabel:SetText("|cffaaaaaa" .. (entry.specName or "?") .. "|r")
        else
            row.specIcon:Hide()
            row.specLabel:SetText("|cff888888-|r")
        end

        -- Looted / total  (items already obtained / total pool for this spec)
        local obtained = entry.baseCount - entry.remainingCount
        row.obtainedLabel:SetText("|cff888888" .. obtained .. "/" .. entry.baseCount .. "|r")

        -- Loot chance: selected-item chance if this dungeon has selections,
        -- otherwise show a dash as requested.
        if entry.hasSelected and entry.selectedOdds then
            local pct      = math.floor(entry.selectedOdds * 100 + 0.5)
            local pctColor = pct >= 20 and "|cffffff00" or "|cffdddddd"
            row.pctLabel:SetText(pctColor .. pct .. "%|r")
        else
            row.pctLabel:SetText("|cff888888-|r")
        end

        rowTop = rowTop + ROW_H + 2
    end

    scrollChild:SetHeight(math.max(rowTop, 1))
    scrollFrame:SetVerticalScroll(0)
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Overview.Show()
    Overview.AnchorToEJ()
    frame:Show()
    Populate()
end

function Overview.Hide()
    frame:Hide()
end

function Overview.IsShown()
    return frame:IsShown()
end

function Overview.IsMinimized()
    local db = _G[VCA.CHAR_DB_NAME]
    return db and db.overviewMinimized or false
end

function Overview.SetMinimized(val)
    local db = _G[VCA.CHAR_DB_NAME]
    if db then
        db.overviewMinimized = val and true or false
    end
end

-- ── Auto-refresh on loot spec change ─────────────────────────────────────────

local specChangeFrame = CreateFrame("Frame")
specChangeFrame:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
specChangeFrame:SetScript("OnEvent", function()
    if frame:IsShown() then
        Populate()
    end
end)
