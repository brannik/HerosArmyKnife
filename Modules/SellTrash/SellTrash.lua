local addonName, addon = ...

    local ms = HerosArmyKnifeDB.settings.moduleSettings
    ms.SellTrash = ms.SellTrash or { auto = true, debug = false, watchItems = {} }
    if ms.SellTrash.debug == nil then ms.SellTrash.debug = false end
addon:RegisterInit(function()
    if addon.GetModuleSettings then addon:GetModuleSettings('SellTrash', { auto = true, debug = false, watchItems = {} }) end
end)

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('SellTrash', { auto = true, debug = false, watchItems = {} }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.SellTrash or { auto = true, debug = false, watchItems = {} }
end

local modFrame = CreateFrame("Frame")
modFrame:RegisterEvent("MERCHANT_SHOW")
modFrame:RegisterEvent("MERCHANT_CLOSED")
modFrame:RegisterEvent("BAG_UPDATE")

-- Helpers
local function GetItemIDFromLink(link)
    if not link then return nil end
    local id = link:match("Hitem:(%d+):")
    return id and tonumber(id) or nil
end

local function IsTracked(itemID)
    if not itemID then return false end
    local s = GetSettings()
    local list = s.watchItems or {}
    for _, id in ipairs(list) do if id == itemID then return true end end
    return false
end

-- Count total items in bags for a given itemID
local function CountItemInBags(itemID)
    if not itemID then return 0 end
    local total = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = GetItemIDFromLink(link)
                if id == itemID then
                    local _, itemCount = GetContainerItemInfo(bag, slot)
                    total = total + (itemCount or 1)
                end
            end
        end
    end
    return total
end

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

local function SellTrackedItems()
    local s = GetSettings()
    local watch = s.watchItems or {}
    if #watch == 0 then if addon.Notify then addon:Notify("Tracked list is empty.", 'warn') end return end
    local soldStacks, soldItems = 0, 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local texture, itemCount, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            local id = GetItemIDFromLink(link)
            if id and IsTracked(id) then
                UseContainerItem(bag, slot)
                soldStacks = soldStacks + 1
                soldItems = soldItems + (itemCount or 1)
            end
        end
    end
    if addon.Notify then
        if soldStacks > 0 then addon:Notify(string.format("Sold %d stacks (%d items) from tracked list.", soldStacks, soldItems), 'success')
        else addon:Notify("No tracked items found in bags.", 'info') end
    end
end

-- UI similar to CacheOpener: item slot + tracked list
local uiFrame, itemSlot, listScroll, listContent

local function RefreshTrackedList()
    if not listContent then return end
    for i = 1, select('#', listContent:GetChildren()) do
        local child = select(i, listContent:GetChildren())
        if child and child._hakTrackedRow then child:Hide(); child:SetParent(nil) end
    end
    local s = GetSettings()
    local watch = s.watchItems or {}
    local y = 0
    local baseWidth = (listScroll and listScroll:GetWidth() or 460)
    for _, id in ipairs(watch) do
        local row = CreateFrame("Frame", nil, listContent)
        row._hakTrackedRow = true
        row:SetSize(baseWidth, 26)
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -y)
        row:EnableMouse(true)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20,20)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        local name, link, _, _, _, _, _, _, _, tex = GetItemInfo(id)
        if tex then icon:SetTexture(tex) end
        local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWidth(baseWidth - 20 - 6 - 28)
        local countInBags = CountItemInBags(id)
        local displayName = name or ("Item "..id)
        fs:SetText(displayName)
        if countInBags == 0 then
            fs:SetTextColor(0.6,0.6,0.6)
            icon:SetVertexColor(0.6,0.6,0.6)
        else
            fs:SetTextColor(1,1,1)
            icon:SetVertexColor(1,1,1)
        end
        local rem = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        rem:SetSize(22,20)
        rem:SetText("X")
        rem:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        rem:SetScript("OnClick", function()
            -- remove id from list
            for i, v in ipairs(s.watchItems) do if v == id then table.remove(s.watchItems, i) break end end
            RefreshTrackedList()
        end)
        row:SetScript("OnEnter", function()
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:"..id)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Item ID: "..id, 0.8,0.8,0.8)
            GameTooltip:AddLine("In bags: "..countInBags, 0.8,0.8,0.8)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        y = y + 28
    end
    if y < 10 then y = 10 end
    listContent:SetHeight(y)
    if listScroll and listScroll.UpdateScrollChildRect then listScroll:UpdateScrollChildRect() end
