local addonName, addon = ...

-- Default transmog collection macro (reusable)
local DEFAULT_TRANSMOG_MACRO = [[/run local c=C_AppearanceCollection for b=0,4 do for s=1,GetContainerNumSlots(b) do local i=GetContainerItemID(b,s) local a=i and C_Appearance.GetItemAppearanceID(i) if a and not c.IsAppearanceCollected(a) then c.CollectItemAppearance(i) end end end]]

addon:RegisterInit(function()
    if addon.GetModuleSettings then
        local s = addon:GetModuleSettings('Transmog', { macro = DEFAULT_TRANSMOG_MACRO, debug = false })
        if not s.macro or s.macro == '' then s.macro = DEFAULT_TRANSMOG_MACRO end
    end
end)

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('Transmog', { macro = DEFAULT_TRANSMOG_MACRO, debug = false }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.Transmog or { macro = "" }
end

local function ExecuteMacro()
    local s = GetSettings()
    local macro = s.macro or ''
    if macro == '' then if addon.Print then addon.Print("Transmog macro empty.") end return end
    -- Split macro into lines and execute /run or /script parts
    for line in string.gmatch(macro, "[^\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line:find("^/run") then
            local code = line:sub(5)
            local f, err = loadstring(code)
            if f then
                local ok, perr = pcall(f)
                if not ok and addon.Print then addon.Print("Transmog macro error: "..tostring(perr)) end
            elseif addon.Print then addon.Print("Macro compile error: "..tostring(err)) end
        elseif line:find("^/script") then
            local code = line:sub(8)
            local f, err = loadstring(code)
            if f then
                local ok, perr = pcall(f)
                if not ok and addon.Print then addon.Print("Transmog macro error: "..tostring(perr)) end
            elseif addon.Print then addon.Print("Macro compile error: "..tostring(err)) end
        end
    end
    if addon.Print then addon.Print("|cff00ff00Transmog macro executed.|r") end
end

local function OnClick(btn)
    -- Fallback direct execution if secure button not yet ready
    ExecuteMacro()
end

local function OnTooltip(btn)
    local s = GetSettings()
    local lines = {
        "Transmog Collector",
        "Click: Add all missing item appearances from your bags to your vanity collection.",
        "Edit or replace the macro in module options.",
    }
    if s.debug then table.insert(lines, "Debug: Enabled") end
    return lines
end

-- Use a shirt icon to represent appearance/transmog collection
addon:RegisterToolbarIcon("Transmog", "Interface\\Icons\\INV_Shirt_16", OnClick, OnTooltip)

-- Secure macro execution overlay (needed for some protected functions/macros)
local secureReadyFrame
local function Transmog_EnsureSecureButton()
    local s = GetSettings()
    local btn = _G["HAKToolbarBtn_Transmog"]
    if not btn or btn._hakSecureAttached then return end
    local sb = CreateFrame("Button", "HAK_TransmogSecureButton", btn, "SecureActionButtonTemplate")
    sb:SetAllPoints(btn)
    sb:RegisterForClicks("LeftButtonUp")
    sb:SetAttribute("type", "macro")
    sb:SetAttribute("macrotext", s.macro or DEFAULT_TRANSMOG_MACRO)
    -- Tooltip passthrough
    sb:SetScript("OnEnter", function()
        if btn:GetScript("OnEnter") then btn:GetScript("OnEnter")(btn) end
    end)
    sb:SetScript("OnLeave", function()
        if btn:GetScript("OnLeave") then btn:GetScript("OnLeave")(btn) end
    end)
    btn._hakSecureAttached = true
    addon.Transmog_UpdateSecureButton = function()
        local s2 = GetSettings()
        if sb then sb:SetAttribute("macrotext", s2.macro or DEFAULT_TRANSMOG_MACRO) end
    end
end

-- Poll until toolbar button exists (after toolbar build)
secureReadyFrame = CreateFrame("Frame")
secureReadyFrame.elapsed = 0
secureReadyFrame:SetScript("OnUpdate", function(self, e)
    self.elapsed = self.elapsed + e
    if self.elapsed > 0.2 then
        Transmog_EnsureSecureButton()
        if _G["HAKToolbarBtn_Transmog"] and _G["HAKToolbarBtn_Transmog"]._hakSecureAttached then
            self:SetScript("OnUpdate", nil)
        else
            self.elapsed = 0
        end
    end
end)

if addon.RegisterModuleOptions then
    addon:RegisterModuleOptions("Transmog", function(panel)
        local macroSection = addon:CreateSection(panel, "Macro Script")
        macroSection:SetHeight(250)
        local infoText = macroSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        infoText:SetPoint("TOPLEFT", macroSection, "TOPLEFT", 0, 0)
        infoText:SetWidth(400)
        infoText:SetJustifyH("LEFT")
        infoText:SetText("Edit the macro executed on left-click. Only /run or /script lines are executed. Apply to save.")
        local scroll = CreateFrame("ScrollFrame", "HAK_TransmogMacroScroll", macroSection, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", -4, -8)
        scroll:SetSize(400, 160)
        local edit = CreateFrame("EditBox", "HAK_TransmogMacroEdit", scroll, "BackdropTemplate")
        edit:SetPoint("TOPLEFT", scroll, "TOPLEFT", 4, -4)
        edit:SetMultiLine(true)
        edit:SetFontObject(GameFontHighlightSmall)
        edit:SetWidth(380)
        edit:SetHeight(152)
        edit:SetAutoFocus(false)
        edit:SetTextInsets(4,4,4,4)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        edit:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = {left=2,right=2,top=2,bottom=2} })
        edit:SetBackdropColor(0,0,0,0.85)
        edit:SetBackdropBorderColor(0.8,0.8,0.8,0.7)
        scroll:SetScrollChild(edit)
        local s = GetSettings()
        if not s.macro or s.macro == '' then s.macro = DEFAULT_TRANSMOG_MACRO end
        edit:SetText(s.macro)
        edit:SetCursorPosition(0)
        edit:HighlightText(0,0)
        edit:SetScript("OnTextChanged", function(self)
            -- Some client builds lack GetStringHeight; use GetTextHeight fallback
            local h = (self.GetStringHeight and self:GetStringHeight()) or (self.GetTextHeight and self:GetTextHeight()) or 152
            if h < 152 then h = 152 end
            self:SetHeight(h + 8)
            if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        end)
        local applyBtn = CreateFrame("Button", nil, macroSection, "UIPanelButtonTemplate")
        applyBtn:SetSize(80, 22)
        applyBtn:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", 0, -8)
        applyBtn:SetText("Apply")
        applyBtn:SetScript("OnClick", function()
            local s2 = GetSettings()
            s2.macro = edit:GetText() or ''
            if addon.Print then addon.Print("Transmog macro updated.") end
            if addon.Transmog_UpdateSecureButton then addon.Transmog_UpdateSecureButton() end
        end)
        local resetBtn = CreateFrame("Button", nil, macroSection, "UIPanelButtonTemplate")
        resetBtn:SetSize(80,22)
        resetBtn:SetPoint("LEFT", applyBtn, "RIGHT", 8, 0)
        resetBtn:SetText("Reset")
        resetBtn:SetScript("OnClick", function()
            local s2 = GetSettings(); s2.macro = DEFAULT_TRANSMOG_MACRO; edit:SetText(s2.macro)
            if addon.Print then addon.Print("Transmog macro reset to default.") end
            if addon.Transmog_UpdateSecureButton then addon.Transmog_UpdateSecureButton() end
        end)
        -- Refresh macro text when panel shown
        panel:SetScript("OnShow", function()
            local st = GetSettings(); if not st.macro or st.macro == '' then st.macro = DEFAULT_TRANSMOG_MACRO end; edit:SetText(st.macro)
        end)
        local debugSection = addon:CreateSection(panel, "Debug", -12)
        local dcb = CreateFrame("CheckButton", "HAK_Transmog_DebugCB", debugSection, "InterfaceOptionsCheckButtonTemplate")
        dcb:SetPoint("TOPLEFT", debugSection, "TOPLEFT", 0, 0)
        _G[dcb:GetName() .. "Text"]:SetText("Enable debug info")
        dcb:SetChecked(GetSettings().debug)
        dcb:SetScript("OnClick", function(self)
            local s3 = GetSettings(); s3.debug = self:GetChecked() and true or false
        end)
    end)
end
