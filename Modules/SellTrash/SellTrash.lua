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

local function SellGreyItems(silent)
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
    if not silent and soldCount > 0 then if addon.Notify then addon:Notify("Sold " .. soldCount .. " trash items.", 'success') end end
    return soldCount
end

local function SellTrackedItems(silent)
    local s = GetSettings()
    local watch = s.watchItems or {}
    if #watch == 0 then if not silent and addon.Notify then addon:Notify("Tracked list is empty.", 'warn') end return 0, 0 end
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
    if not silent and addon.Notify then
        if soldStacks > 0 then addon:Notify(string.format("Sold %d stacks (%d items) from tracked list.", soldStacks, soldItems), 'success')
        else addon:Notify("No tracked items found in bags.", 'info') end
    end
    return soldStacks, soldItems
end

-- UI similar to CacheOpener: item slot + tracked list
local uiFrame, itemSlot, listScroll, listContent, totalText

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
        -- Count label (before icon)
        local countFS = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        countFS:SetJustifyH("RIGHT")
        countFS:SetWidth(26)
        countFS:SetPoint("LEFT", row, "LEFT", 0, 0)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20,20)
        icon:SetPoint("LEFT", countFS, "RIGHT", 4, 0)
        local name, link, _, _, _, _, _, _, _, tex = GetItemInfo(id)
        if tex then icon:SetTexture(tex) end
        local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        fs:SetJustifyH("LEFT")
        -- Reserve width: count(26)+sp(4)+icon(20)+sp(6)+removeBtn(22)+spRight(4)
        fs:SetWidth(baseWidth - (26+4+20+6+22+4))
        local countInBags = CountItemInBags(id)
        local displayName = name or ("Item "..id)
        countFS:SetText(tostring(countInBags or 0))
        fs:SetText(displayName)
        if countInBags == 0 then
            fs:SetTextColor(0.6,0.6,0.6)
            icon:SetVertexColor(0.6,0.6,0.6)
            countFS:SetTextColor(0.6,0.6,0.6)
        else
            fs:SetTextColor(1,1,1)
            icon:SetVertexColor(1,1,1)
            countFS:SetTextColor(1,1,1)
        end
        local rem = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        rem:SetSize(22,20)
        rem:SetText("X")
        rem:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        rem:SetScript("OnClick", function()
            -- remove id from list
            for i, v in ipairs(s.watchItems) do if v == id then table.remove(s.watchItems, i) break end end
            RefreshTrackedList()
            UpdateTotalText()
        end)
        row:SetScript("OnEnter", function()
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:"..id)
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
    -- update total value display if present
    if totalText and uiFrame and uiFrame:IsShown() then
        -- will be refreshed by UpdateTotalText below
    end
end

-- Compute total vendor value (in copper) of tracked items currently in bags
local function ComputeTrackedTotalCopper()
    local s = GetSettings()
    local watch = s.watchItems or {}
    if #watch == 0 then return 0 end
    -- Build quick lookup set for tracked IDs
    local tracked = {}
    for _, id in ipairs(watch) do tracked[id] = true end
    local total = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = GetItemIDFromLink(link)
                if id and tracked[id] then
                    local _, count = GetContainerItemInfo(bag, slot)
                    local vendor = select(11, GetItemInfo(id)) or 0
                    if vendor and vendor > 0 then
                        total = total + vendor * (count or 1)
                    end
                end
            end
        end
    end
    return total
end

local function FormatCopper(copper)
    if type(GetCoinTextureString) == 'function' then
        return GetCoinTextureString(copper)
    end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    return string.format("%dg %ds %dc", g, s, c)
end

-- Compute total vendor value (in copper) of all grey-quality items in bags
local function ComputeGreysTotalCopper()
    local total = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local texture, itemCount, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            if link and quality == 0 then
                local id = GetItemIDFromLink(link)
                local vendor = id and (select(11, GetItemInfo(id)) or 0) or 0
                if vendor and vendor > 0 then total = total + vendor * (itemCount or 1) end
            end
        end
    end
    return total
end

-- Sell both greys and tracked vendor items with a unified notification
local function SellTrashAndTracked(silent)
    local soldGreys = SellGreyItems(true) -- invoke silently; unify messaging here
    local soldTrackedStacks, soldTrackedItems = SellTrackedItems(true)
    if silent then return soldGreys, soldTrackedStacks, soldTrackedItems end
    if addon.Notify then
        if soldGreys > 0 and soldTrackedStacks > 0 then
            addon:Notify(string.format("Sold %d trash items and %d tracked stacks (%d items).", soldGreys, soldTrackedStacks, soldTrackedItems), 'success')
        elseif soldGreys > 0 then
            addon:Notify(string.format("Sold %d trash items.", soldGreys), 'success')
        elseif soldTrackedStacks > 0 then
            addon:Notify(string.format("Sold %d tracked stacks (%d items).", soldTrackedStacks, soldTrackedItems), 'success')
        else
            addon:Notify("No trash/tracked items to sell.", 'info')
        end
    end
    return soldGreys, soldTrackedStacks, soldTrackedItems
end

local function UpdateTotalText()
    if not totalText then return end
    local total = ComputeTrackedTotalCopper()
    totalText:SetText("Tracked value in bags: "..FormatCopper(total))
end

local function EnsureUI()
    if uiFrame then return end
    uiFrame = addon.CreateThemedFrame and addon:CreateThemedFrame(UIParent, "HAKSellTrashFrame", 560, 450, 'panel') or CreateFrame("Frame", "HAKSellTrashFrame", UIParent, "BackdropTemplate")
    uiFrame:SetPoint("CENTER")
    uiFrame:EnableMouse(true)
    uiFrame:SetMovable(true)
    uiFrame:RegisterForDrag("LeftButton")
    uiFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    uiFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local title = uiFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", uiFrame, "TOP", 0, 0)
    title:SetText("Trash Sell List")
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
                UpdateTotalText()
            end
            ClearCursor()
        end
    end)
    itemSlot:SetScript("OnMouseUp", function(self, btn)
        if CursorHasItem() then itemSlot:GetScript("OnReceiveDrag")() end
    end)
    local addHelp = uiFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    addHelp:SetPoint("LEFT", itemSlot, "RIGHT", 8, 0)
    addHelp:SetText("Drag vendor items here to add\nThey will sell with trash at vendor")
    -- Total vendor value label above the list, centered within the left half of the frame
    local leftHalf = CreateFrame("Frame", nil, uiFrame)
    leftHalf:SetPoint("TOPLEFT", uiFrame, "TOPLEFT", 0, -89) -- moved 25px further down
    leftHalf:SetPoint("TOPRIGHT", uiFrame, "TOP", 0, -89)
    leftHalf:SetHeight(1)
    totalText = uiFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    totalText:SetPoint("TOP", leftHalf, "TOP", 0, 0)
    totalText:SetText("Tracked value in bags: 0")
    -- List
    listScroll = CreateFrame("ScrollFrame", nil, uiFrame, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", uiFrame, "TOPLEFT", 16, -112)
    listScroll:SetPoint("BOTTOMRIGHT", uiFrame, "BOTTOMRIGHT", -28, 14)
    listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(500, 10)
    listScroll:SetScrollChild(listContent)
    RefreshTrackedList()
    UpdateTotalText()
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
        -- Auto-sell both greys and tracked items when enabled
        if s.auto then SellTrashAndTracked(false) end
        -- ensure merchant button
        if not merchantButton then
            merchantButton = CreateFrame("Button", "HAK_SellTrackedButton", MerchantFrame, "UIPanelButtonTemplate")
            merchantButton:SetSize(120, 22)
            merchantButton:SetText("Sell Trash")
            merchantButton:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -50, -44)
            merchantButton:SetScript("OnClick", function()
                SellTrashAndTracked(false)
            end)
            merchantButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Sell Trash")
                local greys = ComputeGreysTotalCopper()
                local tracked = ComputeTrackedTotalCopper()
                local combined = (greys or 0) + (tracked or 0)
                GameTooltip:AddLine("Greys:  "..FormatCopper(greys), 1,1,1)
                GameTooltip:AddLine("Tracked:"..FormatCopper(tracked), 1,1,1)
                GameTooltip:AddLine("Total:  "..FormatCopper(combined), 1,1,1)
                GameTooltip:Show()
            end)
            merchantButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
        merchantButton:Show()
        -- Always enabled: sells greys plus tracked list
        merchantButton:SetEnabled(true)
    elseif event == "MERCHANT_CLOSED" then
        if merchantButton then merchantButton:Hide() end
    elseif event == "BAG_UPDATE" then
        if uiFrame and uiFrame:IsShown() then RefreshTrackedList(); UpdateTotalText() end
    end
end)

local function OnClick(btn)
    ToggleUI()
end

local function OnTooltip(btn)
    local lines = {
        "Sell Trash",
        "Click: Open trash/vendor tracking UI.",
        "At vendor: sells greys + tracked vendor items.",
        "Auto-sell: On by default (can be toggled in options).",
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
