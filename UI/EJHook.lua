-- VoidcoreAdvisor: EJHook
-- Post-hooks into the Encounter Journal to auto-show/hide the panel when the
-- player navigates to a boss or dungeon.
--
-- Hook strategy:
--   hooksecurefunc("EJ_SelectEncounter", ...)  → raid boss view
--   hooksecurefunc("EJ_SelectInstance",  ...)  → dungeon / raid overview
--   hooksecurefunc("EJ_SetDifficulty",   ...)  → difficulty change while panel is open
--
-- The re-entry guard (LootPool._reentryGuard) is checked so that internal EJ
-- calls made during pool reads do not retrigger panel updates.
--
-- Season filter:
--   Only current-season M+ dungeons (from C_ChallengeMode rotation) and
--   current-tier raids trigger the panel.  Old-expansion content is ignored.
--   Filter logic lives in LootPool so the cache warmup can share it.

local _, VCA = ...

VCA.EJHook = {}

local UpdateToggleVisibility  -- forward declaration; defined after toggle button section
local pendingReevaluate = false
local EJ_TAB_DUNGEONS = 4
local EJ_TAB_RAIDS = 5
local forcedRaidOverviewInstanceID = nil

local function IsEJOnInstanceListView()
    return EncounterJournal
        and EncounterJournal.instanceSelect
        and EncounterJournal.instanceSelect:IsShown()
end

local function IsEJDungeonsTabSelected()
    if not EncounterJournal or not EncounterJournal:IsShown() then return false end
    if not PanelTemplates_GetSelectedTab then return false end
    local selected = PanelTemplates_GetSelectedTab(EncounterJournal)
    return selected == EJ_TAB_DUNGEONS
end

local function IsEJRaidsTabSelected()
    if not EncounterJournal or not EncounterJournal:IsShown() then return false end
    if not PanelTemplates_GetSelectedTab then return false end
    local selected = PanelTemplates_GetSelectedTab(EncounterJournal)
    return selected == EJ_TAB_RAIDS
end

local function IsCurrentSeasonRaidInstance(instanceID)
    return instanceID and instanceID > 0 and VCA.LootPool.IsCurrentSeasonRaid(instanceID)
end

local function IsCurrentSeasonDungeonInstance(instanceID)
    return instanceID and instanceID > 0 and VCA.LootPool.IsCurrentSeasonDungeon(instanceID)
end

-- ── Hook: boss encounter selected ────────────────────────────────────────────

hooksecurefunc("EJ_SelectEncounter", function(encounterID)
    if VCA.LootPool._reentryGuard then return end
    if not EncounterJournal or not EncounterJournal:IsShown() then return end

    local isRaid = EJ_InstanceIsRaid() == true

    if isRaid then
        local name, _, _, _, _, journalInstanceID = EJ_GetEncounterInfo(encounterID)
        if not name then
            return
        end

        if not VCA.LootPool.IsCurrentSeasonRaid(journalInstanceID) then
            VCA.Panel.Hide()
            UpdateToggleVisibility()
            return
        end

        forcedRaidOverviewInstanceID = nil
        VCA.RaidOverview.Hide()
        if VCA.EJHook.overviewToggleBtn then
            VCA.EJHook.overviewToggleBtn:Hide()
        end

        local difficultyID = EJ_GetDifficulty() or VCA.Difficulty.RAID_NORMAL
        VCA.Panel.SetContext(
            VCA.ContentType.RAID,
            encounterID,
            difficultyID,
            name,
            true   -- is raid
        )
        if not VCA.Panel.IsMinimized() then
            VCA.Panel.Show()
        end
        if VCA.EJHook.toggleBtn then
            VCA.EJHook.toggleBtn:Show()
        end
        UpdateToggleVisibility()
    else
        -- Dungeon boss clicked: show entire instance loot pool, not just this boss.
        local _, _, _, _, _, journalInstanceID = EJ_GetEncounterInfo(encounterID)
        if not journalInstanceID then return end

        if not VCA.LootPool.IsCurrentSeasonDungeon(journalInstanceID) then
            VCA.Panel.Hide()
            UpdateToggleVisibility()
            return
        end

        forcedRaidOverviewInstanceID = nil
        VCA.RaidOverview.Hide()
        if VCA.EJHook.overviewToggleBtn then
            VCA.EJHook.overviewToggleBtn:Hide()
        end

        local instanceName = EJ_GetInstanceInfo(journalInstanceID)
        if not instanceName then return end

        VCA.Panel.SetContext(
            VCA.ContentType.MYTHIC_PLUS,
            journalInstanceID,
            VCA.MythicPlusEJDifficulty,
            instanceName,
            false  -- not a raid
        )
        if not VCA.Panel.IsMinimized() then
            VCA.Panel.Show()
        end
        if VCA.EJHook.toggleBtn then
            VCA.EJHook.toggleBtn:Show()
        end
        UpdateToggleVisibility()
    end
end)

