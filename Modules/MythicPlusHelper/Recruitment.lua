local addonName, addon = ...

-- Basic recruitment management stub
addon.MPlusRecruitment = addon.MPlusRecruitment or {}
local R = addon.MPlusRecruitment
R.active = R.active or false
R.lastMessageTime = 0
R.interval = 60 -- seconds between messages
R._pendingRefresh = false
R._refreshAccum = 0

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('MythicPlusHelper', { monitoring = false, recruitInterval = 60, recruitChannel = 1, recruitNeedTank = false, recruitNeedHealer = false, recruitNeedDPS = false }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings and HerosArmyKnifeDB.settings.moduleSettings.MythicPlusHelper or {}
end

local function BuildRecruitmentMessage(needs)
    local icon = addon.GetCurrentKeystoneIcon and addon:GetCurrentKeystoneIcon() or nil
    local keyLink = addon.GetCurrentKeystoneLink and addon:GetCurrentKeystoneLink() or "(no key)"
    local needTank = tonumber(needs.tank) or 0
    local needHealer = tonumber(needs.healer) or 0
    local needDPS = tonumber(needs.dps) or 0
    local roleParts = {}
    if needDPS > 0 then table.insert(roleParts, needDPS.." dps") end
    if needHealer > 0 then table.insert(roleParts, needHealer.." heal") end
    if needTank > 0 then table.insert(roleParts, needTank.." tank") end
    local needSegment = ""
    if #roleParts > 0 then
        needSegment = " need "..table.concat(roleParts, " ")
    end
    local base = "LFM "..keyLink..needSegment
    if icon then
        base = "|T"..icon..":16:16:0:0|t "..base
    end
    -- Allow whitespace-only custom messages (user may want spacing)
    local suffix = (R.customMessage and #R.customMessage > 0) and (" "..R.customMessage) or ""
    return base .. suffix
end

function R:Start()
    if R.active then return end
    R.active = true
    if addon.Notify then addon:Notify("Recruitment active", 'success') end
end

function R:Stop()
    if not R.active then return end
    R.active = false
    if addon.Notify then addon:Notify("Recruitment stopped", 'warn') end
end

function R:Toggle()
    if R.active then R:Stop() else R:Start() end
end

-- Attempt to send recruitment message (chat only placeholder)
function R:Pulse()
    if not R.active then return end
    local now = time()
    if now - R.lastMessageTime < R.interval then return end
    R.lastMessageTime = now
    local msg = BuildRecruitmentMessage(R.needs or {dps=0,healer=0,tank=0})
    if R.channel then
        SendChatMessage(msg, "CHANNEL", nil, R.channel)
    end
end

-- On update driver if we want periodic sends (optional enable later)
-- UI construction
function R:EnsureUI()
    if R.ui then return end
    local s = GetSettings()
    R.needs = R.needs or { dps=0, healer=0, tank=0 }
    R.channel = s.recruitChannel or R.channel or 1
    R.customMessage = s.recruitCustomMessage or R.customMessage
    local f = addon.CreateThemedFrame and addon:CreateThemedFrame(UIParent, "HAK_MPlusRecruitment", 340, 420, 'panel') or CreateFrame("Frame", "HAK_MPlusRecruitment", UIParent, "BackdropTemplate")
    f:SetPoint("CENTER")
    f:EnableMouse(true)
    f:SetMovable(true)
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, 0)
    title:SetText("Recruitment")
    -- Title-only drag region
    local titleDrag = CreateFrame("Frame", nil, f)
    titleDrag:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    -- Leave space for close button (approx 34px)
    titleDrag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -34, 0)
    titleDrag:SetHeight(34)
    titleDrag:EnableMouse(true)
    titleDrag:RegisterForDrag("LeftButton")
    titleDrag:SetScript("OnDragStart", function() f:StartMoving() end)
    titleDrag:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    close:SetFrameLevel(f:GetFrameLevel()+10)
    close:SetScript("OnClick", function() f:Hide() end)
    -- Keystone display
    local keyLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    -- Anchor body to frame left so only title is centered
    keyLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
    keyLabel:SetText("Keystone:")
    local keyText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    keyText:SetPoint("LEFT", keyLabel, "RIGHT", 8, 0)
    -- Spec selection (radio buttons)
    local specLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    specLabel:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", 0, -16)
    specLabel:SetText("Your Spec:")
    local specs = { "TANK", "HEALER", "DPS" }
    local lastBtn
    local function MakeSpecButton(idx, text)
        local b = CreateFrame("CheckButton", "HAK_RecruitSpecBtn"..text, f, "UIRadioButtonTemplate")
        if not lastBtn then b:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -6) else b:SetPoint("LEFT", lastBtn, "RIGHT", 40, 0) end
        _G[b:GetName().."Text"]:SetText(text)
        -- Restrict hit rect to near the checkbox (avoid huge clickable area)
        b:SetHitRectInsets(2, 2, 2, 2)
        b:SetScript("OnClick", function(self)
            for _, s in ipairs(specs) do
                local other = _G["HAK_RecruitSpecBtn"..s]
                if other and other ~= self then other:SetChecked(false) end
            end
            addon:MPlus_SetSpec(text)
            R:RefreshUI()
        end)
        lastBtn = b
        return b
    end
    for _, s in ipairs(specs) do MakeSpecButton(nil, s) end
    -- Needed roles
    local needLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    needLabel:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -38)
    needLabel:SetText("Needed Roles:")
    local needTank = CreateFrame("CheckButton", "HAK_RecruitNeedTank", f, "InterfaceOptionsCheckButtonTemplate")
    needTank:SetPoint("TOPLEFT", needLabel, "BOTTOMLEFT", 0, -6)
    _G[needTank:GetName().."Text"]:SetText("Tank")
    needTank:SetHitRectInsets(2,2,2,2)
    local needHealer = CreateFrame("CheckButton", "HAK_RecruitNeedHealer", f, "InterfaceOptionsCheckButtonTemplate")
    needHealer:SetPoint("LEFT", needTank, "RIGHT", 80, 0)
    _G[needHealer:GetName().."Text"]:SetText("Healer")
    needHealer:SetHitRectInsets(2,2,2,2)
    local needDPS = CreateFrame("CheckButton", "HAK_RecruitNeedDPS", f, "InterfaceOptionsCheckButtonTemplate")
    needDPS:SetPoint("LEFT", needHealer, "RIGHT", 80, 0)
    _G[needDPS:GetName().."Text"]:SetText("DPS")
    needDPS:SetHitRectInsets(2,2,2,2)
    -- Channel label below role row with consistent spacing
    local channelLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelLabel:SetPoint("TOPLEFT", needTank, "BOTTOMLEFT", 0, -20)
    channelLabel:SetText("Channel:")
    local channelDrop = CreateFrame("Frame", "HAK_RecruitChannelDropdown", f, "UIDropDownMenuTemplate")
    channelDrop:SetPoint("LEFT", channelLabel, "RIGHT", -10, -4)
    local previewLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", channelLabel, "BOTTOMLEFT", 0, -22)
    previewLabel:SetText("Message Preview:")
    -- Create backdrop first to avoid circular SetPoint dependency
    local previewBG = CreateFrame("Frame", nil, f, "BackdropTemplate")
    previewBG:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", -6, -2)
    previewBG:SetSize(312, 68) -- width accommodates text + padding
    previewBG:SetBackdrop({ bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=14, insets={left=4,right=4,top=4,bottom=4} })
    previewBG:SetBackdropColor(0,0,0,0.65)
    previewBG:SetBackdropBorderColor(0.85,0.65,0.15,1)
    local previewText = previewBG:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    previewText:SetPoint("TOPLEFT", previewBG, "TOPLEFT", 6, -6)
    previewText:SetWidth(300)
    previewText:SetJustifyH("LEFT")
    -- Optional custom message suffix
    local customLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    customLabel:SetPoint("TOPLEFT", previewBG, "BOTTOMLEFT", 0, -8)
    customLabel:SetText("Custom Message:")
    local customBox = CreateFrame("EditBox", "HAK_RecruitCustomMsg", f, "InputBoxTemplate")
    customBox:SetAutoFocus(false)
    customBox:SetSize(300, 20)
    customBox:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 4, -4)
    customBox:SetScript("OnTextChanged", function(self, user)
        if not user then return end
        R.customMessage = self:GetText()
        local s = GetSettings(); s.recruitCustomMessage = R.customMessage
        R:RequestRefresh()
    end)
    local sendBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    sendBtn:SetSize(100,24)
    sendBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    sendBtn:SetText("Send")
    -- Full party timer display
    local fullTimerText = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fullTimerText:SetPoint("LEFT", sendBtn, "LEFT", -180, 0)
    fullTimerText:SetText("")
    -- Channel dropdown init
    local function Channel_OnClick(self)
        R.channel = self.value
        local s = GetSettings(); s.recruitChannel = R.channel
        UIDropDownMenu_SetSelectedValue(channelDrop, self.value)
        R:RequestRefresh()
    end
    local channelOptions = { {value=1,text="1 Ascension"}, {value=2,text="2 Newcomers"} }
    local function Channel_Init()
        UIDropDownMenu_Initialize(channelDrop, function(self, level)
            for _, info in ipairs(channelOptions) do
                local item = UIDropDownMenu_CreateInfo()
                item.text = info.text
                item.value = info.value
                item.func = Channel_OnClick
                item.checked = (R.channel == info.value)
                UIDropDownMenu_AddButton(item)
            end
        end)
        UIDropDownMenu_SetSelectedValue(channelDrop, R.channel)
        UIDropDownMenu_SetWidth(channelDrop, 140)
        for _, opt in ipairs(channelOptions) do
            if opt.value == R.channel then
                UIDropDownMenu_SetText(channelDrop, opt.text)
                break
            end
        end
    end
    -- Initialize channel list immediately so it isn't empty
    Channel_Init(); channelDrop._init = true
    -- Send button logic
    sendBtn:SetScript("OnClick", function()
        local msg = BuildRecruitmentMessage(R.needs)
        if R.channel then SendChatMessage(msg, "CHANNEL", nil, R.channel) end
        if addon.Notify then addon:Notify("Sent recruitment message", 'success', addon:GetCurrentKeystoneIcon()) end
    end)
    -- Refresh function
    function R:RefreshUI()
        local spec = addon.MPlusSpec or "DPS"
        local keyLink = addon:GetCurrentKeystoneLink() or "(no key)"
        keyText:SetText(keyLink)
        -- Spec radios
        for _, s in ipairs(specs) do
            local btn = _G["HAK_RecruitSpecBtn"..s]
            if btn then btn:SetChecked(s == spec) end
        end
        -- Lock logic
        needTank:Enable(); needHealer:Enable()
        if spec == "TANK" then needTank:SetChecked(false); needTank:Disable() end
        if spec == "HEALER" then needHealer:SetChecked(false); needHealer:Disable() end
        -- Determine composition slots
        local playerIsTank = (spec == "TANK")
        local playerIsHealer = (spec == "HEALER")
        -- Desired presence of tank/healer slots in final group (player counts automatically)
        local wantTankSlot = playerIsTank or needTank:GetChecked()
        local wantHealerSlot = playerIsHealer or needHealer:GetChecked()
        local dpsTotal = 5 - (wantTankSlot and 1 or 0) - (wantHealerSlot and 1 or 0)
        if dpsTotal < 0 then dpsTotal = 0 end
        -- Party size including player
        local partyCount = 1
        if GetNumRaidMembers and GetNumRaidMembers() > 0 then
            partyCount = GetNumRaidMembers()
        else
            partyCount = GetNumPartyMembers() + 1
        end
        -- Approximate current DPS members: assume all non-player party members are DPS (no role data available)
        local otherMembers = partyCount - 1
        local currentDPSCount = otherMembers + (spec == "DPS" and 1 or 0)
        R.needs.tank = playerIsTank and 0 or (needTank:GetChecked() and 1 or 0)
        R.needs.healer = playerIsHealer and 0 or (needHealer:GetChecked() and 1 or 0)
        local missingDPS = 0
        if needDPS:GetChecked() then
            missingDPS = dpsTotal - currentDPSCount
            if missingDPS < 0 then missingDPS = 0 end
        end
        R.needs.dps = missingDPS
        -- Removed dpsLabel row (no longer displayed) so skip its update
        local msgColor = "|cffFFD200" -- golden accent
        previewText:SetText(msgColor..BuildRecruitmentMessage(R.needs).."|r")
        if customBox and customBox:GetText() ~= (R.customMessage or "") then
            customBox:SetText(R.customMessage or "")
        end
        -- Full party timer display
        if R.fullPartyExpire and time() < R.fullPartyExpire then
            local left = R.fullPartyExpire - time()
            fullTimerText:SetText(string.format("Party Full: %ds", left))
        else
            fullTimerText:SetText("")
        end
    end
    needTank:SetScript("OnClick", function()
        local s = GetSettings(); s.recruitNeedTank = needTank:GetChecked() and true or false
        R:RequestRefresh()
    end)
    needHealer:SetScript("OnClick", function()
        local s = GetSettings(); s.recruitNeedHealer = needHealer:GetChecked() and true or false
        R:RequestRefresh()
    end)
    needDPS:SetScript("OnClick", function()
        local s = GetSettings(); s.recruitNeedDPS = needDPS:GetChecked() and true or false
        R:RequestRefresh()
    end)
    needTank:SetChecked(GetSettings().recruitNeedTank or false)
    needHealer:SetChecked(GetSettings().recruitNeedHealer or false)
    needDPS:SetChecked(GetSettings().recruitNeedDPS or false)
    R.ui = f
    R:RefreshUI()
