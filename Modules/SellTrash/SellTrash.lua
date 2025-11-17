local addonName, addon = ...

    local ms = HerosArmyKnifeDB.settings.moduleSettings
    ms.SellTrash = ms.SellTrash or { auto = true, debug = false, watchItems = {}, protectedItems = {} }
    if ms.SellTrash.debug == nil then ms.SellTrash.debug = false end
addon:RegisterInit(function()
    if addon.GetModuleSettings then addon:GetModuleSettings('SellTrash', { auto = true, debug = false, watchItems = {} }) end
end)

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('SellTrash', { auto = true, debug = false, watchItems = {}, protectedItems = {} }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.SellTrash or { auto = true, debug = false, watchItems = {}, protectedItems = {} }
end

local function IsProtected(itemID)
    if not itemID then return false end
    local s = GetSettings()
    local list = s.protectedItems or {}
    for _, id in ipairs(list) do if id == itemID then return true end end
    return false
end

-- Create event frame for merchant and bag updates
local modFrame = CreateFrame("Frame")
modFrame:RegisterEvent("MERCHANT_SHOW")
modFrame:RegisterEvent("MERCHANT_CLOSED")
modFrame:RegisterEvent("BAG_UPDATE")
modFrame:RegisterEvent("BAG_UPDATE_DELAYED")
modFrame:RegisterEvent("BAG_OPEN")
modFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
modFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")

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
    local s = GetSettings()
    local protected = {}
    for _, id in ipairs(s.protectedItems or {}) do protected[id] = true end
    local soldCount = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local texture, itemCount, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            local id = GetItemIDFromLink(link)
            if link and quality == 0 and not protected[id] then
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
    local protected = {}
    for _, id in ipairs(s.protectedItems or {}) do protected[id] = true end
    if #watch == 0 then
        if not silent and addon.Notify then addon:Notify("Tracked list is empty.", 'warn') end
        return 0, 0
    end
    local soldStacks, soldItems = 0, 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local texture, itemCount, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
            local id = GetItemIDFromLink(link)
            if id and IsTracked(id) and not protected[id] then
                UseContainerItem(bag, slot)
                soldStacks = soldStacks + 1
                soldItems = soldItems + (itemCount or 1)
            end
        end
    end
    if not silent and addon.Notify then
        if soldStacks > 0 then
            addon:Notify(string.format("Sold %d stacks (%d items) from tracked list.", soldStacks, soldItems), 'success')
        else
            addon:Notify("No tracked items found in bags.", 'info')
        end
    end
    return soldStacks, soldItems
end

-- UI similar to CacheOpener: item slot + tracked list
local uiFrame, itemSlot, listScroll, listContent, totalText
local protFrame, protScroll, protContent

local function GetUntrackedSellableItems()
    local s = GetSettings()
    local tracked = {}
    for _, id in ipairs(s.watchItems or {}) do tracked[id] = true end
    local protected = {}
    for _, id in ipairs(s.protectedItems or {}) do protected[id] = true end
    local found = {}
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = GetItemIDFromLink(link)
                local _, _, quality = GetItemInfo(id)
                if id and quality and quality < 3 and not tracked[id] and not protected[id] then
                    found[id] = true
                end
            end
        end
    end
    local result = {}
    for id in pairs(found) do table.insert(result, id) end
    return result
end

-- UI logic moved to SellTrashUI.lua and ProtectedUI.lua

-- Left click: tracked items UI
local function ToggleUI()
    if addon.ToggleSellTrashUI then addon:ToggleSellTrashUI() end
end

-- Right click: protected items UI
local function ToggleProtectedUI()
    if addon.ToggleProtectedUI then addon:ToggleProtectedUI() end
end

local bagButtonCache = {}
local debugLabels = {}
local bagCacheDirty = true
local lastCacheScan = 0
local MIN_CACHE_RESCAN = 0.2

local function SetButtonDebugLabel(button, bagID, slotID, enabled)
    if not button then return end
    local label = debugLabels[button]
    if enabled then
        if not label then
            label = button:CreateFontString(nil, "OVERLAY")
            label:SetFont("Fonts\\FRIZQT__.TTF", 10)
            label:SetTextColor(1, 1, 0)
            label:SetPoint("CENTER", button, "CENTER")
            debugLabels[button] = label
        end
        label:SetText(bagID .. ":" .. slotID)
        label:Show()
    elseif label then
        label:Hide()
    end
end

local function CacheBagButton(bagID, slotID, button, debugEnabled)
    if type(bagID) ~= "number" or type(slotID) ~= "number" or not button then return end
    bagButtonCache[bagID] = bagButtonCache[bagID] or {}
    bagButtonCache[bagID][slotID] = button
    SetButtonDebugLabel(button, bagID, slotID, debugEnabled)
end

local function RefreshBagButtonCache(debugEnabled)
    for bagID, slotMap in pairs(bagButtonCache) do
        for slotID, button in pairs(slotMap) do
            if not debugEnabled then
                SetButtonDebugLabel(button, bagID, slotID, false)
            else
                SetButtonDebugLabel(button, bagID, slotID, true)
            end
        end
    end

    local now = GetTime and GetTime() or 0
    if not bagCacheDirty and (now - lastCacheScan) < MIN_CACHE_RESCAN then
        return
    end
    bagCacheDirty = false
    lastCacheScan = now

    for bagID in pairs(bagButtonCache) do
        bagButtonCache[bagID] = nil
    end

    local frameCount = NUM_CONTAINER_FRAMES or 13
    for i = 1, frameCount do
        local container = _G["ContainerFrame" .. i]
        if container and container.GetID then
            local bagID = container:GetID()
            if bagID ~= nil then
                local slotCount = container.size or GetContainerNumSlots(bagID) or 0
                for idx = 1, slotCount do
                    local button = _G[container:GetName() .. "Item" .. idx]
                    if button and button.GetID then
                        CacheBagButton(bagID, button:GetID(), button, debugEnabled)
                    end
                end
            end
        end
    end

    local frame = EnumerateFrames and EnumerateFrames()
    while frame do
        local bagID, slotID
        if frame.GetBag and frame.GetSlot then
            bagID = frame:GetBag()
            slotID = frame:GetSlot()
        elseif frame.GetBagID and frame.GetID then
            bagID = frame:GetBagID()
            slotID = frame:GetID()
        elseif frame.GetBag and frame.GetID then
            bagID = frame:GetBag()
            slotID = frame:GetID()
        end

        if type(bagID) == "number" and type(slotID) == "number" then
            CacheBagButton(bagID, slotID, frame, debugEnabled)
        end

        frame = EnumerateFrames and EnumerateFrames(frame)
    end
end

-- Find the actual item button frame for a given bag/slot by searching UIParent
local function FindItemButton(bag, slot)
    local slotMap = bagButtonCache[bag]
    return slotMap and slotMap[slot] or nil
end

local function UpdateSlot(bag, slot, itemButton, trackedMap, protectedMap)
    if not itemButton then return end

    local itemID = GetContainerItemID(bag, slot)
    local isTracked = itemID and trackedMap[itemID]
    local isProtected = itemID and protectedMap[itemID]

    -- Handle tracked icon (gold coin) on top-right
    if isTracked then
        if not itemButton.TrackedIcon then
            local icon = itemButton:CreateTexture(nil, "OVERLAY")
            icon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
            icon:SetWidth(13)
            icon:SetHeight(13)
            icon:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMLEFT", 2, 2)
            itemButton.TrackedIcon = icon
        end
        itemButton.TrackedIcon:Show()
    elseif itemButton.TrackedIcon then
        itemButton.TrackedIcon:Hide()
    end

    -- Handle protected icon (silver coin) on bottom-left
    if isProtected then
        if not itemButton.ProtectedIcon then
            local icon = itemButton:CreateTexture(nil, "OVERLAY")
            icon:SetTexture("Interface\\Icons\\INV_Shield_04")
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            icon:SetWidth(13)
            icon:SetHeight(13)
            icon:SetPoint("BOTTOMLEFT", itemButton, "BOTTOMLEFT", 2, 2)
            itemButton.ProtectedIcon = icon
        end
        itemButton.ProtectedIcon:Show()
    elseif itemButton.ProtectedIcon then
        itemButton.ProtectedIcon:Hide()
    end
end

function addon:UpdateBagSlotGlow()
    local settings = GetSettings()
    RefreshBagButtonCache(settings.debug)

    local trackedMap = {}
    for _, id in ipairs(settings.watchItems or {}) do trackedMap[id] = true end
    local protectedMap = {}
    for _, id in ipairs(settings.protectedItems or {}) do protectedMap[id] = true end

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemButton = FindItemButton(bag, slot)
            UpdateSlot(bag, slot, itemButton, trackedMap, protectedMap)
        end
    end
end

-- Compute total vendor value (in copper) of tracked items currently in bags
function addon:ComputeTrackedTotalCopper()
    local s = GetSettings()
    local watch = s.watchItems or {}
    if #watch == 0 then return 0 end
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

function addon:FormatCopper(copper)
    if type(GetCoinTextureString) == 'function' then
        return GetCoinTextureString(copper)
    end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    return string.format("%dg %ds %dc", g, s, c)
end

-- Compute total vendor value (in copper) of all grey-quality items in bags
function addon:ComputeGreysTotalCopper()
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
function addon:SellTrashAndTracked(silent)
    local soldGreys = SellGreyItems(true)
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

function addon:UpdateTotalText()
    -- This will be called from SellTrashUI if needed
end

-- Merchant button
local merchantButton

-- Create update frame for continuous icon updates
local updateFrame = CreateFrame("Frame")
updateFrame:Hide()
local pendingGlowRefresh = false
local refreshAccumulator = 0
local MIN_REFRESH_DELAY = 0.05

local function QueueBagGlowRefresh()
    if addon.IsModuleEnabled and not addon:IsModuleEnabled("SellTrash") then
        pendingGlowRefresh = false
        refreshAccumulator = 0
        updateFrame:Hide()
        if addon.SellTrash_ClearIndicators then addon:SellTrash_ClearIndicators() end
        return
    end

    pendingGlowRefresh = true
    refreshAccumulator = 0
    if not updateFrame:IsShown() then updateFrame:Show() end
end

updateFrame:SetScript("OnUpdate", function(_, elapsed)
    if not pendingGlowRefresh then
        updateFrame:Hide()
        return
    end

    refreshAccumulator = refreshAccumulator + (elapsed or 0)
    if refreshAccumulator < MIN_REFRESH_DELAY then return end

    pendingGlowRefresh = false
    updateFrame:Hide()

    if addon.IsModuleEnabled and not addon:IsModuleEnabled("SellTrash") then
        return
    end

    addon:UpdateBagSlotGlow()
end)

function addon:SellTrash_ClearIndicators()
    for bagID, slotMap in pairs(bagButtonCache) do
        for slotID, button in pairs(slotMap) do
            if button and button.TrackedIcon then button.TrackedIcon:Hide() end
            if button and button.ProtectedIcon then button.ProtectedIcon:Hide() end
            SetButtonDebugLabel(button, bagID, slotID, false)
        end
    end
end

function addon:SellTrash_OnModuleEnabled()
    bagCacheDirty = true
    QueueBagGlowRefresh()
end

modFrame:SetScript("OnEvent", function(self, event)
    if not addon.IsModuleEnabled or not addon:IsModuleEnabled("SellTrash") then return end
    local s = GetSettings()
    if event == "MERCHANT_SHOW" then
        -- Auto-sell both greys and tracked items when enabled
        if s.auto then addon:SellTrashAndTracked(false) end
        -- ensure merchant button
        if not merchantButton then
            merchantButton = CreateFrame("Button", "HAK_SellTrackedButton", MerchantFrame, "UIPanelButtonTemplate")
            merchantButton:SetSize(120, 22)
            merchantButton:SetText("Sell Trash")
            merchantButton:SetPoint("TOPRIGHT", MerchantFrame, "TOPRIGHT", -50, -44)
            merchantButton:SetScript("OnClick", function()
                addon:SellTrashAndTracked(false)
            end)
            merchantButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Sell Trash")
                local greys = addon:ComputeGreysTotalCopper()
                local tracked = addon:ComputeTrackedTotalCopper()
                local combined = (greys or 0) + (tracked or 0)
                GameTooltip:AddLine("Greys:  "..addon:FormatCopper(greys), 1,1,1)
                GameTooltip:AddLine("Tracked:"..addon:FormatCopper(tracked), 1,1,1)
                GameTooltip:AddLine("Total:  "..addon:FormatCopper(combined), 1,1,1)
                GameTooltip:Show()
            end)
            merchantButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
        merchantButton:Show()
        -- Always enabled: sells greys plus tracked list
        merchantButton:SetEnabled(true)
        QueueBagGlowRefresh()
    elseif event == "MERCHANT_CLOSED" then
        if merchantButton then merchantButton:Hide() end
        QueueBagGlowRefresh()
    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "BAG_OPEN" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYERBANKSLOTS_CHANGED" then
        bagCacheDirty = true
        QueueBagGlowRefresh()
    end
end)

local function OnClick(btn, button)
    if button == "RightButton" then
        ToggleProtectedUI()
    else
        ToggleUI()
    end
end

local function OnTooltip(btn)
    local lines = {
        "Sell Trash",
        "Left-click: Open trash/vendor tracking UI.",
        "Right-click: Open protected items UI.",
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
            bagCacheDirty = true
            QueueBagGlowRefresh()
        end)
    end)
end
