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
local GetSeasonFingerprint
local PERSISTED_CACHE_VERSION = 16
local _itemSpecCache = {}

local HUNTER_CLASS_ID = 3
local _fallbackUniversalEquipLoc = {
    INVTYPE_NECK = true,
    INVTYPE_FINGER = true,
}
local _fallbackHunterEquipLoc = {
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
    -- Some hunter ranged weapons (notably guns) can resolve as generic
    -- weapon equip locations while item spec metadata is still warming.
    INVTYPE_WEAPON = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
}
local _fallbackDaggerClassID = {
    [4] = true,  -- Rogue
    [5] = true,  -- Priest
    [7] = true,  -- Shaman
    [8] = true,  -- Mage
    [9] = true,  -- Warlock
    [10] = true, -- Monk
    [11] = true, -- Druid
    [13] = true, -- Evoker
}
local DAGGER_SUBCLASS_ID = _G.LE_ITEM_WEAPON_DAGGER or 15

local _persistableCacheTags = {
    eic = true,
    eis = true,
    iic = true,
    iis = true,
}

local function CopyArray(source)
    local copy = {}
    for i = 1, #source do
        copy[i] = source[i]
    end
    return copy
end

local function GetPersistentCacheDB()
    local db = _G[VCA.CHAR_DB_NAME]
    if type(db) ~= "table" then return nil end

    if type(db.lootCache) ~= "table" then
        db.lootCache = {
            version = PERSISTED_CACHE_VERSION,
            fingerprint = nil,
            entries = {},
        }
    end

    local cacheDB = db.lootCache
    if cacheDB.version ~= PERSISTED_CACHE_VERSION then
        cacheDB.version = PERSISTED_CACHE_VERSION
        cacheDB.fingerprint = nil
        cacheDB.entries = {}
    elseif type(cacheDB.entries) ~= "table" then
        cacheDB.entries = {}
    end

    return cacheDB
end

local function PersistCacheEntry(key, value)
    local tag = key:match("^([^:]+):")
    if not _persistableCacheTags[tag] or type(value) ~= "table" then
        return
    end

    local cacheDB = GetPersistentCacheDB()
    if not cacheDB then return end

    cacheDB.entries[key] = CopyArray(value)
    if GetSeasonFingerprint then
        local fingerprint = GetSeasonFingerprint()
        if fingerprint and fingerprint ~= "" then
            cacheDB.fingerprint = fingerprint
        end
    end
end

local function ClearPersistedCache()
    local db = _G[VCA.CHAR_DB_NAME]
    if type(db) == "table" then
        db.lootCache = nil
    end
end

local function CacheKey(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...) or 0)
    end
    return table.concat(parts, ":")
end

function LootPool.InvalidateCache()
    wipe(_cache)
    ClearPersistedCache()
end

-- -- Season filter -------------------------------------------------------------
-- Determines which EJ instanceIDs belong to the current season.
-- Shared across LootPool (for warmup) and EJHook (for panel gating).

local _seasonDungeonIDs     = {}   -- set: { [instanceID] = true }
local _seasonDungeonList    = {}   -- array of instanceIDs (for iteration)
local _seasonDungeonByName  = {}   -- { [localizedName] = ejInstanceID }
local _seasonRaidIDs        = {}   -- set: { [instanceID] = true }
local _seasonFilterBuilt    = false

