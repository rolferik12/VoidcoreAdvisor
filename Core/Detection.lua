-- VoidcoreAdvisor: Detection
-- Heuristic auto-detection of items received via a Nebulous Voidcore.
--
-- How it works:
--   1. ENCOUNTER_END (success) or CHALLENGE_MODE_COMPLETED opens a short
--      detection window and captures a bag snapshot.
--   2. CURRENCY_DISPLAY_UPDATE is monitored to confirm a Voidcore was spent.
--   3. For M+, CHAT_MSG_LOOT is parsed and the item link's bonus IDs are
--      checked against the expected upgrade-track bonus ID for the completed
--      key level (looked up from VCA.MythicPlusVaultRewards).
--   4. For raids, the first pool-matching CHAT_MSG_LOOT that arrives after
--      the confirmed currency spend is accepted as the Voidcore item.
--   5. Only ONE item per Voidcore spend is ever detected (one-shot).
--   6. BAG_UPDATE_DELAYED serves as a fallback detector.
--   7. Zone transitions immediately close the window to avoid false positives.
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
local voidcoreSpent      = false -- true once CURRENCY_DISPLAY_UPDATE confirms spend
local voidcoreItemFound  = false -- one-shot: true once Voidcore item is identified
local pendingChatLoot    = {}    -- { {itemID, link, time}, ... } buffered before spend

-- ── Public: source management ─────────────────────────────────────────────────

-- Explicitly sets the active source.  The UI (and ENCOUNTER_END handler) both
-- call this so that manual bag inspection and probability displays know which
-- pool to compare against.
function Detection.SetActiveSource(sourceType, sourceID, difficultyID, keyLevel)
    activeSource = {
        sourceType   = sourceType,
        sourceID     = sourceID,
        difficultyID = difficultyID,
        keyLevel     = keyLevel,   -- M+ key level; nil for raids
    }
end

function Detection.ClearActiveSource()
    activeSource      = nil
    windowEndTime     = 0
    voidcoreSpent     = false
    voidcoreItemFound = false
    wipe(pendingChatLoot)
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
    windowEndTime     = GetTime() + VCA.DETECTION_WINDOW_SECONDS
    voidcoreSpent     = false
    voidcoreItemFound = false
    wipe(pendingChatLoot)
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

    -- Single class-wide query (specID 0 = all specs).  LootPool caches the
    -- result so repeated calls within the detection window are free.
    local classID = VCA.SpecInfo.GetPlayerClassID()
    local itemIDs = VCA.LootPool.GetItemsForClass(
        activeSource.sourceType,
        activeSource.sourceID,
        activeSource.difficultyID,
        classID
    )
    local poolSet = {}
    for _, id in ipairs(itemIDs) do
        poolSet[id] = true
    end

    cachedPoolSet    = poolSet
    cachedPoolSource = key
    return poolSet
end

local function InvalidatePoolCache()
    cachedPoolSet    = nil
    cachedPoolSource = nil
end

-- ── Voidcore spend confirmation ────────────────────────────────────────────────
-- We require the currency to decrease before accepting bag-diff results.
-- This prevents regular encounter drops from being misidentified as Voidcore
-- loot.  For M+ the primary detection path is bonus-ID matching on the item
-- link, but the currency gate is still used as a fallback for BAG_UPDATE_DELAYED.

local function IsVoidcoreConfirmed()
    if not activeSource then return false end
    return voidcoreSpent
end

-- ── Item detection ────────────────────────────────────────────────────────────

local function OnCandidateItemDetected(itemID)
    if not activeSource then return end
    if voidcoreItemFound then return end  -- one Voidcore = one item
    if VCA.Data.IsObtained(activeSource.sourceType, activeSource.sourceID,
                            activeSource.difficultyID, itemID) then
        return  -- already known; nothing to do
    end
    VCA.Data.SetObtained(activeSource.sourceType, activeSource.sourceID,
                          activeSource.difficultyID, itemID, true)
    voidcoreItemFound = true  -- one-shot: no further detections this window
    if onDetectedCallback then
        onDetectedCallback(itemID, activeSource)
    end
end

-- ── Link parsing ──────────────────────────────────────────────────────────────
-- Parses loot messages and item-link bonus IDs to identify Voidcore rewards.

-- Extracts bonus IDs from an item hyperlink string as a set.
-- Link format: |Hitem:id:ench:g1:g2:g3:g4:suf:uniq:lvl:spec:upg:inst:nBonus:b1:b2:…|h
local function ParseBonusIDsFromLink(link)
    local itemString = link:match("|Hitem:([^|]+)|")
    if not itemString then return {} end
    local parts = { strsplit(":", itemString) }
    local numBonus = tonumber(parts[13]) or 0
    local set = {}
    for i = 1, numBonus do
        local id = tonumber(parts[13 + i])
        if id then
            set[id] = true
        end
    end
    return set
end

-- Returns the expected Voidcore reward bonus ID for the active M+ key level.
local function GetExpectedMPlusBonusID()
    if not activeSource or not activeSource.keyLevel then return nil end
    local reward = VCA.MythicPlusVaultRewards[math.min(activeSource.keyLevel, 10)]
    return reward and reward.bonusID
end

-- Returns true if the item link contains the expected Voidcore track bonus ID.
local function LinkHasVoidcoreBonusID(link)
    local expected = GetExpectedMPlusBonusID()
    if not expected then return false end
    return ParseBonusIDsFromLink(link)[expected] == true
