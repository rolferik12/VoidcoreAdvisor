-- VoidcoreAdvisor: Data
-- Per-character persistence layer.  Manages which items the character has
-- already received via a Nebulous Voidcore, keyed by source + difficulty.
--
-- Storage key format: "<ContentType>:<sourceID>:<difficultyID>:<itemID>"
-- Example (Heroic raid boss 2532, item 208430):
--   "RAID:2532:15:208430"
-- Example (M+ instanceID 67, item 199388):
--   "MYTHIC_PLUS:67:23:199388"
local _, VCA = ...

VCA.Data = {}
local Data = VCA.Data

-- ── Key construction ──────────────────────────────────────────────────────────
-- Key format: "<ContentType>:<sourceID>:<difficultyID>:<specID>:<itemID>"
-- specID identifies the loot specialization active when the item was obtained.
-- A specID of 0 is used for manual panel overrides (no specific spec context).

function Data.BuildKey(sourceType, sourceID, difficultyID, specID, itemID)
    return sourceType .. ":" .. sourceID .. ":" .. difficultyID .. ":" .. (specID or 0) .. ":" .. itemID
end

-- ── Obtained status ───────────────────────────────────────────────────────────

-- Returns true if this item has been marked as obtained via Voidcore on this
-- character for the given source, difficulty, and specialization.
function Data.IsObtained(sourceType, sourceID, difficultyID, specID, itemID)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db or not db.obtained then
        return false
    end
    return db.obtained[Data.BuildKey(sourceType, sourceID, difficultyID, specID, itemID)] == true
end

-- Marks or unmarks an item as obtained for the given specialization.
-- obtained: boolean (true = mark, false = unmark)
function Data.SetObtained(sourceType, sourceID, difficultyID, specID, itemID, obtained)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db then
        return
    end
    db.obtained = db.obtained or {}
    local key = Data.BuildKey(sourceType, sourceID, difficultyID, specID, itemID)
    if obtained then
        db.obtained[key] = true
    else
        db.obtained[key] = nil
    end
end

-- Toggles the obtained state for the given spec and returns the new state (true/false).
function Data.ToggleObtained(sourceType, sourceID, difficultyID, specID, itemID)
    local current = Data.IsObtained(sourceType, sourceID, difficultyID, specID, itemID)
    Data.SetObtained(sourceType, sourceID, difficultyID, specID, itemID, not current)
    return not current
end

-- ── Pool filtering ────────────────────────────────────────────────────────────

