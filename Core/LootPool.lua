-- VoidcoreAdvisor: LootPool
-- Reads loot tables from the Encounter Journal for a given source and spec.
-- The EJ filter and difficulty state is saved before each read and fully
-- restored afterwards so normal EJ browsing is not disturbed.
--
-- NOTE: EJ_SelectInstance / EJ_SelectEncounter change global EJ state.
-- Callers should avoid calling these functions while the EJ frame is animating
-- a page transition (i.e. during an OnShow / OnHide handler).

local _, VCA = ...

VCA.LootPool = {}
local LootPool = VCA.LootPool

-- Set to true while pool reads are in progress so EJHook ignores our internal
-- EJ_SelectEncounter / EJ_SelectInstance calls.
LootPool._reentryGuard = false

-- ── Result cache ──────────────────────────────────────────────────────────────
-- Keyed by "fnTag:arg1:arg2:…" → cached return value.  Invalidated on season
-- change (CHALLENGE_MODE_MAPS_UPDATE).

local _cache = {}

local function CacheKey(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...) or 0)
    end
    return table.concat(parts, ":")
end

function LootPool.InvalidateCache()
    wipe(_cache)
end

-- ── Season filter ─────────────────────────────────────────────────────────────
-- Determines which EJ instanceIDs belong to the current season.
-- Shared across LootPool (for warmup) and EJHook (for panel gating).

local _seasonDungeonIDs     = {}   -- set: { [instanceID] = true }
local _seasonDungeonList    = {}   -- array of instanceIDs (for iteration)
local _seasonDungeonByName  = {}   -- { [localizedName] = ejInstanceID }
local _seasonRaidIDs        = {}   -- set: { [instanceID] = true }
local _seasonFilterBuilt    = false

function LootPool.BuildSeasonFilter()
    wipe(_seasonDungeonIDs)
    wipe(_seasonDungeonList)
    wipe(_seasonDungeonByName)
    wipe(_seasonRaidIDs)

    if not EncounterJournal then
        if EncounterJournal_LoadUI then
            EncounterJournal_LoadUI()
        end
    end

    -- M+ dungeons: match challenge-mode map names to EJ instanceIDs
    local dungeonNameSet = {}
    if C_ChallengeMode and C_ChallengeMode.GetMapTable then
        local mapIDs = C_ChallengeMode.GetMapTable()
        if mapIDs then
            for _, mapID in ipairs(mapIDs) do
                local name = C_ChallengeMode.GetMapUIInfo(mapID)
                if name then
                    dungeonNameSet[name] = true
                end
            end
        end
    end

    -- Walk the latest EJ tier to find matching dungeon instanceIDs
    local numTiers = EJ_GetNumTiers()
    if numTiers and numTiers > 0 then
        local savedTier = EJ_GetCurrentTier()
        EJ_SelectTier(numTiers)

        -- Dungeons (isRaid = false)
        local idx = 1
        while true do
            local instanceID, name = EJ_GetInstanceByIndex(idx, false)
            if not instanceID then break end
            if name and dungeonNameSet[name] then
                _seasonDungeonIDs[instanceID] = true
                _seasonDungeonList[#_seasonDungeonList + 1] = instanceID
                _seasonDungeonByName[name] = instanceID
            end
            idx = idx + 1
        end

        -- Raids (isRaid = true)
        idx = 1
        while true do
            local instanceID = EJ_GetInstanceByIndex(idx, true)
            if not instanceID then break end
            _seasonRaidIDs[instanceID] = true
            idx = idx + 1
        end

        if savedTier and savedTier > 0 then
            EJ_SelectTier(savedTier)
        end
    end

    -- Only mark as built if we actually found dungeon data.  If the
    -- C_ChallengeMode tables weren't ready yet (common during early login
    -- or zone transitions), EnsureSeasonFilter() will retry on next access.
    if #_seasonDungeonList > 0 or next(_seasonRaidIDs) then
        _seasonFilterBuilt = true
    end
