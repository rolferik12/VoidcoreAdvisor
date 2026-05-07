-- VoidcoreAdvisor: Detection
-- BONUS_ROLL_RESULT-only detection for Nebulous Voidcore rewards.
local _, VCA = ...

VCA.Detection = {}
local Detection = VCA.Detection

-- -- Internal state -----------------------------------------------------------

local sourceOverride = nil -- optional UI-selected source context
local onDetectedCallback = nil -- function(itemID, source) | nil
local pendingRewards = {}
-- Key level captured at CHALLENGE_MODE_START / CHALLENGE_MODE_COMPLETED, before
-- GetActiveKeystoneInfo() goes stale after the keystone is consumed.
local cachedKeyLevel = nil

local function CreateSource(sourceType, sourceID, difficultyID, keyLevel)
    return {
        sourceType = sourceType,
        sourceID = sourceID,
        difficultyID = difficultyID,
        keyLevel = keyLevel
    }
end

local function ResolveCurrentMythicPlusSource()
    local instanceName, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType ~= "party" then
        return nil
    end

    -- 23 = Mythic 0, 8 = Mythic Keystone.
    if difficultyID ~= 23 and difficultyID ~= 8 then
        return nil
    end

    -- Primary: locale-independent InstanceID lookup (requires SeasonData with mapID).
    local sourceID = instanceID and VCA.LootPool and VCA.LootPool.GetSeasonDungeonByInstanceID and
                         VCA.LootPool.GetSeasonDungeonByInstanceID(instanceID)

    -- Fallback: localized name lookup for SeasonData built before mapID support.
    if not sourceID then
        sourceID = VCA.LootPool and VCA.LootPool.GetSeasonDungeonByName and
                       VCA.LootPool.GetSeasonDungeonByName(instanceName)
    end

    if not sourceID then
        return nil
    end

    local keyLevel
    if C_ChallengeMode then
        local level = C_ChallengeMode.GetActiveKeystoneInfo()
        if level and level > 0 then
            keyLevel = level
        end
        -- Fallback 1: level snapshotted at CHALLENGE_MODE_START / CHALLENGE_MODE_COMPLETED
        -- before the keystone is consumed and GetActiveKeystoneInfo() returns 0.
        -- This is the primary fix for the "second run in a session" miss: the first
        -- run's GetCompletionInfo() data may be stale or cleared by the time the
        -- second run's BONUS_ROLL_RESULT fires.
        if not keyLevel and cachedKeyLevel then
            keyLevel = cachedKeyLevel
        end
        -- Fallback 2: GetCompletionInfo() for the just-finished run.
        if not keyLevel then
            local _, completionLevel = C_ChallengeMode.GetCompletionInfo()
            if completionLevel and completionLevel > 0 then
                keyLevel = completionLevel
            end
        end
    end

    return CreateSource(VCA.ContentType.MYTHIC_PLUS, sourceID, VCA.MythicPlusEJDifficulty, keyLevel)
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
    if not source or not itemID then
        return nil
    end

    local classID = VCA.SpecInfo and VCA.SpecInfo.GetPlayerClassID and VCA.SpecInfo.GetPlayerClassID()
    if not classID then
        return nil
    end

    local cachedItemIDs = VCA.LootPool and VCA.LootPool.GetCachedItemsForClass and
                              VCA.LootPool
                                  .GetCachedItemsForClass(source.sourceType, source.sourceID, source.difficultyID,
            classID)

    if not cachedItemIDs then
        return nil
    end

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

