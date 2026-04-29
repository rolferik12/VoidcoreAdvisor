-- VoidcoreAdvisor: LootPoolWarm
-- Cache warmup logic for LootPool.  Loaded after LootPool.lua.
-- Accesses LootPool internals via the LootPool._* references that
-- LootPool.lua exposes at its end.

local _, VCA = ...
local LootPool = VCA.LootPool

-- Local alias matching LootPool.lua's CacheKey format (must stay in sync).
local function CacheKey(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...) or 0)
    end
    return table.concat(parts, ":")
end

-- ── EJ warm-state helpers ─────────────────────────────────────────────────────
-- These are only used by WarmCache and are intentionally kept here rather than
-- in LootPool.lua so that file stays focused on reads and cache management.

local _savedWarmEJState = nil

local function RestorePlayerLootFilter()
    local classID = VCA.SpecInfo and VCA.SpecInfo.GetPlayerClassID and VCA.SpecInfo.GetPlayerClassID() or 0
    local specID = VCA.SpecInfo and VCA.SpecInfo.GetEffectiveLootSpecID and VCA.SpecInfo.GetEffectiveLootSpecID() or 0
    local latestTier = EJ_GetNumTiers()

    LootPool._reentryGuard = true
    if latestTier and latestTier > 0 then
        EJ_SelectTier(latestTier)
    end
    EJ_SetLootFilter(classID or 0, specID or 0)
    LootPool._reentryGuard = false
end

local function CaptureWarmEJState()
    if not EncounterJournal or not EncounterJournal:IsShown() then
        return
    end

    local classID, specID = EJ_GetLootFilter()
    _savedWarmEJState = {
        tierID = EJ_GetCurrentTier(),
        difficultyID = EJ_GetDifficulty(),
        classID = classID or 0,
        specID = specID or 0,
        instanceID = EncounterJournal.instanceID,
        encounterID = EncounterJournal.encounterID,
    }
end

local function ReapplySavedWarmEJState()
    local state = _savedWarmEJState
    if not state then
        return
    end

    if EncounterJournal and EncounterJournal:IsShown() then
        -- Never fight the player's live navigation.
        return
    end

    LootPool._reentryGuard = true

    if state.tierID and state.tierID > 0 then
        EJ_SelectTier(state.tierID)
    end
    if state.difficultyID then
        EJ_SetDifficulty(state.difficultyID)
    end
    EJ_SetLootFilter(state.classID or 0, state.specID or 0)

    if state.instanceID and state.instanceID > 0 then
        EJ_SelectInstance(state.instanceID)

        -- Instance/encounter selection can reset filters, so re-apply.
        if state.tierID and state.tierID > 0 then
            EJ_SelectTier(state.tierID)
        end
        if state.difficultyID then
            EJ_SetDifficulty(state.difficultyID)
        end
        EJ_SetLootFilter(state.classID or 0, state.specID or 0)

        if state.encounterID and state.encounterID > 0 then
            EJ_SelectEncounter(state.encounterID)
            if state.tierID and state.tierID > 0 then
                EJ_SelectTier(state.tierID)
            end
            if state.difficultyID then
                EJ_SetDifficulty(state.difficultyID)
            end
            EJ_SetLootFilter(state.classID or 0, state.specID or 0)
        end
    end

    LootPool._reentryGuard = false
    _savedWarmEJState = nil
end

-- ── Warm state ────────────────────────────────────────────────────────────────

local _warmRetries    = 0
local _maxWarmRetries = 5
local _warmTicker     = nil  -- handle for in-progress warm ticker
local _warmInProgress = false
local _warmPausedByEJ = false
local _warmStartRetries = 0
local _maxWarmStartRetries = 3

-- Keep warm-cache work chunks small to avoid startup hitching.
local WARM_TICK_INTERVAL = 0.08
local WARM_BATCH_BUDGET_MS = 1.5
local WARM_BATCH_BUDGET_MS_POST_EJ = 1.0
local WARM_MIN_BATCH_ITEMS = 1
local WARM_MAX_BATCH_ITEMS = 2

function LootPool.IsWarmInProgress()
    return _warmInProgress
end

function LootPool.IsWarmPausedByEJ()
    return _warmInProgress and _warmPausedByEJ
end

function LootPool.GetWarmStatus()
    return {
        inProgress = _warmInProgress,
        pausedByEJ = _warmPausedByEJ,
        retries = _warmRetries,
    }
end

