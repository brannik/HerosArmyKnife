local addonName, addon = ...


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
    return lines
end

-- Updated to a distinct gear icon
-- Gear cog replaced with more distinct gizmo icon
addon:RegisterToolbarIcon("Settings", "Interface\\Icons\\INV_Gizmo_02", OnClick, OnTooltip)

-- No module-specific settings: this icon simply opens the main options panel.
