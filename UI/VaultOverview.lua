-- VoidcoreAdvisor: VaultOverview
-- Companion panel that opens alongside the Great Vault (WeeklyRewardsFrame).
--
-- For each Myth-tier vault slot (M+10+ or Raid) it shows the item offered
-- in that slot together with the best Nebulous Voidcore % chance across the
-- player's specs.  Items that are on the player's "wanted" list
-- (selectedItemIDs from the main panel) are highlighted in yellow.
--
-- Reading strategy:
--   1. C_WeeklyRewards.GetActivities() – all activity slots.
--   2. For each completed slot (progress >= threshold):
--        a. If activity.rewards[1].itemDBID is present → vault has generated
--           specific items; call GetItemHyperlink(itemDBID) for the actual link.
--        b. Otherwise (vault not yet generated) → call
--           GetExampleRewardItemHyperlinks(activity.id) for preview items.
--   3. Myth-tier gate: include M+ activities only when activity.level >= 10;
--      include all completed Raid activities.
local _, VCA = ...
local L = VCA.L

VCA.VaultOverview = {}
local VaultOverview = VCA.VaultOverview

-- ── Constants ──────────────────────────────────────────────────────────────────

local PANEL_WIDTH = 340
local HEADER_H = 50 -- title + status label
local ROW_H = 54 -- icon(36) + name line + chance/source line + padding
local ICON_SIZE = 36
local PADDING = 12

-- ── Cached reward type for items (Enum.CachedRewardType.Item = 1) ────────────
local REWARD_TYPE_ITEM = (Enum.CachedRewardType and Enum.CachedRewardType.Item) or 1

-- ── Frame ──────────────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame", "VCAVaultOverview", UIParent, "BackdropTemplate")
frame:SetWidth(PANEL_WIDTH)
frame:SetFrameStrata("HIGH")
frame:SetClampedToScreen(true)
frame:Hide()

frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

frame:SetBackdrop({
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
frame:SetBackdropColor(0.05, 0.02, 0.12, 0.95)
frame:SetBackdropBorderColor(0.58, 0.0, 0.82, 1)

-- Title
local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOPLEFT", 16, -14)
titleText:SetText(L["VAULT_OVERVIEW_TITLE"])

-- Close button
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function()
    frame:Hide()
end)

-- Status / sub-title line
local statusLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusLabel:SetPoint("TOPLEFT", 16, -32)
statusLabel:SetPoint("TOPRIGHT", -32, -32)
statusLabel:SetJustifyH("LEFT")
statusLabel:SetWordWrap(false)
statusLabel:SetText("")

-- ── Scroll area ────────────────────────────────────────────────────────────────

local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -HEADER_H)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetWidth(PANEL_WIDTH - PADDING * 2)
scrollChild:SetHeight(1)
scrollFrame:SetScrollChild(scrollChild)

-- ── Row pool ──────────────────────────────────────────────────────────────────

local _rows = {}

local function GetOrCreateRow(index)
    if _rows[index] then
        return _rows[index]
    end

    local r = {}

    r.frame = CreateFrame("Frame", nil, scrollChild)
    r.frame:SetHeight(ROW_H)

    -- Item icon (clickable for tooltip)
    r.iconButton = CreateFrame("Button", nil, r.frame)
    r.iconButton:SetSize(ICON_SIZE, ICON_SIZE)
    r.iconButton:SetPoint("TOPLEFT", r.frame, "TOPLEFT", 0, -4)

    r.icon = r.iconButton:CreateTexture(nil, "ARTWORK")
    r.icon:SetAllPoints(r.iconButton)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    r.iconBorder = r.iconButton:CreateTexture(nil, "OVERLAY")
    r.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    r.iconBorder:SetAllPoints(r.iconButton)

    -- Item name line
    r.nameLabel = r.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.nameLabel:SetPoint("TOPLEFT", r.iconButton, "TOPRIGHT", 5, -1)
    r.nameLabel:SetPoint("TOPRIGHT", r.frame, "TOPRIGHT", 0, -1)
    r.nameLabel:SetJustifyH("LEFT")
    r.nameLabel:SetWordWrap(false)
    r.nameLabel:SetHeight(14)

    -- Chance / source line (below name)
    r.chanceLabel = r.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.chanceLabel:SetPoint("TOPLEFT", r.nameLabel, "BOTTOMLEFT", 0, -3)
    r.chanceLabel:SetPoint("TOPRIGHT", r.nameLabel, "BOTTOMRIGHT", 0, -3)
    r.chanceLabel:SetJustifyH("LEFT")
    r.chanceLabel:SetWordWrap(false)

    _rows[index] = r
    return r