end

local function EnsureUI()
    if uiFrame then return end
    uiFrame = addon.CreateThemedFrame and addon:CreateThemedFrame(UIParent, "HAKSellTrashFrame", 560, 360, 'panel') or CreateFrame("Frame", "HAKSellTrashFrame", UIParent, "BackdropTemplate")
    uiFrame:SetPoint("CENTER")
    uiFrame:EnableMouse(true)
    uiFrame:SetMovable(true)
    uiFrame:RegisterForDrag("LeftButton")
    uiFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    uiFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local title = uiFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", uiFrame, "TOP", 0, 0)
    title:SetText("Sell Tracked Items")
    local close = CreateFrame("Button", nil, uiFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", uiFrame, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() uiFrame:Hide() end)
    -- Item slot
    itemSlot = CreateFrame("Button", nil, uiFrame, "ItemButtonTemplate")
    itemSlot:SetPoint("TOPLEFT", uiFrame, "TOPLEFT", 14, -38)
    itemSlot:SetSize(40, 40)
    itemSlot:RegisterForDrag("LeftButton")
    itemSlot:SetScript("OnReceiveDrag", function()
        local kind, p1, p2 = GetCursorInfo()
        if kind == "item" then
            local id
            local link
            if type(p2) == "string" and p2:find("|Hitem:") then
                link = p2
                id = GetItemIDFromLink(link)
            end
            if not id and type(p1) == "number" then
                id = p1
            end
            if id then
                local s = GetSettings(); s.watchItems = s.watchItems or {}
                local exists = false
                for _, v in ipairs(s.watchItems) do if v == id then exists = true break end end
                if not exists then table.insert(s.watchItems, id) end
                RefreshTrackedList()
            end
            ClearCursor()
        end
    end)
    itemSlot:SetScript("OnMouseUp", function(self, btn)
        if CursorHasItem() then itemSlot:GetScript("OnReceiveDrag")() end
    end)
    local addHelp = uiFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    addHelp:SetPoint("LEFT", itemSlot, "RIGHT", 8, 0)
    addHelp:SetText("Drag an item here to add\nIt will be sold at vendor via button")
    -- List
    listScroll = CreateFrame("ScrollFrame", nil, uiFrame, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", uiFrame, "TOPLEFT", 16, -90)
    listScroll:SetPoint("BOTTOMRIGHT", uiFrame, "BOTTOMRIGHT", -28, 14)
    listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(500, 10)
    listScroll:SetScrollChild(listContent)
    RefreshTrackedList()
    uiFrame:Hide()
end

local function ToggleUI()
    EnsureUI()
    if uiFrame:IsShown() then uiFrame:Hide() else uiFrame:Show(); RefreshTrackedList() end
end

-- Merchant button
local merchantButton

modFrame:SetScript("OnEvent", function(self, event)
    if not addon.IsModuleEnabled or not addon:IsModuleEnabled("SellTrash") then return end
    local s = GetSettings()
    if event == "MERCHANT_SHOW" then
        -- auto-sell greys remains optional
        if s.auto then SellGreyItems() end
        -- ensure merchant button
        if not merchantButton then
            merchantButton = CreateFrame("Button", "HAK_SellTrackedButton", MerchantFrame, "UIPanelButtonTemplate")
            merchantButton:SetSize(120, 22)
            merchantButton:SetText("Sell Tracked")
            merchantButton:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -50, -44)
            merchantButton:SetScript("OnClick", function()
                SellTrackedItems()
            end)
        end
        merchantButton:Show()
        -- enable/disable based on list
        local watch = s.watchItems or {}
        merchantButton:SetEnabled(#watch > 0)
    elseif event == "MERCHANT_CLOSED" then
        if merchantButton then merchantButton:Hide() end
    elseif event == "BAG_UPDATE" then
        if uiFrame and uiFrame:IsShown() then RefreshTrackedList() end
    end
end)

local function OnClick(btn)
    ToggleUI()
end

local function OnTooltip(btn)
    local lines = {
        "Sell Tracked Items",
        "Click: Open tracked sell list UI.",
        "At vendor: 'Sell Tracked' button sells only listed items.",
        "Optional: Auto-sell grey items on open.",
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
