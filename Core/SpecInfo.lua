-- VoidcoreAdvisor: SpecInfo
-- Helpers for querying the player's available specializations and current
-- loot specialization setting.  Wraps GetSpecializationInfo and
-- GetLootSpecialization so the rest of the addon has a clean, testable API.

local _, VCA = ...

VCA.SpecInfo = {}
local SpecInfo = VCA.SpecInfo

-- ── Player class ──────────────────────────────────────────────────────────────

-- Returns the numeric class ID for the current player.
function SpecInfo.GetPlayerClassID()
    local _, _, classID = UnitClass("player")
    return classID
end

-- ── Specializations ───────────────────────────────────────────────────────────

-- Returns an array of spec info tables for every specialization available to
-- the current player's class.
--
-- Each entry:
--   {
--     specID      = number,   -- the numeric specialization ID
--     specIndex   = number,   -- 1-based index within the class (for SetSpecialization)
--     name        = string,
--     description = string,
--     icon        = number,   -- texture fileID
--     role        = string,   -- "TANK", "HEALER", "DAMAGER"
--     classID     = number,
--     className   = string,   -- localized class name (e.g. "Druid")
--     classFile   = string,   -- uppercase token  (e.g. "DRUID")
--   }
function SpecInfo.GetPlayerSpecs()
    local className, classFile, classID = UnitClass("player")
    local numSpecs = GetNumSpecializations()
    local specs = {}
    for i = 1, numSpecs do
        local specID, name, description, icon, role = GetSpecializationInfo(i)
        if specID then
            specs[#specs + 1] = {
                specID      = specID,
                specIndex   = i,
                name        = name,
                description = description,
                icon        = icon,
                role        = role,
                classID     = classID,
                className   = className,
                classFile   = classFile,
            }
        end
    end
    return specs
end

-- ── Loot specialization ───────────────────────────────────────────────────────

-- Returns the raw loot spec ID as configured by the player.
-- Returns 0 if the player has selected "Current Specialization".
function SpecInfo.GetRawLootSpecID()
    return GetLootSpecialization()
end

-- Returns the resolved loot spec ID.
-- If the raw value is 0 (= "use active spec"), this resolves to the player's
-- currently active specialization ID so callers never have to handle 0 themselves.
function SpecInfo.GetEffectiveLootSpecID()
    local lootSpecID = GetLootSpecialization()
    if lootSpecID == 0 then
        local specIndex = GetSpecialization()
        if specIndex then
            local specID = GetSpecializationInfo(specIndex)
            return specID
        end
    end
    return lootSpecID
end

-- Returns true if a specific specID is the player's current effective loot spec.
function SpecInfo.IsActiveLootSpec(specID)
    return SpecInfo.GetEffectiveLootSpecID() == specID
end
