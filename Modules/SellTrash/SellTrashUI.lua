local addonName, addon = ...

-- Tracked items UI for SellTrash
local uiFrame, itemSlot, listScroll, listContent, totalText

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('SellTrash', { auto = true, debug = false, watchItems = {}, protectedItems = {} }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.SellTrash or { auto = true, debug = false, watchItems = {}, protectedItems = {} }
end

local function CountItemInBags(itemID)
    if not itemID then return 0 end
    local total = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = link:match("|Hitem:(%d+)")
                if id and tonumber(id) == itemID then
                    local _, itemCount = GetContainerItemInfo(bag, slot)
                    total = total + (itemCount or 1)
                end
            end
        end
    end
    return total
end

local function GetItemSellPrice(itemID)
    if not itemID then return 0 end
    local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemID)
    return sellPrice or 0
end

local function RefreshTrackedList()
    if not listContent then return end
    local children = {listContent:GetChildren()}
    for i = 1, #children do
        local child = children[i]
        if child then child:Hide(); child:SetParent(nil) end
    end
    local s = GetSettings()
    local tracked = s.watchItems or {}
    
    -- Sort items: those in bags first, then those not in bags
    local itemsWithCounts = {}
    local seen = {}
    for _, id in ipairs(tracked) do
        if not seen[id] then
            seen[id] = true
            local count = CountItemInBags(id)
            table.insert(itemsWithCounts, { id = id, count = count })
        end
    end
    
    table.sort(itemsWithCounts, function(a, b)
        if (a.count > 0) ~= (b.count > 0) then
            return a.count > 0
        end
        return a.id < b.id
    end)
    
    local y = 0
    local baseWidth = 480
    local totalValue = 0
    local usableWidth = (listScroll and listScroll:GetWidth() or 0) - 8
    if not usableWidth or usableWidth < 280 then usableWidth = 480 end
    listContent:SetWidth(usableWidth)
    for _, item in ipairs(itemsWithCounts) do
        local id = item.id
        local count = item.count
        local row = CreateFrame("Frame", nil, listContent)
        row._hakTrackedRow = true
        row:SetSize(baseWidth, 28)
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, -y)
        row:SetHeight(28)
        
        -- Background
        if count == 0 then
            row:SetAlpha(0.6)
        end
        
        -- Icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20,20)
        icon:SetPoint("LEFT", row, "LEFT", 4, 0)
        local name, link, _, _, _, _, _, _, _, tex = GetItemInfo(id)
        if tex then icon:SetTexture(tex) end
        if count == 0 then
            icon:SetVertexColor(0.5, 0.5, 0.5)
        else
            icon:SetVertexColor(1, 0.95, 0.7)
        end
        
        -- Count badge
        local countText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        countText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        countText:SetWidth(35)
        countText:SetWidth(40)
        if count > 0 then
            countText:SetText(count.."x")
            countText:SetTextColor(0.2, 1, 0.2)
        else
            countText:SetText("0x")
            countText:SetTextColor(0.7, 0.3, 0.3)
        end
        
        -- Item name
        local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", countText, "RIGHT", 4, 0)
        fs:SetJustifyH("LEFT")
        fs:SetPoint("RIGHT", row, "RIGHT", -34, 0)
        local displayName = name or ("Item "..id)
        fs:SetText(displayName)
        if count == 0 then
            fs:SetTextColor(0.6, 0.6, 0.6)
        else
            fs:SetTextColor(1, 0.95, 0.7)
        end
        
        -- Calculate total value
        local sellPrice = GetItemSellPrice(id)
        totalValue = totalValue + (sellPrice * count)
        
        -- Remove button
        local rem = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        rem:SetSize(24, 20)
        rem:SetText("X")
        rem:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        rem:SetScript("OnClick", function()
            for i, v in ipairs(s.watchItems) do
                if v == id then
                    table.remove(s.watchItems, i)
                    break
                end
            end
            RefreshTrackedList()
            if addon.UpdateBagSlotGlow then addon:UpdateBagSlotGlow() end
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
    
    -- Update total text
    if totalText then
        if totalValue == 0 then
            totalText:SetText("Total vendor value: 0 gold")
        else
            local g = math.floor(totalValue / 10000)
            local s = math.floor((totalValue % 10000) / 100)
            local c = totalValue % 100
            totalText:SetText(string.format("Total vendor value: %d g %d s %d c", g, s, c))
        end
    end
end

function addon:EnsureSellTrashUI()
    if uiFrame then return end
    uiFrame = addon.CreateThemedFrame and addon:CreateThemedFrame(UIParent, "HAKSellTrashFrame", 600, 500, 'panel') or CreateFrame("Frame", "HAKSellTrashFrame", UIParent, "BackdropTemplate")
    uiFrame:SetPoint("CENTER")
    uiFrame:EnableMouse(true)
    uiFrame:SetMovable(true)
    uiFrame:RegisterForDrag("LeftButton")
    uiFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    uiFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Title anchored to title region when available
    local title = uiFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    local titleRegion = uiFrame.GetTitleRegion and uiFrame:GetTitleRegion()
    
    title:SetPoint("CENTER", uiFrame, "TOP", 0, -5)
    title:SetJustifyH("CENTER")
    title:SetText("Trash List")
    
    -- Close button
    local close = CreateFrame("Button", nil, uiFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", uiFrame, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() uiFrame:Hide() end)
    
    -- Item slot section
    itemSlot = CreateFrame("Button", nil, uiFrame, "ItemButtonTemplate")
    itemSlot:SetPoint("TOPLEFT", uiFrame, "TOPLEFT", 18, -56)
    itemSlot:SetSize(40, 40)
    itemSlot:RegisterForDrag("LeftButton")
    itemSlot:SetScript("OnReceiveDrag", function()
        local kind, p1, p2 = GetCursorInfo()
        if kind == "item" then
            local id
            local link
            if type(p2) == "string" and p2:find("|Hitem:") then
                link = p2
                id = link:match("|Hitem:(%d+)")
                if id then id = tonumber(id) end
            end
            if not id and type(p1) == "number" then
                id = p1
            end
            if id then
                local s = GetSettings()
                -- Check if item is protected
                local isProtected = false
                for _, protectedId in ipairs(s.protectedItems or {}) do
                    if protectedId == id then
                        isProtected = true
                        break
                    end
                end
                if isProtected then
                    if addon.Notify then addon:Notify("This item is protected from selling.", 'warn') end
                else
                    s.watchItems = s.watchItems or {}
                    local exists = false
                    for _, v in ipairs(s.watchItems) do if v == id then exists = true break end end
                    if not exists then table.insert(s.watchItems, id) end
                    RefreshTrackedList()
                    if addon.UpdateBagSlotGlow then addon:UpdateBagSlotGlow() end
                end
            end
            ClearCursor()
        end
    end)
    itemSlot:SetScript("OnMouseUp", function(self, btn)
        if CursorHasItem() then itemSlot:GetScript("OnReceiveDrag")() end
    end)
    
    local addHelp = uiFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    addHelp:SetPoint("LEFT", itemSlot, "RIGHT", 10, 0)
    addHelp:SetText("Drag items\nhere to add")
    
    -- Add All button
    local addAllBtn = CreateFrame("Button", nil, uiFrame, "UIPanelButtonTemplate")
    addAllBtn:SetSize(132, 24)
    addAllBtn:SetText("Add Untracked")
    addAllBtn:SetPoint("TOPRIGHT", uiFrame, "TOPRIGHT", -20, -56)
    addAllBtn:SetScript("OnClick", function()
        local s = GetSettings()
        if addon.GetUntrackedSellableItems then
            local toAdd = addon:GetUntrackedSellableItems()
            for _, id in ipairs(toAdd) do
                local exists = false
                for _, v in ipairs(s.watchItems) do if v == id then exists = true break end end
                if not exists then table.insert(s.watchItems, id) end
            end
            RefreshTrackedList()
            if addon.UpdateBagSlotGlow then addon:UpdateBagSlotGlow() end
        end
    end)
    
    -- Total value text
    totalText = uiFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    totalText:SetPoint("TOPLEFT", itemSlot, "BOTTOMLEFT", 0, -18)
    totalText:SetPoint("RIGHT", uiFrame, "RIGHT", -28, 0)
    totalText:SetText("Total vendor value: 0 gold")
    totalText:SetTextColor(1, 1, 0.3)
    
    -- List scroll
    listScroll = CreateFrame("ScrollFrame", nil, uiFrame, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", totalText, "BOTTOMLEFT", -2, -12)
    listScroll:SetPoint("BOTTOMRIGHT", uiFrame, "BOTTOMRIGHT", -32, 18)
    
    listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(480, 10)
    listScroll:SetScrollChild(listContent)
    
    RefreshTrackedList()
    uiFrame:Hide()
end

function addon:ToggleSellTrashUI()
    addon:EnsureSellTrashUI()
    if uiFrame:IsShown() then uiFrame:Hide() else uiFrame:Show(); RefreshTrackedList() end
end
