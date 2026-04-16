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

function Data.BuildKey(sourceType, sourceID, difficultyID, itemID)
    return sourceType .. ":" .. sourceID .. ":" .. difficultyID .. ":" .. itemID
end

-- ── Obtained status ───────────────────────────────────────────────────────────

-- Returns true if this item has been marked as obtained via Voidcore on this
-- character for the given source and difficulty.
function Data.IsObtained(sourceType, sourceID, difficultyID, itemID)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db or not db.obtained then return false end
    return db.obtained[Data.BuildKey(sourceType, sourceID, difficultyID, itemID)] == true
end

-- Marks or unmarks an item as obtained.
-- obtained: boolean (true = mark, false = unmark)
function Data.SetObtained(sourceType, sourceID, difficultyID, itemID, obtained)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db then return end
    db.obtained = db.obtained or {}
    local key = Data.BuildKey(sourceType, sourceID, difficultyID, itemID)
    if obtained then
        db.obtained[key] = true
    else
        db.obtained[key] = nil
    end
end

-- Toggles the obtained state and returns the new state (true/false).
function Data.ToggleObtained(sourceType, sourceID, difficultyID, itemID)
    local current = Data.IsObtained(sourceType, sourceID, difficultyID, itemID)
    Data.SetObtained(sourceType, sourceID, difficultyID, itemID, not current)
    return not current
end

-- ── Pool filtering ────────────────────────────────────────────────────────────

-- Given a flat array of item tables (each must have an `itemID` field),
-- returns a new array containing only items NOT yet obtained.
function Data.GetRemainingItems(pool, sourceType, sourceID, difficultyID)
    local remaining = {}
    for _, item in ipairs(pool) do
        if not Data.IsObtained(sourceType, sourceID, difficultyID, item.itemID) then
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
    if not db or not db.selectedItems then return {} end
    local key = SelectionKey(sourceType, sourceID, difficultyID)
    return db.selectedItems[key] or {}
end

-- Saves a set { [itemID]=true } (or nil/empty to clear) for the given source.
function Data.SaveSelectedItems(sourceType, sourceID, difficultyID, selectionSet)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db then return end
    db.selectedItems = db.selectedItems or {}
    local key = SelectionKey(sourceType, sourceID, difficultyID)
    if not selectionSet or not next(selectionSet) then
        db.selectedItems[key] = nil
    else
        -- Store a copy so the caller's table can be wiped without affecting the DB.
        local copy = {}
        for id in pairs(selectionSet) do copy[id] = true end
        db.selectedItems[key] = copy
    end
end

-- Removes a single item from the saved selection for the given source.
function Data.RemoveSelectedItem(sourceType, sourceID, difficultyID, itemID)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db or not db.selectedItems then return end
    local key = SelectionKey(sourceType, sourceID, difficultyID)
    local set = db.selectedItems[key]
    if not set then return end
    set[itemID] = nil
    if not next(set) then
        db.selectedItems[key] = nil
    end
end

-- ── Bulk operations ───────────────────────────────────────────────────────────

-- Returns all { sourceType, sourceID, difficultyID, itemID } tuples from the DB
-- whose key begins with the given source + difficulty prefix.
-- Useful for building a list of obtained items for a specific source UI view.
function Data.GetObtainedForSource(sourceType, sourceID, difficultyID)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db or not db.obtained then return {} end
    local prefix = sourceType .. ":" .. sourceID .. ":" .. difficultyID .. ":"
    local result = {}
    for key in pairs(db.obtained) do
        if key:sub(1, #prefix) == prefix then
            local itemID = tonumber(key:sub(#prefix + 1))
            if itemID then
                result[#result + 1] = itemID
            end
        end
    end
    return result
end

-- Clears all obtained data for one source + difficulty combination.
function Data.ClearSource(sourceType, sourceID, difficultyID)
    local db = _G[VCA.CHAR_DB_NAME]
    if not db or not db.obtained then return end
    local prefix = sourceType .. ":" .. sourceID .. ":" .. difficultyID .. ":"
    for key in pairs(db.obtained) do
        if key:sub(1, #prefix) == prefix then
            db.obtained[key] = nil
        end
    end
end

-- Returns the total number of items marked as obtained across all sources.
function Data.GetTotalObtainedCount()
    local db = _G[VCA.CHAR_DB_NAME]
    if not db or not db.obtained then return 0 end
    local count = 0
    for _ in pairs(db.obtained) do
        count = count + 1
    end
    return count
end
