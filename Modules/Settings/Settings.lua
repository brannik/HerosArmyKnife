local addonName, addon = ...

addon:RegisterInit(function()
    if addon.GetModuleSettings then addon:GetModuleSettings('Settings', { debug = false }) end
end)

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('Settings', { debug = false }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.Settings or { debug = false }
end

local function OnClick(btn)
    if InterfaceOptionsFrame then
        InterfaceOptionsFrame_OpenToCategory("HerosArmyKnife")
        InterfaceOptionsFrame_OpenToCategory("HerosArmyKnife")
    end
end

local function OnTooltip(btn)
    local lines = {
        "Settings",
        "Click: Open HerosArmyKnife options panel.",
    }
    if GetSettings().debug then table.insert(lines, "Debug: Enabled") end
    return lines
end

-- Updated to a distinct gear icon
-- Gear cog replaced with more distinct gizmo icon
addon:RegisterToolbarIcon("Settings", "Interface\\Icons\\INV_Gizmo_02", OnClick, OnTooltip)

if addon.RegisterModuleOptions then
    addon:RegisterModuleOptions("Settings", function(panel)
        local debugSection = addon:CreateSection(panel, "Debug")
        local cb = CreateFrame("CheckButton", "HAK_Settings_DebugCB", debugSection, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", debugSection, "TOPLEFT", 0, 0)
        _G[cb:GetName() .. "Text"]:SetText("Enable debug info")
        cb:SetChecked(GetSettings().debug)
        cb:SetScript("OnClick", function(self)
            local s = GetSettings(); s.debug = self:GetChecked() and true or false
        end)
    end)
end