end

-- Extracts { {itemID, link}, … } pairs from a CHAT_MSG_LOOT message.
local function ParseLootEntriesFromChatMsg(msg)
    local entries = {}
    for link in msg:gmatch("|Hitem:[^|]+|h[^|]*|h") do
        local idStr = link:match("|Hitem:(%d+):")
        if idStr then
            entries[#entries + 1] = { itemID = tonumber(idStr), link = link }
        end
    end
    return entries
end

-- Scans bags for the first slot containing itemID and returns its item link.
-- Used as a fallback when BAG_UPDATE_DELAYED fires but CHAT_MSG_LOOT was missed.
local function FindBagItemLink(itemID)
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                return C_Container.GetContainerItemLink(bag, slot)
            end
        end
    end
    return nil
end

-- ── Event frame ───────────────────────────────────────────────────────────────

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    -- ── Encounter completed (raid boss kill) ──────────────────────────────
    if event == "ENCOUNTER_END" then
        local encounterID, _, difficultyID, _, endStatus = ...
        if endStatus ~= 1 then return end  -- 1 = success / kill
        -- Inside an active M+ key, individual boss kills are irrelevant —
        -- detection is handled by CHALLENGE_MODE_COMPLETED instead.
        if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
           and C_ChallengeMode.GetActiveChallengeMapID() then
            return
        end
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
            local keyLevel
            if C_ChallengeMode.GetActiveKeystoneInfo then
                keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
            end
            Detection.SetActiveSource(
                VCA.ContentType.MYTHIC_PLUS,
                mapID,
                VCA.MythicPlusEJDifficulty,
                keyLevel
            )
            InvalidatePoolCache()
            bagSnapshot = SnapshotBags()
            OpenWindow()
        end

    -- ── Voidcore currency spent ────────────────────────────────────────────
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        if not IsWindowOpen() or not activeSource then return end
        local currencyType, _, quantityChange = ...
        if currencyType == VCA.VOIDCORE_CURRENCY_ID and quantityChange and quantityChange < 0 then
            voidcoreSpent = true
            -- Replay any pool-matching loot buffered in the same frame (edge
            -- case where CHAT_MSG_LOOT fired just before this event).
            if activeSource.sourceType == VCA.ContentType.RAID and not voidcoreItemFound then
                local spendTime = GetTime()
                local poolSet   = GetActivePoolSet()
                for _, entry in ipairs(pendingChatLoot) do
                    if entry.time >= spendTime and poolSet[entry.itemID] then
                        OnCandidateItemDetected(entry.itemID)
                        break
                    end
                end
            end
            wipe(pendingChatLoot)
        end

    -- ── Bag change settled (fallback detector) ────────────────────────────
    elseif event == "BAG_UPDATE_DELAYED" then
        if not IsWindowOpen() or not activeSource then return end
        if not IsVoidcoreConfirmed() or voidcoreItemFound then return end
        local currentSnap = SnapshotBags()
        local newItems    = DiffSnapshots(bagSnapshot, currentSnap)
        if #newItems == 0 then return end
        local poolSet = GetActivePoolSet()
        for _, itemID in ipairs(newItems) do
            if poolSet[itemID] then
                if activeSource.sourceType == VCA.ContentType.MYTHIC_PLUS then
                    -- M+: verify the bag item link has the Voidcore bonus ID.
                    local link = FindBagItemLink(itemID)
                    if link and LinkHasVoidcoreBonusID(link) then
                        OnCandidateItemDetected(itemID)
                    end
                else
                    -- Raid fallback: accept first pool match post-spend.
                    OnCandidateItemDetected(itemID)
                end
                if voidcoreItemFound then break end
            end
        end
        -- Update snapshot so repeated BAG_UPDATE_DELAYED don't re-fire.
        bagSnapshot = currentSnap

    -- ── Chat loot message (primary detector) ──────────────────────────────
    elseif event == "CHAT_MSG_LOOT" then
        if not IsWindowOpen() or not activeSource then return end
        if voidcoreItemFound then return end
        local msg     = ...
        local poolSet = GetActivePoolSet()
        for _, entry in ipairs(ParseLootEntriesFromChatMsg(msg)) do
            if poolSet[entry.itemID] then
                if activeSource.sourceType == VCA.ContentType.MYTHIC_PLUS then
                    -- M+: bonus ID on the link is definitive.
                    if LinkHasVoidcoreBonusID(entry.link) then
                        OnCandidateItemDetected(entry.itemID)
                        return
                    end
                elseif activeSource.sourceType == VCA.ContentType.RAID then
                    if voidcoreSpent then
                        -- Currency already spent — first pool match is accepted.
                        OnCandidateItemDetected(entry.itemID)
                        return
                    else
                        -- Not yet spent — buffer for replay on currency event.
                        pendingChatLoot[#pendingChatLoot + 1] = {
                            itemID = entry.itemID,
                            link   = entry.link,
                            time   = GetTime(),
                        }
                    end
                end
            end
        end

    -- ── Zone transition: close window to prevent cross-zone false positives ─
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        windowEndTime     = 0
        bagSnapshot       = {}
        voidcoreSpent     = false
        voidcoreItemFound = false
        wipe(pendingChatLoot)
    end
end)