GetSeasonFingerprint = function()
    if not _seasonFilterBuilt then
        return nil
    end

    local parts = {}
    for _, instanceID in ipairs(_seasonDungeonList) do
        parts[#parts + 1] = "d" .. tostring(instanceID)
    end

    local raidIDs = {}
    for instanceID in pairs(_seasonRaidIDs) do
        raidIDs[#raidIDs + 1] = instanceID
    end
    table.sort(raidIDs)
    for _, instanceID in ipairs(raidIDs) do
        parts[#parts + 1] = "r" .. tostring(instanceID)
    end

    return table.concat(parts, ",")
end

local function SyncPersistedSeasonFingerprint()
    local cacheDB = GetPersistentCacheDB()
    if not cacheDB then return end

    local fingerprint = GetSeasonFingerprint()
    if not fingerprint or fingerprint == "" then return end

    if type(cacheDB.fingerprint) == "string"
       and cacheDB.fingerprint ~= ""
       and cacheDB.fingerprint ~= fingerprint
    then
        wipe(_cache)
        cacheDB.entries = {}
    end

    cacheDB.fingerprint = fingerprint
end

function LootPool.LoadPersistedCache()
    local cacheDB = GetPersistentCacheDB()
    if not cacheDB or type(cacheDB.entries) ~= "table" then
        return
    end

    local fingerprint = GetSeasonFingerprint()
    if fingerprint and fingerprint ~= "" then
        if type(cacheDB.fingerprint) == "string"
           and cacheDB.fingerprint ~= ""
           and cacheDB.fingerprint ~= fingerprint
        then
            cacheDB.entries = {}
            cacheDB.fingerprint = fingerprint
            return
        end
        cacheDB.fingerprint = fingerprint
    end

    for key, itemIDs in pairs(cacheDB.entries) do
        local tag = key:match("^([^:]+):")
        if _persistableCacheTags[tag] and type(itemIDs) == "table" then
            _cache[key] = CopyArray(itemIDs)
        end
    end
end

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
        SyncPersistedSeasonFingerprint()
    end
end

local function EnsureSeasonFilter()
    if not _seasonFilterBuilt then
        LootPool.BuildSeasonFilter()
    end
end

function LootPool.IsSeasonFilterReady()
    return _seasonFilterBuilt == true
end

function LootPool.GetCachedSeasonDungeonByName(name)
    return _seasonDungeonByName[name]
end

function LootPool.GetCachedSeasonDungeonInstanceIDs()
    return _seasonDungeonList
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
local _activeUseLootFilter = false

local function ReapplyEJFilter()
    if _activeTierID then
        EJ_SelectTier(_activeTierID)
    end
    if _activeDifficultyID then
        EJ_SetDifficulty(_activeDifficultyID)
    end
    if _activeUseLootFilter then
        EJ_SetLootFilter(_activeClassID or 0, _activeSpecID or 0)
    end
end

local function ResolveEncounterInstanceID(encounterID)
    if not encounterID or encounterID == 0 then
        return nil
    end

    local _, _, _, _, _, instanceID = EJ_GetEncounterInfo(encounterID)
    if instanceID and instanceID > 0 then
        return instanceID
    end

    return nil
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
    local useLootFilter            = classID ~= nil or specID ~= nil

    -- Always select the latest tier before setting filters.  On first load
    -- the EJ may default to tier 1 which can cause EJ_SetLootFilter to
    -- silently fail, returning unfiltered (all-class) results.
    local latestTier = EJ_GetNumTiers()

    -- Store active filter so SelectInstance / SelectEncounter can re-apply.
    _activeDifficultyID = difficultyID
    _activeTierID       = latestTier
    _activeClassID      = classID or 0
    _activeSpecID       = specID or 0
    _activeUseLootFilter = useLootFilter

    LootPool._reentryGuard = true
    if latestTier and latestTier > 0 then
        EJ_SelectTier(latestTier)
    end
    EJ_SetDifficulty(difficultyID)
    if useLootFilter then
        EJ_SetLootFilter(classID or 0, specID or 0)
    end

    -- Verify the loot filter actually took effect.  If the EJ hasn't fully
    -- initialised yet the filter can silently fail, causing all-class items
    -- to be returned and cached as if they were class-filtered.
    local filterOK = true
    if useLootFilter then
        local actualClass, actualSpec = EJ_GetLootFilter()
        filterOK = (actualClass == (classID or 0)) and (actualSpec == (specID or 0))
    end

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
    _activeUseLootFilter = false

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

local function GetItemEligibleSpecSet(itemID)
    local cached = _itemSpecCache[itemID]
    if cached ~= nil then
        return cached, true
    end

    local specInfo

    if C_Item and C_Item.GetItemSpecInfo then
        specInfo = C_Item.GetItemSpecInfo(itemID)
    elseif GetItemSpecInfo then
        specInfo = GetItemSpecInfo(itemID)
    end

    if type(specInfo) == "table" then
        -- Some universally-eligible items can report an empty spec list. Treat
        -- this as "all player specs" only once item data is actually loaded;
        -- otherwise treat as not-ready to avoid caching transient empty results.
        if #specInfo == 0 then
            local itemName
            if C_Item and C_Item.GetItemNameByID then
                itemName = C_Item.GetItemNameByID(itemID)
            elseif GetItemInfo then
                itemName = GetItemInfo(itemID)
            end

            if not itemName then
                if GetItemInfo then
                    GetItemInfo(itemID)
                end
                return nil, false
            end

            local allSpecSet = {}
            if VCA.SpecInfo and VCA.SpecInfo.GetPlayerSpecs then
                for _, spec in ipairs(VCA.SpecInfo.GetPlayerSpecs()) do
                    allSpecSet[spec.specID] = true
                end
            end

            _itemSpecCache[itemID] = allSpecSet
            return allSpecSet, true
        end

        local specSet = {}
        for _, eligibleSpecID in ipairs(specInfo) do
            specSet[eligibleSpecID] = true
        end
        _itemSpecCache[itemID] = specSet
        return specSet, true
    end

    -- Metadata may be temporarily unavailable while item data is still warming.
    -- Prime the client cache and do not cache this miss so later reads can
    -- recover without /reload.
    if GetItemInfo then
        GetItemInfo(itemID)
    end
    return nil, false
end

local function GetClassIDForSpecID(specID)
    if not VCA.SpecInfo or not VCA.SpecInfo.GetPlayerSpecs then
        return nil
    end

    for _, spec in ipairs(VCA.SpecInfo.GetPlayerSpecs()) do
        if spec.specID == specID then
            return spec.classID
        end
    end

    return nil
end

local function IsItemUsableByPlayer(itemID)
    if C_Item and C_Item.IsUsableItem then
        local usable = C_Item.IsUsableItem(itemID)
        return usable == true
    end

    if IsUsableItem then
        local usable = IsUsableItem(itemID)
        return usable == true
    end

    return false
end

local function IsFallbackItemEligibleForClass(itemID, classID)
    if not classID or not C_Item or not C_Item.GetItemInfoInstant then
        return false
    end

    local playerClassID = VCA.SpecInfo and VCA.SpecInfo.GetPlayerClassID and VCA.SpecInfo.GetPlayerClassID()
    if not playerClassID or classID ~= playerClassID then
        return false
    end

    -- Primary fallback when spec metadata is absent: if the item is usable by
    -- the current character, treat it as eligible for this class/spec pool.
    if IsItemUsableByPlayer(itemID) then
        return true
    end

    local _, _, _, equipLoc, _, itemClassID, itemSubClassID = C_Item.GetItemInfoInstant(itemID)
    if not equipLoc or equipLoc == "" then
        return false
    end

    -- Some dagger drops can report as unusable until client item metadata is
    -- fully available. Allow them for classes that can equip daggers.
    if itemClassID == 2
       and itemSubClassID == DAGGER_SUBCLASS_ID
       and _fallbackDaggerClassID[classID]
    then
        return true
    end

    if _fallbackUniversalEquipLoc[equipLoc] then
        return true
    end

    if classID == HUNTER_CLASS_ID and _fallbackHunterEquipLoc[equipLoc] then
        return true
    end

    return false
end

local function SpecSetHasAnyPlayerSpecForClass(specSet, classID)
    if not specSet or not classID or not VCA.SpecInfo or not VCA.SpecInfo.GetPlayerSpecs then
        return false
    end

    for _, spec in ipairs(VCA.SpecInfo.GetPlayerSpecs()) do
        if spec.classID == classID and specSet[spec.specID] then
            return true
        end
    end

    return false
end

local function IsItemEligibleForSpec(itemID, specID)
    local specSet, metadataReady = GetItemEligibleSpecSet(itemID)
    local classID = GetClassIDForSpecID(specID)

    if specSet ~= nil then
        if specSet[specID] == true then
            return true, metadataReady
        end

        -- Some items can report a spec mapping that does not correspond to
        -- player spec IDs. In that case, use class-level fallback eligibility.
        if classID and not SpecSetHasAnyPlayerSpecForClass(specSet, classID) then
            return IsFallbackItemEligibleForClass(itemID, classID), metadataReady
        end

        return false, metadataReady
    end

    return IsFallbackItemEligibleForClass(itemID, classID), metadataReady
end

local function IsItemEligibleForClass(itemID, classID)
    if not classID or not VCA.SpecInfo or not VCA.SpecInfo.GetPlayerSpecs then
        return false, true
    end

    local specSet, metadataReady = GetItemEligibleSpecSet(itemID)
    if specSet == nil then
        return IsFallbackItemEligibleForClass(itemID, classID), metadataReady
    end

    for _, spec in ipairs(VCA.SpecInfo.GetPlayerSpecs()) do
        if spec.classID == classID and specSet[spec.specID] then
            return true, metadataReady
        end
    end

    -- If metadata exists but has no overlap with this class's player specs,
    -- treat it as an incompatible mapping and use class-level fallback.
    if not SpecSetHasAnyPlayerSpecForClass(specSet, classID) then
        return IsFallbackItemEligibleForClass(itemID, classID), metadataReady
    end

    return false, metadataReady
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
    local readOK = WithEJState(difficultyID, classID, specID, function()
        local instanceID = ResolveEncounterInstanceID(encounterID)
        if instanceID then SelectInstance(instanceID) end
        SelectEncounter(encounterID)
        items = CollectLootForSelectedEncounter()
    end)

    if not readOK then
        return {}
    end

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

    local ejSpecSet = {}

    local readOK = WithEJState(difficultyID, classID, specID, function()
        local resolvedInstanceID = instanceID or ResolveEncounterInstanceID(encounterID)
        if resolvedInstanceID then
            SelectInstance(resolvedInstanceID)
        end
        SelectEncounter(encounterID)

        local items = CollectLootForSelectedEncounter()
        for _, item in ipairs(items) do
            ejSpecSet[item.itemID] = true
        end
    end)

    if not readOK then
        return {}
    end

    local classItemIDs = LootPool.GetEncounterItemsForClass(encounterID, difficultyID, classID, instanceID)
    local itemIDs = {}
    local metadataComplete = true
    local useEJGate = next(ejSpecSet) ~= nil

    for _, itemID in ipairs(classItemIDs) do
        if (not useEJGate) or ejSpecSet[itemID] then
            local eligible, metadataReady = IsItemEligibleForSpec(itemID, specID)
            if not metadataReady then
                metadataComplete = false
            end
            if eligible then
                itemIDs[#itemIDs + 1] = itemID
            end
        end
    end

    if metadataComplete then
        _cache[key] = itemIDs
        PersistCacheEntry(key, itemIDs)
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

    local readOK = WithEJState(difficultyID, classID, specID, function()
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

    -- If EJ filter application failed, do not return untrusted all-class data.
    if not readOK then
        return { all = {}, byEncounter = {} }
    end

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

    local ejSpecSet = {}

    local readOK = WithEJState(difficultyID, classID, specID, function()
        SelectInstance(instanceID)
        local idx = 1
        while true do
            local name, _, encounterID = EJ_GetEncounterInfoByIndex(idx)
            if not name then break end

            SelectEncounter(encounterID)
            local items = CollectLootForSelectedEncounter()
            for _, item in ipairs(items) do
                ejSpecSet[item.itemID] = true
            end

            idx = idx + 1
        end
    end)

    if not readOK then
        return {}
    end

    local classItemIDs = LootPool.GetInstanceItemsForClass(instanceID, difficultyID, classID)
    local itemIDs = {}
    local metadataComplete = true
    local useEJGate = next(ejSpecSet) ~= nil

    for _, itemID in ipairs(classItemIDs) do
        if (not useEJGate) or ejSpecSet[itemID] then
            local eligible, metadataReady = IsItemEligibleForSpec(itemID, specID)
            if not metadataReady then
                metadataComplete = false
            end
            if eligible then
                itemIDs[#itemIDs + 1] = itemID
            end
        end
    end

    if metadataComplete then
        _cache[key] = itemIDs
        PersistCacheEntry(key, itemIDs)
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

    local candidateIDs = {}

    local readOK = WithEJState(difficultyID, classID, 0, function()
        local resolvedInstanceID = instanceID or ResolveEncounterInstanceID(encounterID)
        if resolvedInstanceID then
            SelectInstance(resolvedInstanceID)
        end
        SelectEncounter(encounterID)

        local items = CollectLootForSelectedEncounter()
        for _, item in ipairs(items) do
            candidateIDs[item.itemID] = true
        end
    end)

    if not readOK then
        return {}
    end

    local itemIDs = {}
    local metadataComplete = true
    for itemID in pairs(candidateIDs) do
        local eligible, metadataReady = IsItemEligibleForClass(itemID, classID)
        if not metadataReady then
            metadataComplete = false
        end
        if eligible then
            itemIDs[#itemIDs + 1] = itemID
        end
    end

    if metadataComplete then
        _cache[key] = itemIDs
        PersistCacheEntry(key, itemIDs)
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

    local candidateIDs = {}

    local readOK = WithEJState(difficultyID, classID, 0, function()
        SelectInstance(instanceID)
        local idx = 1
        while true do
            local name, _, encounterID = EJ_GetEncounterInfoByIndex(idx)
            if not name then break end

            SelectEncounter(encounterID)
            local items = CollectLootForSelectedEncounter()
            for _, item in ipairs(items) do
                candidateIDs[item.itemID] = true
            end

            idx = idx + 1
        end
    end)

    if not readOK then
        return {}
    end

    local itemIDs = {}
    local metadataComplete = true
    for itemID in pairs(candidateIDs) do
        local eligible, metadataReady = IsItemEligibleForClass(itemID, classID)
        if not metadataReady then
            metadataComplete = false
        end
        if eligible then
            itemIDs[#itemIDs + 1] = itemID
        end
    end

    if metadataComplete then
        _cache[key] = itemIDs
        PersistCacheEntry(key, itemIDs)
    end
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

-- ── Internal references for LootPoolWarm.lua ──────────────────────────────────
-- LootPoolWarm.lua is loaded immediately after this file.  Expose the private
-- tables and functions it needs via the LootPool namespace so it can access
-- them without duplicating logic here.  Do not reassign these – they are
-- live table/function references.

LootPool._cache           = _cache
LootPool._seasonRaidIDs   = _seasonRaidIDs
LootPool._WithEJState     = WithEJState
LootPool._SelectInstance  = SelectInstance
