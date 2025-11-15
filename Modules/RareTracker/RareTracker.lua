local addonName, addon = ...

-- RareTracker: Detect nearby rare or rare-elite mobs when targeted or moused over; announce & optionally mark.
-- NOTE: On 3.3.5 client we do not have modern vignette APIs; detection relies on target / mouseover classification.
-- Future enhancement: optional nameplate scan (fragile); disabled for performance & reliability.

local DEFAULTS = { debug = false, autoMark = true, announce = true, repeatDelay = 300, markerIcon = 8, monitoring = true, popup = true, disableInRested = true, ambientScan = false, sound = true, soundChoice = 'RaidWarning' }

addon:RegisterInit(function()
    if addon.GetModuleSettings then addon:GetModuleSettings('RareTracker', DEFAULTS) end
end)

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('RareTracker', DEFAULTS) end
    return DEFAULTS
end

local lastSeen = {} -- GUID -> timestamp of last announce
local recentNames = {} -- name -> timestamp (fallback if GUID missing)

local function CanMark()
    -- You can always mark when solo; in group need leader/assist privileges.
    if not IsInGroup() then return true end
    return (IsPartyLeader() or IsRaidLeader() or IsRaidOfficer())
end

local function MarkUnit(unit, icon)
    if not UnitExists(unit) then return end
    if not CanMark() then return end
    SetRaidTarget(unit, icon or GetSettings().markerIcon or 8)
end

local function ShouldAnnounce(guid, name)
    local delay = GetSettings().repeatDelay or 300
    local now = time()
    if guid and guid ~= "" then
        local last = lastSeen[guid]
        if last and (now - last) < delay then return false end
        lastSeen[guid] = now
        return true
    end
    if name and name ~= "" then
        local last = recentNames[name]
        if last and (now - last) < delay then return false end
        recentNames[name] = now
        return true
    end
    return true
end

local function ClassifyAndHandle(unit)
    if not UnitExists(unit) then return end
    local s = GetSettings()
    if s.disableInRested and IsResting and IsResting() then return end
    if not s.monitoring then return end
    local class = UnitClassification(unit) -- "normal","elite","worldboss","rare","rareelite" etc.
    if not class then return end
    if class ~= "rare" and class ~= "rareelite" then return end
    local name = UnitName(unit) or "(unknown)"
    local guid = UnitGUID(unit)
    if not ShouldAnnounce(guid, name) then return end
    -- Popup display
    if s.popup then RareTracker_ShowPopup(name, class, guid) end
    if s.announce and addon.Notify then
        local iconTex = UnitPortraitTexture and UnitPortraitTexture(unit) -- often nil; fallback to skull icon
        addon:Notify("Rare detected: "..name.." ("..class..")", 'warn', iconTex)
    end
    if s.sound then RareTracker_PlaySound(s.soundChoice) end
    if s.autoMark then MarkUnit(unit, s.markerIcon) end
    if s.debug and addon.Print then addon.Print("RareTracker: handled "..name.." guid="..tostring(guid)) end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:SetScript("OnEvent", function(_, event)
    if not addon.IsModuleEnabled or not addon:IsModuleEnabled('RareTracker') then return end
    if event == "PLAYER_TARGET_CHANGED" then
        ClassifyAndHandle("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        ClassifyAndHandle("mouseover")
    end
end)

-- Toolbar integration
local function OnClick(btn)
    local s = GetSettings()
    -- Left click: toggle monitoring
    if IsShiftKeyDown() then
        ClassifyAndHandle("target")
    else
        s.monitoring = not s.monitoring
        if addon.Notify then addon:Notify("RareTracker monitoring "..(s.monitoring and "enabled" or "disabled"), s.monitoring and 'success' or 'warn') end
    end
end

local function OnTooltip(btn)
    local s = GetSettings()
    local lines = {
        "Rare Tracker",
        "Click: toggle monitoring | Shift-Click: manual check target",
        string.format("Monitoring: %s", s.monitoring and "ON" or "OFF"),
        string.format("Auto Mark: %s", s.autoMark and "ON" or "OFF"),
        string.format("Popup: %s", s.popup and "ON" or "OFF"),
        string.format("Rested Suppress: %s", s.disableInRested and "ON" or "OFF"),
        string.format("Repeat Delay: %ds", s.repeatDelay or 300),
        string.format("Marker Icon: %d", s.markerIcon or 8),
        string.format("Ambient Scan: %s", s.ambientScan and "ON" or "OFF"),
        string.format("Sound: %s (%s)", s.sound and "ON" or "OFF", s.soundChoice or "RaidWarning"),
    }
    if s.debug then table.insert(lines, "Debug: Enabled") end
    return lines
end

addon:RegisterToolbarIcon("RareTracker", "Interface\\Icons\\Ability_Hunter_MasterMarksman", OnClick, OnTooltip)

-- Module options
-- Popup UI
local popupFrame
function RareTracker_ShowPopup(name, class, guid)
    local s = GetSettings(); if not s.popup then return end
    if s.disableInRested and IsResting and IsResting() then return end
    if not popupFrame then
        popupFrame = addon.CreateThemedFrame and addon:CreateThemedFrame(UIParent, "HAKRarePopup", 240, 90, 'panel') or CreateFrame("Frame", "HAKRarePopup", UIParent, "BackdropTemplate")
        popupFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
        popupFrame:EnableMouse(true)
        local title = popupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, 0)
        popupFrame.title = title
        local info = popupFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        info:SetPoint("TOP", title, "BOTTOM", 0, -4)
        popupFrame.info = info
        local markBtn = CreateFrame("Button", nil, popupFrame, "UIPanelButtonTemplate")
        markBtn:SetSize(80, 20)
        markBtn:SetPoint("BOTTOMLEFT", 12, 12)
        markBtn:SetText("Mark Skull")
        popupFrame.markBtn = markBtn
        markBtn:SetScript("OnClick", function()
            if popupFrame._unitGuid and popupFrame._unitGuid == UnitGUID("target") then
                MarkUnit("target", 8)
            else
                -- attempt to mark if current target matches name
                local n = UnitName("target")
                if n and n == popupFrame._name then MarkUnit("target", 8) end
            end
            popupFrame:Hide()
        end)
        local closeBtn = CreateFrame("Button", nil, popupFrame, "UIPanelButtonTemplate")
        closeBtn:SetSize(60, 20)
        closeBtn:SetPoint("BOTTOMRIGHT", -12, 12)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function() popupFrame:Hide() end)
        popupFrame:SetScript("OnUpdate", function(self, elapsed)
            if not self._expiry then return end
            if GetTime() > self._expiry then self:Hide(); self._expiry = nil end
        end)
    end
    popupFrame._name = name; popupFrame._class = class; popupFrame._unitGuid = guid
    popupFrame.title:SetText("Rare Found")
    popupFrame.info:SetText(name .. " ("..class..")")
    popupFrame._expiry = GetTime() + 12
    popupFrame:Show()
