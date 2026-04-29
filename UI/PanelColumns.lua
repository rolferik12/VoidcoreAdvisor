-- VoidcoreAdvisor: PanelColumns
-- Populate and refresh logic for the two panel columns.
-- Loaded after Panel.lua.  Accesses shared widget/state references via
-- Panel._s (a table set up by Panel.lua before this file is loaded).
local _, VCA = ...
local L = VCA.L
local Panel = VCA.Panel
local _s = Panel._s

-- Column-layout constants (must match Panel.lua).
local ROW_H = 26
local PADDING = 12

-- ── Scrollbar ──────────────────────────────────────────────────────────────────

local function UpdateScrollbar()
    local childH = _s.itemScrollChild:GetHeight()
    local frameH = _s.itemScrollFrame:GetHeight()
    if childH <= frameH or frameH <= 0 then
        _s.scrollTrack:Hide()
        _s.scrollThumb:Hide()
        return
    end
    _s.scrollTrack:Show()
    _s.scrollThumb:Show()
    local thumbRatio = frameH / childH
    local thumbH = math.max(20, frameH * thumbRatio)
    _s.scrollThumb:SetHeight(thumbH)
    local scrollRange = childH - frameH
    local current = _s.itemScrollFrame:GetVerticalScroll()
    local trackSpace = frameH - thumbH
    local offset = (current / scrollRange) * trackSpace
    _s.scrollThumb:ClearAllPoints()
    _s.scrollThumb:SetPoint("TOPRIGHT", _s.itemScrollFrame, "TOPRIGHT", 0, -offset)
end

Panel.UpdateScrollbar = UpdateScrollbar

-- ── Spec Picker Popup ─────────────────────────────────────────────────────────
-- Floating popup shown when clicking the loot icon on an item row.
-- Multiple specializations can be selected; confirmed with OK.

local SpecPickerPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
SpecPickerPopup:SetFrameStrata("TOOLTIP")
SpecPickerPopup:SetClampedToScreen(true)
SpecPickerPopup:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = {
        left = 3,
        right = 3,
        top = 3,
        bottom = 3
    }
})
SpecPickerPopup:SetBackdropColor(0.05, 0.02, 0.12, 0.95)
SpecPickerPopup:SetBackdropBorderColor(0.58, 0.0, 0.82, 1)
SpecPickerPopup:Hide()

-- Full-screen click-catcher that dismisses the popup without saving.
local _pickerCatchFrame = CreateFrame("Frame", nil, UIParent)
_pickerCatchFrame:SetAllPoints(UIParent)
_pickerCatchFrame:SetFrameStrata("DIALOG")
_pickerCatchFrame:EnableMouse(true)
_pickerCatchFrame:SetPropagateMouseClicks(true)
_pickerCatchFrame:Hide()

local _pickerContext = {}
local _pickerCheckRows = {} -- pooled { frame, checkbox, iconTex, lbl, specID }
local _pickerOkBtn

local PICKER_ROW_H = 22
local PICKER_W = 175
local PICKER_PAD = 6
local PICKER_TOP = 24 -- title bar height
local PICKER_OK_H = 28 -- bottom row reserved for OK button

local function HideSpecPicker()
    SpecPickerPopup:Hide()
    _pickerCatchFrame:Hide()
end

_pickerCatchFrame:SetScript("OnMouseDown", function()
    HideSpecPicker()
end)

local function OnPickerOK()
    local ctx = _pickerContext
    HideSpecPicker()

    local anyChecked = false
    for _, row in ipairs(_pickerCheckRows) do
        if row.frame:IsShown() then
            local checked = row.checkbox:GetChecked()
            VCA.Data.SetObtained(ctx.sourceType, ctx.sourceID, ctx.diffID, row.specID, ctx.itemID, checked)
            if checked then
                anyChecked = true
            end
        end
    end

    if anyChecked then
        -- At least one real spec is now checked; remove any migrated (specID=0) entry.
        VCA.Data.SetObtained(ctx.sourceType, ctx.sourceID, ctx.diffID, 0, ctx.itemID, false)
    end

    if not anyChecked then
        -- All unchecked: item is fully unobtained; remove any stale selection.
        if _s.selectedItemIDs[ctx.itemID] then
            _s.selectedItemIDs[ctx.itemID] = nil
            Panel.SaveItemSelections()
        end
    else
        if _s.selectedItemIDs[ctx.itemID] then
            _s.selectedItemIDs[ctx.itemID] = nil
            Panel.SaveItemSelections()
        end
    end
    Panel.Refresh()
end

