local addonName, addon = ...

SLASH_HEROSARMYKNIFE1 = "/hak"

local function trim(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

local function handler(msg)
    msg = trim(msg):lower()
    if msg == "reload" then
        ReloadUI()
        return
    elseif msg == "options" or msg == "config" then
        if InterfaceOptionsFrame then
            InterfaceOptionsFrame_OpenToCategory("HerosArmyKnife")
            InterfaceOptionsFrame_OpenToCategory("HerosArmyKnife")
        end
        return
    elseif msg == "layout" then
        if addon.RebuildToolbar then addon:RebuildToolbar(); if addon.Notify then addon:Notify("Toolbar layout rebuilt.", 'success') else DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99HerosArmyKnife|r: Toolbar layout rebuilt.") end end
        return
    elseif msg == "show" then
        if addon.toolbarFrame then
            addon.toolbarFrame:Show(); if addon.Notify then addon:Notify("Toolbar shown.", 'info') else DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99HerosArmyKnife|r: Toolbar shown.") end
        else
            if addon.BuildToolbar then addon:BuildToolbar(); if addon.Notify then addon:Notify("Toolbar built & shown.", 'success') else DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99HerosArmyKnife|r: Toolbar built & shown.") end end
        end
        return
    end

    if addon.Notify then addon:Notify("Commands: reload, options, layout, show | drag toolbar, click icons", 'info') else DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99HerosArmyKnife|r: Commands: reload, options, layout, show | drag toolbar, click icons") end
end

SlashCmdList["HEROSARMYKNIFE"] = handler
