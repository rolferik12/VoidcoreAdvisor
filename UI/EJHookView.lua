-- VoidcoreAdvisor: EJHookView
-- View-state helpers for Encounter Journal integration.
-- Loaded after EJHook.lua and uses EJHook._s shared state.

local _, VCA = ...
local EJHook = VCA.EJHook
local _s = EJHook._s

local IsEJOnInstanceListView = _s.IsEJOnInstanceListView
local IsEJDungeonsTabSelected = _s.IsEJDungeonsTabSelected
local IsEJRaidsTabSelected = _s.IsEJRaidsTabSelected
local IsCurrentSeasonRaidInstance = _s.IsCurrentSeasonRaidInstance
local IsCurrentSeasonDungeonInstance = _s.IsCurrentSeasonDungeonInstance

-- ── Toggle visibility ─────────────────────────────────────────────────────────

local function IsEJShowingRelevantContent()
    if not EncounterJournal or not EncounterJournal:IsShown() then return false end
    if not (IsEJDungeonsTabSelected() or IsEJRaidsTabSelected()) then return false end
    if IsEJOnInstanceListView() then return false end

    -- Keep the toggle visible while our loot panel is currently displayed.
    if VCA.Panel.IsShown() and VCA.Panel.sourceID and not VCA.RaidOverview.IsShown() then
        return true
    end

    local instanceID = EncounterJournal.instanceID
    if not instanceID or instanceID == 0 then return false end

    local isRaid = IsCurrentSeasonRaidInstance(instanceID) or (EJ_InstanceIsRaid() == true)

    if isRaid then
        if not IsEJRaidsTabSelected() then return false end
        local encounterID = EncounterJournal.encounterID
        if not encounterID or encounterID == 0 then
            return VCA.Panel.IsShown() and VCA.Panel.sourceType == VCA.ContentType.RAID
        end
        local _, _, _, _, _, journalInstanceID = EJ_GetEncounterInfo(encounterID)
        return journalInstanceID and VCA.LootPool.IsCurrentSeasonRaid(journalInstanceID)
    end

    if not IsEJDungeonsTabSelected() then return false end
    return IsCurrentSeasonDungeonInstance(instanceID)
end

local function IsEJShowingOverviewContext()
    if not EncounterJournal or not EncounterJournal:IsShown() then return false end

    if IsEJDungeonsTabSelected() and IsEJOnInstanceListView() then
        return true
    end

    if not IsEJRaidsTabSelected() then return false end
    if IsEJOnInstanceListView() then return false end

    local instanceID = EncounterJournal.instanceID
    if not instanceID or instanceID == 0 then
        return false
    end

    local encounterID = EncounterJournal.encounterID

    -- Keep the overview toggle visible across current-season raid pages.
    if IsCurrentSeasonRaidInstance(instanceID)
       and ((not encounterID or encounterID == 0) or _s.forcedRaidOverviewInstanceID == instanceID)
    then
        return true
    end

    return false
end

function EJHook.UpdateToggleVisibility()
    local btn = EJHook.toggleBtn
    if btn then
        if IsEJShowingRelevantContent() then
            btn:Show()
        else
            btn:Hide()
        end
    end

    local overviewBtn = EJHook.overviewToggleBtn
    if overviewBtn then
        -- Keep dungeon and raid overview buttons at different anchors.
        if IsEJRaidsTabSelected() then
            overviewBtn:ClearAllPoints()
            overviewBtn:SetPoint("TOPRIGHT", EncounterJournal, "TOPRIGHT", -12, -110)
        else
            overviewBtn:ClearAllPoints()
            overviewBtn:SetPoint("TOPRIGHT", EncounterJournal, "TOPRIGHT", -34, -90)
        end

        if IsEJShowingOverviewContext() then
            overviewBtn:Show()
        else
            overviewBtn:Hide()
        end
    end
end

-- ── Overview / re-evaluate helpers ───────────────────────────────────────────