-- Checks whether every item in the spec-specific pool is now obtained for
-- the given key tier.  If so, resets only that tier's obtained flags so the
-- cycle can repeat independently per tier.  Returns true if a reset was performed.
-- isHighTier: true = ≥10 tier, false = <10 tier, nil = tier-less / non-M+ (full reset)
local function CheckAndResetIfComplete(source, specID, isHighTier)
    if not source or not specID then
        return false
    end

    local classID = VCA.SpecInfo and VCA.SpecInfo.GetPlayerClassID and VCA.SpecInfo.GetPlayerClassID()
    if not classID then
        return false
    end

    local specPool = VCA.LootPool and VCA.LootPool.GetCachedItemsForSpec and
                         VCA.LootPool
                             .GetCachedItemsForSpec(source.sourceType, source.sourceID, source.difficultyID, classID,
            specID)
    if not specPool or #specPool == 0 then
        return false
    end

    for _, itemID in ipairs(specPool) do
        if not VCA.Data.IsObtainedForKeyTier(source.sourceType, source.sourceID, source.difficultyID, specID, itemID,
            isHighTier) then
            return false
        end
    end

    -- All items obtained for this spec+tier — reset only this tier's cycle.
    VCA.Data.ClearSourceForKeyTier(source.sourceType, source.sourceID, source.difficultyID, specID, isHighTier)
    return true
end

-- Public wrapper so UI code (PanelColumns) can trigger the same reset check
-- after a manual spec-picker toggle without going through the detection path.
-- source must be a table with sourceType, sourceID, difficultyID fields.
-- isHighTier: true = ≥10 cycle, false = <10 cycle, nil = full / non-M+ reset.
function Detection.CheckAndResetIfComplete(source, specID, isHighTier)
    return CheckAndResetIfComplete(source, specID, isHighTier)
end

local function OnCandidateItemDetected(itemID, source, specID)
    if not source or not itemID then
        return
    end

    -- Derive the key tier from the source's key level.
    -- Mythic Keystone (diffID 8) always has a keyLevel; Mythic 0 / unknown → nil (tier-less).
    local isHighTier
    if source.keyLevel then
        isHighTier = source.keyLevel >= 10
    end

    if VCA.Data
        .IsObtainedForKeyTier(source.sourceType, source.sourceID, source.difficultyID, specID, itemID, isHighTier) then
        return
    end

    VCA.Data.SetObtainedForKeyTier(source.sourceType, source.sourceID, source.difficultyID, specID, itemID, isHighTier,
        true)

    if onDetectedCallback then
        onDetectedCallback(itemID, source)
    end

    CheckAndResetIfComplete(source, specID, isHighTier)
end

local function TryResolveReward(itemID, source, specID)
    local matchedItemID = FindDetectedItem(itemID, source)
    if matchedItemID then
        OnCandidateItemDetected(matchedItemID, source, specID)
        return true
    end

    return false
end

