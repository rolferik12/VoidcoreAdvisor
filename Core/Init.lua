-- VoidcoreAdvisor: Init
-- Bootstrap: SavedVariables initialisation, login event handling, and
-- the public slash-command interface.  Loaded last so every other module
-- is available when this code runs.

local addonName, VCA = ...
local L = VCA.L

-- ── SavedVariables defaults ───────────────────────────────────────────────────

local function GetDefaults()
    return {
        schemaVersion = VCA.SCHEMA_VERSION,
        obtained      = {},
        selectedItems = {},   -- { ["TYPE:sourceID:diffID"] = { [itemID]=true, ... } }
    }
end

-- Apply any future schema migrations here.
local function MigrateDB(db)
    if db.schemaVersion == VCA.SCHEMA_VERSION then return end
    -- Example (when SCHEMA_VERSION bumps to 2):
    -- if db.schemaVersion < 2 then
    --     db.newField = {}
    -- end
    db.schemaVersion = VCA.SCHEMA_VERSION
end

local function InitDB()
    if type(_G[VCA.CHAR_DB_NAME]) ~= "table" then
        _G[VCA.CHAR_DB_NAME] = GetDefaults()
    else
        MigrateDB(_G[VCA.CHAR_DB_NAME])
        -- Ensure required top-level keys are present (handles sparse old saves).
        _G[VCA.CHAR_DB_NAME].obtained      = _G[VCA.CHAR_DB_NAME].obtained or {}
        _G[VCA.CHAR_DB_NAME].selectedItems  = _G[VCA.CHAR_DB_NAME].selectedItems or {}
    end
end

-- ── Bootstrap event handler ───────────────────────────────────────────────────

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")

initFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if (...) ~= addonName then return end
        InitDB()
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        -- Game data (class, specs, etc.) is now available.
        -- Notify any future UI layer that the backend is ready.
        if VCA.OnBackendReady then
            VCA.OnBackendReady()
        end
    end
end)

-- ── Public API ────────────────────────────────────────────────────────────────

-- Wipe all obtained item data for this character (exposed to slash command
-- and the UI "Reset" button when it is built).
function VCA.ResetObtainedData()
    _G[VCA.CHAR_DB_NAME] = GetDefaults()
end

-- ── Slash commands ────────────────────────────────────────────────────────────

SLASH_VOIDCOREADVISOR1 = "/vca"
SLASH_VOIDCOREADVISOR2 = "/voidcoreadvisor"

SlashCmdList["VOIDCOREADVISOR"] = function(msg)
    local cmd = (msg:match("^%s*(%S+)") or ""):lower()

    if cmd == "reset" then
        VCA.ResetObtainedData()
        print("|cff9370DBVoidcoreAdvisor:|r " .. L["RESET_CONFIRM"])

    elseif cmd == "count" then
        local count = VCA.Data.GetTotalObtainedCount()
        print("|cff9370DBVoidcoreAdvisor:|r " .. string.format(L["COUNT_FORMAT"], count))

    elseif cmd == "spec" then
        -- Debug: print which spec will be used for loot.
        local specID   = VCA.SpecInfo.GetEffectiveLootSpecID()
        local rawID    = VCA.SpecInfo.GetRawLootSpecID()
        local suffix   = rawID == 0 and L["FOLLOWS_ACTIVE_SPEC"] or ""
        print("|cff9370DBVoidcoreAdvisor:|r " .. string.format(L["SPEC_FORMAT"], specID or "unknown", suffix))

    elseif cmd == "source" then
        -- Debug: print the currently active detection source.
        local src = VCA.Detection.GetActiveSource()
        if src then
            print("|cff9370DBVoidcoreAdvisor:|r " .. string.format(L["SOURCE_FORMAT"],
                  src.sourceType, src.sourceID, src.difficultyID))
        else
            print("|cff9370DBVoidcoreAdvisor:|r " .. L["NO_ACTIVE_SOURCE"])
        end

    elseif cmd == "version" then
        print("|cff9370DBVoidcoreAdvisor:|r " .. string.format(L["VERSION_FORMAT"], VCA.VERSION))

    else
        print("|cff9370DBVoidcoreAdvisor:|r " .. L["HELP_HEADER"])
        print(L["HELP_RESET"])
        print(L["HELP_COUNT"])
        print(L["HELP_SPEC"])
        print(L["HELP_SOURCE"])
        print(L["HELP_VERSION"])
    end
end