end

local function EnsureSeasonFilter()
    if not _seasonFilterBuilt then
        LootPool.BuildSeasonFilter()
    end
end

function LootPool.IsCurrentSeasonDungeon(instanceID)
    EnsureSeasonFilter()
    return _seasonDungeonIDs[instanceID] == true
end

-- Returns the EJ instanceID for a season dungeon given its localized name,
-- or nil if the name does not match any current-season dungeon.
function LootPool.GetSeasonDungeonByName(name)
    EnsureSeasonFilter()
    return _seasonDungeonByName[name]
end

function LootPool.IsCurrentSeasonRaid(instanceID)
    EnsureSeasonFilter()
    return _seasonRaidIDs[instanceID] == true
end

-- Returns the ordered array of current-season dungeon EJ instanceIDs.
function LootPool.GetSeasonDungeonInstanceIDs()
    EnsureSeasonFilter()
    return _seasonDungeonList
end

-- ── EJ state save/restore ─────────────────────────────────────────────────────

-- Active filter state — set during WithEJState so that SelectInstance /
-- SelectEncounter can re-apply the filter after each EJ navigation call.
-- EJ_SelectInstance / EJ_SelectEncounter can internally reset the difficulty,
-- tier, and loot filter, so we must re-apply after every call.
local _activeDifficultyID = nil
local _activeTierID       = nil
local _activeClassID      = nil
local _activeSpecID       = nil

local function ReapplyEJFilter()
    if _activeTierID then
        EJ_SelectTier(_activeTierID)
    end
    if _activeDifficultyID then
        EJ_SetDifficulty(_activeDifficultyID)
    end
    EJ_SetLootFilter(_activeClassID or 0, _activeSpecID or 0)
end

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

-- Snapshot the player's current EJ page so warm-cache navigation can restore it
-- after finishing. This is only captured while EJ is visible to the player.
local _savedWarmEJState = nil

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

-- Wrappers that re-apply the filter after each EJ navigation call.
local function SelectInstance(instanceID)
    EJ_SelectInstance(instanceID)
    ReapplyEJFilter()
end

local function SelectEncounter(encounterID)
    EJ_SelectEncounter(encounterID)
    ReapplyEJFilter()
end

-- Temporarily sets EJ difficulty + loot filter, runs fn(), then restores the
-- original values.  fn() receives no arguments.  Inside fn(), use the module-
-- local SelectInstance / SelectEncounter instead of the raw EJ_Select* APIs
-- so the filter is automatically re-applied after each navigation call.
local function WithEJState(difficultyID, classID, specID, fn)
    local origDifficulty           = EJ_GetDifficulty()
    local origClassID, origSpecID  = EJ_GetLootFilter()
    local origTier                 = EJ_GetCurrentTier()

    -- Always select the latest tier before setting filters.  On first load
    -- the EJ may default to tier 1 which can cause EJ_SetLootFilter to
    -- silently fail, returning unfiltered (all-class) results.
    local latestTier = EJ_GetNumTiers()

    -- Store active filter so SelectInstance / SelectEncounter can re-apply.
    _activeDifficultyID = difficultyID
    _activeTierID       = latestTier
    _activeClassID      = classID or 0
    _activeSpecID       = specID or 0

    LootPool._reentryGuard = true
    if latestTier and latestTier > 0 then
        EJ_SelectTier(latestTier)
    end
    EJ_SetDifficulty(difficultyID)
    EJ_SetLootFilter(classID or 0, specID or 0)

    -- Verify the loot filter actually took effect.  If the EJ hasn't fully
    -- initialised yet the filter can silently fail, causing all-class items
    -- to be returned and cached as if they were class-filtered.
    local actualClass, actualSpec = EJ_GetLootFilter()
    local filterOK = (actualClass == (classID or 0)) and (actualSpec == (specID or 0))

    local ok, err = true, nil
    if filterOK then
        ok, err = xpcall(fn, function(e)
            return e .. "\n" .. debugstack()
        end)
    end

    -- Always restore regardless of error.
    _activeDifficultyID = nil
    _activeTierID       = nil
    _activeClassID      = nil
    _activeSpecID       = nil

    if origTier and origTier > 0 then
        EJ_SelectTier(origTier)
    end
    EJ_SetDifficulty(origDifficulty or difficultyID)
    EJ_SetLootFilter(origClassID or 0, origSpecID or 0)
    LootPool._reentryGuard = false

    if not ok then
        local handler = geterrorhandler()
        if handler then
            pcall(handler, "VoidcoreAdvisor/LootPool: " .. tostring(err))
        end
    end

    return filterOK and ok
