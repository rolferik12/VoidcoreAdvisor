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

local PANEL_WIDTH = 260
local HEADER_H = 50 -- title + status label
local ROW_H = 44 -- icon(36) + 4px top pad + 4px bottom pad (single text line)
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

-- Lazy cache for the Nebulous Voidcore currency icon (currency ID 3418).
local _voidcoreIconID = nil
local function GetVoidcoreIconID()
    if not _voidcoreIconID then
        local info = C_CurrencyInfo.GetCurrencyInfo(3418)
        _voidcoreIconID = info and info.iconFileID
    end
    return _voidcoreIconID
end

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

    -- Layout:
    --   Line 1: [nameLabel …………………………………………………] [4] [pctLabel w=46] [-2]
    --   Line 2: [sourceLabel text] [4] [★][★][★]
    --            stars are 14×14, 6px step (8px overlap), anchored to sourceLabel RIGHT.

    -- Percentage label (top-right, aligned with nameLabel)
    r.pctLabel = r.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.pctLabel:SetPoint("TOPRIGHT", r.frame, "TOPRIGHT", -2, -5)
    r.pctLabel:SetJustifyH("RIGHT")
    r.pctLabel:SetWordWrap(false)

    -- Nebulous Voidcore currency icon, 14×14, sits 2px to the left of pctLabel.
    -- pctLabel left edge = frameRight-48; icon right edge = frameRight-50; icon left = frameRight-64.
    r.pctIcon = r.frame:CreateTexture(nil, "ARTWORK")
    r.pctIcon:SetSize(14, 14)
    r.pctIcon:SetPoint("RIGHT", r.pctLabel, "LEFT", -1, 0)
    r.pctIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.pctIcon:Hide()

    -- Item name (top line; right edge stops before pctIcon: frameRight-64 minus 4px gap = -68)
    r.nameLabel = r.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.nameLabel:SetPoint("TOPLEFT", r.iconButton, "TOPRIGHT", 5, -1)
    r.nameLabel:SetPoint("TOPRIGHT", r.frame, "TOPRIGHT", -68, -1)
    r.nameLabel:SetJustifyH("LEFT")
    r.nameLabel:SetWordWrap(false)
    r.nameLabel:SetHeight(14)

    -- Source name (dungeon / boss).  No TOPRIGHT bound → auto-sizes to text width
    -- so stars can anchor to its RIGHT edge.
    r.sourceLabel = r.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.sourceLabel:SetPoint("TOPLEFT", r.nameLabel, "BOTTOMLEFT", 0, -2)
    r.sourceLabel:SetJustifyH("LEFT")
    r.sourceLabel:SetWordWrap(false)

    -- Favorite-count stars: 14×14, 8px overlap (6px step), immediately right of sourceLabel.
    -- star1 = leftmost (drawn first / bottom layer).
    -- star2/3 drawn on top, each 6px to the right of the previous left edge.
    r.star1 = r.frame:CreateTexture(nil, "ARTWORK")
    r.star1:SetAtlas("PetJournal-FavoritesIcon")
    r.star1:SetSize(14, 14)
    r.star1:SetPoint("LEFT", r.sourceLabel, "RIGHT", 4, -1)

    r.star2 = r.frame:CreateTexture(nil, "ARTWORK")
    r.star2:SetAtlas("PetJournal-FavoritesIcon")
    r.star2:SetSize(14, 14)
    r.star2:SetPoint("LEFT", r.star1, "LEFT", 6, 0)

    r.star3 = r.frame:CreateTexture(nil, "ARTWORK")
    r.star3:SetAtlas("PetJournal-FavoritesIcon")
    r.star3:SetSize(14, 14)
    r.star3:SetPoint("LEFT", r.star2, "LEFT", 6, 0)

    -- Invisible hover target covering all three stars (star span = 26px wide)
    r.starButton = CreateFrame("Button", nil, r.frame)
    r.starButton:SetSize(26, 14)
    r.starButton:SetPoint("LEFT", r.star1, "LEFT", 0, 0)
    r.starButton:EnableMouse(false)

    -- Invisible hover target covering pctIcon + pctLabel (70px wide, right-aligned)
    r.pctButton = CreateFrame("Button", nil, r.frame)
    r.pctButton:SetSize(70, 14)
    r.pctButton:SetPoint("TOPRIGHT", r.frame, "TOPRIGHT", -2, -5)
    r.pctButton:EnableMouse(false)

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

