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
    local text = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetWidth(380)
    w.text = text

    function w:Refresh()
        local ms = HerosArmyKnifeDB.settings.moduleSettings
        local about = ms and ms.About or {}
        local author = about.author or "Agset"
        local lines = {
            "|cff33FF99Overview|r",
            "HerosArmyKnife is a modular utility toolbar providing quick access to gameplay helpers.",
            " ",
            "|cffFFD200Modules|r",
            "|cff4D94FFMythicPlusHelper|r: Keystone icon, LFG monitoring (dynamic filtered list), recruitment message builder, role marking (Circle tank / Moon healer), animated status indicators.",
            "|cff00C8FFCacheOpener|r: Streamlines opening cache/chest style containers with a single click interface.",
            "|cffFF6A00SellTrash|r: Quickly sells poor-quality (grey) items to vendors to free bag space.",
            "|cff33FF99Transmog|r: Executes customizable macro to collect unowned item appearances from your bags.",
            "|cffB5B5B5Reload|r: Provides fast UI reload convenience (if present).",
            "|cffC8C800Settings|r: Central configuration panel (orientation, spacing, theme, notifications).",
            "|cffAAAAFFAbout|r: This info window and basic addon usage guidance.",
            " ",
            "|cffFFD200Features|r",
            "Colored, animated monitoring aura & ring indicators, memory-conscious row pooling, throttled UI refresh, role-based party marking, hover highlight effects on toolbar icons, persistent settings.",
            " ",
            "|cffFF80FFCredits|r",
            "Author: |cff33FF99"..author.."|r",
            "Thank you for using HerosArmyKnife!",
        }
        text:SetText(table.concat(lines, "\n"))
        local h = text:GetStringHeight() or 300
        content:SetHeight(h + 12)
    end
    w:Refresh()
    addon._AboutInfoWindow = w
    return w
end

local function OnClick(btn)
    local w = EnsureAboutWindow()
    if w:IsShown() then w:Hide() else w:Show(); w:Refresh() end
end

local function GetSettings() return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.About or { debug = false } end

local function OnTooltip(btn)
    local lines = {
        "HerosArmyKnife (About)",
        "Drag frame to move toolbar.",
        "Right-click toolbar frame for settings.",
        "Use the gear icon to open options.",
    }
    if GetSettings().debug then
        table.insert(lines, "Debug: Enabled")
    end
    return lines
end

-- Use a scroll icon for About information
addon:RegisterToolbarIcon("About", "Interface\\Icons\\INV_Scroll_11", OnClick, OnTooltip)

addon:RegisterInit(function()
    local ms = HerosArmyKnifeDB.settings.moduleSettings
    ms.About = ms.About or { debug = false, author = ms.About and ms.About.author or "HerosArmyKnife" }
end)

if addon.RegisterModuleOptions then
    addon:RegisterModuleOptions("About", function(panel)
        local debugSection = addon:CreateSection(panel, "Debug")
        local cb = CreateFrame("CheckButton", "HAK_About_DebugCB", debugSection, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", debugSection, "TOPLEFT", 0, 0)
        _G[cb:GetName() .. "Text"]:SetText("Enable debug info")
        cb:SetChecked(GetSettings().debug)
        cb:SetScript("OnClick", function(self)
            local s = GetSettings(); s.debug = self:GetChecked() and true or false
        end)
        local authorLabel = debugSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        authorLabel:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -10)
        authorLabel:SetText("Author Name:")
        local authorEdit = CreateFrame("EditBox", "HAK_About_AuthorEdit", debugSection, "InputBoxTemplate")
        authorEdit:SetAutoFocus(false)
        authorEdit:SetSize(180, 20)
        authorEdit:SetPoint("LEFT", authorLabel, "RIGHT", 8, 0)
        authorEdit:SetText((GetSettings().author or "HerosArmyKnife"))
        authorEdit:SetCursorPosition(0)
        authorEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        authorEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        authorEdit:SetScript("OnTextChanged", function(self, user)
            if not user then return end
            local s = GetSettings(); s.author = self:GetText()
            if addon._AboutInfoWindow and addon._AboutInfoWindow:IsShown() then addon._AboutInfoWindow:Refresh() end
        end)
        panel:SetScript("OnShow", function() authorEdit:SetText(GetSettings().author or "HerosArmyKnife") end)
    end)
end
