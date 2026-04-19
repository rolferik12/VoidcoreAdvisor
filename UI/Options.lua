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

        local initializer = Settings.CreateCheckbox(category, setting, L["OPTIONS_REMINDER_TOOLTIP"])

        -- Add a "Preview" button on the same row as the checkbox.
        hooksecurefunc(SettingsCheckboxControlMixin, "Init", function(self, init)
            if init == initializer then
                if not self.VCAPreviewButton then
                    local btn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
                    btn:SetSize(100, 22)
                    btn:SetPoint("RIGHT", self, "RIGHT", -16, 0)
                    btn:SetText(L["OPTIONS_PREVIEW_REMINDER"])
                    btn:SetScript("OnClick", function()
                        if VoidcoreAdvisorReminder:IsShown() then
                            VCA.Reminder.Hide()
                        else
                            VCA.Reminder.ShowExample()
                        end
                    end)
                    self.VCAPreviewButton = btn
                end
                self.VCAPreviewButton:Show()
            elseif self.VCAPreviewButton then
                self.VCAPreviewButton:Hide()
            end
        end)
    end

    -- ── Finish ────────────────────────────────────────────────────────────
    Settings.RegisterAddOnCategory(category)
end)
