-- VoidcoreAdvisor: Detection
-- BONUS_ROLL_RESULT-only detection for Nebulous Voidcore rewards.

local _, VCA = ...

VCA.Detection = {}
local Detection = VCA.Detection

-- -- Internal state -----------------------------------------------------------

local sourceOverride = nil    -- optional UI-selected source context
local onDetectedCallback = nil -- function(itemID, source) | nil
local pendingRewards = {}

local function CreateSource(sourceType, sourceID, difficultyID, keyLevel)
    return {
        sourceType = sourceType,
        sourceID = sourceID,
        difficultyID = difficultyID,
        keyLevel = keyLevel,
    }
end

local function ResolveCurrentMythicPlusSource()
    local instanceName, instanceType, difficultyID = GetInstanceInfo()
    if instanceType ~= "party" then
        return nil
    end

    -- 23 = Mythic 0, 8 = Mythic Keystone.
    if difficultyID ~= 23 and difficultyID ~= 8 then
        return nil
    end

    local sourceID = VCA.LootPool and VCA.LootPool.GetCachedSeasonDungeonByName and
        VCA.LootPool.GetCachedSeasonDungeonByName(instanceName)
    if not sourceID then
        return nil
    end

    return CreateSource(
        VCA.ContentType.MYTHIC_PLUS,
        sourceID,
        VCA.MythicPlusEJDifficulty)
end

local function GetResolvedSource()
    if sourceOverride then
        return sourceOverride
    end

    return ResolveCurrentMythicPlusSource()
end

local function IsInInstancedContent()
    local inInstance = IsInInstance()
    return inInstance == true
end

local function FindDetectedItem(itemID, source)
    if not source or not itemID then return nil end

    local classID = VCA.SpecInfo and VCA.SpecInfo.GetPlayerClassID and VCA.SpecInfo.GetPlayerClassID()
    if not classID then return nil end

    local cachedItemIDs = VCA.LootPool and VCA.LootPool.GetCachedItemsForClass and
        VCA.LootPool.GetCachedItemsForClass(
            source.sourceType,
            source.sourceID,
            source.difficultyID,
            classID)

    if not cachedItemIDs then return nil end

    for _, cachedItemID in ipairs(cachedItemIDs) do
        if cachedItemID == itemID then
            return cachedItemID, source
        end
    end

    return nil
end

-- -- Public: source management ------------------------------------------------

-- Explicitly sets the active source. The UI should call this whenever context
-- changes so BONUS_ROLL_RESULT can be attributed to the correct pool.
function Detection.SetActiveSource(sourceType, sourceID, difficultyID, keyLevel)
    sourceOverride = CreateSource(sourceType, sourceID, difficultyID, keyLevel)
end

function Detection.ClearActiveSource()
    sourceOverride = nil
end

function Detection.GetActiveSource()
    return GetResolvedSource()
end

-- callback = function(itemID, source)
function Detection.SetOnItemDetectedCallback(callback)
    onDetectedCallback = callback
end

-- -- Item detection -----------------------------------------------------------

local function OnCandidateItemDetected(itemID, source)
    if not source or not itemID then return end

    if VCA.Data.IsObtained(source.sourceType, source.sourceID,
                            source.difficultyID, itemID) then
        return
    end

    VCA.Data.SetObtained(source.sourceType, source.sourceID,
                          source.difficultyID, itemID, true)

    if onDetectedCallback then
        onDetectedCallback(itemID, source)
    end
end

local function TryResolveReward(itemID, source)
    local matchedItemID = FindDetectedItem(itemID, source)
    if matchedItemID then
        OnCandidateItemDetected(matchedItemID, source)
        return true
    end

    return false
end

local function QueuePendingReward(itemID, source)
    if not itemID then return end

    pendingRewards[#pendingRewards + 1] = {
        itemID = itemID,
        source = source,
    }
end

local function ProcessPendingRewards()
    if #pendingRewards == 0 then
        return
    end

    local remaining = {}
    for _, entry in ipairs(pendingRewards) do
        local source = entry.source or GetResolvedSource()
        if not TryResolveReward(entry.itemID, source) then
            remaining[#remaining + 1] = {
                itemID = entry.itemID,
                source = source,
            }
        end
    end

    pendingRewards = remaining
end

local function ProcessRewardItem(itemID)
    if not itemID then return end

    local source = GetResolvedSource()
    if TryResolveReward(itemID, source) then
        return
    end

    if IsInInstancedContent() then
        QueuePendingReward(itemID, source)
        return
    end

    QueuePendingReward(itemID, source)
    ProcessPendingRewards()
end

-- -- Event frame --------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BONUS_ROLL_RESULT")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        Detection.ClearActiveSource()
        if not IsInInstancedContent() then
            C_Timer.After(0, ProcessPendingRewards)
        end
        return
    end

    if event ~= "BONUS_ROLL_RESULT" then return end

    local typeIdentifier, itemLink = ...
    if typeIdentifier ~= "item" then return end
    if type(itemLink) ~= "string" then return end

    local idStr = itemLink:match("|Hitem:(%d+):")
    local itemID = idStr and tonumber(idStr)
    if not itemID then return end

    C_Timer.After(0, function()
        ProcessRewardItem(itemID)
    end)
end)
