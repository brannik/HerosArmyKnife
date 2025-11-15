local addonName, addon = ...

-- No settings yet; if needed later use addon:RegisterInit similar to other modules.

local function OnClick(btn)
    ReloadUI()
end

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('Reload', { debug = false }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.Reload or { debug = false }
end

local function OnTooltip(btn)
    local lines = {
        "Reload UI",
        "Click to perform /reload (refresh interface).",
        "Useful after editing addons or fixing taint.",
    }
    if GetSettings().debug then table.insert(lines, "Debug: Enabled") end
    return lines
end

addon:RegisterToolbarIcon("Reload", "Interface\\Buttons\\UI-RefreshButton", OnClick, OnTooltip)

-- Module-specific options panel (simple description)
addon:RegisterInit(function()
    if addon.GetModuleSettings then addon:GetModuleSettings('Reload', { debug = false }) end
end)

if addon.RegisterModuleOptions then
    addon:RegisterModuleOptions("Reload", function(panel)
        local debugSection = addon:CreateSection(panel, "Debug")
        local cb = CreateFrame("CheckButton", "HAK_Reload_DebugCB", debugSection, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", debugSection, "TOPLEFT", 0, 0)
        _G[cb:GetName() .. "Text"]:SetText("Enable debug info")
        cb:SetChecked(GetSettings().debug)
        cb:SetScript("OnClick", function(self)
            local s = GetSettings(); s.debug = self:GetChecked() and true or false
        end)
    end)
end
