local addonName, addon = ...

-- About module has no persistent settings; uses RegisterInit if needed in future.

local function EnsureAboutWindow()
    if addon._AboutInfoWindow then return addon._AboutInfoWindow end
    local w = addon.CreateThemedFrame and addon:CreateThemedFrame(UIParent, "HAK_AboutInfo", 460, 360, 'panel') or CreateFrame("Frame", "HAK_AboutInfo", UIParent, "BackdropTemplate")
    w:SetPoint("CENTER", UIParent, "CENTER", -20, 40)
    w:EnableMouse(true)
    w:SetMovable(true)
    local drag = CreateFrame("Frame", nil, w)
    drag:SetPoint("TOPLEFT", w, "TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", w, "TOPRIGHT", -34, 0)
    drag:SetHeight(34)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() w:StartMoving() end)
    drag:SetScript("OnDragStop", function() w:StopMovingOrSizing() end)
    -- Extend draggable area by +100px to the right without overlapping close button reservation
    local dragExt = CreateFrame("Frame", nil, w)
    dragExt:SetPoint("TOPRIGHT", w, "TOPRIGHT", -34, 0)
    dragExt:SetHeight(34)
    dragExt:SetWidth(100)
    dragExt:EnableMouse(true)
    dragExt:RegisterForDrag("LeftButton")
    dragExt:SetScript("OnDragStart", function() w:StartMoving() end)
    dragExt:SetScript("OnDragStop", function() w:StopMovingOrSizing() end)
    local title = w:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", w, "TOP", 0, 0)
    title:SetText("About")
    local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -4, -4)
    close:SetFrameLevel(w:GetFrameLevel()+10)
    close:SetScript("OnClick", function() w:Hide() end)
    local scroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", w, "TOPLEFT", 12, -40)
    scroll:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -30, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(400, 10)
    scroll:SetScrollChild(content)
    w.content = content
    -- Discord quick-copy button (repositioned inline after link in Credits section during Refresh)
    local copyBtn = CreateFrame("Button", nil, w.content, "UIPanelButtonTemplate")
    copyBtn:SetSize(110,20)
    copyBtn:SetPoint("TOPLEFT", w.content, "TOPLEFT", 0, 0) -- temporary anchor; real placement set in Refresh()
    copyBtn:SetText("Copy Link")
    copyBtn:SetScript("OnClick", function()
        if not StaticPopupDialogs["HAK_DISCORD_INVITE"] then
            StaticPopupDialogs["HAK_DISCORD_INVITE"] = {
                text = "Discord Invite - Press Ctrl+C",
                button1 = OKAY,
                hasEditBox = true,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
                OnShow = function(self)
                    self.editBox:SetText("https://discord.gg/PzzmbxQyRy")
                    self.editBox:HighlightText()
                    self.editBox:SetFocus()
                end,
                EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
            }
        end
        StaticPopup_Show("HAK_DISCORD_INVITE")
    end)
    w.discordCopyBtn = copyBtn

    w._sections = {}

    function w:Refresh()
        for _, f in ipairs(w._sections) do f:Hide() end
        wipe(w._sections)
        local ms = HerosArmyKnifeDB.settings.moduleSettings
        local about = ms and ms.About or {}
        local author = about.author or "Agset"
        local hasDebug = addon.moduleRegistry and addon.moduleRegistry['DebugTools']
        local y = 0
        local function addHeader(text, color)
            local hdr = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            hdr:SetPoint("TOP", content, "TOP", 0, y)
            hdr:SetJustifyH("CENTER")
            local c = color or {1,0.82,0}
            hdr:SetText(string.format("|cff%02x%02x%02x%s|r", c[1]*255, c[2]*255, c[3]*255, text))
            y = y - (hdr:GetStringHeight() + 10)
            table.insert(w._sections, hdr)
            return hdr
        end
        local function addText(lines, justify, color)
            if type(lines) == 'string' then lines = { lines } end
            local container = CreateFrame("Frame", nil, content)
            container:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            container:SetWidth(380)
            container._lineFS = {}
            local prev
            for _, line in ipairs(lines) do
                local fs = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                fs:SetWidth(380)
                fs:SetJustifyH(justify or "LEFT")
                fs:SetPoint("TOPLEFT", prev or container, prev and "BOTTOMLEFT" or "TOPLEFT", 0, prev and -4 or 0)
                if color then
                    fs:SetText(string.format("|cff%02x%02x%02x%s|r", color[1]*255, color[2]*255, color[3]*255, line))
                else
                    fs:SetText(line)
                end
                table.insert(container._lineFS, fs)
                prev = fs
            end
            -- Robust height calculation using string heights (avoids nil GetBottom during initial build)
            local totalH = 0
            for i, fs in ipairs(container._lineFS) do
                local sh = fs:GetStringHeight()
                if not sh or sh == 0 then sh = 14 end
                totalH = totalH + sh
                if i < #container._lineFS then totalH = totalH + 4 end -- inter-line spacing
            end
            container:SetHeight(totalH + 4)
            y = y - (container:GetHeight() + 14)
            table.insert(w._sections, container)
            return container
        end
        -- Sections
        addHeader("Overview", {0.2,0.85,0.6})
        addText({"HerosArmyKnife is a modular utility toolbar providing quick access","to gameplay helpers and QoL features."}, "CENTER")
        addHeader("Modules", {1,0.82,0})
        local moduleLines = {
            "|cff4D94FFMythicPlusHelper|r - Keystone tracking with combat-aware scans; right-click icon for monitoring toggle, party info, recruitment UI, and LFG monitor.",
            "|cff00C8FFCacheOpener|r - Tracks watched cache items, enforces reserved bag slots, and opens stacks with a configurable delay.",
            "|cffFF6A00SellTrash|r - Auto-sell poor quality items plus user-tracked goods; toolbar left-click opens tracked list, right-click opens protected list.",
            "|cff33FF99Transmog|r - Safe in-addon collector that scans bags for unowned appearances; optional custom macro execution.",
            "|cffFFAA00RareTracker|r - Detects rare/rare-elite targets, optional raid marker, alert popup, and sound notification.",
            "|cffC8C800Settings|r - Global theme, toolbar layout, notification routing, and module toggles.",
            "|cffE6CC80Reload|r - One-click /reload shortcut for faster UI iteration.",
            "|cffAAAAFFAbout|r - Module reference, credits, and Discord invite.",
        }
        if hasDebug then table.insert(moduleLines, "|cffFF8800DebugTools|r - Development sandbox: inject sample data, trigger module tests, toggle live monitors.") end
        addText(moduleLines)
        addHeader("Credits", {1,0.5,0.85})
        local creditsPara = addText({"Author: |cff33FF99"..author.."|r","Discord: |cff7289DAhttps://discord.gg/PzzmbxQyRy|r","Thank you for using HerosArmyKnife!"}, "CENTER")
        -- Position copy button directly BELOW the Discord link line instead of inline
        if w.discordCopyBtn and creditsPara and creditsPara._lineFS and creditsPara._lineFS[2] then
            w.discordCopyBtn:ClearAllPoints()
            w.discordCopyBtn:SetParent(creditsPara)
            w.discordCopyBtn:SetPoint("TOPLEFT", creditsPara._lineFS[2], "CENTER", -40, -40)
            w.discordCopyBtn:Show()
        end
        local totalHeight = math.abs(y) + 20
        -- Ensure overall content height accounts for button placed below last measured line
        if w.discordCopyBtn and w.discordCopyBtn:IsShown() then
            local btnBottom = w.discordCopyBtn:GetBottom()
            local contentBottom = content:GetBottom()
            if btnBottom and contentBottom and btnBottom < contentBottom then
                local diff = contentBottom - btnBottom + 12
                totalHeight = totalHeight + diff
            else
                -- Simple fallback: add button height spacing
                totalHeight = totalHeight + (w.discordCopyBtn:GetHeight() + 12)
            end
        end
        if totalHeight < 300 then totalHeight = 300 end
        content:SetHeight(totalHeight)
    end
    w:Refresh()
    -- Start hidden so the first toolbar click shows the window instead of immediately hiding it.
    w:Hide()
    addon._AboutInfoWindow = w
    return w
end

local function OnClick(btn)
    local w = EnsureAboutWindow()
    if w:IsShown() then w:Hide() else w:Show(); w:Refresh() end
end

-- Single tooltip builder (removed duplicate definitions and stray code)
local function OnTooltip(btn)
    return {
        "HerosArmyKnife (About)",
        "Click: Toggle info window.",
        "Drag toolbar frame to reposition.",
    }
end

-- Register toolbar icon once
addon:RegisterToolbarIcon("About", "Interface\\Icons\\INV_Scroll_11", OnClick, OnTooltip)

-- No module options panel needed; previously removed.

-- End of About module
