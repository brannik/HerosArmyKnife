local addonName, addon = ...

-- Default transmog collection macro (reusable)
local DEFAULT_TRANSMOG_MACRO = [[/run local c=C_AppearanceCollection for b=0,4 do for s=1,GetContainerNumSlots(b) do local i=GetContainerItemID(b,s) local a=i and C_Appearance.GetItemAppearanceID(i) if a and not c.IsAppearanceCollected(a) then c.CollectItemAppearance(i) end end end]]

addon:RegisterInit(function()
    if addon.GetModuleSettings then
        local s = addon:GetModuleSettings('Transmog', { macro = DEFAULT_TRANSMOG_MACRO, debug = false, useMacro = false })
        if not s.macro or s.macro == '' then s.macro = DEFAULT_TRANSMOG_MACRO end
    end
end)

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('Transmog', { macro = DEFAULT_TRANSMOG_MACRO, debug = false, useMacro = false }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.Transmog or { macro = "", useMacro = false }
end

-- Internal collector (recommended): avoids /run macros to reduce taint
local function ExecuteCollector()
    local okAny = false
    local errors = 0
    local c = _G.C_AppearanceCollection or _G.C_Appearance or {}
    local apiCollect = c.CollectItemAppearance or (C_AppearanceCollection and C_AppearanceCollection.CollectItemAppearance)
    local apiGetId = (C_Appearance and C_Appearance.GetItemAppearanceID) or (c.GetItemAppearanceID)
    if not apiCollect or not apiGetId then
        if addon.Notify then addon:Notify("Transmog API missing on this client.", 'warn') elseif addon.Print then addon.Print("Transmog API missing on this client.") end
        return
    end
    for bag=0,4 do
        local slots = GetContainerNumSlots and GetContainerNumSlots(bag) or 0
        for slot=1,slots do
            local itemID = GetContainerItemID and GetContainerItemID(bag, slot)
            if itemID then
                local aID
                local ok1, err1 = pcall(function() aID = apiGetId(itemID) end)
                if ok1 and aID then
                    local collected = false
                    local ok2 = pcall(function() collected = (C_AppearanceCollection and C_AppearanceCollection.IsAppearanceCollected and C_AppearanceCollection.IsAppearanceCollected(aID)) or false end)
                    if ok2 and not collected then
                        local ok3 = pcall(function() apiCollect(itemID) end)
                        if ok3 then okAny = true else errors = errors + 1 end
                    end
                else
                    errors = errors + 1
                end
            end
        end
    end
    if okAny then
        if addon.Notify then addon:Notify("Collected new appearances from bags.", 'success') elseif addon.Print then addon.Print("Collected new appearances from bags.") end
    else
        if addon.Notify then addon:Notify("No new appearances found.", 'info') elseif addon.Print then addon.Print("No new appearances found.") end
    end
end

local function NormalizeNewlines(text)
    if not text then return "" end
    text = tostring(text)
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    return text
end

local function ExecuteMacro()
    local s = GetSettings()
    local macro = NormalizeNewlines(s.macro or '')
    if macro == '' then if addon.Print then addon.Print("Transmog macro empty.") end return end
    -- Prefer RunMacroText for full macro compatibility when available and allowed
    if type(RunMacroText) == "function" then
        if InCombatLockdown and InCombatLockdown() then
            if addon.Notify then addon:Notify("Cannot run macro during combat.", 'warn') elseif addon.Print then addon.Print("Cannot run macro during combat.") end
            return
        end
        local ok, err = pcall(RunMacroText, macro)
        if ok then
            if addon.Print then addon.Print("|cff00ff00Transmog macro executed.|r") end
            return
        else
            if addon.Print then addon.Print("RunMacroText failed, falling back. "..tostring(err)) end
        end
    end
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
    local s = GetSettings()
    -- If user opted into macro mode, rely on secure overlay to fire the macro.
    if s.useMacro then
        if InCombatLockdown and InCombatLockdown() then
            if addon.Notify then addon:Notify("Cannot run macro during combat.", 'warn') elseif addon.Print then addon.Print("Cannot run macro during combat.") end
            return
        end
        local overlay = _G["HAK_TransmogSecureButton"]
        if overlay and overlay:IsShown() then
            if addon.Transmog_UpdateSecureButton then addon.Transmog_UpdateSecureButton() end
            -- Secure button consumes the click; nothing else to do.
            return
        end
        -- Fallback if secure button missing: execute macro directly.
        ExecuteMacro()
        return
    end
    -- Recommended internal collector path
    if InCombatLockdown and InCombatLockdown() then
        if addon.Notify then addon:Notify("Cannot collect during combat.", 'warn') elseif addon.Print then addon.Print("Cannot collect during combat.") end
        return
    end
    ExecuteCollector()
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
    if not btn then return end
    -- Only attach secure button in macro mode
    if not s.useMacro then
        local sb = _G["HAK_TransmogSecureButton"]
        if sb then sb:Hide(); sb:EnableMouse(false); btn._hakSecureAttached = nil end
        return
    end
    if btn._hakSecureAttached then return end
    local sb = CreateFrame("Button", "HAK_TransmogSecureButton", btn, "SecureActionButtonTemplate")
    sb:SetAllPoints(btn)
    sb:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
    local macroText = NormalizeNewlines(s.macro or DEFAULT_TRANSMOG_MACRO)
    sb:SetAttribute("type", "macro")
    sb:SetAttribute("type1", "macro")
    sb:SetAttribute("type2", "macro")
    sb:SetAttribute("macrotext", macroText)
    sb:SetAttribute("macrotext1", macroText)
    sb:SetAttribute("macrotext2", macroText)
    sb:SetScript("PostClick", function()
        if addon.Print then addon.Print("|cff00ff00Collected uncollected appearances!|r") end
        if addon.Notify then addon:Notify("Collected uncollected appearances!", 'success') end
    end)
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
        local cur = _G["HAK_TransmogSecureButton"]
        if s2.useMacro then
            if not cur then Transmog_EnsureSecureButton(); cur = _G["HAK_TransmogSecureButton"] end
            if cur then
                local mt = NormalizeNewlines(s2.macro or DEFAULT_TRANSMOG_MACRO)
                cur:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
                cur:SetAttribute("type", "macro")
                cur:SetAttribute("type1", "macro")
                cur:SetAttribute("type2", "macro")
                cur:SetAttribute("macrotext", mt)
                cur:SetAttribute("macrotext1", mt)
                cur:SetAttribute("macrotext2", mt)
                cur:Show(); cur:EnableMouse(true)
            end
        else
            if cur then cur:Hide(); cur:EnableMouse(false) end
        end
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
        infoText:SetText("Default left-click uses an internal collector (recommended). Optionally enable macro mode below if you need custom behavior. Only /run or /script lines are executed. Apply to save.")
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
            s2.macro = NormalizeNewlines(edit:GetText() or '')
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
        local runBtn = CreateFrame("Button", nil, macroSection, "UIPanelButtonTemplate")
        runBtn:SetSize(90,22)
        runBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
        runBtn:SetText("Run Macro Now")
        runBtn:SetScript("OnClick", function()
            ExecuteMacro()
        end)
        local modeSection = addon:CreateSection(panel, "Execution Mode", -12)
        local cb = CreateFrame("CheckButton", "HAK_Transmog_UseMacroCB", modeSection, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", modeSection, "TOPLEFT", 0, 0)
        _G[cb:GetName() .. "Text"]:SetText("Use macro on left-click (advanced, may cause taint)")
        cb:SetChecked(GetSettings().useMacro)
        cb:SetScript("OnClick", function(self)
            local s3 = GetSettings(); s3.useMacro = self:GetChecked() and true or false
            if addon.Transmog_UpdateSecureButton then addon.Transmog_UpdateSecureButton() end
        end)
        -- Refresh macro text when panel shown
        panel:SetScript("OnShow", function()
            local st = GetSettings(); if not st.macro or st.macro == '' then st.macro = DEFAULT_TRANSMOG_MACRO end; edit:SetText(st.macro)
            if cb then cb:SetChecked(st.useMacro and true or false) end
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
