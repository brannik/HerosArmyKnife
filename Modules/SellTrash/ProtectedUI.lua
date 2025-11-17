local addonName, addon = ...

-- Protected items UI for SellTrash
local protFrame, protScroll, protContent

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('SellTrash', { auto = true, debug = false, watchItems = {}, protectedItems = {} }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.SellTrash or { auto = true, debug = false, watchItems = {}, protectedItems = {} }
end

local function RefreshProtectedList()
    if not protContent then return end
    local children = {protContent:GetChildren()}
    for i = 1, #children do
        local child = children[i]
        if child then child:Hide(); child:SetParent(nil) end
    end
    local s = GetSettings()
    local prot = s.protectedItems or {}
    
    -- Sort items: those in bags first, then those not in bags
    local itemsWithCounts = {}
    local seen = {}
    for _, id in ipairs(prot) do
        if not seen[id] then
            seen[id] = true
            local count = 0
            for bag = 0, 4 do
                local slots = GetContainerNumSlots(bag)
                for slot = 1, slots do
                    local link = GetContainerItemLink(bag, slot)
                    if link then
                        local itemID = link:match("|Hitem:(%d+)")
                        if itemID and tonumber(itemID) == id then
                            local _, itemCount = GetContainerItemInfo(bag, slot)
                            count = count + (itemCount or 1)
                        end
                    end
                end
            end
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
    local usableWidth = (protScroll and protScroll:GetWidth() or 0) - 8
    if not usableWidth or usableWidth < 280 then usableWidth = 480 end
    protContent:SetWidth(usableWidth)
    
    for _, item in ipairs(itemsWithCounts) do
        local id = item.id
        local count = item.count
        local row = CreateFrame("Frame", nil, protContent)
        row._hakProtectedRow = true
        row:SetPoint("TOPLEFT", protContent, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", protContent, "TOPRIGHT", 0, -y)
        row:SetHeight(28)
        row:EnableMouse(true)
        
        -- Background
        if count == 0 then
            row:SetAlpha(0.6)
        end
        
        -- Icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", row, "LEFT", 4, 0)
        local name, link, _, _, _, _, _, _, _, tex = GetItemInfo(id)
        if tex then icon:SetTexture(tex) end
        if count == 0 then
            icon:SetVertexColor(0.5, 0.5, 0.5)
        else
            icon:SetVertexColor(0.8, 0.8, 1)
        end
        
        -- Count badge
        local countText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        countText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        countText:SetWidth(40)
        countText:SetJustifyH("LEFT")
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
        fs:SetPoint("RIGHT", row, "RIGHT", -34, 0)
        fs:SetJustifyH("LEFT")
        local displayName = name or ("Item "..id)
        fs:SetText(displayName)
        if count == 0 then
            fs:SetTextColor(0.6, 0.6, 0.6)
        else
            fs:SetTextColor(0.8, 0.8, 1)
        end
        
        -- Remove button
        local rem = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        rem:SetSize(24, 20)
        rem:SetText("X")
        rem:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        rem:SetScript("OnClick", function()
            for i, v in ipairs(s.protectedItems) do
                if v == id then
                    table.remove(s.protectedItems, i)
                    break
                end
            end
            RefreshProtectedList()
            if addon.UpdateBagSlotGlow then addon:UpdateBagSlotGlow() end
        end)
        
        row:SetScript("OnEnter", function()
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:"..id)
            GameTooltip:AddLine("PROTECTED FROM SELL", 0.2, 0.8, 1)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        y = y + 28
    end
    
    if y < 10 then y = 10 end
    protContent:SetHeight(y)
    if protScroll and protScroll.UpdateScrollChildRect then protScroll:UpdateScrollChildRect() end
end

function addon:EnsureProtectedUI()
    if protFrame then return end
    protFrame = addon.CreateThemedFrame and addon:CreateThemedFrame(UIParent, "HAKProtectedItemsFrame", 600, 500, 'panel') or CreateFrame("Frame", "HAKProtectedItemsFrame", UIParent, "BackdropTemplate")
    protFrame:SetPoint("CENTER")
    protFrame:EnableMouse(true)
    protFrame:SetMovable(true)
    protFrame:RegisterForDrag("LeftButton")
    protFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    protFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Title anchored to title region when available
    local title = protFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    local titleRegion = protFrame.GetTitleRegion and protFrame:GetTitleRegion()
    

    title:SetPoint("CENTER", protFrame, "TOP", 0, -5)
    title:SetJustifyH("CENTER")
    title:SetText("Protected List")
    
    -- Close button
    local close = CreateFrame("Button", nil, protFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", protFrame, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() protFrame:Hide() end)
    
    -- Item slot section
    local protSlot = CreateFrame("Button", nil, protFrame, "ItemButtonTemplate")
    protSlot:SetPoint("TOPLEFT", protFrame, "TOPLEFT", 18, -56)
    protSlot:SetSize(40, 40)
    protSlot:RegisterForDrag("LeftButton")
    protSlot:SetScript("OnReceiveDrag", function()
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
                s.protectedItems = s.protectedItems or {}
                local exists = false
                for _, v in ipairs(s.protectedItems) do if v == id then exists = true break end end
                if not exists then table.insert(s.protectedItems, id) end
                RefreshProtectedList()
                if addon.UpdateBagSlotGlow then addon:UpdateBagSlotGlow() end
            end
            ClearCursor()
        end
    end)
    protSlot:SetScript("OnMouseUp", function(self, btn)
        if CursorHasItem() then protSlot:GetScript("OnReceiveDrag")() end
    end)
    
    local protHelp = protFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    protHelp:SetPoint("LEFT", protSlot, "RIGHT", 10, 0)
    protHelp:SetText("Drag items\nhere to add")
    
    -- List scroll
    protScroll = CreateFrame("ScrollFrame", nil, protFrame, "UIPanelScrollFrameTemplate")
    protScroll:SetPoint("TOPLEFT", protSlot, "BOTTOMLEFT", -2, -12)
    protScroll:SetPoint("BOTTOMRIGHT", protFrame, "BOTTOMRIGHT", -32, 18)
    
    protContent = CreateFrame("Frame", nil, protScroll)
    protContent:SetSize(480, 10)
    protScroll:SetScrollChild(protContent)
    
    RefreshProtectedList()
    protFrame:Hide()
end

function addon:ToggleProtectedUI()
    addon:EnsureProtectedUI()
    if protFrame:IsShown() then protFrame:Hide() else protFrame:Show(); RefreshProtectedList() end
end