-- Replays saved bonus roll log entries through the detection pipeline.
-- Marks any unmatched items as obtained if they belong to the known pool.
-- Safe to call multiple times; IsObtained guards against double-marking.
-- verbose=true prints per-entry results to chat.
function Detection.ReplayBonusRollLog(verbose)
    local log = VCA.Data and VCA.Data.GetBonusRollLog and VCA.Data.GetBonusRollLog()
    if not log or #log == 0 then
        if verbose then
            print("|cff9370DBVoidcoreAdvisor:|r Replay: log is empty.")
        end
        return
    end
    local marked, skipped, nomatch, incomplete = 0, 0, 0, 0
    for i, entry in ipairs(log) do
        if not (entry.itemID and entry.sourceType and entry.sourceID and entry.difficultyID and entry.specID) then
            incomplete = incomplete + 1
            if verbose then
                print(string.format(
                    "|cff9370DBVoidcoreAdvisor:|r Replay [%d]: skipped — incomplete entry (itemID=%s specID=%s source=%s:%s diff=%s)",
                    i, tostring(entry.itemID), tostring(entry.specID), tostring(entry.sourceType),
                    tostring(entry.sourceID), tostring(entry.difficultyID)))
            end
        else
            local source = {
                sourceType = entry.sourceType,
                sourceID = entry.sourceID,
                difficultyID = entry.difficultyID,
                keyLevel = entry.keyLevel
            }
            local isHighTier
            if entry.keyLevel then
                isHighTier = entry.keyLevel >= 10
            end
            local alreadyObtained = VCA.Data.IsObtainedForKeyTier(source.sourceType, source.sourceID,
                source.difficultyID, entry.specID, entry.itemID, isHighTier)
            if alreadyObtained then
                -- If the log entry has a known tier and the existing record is a bare key
                -- (unknown-tier legacy entry), upgrade it to a proper tiered key so that
                -- each tier's cycle can be reset independently going forward.
                if isHighTier ~= nil and
                    VCA.Data
                        .IsObtainedBareKey(source.sourceType, source.sourceID, source.difficultyID, entry.specID,
                        entry.itemID) then
                    if not VCA.Data.IsObtainedTiered(source.sourceType, source.sourceID, source.difficultyID,
                        entry.specID, entry.itemID, isHighTier) then
                        VCA.Data.SetObtainedForKeyTier(source.sourceType, source.sourceID, source.difficultyID,
                            entry.specID, entry.itemID, isHighTier, true)
                        if verbose then
                            local name = C_Item.GetItemNameByID(entry.itemID) or tostring(entry.itemID)
                            print(string.format(
                                "|cff9370DBVoidcoreAdvisor:|r Replay [%d]: upgraded bare → %s tier for %s (spec=%s)",
                                i, isHighTier and "≥10" or "<10", name, tostring(entry.specID)))
                        end
                    end
                end
                skipped = skipped + 1
                if verbose then
                    local name = C_Item.GetItemNameByID(entry.itemID) or tostring(entry.itemID)
                    print(string.format("|cff9370DBVoidcoreAdvisor:|r Replay [%d]: already obtained — %s (spec=%s)",
                        i, name, tostring(entry.specID)))
                end
            else
                local classID = VCA.SpecInfo and VCA.SpecInfo.GetPlayerClassID and VCA.SpecInfo.GetPlayerClassID()
                local cachedPool = classID and VCA.LootPool and VCA.LootPool.GetCachedItemsForClass and
                                       VCA.LootPool
                                           .GetCachedItemsForClass(source.sourceType, source.sourceID,
                        source.difficultyID, classID)
                local inPool = false
                if cachedPool then
                    for _, id in ipairs(cachedPool) do
                        if id == entry.itemID then
                            inPool = true;
                            break
                        end
                    end
                end
                if verbose then
                    local name = C_Item.GetItemNameByID(entry.itemID) or tostring(entry.itemID)
                    print(string.format(
                        "|cff9370DBVoidcoreAdvisor:|r Replay [%d]: %s spec=%s source=%s:%s — classID=%s poolSize=%s inPool=%s",
                        i, name, tostring(entry.specID), source.sourceType, tostring(source.sourceID),
                        tostring(classID), cachedPool and tostring(#cachedPool) or "nil", tostring(inPool)))
                end
                if TryResolveReward(entry.itemID, source, entry.specID) then
                    marked = marked + 1
                    -- Detect a cycle reset: if the item we just marked is no longer
                    -- obtained, CheckAndResetIfComplete fired and cleared the pool.
                    if verbose and
                        not VCA.Data
                            .IsObtained(source.sourceType, source.sourceID, source.difficultyID, entry.specID,
                            entry.itemID) then
                        print(string.format(
                            "|cff9370DBVoidcoreAdvisor:|r Replay [%d]: pool complete — cycle reset for spec %s.", i,
                            tostring(entry.specID)))
                    end
                else
                    nomatch = nomatch + 1
                end
            end
        end
    end
    if verbose then
        print(string.format(
            "|cff9370DBVoidcoreAdvisor:|r Replay complete: %d marked, %d already obtained, %d not in pool, %d incomplete.",
            marked, skipped, nomatch, incomplete))
    end
end

local function QueuePendingReward(itemID, source, specID)
    if not itemID then
        return
    end

    pendingRewards[#pendingRewards + 1] = {
        itemID = itemID,
        source = source,
        specID = specID
    }
end

local function ProcessPendingRewards()
    if #pendingRewards == 0 then
        return
    end

    local remaining = {}
    for _, entry in ipairs(pendingRewards) do
        local source = entry.source or GetResolvedSource()
        if not TryResolveReward(entry.itemID, source, entry.specID) then
            remaining[#remaining + 1] = {
                itemID = entry.itemID,
                source = source,
                specID = entry.specID
            }
        end
    end

    pendingRewards = remaining
end

local function ProcessRewardItem(itemID, specID, sourceHint)
    if not itemID then
        return
    end

    -- Prefer a source captured at event time; fall back to live resolution.
    local source = sourceHint or GetResolvedSource()
    if TryResolveReward(itemID, source, specID) then
        return
    end

    if IsInInstancedContent() then
        QueuePendingReward(itemID, source, specID)
        return
    end

    QueuePendingReward(itemID, source, specID)
    ProcessPendingRewards()
end

-- -- Event frame --------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BONUS_ROLL_RESULT")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_COMPLETED" then
        -- Snapshot the key level while GetActiveKeystoneInfo() is still valid.
        -- This must happen before the keystone is consumed/upgraded so that
        -- the fallback path in ResolveCurrentMythicPlusSource() has reliable data
        -- when BONUS_ROLL_RESULT fires after the run ends.
        if C_ChallengeMode then
            local level = C_ChallengeMode.GetActiveKeystoneInfo()
            if level and level > 0 then
                cachedKeyLevel = level
                local instanceName = GetInstanceInfo()
                print(string.format("|cff9370DBVoidcoreAdvisor:|r Key detected - %s +%d.", instanceName or "Unknown",
                    cachedKeyLevel))
            end
        end
        return
    end

    if event == "CHALLENGE_MODE_RESET" then
        cachedKeyLevel = nil
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        -- ZONE_CHANGED_NEW_AREA fires inside a dungeon when challenge mode
        -- transitions from active → completed, before BONUS_ROLL_RESULT fires.
        -- Only clear the cached key level once the player has actually left the
        -- instance; PLAYER_ENTERING_WORLD is an unconditional clear because it
        -- always represents a full cross-zone load screen.
        if event == "PLAYER_ENTERING_WORLD" or not IsInInstancedContent() then
            cachedKeyLevel = nil
        end
        Detection.ClearActiveSource()
        if not IsInInstancedContent() then
            C_Timer.After(0, ProcessPendingRewards)
        end
        return
    end

    if event ~= "BONUS_ROLL_RESULT" then
        return
    end

    local typeIdentifier, itemLink, quantity, specID = ...
    if typeIdentifier ~= "item" then
        return
    end
    if type(itemLink) ~= "string" then
        return
    end

    local idStr = itemLink:match("|Hitem:(%d+):")
    local itemID = idStr and tonumber(idStr)
    if not itemID then
        return
    end

    -- specID is provided directly by the event payload.  Fall back to the
    -- effective loot spec only if the event omits it (future-proofing).
    if not specID or specID == 0 then
        specID = VCA.SpecInfo and VCA.SpecInfo.GetEffectiveLootSpecID and VCA.SpecInfo.GetEffectiveLootSpecID()
    end

    -- Capture source immediately at event time — GetInstanceInfo() may return
    -- a different state one frame later (e.g. after run completion), causing
    -- ResolveCurrentMythicPlusSource to return nil and silently drop detection.
    local capturedSource = GetResolvedSource()

    -- Persist a raw log entry immediately so the player can manually verify
    -- which items fired if auto-detection later fails to match them.
    if VCA.Data and VCA.Data.LogBonusRoll then
        VCA.Data.LogBonusRoll(itemID, itemLink, specID, capturedSource)
    end

    C_Timer.After(0, function()
        ProcessRewardItem(itemID, specID, capturedSource)
        -- Replay the full log as a safety net: if ProcessRewardItem still missed
        -- the item (e.g. cache was not yet populated), the log entry has the
        -- correct source and will match now that the cache is warm.
        Detection.ReplayBonusRollLog(false)
    end)
end)
