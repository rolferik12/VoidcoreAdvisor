-- VoidcoreAdvisor: Probability
-- Calculates Nebulous Voidcore drop probability for each player spec.
--
-- How probability works:
--   The Voidcore grants one RANDOM item from the pool that matches your loot
--   spec.  Once an item is received it is removed from the pool for that
--   difficulty.  Therefore:
--
--     odds of any specific desired item  =  1 / remaining_pool_size
--
--   A smaller pool is better when you are chasing a specific piece.
--
-- This module exposes two numbers per spec:
--   baseOdds      – 1 / total items for this spec (no accounting for obtained)
--   remainingOdds – 1 / items NOT yet obtained (the live, actionable number)

local _, VCA = ...

VCA.Probability = {}
local Probability = VCA.Probability

-- ── Per-spec calculation ──────────────────────────────────────────────────────

-- Calculates probability data for one spec against one source.
--
-- sourceType   : VCA.ContentType constant
-- sourceID     : encounterID (RAID) or instanceID (MYTHIC_PLUS)
-- difficultyID : EJ difficulty ID
-- classID      : numeric class ID
-- specID       : numeric specialization ID
--
-- Returns:
--   {
--     specID         : number
--     baseCount      : number  – total items available to this spec
--     remainingCount : number  – items not yet obtained
--     baseOdds       : number  – 1/baseCount       (0 if no items)
--     remainingOdds  : number  – 1/remainingCount  (0 if all obtained)
--     allObtained    : bool    – true when every item has been claimed
--     noItems        : bool    – true when this spec has no eligible items
--   }
function Probability.CalculateForSpec(sourceType, sourceID, difficultyID, classID, specID)
    local itemIDs = VCA.LootPool.GetItemsForSpec(sourceType, sourceID, difficultyID, classID, specID)
    local baseCount = #itemIDs

    local remainingCount = 0
    for _, itemID in ipairs(itemIDs) do
        if not VCA.Data.IsObtained(sourceType, sourceID, difficultyID, itemID) then
            remainingCount = remainingCount + 1
        end
    end

    return {
        specID         = specID,
        baseCount      = baseCount,
        remainingCount = remainingCount,
        baseOdds       = baseCount > 0       and (1 / baseCount)       or 0,
        remainingOdds  = remainingCount > 0  and (1 / remainingCount)  or 0,
        allObtained    = baseCount > 0 and remainingCount == 0,
        noItems        = baseCount == 0,
    }
end

-- ── Ranking ───────────────────────────────────────────────────────────────────

