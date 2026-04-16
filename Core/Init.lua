-- VoidcoreAdvisor: Init
-- Bootstrap: SavedVariables initialisation, login event handling, and
-- the public slash-command interface.  Loaded last so every other module
-- is available when this code runs.

local addonName, VCA = ...

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
        print("|cff9370DBVoidcoreAdvisor:|r All obtained-item data has been reset.")

    elseif cmd == "count" then
        local count = VCA.Data.GetTotalObtainedCount()
        print("|cff9370DBVoidcoreAdvisor:|r " .. count .. " item(s) marked as obtained via Voidcore.")

    elseif cmd == "spec" then
        -- Debug: print which spec will be used for loot.
        local specID   = VCA.SpecInfo.GetEffectiveLootSpecID()
        local rawID    = VCA.SpecInfo.GetRawLootSpecID()
        local suffix   = rawID == 0 and " (follows active spec)" or ""
        print("|cff9370DBVoidcoreAdvisor:|r Effective loot spec ID: " .. (specID or "unknown") .. suffix)

    elseif cmd == "source" then
        -- Debug: print the currently active detection source.
        local src = VCA.Detection.GetActiveSource()
        if src then
            print("|cff9370DBVoidcoreAdvisor:|r Active source — type: " .. src.sourceType ..
                  "  sourceID: " .. src.sourceID ..
                  "  difficulty: " .. src.difficultyID)
        else
            print("|cff9370DBVoidcoreAdvisor:|r No active source set.")
        end

    elseif cmd == "version" then
        print("|cff9370DBVoidcoreAdvisor:|r Version " .. VCA.VERSION)

    else
        print("|cff9370DBVoidcoreAdvisor:|r Commands:")
        print("  /vca reset    – clear all obtained-item data")
        print("  /vca count    – show total items marked as obtained")
        print("  /vca spec     – show effective loot spec ID")
        print("  /vca source   – show active detection source")
        print("  /vca version  – show addon version")
    end
end
