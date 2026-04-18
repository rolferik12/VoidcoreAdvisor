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

local _seasonDungeonIDs   = {}   -- set: { [instanceID] = true }
local _seasonDungeonList  = {}   -- array of instanceIDs (for iteration)
local _seasonRaidIDs      = {}   -- set: { [instanceID] = true }
local _seasonFilterBuilt  = false

function LootPool.BuildSeasonFilter()
    wipe(_seasonDungeonIDs)
    wipe(_seasonDungeonList)
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

    _seasonFilterBuilt = true
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

-- Temporarily sets EJ difficulty + loot filter, runs fn(), then restores the
-- original values.  fn() receives no arguments.
local function WithEJState(difficultyID, classID, specID, fn)
    local origDifficulty           = EJ_GetDifficulty()
    local origClassID, origSpecID  = EJ_GetLootFilter()

    LootPool._reentryGuard = true
    EJ_SetDifficulty(difficultyID)
    EJ_SetLootFilter(classID or 0, specID or 0)

    local ok, err = xpcall(fn, function(e)
        return e .. "\n" .. debugstack()
    end)

    -- Always restore regardless of error.
    EJ_SetDifficulty(origDifficulty or difficultyID)
    EJ_SetLootFilter(origClassID or 0, origSpecID or 0)
    LootPool._reentryGuard = false

    if not ok then
        local handler = geterrorhandler()
        if handler then
            pcall(handler, "VoidcoreAdvisor/LootPool: " .. tostring(err))
        end
    end
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
        EJ_SelectEncounter(encounterID)
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
function LootPool.GetEncounterItemsForSpec(encounterID, difficultyID, classID, specID)
    local key = CacheKey("eis", encounterID, difficultyID, classID, specID)
    if _cache[key] then return _cache[key] end

    local itemIDs = {}
    WithEJState(difficultyID, classID, specID, function()
        EJ_SelectEncounter(encounterID)
        local numLoot = EJ_GetNumLoot()
        for i = 1, numLoot do
            local info = C_EncounterJournal.GetLootInfoByIndex(i)
            if info and info.itemID and info.itemID > 0 and IsGearOrWeapon(info.itemID) then
                itemIDs[#itemIDs + 1] = info.itemID
            end
        end
    end)

    _cache[key] = itemIDs
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
        EJ_SelectInstance(instanceID)
        local idx = 1
        while true do
            local name, _, encounterID = EJ_GetEncounterInfoByIndex(idx)
            if not name then break end
            EJ_SelectEncounter(encounterID)
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
        EJ_SelectInstance(instanceID)
        local idx = 1
        while true do
            local name, _, encounterID = EJ_GetEncounterInfoByIndex(idx)
            if not name then break end
            EJ_SelectEncounter(encounterID)
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

    _cache[key] = itemIDs
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
function LootPool.GetEncounterItemsForClass(encounterID, difficultyID, classID)
    local key = CacheKey("eic", encounterID, difficultyID, classID)
    if _cache[key] then return _cache[key] end

    local itemIDs = {}
    WithEJState(difficultyID, classID, 0, function()
        EJ_SelectEncounter(encounterID)
        local numLoot = EJ_GetNumLoot()
        for i = 1, numLoot do
            local info = C_EncounterJournal.GetLootInfoByIndex(i)
            if info and info.itemID and info.itemID > 0 and IsGearOrWeapon(info.itemID) then
                itemIDs[#itemIDs + 1] = info.itemID
            end
        end
    end)

    _cache[key] = itemIDs
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
        EJ_SelectInstance(instanceID)
        local idx = 1
        while true do
            local name, _, encounterID = EJ_GetEncounterInfoByIndex(idx)
            if not name then break end
            EJ_SelectEncounter(encounterID)
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

    _cache[key] = itemIDs
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

-- ── Cache warmup ──────────────────────────────────────────────────────────────
-- Pre-scans all current-season dungeons × all player specs at login so that
-- Panel.Show() is instant.  Retries up to _maxWarmRetries if item data is
-- missing (client hasn't cached it yet from the server).

local _warmRetries    = 0
local _maxWarmRetries = 5
local _warmTicker     = nil  -- handle for in-progress warm ticker

function LootPool.WarmCache()
    EnsureSeasonFilter()

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

    -- Build a queue of work items — one per dungeon — so we can spread the
    -- EJ reads across frames instead of doing them all synchronously.
    local queue = {}
    for _, instanceID in ipairs(dungeonIDs) do
        queue[#queue + 1] = instanceID
    end

    local idx = 0
    local function ProcessNext()
        idx = idx + 1
        if idx > #queue then
            _warmTicker:Cancel()
            _warmTicker = nil

            -- Check if every dungeon class-wide read was cached (complete data).
            local allCached = true
            for _, instanceID in ipairs(dungeonIDs) do
                local key = CacheKey("ii", instanceID, difficultyID, classID, 0)
                if not _cache[key] then
                    allCached = false
                    break
                end
            end

            if not allCached and _warmRetries < _maxWarmRetries then
                _warmRetries = _warmRetries + 1
                C_Timer.After(_warmRetries * 2, function()
                    LootPool.WarmCache()
                end)
            end
            return
        end

        local instanceID = queue[idx]

        -- Class-wide read (used by PopulateItemColumn)
        LootPool.GetInstanceItems(instanceID, difficultyID, classID)

        -- Class-wide itemID set (used by Detection.GetActivePoolSet)
        LootPool.GetInstanceItemsForClass(instanceID, difficultyID, classID)

        -- Per-spec reads (used by Probability)
        for _, spec in ipairs(specs) do
            LootPool.GetInstanceItemsForSpec(instanceID, difficultyID, spec.classID, spec.specID)
        end
    end

    -- Process one dungeon per frame (ticker interval 0 = next frame).
    _warmTicker = C_Timer.NewTicker(0, ProcessNext, #queue + 1)
end