-- Ranks a list of specs by probability (best first = smallest remaining pool).
--
-- Sort order:
--   1. Specs with remaining items come before fully-obtained specs.
--   2. Among specs with remaining items: smaller remainingCount is better.
--   3. Tiebreak: smaller baseCount, then specID for stability.
--   4. Specs with NO eligible items (noItems) are always last.
--
-- specs        : array from VCA.SpecInfo.GetPlayerSpecs()
-- sourceType, sourceID, difficultyID : source to evaluate
--
-- Returns: sorted array.  Each entry is the table from CalculateForSpec, plus:
--   { specName, specIcon, specRole, specIndex, rank }
function Probability.RankSpecs(specs, sourceType, sourceID, difficultyID)
    local results = {}
    for _, spec in ipairs(specs) do
        local data = Probability.CalculateForSpec(
            sourceType, sourceID, difficultyID,
            spec.classID, spec.specID
        )
        data.specName  = spec.name
        data.specIcon  = spec.icon
        data.specRole  = spec.role
        data.specIndex = spec.specIndex
        results[#results + 1] = data
    end

    table.sort(results, function(a, b)
        -- Specs with no eligible items drop to the very bottom.
        if a.noItems ~= b.noItems then
            return not a.noItems
        end
        -- Fully-obtained specs come after those with items remaining.
        if a.allObtained ~= b.allObtained then
            return not a.allObtained
        end
        -- Smaller remaining pool = better odds = ranks higher.
        if a.remainingCount ~= b.remainingCount then
            return a.remainingCount < b.remainingCount
        end
        -- Tiebreak by base pool size then spec ID for a stable sort.
        if a.baseCount ~= b.baseCount then
            return a.baseCount < b.baseCount
        end
        return a.specID < b.specID
    end)

    for i, result in ipairs(results) do
        result.rank = i
    end

    return results
end

-- Convenience: rank all specs of the current player for a given source.
-- Returns the sorted array from RankSpecs.
function Probability.RankCurrentPlayerSpecs(sourceType, sourceID, difficultyID)
    local specs = VCA.SpecInfo.GetPlayerSpecs()
    return Probability.RankSpecs(specs, sourceType, sourceID, difficultyID)
end

-- Ranks the current player's specs by how many of the given itemIDs fall into
-- each spec's loot pool at the specified source/difficulty.
--
-- itemIDs     : array of itemID numbers to filter by
-- Returns the same table shape as RankSpecs, but baseCount / remainingCount
-- reflect only the supplied items (not the full pool).
-- Sort order: specs that cover MORE selected items rank first; within equals,
-- fewer remaining (smaller unobtained intersection) ranks higher.
function Probability.RankCurrentPlayerSpecsForItems(itemIDs, sourceType, sourceID, difficultyID)
    local specs = VCA.SpecInfo.GetPlayerSpecs()

    local selectedSet = {}
    for _, id in ipairs(itemIDs) do selectedSet[id] = true end

    local results = {}
    for _, spec in ipairs(specs) do
        local allSpecItemIDs = VCA.LootPool.GetItemsForSpec(
            sourceType, sourceID, difficultyID, spec.classID, spec.specID)

        -- Check if this spec can see any of the selected items.
        local matchCount = 0
        for _, itemID in ipairs(allSpecItemIDs) do
            if selectedSet[itemID] then
                matchCount = matchCount + 1
            end
        end

        -- Full-pool counts drive the probability: the Voidcore rolls from the
        -- entire loot table for this spec, so a smaller remaining pool means a
        -- higher chance that any specific item (including the selected one) drops.
        local baseCount      = #allSpecItemIDs
        local remainingCount = 0
        local matchRemainingCount = 0
        for _, itemID in ipairs(allSpecItemIDs) do
            if not VCA.Data.IsObtained(sourceType, sourceID, difficultyID, itemID) then
                remainingCount = remainingCount + 1
                if selectedSet[itemID] then
                    matchRemainingCount = matchRemainingCount + 1
                end
            end
        end

        local selectedCount = #itemIDs
        results[#results + 1] = {
            specID              = spec.specID,
            specName            = spec.name,
            specIcon            = spec.icon,
            specRole            = spec.role,
            specIndex           = spec.specIndex,
            baseCount           = baseCount,
            remainingCount      = remainingCount,
            matchCount          = matchCount,
            matchRemainingCount = matchRemainingCount,
            baseOdds            = baseCount > 0 and (1 / baseCount) or 0,
            remainingOdds       = remainingCount > 0 and (1 / remainingCount) or 0,
            selectedOdds        = remainingCount > 0 and (matchRemainingCount / remainingCount) or 0,
            allObtained         = baseCount > 0 and remainingCount == 0,
            noItems             = matchCount < selectedCount,  -- spec cannot loot ALL selected items
        }
    end

    table.sort(results, function(a, b)
        if a.noItems ~= b.noItems then return not a.noItems end
        if a.allObtained ~= b.allObtained then return not a.allObtained end
        -- Smaller remaining pool = higher drop chance = ranks higher.
        if a.remainingCount ~= b.remainingCount then return a.remainingCount < b.remainingCount end
        if a.baseCount ~= b.baseCount then return a.baseCount < b.baseCount end
        return a.specID < b.specID
    end)

    for i, r in ipairs(results) do r.rank = i end
    return results
end

-- ── Voidcore cost helper ──────────────────────────────────────────────────────

-- Returns the number of Nebulous Voidcores required for one roll at sourceType.
function Probability.GetVoidcoreCost(sourceType)
    if sourceType == VCA.ContentType.RAID then
        return VCA.VoidcoreCost.RAID
    end
    return VCA.VoidcoreCost.MYTHIC_PLUS
end
