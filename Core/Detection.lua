-- VoidcoreAdvisor: Detection
-- BONUS_ROLL_RESULT-only detection for Nebulous Voidcore rewards.

local _, VCA = ...

VCA.Detection = {}
local Detection = VCA.Detection

-- -- Internal state -----------------------------------------------------------

local activeSource = nil      -- { sourceType, sourceID, difficultyID, keyLevel } | nil
local onDetectedCallback = nil -- function(itemID, source) | nil

local function FindDetectedItemInCache(itemID)
    if not activeSource or not itemID then return nil end

    local classID = VCA.SpecInfo and VCA.SpecInfo.GetPlayerClassID and VCA.SpecInfo.GetPlayerClassID()
    if not classID then return nil end

    local cachedItemIDs = VCA.LootPool and VCA.LootPool.GetCachedItemsForClass and
        VCA.LootPool.GetCachedItemsForClass(
            activeSource.sourceType,
            activeSource.sourceID,
            activeSource.difficultyID,
            classID)

    if not cachedItemIDs then return nil end

    for _, cachedItemID in ipairs(cachedItemIDs) do
        if cachedItemID == itemID then
            return cachedItemID
        end
    end

    return nil
end

-- -- Public: source management ------------------------------------------------

-- Explicitly sets the active source. The UI should call this whenever context
-- changes so BONUS_ROLL_RESULT can be attributed to the correct pool.
function Detection.SetActiveSource(sourceType, sourceID, difficultyID, keyLevel)
    activeSource = {
        sourceType = sourceType,
        sourceID = sourceID,
        difficultyID = difficultyID,
        keyLevel = keyLevel,
    }
end

function Detection.ClearActiveSource()
    activeSource = nil
end

function Detection.GetActiveSource()
    return activeSource
end

-- callback = function(itemID, source)
function Detection.SetOnItemDetectedCallback(callback)
    onDetectedCallback = callback
end

-- -- Item detection -----------------------------------------------------------

local function OnCandidateItemDetected(itemID)
    if not activeSource or not itemID then return end

    if VCA.Data.IsObtained(activeSource.sourceType, activeSource.sourceID,
                            activeSource.difficultyID, itemID) then
        return
    end

    VCA.Data.SetObtained(activeSource.sourceType, activeSource.sourceID,
                          activeSource.difficultyID, itemID, true)

    if onDetectedCallback then
        onDetectedCallback(itemID, activeSource)
    end
end

-- -- Event frame --------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BONUS_ROLL_RESULT")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event ~= "BONUS_ROLL_RESULT" then return end

    local typeIdentifier, itemLink = ...
    if typeIdentifier ~= "item" then return end
    if type(itemLink) ~= "string" then return end

    local idStr = itemLink:match("|Hitem:(%d+):")
    local itemID = idStr and tonumber(idStr)
    local matchedItemID = itemID and FindDetectedItemInCache(itemID)
    if matchedItemID then
        OnCandidateItemDetected(matchedItemID)
    end
end)