-- Count saved favorites for this vault slot's source, read from the persisted DB
-- via Data.GetSelectedItems.  Panel._s.selectedItemIDs is per-context (one dungeon
-- at a time) and must NOT be used here.
local function CountFavoritesForSource(sourceInfo)
    if not sourceInfo then
        return 0
    end
    local selected = VCA.Data.GetSelectedItems(sourceInfo.sourceType, sourceInfo.sourceID, sourceInfo.difficultyID)
    local count = 0
    for _ in pairs(selected) do
        count = count + 1
    end
    return count
end

-- ── Star tooltip ─────────────────────────────────────────────────────────────
-- Slot sort order for the item list (mirrors BonusRollConfirm).
local VAULT_TIP_SLOT_ORDER = {
    INVTYPE_HEAD = 1,
    INVTYPE_NECK = 2,
    INVTYPE_SHOULDER = 3,
    INVTYPE_CLOAK = 4,
    INVTYPE_CHEST = 5,
    INVTYPE_ROBE = 5,
    INVTYPE_WRIST = 6,
    INVTYPE_HAND = 7,
    INVTYPE_WAIST = 8,
    INVTYPE_LEGS = 9,
    INVTYPE_FEET = 10,
    INVTYPE_FINGER = 11,
    INVTYPE_TRINKET = 12,
    INVTYPE_WEAPON = 13,
    INVTYPE_WEAPONMAINHAND = 13,
    INVTYPE_2HWEAPON = 13,
    INVTYPE_WEAPONOFFHAND = 14,
    INVTYPE_SHIELD = 14,
    INVTYPE_HOLDABLE = 14,
    INVTYPE_RANGED = 15,
    INVTYPE_RANGEDRIGHT = 15
}