end

-- ── ItemID → source reverse map ────────────────────────────────────────────────
-- Built lazily from SeasonData.  Raid items prefer the highest difficulty
-- (Mythic > Heroic > Normal) so vault Myth items surface the right loot pool.

local _sourceMap = nil
local _raidDiffPriority = {
    [16] = 3,
    [15] = 2,
    [14] = 1
}

local function BuildSourceMap()
    _sourceMap = {}
    local sd = VCA.SeasonData
    if not sd then
        return
    end

    -- M+ dungeons: bySpec = { [specID] = {itemIDs} }
    if sd.dungeons then
        for instanceID, dungeonData in pairs(sd.dungeons) do
            if dungeonData.bySpec then
                for _, itemList in pairs(dungeonData.bySpec) do
                    for _, itemID in ipairs(itemList) do
                        if not _sourceMap[itemID] then
                            _sourceMap[itemID] = {
                                sourceType = VCA.ContentType.MYTHIC_PLUS,
                                sourceID = instanceID,
                                difficultyID = VCA.MythicPlusEJDifficulty
                            }
                        end
                    end
                end
            end
        end
    end

    -- Raids: bySpec = { [difficultyID] = { [specID] = {itemIDs} } }
    -- Prefer higher-difficulty entries so vault Myth items map to Mythic odds.
    if sd.raids then
        for encounterID, raidData in pairs(sd.raids) do
            if raidData.bySpec then
                for difficultyID, specMap in pairs(raidData.bySpec) do
                    local newPri = _raidDiffPriority[difficultyID] or 0
                    for _, itemList in pairs(specMap) do
                        for _, itemID in ipairs(itemList) do
                            local existing = _sourceMap[itemID]
                            local existingPri = (existing and existing.sourceType == VCA.ContentType.RAID) and
                                                    (_raidDiffPriority[existing.difficultyID] or 0) or -1
                            if not existing or newPri > existingPri then
                                _sourceMap[itemID] = {
                                    sourceType = VCA.ContentType.RAID,
                                    sourceID = encounterID,
                                    difficultyID = difficultyID
                                }
                            end
                        end
                    end
                end
            end
        end
    end
end

local function GetSourceMap()
    if not _sourceMap then
        BuildSourceMap()
    end
    return _sourceMap
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function GetItemIDFromLink(link)
    return link and tonumber(link:match("item:(%d+)"))
end