end

-- ── Low-level EJ read ─────────────────────────────────────────────────────────

-- Returns true when itemID is armor (classID 4) or a weapon (classID 2).
-- Uses GetItemInfoInstant which is synchronous and needs no server query.
local function IsGearOrWeapon(itemID)
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    return classID == 2 or classID == 4
end

-- Collects all loot items for the currently selected encounter under the
-- current EJ filter.  Caller is responsible for setting the encounter first.
-- Non-equippable items (tokens, crafting reagents, etc.) are excluded.
-- Returns an array of:
--   { itemID, name, link, icon, slot, armorType }
local function CollectLootForSelectedEncounter()
    local items = {}
    local numLoot = EJ_GetNumLoot()
    for i = 1, numLoot do
        local info = C_EncounterJournal.GetLootInfoByIndex(i)
        if info and info.itemID and info.itemID > 0 and IsGearOrWeapon(info.itemID) then
            items[#items + 1] = {
                itemID    = info.itemID,
                name      = info.name      or "",
                link      = info.link      or "",
                icon      = info.icon      or "",
                slot      = info.slot      or "",
                armorType = info.armorType or "",
            }
        end
    end
    return items
end

-- ── Public: per-encounter reads ───────────────────────────────────────────────

-- Returns all loot items for a single raid boss encounter at a given difficulty.
-- Optional classID/specID filter the results (0 = no filter for that axis).
--
-- encounterID  : EJ journal encounter ID
-- difficultyID : EJ difficulty ID (use VCA.Difficulty constants)
-- classID      : (optional) numeric class ID, default 0 (all classes)
-- specID       : (optional) numeric specialization ID, default 0 (all specs)
-- Returns: array of item tables (see CollectLootForSelectedEncounter)
function LootPool.GetEncounterItems(encounterID, difficultyID, classID, specID)
    local key = CacheKey("ei", encounterID, difficultyID, classID or 0, specID or 0)
    if _cache[key] then return _cache[key] end

    local items = {}
    WithEJState(difficultyID, classID or 0, specID or 0, function()
        SelectEncounter(encounterID)
        items = CollectLootForSelectedEncounter()
    end)

    if #items > 0 then _cache[key] = items end
    return items
end

