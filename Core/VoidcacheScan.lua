-- VoidcoreAdvisor: VoidcacheScan
-- Scans the Nebulous Voidcache tooltip for each of the player's loot
-- specializations to determine which items are obtainable per spec per
-- dungeon.  Items the player cannot receive with a given spec are then
-- marked as obtained so they no longer appear in the tracker.
--
-- Scanning sequence (outer = spec, inner = dungeon) ensures the same
-- Voidcache item ID is never read on two consecutive tooltip calls, which
-- avoids the client cache returning stale spec data.
--
-- If a tooltip returns fewer than MIN_LINES lines it is retried in-place
-- with a small delay (up to MAX_RETRIES times) before moving on.
local _, VCA = ...

VCA.VoidcacheScan = {}
local Scan = VCA.VoidcacheScan

-- ── Tuning constants ──────────────────────────────────────────────────────────

local MAX_RETRIES = 5 -- per (spec, dungeon) pair before giving up
local RETRY_DELAY = 0.35 -- seconds between retries for the same item
local STEP_DELAY = 0.5 -- seconds between successful scan steps (slowed for readable logs)
local SPEC_CHANGE_DELAY = 1.2 -- seconds to wait after SetLootSpecialization
local MIN_LINES = 7 -- minimum tooltip lines required for a valid read

-- ── Logging ───────────────────────────────────────────────────────────────────