-- Best voidcore chance for itemID across all player specs.
-- Returns: odds (0–1), bestSpec (or nil when item is not in any spec's pool).
local function GetBestChanceForItem(itemID, sourceInfo)
    if not sourceInfo then
        return 0, nil
    end

    local specs = VCA.SpecInfo.GetPlayerSpecs()
    if not specs or #specs == 0 then
        return 0, nil
    end

    local bestOdds = 0
    local bestSpec = nil

    for _, spec in ipairs(specs) do
        local specItems = VCA.LootPool.GetItemsForSpec(sourceInfo.sourceType, sourceInfo.sourceID,
            sourceInfo.difficultyID, spec.classID, spec.specID)
        local itemInPool = false
        local remaining = 0

        for _, id in ipairs(specItems) do
            if id == itemID then
                itemInPool = true
            end
            if not VCA.Data.IsObtained(sourceInfo.sourceType, sourceInfo.sourceID, sourceInfo.difficultyID, spec.specID,
                id) then
                remaining = remaining + 1
            end
        end

        if itemInPool and remaining > 0 then
            local odds = 1 / remaining
            if odds > bestOdds then
                bestOdds = odds
                bestSpec = spec
            end
        end
    end

    return bestOdds, bestSpec
end

-- Friendly name for a source (dungeon name or boss name).
local function GetSourceName(sourceInfo)
    if not sourceInfo then
        return nil
    end
    if sourceInfo.sourceType == VCA.ContentType.MYTHIC_PLUS then
        return (EJ_GetInstanceInfo(sourceInfo.sourceID))
    else
        return (EJ_GetEncounterInfo(sourceInfo.sourceID))
    end
end

-- Convert numeric quality to an inline color code.
local function QualityColor(quality)
    if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        return string.format("|cff%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
    end
    return "|cffdddddd"
end

-- ── Collect vault items ────────────────────────────────────────────────────────
-- Returns an array of { itemID, link, isActual } for qualifying vault slots.
-- isActual = true when the item is the real vault reward (not just an example).
--
-- 12.0.x (Midnight) notes:
--   • GetActivities(type) filters by vault category:
--       GetActivities(1) → Mythic+ slots
--       GetActivities(3) → Raid slots
--     We only fetch these two — they're the only categories with
--     SeasonData-tracked loot.
--   • ALL activities carry raidString in Season 1 — do not use it to
--     identify raid activities.
--   • GetExampleRewardItemHyperlinks returns TWO STRINGS (not a table):
--       hyperlink, upgradeHyperlink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(id)
--   • Already-claimed activities keep rewards but may have progress=0, so
--     check rewards presence rather than relying solely on progress>=threshold.

local VAULT_TYPE_MYTHICPLUS = 1 -- Mythic+ vault slots  (confirmed 12.0.x)
local VAULT_TYPE_RAID = 3 -- Raid vault slots     (confirmed 12.0.x)

local function CollectVaultItems()
    local result = {}
    local seen = {}
    local sourceMap = GetSourceMap()

    if not C_WeeklyRewards then
        return result
    end

    -- Fetch only M+ and Raid vault slots; combine into one list.
    local mplusActs = C_WeeklyRewards.GetActivities(VAULT_TYPE_MYTHICPLUS) or {}
    local raidActs = C_WeeklyRewards.GetActivities(VAULT_TYPE_RAID) or {}
    local activities = {}
    for _, a in ipairs(mplusActs) do
        activities[#activities + 1] = a
    end
    for _, a in ipairs(raidActs) do
        activities[#activities + 1] = a
    end

    for _, activity in ipairs(activities) do
        -- ── Strategy 1: actual vault item (itemDBID present) ──────────────────
        -- Show any activity whose rewards include a sourceMap-tracked item.
        -- This covers all types (Dungeon, Raid, World) and claimed/unclaimed.
        local gotActual = false
        if activity.rewards then
            for _, reward in ipairs(activity.rewards) do
                if reward.type == REWARD_TYPE_ITEM and reward.itemDBID then
                    local link = C_WeeklyRewards.GetItemHyperlink(reward.itemDBID)
                    if link then
                        local itemID = GetItemIDFromLink(link)
                        if itemID and not seen[itemID] and sourceMap[itemID] then
                            seen[itemID] = true
                            result[#result + 1] = {
                                itemID = itemID,
                                link = link,
                                isActual = true
                            }
                            gotActual = true
                        end
                    end
                end
            end
        end

        -- ── Strategy 2: example item (vault not yet generated this week) ──────
        -- GetExampleRewardItemHyperlinks returns TWO STRINGS (not a table):
        --   hyperlink, upgradeHyperlink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(id)
        -- Prefer the upgradeHyperlink (higher-track version) when available.
        if not gotActual and activity.progress >= activity.threshold then
            local link, upgradeLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(activity.id)
            local bestLink = upgradeLink or link
            if bestLink then
                local itemID = GetItemIDFromLink(bestLink)
                if itemID and not seen[itemID] and sourceMap[itemID] then
                    seen[itemID] = true
                    result[#result + 1] = {
                        itemID = itemID,
                        link = bestLink,
                        isActual = false
                    }
                end
            end
        end
    end

    return result
end

-- ── Refresh ────────────────────────────────────────────────────────────────────

function VaultOverview.Refresh()
    -- Hide all rows
    for _, row in ipairs(_rows) do
        row.frame:Hide()
    end
    statusLabel:SetText("")

    if not C_WeeklyRewards then
        statusLabel:SetText("|cff888888" .. L["VAULT_OVERVIEW_NO_DATA"] .. "|r")
        frame:SetHeight(HEADER_H + 30)
        return
    end

    local vaultItems = CollectVaultItems()
    local selectedItemIDs = VCA.Panel and VCA.Panel._s and VCA.Panel._s.selectedItemIDs

    if #vaultItems == 0 then
        statusLabel:SetText("|cff888888" .. L["VAULT_OVERVIEW_NO_QUALIFYING"] .. "|r")
        frame:SetHeight(HEADER_H + 30)
        return
    end

    -- Determine whether all items are actual vault items or examples
    local hasExamples = false
    for _, vi in ipairs(vaultItems) do
        if not vi.isActual then
            hasExamples = true;
            break
        end
    end

    local countStr = string.format(L["VAULT_OVERVIEW_COUNT"], #vaultItems)
    if hasExamples then
        countStr = countStr .. "  |cff888888" .. L["VAULT_OVERVIEW_EXAMPLES_SUFFIX"] .. "|r"
    end
    statusLabel:SetText("|cff888888" .. countStr .. "|r")

    -- Render rows
    local colW = PANEL_WIDTH - PADDING * 2
    local totalH = 0

    for i, vi in ipairs(vaultItems) do
        local row = GetOrCreateRow(i)
        row.frame:SetWidth(colW)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -totalH)
        row.frame:Show()

        -- Item icon
        local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(vi.itemID)
        itemName = itemName or ("Item " .. vi.itemID)
        local quality = 4 -- Epic: vault items are always Epic-quality in Midnight S1

        local iconTex = (itemIcon and itemIcon ~= 0) and itemIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
        row.icon:SetTexture(iconTex)

        if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
            local c = ITEM_QUALITY_COLORS[quality]
            row.iconBorder:SetVertexColor(c.r, c.g, c.b)
            row.iconBorder:Show()
        else
            row.iconBorder:Hide()
        end

        -- Tooltip on hover
        local capturedLink = vi.link
        row.iconButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(capturedLink)
            GameTooltip:Show()
        end)
        row.iconButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Name (yellow if on wanted list, quality colour otherwise)
        local isWanted = selectedItemIDs and selectedItemIDs[vi.itemID]
        row.nameLabel:SetText((isWanted and "|cffffff00" or QualityColor(quality)) .. itemName .. "|r")

        -- Chance line: "<source name>  XX%"
        local sourceInfo = GetSourceMap()[vi.itemID]
        local bestOdds, _ = GetBestChanceForItem(vi.itemID, sourceInfo)
        local chanceText

        if sourceInfo and bestOdds and bestOdds > 0 then
            local pct = math.floor(bestOdds * 100 + 0.5)
            local sourceName = GetSourceName(sourceInfo) or "?"
            local pctColor = isWanted and "|cffffff00" or "|cffb048f8"
            chanceText = "|cff888888" .. sourceName .. "|r  " .. pctColor .. pct .. "%|r"
        elseif sourceInfo then
            -- Item IS tracked but all copies obtained (remaining = 0 for every spec)
            chanceText = "|cff888888" .. (GetSourceName(sourceInfo) or "?") .. "  |r|cff44ff44" ..
                             L["VAULT_OVERVIEW_OBTAINED"] .. "|r"
        else
            -- Item is not in any tracked loot pool (e.g. token, currency)
            chanceText = "|cff555555" .. L["VAULT_OVERVIEW_UNKNOWN_SOURCE"] .. "|r"
        end

        row.chanceLabel:SetText(chanceText)

        totalH = totalH + ROW_H + 2
    end

    scrollChild:SetHeight(math.max(totalH, 1))
    frame:SetHeight(math.min(600, math.max(HEADER_H + 40, totalH + HEADER_H + PADDING)))
end

-- ── Show / Hide / Toggle ──────────────────────────────────────────────────────

function VaultOverview.Show()
    if not (C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards()) then
        return
    end
    VaultOverview.Refresh()
    if not frame:IsShown() then
        frame:ClearAllPoints()
        if WeeklyRewardsFrame and WeeklyRewardsFrame:IsShown() then
            frame:SetPoint("TOPLEFT", WeeklyRewardsFrame, "TOPRIGHT", 10, 0)
        else
            frame:SetPoint("CENTER", UIParent, "CENTER", 500, 0)
        end
        frame:Show()
    end
end

function VaultOverview.Hide()
    frame:Hide()
end

function VaultOverview.Toggle()
    if frame:IsShown() then
        VaultOverview.Hide()
    else
        VaultOverview.Show()
    end
end

-- ── Events ────────────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
eventFrame:SetScript("OnEvent", function()
    -- Invalidate the source map in case SeasonData was updated, then refresh
    -- the panel if it is already open.
    _sourceMap = nil
    if frame:IsShown() then
        VaultOverview.Refresh()
    end
end)

-- ── Hook WeeklyRewardsFrame show / hide ───────────────────────────────────────
-- Deferred to PLAYER_LOGIN so WeeklyRewardsFrame is guaranteed to exist.

local _hooked = false

local function TryHookVaultFrame()
    if _hooked or not WeeklyRewardsFrame then
        return
    end
    hooksecurefunc(WeeklyRewardsFrame, "Show", VaultOverview.Show)
    hooksecurefunc(WeeklyRewardsFrame, "Hide", VaultOverview.Hide)
    _hooked = true
end

local hookInitFrame = CreateFrame("Frame")
hookInitFrame:RegisterEvent("PLAYER_LOGIN")
hookInitFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    C_Timer.After(0, TryHookVaultFrame)
end)