function EJHook.ShowOverviewIfAllowed()
    VCA.DungeonOverview.Hide()
    VCA.RaidOverview.Hide()

    if not IsEJShowingOverviewContext() then
        return
    end
    if VCA.DungeonOverview.IsMinimized() then
        return
    end

    if IsEJOnInstanceListView() then
        if IsEJDungeonsTabSelected() then
            VCA.DungeonOverview.Show()
        end
        return
    end

    local instanceID = EncounterJournal and EncounterJournal.instanceID
    if not instanceID or instanceID == 0 then
        VCA.DungeonOverview.Hide()
        return
    end

    local encounterID = EncounterJournal and EncounterJournal.encounterID
    if IsCurrentSeasonRaidInstance(instanceID)
       and ((not encounterID or encounterID == 0) or _s.forcedRaidOverviewInstanceID == instanceID)
    then
        local difficultyID = EJ_GetDifficulty() or VCA.Difficulty.RAID_NORMAL
        VCA.RaidOverview.Show(instanceID, difficultyID)
    end
end

function EJHook.ReevaluateAndShow()
    if not EncounterJournal or not EncounterJournal:IsShown() then return end
    if not (IsEJDungeonsTabSelected() or IsEJRaidsTabSelected()) then
        VCA.Panel.Hide()
        VCA.DungeonOverview.Hide()
        VCA.RaidOverview.Hide()
        return
    end
    if IsEJOnInstanceListView() then
        VCA.Panel.Hide()
        EJHook.ShowOverviewIfAllowed()
        return
    end
    VCA.Panel.AnchorToEJ()

    local instanceID = EncounterJournal.instanceID
    if not instanceID or instanceID == 0 then return end

    if _s.forcedRaidOverviewInstanceID and _s.forcedRaidOverviewInstanceID == instanceID then
        VCA.Panel.Hide()
        EJHook.ShowOverviewIfAllowed()
        return
    end

    local isRaid = IsCurrentSeasonRaidInstance(instanceID) or (EJ_InstanceIsRaid() == true)

    if isRaid then
        local encounterID = EncounterJournal.encounterID
        if not encounterID or encounterID == 0 then
            VCA.Panel.Hide()
            EJHook.ShowOverviewIfAllowed()
            return
        end

        local name, _, _, _, _, journalInstanceID = EJ_GetEncounterInfo(encounterID)
        if not name then return end
        if not VCA.LootPool.IsCurrentSeasonRaid(journalInstanceID) then return end

        local difficultyID = EJ_GetDifficulty() or VCA.Difficulty.RAID_NORMAL
        VCA.Panel.SetContext(
            VCA.ContentType.RAID,
            encounterID,
            difficultyID,
            name,
            true
        )
        VCA.RaidOverview.Hide()
        VCA.Panel.Show()
    else
        if not VCA.LootPool.IsCurrentSeasonDungeon(instanceID) then return end

        local instanceName = EJ_GetInstanceInfo(instanceID)
        if not instanceName then return end

        VCA.Panel.SetContext(
            VCA.ContentType.MYTHIC_PLUS,
            instanceID,
            VCA.MythicPlusEJDifficulty,
            instanceName,
            false
        )
        VCA.RaidOverview.Hide()
        VCA.Panel.Show()
    end
end

function EJHook.QueueReevaluateAndShow()
    if _s.pendingReevaluate then return end
    _s.pendingReevaluate = true
    C_Timer.After(0, function()
        _s.pendingReevaluate = false
        if VCA.Panel.IsMinimized() then return end

        -- When raid overview was explicitly selected, avoid extra deferred pass.
        local currentInstanceID = EncounterJournal and EncounterJournal.instanceID
        if _s.forcedRaidOverviewInstanceID
           and currentInstanceID
           and _s.forcedRaidOverviewInstanceID == currentInstanceID
        then
            EJHook.ShowOverviewIfAllowed()
            EJHook.UpdateToggleVisibility()
            return
        end

        EJHook.ReevaluateAndShow()
        EJHook.UpdateToggleVisibility()
    end)
end

-- Exposed so LootPool.WarmCache can nudge EJ after cache/season readiness.
function EJHook.TryReevaluate()
    if not EncounterJournal or not EncounterJournal:IsShown() then return end
    if VCA.Panel.IsMinimized() then return end
    EJHook.QueueReevaluateAndShow()
end
