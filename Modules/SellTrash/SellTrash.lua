local addonName, addon = ...

    local ms = HerosArmyKnifeDB.settings.moduleSettings
    ms.SellTrash = ms.SellTrash or { auto = true, debug = false }
    if ms.SellTrash.debug == nil then ms.SellTrash.debug = false end
addon:RegisterInit(function()
    if addon.GetModuleSettings then addon:GetModuleSettings('SellTrash', { auto = true, debug = false }) end
end)

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('SellTrash', { auto = true, debug = false }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.SellTrash or { auto = true }
end

local modFrame = CreateFrame("Frame")
modFrame:RegisterEvent("MERCHANT_SHOW")

local function SellGreyItems()
    local soldCount = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local texture, itemCount, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            if link and quality == 0 then
                UseContainerItem(bag, slot)
                soldCount = soldCount + (itemCount or 1)
            end
        end
    end
    if soldCount > 0 then if addon.Notify then addon:Notify("Sold " .. soldCount .. " trash items.", 'success') end end
end

modFrame:SetScript("OnEvent", function(self, event)
    if not addon.IsModuleEnabled or not addon:IsModuleEnabled("SellTrash") then return end
    local s = GetSettings()
    if event == "MERCHANT_SHOW" and s.auto then SellGreyItems() end
end)

local function OnClick(btn)
    SellGreyItems()
end

local function OnTooltip(btn)
    local lines = {
        "Sell Trash",
        "Click: Sell grey-quality items (must be at vendor).",
        "Auto mode: sells on vendor open.",
    }
    if GetSettings().debug then table.insert(lines, "Debug: Enabled") end
    return lines
end

addon:RegisterToolbarIcon("SellTrash", "Interface\\Icons\\INV_Misc_Coin_02", OnClick, OnTooltip)

if addon.RegisterModuleOptions then
    addon:RegisterModuleOptions("SellTrash", function(panel)
        local debugSection = addon:CreateSection(panel, "Debug", -8, 580)
        local dcb = CreateFrame("CheckButton", "HAK_SellTrash_DebugCB", debugSection, "InterfaceOptionsCheckButtonTemplate")
        dcb:SetPoint("TOPLEFT", debugSection, "TOPLEFT", 0, 0)
        _G[dcb:GetName() .. "Text"]:SetText("Enable debug info")
        dcb:SetChecked(GetSettings().debug)
        dcb:SetScript("OnClick", function(self)
            local s = GetSettings(); s.debug = self:GetChecked() and true or false
        end)
    end)
end