local _pickerTitleLabel = SpecPickerPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
_pickerTitleLabel:SetPoint("TOPLEFT", SpecPickerPopup, "TOPLEFT", PICKER_PAD, -8)
_pickerTitleLabel:SetPoint("TOPRIGHT", SpecPickerPopup, "TOPRIGHT", -PICKER_PAD, -8)
_pickerTitleLabel:SetJustifyH("LEFT")
_pickerTitleLabel:SetText(L["SPEC_PICKER_TITLE"])

local function BuildPickerRows(specs, sourceType, sourceID, diffID, itemID)
    for _, row in ipairs(_pickerCheckRows) do
        row.frame:Hide()
    end

    for i, spec in ipairs(specs) do
        local row = _pickerCheckRows[i]
        if not row then
            local f = CreateFrame("Frame", nil, SpecPickerPopup)
            f:SetHeight(PICKER_ROW_H)

            local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            cb:SetSize(16, 16)
            cb:SetPoint("LEFT", f, "LEFT", 0, 0)

            local iconTex = f:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(16, 16)
            iconTex:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", iconTex, "RIGHT", 4, 0)
            lbl:SetPoint("RIGHT", f, "RIGHT", 0, 0)
            lbl:SetJustifyH("LEFT")

            row = {
                frame = f,
                checkbox = cb,
                iconTex = iconTex,
                lbl = lbl
            }
            _pickerCheckRows[i] = row
        end

        row.frame:SetWidth(PICKER_W - PICKER_PAD * 2)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", SpecPickerPopup, "TOPLEFT", PICKER_PAD, -(PICKER_TOP + (i - 1) * PICKER_ROW_H))
        row.iconTex:SetTexture(spec.icon)
        row.lbl:SetText(spec.name)
        row.specID = spec.specID
        -- Pre-check if this spec already has the item recorded as obtained.
        local alreadyObtained = itemID and VCA.Data.IsObtained(sourceType, sourceID, diffID, spec.specID, itemID)
        row.checkbox:SetChecked(alreadyObtained or false)
        row.frame:Show()
    end

    SpecPickerPopup:SetSize(PICKER_W, PICKER_TOP + #specs * PICKER_ROW_H + PICKER_OK_H + PICKER_PAD)

    if not _pickerOkBtn then
        _pickerOkBtn = CreateFrame("Button", nil, SpecPickerPopup, "UIPanelButtonTemplate")
        _pickerOkBtn:SetSize(70, 22)
        _pickerOkBtn:SetText(L["SPEC_PICKER_OK"])
        _pickerOkBtn:SetScript("OnClick", OnPickerOK)
    end
    _pickerOkBtn:ClearAllPoints()
    _pickerOkBtn:SetPoint("BOTTOM", SpecPickerPopup, "BOTTOM", 0, PICKER_PAD)
    _pickerOkBtn:Show()
end

local function ShowSpecPickerFor(anchorWidget, sourceType, sourceID, diffID, itemID)
    _pickerContext.sourceType = sourceType
    _pickerContext.sourceID = sourceID
    _pickerContext.diffID = diffID
    _pickerContext.itemID = itemID
    BuildPickerRows(VCA.SpecInfo.GetPlayerSpecs(), sourceType, sourceID, diffID, itemID)
    SpecPickerPopup:ClearAllPoints()
    SpecPickerPopup:SetPoint("BOTTOMLEFT", anchorWidget, "TOPRIGHT", 4, 0)
    _pickerCatchFrame:Show()
    SpecPickerPopup:Show()
end

-- ── Populate item column ───────────────────────────────────────────────────────

local function PopulateItemColumn(sourceType, sourceID, difficultyID)
    _s.HideAllItemRows()

    local classID = VCA.SpecInfo.GetPlayerClassID()
    local trustedItemSet = {}
    local specs = VCA.SpecInfo.GetPlayerSpecs()

    for _, spec in ipairs(specs) do
        local specItemIDs = VCA.LootPool.GetItemsForSpec(sourceType, sourceID, difficultyID, spec.classID, spec.specID)
        for _, id in ipairs(specItemIDs) do
            trustedItemSet[id] = true
        end
    end

    -- If selected items were persisted from an older dataset for this source,
    -- drop selections that are no longer trusted so they do not force the
    -- entire list into an always-dimmed state.
    local prunedAnySelection = false
    if next(_s.selectedItemIDs) then
        for selID in pairs(_s.selectedItemIDs) do
            if not trustedItemSet[selID] then
                _s.selectedItemIDs[selID] = nil
                prunedAnySelection = true
            end
        end
    end
    if prunedAnySelection then
        Panel.SaveItemSelections()
    end

    -- Build set of item IDs lootable by selected specs (if any).
    local specFilterSet -- nil when no spec filter is active
    if next(_s.selectedSpecIDs) then
        specFilterSet = {}
        for specID in pairs(_s.selectedSpecIDs) do
            local specItemIDs = VCA.LootPool.GetItemsForSpec(sourceType, sourceID, difficultyID, classID, specID)
            for _, id in ipairs(specItemIDs) do
                specFilterSet[id] = true
            end
        end
    end

    -- When items are selected, find which specs can loot ALL of them,
    -- then build a lootable set from those specs to grey out the rest.
    local itemImpliedFilter -- nil when no item selection filter is active
    if next(_s.selectedItemIDs) then
        -- Find specs that can loot every selected item
        local qualifyingSpecs = {}
        for _, spec in ipairs(specs) do
            local specItemIDs = VCA.LootPool.GetItemsForSpec(sourceType, sourceID, difficultyID, classID, spec.specID)
            local idSet = {}
            for _, id in ipairs(specItemIDs) do
                idSet[id] = true
            end
            local coversAll = true
            for selID in pairs(_s.selectedItemIDs) do
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
                local specItemIDs = VCA.LootPool.GetItemsForSpec(sourceType, sourceID, difficultyID, classID, specID)
                for _, id in ipairs(specItemIDs) do
                    itemImpliedFilter[id] = true
                end
            end
        else
            -- No single spec covers all selected items — only keep selected
            itemImpliedFilter = {}
            for id in pairs(_s.selectedItemIDs) do
                itemImpliedFilter[id] = true
            end
        end
    end

    -- Fetch enriched item data with class filter so the EJ returns only items
    -- relevant to this class (all specs).  Using the class filter ensures the
    -- client has cached data (name, icon) for every item returned.
    local displayItems
    if sourceType == VCA.ContentType.RAID then
        displayItems = VCA.LootPool.GetEncounterItems(sourceID, difficultyID, classID, 0)
    else
        displayItems = VCA.LootPool.GetInstanceItems(sourceID, difficultyID, classID, 0).all
    end

    -- Trust gate: never show raw EJ loot without a trusted class/spec-derived
    -- allow-list. If trustedItemSet is empty, this intentionally yields an
    -- empty view instead of leaking the full dungeon loot table.
    local filteredItems = {}
    for _, item in ipairs(displayItems) do
        if trustedItemSet[item.itemID] then
            filteredItems[#filteredItems + 1] = item
        end
    end
    displayItems = filteredItems

    -- Fallback: if EJ enriched reads are temporarily empty but trusted pools
    -- are already available, build a minimal display list from trusted IDs.
    -- This keeps the loot column usable without weakening the trust gate.
    if #displayItems == 0 and next(trustedItemSet) then
        for itemID in pairs(trustedItemSet) do
            local itemName, itemLink, _, _, _, _, _, _, equipLoc, itemIcon = GetItemInfo(itemID)
            if (not itemIcon or itemIcon == 0 or itemIcon == "") and C_Item and C_Item.GetItemInfoInstant then
                local _, _, _, instantEquipLoc, instantIcon = C_Item.GetItemInfoInstant(itemID)
                equipLoc = equipLoc or instantEquipLoc
                itemIcon = itemIcon or instantIcon
            end

            displayItems[#displayItems + 1] = {
                itemID = itemID,
                name = itemName or "",
                link = itemLink or "",
                icon = itemIcon or 0,
                slot = (equipLoc and _G[equipLoc]) or ""
            }
        end
    end

    -- Sort by equipment slot: head first, trinkets last.
    table.sort(displayItems, function(a, b)
        local oa = _s.GetSlotSortOrder(a.itemID)
        local ob = _s.GetSlotSortOrder(b.itemID)
        if oa ~= ob then
            return oa < ob
        end
        return (a.name or "") < (b.name or "")
    end)

    local colW = _s.LeftColWidth()
    local rowTop = 0
    for _, item in ipairs(displayItems) do
        -- An item is considered obtained when it has been won by at least one
        -- of the player's specs.  Probability rows track per-spec state
        -- independently; this just drives the visual dim in the item list.
        local obtained = false
        for _, spec in ipairs(specs) do
            if VCA.Data.IsObtained(sourceType, sourceID, difficultyID, spec.specID, item.itemID) then
                obtained = true
                break
            end
        end
        -- Amber state: obtained only under specID=0 (migrated from pre-spec data).
        local obtainedMigrated = not obtained and
                                     VCA.Data.IsObtainedMigrated(sourceType, sourceID, difficultyID, item.itemID)
        local row = _s.GetOrCreateItemRow(_s.itemRows, _s.itemScrollChild)
        row.frame:SetWidth(colW - PADDING)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", _s.itemScrollChild, "TOPLEFT", 0, -rowTop)
        row.frame:Show()

        -- Selection highlight
        row.frame.itemID = item.itemID
        row.frame.itemLink = item.link or ""
        row.frame.itemSlot = item.slot or ""
        if _s.selectedItemIDs[item.itemID] then
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
        local itemName, _, quality = GetItemInfo(item.itemID)
        local ejName = (item.name ~= "" and item.name) or nil
        itemName = itemName or ejName or ("Item " .. item.itemID)
        quality = quality or 1
        if sourceType == VCA.ContentType.MYTHIC_PLUS then
            local reward = _s.GetRewardForKeyLevel(_s.getSelectedKeyLevel())
            if reward and reward.bonusID >= 12793 then
                quality = 4 -- Hero/Myth track → Epic
            end
        end
        local slotText = item.slot ~= "" and (" |cff888888[" .. item.slot .. "]|r") or ""
        row.nameLabel:SetText(_s.QualityColor(quality) .. itemName .. "|r" .. slotText)

        -- Quality border on the icon
        if ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
            local c = ITEM_QUALITY_COLORS[quality]
            row.iconBorder:SetVertexColor(c.r, c.g, c.b)
            row.iconBorder:Show()
        else
            row.iconBorder:Hide()
        end

        -- Obtained checkbox
        row.checkbox:SetChecked(obtainedMigrated and "migrated" or obtained)
        row.checkbox.itemID = item.itemID
        row.checkbox.sourceType = sourceType
        row.checkbox.sourceID = sourceID
        row.checkbox.diffID = difficultyID
        -- Obtained loot icon button tooltip: list which specs have it obtained.
        row.checkbox.specs = specs
        row.checkbox:SetScript("OnEnter", function(self)
            local obtainedSpecs = {}
            for _, sp in ipairs(self.specs) do
                if VCA.Data.IsObtained(self.sourceType, self.sourceID, self.diffID, sp.specID, self.itemID) then
                    obtainedSpecs[#obtainedSpecs + 1] = sp
                end
            end
            local migratedObtained = VCA.Data.IsObtainedMigrated(self.sourceType, self.sourceID, self.diffID,
                self.itemID)
            if #obtainedSpecs == 0 and not migratedObtained then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["SPEC_PICKER_TITLE"], 1, 1, 1)
            for _, sp in ipairs(obtainedSpecs) do
                GameTooltip:AddLine("|T" .. sp.icon .. ":12:12:0:0:64:64:4:60:4:60|t " .. sp.name, 0.4, 1.0, 0.4)
            end
            if migratedObtained then
                GameTooltip:AddLine(L["OBTAINED_UNKNOWN_SPEC"], 1.0, 0.7, 0.1)
            end
            GameTooltip:Show()
        end)
        row.checkbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row.checkbox:SetScript("OnClick", function(self)
            -- Always open the spec picker, pre-checked to the current obtained state.
            -- OK saves whatever is checked; clicking outside dismisses without changes.
            ShowSpecPickerFor(self, self.sourceType, self.sourceID, self.diffID, self.itemID)
        end)

        -- Dim row if obtained, filtered out by spec selection, or
        -- not lootable by the specs implied by the item selection.
        local specFiltered = specFilterSet and not specFilterSet[item.itemID]
        local itemFiltered = itemImpliedFilter and not itemImpliedFilter[item.itemID]
        local dimmed = obtained or obtainedMigrated or specFiltered or itemFiltered
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

    _s.itemScrollChild:SetHeight(math.max(rowTop, 1))

    if #displayItems == 0 then
        -- Show a "no items" notice
        local noRow = _s.GetOrCreateItemRow(_s.itemRows, _s.itemScrollChild)
        noRow.frame:SetWidth(colW - PADDING)
        noRow.frame:ClearAllPoints()
        noRow.frame:SetPoint("TOPLEFT", _s.itemScrollChild, "TOPLEFT", 0, 0)
        noRow.frame:Show()
        noRow.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        noRow.nameLabel:SetText("|cff888888" .. L["NO_ITEMS_FOR_SPEC"] .. "|r")
        noRow.nameLabel:SetAlpha(1)
        noRow.iconButton:SetAlpha(0.3)
        noRow.iconBorder:Hide()
        noRow.checkbox:Hide()
        _s.itemScrollChild:SetHeight(ROW_H)
    end

    -- Reset scroll position and update scrollbar
    _s.itemScrollFrame:SetVerticalScroll(0)
    UpdateScrollbar()
end

-- ── Populate spec column ───────────────────────────────────────────────────────

local function PopulateSpecColumn(sourceType, sourceID, difficultyID, filterItemIDs)
    _s.HideAllSpecRows()

    local rankings
    if filterItemIDs and #filterItemIDs > 0 then
        rankings = VCA.Probability.RankCurrentPlayerSpecsForItems(filterItemIDs, sourceType, sourceID, difficultyID)
    else
        rankings = VCA.Probability.RankCurrentPlayerSpecs(sourceType, sourceID, difficultyID)
    end
    local colW = _s.RightColWidth()
    local rowTop = 0

    for _, entry in ipairs(rankings) do
        local row = _s.GetOrCreateSpecRow(_s.specRows, _s.specScrollChild)
        row.frame:SetWidth(colW - PADDING)
        row.frame:ClearAllPoints()
        row.frame:SetPoint("TOPLEFT", _s.specScrollChild, "TOPLEFT", 0, -rowTop)
        row.frame:Show()

        -- Store specID for click selection
        row.frame.specID = entry.specID

        -- Selection highlight
        if _s.selectedSpecIDs[entry.specID] then
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
        local nameColor = entry.allObtained and "|cff44ff44" or (entry.noItems and "|cff888888" or "|cffdddddd")
        row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        row.nameLabel:SetPoint("RIGHT", row.frame, "RIGHT", -90, 0)
        row.nameLabel:SetText(nameColor .. (entry.specName or "?") .. "|r")

        -- Stats: remaining/total + percentage (right side)
        local hasSelection = filterItemIDs and #filterItemIDs > 0
        local statsText
        if entry.noItems then
            statsText = "|cff888888—|r"
        elseif entry.allObtained then
            statsText = "|cff44ff44" .. L["ALL_OBTAINED"] .. "|r"
        elseif hasSelection and entry.selectedOdds then
            local pct = math.floor(entry.selectedOdds * 100 + 0.5)
            statsText =
                "|cffaaaaaa" .. entry.remainingCount .. "/" .. entry.baseCount .. "|r  " .. "|cffffff00" .. pct .. "%|r"
        else
            statsText = "|cffaaaaaa" .. entry.remainingCount .. "/" .. entry.baseCount .. "|r"
        end
        row.statsLabel:SetText(statsText)

        rowTop = rowTop + ROW_H + 2
    end

    _s.specScrollChild:SetHeight(math.max(rowTop, 1))
end

-- ── Clear-filter button visibility ────────────────────────────────────────────

local function UpdateClearFilterButton()
    if next(_s.selectedSpecIDs) or next(_s.selectedItemIDs) then
        _s.clearSpecBtn:Show()
    else
        _s.clearSpecBtn:Hide()
    end
end

-- ── Refresh item column ────────────────────────────────────────────────────────
-- Updates the item column when spec selection changes.
-- Updates the loot header to indicate spec filtering.

function Panel.RefreshItemColumn()
    PopulateItemColumn(Panel.sourceType, Panel.sourceID, Panel.difficultyID)
    local count = 0
    for _ in pairs(_s.selectedSpecIDs) do
        count = count + 1
    end
    if count > 0 then
        local label = count == 1 and L["COL_LOOT_FILTERED"] or string.format(L["COL_LOOT_FILTERED_N"], count)
        _s.lootColHeader:SetText("|cffb048f8" .. label .. "|r")
    else
        _s.lootColHeader:SetText("|cffb048f8" .. L["COL_LOOT"] .. "|r")
    end
    UpdateClearFilterButton()
end

-- ── Refresh spec column ────────────────────────────────────────────────────────
-- Updates the spec column based on current item selection:
--   * Items selected  → header shows "SPEC FIT" and ranks by intersection
--   * Nothing selected → normal full-pool rankings

function Panel.RefreshSpecColumn()
    local selectedList = {}
    for id in pairs(_s.selectedItemIDs) do
        selectedList[#selectedList + 1] = id
    end
    if #selectedList > 0 then
        local count = #selectedList
        local label = count == 1 and L["COL_SPEC_FIT"] or (L["COL_SPEC_FIT"] .. "  |cff888888(" .. count .. ")|r")
        _s.specColHeader:SetText("|cffb048f8" .. label .. "|r")
        PopulateSpecColumn(Panel.sourceType, Panel.sourceID, Panel.difficultyID, selectedList)
    else
        _s.specColHeader:SetText("|cffb048f8" .. L["COL_SPEC_RANKING"] .. "|r")
        PopulateSpecColumn(Panel.sourceType, Panel.sourceID, Panel.difficultyID)
    end
    UpdateClearFilterButton()
end