-- ── Hook: instance (dungeon / raid overview) selected ────────────────────────

hooksecurefunc("EJ_SelectInstance", function(instanceID)
    if VCA.LootPool._reentryGuard then return end
    if not EncounterJournal or not EncounterJournal:IsShown() then return end

    local name = EJ_GetInstanceInfo(instanceID)
    if not name then return end

    VCA.RaidOverview.Hide()

    local isRaid = IsCurrentSeasonRaidInstance(instanceID) or (EJ_InstanceIsRaid() == true)

    if isRaid then
        -- Raid overview page: show the boss overview panel (not the per-boss panel).
        forcedRaidOverviewInstanceID = instanceID
        VCA.Panel.Hide()
        if IsCurrentSeasonRaidInstance(instanceID) and not VCA.DungeonOverview.IsMinimized() then
            local difficultyID = EJ_GetDifficulty() or VCA.Difficulty.RAID_NORMAL
            VCA.RaidOverview.Show(instanceID, difficultyID)
        end
        if VCA.EJHook.toggleBtn then
            VCA.EJHook.toggleBtn:Hide()
        end
        if VCA.EJHook.overviewToggleBtn then
            if IsCurrentSeasonRaidInstance(instanceID) then
                VCA.EJHook.overviewToggleBtn:Show()
            else
                VCA.EJHook.overviewToggleBtn:Hide()
            end
        end
        UpdateToggleVisibility()
        return
    end

    forcedRaidOverviewInstanceID = nil

    if not IsCurrentSeasonDungeonInstance(instanceID) then
        VCA.Panel.Hide()
        UpdateToggleVisibility()
        return
    end

    -- M+ / dungeon overview: show the panel for the whole instance pool.
    VCA.Panel.SetContext(
        VCA.ContentType.MYTHIC_PLUS,
        instanceID,
        VCA.MythicPlusEJDifficulty,
        name,
        false  -- not a raid
    )
    if not VCA.Panel.IsMinimized() then
        VCA.Panel.Show()
    end
    if VCA.EJHook.toggleBtn then
        VCA.EJHook.toggleBtn:Show()
    end
    if VCA.EJHook.overviewToggleBtn then
        VCA.EJHook.overviewToggleBtn:Hide()
    end
    UpdateToggleVisibility()
end)

-- ── Hook: difficulty changed while panel is open ──────────────────────────────
-- When the user changes the EJ difficulty dropdown for a raid, refresh the
-- panel's stored difficultyID so later probability reads use the right pool.

hooksecurefunc("EJ_SetDifficulty", function(difficultyID)
    if VCA.LootPool._reentryGuard then return end
    if VCA.RaidOverview.IsShown() then
        local instanceID = EncounterJournal and EncounterJournal.instanceID
        if instanceID and instanceID > 0 then
            VCA.RaidOverview.Show(instanceID, difficultyID)
        end
    end
    if not VCA.Panel.IsShown() then return end
    if VCA.Panel.sourceType ~= VCA.ContentType.RAID then return end

    -- Update stored difficulty and re-apply context with the same source.
    if VCA.Panel.sourceID then
        local name = VCA.Panel.sourceLabel and VCA.Panel.sourceLabel:GetText() or ""
        VCA.Panel.SetContext(
            VCA.ContentType.RAID,
            VCA.Panel.sourceID,
            difficultyID,
            name,
            true
        )
    end
end)

