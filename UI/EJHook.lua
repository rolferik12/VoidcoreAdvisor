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
        VCA.Panel.Show()
    else
        -- Dungeon boss clicked: show entire instance loot pool, not just this boss.
        local _, _, _, _, _, journalInstanceID = EJ_GetEncounterInfo(encounterID)
        if not journalInstanceID then return end

        if not VCA.LootPool.IsCurrentSeasonDungeon(journalInstanceID) then
            VCA.Panel.Hide()
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
        VCA.Panel.Show()
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
        return
    end

    if not VCA.LootPool.IsCurrentSeasonDungeon(instanceID) then
        VCA.Panel.Hide()
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
    VCA.Panel.Show()
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

-- ── EJ open / close sync ──────────────────────────────────────────────────────
-- Wait until PLAYER_LOGIN so EncounterJournal is guaranteed to exist before
-- we try to hook its scripts.  Also kicks off the loot cache warmup.

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

    -- Build season filter and pre-cache all dungeon loot pools.
    VCA.LootPool.BuildSeasonFilter()
    VCA.LootPool.WarmCache()

    if not EncounterJournal then return end

    -- When the EJ closes, hide our panel with it.
    EncounterJournal:HookScript("OnHide", function()
        VCA.Panel.Hide()
    end)

    -- If the EJ is already open on login (rare), lock the anchor in now.
    if EncounterJournal:IsShown() then
        VCA.Panel.AnchorToEJ()
    end
end)
