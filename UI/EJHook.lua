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

-- ── Hook: boss encounter selected ────────────────────────────────────────────

hooksecurefunc("EJ_SelectEncounter", function(encounterID)
    if VCA.LootPool._reentryGuard then return end
    if not EncounterJournal or not EncounterJournal:IsShown() then return end

    local isRaid = EJ_InstanceIsRaid() == true

    if isRaid then
        local name, _, _, _, _, journalInstanceID = EJ_GetEncounterInfo(encounterID)
        if not name then return end

        if not VCA.LootPool.IsCurrentSeasonRaid(journalInstanceID) then
            VCA.Panel.Hide()
            UpdateToggleVisibility()
            return
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
        UpdateToggleVisibility()
    end
end)

-- ── Hook: instance (dungeon / raid overview) selected ────────────────────────

hooksecurefunc("EJ_SelectInstance", function(instanceID)
    if VCA.LootPool._reentryGuard then return end
    if not EncounterJournal or not EncounterJournal:IsShown() then return end

    local name = EJ_GetInstanceInfo(instanceID)
    if not name then return end

    local isRaid = EJ_InstanceIsRaid() == true

    if isRaid then
        -- For a raid overview page no single encounter is selected yet.
        -- Hide the panel and wait for EJ_SelectEncounter to fire for a boss.
        VCA.Panel.Hide()
        UpdateToggleVisibility()
        return
    end

    if not VCA.LootPool.IsCurrentSeasonDungeon(instanceID) then
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
    UpdateToggleVisibility()
end)

-- ── Hook: difficulty changed while panel is open ──────────────────────────────
-- When the user changes the EJ difficulty dropdown for a raid, refresh the
-- panel's stored difficultyID so later probability reads use the right pool.

hooksecurefunc("EJ_SetDifficulty", function(difficultyID)
    if VCA.LootPool._reentryGuard then return end
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

    local instanceID = EncounterJournal.instanceID
    if not instanceID or instanceID == 0 then return false end

    local isRaid = EJ_InstanceIsRaid() == true

    if isRaid then
        local encounterID = EncounterJournal.encounterID
        if not encounterID or encounterID == 0 then return false end
        local _, _, _, _, _, journalInstanceID = EJ_GetEncounterInfo(encounterID)
        return journalInstanceID and VCA.LootPool.IsCurrentSeasonRaid(journalInstanceID)
    else
        return VCA.LootPool.IsCurrentSeasonDungeon(instanceID)
    end
end

UpdateToggleVisibility = function()
    local btn = VCA.EJHook.toggleBtn
    if not btn then return end
    if IsEJShowingRelevantContent() then
        btn:Show()
    else
        btn:Hide()
    end
end

-- ── Re-evaluate current EJ context ───────────────────────────────────────────
-- Inspects the current Encounter Journal state (instance/encounter) and
-- sets the panel context + shows it.  Used by the toggle button and OnShow hook.

local function ReevaluateAndShow()
    if not EncounterJournal or not EncounterJournal:IsShown() then return end
    VCA.Panel.AnchorToEJ()

    local instanceID = EncounterJournal.instanceID
    if not instanceID or instanceID == 0 then return end

    local isRaid = EJ_InstanceIsRaid() == true

    if isRaid then
        local encounterID = EncounterJournal.encounterID
        if not encounterID or encounterID == 0 then return end

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
        VCA.Panel.Show()
    end
end
-- Exposed so LootPool.WarmCache can nudge the EJ after the cache / season
-- filter becomes ready (e.g. data was unavailable at login and warmed later).
function VCA.EJHook.TryReevaluate()
    if not EncounterJournal or not EncounterJournal:IsShown() then return end
    if VCA.Panel.IsMinimized() then return end
    ReevaluateAndShow()
end
-- ── EJ open / close sync ──────────────────────────────────────────────────────
-- Wait until PLAYER_LOGIN so EncounterJournal is guaranteed to exist before
-- we try to hook its scripts.  Also kicks off the loot cache warmup.

local syncFrame = CreateFrame("Frame")
syncFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
syncFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
syncFrame:SetScript("OnEvent", function(self, event)
    if event == "CHALLENGE_MODE_MAPS_UPDATE" then
        -- M+ rotation may have changed (new season); rebuild and re-warm.
        VCA.LootPool.InvalidateCache()
        VCA.LootPool.BuildSeasonFilter()
        VCA.LootPool.WarmCache()
        return
    end

    -- PLAYER_ENTERING_WORLD
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")

    -- Build season filter and pre-cache all dungeon loot pools.
    VCA.LootPool.BuildSeasonFilter()
    VCA.LootPool.WarmCache()

    if not EncounterJournal then return end

    -- When the EJ closes, hide our panel with it.
    EncounterJournal:HookScript("OnHide", function()
        VCA.Panel.Hide()
        UpdateToggleVisibility()
    end)

    -- When the EJ opens (or reopens), re-evaluate the current instance/encounter
    -- so the panel shows even if EJ_SelectInstance / EJ_SelectEncounter didn't fire.
    EncounterJournal:HookScript("OnShow", function()
        VCA.Panel.AnchorToEJ()
        UpdateToggleVisibility()
        if VCA.Panel.IsMinimized() then return end
        ReevaluateAndShow()
    end)

    -- When the user navigates back to the instance list, hide the toggle
    -- (no encounter/dungeon is selected on that screen).
    if EncounterJournal.instanceSelect then
        EncounterJournal.instanceSelect:HookScript("OnShow", function()
            VCA.Panel.Hide()
            if VCA.EJHook.toggleBtn then VCA.EJHook.toggleBtn:Hide() end
        end)
    end

    -- When the user switches EJ tabs (Dungeons & Raids, Loot, Journeys, etc.),
    -- hide the panel and button directly. EJ state (instanceID) is still stale
    -- when this fires, so UpdateToggleVisibility would immediately re-show it.
    EventRegistry:RegisterCallback("EncounterJournal.TabSet", function()
        VCA.Panel.Hide()
        if VCA.EJHook.toggleBtn then VCA.EJHook.toggleBtn:Hide() end
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

    -- If the EJ is already open on login (rare), lock the anchor in now.
    if EncounterJournal:IsShown() then
        VCA.Panel.AnchorToEJ()
        UpdateToggleVisibility()
    end
end)
