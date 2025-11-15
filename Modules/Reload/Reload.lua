local addonName, addon = ...

-- No settings yet; if needed later use addon:RegisterInit similar to other modules.

local function OnClick(btn)
    ReloadUI()
end


local function OnTooltip(btn)
    local lines = {
        "Reload UI",
        "Click to perform /reload (refresh interface).",
        "Useful after editing addons or fixing taint.",
    }
    return lines
end

addon:RegisterToolbarIcon("Reload", "Interface\\Buttons\\UI-RefreshButton", OnClick, OnTooltip)

-- Module-specific options panel (simple description)
-- Removed debug/settings integration: utility has no configurable options.