-- Tooltip shown when hovering the pct icon/label.
local function ShowPctTooltip(owner, isObtained)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if isObtained then
        GameTooltip:SetText(L["VAULT_PCT_TIP_OBTAINED_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["VAULT_PCT_TIP_OBTAINED_1"], 0.7, 0.7, 0.7, true)
    else
        GameTooltip:SetText(L["VAULT_PCT_TIP_ACTIVE_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["VAULT_PCT_TIP_ACTIVE_1"], 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["VAULT_PCT_TIP_ACTIVE_2"], 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L["VAULT_PCT_TIP_ACTIVE_3"], 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

-- Summary + item list tooltip for the star cluster.
-- Header: source name / count / flavour text, then each wishlist item.
-- currentItemID is marked with the atlas star; others use a same-width spacer.
local function ShowStarTooltip(owner, source)
    local sel = VCA.Data.GetSelectedItems(source.sourceType, source.sourceID, source.difficultyID)
    local count = 0
    for _ in pairs(sel) do
        count = count + 1
    end
    if count == 0 then
        return
    end

    local rows = {}
    for id in pairs(sel) do
        local itemName, _, _, _, _, _, _, _, equipLoc, itemTexture = GetItemInfo(id)
        if itemName then
            rows[#rows + 1] = {
                itemName = itemName,
                itemTexture = itemTexture,
                equipLoc = equipLoc,
                sortKey = VAULT_TIP_SLOT_ORDER[equipLoc] or 99
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.sortKey ~= b.sortKey then
            return a.sortKey < b.sortKey
        end
        return (a.itemName or "") < (b.itemName or "")
    end)

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local sourceName = GetSourceName(source) or L["VAULT_OVERVIEW_UNKNOWN_SOURCE"]
    GameTooltip:SetText(sourceName .. ":", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|A:PetJournal-FavoritesIcon:14:14|a " ..
                            string.format(L["VAULT_OVERVIEW_STAR_TIP_COUNT"], count), 1, 1, 0.82)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["VAULT_OVERVIEW_STAR_TIP_VOIDCORE_1"], 0.7, 0.7, 0.7)
    GameTooltip:AddLine(L["VAULT_OVERVIEW_STAR_TIP_VOIDCORE_2"], 0.7, 0.7, 0.7)

    if #rows > 0 then
        GameTooltip:AddLine(" ")
        for _, row in ipairs(rows) do
            local iconMarkup = row.itemTexture and ("|T" .. row.itemTexture .. ":14:14:0:0:64:64:4:60:4:60|t ") or "  "
            local nameColored = "|cnIQ4:" .. row.itemName .. "|r"
            local slotText = (row.equipLoc and _G[row.equipLoc] and _G[row.equipLoc] ~= "") and
                                 (" |cff888888[" .. _G[row.equipLoc] .. "]|r") or ""
            GameTooltip:AddLine(iconMarkup .. nameColored .. slotText)
        end
    end
    GameTooltip:Show()
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

    -- Annotate each vault item with the favorite count for its source, then
    -- sort ascending: fewest favorites first = most attractive vault slots at top.
    local sMap = GetSourceMap()
    for _, vi in ipairs(vaultItems) do
        vi.favCount = CountFavoritesForSource(sMap[vi.itemID])
    end
    table.sort(vaultItems, function(a, b)
        return (a.favCount or 0) < (b.favCount or 0)
    end)

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

        -- Resolve source and wanted status from persisted DB (not Panel context).
        local sourceInfo = sMap[vi.itemID]
        local isWanted = false
        if sourceInfo then
            local selected = VCA.Data.GetSelectedItems(sourceInfo.sourceType, sourceInfo.sourceID,
                sourceInfo.difficultyID)
            isWanted = selected[vi.itemID] == true
        end

        -- Name: always quality colour regardless of wanted status
        row.nameLabel:SetText(QualityColor(quality) .. itemName .. "|r")

        -- Favorite stars: count of saved favorites for this vault slot's source.
        -- Stars are dimmed when this specific item is not on the favorites list.
        local favCount = vi.favCount or 0
        row.star1:SetShown(favCount >= 1)
        row.star2:SetShown(favCount >= 2)
        row.star3:SetShown(favCount >= 3)
        local starAlpha = isWanted and 1.0 or 0.35
        row.star1:SetAlpha(starAlpha)
        row.star2:SetAlpha(starAlpha)
        row.star3:SetAlpha(starAlpha)

        -- Star tooltip: summary + item list for this source
        if favCount > 0 and sourceInfo then
            local capSource = sourceInfo
            row.starButton:EnableMouse(true)
            row.starButton:SetScript("OnEnter", function(self)
                ShowStarTooltip(self, capSource)
            end)
            row.starButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            row.starButton:EnableMouse(false)
            row.starButton:SetScript("OnEnter", nil)
            row.starButton:SetScript("OnLeave", nil)
        end

        -- Percentage label: purple if wanted, grey otherwise.
        -- Check if the vault item itself is obtained for any loot spec first —
        -- if so, show "—" regardless of what GetBestChanceForItem returns
        -- (which would otherwise give a non-zero value from other pool items).
        local bestOdds, _ = GetBestChanceForItem(vi.itemID, sourceInfo)
        local isVaultItemObtained = false
        if sourceInfo then
            local specs = VCA.SpecInfo.GetPlayerSpecs()
            if specs then
                for _, spec in ipairs(specs) do
                    if VCA.Data.IsObtained(sourceInfo.sourceType, sourceInfo.sourceID, sourceInfo.difficultyID,
                        spec.specID, vi.itemID) then
                        isVaultItemObtained = true
                        break
                    end
                end
            end
        end

        local iconID = GetVoidcoreIconID()

        local function showIcon(desaturated)
            if iconID then
                row.pctIcon:SetTexture(iconID)
                row.pctIcon:SetDesaturated(desaturated)
                row.pctIcon:Show()
            else
                row.pctIcon:Hide()
            end
        end

        if isVaultItemObtained then
            row.pctLabel:SetText("|cff888888—|r")
            showIcon(true)
            row.pctButton:EnableMouse(true)
            row.pctButton:SetScript("OnEnter", function(self)
                ShowPctTooltip(self, true)
            end)
            row.pctButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        elseif sourceInfo and bestOdds and bestOdds > 0 then
            local pct = math.floor(bestOdds * 100 + 0.5)
            local pctColor = isWanted and "|cffb048f8" or "|cff888888"
            row.pctLabel:SetText(pctColor .. pct .. "%|r")
            showIcon(false)
            row.pctButton:EnableMouse(true)
            row.pctButton:SetScript("OnEnter", function(self)
                ShowPctTooltip(self, false)
            end)
            row.pctButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        elseif sourceInfo then
            -- bestOdds == 0: every item in this pool is already obtained
            row.pctLabel:SetText("|cff888888—|r")
            showIcon(true)
            row.pctButton:EnableMouse(true)
            row.pctButton:SetScript("OnEnter", function(self)
                ShowPctTooltip(self, true)
            end)
            row.pctButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            row.pctLabel:SetText("")
            row.pctIcon:Hide()
            row.pctButton:EnableMouse(false)
            row.pctButton:SetScript("OnEnter", nil)
            row.pctButton:SetScript("OnLeave", nil)
        end

        -- Source name below the item name
        local sourceName = GetSourceName(sourceInfo)
        row.sourceLabel:SetText(sourceName and ("|cff888888" .. sourceName .. "|r") or "")

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
