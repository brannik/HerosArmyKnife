local addonName, addon = ...

addon:RegisterInit(function()
    if addon.GetModuleSettings then addon:GetModuleSettings('CacheOpener', { cacheItems = {}, reservedSlots = 2, openDelay = 0.3, debug = false }) end
end)

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('CacheOpener', { cacheItems = {}, reservedSlots = 2, openDelay = 0.3, debug = false }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.CacheOpener or { cacheItems = {}, reservedSlots = 2, openDelay = 0.3, debug = false }
end

-- Scan bags and count occurrences of watched cache items
local function ScanBagCounts(watched)
    local counts = {}
    for _, id in ipairs(watched) do counts[id] = 0 end
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local _, itemCount, _, _, _, _, link = GetContainerItemInfo(bag, slot)
            if link then
                local itemID = tonumber(string.match(link, "item:(%d+):"))
                if itemID and counts[itemID] ~= nil then
                    counts[itemID] = counts[itemID] + (itemCount or 1)
                end
            end
        end
    end
    return counts
end

local function CountFreeSlots()
    local free = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local _, _, _, _, _, _, link = GetContainerItemInfo(bag, slot)
            if not link then free = free + 1 end
        end
    end
    return free
end

-- Determine if item is likely an openable cache/bag/chest (heuristic)
function addon.CacheOpener_IsOpenable(itemID)
    if not itemID then return false end
    local name, link, quality, level, reqLevel, itemType, itemSubType, stackCount, equipLoc = GetItemInfo(itemID)
    -- Bags / containers
    if itemType == "Container" then return true end
    -- Miscellaneous (often chests/caches)
    if itemType == "Miscellaneous" then return true end
    -- Consumable but not food/drink
    if itemType == "Consumable" and itemSubType ~= "Food & Drink" then return true end
    -- If equippable, reject
    if equipLoc and equipLoc ~= "" then return false end
    -- Fallback: unknown type treated as potential cache if no equip slot
    return true
end

-- Opening runner state
local runnerFrame
local openRunner

local function StartOpening(itemID)
    local s = GetSettings()
    if not itemID then return end
    -- Build queue
    local queue = {}
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local _, _, _, _, _, _, link = GetContainerItemInfo(bag, slot)
            if link then
                local id = tonumber(string.match(link, "item:(%d+):"))
                if id == itemID then table.insert(queue, { bag = bag, slot = slot }) end
            end
        end
    end
    if #queue == 0 then if addon.Notify then addon:Notify("No caches to open for item "..itemID, 'info') end return end
    if not runnerFrame then
        runnerFrame = CreateFrame("Frame")
    end
    openRunner = {
        queue = queue,
        nextTime = 0,
        delay = s.openDelay or 0.3,
        itemID = itemID,
        reserved = s.reservedSlots or 2,
        opened = 0,
    }
    runnerFrame:SetScript("OnUpdate", function(_, elapsed)
        if not openRunner then return end
        local t = GetTime()
        if t < openRunner.nextTime then return end
        -- Check reserved slots
        if CountFreeSlots() < openRunner.reserved then
            if addon.Notify then addon:Notify("Stopped: reserved slots threshold reached.", 'warn') end
            openRunner = nil
            runnerFrame:SetScript("OnUpdate", nil)
            return
        end
        local q = openRunner.queue
        local entry = table.remove(q, 1)
        if not entry then
            if addon.Notify then addon:Notify("Finished opening "..openRunner.opened.." caches.", 'success') end
            openRunner = nil
            runnerFrame:SetScript("OnUpdate", nil)
            return
        end
        UseContainerItem(entry.bag, entry.slot)
        openRunner.opened = openRunner.opened + 1
        openRunner.nextTime = t + openRunner.delay
    end)
    if addon.Notify then addon:Notify("Opening "..#queue.." caches (ID="..itemID..") with delay="..(openRunner.delay)..".", 'info') end
end

local uiFrame
local cacheButtons = {}
local itemSlot

local function CreateUI()
    if uiFrame then return end
    uiFrame = addon.CreateThemedFrame and addon:CreateThemedFrame(UIParent, "HAKCacheOpenerFrame", 380, 260, 'panel') or CreateFrame("Frame", "HAKCacheOpenerFrame", UIParent, "BackdropTemplate")
    uiFrame:SetPoint("CENTER")
    local container
    if addon.ApplyStandardPanelChrome then
        container = addon:ApplyStandardPanelChrome(uiFrame, "Cache Opener", { bodyPadding = { left = 20, right = 22, top = 74, bottom = 18 }, dragBody = true })
    end
    if not container then
        uiFrame:EnableMouse(true)
        uiFrame:SetMovable(true)
        uiFrame:SetClampedToScreen(true)
        uiFrame:RegisterForDrag("LeftButton")
        uiFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        uiFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        if not uiFrame.titleText then
            local title = uiFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            title:SetPoint("TOP", uiFrame, "TOP", 0, -6)
            title:SetText("Cache Opener")
            uiFrame.titleText = title
        end
        if not uiFrame.closeButton then
            local close = CreateFrame("Button", nil, uiFrame, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", uiFrame, "TOPRIGHT", -6, -6)
            close:SetScript("OnClick", function() uiFrame:Hide() end)
            uiFrame.closeButton = close
        end
        container = CreateFrame("Frame", nil, uiFrame)
        container:SetPoint("TOPLEFT", uiFrame, "TOPLEFT", 20, -72)
        container:SetPoint("BOTTOMRIGHT", uiFrame, "BOTTOMRIGHT", -22, 18)
    end
    container = container or uiFrame
    itemSlot = CreateFrame("Button", "HAK_CacheOpener_ItemSlot", container, "ItemButtonTemplate")
    itemSlot:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    itemSlot:SetSize(40,40)
    itemSlot.icon = _G[itemSlot:GetName().."IconTexture"]
    local slotBorder = itemSlot:CreateTexture(nil, "OVERLAY")
    slotBorder:SetAllPoints()
    slotBorder:SetTexture("Interface/Buttons/UI-Quickslot2")
    local slotHelp = container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slotHelp:SetPoint("TOPLEFT", itemSlot, "TOPRIGHT", 12, -2)
    slotHelp:SetWidth(220)
    slotHelp:SetJustifyH("LEFT")
    slotHelp:SetText("Drag cache items here to track.\nRight-click icons below to remove.")
    itemSlot:SetScript("OnReceiveDrag", function(self)
        local infoType, itemID = GetCursorInfo()
        if infoType ~= "item" or not itemID then return end
        if not addon.CacheOpener_IsOpenable(itemID) then if addon.Notify then addon:Notify("Item not an openable cache/bag type.", 'error') end ClearCursor(); return end
        local s = GetSettings()
        for _, id in ipairs(s.cacheItems) do if id == itemID then ClearCursor(); return end end
        table.insert(s.cacheItems, itemID)
        ClearCursor()
        if addon.Notify then addon:Notify("Added cache item ID "..itemID, 'success') end
        addon.CacheOpener_UpdateGrid()
    end)
    itemSlot:SetScript("OnClick", function(self)
        local infoType, itemID = GetCursorInfo()
        if infoType ~= "item" or not itemID then return end
        if not addon.CacheOpener_IsOpenable(itemID) then if addon.Notify then addon:Notify("Item not an openable cache/bag type.", 'error') end ClearCursor(); return end
        local s = GetSettings()
        for _, id in ipairs(s.cacheItems) do if id == itemID then ClearCursor(); return end end
        table.insert(s.cacheItems, itemID)
        ClearCursor()
        if addon.Notify then addon:Notify("Added cache item ID "..itemID, 'success') end
        addon.CacheOpener_UpdateGrid()
    end)
    itemSlot:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Add Cache Type", 0,1,0)
        GameTooltip:AddLine("Drop a cache/chest/bag item here to track it.", 1,1,1, true)
        GameTooltip:AddLine("Right-click grid icons later to remove.", 1,1,1, true)
        GameTooltip:AddLine("Tracked types will appear below with counts.", 0.9,0.9,0.9, true)
        GameTooltip:Show()
    end)
    itemSlot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Scrollable grid container below item slot
    uiFrame.gridScroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    uiFrame.gridScroll:SetPoint("TOPLEFT", itemSlot, "BOTTOMLEFT", -2, -22)
    uiFrame.gridScroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -12, 0)
    uiFrame.gridContent = CreateFrame("Frame", nil, uiFrame.gridScroll)
    uiFrame.gridContent:SetPoint("TOPLEFT")
    uiFrame.gridContent:SetSize(10, 10)
    uiFrame.gridScroll:SetScrollChild(uiFrame.gridContent)
    uiFrame:Hide()
end

local function UpdateGrid()
    CreateUI()
    local s = GetSettings()
    local watched = s.cacheItems
    local counts = ScanBagCounts(watched)
    for _, btn in ipairs(cacheButtons) do btn:Hide() end
    cacheButtons = {}
    local cols = 6
    local size = 32
    local spacing = 4
    local totalWidth = cols*size + (cols-1)*spacing
    local scrollWidth = (uiFrame and uiFrame.gridScroll and uiFrame.gridScroll:GetWidth()) or totalWidth
    local leftOffset = math.max(0, (scrollWidth - totalWidth) / 2)
    uiFrame.gridContent:SetWidth(math.max(scrollWidth, totalWidth))
    for i, itemID in ipairs(watched) do
        local btn = CreateFrame("Button", "HAK_CacheBtn_"..itemID, uiFrame.gridContent)
        btn:SetSize(size,size)
        local row = math.floor((i-1)/cols)
        local col = (i-1)%cols
        btn:SetPoint("TOPLEFT", uiFrame.gridContent, "TOPLEFT", leftOffset + col*(size+spacing), -row*(size+spacing))
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints()
        local texture = select(10, GetItemInfo(itemID)) or "Interface/Icons/INV_Misc_QuestionMark"
        btn.icon:SetTexture(texture)
        local count = counts[itemID] or 0
        if count == 0 then btn.icon:SetVertexColor(0.3,0.3,0.3) else btn.icon:SetVertexColor(1,1,1) end
        btn.countText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.countText:SetPoint("TOP", btn, "BOTTOM", 0, -2)
        btn.countText:SetText(count)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local name, link, quality = GetItemInfo(itemID)
            if name then
                local r,g,b = GetItemQualityColor(quality or 1)
                GameTooltip:AddLine(name, r,g,b)
            else
                GameTooltip:AddLine("Item ID "..itemID, 1,1,1)
            end
            GameTooltip:AddLine("Count: "..count, 1,1,1)
            GameTooltip:AddLine("Left-click: open all caches (reserves "..(s.reservedSlots).." slots)", 0.8,0.8,0.8, true)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:SetScript("OnClick", function(self, btnType)
            if btnType == "RightButton" then
                for idx, id in ipairs(s.cacheItems) do
                    if id == itemID then table.remove(s.cacheItems, idx); break end
                end
                if addon.Notify then addon:Notify("Removed cache item ID "..itemID, 'info') end
                UpdateGrid()
                return
            end
            StartOpening(itemID)
        end)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        table.insert(cacheButtons, btn)
    end
    local rows = math.ceil(#watched / cols)
    local contentHeight = rows*(size+spacing)
    if contentHeight < 160 then contentHeight = 160 end
    uiFrame.gridContent:SetHeight(contentHeight)
    uiFrame.gridScroll:UpdateScrollChildRect()
end
addon.CacheOpener_UpdateGrid = UpdateGrid

local function ToggleUI()
    CreateUI()
    if uiFrame:IsShown() then uiFrame:Hide() else uiFrame:Show(); UpdateGrid() end
end

local function OnTooltip(btn)
    local s = GetSettings()
    local lines = {
        "Cache Opener",
        "Click: Toggle cache opener UI.",
        "Drag & drop cache onto slot to add.",
        "Reserved slots: "..s.reservedSlots.." | Delay: "..s.openDelay.."s",
        "Right-click icon: remove cache type",
    }
    -- Append saved caches and counts
    if #s.cacheItems > 0 then
        table.insert(lines, " ")
        local bagCounts = ScanBagCounts(s.cacheItems)
        for _, itemID in ipairs(s.cacheItems) do
            local name, _, quality = GetItemInfo(itemID)
            local count = bagCounts[itemID] or 0
            if name then
                local r,g,b = GetItemQualityColor(quality or 1)
                local hex = string.format("%02x%02x%02x", r*255, g*255, b*255)
                table.insert(lines, "|cff"..hex..name.."|r: "..count)
            else
                table.insert(lines, "Item "..itemID..": "..count)
            end
        end
    end
    if s.debug then table.insert(lines, "Debug: Enabled") end
    return lines
end

-- Updated icon to a treasure chest for clarity
addon:RegisterToolbarIcon("CacheOpener", "Interface\\Icons\\INV_Box_01", function() ToggleUI() end, OnTooltip)

if addon.RegisterModuleOptions then
    addon:RegisterModuleOptions("CacheOpener", function(panel)
        local settingsSection = addon:CreateSection(panel, "Opening Settings", -8, 580)
        local reservedSlider = CreateFrame("Slider", "HAK_CacheOpener_ReservedSlider", settingsSection, "OptionsSliderTemplate")
        -- Add more space below "Opening Settings" header
        reservedSlider:SetPoint("TOPLEFT", settingsSection, "TOPLEFT", 0, -16)
        reservedSlider:SetWidth(200)
        reservedSlider:SetMinMaxValues(2,10)
        reservedSlider:SetValueStep(1)
        _G[reservedSlider:GetName().."Low"]:SetText("2")
        _G[reservedSlider:GetName().."High"]:SetText("10")
        _G[reservedSlider:GetName().."Text"]:SetText("Reserved Empty Slots")
        local reservedValueText = settingsSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        reservedValueText:SetPoint("LEFT", reservedSlider, "RIGHT", 14, 0)
        do
            local f, size, flags = GameFontNormal:GetFont()
            reservedValueText:SetFont(f, (size or 13)+1, flags)
            reservedValueText:SetTextColor(1,0.95,0.2)
        end
        reservedSlider:SetScript("OnValueChanged", function(self, value)
            local s = GetSettings(); s.reservedSlots = math.floor(value+0.5); addon.CacheOpener_UpdateGrid()
            reservedValueText:SetText(s.reservedSlots)
        end)
        reservedSlider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Reserved Empty Slots", 0,1,0)
            GameTooltip:AddLine("Minimum free bag slots kept while opening.", 1,1,1, true)
            GameTooltip:AddLine("Opening stops when free slots < this value.", 0.9,0.9,0.9, true)
            GameTooltip:Show()
        end)
        reservedSlider:SetScript("OnLeave", function() GameTooltip:Hide() end)
        reservedSlider:SetValue(GetSettings().reservedSlots or 2)
        reservedValueText:SetText(GetSettings().reservedSlots or 2)
        local delaySlider = CreateFrame("Slider", "HAK_CacheOpener_DelaySlider", settingsSection, "OptionsSliderTemplate")
        delaySlider:SetPoint("TOPLEFT", reservedSlider, "BOTTOMLEFT", 0, -40)
        delaySlider:SetWidth(200)
        delaySlider:SetMinMaxValues(0.1, 1.0)
        delaySlider:SetValueStep(0.05)
        _G[delaySlider:GetName().."Low"]:SetText("0.1")
        _G[delaySlider:GetName().."High"]:SetText("1.0")
        _G[delaySlider:GetName().."Text"]:SetText("Delay Between Opens (s)")
        local delayValueText = settingsSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        delayValueText:SetPoint("LEFT", delaySlider, "RIGHT", 14, 0)
        do
            local f, size, flags = GameFontNormal:GetFont()
            delayValueText:SetFont(f, (size or 13)+1, flags)
            delayValueText:SetTextColor(1,0.95,0.2)
        end
        delaySlider:SetScript("OnValueChanged", function(self, value)
            local s = GetSettings(); s.openDelay = tonumber(string.format("%.2f", value))
            delayValueText:SetText(string.format("%.2f s", s.openDelay))
        end)
        delaySlider:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Delay Between Opens", 0,1,0)
            GameTooltip:AddLine("Seconds waited between each cache open.", 1,1,1, true)
            GameTooltip:AddLine("Lower = faster chain opening.", 0.9,0.9,0.9, true)
            GameTooltip:Show()
        end)
        delaySlider:SetScript("OnLeave", function() GameTooltip:Hide() end)
        delaySlider:SetValue(GetSettings().openDelay or 0.3)
        delayValueText:SetText(string.format("%.2f s", GetSettings().openDelay or 0.3))
        -- Adjust section height to encompass sliders and spacing to prevent overlap with next section
        local function AdjustSettingsSectionHeight()
            local top = settingsSection:GetTop()
            local bottom = delaySlider:GetBottom()
            if top and bottom then
                local h = top - bottom + 48 -- padding
                if h < 120 then h = 120 end
                settingsSection:SetHeight(h)
            else
                settingsSection:SetHeight(140)
            end
        end
        AdjustSettingsSectionHeight()
        local debugSection = addon:CreateSection(panel, "Debug", -24, 580)
        local dcb = CreateFrame("CheckButton", "HAK_CacheOpener_DebugCB", debugSection, "InterfaceOptionsCheckButtonTemplate")
        dcb:SetPoint("TOPLEFT", debugSection, "TOPLEFT", 0, 0)
        _G[dcb:GetName() .. "Text"]:SetText("Enable debug info")
        dcb:SetChecked(GetSettings().debug)
        dcb:SetScript("OnClick", function(self)
            local s = GetSettings(); s.debug = self:GetChecked() and true or false
        end)
        debugSection:SetHeight(40)
    end)
end

-- Refresh grid on bag updates
local bagFrame = CreateFrame("Frame")
bagFrame:RegisterEvent("BAG_UPDATE")
bagFrame:SetScript("OnEvent", function()
    if uiFrame and uiFrame:IsShown() then addon.CacheOpener_UpdateGrid() end
end)
