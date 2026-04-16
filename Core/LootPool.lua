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

-- Returns all loot items for a single raid boss encounter at a given difficulty,
-- with NO class/spec filter applied (shows every item that can drop).
--
-- encounterID  : EJ journal encounter ID
-- difficultyID : EJ difficulty ID (use VCA.Difficulty constants)
-- Returns: array of item tables (see CollectLootForSelectedEncounter)
function LootPool.GetEncounterItems(encounterID, difficultyID)
    local items = {}
    WithEJState(difficultyID, 0, 0, function()
        EJ_SelectEncounter(encounterID)
        items = CollectLootForSelectedEncounter()
    end)
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
    return itemIDs
end

-- ── Public: per-instance reads (M+ dungeons) ─────────────────────────────────

-- Returns all loot items for an entire dungeon instance at a given difficulty,
-- with NO class/spec filter.  Items are deduplicated across encounters because
-- M+ can award any item from any boss in the dungeon.
--
-- instanceID   : EJ instance ID
-- difficultyID : EJ difficulty ID (VCA.MythicPlusEJDifficulty for M+)
-- Returns:
--   {
--     all         = item[]   -- flat deduplicated list
--     byEncounter = { [encounterID] = item[] }
--   }
function LootPool.GetInstanceItems(instanceID, difficultyID)
    local result = { all = {}, byEncounter = {} }
    local seen   = {}

    WithEJState(difficultyID, 0, 0, function()
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
