-- VoidcoreAdvisor: Options
-- Registers the addon in the Game Menu → Options → AddOns panel using the
-- Settings API (added in 10.0).

local addonName, VCA = ...
local L = VCA.L

-- ── Register settings on ADDON_LOADED ─────────────────────────────────────────
-- The Settings API must be called after the addon's SavedVariables are loaded.

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    -- Create a vertical-layout category for the AddOns tab.
    local category = Settings.RegisterVerticalLayoutCategory("VoidcoreAdvisor")

    -- ── Loot Spec Reminder toggle ─────────────────────────────────────────
    do
        local variable    = "VoidcoreAdvisor_ReminderEnabled"
        local name        = L["OPTIONS_REMINDER_ENABLE"]
        local variableKey = "reminderEnabled"
        local variableTbl = _G[VCA.GLOBAL_DB_NAME]
        local default     = true

        local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, type(default), name, default)

        Settings.CreateCheckbox(category, setting, L["OPTIONS_REMINDER_TOOLTIP"])
    end

    -- ── Finish ────────────────────────────────────────────────────────────
    Settings.RegisterAddOnCategory(category)
end)