-- ── Toggle button visibility ─────────────────────────────────────────────────
-- Returns true if the EJ is currently showing a current-season dungeon or raid
-- boss (i.e. content the panel cares about).

local function IsEJShowingRelevantContent()
    if not EncounterJournal or not EncounterJournal:IsShown() then return false end
    if not (IsEJDungeonsTabSelected() or IsEJRaidsTabSelected()) then return false end
    if IsEJOnInstanceListView() then return false end

    -- If our loot panel is already visible for the current page, keep its toggle visible
    -- even if the EJ state has not fully propagated encounter fields yet.
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
    else
        if not IsEJDungeonsTabSelected() then return false end
        return IsCurrentSeasonDungeonInstance(instanceID)
    end
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

    -- Keep the overview toggle visible across all current-season raid pages
    -- (overview + boss pages) so the user can force show/hide behavior while
    -- debugging state transitions.
    if IsCurrentSeasonRaidInstance(instanceID)
       and ((not encounterID or encounterID == 0) or forcedRaidOverviewInstanceID == instanceID)
    then
        return true
    end

    return false
end

UpdateToggleVisibility = function()
    local btn = VCA.EJHook.toggleBtn
    if btn then
        if IsEJShowingRelevantContent() then
            btn:Show()
        else
            btn:Hide()
        end
    end

    local overviewBtn = VCA.EJHook.overviewToggleBtn
    if overviewBtn then
        -- Keep dungeon and raid overview buttons at different anchors.
        -- Raid overview uses the same position as the boss loot toggle.
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

local function ShowOverviewIfAllowed()
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
       and ((not encounterID or encounterID == 0) or forcedRaidOverviewInstanceID == instanceID)
    then
        local difficultyID = EJ_GetDifficulty() or VCA.Difficulty.RAID_NORMAL
        VCA.RaidOverview.Show(instanceID, difficultyID)
    end
end

-- ── Re-evaluate current EJ context ───────────────────────────────────────────
-- Inspects the current Encounter Journal state (instance/encounter) and
-- sets the panel context + shows it.  Used by the toggle button and OnShow hook.

local function ReevaluateAndShow()
    if not EncounterJournal or not EncounterJournal:IsShown() then return end
    if not (IsEJDungeonsTabSelected() or IsEJRaidsTabSelected()) then
        VCA.Panel.Hide()
        VCA.DungeonOverview.Hide()
        VCA.RaidOverview.Hide()
        return
    end
    if IsEJOnInstanceListView() then
        VCA.Panel.Hide()
        ShowOverviewIfAllowed()
        return
    end
    VCA.Panel.AnchorToEJ()

    local instanceID = EncounterJournal.instanceID
    if not instanceID or instanceID == 0 then return end

    if forcedRaidOverviewInstanceID and forcedRaidOverviewInstanceID == instanceID then
        VCA.Panel.Hide()
        ShowOverviewIfAllowed()
        return
    end

    local isRaid = IsCurrentSeasonRaidInstance(instanceID) or (EJ_InstanceIsRaid() == true)

    if isRaid then
        local encounterID = EncounterJournal.encounterID
        if not encounterID or encounterID == 0 then
            VCA.Panel.Hide()
            ShowOverviewIfAllowed()
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

local function QueueReevaluateAndShow()
    if pendingReevaluate then return end
    pendingReevaluate = true
    C_Timer.After(0, function()
        pendingReevaluate = false
        if VCA.Panel.IsMinimized() then return end

        -- When a raid overview was explicitly selected, avoid the extra
        -- deferred re-evaluation pass. EJ state can still be mid-transition
        -- here and may briefly hide the overview (flash-close).
        local currentInstanceID = EncounterJournal and EncounterJournal.instanceID
        if forcedRaidOverviewInstanceID
           and currentInstanceID
           and forcedRaidOverviewInstanceID == currentInstanceID
        then
            ShowOverviewIfAllowed()
            UpdateToggleVisibility()
            return
        end

        ReevaluateAndShow()
        UpdateToggleVisibility()
    end)