-- ── Cache warmup ──────────────────────────────────────────────────────────────
-- Pre-scans all current-season dungeons × all player specs at login so that
-- Panel.Show() is instant, and also warms current-season raid encounter loot
-- pools for every player spec so raid boss/overview views do not stall on
-- their first EJ open. Retries up to _maxWarmRetries if season or item data
-- is missing (client / EJ data not ready yet).

function LootPool.WarmCache()
    -- Ensure season filter is built; if not, schedule a retry.
    if not LootPool.IsSeasonFilterReady() then
        LootPool.BuildSeasonFilter()
    end

    if not LootPool.IsSeasonFilterReady() then
        _warmInProgress = false
        _warmPausedByEJ = false

        if _warmStartRetries < _maxWarmStartRetries then
            _warmStartRetries = _warmStartRetries + 1
            C_Timer.After(3, function()
                if IsInInstance and IsInInstance() then
                    return
                end
                LootPool.WarmCache()
            end)
        end
        return
    end

    _warmStartRetries = 0
    _warmInProgress = true
    _warmPausedByEJ = false
    _savedWarmEJState = nil

    if not EncounterJournal then
        if EncounterJournal_LoadUI then
            EncounterJournal_LoadUI()
        end
    end

    -- Cancel any in-progress warm ticker from a previous call.
    if _warmTicker then
        _warmTicker:Cancel()
        _warmTicker = nil
    end

    -- Convenience aliases for the internal helpers exposed by LootPool.lua.
    local _cache         = LootPool._cache
    local _seasonRaidIDs = LootPool._seasonRaidIDs
    local WithEJState    = LootPool._WithEJState
    local SelectInstance = LootPool._SelectInstance

    local classID      = VCA.SpecInfo.GetPlayerClassID()
    local specs        = VCA.SpecInfo.GetPlayerSpecs()
    local dungeonIDs   = LootPool.GetSeasonDungeonInstanceIDs()
    local difficultyID = VCA.MythicPlusEJDifficulty
    local raidQueue    = {}
    local selectedRaidPriority = {}

    do
        local db = _G[VCA.CHAR_DB_NAME]
        local selected = db and db.selectedItems
        if type(selected) == "table" then
            for key, set in pairs(selected) do
                if type(key) == "string" and type(set) == "table" and key:sub(1, 5) == "RAID:" and next(set) then
                    -- Key format: RAID:<encounterID>:<difficultyID>
                    local _, encounterID, raidDiff = strsplit(":", key)
                    encounterID = tonumber(encounterID)
                    raidDiff = tonumber(raidDiff)
                    if encounterID and raidDiff then
                        selectedRaidPriority[encounterID .. ":" .. raidDiff] = true
                    end
                end
            end
        end
    end

    WithEJState(VCA.Difficulty.RAID_NORMAL, nil, nil, function()
        for instanceID in pairs(_seasonRaidIDs) do
            SelectInstance(instanceID)
            local idx = 1
            while true do
                local name, _, encounterID = EJ_GetEncounterInfoByIndex(idx)
                if not name then break end
                for raidDifficultyID in pairs(VCA.EligibleRaidDifficulties) do
                    local raidKey = encounterID .. ":" .. raidDifficultyID
                    local priority = selectedRaidPriority[raidKey] and 0 or 1

                    -- Raid-class must be queued BEFORE raid-spec entries for the same
                    -- encounter/difficulty. GetEncounterItemsForSpec cross-validates
                    -- against the class-wide pool; if that pool isn't cached yet it
                    -- triggers a live read, and if EJ data isn't loaded the spec result
                    -- won't be cached. Warming class first ensures the validation succeeds.
                    raidQueue[#raidQueue + 1] = {
                        kind = "raid-class",
                        instanceID = instanceID,
                        encounterID = encounterID,
                        difficultyID = raidDifficultyID,
                        priority = priority,
                    }
                    for _, spec in ipairs(specs) do
                        raidQueue[#raidQueue + 1] = {
                            kind = "raid-spec",
                            instanceID = instanceID,
                            encounterID = encounterID,
                            difficultyID = raidDifficultyID,
                            classID = spec.classID,
                            specID = spec.specID,
                            priority = priority,
                        }
                    end
                end
                idx = idx + 1
            end
        end
    end)

    table.sort(raidQueue, function(a, b)
        if (a.priority or 1) ~= (b.priority or 1) then
            return (a.priority or 1) < (b.priority or 1)
        end
        if a.encounterID ~= b.encounterID then
            return a.encounterID < b.encounterID
        end
        if a.difficultyID ~= b.difficultyID then
            return a.difficultyID < b.difficultyID
        end
        return (a.kind or "") < (b.kind or "")
    end)

    -- Build a queue of work items so we can spread the EJ reads across frames
    -- instead of doing them all synchronously.
    local queue = {}
    -- Keep selected raid encounters first so raid overview has data quickly,
    -- even when the user opens EJ soon after login.
    for _, entry in ipairs(raidQueue) do
        if (entry.priority or 1) == 0 then
            queue[#queue + 1] = entry
        end
    end

    -- Then warm dungeons in smaller units to avoid bursty EJ work.
    for _, instanceID in ipairs(dungeonIDs) do
        queue[#queue + 1] = {
            kind = "dungeon-enriched",
            instanceID = instanceID,
            difficultyID = difficultyID,
            classID = classID,
            done = false,
        }
        queue[#queue + 1] = {
            kind = "dungeon-class",
            instanceID = instanceID,
            difficultyID = difficultyID,
            classID = classID,
        }
        for _, spec in ipairs(specs) do
            queue[#queue + 1] = {
                kind = "dungeon-spec",
                instanceID = instanceID,
                difficultyID = difficultyID,
                classID = spec.classID,
                specID = spec.specID,
            }
        end
    end

    -- Finally warm non-priority raid entries.
    for _, entry in ipairs(raidQueue) do
        if (entry.priority or 1) ~= 0 then
            queue[#queue + 1] = entry
        end
    end

    print("|cff66ccffVoidcoreAdvisor:|r Warming cache")

    -- Warmup-only tracking for raid-spec keys that repeatedly fail to cache
    -- after EJ interruption. These are treated as optional for warm completion.
    local warmSpecMissCount = {}
    local warmSpecSkip = {}
    local warmRaidClassMissCount = {}
    local warmRaidClassSkip = {}
    local warmDungeonMissCount = {}
    local warmDungeonSkip = {}

    local function IsWarmEntryCached(entry, warmSpecSkipTable, warmRaidClassSkipTable, warmDungeonSkipTable)
        if entry.kind == "raid-class" then
            local classKey = CacheKey("eic", entry.encounterID, entry.difficultyID, classID)
            if warmRaidClassSkipTable and warmRaidClassSkipTable[classKey] then
                return true
            end
            return _cache[classKey] ~= nil
        end

        if entry.kind == "raid-spec" then
            local specKey = CacheKey("eis", entry.encounterID, entry.difficultyID, entry.classID, entry.specID)
            if warmSpecSkipTable and warmSpecSkipTable[specKey] then
                return true
            end
            return _cache[specKey] ~= nil
        end

        if entry.kind == "dungeon-enriched" then
            -- Optional warm-only data; don't block completion on async item details.
            return entry.done == true
        end

        if entry.kind == "dungeon-class" then
            local classKey = CacheKey("iic", entry.instanceID, entry.difficultyID, entry.classID)
            if warmDungeonSkipTable and warmDungeonSkipTable[classKey] then
                return true
            end
            return _cache[classKey] ~= nil
        end

        if entry.kind == "dungeon-spec" then
            local specKey = CacheKey("iis", entry.instanceID, entry.difficultyID, entry.classID, entry.specID)
            if warmDungeonSkipTable and warmDungeonSkipTable[specKey] then
                return true
            end
            return _cache[specKey] ~= nil
        end

        local instanceID = entry.instanceID
        if warmDungeonSkipTable and warmDungeonSkipTable[instanceID] then
            return true
        end

        -- The "ii" key (enriched item data with names/icons) is NOT required here.
        -- It has a completeness check that can fail until item data loads from server.
        -- The class/spec ID-only caches (iic/iis) are what the overview and probability
        -- calculations actually need, and they succeed on the first pass.
        local iicKey = CacheKey("iic", instanceID, difficultyID, classID)
        if not _cache[iicKey] then
            return false
        end

        for _, spec in ipairs(specs) do
            local specKey = CacheKey("iis", instanceID, difficultyID, spec.classID, spec.specID)
            if not _cache[specKey] then
                return false
            end
        end

        return true
    end

    local idx = 0
    local pauseCycles = 0
    local warmStartTime = GetTime()
    local resumeCooldownUntil = 0
    local resumeRampUntil = 0
    local nextAllowedProcessTime = 0
    local function CompleteWarmPass()
        -- Completed one full pass through the queue. Check if everything cached.
        local allCached = LootPool.IsSeasonFilterReady()
        local uncachedEntries = {}
        for _, entry in ipairs(queue) do
            if not IsWarmEntryCached(entry, warmSpecSkip, warmRaidClassSkip, warmDungeonSkip) then
                allCached = false
                if entry.kind == "dungeon-class" then
                    uncachedEntries[#uncachedEntries + 1] = string.format("dungeon-class:I%d", entry.instanceID)
                elseif entry.kind == "dungeon-spec" then
                    uncachedEntries[#uncachedEntries + 1] = string.format("dungeon-spec:I%d:S%d", entry.instanceID, entry.specID)
                elseif entry.kind == "raid-spec" then
                    uncachedEntries[#uncachedEntries + 1] = string.format("raid-spec:E%d:D%d:S%d", entry.encounterID, entry.difficultyID, entry.specID)
                end
            end
        end

        if not allCached and #uncachedEntries > 0 then
            -- Intentionally silent: uncached detail list was debug-only.
        end

        if allCached then
            -- All cached! Done.
            _warmTicker:Cancel()
            _warmTicker = nil
            _warmInProgress = false
            _warmPausedByEJ = false
            _warmRetries = 0
            print("|cff66ccffVoidcoreAdvisor:|r Cache loaded and ready!")
        elseif _warmRetries < _maxWarmRetries then
            -- Not cached and retries remain. Restart the queue.
            _warmRetries = _warmRetries + 1
            idx = 0  -- Reset to loop again

            local hasUncachedItems = false
            for _, entry in ipairs(queue) do
                if not IsWarmEntryCached(entry, warmSpecSkip, warmRaidClassSkip, warmDungeonSkip) then
                    hasUncachedItems = true
                    break
                end
            end

            if hasUncachedItems then
                return  -- Will loop again next tick
            end
        else
            -- Max retries exceeded, give up
            _warmTicker:Cancel()
            _warmTicker = nil
            _warmInProgress = false
            _warmPausedByEJ = false
            print("|cff66ccffVoidcoreAdvisor:|r Cache warm abandoned")
        end

        RestorePlayerLootFilter()
        ReapplySavedWarmEJState()

        -- If the EJ is open and showing content, poke EJHook so the panel
        -- can appear now that the season filter / cache may have become ready.
        -- This handles the case where the player opened EJ during the warm
        -- window (e.g. first 2 s after login before item data was available).
        if LootPool.IsSeasonFilterReady() and VCA.EJHook and VCA.EJHook.TryReevaluate then
            VCA.EJHook.TryReevaluate()
        end
    end

    local function ProcessNext()
        if IsInInstance and IsInInstance() then
            if _warmTicker then
                _warmTicker:Cancel()
                _warmTicker = nil
            end
            _warmInProgress = false
            _warmPausedByEJ = false
            return
        end

        -- Never drive internal EJ navigation while the journal is visible.
        -- Otherwise the player can hear page-turn sounds and briefly see the
        -- UI flip as warm-cache SelectInstance/SelectEncounter calls run.
        if EncounterJournal and EncounterJournal:IsShown() then
            if not _warmPausedByEJ then
                _warmPausedByEJ = true
                pauseCycles = pauseCycles + 1
            end
            CaptureWarmEJState()
            return
        end

        if _warmPausedByEJ then
            _warmPausedByEJ = false

            -- Let the client settle after EJ closes, then ramp warmup back in.
            -- This avoids a burst of EJ reads on the first frame after resume.
            resumeCooldownUntil = GetTime() + 1.00
            resumeRampUntil = resumeCooldownUntil + 6.00
            nextAllowedProcessTime = resumeCooldownUntil
            return
        end

        _warmPausedByEJ = false

        local now = GetTime()
        if now < resumeCooldownUntil or now < nextAllowedProcessTime then
            return
        end

        -- If the last processed item finished a full queue pass, resolve that
        -- pass before incrementing again so we never run beyond #queue.
        if idx >= #queue then
            CompleteWarmPass()
            return
        end

        idx = idx + 1

        if idx > #queue then
            CompleteWarmPass()
            return
        end

        local entry = queue[idx]

        if entry.kind == "raid-class" then
            local classKey = CacheKey("eic", entry.encounterID, entry.difficultyID, classID)
            if _cache[classKey] ~= nil or warmRaidClassSkip[classKey] then
                return
            end

            LootPool.GetEncounterItemsForClass(entry.encounterID, entry.difficultyID, classID, entry.instanceID)

            if _cache[classKey] == nil then
                local missCount = (warmRaidClassMissCount[classKey] or 0) + 1
                warmRaidClassMissCount[classKey] = missCount
                if missCount >= 2 and not warmRaidClassSkip[classKey] then
                    warmRaidClassSkip[classKey] = true
                end
            end
            return
        end

        if entry.kind == "raid-spec" then
            local specKey = CacheKey("eis", entry.encounterID, entry.difficultyID, entry.classID, entry.specID)
            if _cache[specKey] ~= nil or warmSpecSkip[specKey] then
                return
            end

            -- Per-spec reads power both the raid boss panel and raid overview rankings.
            LootPool.GetEncounterItemsForSpec(
                entry.encounterID,
                entry.difficultyID,
                entry.classID,
                entry.specID,
                entry.instanceID
            )

            if _cache[specKey] == nil then
                local missCount = (warmSpecMissCount[specKey] or 0) + 1
                warmSpecMissCount[specKey] = missCount
                if missCount >= 1 and not warmSpecSkip[specKey] then
                    warmSpecSkip[specKey] = true
                end
            end
            return
        end

        if entry.kind == "dungeon-enriched" then
            if entry.done then
                return
            end

            -- Optional warm-only pass for names/icons. Never blocks completion.
            LootPool.GetInstanceItems(entry.instanceID, entry.difficultyID, entry.classID)
            entry.done = true
            return
        end

        if entry.kind == "dungeon-class" then
            local classKey = CacheKey("iic", entry.instanceID, entry.difficultyID, entry.classID)
            if _cache[classKey] ~= nil or warmDungeonSkip[classKey] then
                return
            end

            LootPool.GetInstanceItemsForClass(entry.instanceID, entry.difficultyID, entry.classID)

            if _cache[classKey] == nil then
                local missCount = (warmDungeonMissCount[classKey] or 0) + 1
                warmDungeonMissCount[classKey] = missCount
                if missCount >= 2 and not warmDungeonSkip[classKey] then
                    warmDungeonSkip[classKey] = true
                end
            end
            return
        end

        if entry.kind == "dungeon-spec" then
            local specKey = CacheKey("iis", entry.instanceID, entry.difficultyID, entry.classID, entry.specID)
            if _cache[specKey] ~= nil or warmDungeonSkip[specKey] then
                return
            end

            LootPool.GetInstanceItemsForSpec(entry.instanceID, entry.difficultyID, entry.classID, entry.specID)

            if _cache[specKey] == nil then
                local missCount = (warmDungeonMissCount[specKey] or 0) + 1
                warmDungeonMissCount[specKey] = missCount
                -- Treat repeatedly missing spec caches as optional warm entries.
                if missCount >= 2 and not warmDungeonSkip[specKey] then
                    warmDungeonSkip[specKey] = true
                end
            end
            return
        end
    end

    -- Process in a small time budget per tick to avoid frame spikes.
    local function ProcessBatch()
        local elapsedSinceStart = GetTime() - warmStartTime
        local maxItems = WARM_MAX_BATCH_ITEMS
        local budgetMs = WARM_BATCH_BUDGET_MS

        -- First-load ramp: start gently, then scale up.
        if elapsedSinceStart < 3.0 then
            maxItems = WARM_MIN_BATCH_ITEMS
        end

        if GetTime() < resumeRampUntil then
            maxItems = WARM_MIN_BATCH_ITEMS
            budgetMs = WARM_BATCH_BUDGET_MS_POST_EJ
        end

        local processed = 0
        local batchStartMs = debugprofilestop and debugprofilestop() or 0
        while processed < maxItems do
            ProcessNext()
            processed = processed + 1

            -- During post-EJ ramp, force a gap between heavy EJ reads to avoid
            -- frame spikes from back-to-back instance/encounter/filter changes.
            if GetTime() < resumeRampUntil then
                nextAllowedProcessTime = GetTime() + 0.20
            end

            -- Stop the batch early if ticker was cancelled inside ProcessNext
            if not _warmTicker then return end

            if debugprofilestop then
                local nowMs = debugprofilestop()
                if (nowMs - batchStartMs) >= budgetMs then
                    break
                end
            end
        end
    end
    _warmTicker = C_Timer.NewTicker(WARM_TICK_INTERVAL, ProcessBatch)
end