-- Given a flat array of item tables (each must have an `itemID` field),
-- returns a new array containing only items NOT yet obtained for the given spec.
function Data.GetRemainingItems(pool, sourceType, sourceID, difficultyID, specID)
    local remaining = {}
    for _, item in ipairs(pool) do
        if not Data.IsObtained(sourceType, sourceID, difficultyID, specID, item.itemID) then
            remaining[#remaining + 1] = item
        end
    end
    return remaining
end

-- ── Selected items persistence ─────────────────────────────────────────────────

local function SelectionKey(sourceType, sourceID, difficultyID)
    return sourceType .. ":" .. sourceID .. ":" .. difficultyID
end

-- Returns a set { [itemID]=true } of selected items for the given source context.
function Data.GetSelectedItems(sourceType, sourceID, difficultyID)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db or not db.selectedItems then
        return {}
    end
    local key = SelectionKey(sourceType, sourceID, difficultyID)
    local raw = db.selectedItems[key]
    if type(raw) ~= "table" then
        return {}
    end

    -- Normalize to the canonical set format: { [itemID] = true }.
    -- This also migrates legacy array/string-keyed data and drops invalid entries.
    local normalized = {}
    for k, v in pairs(raw) do
        if v == true then
            local id = tonumber(k)
            if id and id > 0 then
                normalized[id] = true
            end
        else
            local id = tonumber(v)
            if id and id > 0 then
                normalized[id] = true
            end
        end
    end

    if not next(normalized) then
        db.selectedItems[key] = nil
        return {}
    end

    db.selectedItems[key] = normalized
    return normalized
end

-- Saves a set { [itemID]=true } (or nil/empty to clear) for the given source.
function Data.SaveSelectedItems(sourceType, sourceID, difficultyID, selectionSet)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db then
        return
    end
    db.selectedItems = db.selectedItems or {}
    local key = SelectionKey(sourceType, sourceID, difficultyID)
    if not selectionSet or not next(selectionSet) then
        db.selectedItems[key] = nil
    else
        -- Store a copy so the caller's table can be wiped without affecting the DB.
        local copy = {}
        for id in pairs(selectionSet) do
            copy[id] = true
        end
        db.selectedItems[key] = copy
    end
end

-- Removes a single item from the saved selection for the given source.
function Data.RemoveSelectedItem(sourceType, sourceID, difficultyID, itemID)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db or not db.selectedItems then
        return
    end
    local key = SelectionKey(sourceType, sourceID, difficultyID)
    local set = db.selectedItems[key]
    if not set then
        return
    end
    set[itemID] = nil
    if not next(set) then
        db.selectedItems[key] = nil
    end
end

-- ── Bulk operations ───────────────────────────────────────────────────────────

-- Returns all itemIDs from the DB for the given source, difficulty, and spec.
-- If specID is nil, returns items obtained under any specialization.
function Data.GetObtainedForSource(sourceType, sourceID, difficultyID, specID)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db or not db.obtained then
        return {}
    end
    -- Key format after prefix: "specID:itemID"
    local prefix = sourceType .. ":" .. sourceID .. ":" .. difficultyID .. ":"
    local specPrefix = specID and (tostring(specID) .. ":") or nil
    local result = {}
    for key in pairs(db.obtained) do
        if key:sub(1, #prefix) == prefix then
            local rest = key:sub(#prefix + 1)
            local itemID
            if specPrefix then
                if rest:sub(1, #specPrefix) == specPrefix then
                    itemID = tonumber(rest:sub(#specPrefix + 1))
                end
            else
                itemID = tonumber(rest:match(":(%d+)$"))
            end
            if itemID then
                result[#result + 1] = itemID
            end
        end
    end
    return result
end

-- Clears all obtained data for one source + difficulty combination.
-- If specID is provided, only clears data for that specialization.
function Data.ClearSource(sourceType, sourceID, difficultyID, specID)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db or not db.obtained then
        return
    end
    local prefix = sourceType .. ":" .. sourceID .. ":" .. difficultyID .. ":"
    local specPrefix = specID and (tostring(specID) .. ":") or nil
    for key in pairs(db.obtained) do
        if key:sub(1, #prefix) == prefix then
            local rest = key:sub(#prefix + 1)
            if not specPrefix or rest:sub(1, #specPrefix) == specPrefix then
                db.obtained[key] = nil
            end
        end
    end
end

-- Returns the total number of items marked as obtained across all sources.
function Data.GetTotalObtainedCount()
    local db = _G[VCA.CHAR_DB_NAME]
    if not db or not db.obtained then
        return 0
    end
    local count = 0
    for _ in pairs(db.obtained) do
        count = count + 1
    end
    return count
end

-- ── Migration helpers ─────────────────────────────────────────────────────────

-- Returns true if this item has a specID=0 entry (migrated from the pre-spec
-- schema where obtained keys had no specID segment).
function Data.IsObtainedMigrated(sourceType, sourceID, difficultyID, itemID)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db or not db.obtained then
        return false
    end
    return db.obtained[Data.BuildKey(sourceType, sourceID, difficultyID, 0, itemID)] == true
end

-- One-time migration: rewrites 4-part keys ("TYPE:srcID:diffID:itemID") to
-- 5-part keys with specID=0 ("TYPE:srcID:diffID:0:itemID").
-- Called from Init.lua MigrateDB during the v1→v2 schema upgrade.
function Data.MigrateV1Keys(db)
    if not db.obtained then
        return
    end
    local toAdd = {}
    local toRemove = {}
    for key in pairs(db.obtained) do
        -- Count colons: 4-part key has 3, 5-part has 4.
        local colons = 0
        for _ in key:gmatch(":") do
            colons = colons + 1
        end
        if colons == 3 then
            local t, src, diff, item = key:match("^([^:]+):([^:]+):([^:]+):([^:]+)$")
            if t and src and diff and item then
                toAdd[t .. ":" .. src .. ":" .. diff .. ":0:" .. item] = true
                toRemove[key] = true
            end
        end
    end
    for k in pairs(toRemove) do
        db.obtained[k] = nil
    end
    for k in pairs(toAdd) do
        db.obtained[k] = true
    end
end
