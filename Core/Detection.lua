-- VoidcoreAdvisor: Detection
-- Heuristic auto-detection of items received via a Nebulous Voidcore.
--
-- How it works:
--   1. ENCOUNTER_END (success) or CHALLENGE_MODE_COMPLETED opens a short
--      detection window and captures a bag snapshot.
--   2. During the window, BAG_UPDATE_DELAYED diffs the bags.  Any new itemID
--      that is in the current source's loot pool is auto-marked as obtained.
--   3. CHAT_MSG_LOOT is also parsed as a belt-and-braces cross-check.
--   4. Zone transitions immediately close the window to avoid false positives.
--
-- These are heuristics.  The UI layer provides manual overrides.

local _, VCA = ...

VCA.Detection = {}
local Detection = VCA.Detection

-- ── Internal state ────────────────────────────────────────────────────────────

local activeSource       = nil   -- { sourceType, sourceID, difficultyID } | nil
local windowEndTime      = 0     -- GetTime() value when detection window closes
local bagSnapshot        = {}    -- { [itemID] = count } before potential loot
local onDetectedCallback = nil   -- function(itemID, source) | nil

-- ── Public: source management ─────────────────────────────────────────────────

-- Explicitly sets the active source.  The UI (and ENCOUNTER_END handler) both
-- call this so that manual bag inspection and probability displays know which
-- pool to compare against.
function Detection.SetActiveSource(sourceType, sourceID, difficultyID)
    activeSource = {
        sourceType   = sourceType,
        sourceID     = sourceID,
        difficultyID = difficultyID,
    }
end

function Detection.ClearActiveSource()
    activeSource  = nil
    windowEndTime = 0
end

function Detection.GetActiveSource()
    return activeSource
end

-- Registers a callback invoked whenever an item is auto-detected as obtained.
-- callback = function(itemID, source)
--   itemID : number
--   source : { sourceType, sourceID, difficultyID }
function Detection.SetOnItemDetectedCallback(callback)
    onDetectedCallback = callback
end

-- ── Detection window ──────────────────────────────────────────────────────────

local function OpenWindow()
    windowEndTime = GetTime() + VCA.DETECTION_WINDOW_SECONDS
end

local function IsWindowOpen()
    return windowEndTime > 0 and GetTime() < windowEndTime
end

-- ── Bag snapshot ──────────────────────────────────────────────────────────────

local function SnapshotBags()
    local snapshot = {}
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                snapshot[info.itemID] = (snapshot[info.itemID] or 0) + 1
            end
        end
    end
    return snapshot
end

-- Returns an array of itemIDs that appear more times in newSnap than oldSnap.
local function DiffSnapshots(oldSnap, newSnap)
    local newItems = {}
    for itemID, count in pairs(newSnap) do
        if count > (oldSnap[itemID] or 0) then
            newItems[#newItems + 1] = itemID
        end
    end
    return newItems
end

-- ── Pool set caching ──────────────────────────────────────────────────────────
-- Builds a set of itemIDs in the active source pool for the player's class.
-- Class-filtered (not spec-filtered) so items for any spec are included.

local cachedPoolSet     = nil
local cachedPoolSource  = nil  -- serialised source key, invalidated on change

local function GetActivePoolSet()
    if not activeSource then return {} end
    local key = activeSource.sourceType .. ":" .. activeSource.sourceID .. ":" .. activeSource.difficultyID
    if cachedPoolSet and cachedPoolSource == key then
        return cachedPoolSet
    end

    -- Read pool for each of the player's specs and union them all.
    -- This catches cases where the player switches loot spec mid-window.
    local specs  = VCA.SpecInfo.GetPlayerSpecs()
    local poolSet = {}
    for _, spec in ipairs(specs) do
        local itemIDs = VCA.LootPool.GetItemsForSpec(
            activeSource.sourceType,
            activeSource.sourceID,
            activeSource.difficultyID,
            spec.classID,
            spec.specID
        )
        for _, id in ipairs(itemIDs) do
            poolSet[id] = true
        end
    end

    cachedPoolSet    = poolSet
    cachedPoolSource = key
    return poolSet
end

local function InvalidatePoolCache()
    cachedPoolSet    = nil
    cachedPoolSource = nil
end

-- ── Item detection ────────────────────────────────────────────────────────────

local function OnCandidateItemDetected(itemID)
    if not activeSource then return end
    if VCA.Data.IsObtained(activeSource.sourceType, activeSource.sourceID,
                            activeSource.difficultyID, itemID) then
        return  -- already known; nothing to do
    end
    VCA.Data.SetObtained(activeSource.sourceType, activeSource.sourceID,
                          activeSource.difficultyID, itemID, true)
    if onDetectedCallback then
        onDetectedCallback(itemID, activeSource)
    end
end

-- Parse item IDs from a CHAT_MSG_LOOT message string.
-- Item hyperlinks use the format  |Hitem:<itemID>:...|h...
local function ParseItemIDsFromChatMsg(msg)
    local ids = {}
    for idStr in msg:gmatch("|Hitem:(%d+):") do
        ids[#ids + 1] = tonumber(idStr)
    end
    return ids
end

-- ── Event frame ───────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    -- ── Encounter completed (raid boss kill) ──────────────────────────────
    if event == "ENCOUNTER_END" then
        local encounterID, _, difficultyID, _, endStatus = ...
        if endStatus ~= 1 then return end  -- 1 = success / kill
        Detection.SetActiveSource(VCA.ContentType.RAID, encounterID, difficultyID)
        InvalidatePoolCache()
        bagSnapshot = SnapshotBags()
        OpenWindow()

    -- ── M+ dungeon completed ──────────────────────────────────────────────
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        -- C_ChallengeMode.GetActiveChallengeMapID() returns the EJ instanceID
        -- (mapID) for the dungeon.  It is valid immediately after this event.
        local mapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID()
        if mapID then
            Detection.SetActiveSource(
                VCA.ContentType.MYTHIC_PLUS,
                mapID,
                VCA.MythicPlusEJDifficulty
            )
            InvalidatePoolCache()
            bagSnapshot = SnapshotBags()
            OpenWindow()
        end

    -- ── Bag change settled ────────────────────────────────────────────────
    elseif event == "BAG_UPDATE_DELAYED" then
        if not IsWindowOpen() or not activeSource then return end
        local currentSnap = SnapshotBags()
        local newItems    = DiffSnapshots(bagSnapshot, currentSnap)
        if #newItems == 0 then return end
        local poolSet = GetActivePoolSet()
        for _, itemID in ipairs(newItems) do
            if poolSet[itemID] then
                OnCandidateItemDetected(itemID)
            end
        end
        -- Update snapshot so repeated BAG_UPDATE_DELAYED don't re-fire.
        bagSnapshot = currentSnap

    -- ── Chat loot message (belt-and-braces) ───────────────────────────────
    elseif event == "CHAT_MSG_LOOT" then
        if not IsWindowOpen() or not activeSource then return end
        local msg     = ...
        local poolSet = GetActivePoolSet()
        for _, itemID in ipairs(ParseItemIDsFromChatMsg(msg)) do
            if poolSet[itemID] then
                OnCandidateItemDetected(itemID)
            end
        end

    -- ── Zone transition: close window to prevent cross-zone false positives ─
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        windowEndTime = 0
        bagSnapshot   = {}
    end
end)