-- Returns item IDs visible to a specific class/spec for a single encounter.
-- Only items the Voidcore can grant to that spec are included.
--
-- encounterID  : EJ journal encounter ID
-- difficultyID : EJ difficulty ID
-- classID      : numeric class ID
-- specID       : numeric specialization ID
-- Returns: array of itemID numbers
function LootPool.GetEncounterItemsForSpec(encounterID, difficultyID, classID, specID, instanceID)
    local key = CacheKey("eis", encounterID, difficultyID, classID, specID)
    if _cache[key] then return _cache[key] end

    local itemIDs = {}
    local readOK = WithEJState(difficultyID, classID, specID, function()
        if instanceID then SelectInstance(instanceID) end
        SelectEncounter(encounterID)
        local numLoot = EJ_GetNumLoot()
        for i = 1, numLoot do
            local info = C_EncounterJournal.GetLootInfoByIndex(i)
            if info and info.itemID and info.itemID > 0 and IsGearOrWeapon(info.itemID) then
                itemIDs[#itemIDs + 1] = info.itemID
            end
        end
    end)

    -- Cross-validate: per-spec items must be a subset of the class-wide pool.
    -- If the spec filter silently failed, it returns all-class items which
    -- would NOT be a subset of the class pool. This catches that case.
    -- Note: do NOT gate on GetEncounterItems(0,0) — EJ_SetLootFilter(0,0) is
    -- invalid (class 0 doesn't exist) and always returns 0 items, blocking caching.
    if readOK then
        local classItems = LootPool.GetEncounterItemsForClass(encounterID, difficultyID, classID)
        -- classItems being cached (non-nil from prior raid-class warm) confirms EJ data loaded.
        if _cache[CacheKey("eic", encounterID, difficultyID, classID)] ~= nil then
            if #classItems == 0 then
                -- No gear for this class on this boss — valid empty result, cache it.
                _cache[key] = itemIDs
            else
                local classSet = {}
                for _, id in ipairs(classItems) do classSet[id] = true end
                local isSubset = true
                for _, id in ipairs(itemIDs) do
                    if not classSet[id] then
                        isSubset = false
                        break
                    end
                end
                if isSubset then
                    _cache[key] = itemIDs
                end
            end
        end
    end
    return itemIDs
end

-- ── Public: per-instance reads (M+ dungeons) ─────────────────────────────────

-- Returns all loot items for an entire dungeon instance at a given difficulty.
-- Optional classID/specID filter the results (0 = no filter for that axis).
-- Items are deduplicated across encounters because M+ can award any item from
-- any boss in the dungeon.
--
-- instanceID   : EJ instance ID
-- difficultyID : EJ difficulty ID (VCA.MythicPlusEJDifficulty for M+)
-- classID      : (optional) numeric class ID, default 0 (all classes)
-- specID       : (optional) numeric specialization ID, default 0 (all specs)
-- Returns:
--   {
--     all         = item[]   -- flat deduplicated list
--     byEncounter = { [encounterID] = item[] }
--   }
function LootPool.GetInstanceItems(instanceID, difficultyID, classID, specID)
    local key = CacheKey("ii", instanceID, difficultyID, classID or 0, specID or 0)
    if _cache[key] then return _cache[key] end

    local result = { all = {}, byEncounter = {} }
    local seen   = {}

    WithEJState(difficultyID, classID or 0, specID or 0, function()
        SelectInstance(instanceID)
        local idx = 1
        while true do
            local name, _, encounterID = EJ_GetEncounterInfoByIndex(idx)
            if not name then break end
            SelectEncounter(encounterID)
            local items = CollectLootForSelectedEncounter()
            result.byEncounter[encounterID] = items
            for _, item in ipairs(items) do
                if not seen[item.itemID] then
                    seen[item.itemID] = true
                    result.all[#result.all + 1] = item
                end
            end
            idx = idx + 1
        end
    end)

    -- Only cache if item data looks complete (names + icons loaded).
    local complete = true
    for _, item in ipairs(result.all) do
        if item.name == "" or item.icon == "" then
            complete = false
            -- Prime the client item cache so a retry succeeds.
            if GetItemInfo then GetItemInfo(item.itemID) end
        end
    end
    if #result.all > 0 and complete then
        _cache[key] = result
    end

    return result
end

-- Returns item IDs visible to a specific class/spec across an entire instance.
-- Used for M+ pool size calculation.
--
-- instanceID   : EJ instance ID
-- difficultyID : EJ difficulty ID
-- classID      : numeric class ID
-- specID       : numeric specialization ID
-- Returns: array of itemID numbers (deduplicated)
function LootPool.GetInstanceItemsForSpec(instanceID, difficultyID, classID, specID)
    local key = CacheKey("iis", instanceID, difficultyID, classID, specID)
    if _cache[key] then return _cache[key] end

    local itemIDSet = {}
    WithEJState(difficultyID, classID, specID, function()
        SelectInstance(instanceID)
        local idx = 1
        while true do
            local name, _, encounterID = EJ_GetEncounterInfoByIndex(idx)
            if not name then break end
            SelectEncounter(encounterID)
            local numLoot = EJ_GetNumLoot()
            for i = 1, numLoot do
                local info = C_EncounterJournal.GetLootInfoByIndex(i)
                if info and info.itemID and info.itemID > 0 and IsGearOrWeapon(info.itemID) then
                    itemIDSet[info.itemID] = true
                end
            end
            idx = idx + 1
        end
    end)

    local itemIDs = {}
    for id in pairs(itemIDSet) do
        itemIDs[#itemIDs + 1] = id
    end

    -- Cross-validate: per-spec items must be a subset of the class-wide pool.
    -- If the spec filter silently failed, the result will match the class-wide
    -- count rather than a proper subset.  Do not cache so the retry fixes it.
    if #itemIDs > 0 then
        local classItems = LootPool.GetInstanceItemsForClass(instanceID, difficultyID, classID)
        if #classItems > 0 then
            local classSet = {}
            for _, id in ipairs(classItems) do classSet[id] = true end
            local isSubset = true
            for _, id in ipairs(itemIDs) do
                if not classSet[id] then
                    isSubset = false
                    break
                end
            end
            if isSubset then
                _cache[key] = itemIDs
            end
        end
    end
    return itemIDs
end

-- ── Public: class-wide reads (all specs) ──────────────────────────────────────

-- Returns item IDs visible to ANY spec of a class for a single encounter.
-- Uses EJ_SetLootFilter(classID, 0) which the EJ treats as "all specializations".
--
-- encounterID  : EJ journal encounter ID
-- difficultyID : EJ difficulty ID
-- classID      : numeric class ID
-- Returns: array of itemID numbers
function LootPool.GetEncounterItemsForClass(encounterID, difficultyID, classID, instanceID)
    local key = CacheKey("eic", encounterID, difficultyID, classID)
    if _cache[key] then return _cache[key] end

    local itemIDs = {}
    local readOK = WithEJState(difficultyID, classID, 0, function()
        if instanceID then SelectInstance(instanceID) end
        SelectEncounter(encounterID)
        local numLoot = EJ_GetNumLoot()
        for i = 1, numLoot do
            local info = C_EncounterJournal.GetLootInfoByIndex(i)
            if info and info.itemID and info.itemID > 0 and IsGearOrWeapon(info.itemID) then
                itemIDs[#itemIDs + 1] = info.itemID
            end
        end
    end)

    if readOK then
        -- readOK guarantees EJ_SetLootFilter verified successfully, so the result
        -- is trustworthy even if empty (class simply has no gear on this boss).
        _cache[key] = itemIDs
    end
    return itemIDs
end

-- Returns item IDs visible to ANY spec of a class across an entire instance.
-- Deduplicated across encounters.
--
-- instanceID   : EJ instance ID
-- difficultyID : EJ difficulty ID
-- classID      : numeric class ID
-- Returns: array of itemID numbers (deduplicated)
function LootPool.GetInstanceItemsForClass(instanceID, difficultyID, classID)
    local key = CacheKey("iic", instanceID, difficultyID, classID)
    if _cache[key] then return _cache[key] end

    local itemIDSet = {}
    WithEJState(difficultyID, classID, 0, function()
        SelectInstance(instanceID)
        local idx = 1
        while true do
            local name, _, encounterID = EJ_GetEncounterInfoByIndex(idx)
            if not name then break end
            SelectEncounter(encounterID)
            local numLoot = EJ_GetNumLoot()
            for i = 1, numLoot do
                local info = C_EncounterJournal.GetLootInfoByIndex(i)
                if info and info.itemID and info.itemID > 0 and IsGearOrWeapon(info.itemID) then
                    itemIDSet[info.itemID] = true
                end
            end
            idx = idx + 1
        end
    end)

    local itemIDs = {}
    for id in pairs(itemIDSet) do
        itemIDs[#itemIDs + 1] = id
    end

    if #itemIDs > 0 then _cache[key] = itemIDs end
    return itemIDs
end

-- ── Public: unified dispatch ──────────────────────────────────────────────────

-- Dispatches to the correct Get*ItemsForSpec function based on content type.
-- Use this when callers have a VCA.ContentType value and don't want to branch.
--
-- sourceType   : VCA.ContentType.RAID or VCA.ContentType.MYTHIC_PLUS
-- sourceID     : encounterID (RAID) or instanceID (MYTHIC_PLUS)
-- difficultyID : EJ difficulty ID
-- classID      : numeric class ID
-- specID       : numeric specialization ID
-- Returns: array of itemID numbers
function LootPool.GetItemsForSpec(sourceType, sourceID, difficultyID, classID, specID)
    if sourceType == VCA.ContentType.RAID then
        return LootPool.GetEncounterItemsForSpec(sourceID, difficultyID, classID, specID)
    else
        return LootPool.GetInstanceItemsForSpec(sourceID, difficultyID, classID, specID)
    end
end

-- Dispatches to the correct Get*ItemsForClass function based on content type.
--
-- sourceType   : VCA.ContentType.RAID or VCA.ContentType.MYTHIC_PLUS
-- sourceID     : encounterID (RAID) or instanceID (MYTHIC_PLUS)
-- difficultyID : EJ difficulty ID
-- classID      : numeric class ID
-- Returns: array of itemID numbers
function LootPool.GetItemsForClass(sourceType, sourceID, difficultyID, classID)
    if sourceType == VCA.ContentType.RAID then
        return LootPool.GetEncounterItemsForClass(sourceID, difficultyID, classID)
    else
        return LootPool.GetInstanceItemsForClass(sourceID, difficultyID, classID)
    end
end

function LootPool.GetCachedItemsForClass(sourceType, sourceID, difficultyID, classID)
    local key
    if sourceType == VCA.ContentType.RAID then
        key = CacheKey("eic", sourceID, difficultyID, classID)
    else
        key = CacheKey("iic", sourceID, difficultyID, classID)
    end
    return _cache[key]
end

function LootPool.GetCachedItemsForSpec(sourceType, sourceID, difficultyID, classID, specID)
    local key
    if sourceType == VCA.ContentType.RAID then
        key = CacheKey("eis", sourceID, difficultyID, classID, specID)
    else
        key = CacheKey("iis", sourceID, difficultyID, classID, specID)
    end
    return _cache[key]
end

-- ── Cache warmup ──────────────────────────────────────────────────────────────
-- Pre-scans all current-season dungeons × all player specs at login so that
-- Panel.Show() is instant, and also warms current-season raid encounter loot
-- pools for every player spec so raid boss/overview views do not stall on
-- their first EJ open. Retries up to _maxWarmRetries if season or item data
-- is missing (client / EJ data not ready yet).

local _warmRetries    = 0
local _maxWarmRetries = 5
local _warmTicker     = nil  -- handle for in-progress warm ticker
local _warmInProgress = false
local _warmPausedByEJ = false

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

function LootPool.WarmCache()
    EnsureSeasonFilter()
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

    WithEJState(VCA.Difficulty.RAID_NORMAL, 0, 0, function()
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

    -- Then warm dungeons as before.
    for _, instanceID in ipairs(dungeonIDs) do
        queue[#queue + 1] = {
            kind = "dungeon",
            instanceID = instanceID,
        }
    end

    -- Finally warm non-priority raid entries.
    for _, entry in ipairs(raidQueue) do
        if (entry.priority or 1) ~= 0 then
            queue[#queue + 1] = entry
        end
    end

    print(string.format("|cff66ccffVoidcoreAdvisor:|r [%.1f] Warming cache: %d raid entries, %d dungeons (%.1f queue items total)",
        GetTime(), #raidQueue, #dungeonIDs, #queue))

    -- Warmup-only tracking for raid-spec keys that repeatedly fail to cache
    -- after EJ interruption. These are treated as optional for warm completion.
    local warmSpecMissCount = {}
    local warmSpecSkip = {}

    local function IsWarmEntryCached(entry, warmSpecSkipTable)
        if entry.kind == "raid-class" then
            local classKey = CacheKey("eic", entry.encounterID, entry.difficultyID, classID)
            return _cache[classKey] ~= nil
        end

        if entry.kind == "raid-spec" then
            local specKey = CacheKey("eis", entry.encounterID, entry.difficultyID, entry.classID, entry.specID)
            if warmSpecSkipTable and warmSpecSkipTable[specKey] then
                return true
            end
            return _cache[specKey] ~= nil
        end

        local instanceID = entry.instanceID
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
    local resumeCooldownUntil = 0
    local resumeRampUntil = 0
    local nextAllowedProcessTime = 0
    local function CompleteWarmPass()
        -- Completed one full pass through the queue. Check if everything cached.
        local allCached = _seasonFilterBuilt == true
        local uncachedEntries = {}
        for _, entry in ipairs(queue) do
            if not IsWarmEntryCached(entry, warmSpecSkip) then
                allCached = false
                if entry.kind == "dungeon" then
                    uncachedEntries[#uncachedEntries + 1] = string.format("dungeon:%d", entry.instanceID)
                elseif entry.kind == "raid-spec" then
                    uncachedEntries[#uncachedEntries + 1] = string.format("raid-spec:E%d:D%d:S%d", entry.encounterID, entry.difficultyID, entry.specID)
                end
            end
        end

        if not allCached and #uncachedEntries > 0 then
            -- Print up to 10 uncached entries so the log isn't flooded
            local preview = {}
            for i = 1, math.min(10, #uncachedEntries) do preview[i] = uncachedEntries[i] end
            local suffix = #uncachedEntries > 10 and string.format(" (+%d more)", #uncachedEntries - 10) or ""
            print(string.format("|cff66ccffVoidcoreAdvisor:|r [%.1f] Still uncached (%d): %s%s",
                GetTime(), #uncachedEntries, table.concat(preview, ", "), suffix))
        end

        if allCached then
            -- All cached! Done.
            _warmTicker:Cancel()
            _warmTicker = nil
            _warmInProgress = false
            _warmPausedByEJ = false
            _warmRetries = 0
            print(string.format("|cff66ccffVoidcoreAdvisor:|r [%.1f] Cache loaded and ready!", GetTime()))
        elseif _warmRetries < _maxWarmRetries then
            -- Not cached and retries remain. Restart the queue.
            _warmRetries = _warmRetries + 1
            idx = 0  -- Reset to loop again

            local hasUncachedItems = false
            for _, entry in ipairs(queue) do
                if not IsWarmEntryCached(entry, warmSpecSkip) then
                    hasUncachedItems = true
                    break
                end
            end

            if hasUncachedItems then
                print(string.format("|cff66ccffVoidcoreAdvisor:|r [%.1f] Item data incomplete, restarting cache warm (attempt %d/%d)",
                    GetTime(), _warmRetries, _maxWarmRetries))
                return  -- Will loop again next tick
            end
        else
            -- Max retries exceeded, give up
            _warmTicker:Cancel()
            _warmTicker = nil
            _warmInProgress = false
            _warmPausedByEJ = false
            print(string.format("|cff66ccffVoidcoreAdvisor:|r [%.1f] Cache warm abandoned after max retries", GetTime()))
        end

        RestorePlayerLootFilter()
        ReapplySavedWarmEJState()

        -- If the EJ is open and showing content, poke EJHook so the panel
        -- can appear now that the season filter / cache may have become ready.
        -- This handles the case where the player opened EJ during the warm
        -- window (e.g. first 2 s after login before item data was available).
        if _seasonFilterBuilt and VCA.EJHook and VCA.EJHook.TryReevaluate then
            VCA.EJHook.TryReevaluate()
        end
    end

    local function ProcessNext()
        -- Never drive internal EJ navigation while the journal is visible.
        -- Otherwise the player can hear page-turn sounds and briefly see the
        -- UI flip as warm-cache SelectInstance/SelectEncounter calls run.
        if EncounterJournal and EncounterJournal:IsShown() then
            if not _warmPausedByEJ then
                _warmPausedByEJ = true
                pauseCycles = pauseCycles + 1
                print(string.format("|cff66ccffVoidcoreAdvisor:|r [%.1f] Cache warming paused while EJ open", GetTime()))
            end
            CaptureWarmEJState()
            return
        end

        if _warmPausedByEJ then
            print(string.format("|cff66ccffVoidcoreAdvisor:|r [%.1f] Cache warming resumed (paused %d times)", GetTime(), pauseCycles))
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
        
        -- Progress indicator every 50 items
        if idx > 0 and idx % 50 == 0 then
            print(string.format("|cff66ccffVoidcoreAdvisor:|r [%.1f] Warming cache: %d/%d items", GetTime(), idx, #queue))
        end
        
        if idx > #queue then
            CompleteWarmPass()
            return
        end

        local entry = queue[idx]

        if entry.kind == "raid-class" then
            LootPool.GetEncounterItemsForClass(entry.encounterID, entry.difficultyID, classID, entry.instanceID)
            return
        end

        if entry.kind == "raid-spec" then
            -- Per-spec reads power both the raid boss panel and raid overview rankings.
            LootPool.GetEncounterItemsForSpec(
                entry.encounterID,
                entry.difficultyID,
                entry.classID,
                entry.specID,
                entry.instanceID
            )

            local specKey = CacheKey("eis", entry.encounterID, entry.difficultyID, entry.classID, entry.specID)
            if _cache[specKey] == nil then
                local missCount = (warmSpecMissCount[specKey] or 0) + 1
                warmSpecMissCount[specKey] = missCount
                if missCount >= 1 and not warmSpecSkip[specKey] then
                    warmSpecSkip[specKey] = true
                    print(string.format(
                        "|cff66ccffVoidcoreAdvisor:|r [%.1f] Skipping unstable raid-spec warm key E%d D%d S%d after %d misses",
                        GetTime(), entry.encounterID, entry.difficultyID, entry.specID, missCount
                    ))
                end
            end
            return
        end

        local instanceID = entry.instanceID

        -- Attempt to cache enriched item data (names + icons). This has a completeness
        -- check and may not cache if item data isn't loaded from the server yet. That is
        -- OK — it will be fetched on demand when the panel opens. Don't gate the
        -- class/spec reads on its success.
        LootPool.GetInstanceItems(instanceID, difficultyID, classID)

        -- Class-wide itemID set (used by Detection.GetActivePoolSet)
        LootPool.GetInstanceItemsForClass(instanceID, difficultyID, classID)

        -- Per-spec reads (used by Probability)
        for _, spec in ipairs(specs) do
            LootPool.GetInstanceItemsForSpec(instanceID, difficultyID, spec.classID, spec.specID)
        end
    end

    -- Process multiple items per tick at a short interval to keep total warm time low
    -- without hammering every frame. 5 items per 0.05s tick = ~100 items/second.
    local ITEMS_PER_TICK = 5
    local function ProcessBatch()
        local itemsThisTick = ITEMS_PER_TICK
        if GetTime() < resumeRampUntil then
            itemsThisTick = 1
        end

        for _ = 1, itemsThisTick do
            ProcessNext()

            -- During post-EJ ramp, force a gap between heavy EJ reads to avoid
            -- frame spikes from back-to-back instance/encounter/filter changes.
            if GetTime() < resumeRampUntil then
                nextAllowedProcessTime = GetTime() + 0.20
            end

            -- Stop the batch early if ticker was cancelled inside ProcessNext
            if not _warmTicker then return end
        end
    end
    _warmTicker = C_Timer.NewTicker(0.05, ProcessBatch)
end