end

function R:ShowUI()
    R:EnsureUI(); R.ui:Show(); R:RequestRefresh(); R:RefreshUI()
end

function R:RequestRefresh()
    R._pendingRefresh = true
end

-- Full party monitoring and whisper autorespond
local function CheckFullParty()
    local count
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        count = GetNumRaidMembers()
    else
        count = GetNumPartyMembers() + 1
    end
    if count >= 5 and not R.fullPartyExpire then
        R.fullPartyExpire = time() + 60
        if addon.Notify then addon:Notify("Party full - 60s lock", 'warn') end
    elseif count < 5 and R.fullPartyExpire then
        R.fullPartyExpire = nil
        if addon.Notify then addon:Notify("Party slot opened", 'info') end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        if R.fullPartyExpire and time() < R.fullPartyExpire then
            SendChatMessage("Party currently full, please wait.", "WHISPER", nil, sender)
        end
    else
        CheckFullParty()
    end
    if R.ui and R.ui:IsShown() then R:RequestRefresh() end
end)

-- Countdown notifications (every 10s last minute)
local countdownFrame = CreateFrame("Frame")
countdownFrame.t = 0
countdownFrame:SetScript("OnUpdate", function(self, elapsed)
    if not R.fullPartyExpire then return end
    self.t = self.t + elapsed
    if self.t < 1 then return end
    self.t = 0
    local left = R.fullPartyExpire - time()
    if left <= 0 then R.fullPartyExpire = nil; if addon.Notify then addon:Notify("Lock ended", 'success') end return end
    if left % 10 == 0 or left <= 5 then
        if addon.Notify then addon:Notify("Party lock: "..left.."s", 'info') end
    end
    if R.ui and R.ui:IsShown() then R:RequestRefresh() end
end)

-- Expose open function through addon for menu hook
function addon:MPlus_OpenRecruitment()
    R:ShowUI()
end

-- Lightweight OnUpdate for periodic Pulse
if not R.frame then
    R.frame = CreateFrame("Frame")
    R.frame:SetScript("OnUpdate", function(_, elapsed)
        R:Pulse()
        if R._pendingRefresh then
            R._refreshAccum = R._refreshAccum + elapsed
            if R._refreshAccum >= 0.25 then
                R._refreshAccum = 0
                R._pendingRefresh = false
                if R.ui and R.ui:IsShown() then R:RefreshUI() end
            end
        end
    end)
end