end

-- Sound handling
local SOUND_MAP = {
    RaidWarning = 8959, -- Raid Warning
    LevelUp = 888, -- Level Up
    TellMessage = 3081, -- Whisper message
    Alarm = 12889, -- UI_Garrison_Alert (may vary; fallback)
}

function RareTracker_PlaySound(choice)
    local id = SOUND_MAP[choice or 'RaidWarning'] or SOUND_MAP.RaidWarning
    if PlaySound then
        PlaySound(id, "Master")
    elseif PlaySoundKitID then
        PlaySoundKitID(id, "Master")
    end
end

-- Options panel additions
if addon.RegisterModuleOptions then
    addon:RegisterModuleOptions("RareTracker", function(panel)
        local section = addon:CreateSection(panel, "Rare Tracker", -8, 580)
        -- Headers for clearer grouping
        local headerActivation = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        headerActivation:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
        headerActivation:SetText("Activation")
        local monitorCB = CreateFrame("CheckButton", "HAK_RareTracker_MonitorCB", section, "InterfaceOptionsCheckButtonTemplate")
        monitorCB:SetPoint("TOPLEFT", headerActivation, "BOTTOMLEFT", 0, -4)
        _G[monitorCB:GetName().."Text"]:SetText("Monitoring enabled")
        monitorCB:SetChecked(GetSettings().monitoring)
        monitorCB:SetScript("OnClick", function(self) local s = GetSettings(); s.monitoring = self:GetChecked() and true or false end)
        local popupCB = CreateFrame("CheckButton", "HAK_RareTracker_PopupCB", section, "InterfaceOptionsCheckButtonTemplate")
        popupCB:SetPoint("TOPLEFT", monitorCB, "BOTTOMLEFT", 0, -4)
        _G[popupCB:GetName().."Text"]:SetText("Show popup window")
        popupCB:SetChecked(GetSettings().popup)
        popupCB:SetScript("OnClick", function(self) local s = GetSettings(); s.popup = self:GetChecked() and true or false end)
        local restedCB = CreateFrame("CheckButton", "HAK_RareTracker_RestedCB", section, "InterfaceOptionsCheckButtonTemplate")
        restedCB:SetPoint("TOPLEFT", popupCB, "BOTTOMLEFT", 0, -4)
        _G[restedCB:GetName().."Text"]:SetText("Suppress in rested zones")
        restedCB:SetChecked(GetSettings().disableInRested)
        restedCB:SetScript("OnClick", function(self) local s = GetSettings(); s.disableInRested = self:GetChecked() and true or false end)
        local ambientCB = CreateFrame("CheckButton", "HAK_RareTracker_AmbientCB", section, "InterfaceOptionsCheckButtonTemplate")
        ambientCB:SetPoint("TOPLEFT", restedCB, "BOTTOMLEFT", 0, -4)
        _G[ambientCB:GetName().."Text"]:SetText("Ambient proximity scan (experimental)")
        ambientCB:SetChecked(GetSettings().ambientScan)
        ambientCB:SetScript("OnClick", function(self) local s = GetSettings(); s.ambientScan = self:GetChecked() and true or false end)
        local headerBehavior = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        headerBehavior:SetPoint("TOPLEFT", ambientCB, "BOTTOMLEFT", 0, -12)
        headerBehavior:SetText("Behavior")
        local autoCB = CreateFrame("CheckButton", "HAK_RareTracker_AutoMarkCB", section, "InterfaceOptionsCheckButtonTemplate")
        autoCB:SetPoint("TOPLEFT", headerBehavior, "BOTTOMLEFT", 0, -4)
        _G[autoCB:GetName().."Text"]:SetText("Auto mark rares")
        autoCB:SetChecked(GetSettings().autoMark)
        autoCB:SetScript("OnClick", function(self)
            local s = GetSettings(); s.autoMark = self:GetChecked() and true or false
        end)
        local announceCB = CreateFrame("CheckButton", "HAK_RareTracker_AnnounceCB", section, "InterfaceOptionsCheckButtonTemplate")
        announceCB:SetPoint("TOPLEFT", autoCB, "BOTTOMLEFT", 0, -4)
        _G[announceCB:GetName().."Text"]:SetText("Announce (notifications)")
        announceCB:SetChecked(GetSettings().announce)
        announceCB:SetScript("OnClick", function(self)
            local s = GetSettings(); s.announce = self:GetChecked() and true or false
        end)
        local soundCB = CreateFrame("CheckButton", "HAK_RareTracker_SoundCB", section, "InterfaceOptionsCheckButtonTemplate")
        soundCB:SetPoint("TOPLEFT", announceCB, "BOTTOMLEFT", 0, -4)
        _G[soundCB:GetName().."Text"]:SetText("Play sound alert")
        soundCB:SetChecked(GetSettings().sound)
        soundCB:SetScript("OnClick", function(self) local s = GetSettings(); s.sound = self:GetChecked() and true or false end)
        local soundLabel = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        soundLabel:SetPoint("TOPLEFT", soundCB, "BOTTOMLEFT", 4, -8)
        soundLabel:SetText("Sound Choice")
        local soundDrop = CreateFrame("Frame", "HAK_RareTracker_SoundDrop", section, "UIDropDownMenuTemplate")
        soundDrop:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", -16, -4)
        local function Sound_OnClick(self)
            local s = GetSettings(); s.soundChoice = self.value
            UIDropDownMenu_SetText(soundDrop, self.value)
            CloseDropDownMenus()
            RareTracker_PlaySound(self.value) -- preview
        end
        local function InitSoundDropdown()
            local info = UIDropDownMenu_CreateInfo()
            for name,_ in pairs(SOUND_MAP) do
                info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.value = name
                info.func = Sound_OnClick
                info.checked = (GetSettings().soundChoice == name)
                UIDropDownMenu_AddButton(info)
            end
        end
        soundDrop:HookScript("OnShow", function() UIDropDownMenu_Initialize(soundDrop, InitSoundDropdown); UIDropDownMenu_SetText(soundDrop, GetSettings().soundChoice) end)

        local headerTiming = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        headerTiming:SetPoint("TOPLEFT", soundDrop, "BOTTOMLEFT", 16, -18)
        headerTiming:SetText("Timing & Marker")
        local delaySlider = CreateFrame("Slider", "HAK_RareTracker_DelaySlider", section, "OptionsSliderTemplate")
        delaySlider:SetPoint("TOPLEFT", headerTiming, "BOTTOMLEFT", -16, -6)
        delaySlider:SetMinMaxValues(30, 600)
        delaySlider:SetValueStep(10)
        if delaySlider.SetObeyStepOnDrag then delaySlider:SetObeyStepOnDrag(true) end
        _G[delaySlider:GetName().."Low"]:SetText("30")
        _G[delaySlider:GetName().."High"]:SetText("600")
        _G[delaySlider:GetName().."Text"]:SetText("Repeat Delay (s)")
        delaySlider:SetValue(GetSettings().repeatDelay or 300)
        delaySlider:SetScript("OnValueChanged", function(self, value)
            local s = GetSettings(); s.repeatDelay = math.floor(value + 0.5)
            if self.valueText then self.valueText:SetText(string.format("%d", s.repeatDelay)) end
        end)
        delaySlider.valueText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        delaySlider.valueText:SetPoint("LEFT", delaySlider, "RIGHT", 18, 0)
        delaySlider.valueText:SetText(string.format("%d", GetSettings().repeatDelay or 300))

        local iconSlider = CreateFrame("Slider", "HAK_RareTracker_IconSlider", section, "OptionsSliderTemplate")
        iconSlider:SetPoint("TOPLEFT", delaySlider, "BOTTOMLEFT", 0, -28)
        iconSlider:SetMinMaxValues(1, 8)
        iconSlider:SetValueStep(1)
        if iconSlider.SetObeyStepOnDrag then iconSlider:SetObeyStepOnDrag(true) end
        _G[iconSlider:GetName().."Low"]:SetText("1")
        _G[iconSlider:GetName().."High"]:SetText("8")
        _G[iconSlider:GetName().."Text"]:SetText("Raid Marker Icon")
        iconSlider:SetValue(GetSettings().markerIcon or 8)
        iconSlider:SetScript("OnValueChanged", function(self, value)
            local s = GetSettings(); s.markerIcon = math.floor(value + 0.5)
            if self.valueText then self.valueText:SetText(string.format("%d", s.markerIcon)) end
        end)
        iconSlider.valueText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        iconSlider.valueText:SetPoint("LEFT", iconSlider, "RIGHT", 18, 0)
        iconSlider.valueText:SetText(string.format("%d", GetSettings().markerIcon or 8))

        local headerDebug = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        headerDebug:SetPoint("TOPLEFT", iconSlider, "BOTTOMLEFT", 0, -20)
        headerDebug:SetText("Debug")
        local debugCB = CreateFrame("CheckButton", "HAK_RareTracker_DebugCB", section, "InterfaceOptionsCheckButtonTemplate")
        debugCB:SetPoint("TOPLEFT", headerDebug, "BOTTOMLEFT", 0, -4)
        _G[debugCB:GetName().."Text"]:SetText("Debug logging")
        debugCB:SetChecked(GetSettings().debug)
        debugCB:SetScript("OnClick", function(self)
            local s = GetSettings(); s.debug = self:GetChecked() and true or false
        end)

        panel.refresh = function()
            monitorCB:SetChecked(GetSettings().monitoring)
            popupCB:SetChecked(GetSettings().popup)
            restedCB:SetChecked(GetSettings().disableInRested)
            ambientCB:SetChecked(GetSettings().ambientScan)
            autoCB:SetChecked(GetSettings().autoMark)
            announceCB:SetChecked(GetSettings().announce)
            soundCB:SetChecked(GetSettings().sound)
            UIDropDownMenu_SetText(soundDrop, GetSettings().soundChoice)
            delaySlider:SetValue(GetSettings().repeatDelay or 300)
            delaySlider.valueText:SetText(string.format("%d", GetSettings().repeatDelay or 300))
            iconSlider:SetValue(GetSettings().markerIcon or 8)
            iconSlider.valueText:SetText(string.format("%d", GetSettings().markerIcon or 8))
            debugCB:SetChecked(GetSettings().debug)
        end
        panel:SetScript("OnShow", panel.refresh)
    end)
end

-- Ambient scan placeholder (limited by client API; rare proximity without target/mouseover not reliably detectable in 3.3.5)
local ambientFrame = CreateFrame("Frame")
ambientFrame.t = 0
ambientFrame:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    if self.t < 1.5 then return end
    self.t = 0
    local s = GetSettings()
    if not s.monitoring or not s.ambientScan then return end
    -- Placeholder: could implement nameplate enumeration, omitted for performance / reliability.
end)