local function Log(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff9090ff[VCA Scan]|r " .. tostring(msg))
end

-- ── Combat-interrupt frame ────────────────────────────────────────────────────

local _combatFrame = CreateFrame("Frame")

-- ── Scan state ────────────────────────────────────────────────────────────────
-- nil when idle, table when a scan is running.

local _state = nil

-- ── Progress callback ─────────────────────────────────────────────────────────
-- Signature: fn(specIdx, specCount, dungeonIdx, dungeonCount, status)
--   During scan: specIdx/specCount/dungeonIdx/dungeonCount are numbers, status is nil.
--   On finish:   all four numbers are nil, status is "COMPLETE", "ABORTED", or "COMBAT".

local _progressCallback = nil

function Scan.SetProgressCallback(fn)
    _progressCallback = fn
end

local function NotifyProgress(specIdx, specCount, dungeonIdx, dungeonCount, status)
    if _progressCallback then
        _progressCallback(specIdx, specCount, dungeonIdx, dungeonCount, status)
    end
end

-- ── Tooltip parsing ───────────────────────────────────────────────────────────

local function StripColorCodes(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Reads tooltip data from C_TooltipInfo and collects item names from line 7+.
-- Each item line is prefixed with "- " which is stripped to get the bare name.
-- Returns a { [itemName] = true } set, or nil when the data is missing or thin.
local function ParseVoidcacheTooltip(tooltipData, numLines, logLines)
    if numLines < MIN_LINES then
        return nil
    end
    local items = {}
    for i, lineData in ipairs(tooltipData.lines) do
        local text = lineData.leftText
        if text then
            if logLines then
                Log(string.format("  line %d: %q", i, text))
            end
            -- Item entries start at line 7, each prefixed with "- "
            if i >= 7 then
                local clean = StripColorCodes(text)
                if clean:sub(1, 2) == "- " then
                    local itemName = clean:sub(3):match("^(.-)%s*$")
                    if itemName and itemName ~= "" then
                        items[itemName] = true
                    end
                end
            end
        end
    end
    return items
end

-- ── Name cache ────────────────────────────────────────────────────────────────

-- Returns { [localizedName] = itemID } for every item a specific spec can get
-- from the dungeon's Voidcache.  Relies on the item cache being warm.
local function BuildDungeonNameCache(instanceID, specID)
    local dungeonData = VCA.SeasonData and VCA.SeasonData.dungeons[instanceID]
    if not dungeonData then
        return {}
    end
    local itemIDs = (dungeonData.bySpec and dungeonData.bySpec[specID]) or {}
    local nameCache = {}
    local missing = 0
    for _, itemID in ipairs(itemIDs) do
        local name = GetItemInfo(itemID)
        if name and name ~= "" then
            nameCache[name] = itemID
        else
            missing = missing + 1
        end
    end
    local total = #itemIDs
    Log(string.format("  nameCache[%d] spec %d: %d/%d items resolved (%d missing from cache)", instanceID, specID,
        total - missing, total, missing))
    return nameCache
end

-- ── Public: availability check ────────────────────────────────────────────────

-- Returns true (or false, reason) indicating whether a scan can start now.
-- reason is "COMBAT" or "INSTANCE".
function Scan.CanScan()
    if InCombatLockdown() then
        return false, "COMBAT"
    end
    local _, instanceType = IsInInstance()
    if instanceType and instanceType ~= "none" then
        return false, "INSTANCE"
    end
    return true
end

function Scan.IsRunning()
    return _state ~= nil and _state.running == true
end

-- ── Abort ─────────────────────────────────────────────────────────────────────

local function AbortScan(reason)
    if not _state then
        return
    end
    _state.running = false

    -- Restore the player's original loot spec.
    if _state.originalLootSpec ~= nil then
        SetLootSpecialization(_state.originalLootSpec)
    end

    _combatFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")

    NotifyProgress(nil, nil, nil, nil, reason or "ABORTED")
    _state = nil
end

-- ── Result application ────────────────────────────────────────────────────────

local function FinalizeScan()
    if not _state then
        return
    end

    local results = _state.results -- [specID][instanceID] = { [name]=true }
    local nameCaches = _state.nameCaches -- [specID][instanceID] = { [name]=itemID }
    local specs = _state.specs -- { {specID=N, index=I}, ... }

    local db = _G[VCA.CHAR_DB_NAME]
    if not db then
        AbortScan("NO_DB")
        return
    end

    local diffID = VCA.MythicPlusEJDifficulty
    local contentType = VCA.ContentType.MYTHIC_PLUS

    -- 1. Clear all existing MYTHIC_PLUS obtained entries — the scan result is now authoritative.
    db.obtained = db.obtained or {}
    for key in pairs(db.obtained) do
        if key:sub(1, 12) == "MYTHIC_PLUS:" then
            db.obtained[key] = nil
        end
    end

    -- 2. Apply scan results for every season dungeon.
    local instanceIDs = VCA.LootPool.GetSeasonDungeonInstanceIDs()
    local totalMarked = 0

    -- Dump raw scan-result sizes so we can spot empty reads immediately.
    Log("── Scan result sizes (spec × dungeon):")
    for _, specEntry in ipairs(specs) do
        local _, specName = GetSpecializationInfo(specEntry.index)
        for _, instanceID in ipairs(instanceIDs) do
            local specItems = results[specEntry.specID] and results[specEntry.specID][instanceID]
            local count = 0
            if specItems then
                for _ in pairs(specItems) do
                    count = count + 1
                end
            end
            Log(string.format("  spec %-20s instance %d → %d items", tostring(specName), instanceID, count))
        end
    end

    -- Apply results per-spec so each spec is only judged against its own item pool.
    for _, specEntry in ipairs(specs) do
        local specID = specEntry.specID
        local _, specName = GetSpecializationInfo(specEntry.index)
        local specResults = results[specID] or {}
        local specCaches = nameCaches[specID] or {}

        for _, instanceID in ipairs(instanceIDs) do
            local nameCache = specCaches[instanceID] or {}
            local specItems = specResults[instanceID] or {}
            local ncSize = 0
            for _ in pairs(nameCache) do
                ncSize = ncSize + 1
            end
            Log(string.format("Applying results for spec %s instance %d (%d items in nameCache)", tostring(specName),
                instanceID, ncSize))

            for itemName, itemID in pairs(nameCache) do
                if specItems[itemName] then
                    -- Item appeared in this spec's tooltip scan — lootable, leave as-is.
                    Log(string.format("  LOOTABLE id %d (%s) spec %s", itemID, itemName, tostring(specName)))
                else
                    -- Item is in this spec's pool but was NOT seen in the scan.
                    totalMarked = totalMarked + 1
                    Log(string.format("  OBTAINED id %d (%s) for spec %s — not in scan results", itemID, itemName,
                        tostring(specName)))
                    VCA.Data.SetObtained(contentType, instanceID, diffID, specID, itemID, true)
                end
            end

        end
    end

    Log(string.format("Finalize complete: %d spec/item combos marked as obtained.", totalMarked))

    -- 3. Restore original loot spec.
    SetLootSpecialization(_state.originalLootSpec or 0)
    _combatFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")

    NotifyProgress(nil, nil, nil, nil, "COMPLETE")

    -- Refresh any open panels.
    if VCA.DungeonOverview and VCA.DungeonOverview.Refresh then
        VCA.DungeonOverview.Refresh()
    end

    _state = nil
end

-- ── Scan step ─────────────────────────────────────────────────────────────────

local ScanStep -- forward declaration

ScanStep = function()
    if not _state or not _state.running then
        return
    end

    -- All specs done → apply results.
    if _state.specIdx > #_state.specs then
        FinalizeScan()
        return
    end

    local specEntry = _state.specs[_state.specIdx]
    local dungeonEntry = _state.dungeons[_state.dungeonIdx]

    -- Set loot spec at the start of each new spec pass (first dungeon, no retries).
    if _state.dungeonIdx == 1 and _state.retries == 0 then
        if not _state.specSwitchDone then
            -- Request the spec change and wait for it to apply before reading tooltips.
            local _, specName = GetSpecializationInfo(specEntry.index)
            Log(string.format("── Spec pass %d/%d: %s (specID %d) — waiting %.1fs for spec change...",
                _state.specIdx, #_state.specs, tostring(specName), specEntry.specID, SPEC_CHANGE_DELAY))
            SetLootSpecialization(specEntry.specID)
            _state.specSwitchDone = true
            C_Timer.After(SPEC_CHANGE_DELAY, ScanStep)
            return
        end
        -- Spec change has been applied; clear flag so the next spec gets its own delay.
        _state.specSwitchDone = false
    end

    -- Read the Voidcache tooltip via C_TooltipInfo (pure data call, no frame needed).
    local tooltipData = C_TooltipInfo.GetItemByID(dungeonEntry.voidcacheID)
    local numLines = (tooltipData and tooltipData.lines) and #tooltipData.lines or 0
    -- Log raw lines only on the first attempt of the first spec to show the actual format.
    local logLines = (_state.specIdx == 1 and _state.retries == 0)
    local parsed = ParseVoidcacheTooltip(tooltipData, numLines, logLines)

    if not parsed then
        -- Not enough lines yet — retry in place.
        _state.retries = _state.retries + 1
        Log(string.format("  instance %d (voidcache %d): only %d lines, retry %d/%d", dungeonEntry.instanceID,
            dungeonEntry.voidcacheID, numLines, _state.retries, MAX_RETRIES))
        if _state.retries <= MAX_RETRIES then
            C_Timer.After(RETRY_DELAY, ScanStep)
            return
        end
        Log(string.format("  instance %d: max retries exhausted, storing empty result", dungeonEntry.instanceID))
        parsed = {}
    end

    -- First successful read — do one confirmation pass to catch any lines that
    -- may have been missing at the tail of the tooltip.
    if not _state.confirmPending then
        local firstCount = 0
        for _ in pairs(parsed) do
            firstCount = firstCount + 1
        end
        Log(string.format("  instance %d: first read OK (%d lines, %d items) — confirming...",
            dungeonEntry.instanceID, numLines, firstCount))
        _state.confirmPending = true
        _state.confirmResult = parsed
        C_Timer.After(RETRY_DELAY, ScanStep)
        return
    end

    -- Confirmation pass — merge both reads (union) so no item is missed.
    local merged = {}
    for k, v in pairs(_state.confirmResult) do
        merged[k] = v
    end
    for k, v in pairs(parsed) do
        merged[k] = v
    end
    local firstCount, secondCount, mergedCount = 0, 0, 0
    for _ in pairs(_state.confirmResult) do
        firstCount = firstCount + 1
    end
    for _ in pairs(parsed) do
        secondCount = secondCount + 1
    end
    for _ in pairs(merged) do
        mergedCount = mergedCount + 1
    end
    Log(string.format("  instance %d: confirm read %d items (first %d, second %d) → merged %d",
        dungeonEntry.instanceID, secondCount, firstCount, secondCount, mergedCount))
    parsed = merged
    _state.confirmPending = false
    _state.confirmResult = nil

    local itemCount = 0
    for _ in pairs(parsed) do
        itemCount = itemCount + 1
    end
    Log(string.format("  instance %d (voidcache %d): %d lines → %d items parsed", dungeonEntry.instanceID,
        dungeonEntry.voidcacheID, numLines, itemCount))

    -- Log each parsed name and the itemID it resolves to in the name cache.
    local nameCache = (_state.nameCaches[specEntry.specID] or {})[dungeonEntry.instanceID] or {}
    for itemName in pairs(parsed) do
        local resolvedID = nameCache[itemName]
        if resolvedID then
            Log(string.format("    MATCH  %q → id %d", itemName, resolvedID))
        else
            Log(string.format("    NOMATCH %q (not in nameCache)", itemName))
        end
    end
    -- Log nameCache entries that had no match in the parsed tooltip.
    for cachedName, cachedID in pairs(nameCache) do
        if not parsed[cachedName] then
            Log(string.format("    NOTFOUND id %d %q", cachedID, cachedName))
        end
    end

    -- Store result.
    _state.results[specEntry.specID] = _state.results[specEntry.specID] or {}
    _state.results[specEntry.specID][dungeonEntry.instanceID] = parsed
    _state.retries = 0
    _state.confirmPending = false
    _state.confirmResult = nil

    -- Advance position.
    _state.dungeonIdx = _state.dungeonIdx + 1
    if _state.dungeonIdx > #_state.dungeons then
        _state.dungeonIdx = 1
        _state.specIdx = _state.specIdx + 1
    end

    -- Notify progress (may call into DungeonOverview to update button text).
    NotifyProgress(_state.specIdx, #_state.specs, _state.dungeonIdx, #_state.dungeons, nil)

    C_Timer.After(STEP_DELAY, ScanStep)
end

-- ── Public: start ─────────────────────────────────────────────────────────────

function Scan.Start()
    local canScan, reason = Scan.CanScan()
    if not canScan then
        return false, reason
    end
    if Scan.IsRunning() then
        return false, "RUNNING"
    end
    if not VCA.SeasonData then
        return false, "NO_SEASON_DATA"
    end

    -- Build spec list from the current player's available specializations.
    local numSpecs = GetNumSpecializations()
    local specs = {}
    for i = 1, numSpecs do
        local specID = GetSpecializationInfo(i)
        if specID and specID > 0 then
            specs[#specs + 1] = {
                specID = specID,
                index = i
            }
        end
    end
    if #specs == 0 then
        return false, "NO_SPECS"
    end

    -- Build dungeon list restricted to dungeons that have a known Voidcache ID.
    local instanceIDs = VCA.LootPool.GetSeasonDungeonInstanceIDs()
    local dungeons = {}
    for _, instanceID in ipairs(instanceIDs) do
        local voidcacheID = VCA.DungeonVoidcacheIDs and VCA.DungeonVoidcacheIDs[instanceID]
        if voidcacheID then
            dungeons[#dungeons + 1] = {
                instanceID = instanceID,
                voidcacheID = voidcacheID
            }
        end
    end
    if #dungeons == 0 then
        return false, "NO_DUNGEONS"
    end

    -- Pre-build name caches per spec (requires item cache to be warm).
    Log(string.format("Starting scan: %d spec(s), %d dungeon(s)", #specs, #dungeons))
    for _, specEntry in ipairs(specs) do
        local _, specName = GetSpecializationInfo(specEntry.index)
        Log(string.format("  spec: %s (id %d)", tostring(specName), specEntry.specID))
    end
    local nameCaches = {} -- [specID][instanceID] = { [name]=itemID }
    for _, specEntry in ipairs(specs) do
        nameCaches[specEntry.specID] = {}
        for _, dungeonEntry in ipairs(dungeons) do
            nameCaches[specEntry.specID][dungeonEntry.instanceID] =
                BuildDungeonNameCache(dungeonEntry.instanceID, specEntry.specID)
        end
    end

    -- Initialise state.
    _state = {
        running = true,
        specs = specs,
        dungeons = dungeons,
        specIdx = 1,
        dungeonIdx = 1,
        retries = 0,
        confirmPending = false,
        confirmResult = nil,
        specSwitchDone = false,
        results = {},
        nameCaches = nameCaches,
        originalLootSpec = GetLootSpecialization()
    }

    -- Register combat guard.
    _combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

    -- Fire initial progress notification, then begin.
    NotifyProgress(1, #specs, 1, #dungeons, nil)
    C_Timer.After(0, ScanStep)

    return true
end

-- ── Combat guard ──────────────────────────────────────────────────────────────

_combatFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" and _state and _state.running then
        AbortScan("COMBAT")
    end
end)