end
-- Exposed so LootPool.WarmCache can nudge the EJ after the cache / season
-- filter becomes ready (e.g. data was unavailable at login and warmed later).
function VCA.EJHook.TryReevaluate()
    if not EncounterJournal or not EncounterJournal:IsShown() then return end
    if VCA.Panel.IsMinimized() then return end
    QueueReevaluateAndShow()
end
-- ── EJ open / close sync ──────────────────────────────────────────────────────
-- Wait until PLAYER_LOGIN so EncounterJournal can be loaded before we try to
-- hook its scripts.

local syncFrame = CreateFrame("Frame")
syncFrame:RegisterEvent("PLAYER_LOGIN")
syncFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
syncFrame:SetScript("OnEvent", function(self, event)
    if event == "CHALLENGE_MODE_MAPS_UPDATE" then
        -- M+ rotation may have changed (new season); rebuild and re-warm.
        VCA.LootPool.InvalidateCache()
        VCA.LootPool.BuildSeasonFilter()
        VCA.LootPool.WarmCache()
        return
    end

    -- PLAYER_LOGIN
    self:UnregisterEvent("PLAYER_LOGIN")

    if not EncounterJournal and EncounterJournal_LoadUI then
        EncounterJournal_LoadUI()
    end

    if not EncounterJournal then return end

    -- When the EJ closes, hide our panel with it.
    EncounterJournal:HookScript("OnHide", function()
        forcedRaidOverviewInstanceID = nil
        VCA.Panel.Hide()
        VCA.DungeonOverview.Hide()
        VCA.RaidOverview.Hide()
        UpdateToggleVisibility()
    end)

    -- When the EJ opens (or reopens), re-evaluate the current instance/encounter
    -- so the panel shows even if EJ_SelectInstance / EJ_SelectEncounter didn't fire.
    EncounterJournal:HookScript("OnShow", function()
        VCA.Panel.AnchorToEJ()
        UpdateToggleVisibility()
        ShowOverviewIfAllowed()
        if VCA.Panel.IsMinimized() then return end
        QueueReevaluateAndShow()
    end)

    -- Initial open / navigation can update instance state one frame later.
    -- Hook this to keep the panel in sync on the first EJ open in instances.
    if type(EncounterJournal_DisplayInstance) == "function" then
        hooksecurefunc("EncounterJournal_DisplayInstance", function()
            if not EncounterJournal or not EncounterJournal:IsShown() then return end
            QueueReevaluateAndShow()
        end)
    end

    -- When the user navigates back to the instance list, hide the main panel
    -- and show the dungeon overview instead.
    if EncounterJournal.instanceSelect then
        EncounterJournal.instanceSelect:HookScript("OnShow", function()
            forcedRaidOverviewInstanceID = nil
            VCA.Panel.Hide()
            if VCA.EJHook.toggleBtn then VCA.EJHook.toggleBtn:Hide() end
            ShowOverviewIfAllowed()
            UpdateToggleVisibility()
        end)
        EncounterJournal.instanceSelect:HookScript("OnHide", function()
            VCA.DungeonOverview.Hide()
            UpdateToggleVisibility()
        end)
    end

    -- When the user switches EJ tabs (Dungeons & Raids, Loot, Journeys, etc.),
    -- hide the panel and button directly. EJ state (instanceID) is still stale
    -- when this fires, so UpdateToggleVisibility would immediately re-show it.
    EventRegistry:RegisterCallback("EncounterJournal.TabSet", function()
        forcedRaidOverviewInstanceID = nil
        VCA.Panel.Hide()
        VCA.DungeonOverview.Hide()
        VCA.RaidOverview.Hide()
        if VCA.EJHook.toggleBtn then VCA.EJHook.toggleBtn:Hide() end

        -- Tab switching updates EJ state asynchronously; re-check next frame.
        C_Timer.After(0, function()
            if not EncounterJournal or not EncounterJournal:IsShown() then return end

            if IsEJDungeonsTabSelected() or IsEJRaidsTabSelected() then
                if IsEJOnInstanceListView() then
                    ShowOverviewIfAllowed()
                elseif not VCA.Panel.IsMinimized() then
                    QueueReevaluateAndShow()
                end
            end

            UpdateToggleVisibility()
        end)
    end, "VoidcoreAdvisor")

    -- ── Toggle button (BonusLoot-Chest) ──────────────────────────────────────
    -- Small chest icon in the top-right of the Encounter Journal that lets
    -- the user show/hide the VoidcoreAdvisor panel.
    local toggleBtn = CreateFrame("Button", nil, EncounterJournal)
    toggleBtn:SetSize(36, 36)
    toggleBtn:SetPoint("TOPRIGHT", EncounterJournal, "TOPRIGHT", -12, -110)

    local toggleIcon = toggleBtn:CreateTexture(nil, "ARTWORK")
    toggleIcon:SetAllPoints()
    toggleIcon:SetAtlas("azeritereforger-glow")

    local toggleHighlight = toggleBtn:CreateTexture(nil, "HIGHLIGHT")
    toggleHighlight:SetSize(32, 32)
    toggleHighlight:SetPoint("CENTER")
    toggleHighlight:SetAtlas("azeritereforger-glow")
    toggleHighlight:SetVertexColor(1, 0.82, 0, 0.7)

    toggleBtn:SetScript("OnClick", function()
        if VCA.Panel.IsMinimized() then
            VCA.Panel.SetMinimized(false)
            ReevaluateAndShow()
        else
            VCA.Panel.SetMinimized(true)
            VCA.Panel.Hide()
        end
    end)

    toggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("VoidcoreAdvisor")
        if VCA.Panel.IsMinimized() then
            GameTooltip:AddLine(VCA.L["TOGGLE_SHOW"], 1, 1, 1)
        else
            GameTooltip:AddLine(VCA.L["TOGGLE_HIDE"], 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    toggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    toggleBtn:Hide()  -- hidden by default; shown when viewing relevant content
    VCA.EJHook.toggleBtn = toggleBtn

    -- ── Overview toggle button (instance-list view) ─────────────────────────
    -- Chest icon near the panel toggle; controls dungeon overview visibility.
    local overviewToggleBtn = CreateFrame("Button", nil, EncounterJournal)
    overviewToggleBtn:SetSize(36, 36)
    overviewToggleBtn:SetPoint("TOPRIGHT", EncounterJournal, "TOPRIGHT", -34, -90)

    local overviewIcon = overviewToggleBtn:CreateTexture(nil, "ARTWORK")
    overviewIcon:SetAllPoints()
    overviewIcon:SetAtlas("azeritereforger-glow")
    overviewIcon:SetVertexColor(0.75, 0.85, 1, 1)

    local overviewHighlight = overviewToggleBtn:CreateTexture(nil, "HIGHLIGHT")
    overviewHighlight:SetSize(32, 32)
    overviewHighlight:SetPoint("CENTER")
    overviewHighlight:SetAtlas("azeritereforger-glow")
    overviewHighlight:SetVertexColor(0.2, 0.8, 1, 0.7)

    overviewToggleBtn:SetScript("OnClick", function()
        if VCA.DungeonOverview.IsMinimized() then
            VCA.DungeonOverview.SetMinimized(false)
            ShowOverviewIfAllowed()
        else
            VCA.DungeonOverview.SetMinimized(true)
            VCA.DungeonOverview.Hide()
            VCA.RaidOverview.Hide()
        end
        UpdateToggleVisibility()
    end)

    overviewToggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("VoidcoreAdvisor")
        if VCA.DungeonOverview.IsMinimized() then
            GameTooltip:AddLine(VCA.L["TOGGLE_OVERVIEW_SHOW"], 1, 1, 1)
        else
            GameTooltip:AddLine(VCA.L["TOGGLE_OVERVIEW_HIDE"], 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    overviewToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    overviewToggleBtn:Hide()
    VCA.EJHook.overviewToggleBtn = overviewToggleBtn

    -- If the EJ is already open on login (rare), lock the anchor in now.
    if EncounterJournal:IsShown() then
        VCA.Panel.AnchorToEJ()
        UpdateToggleVisibility()
    end
end)
