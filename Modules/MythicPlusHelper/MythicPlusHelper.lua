local addonName, addon = ...

-- Keystone detection cache
local keystoneInfo = { id = nil, name = nil, link = nil, texture = nil }
local KEY_FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Key_03"

addon:RegisterInit(function()
    local s = addon.GetModuleSettings and addon:GetModuleSettings('MythicPlusHelper', { monitoring = false, debug = false, glow = { r=1, g=0.85, b=0, a=0.9, pulse=false }, spec = "DPS", recruitInterval = 60, recruitChannel = 1, recruitNeedTank = false, recruitNeedHealer = false, recruitNeedDPS = false, shareEnabled = true, shareNotify = false }) or (HerosArmyKnifeDB.settings.moduleSettings.MythicPlusHelper or {})
    if s.monitoring == nil then s.monitoring = false end
    if s.debug == nil then s.debug = false end
    if not s.glow then s.glow = { r=1, g=0.85, b=0, a=0.9, pulse=false } end
    if not s.spec then s.spec = "DPS" end
    if s.recruitInterval == nil then s.recruitInterval = 60 end
    if s.recruitChannel == nil then s.recruitChannel = 1 end
    if s.recruitNeedTank == nil then s.recruitNeedTank = false end
    if s.recruitNeedHealer == nil then s.recruitNeedHealer = false end
    if s.recruitNeedDPS == nil then s.recruitNeedDPS = false end
    if s.shareEnabled == nil then s.shareEnabled = true end
    if s.shareNotify == nil then s.shareNotify = false end
    addon.MPlusSpec = s.spec
    -- Auto-apply saved monitoring state silently on init
    if s.monitoring then
        addon:MPlus_SetMonitoring(true, true) -- silent
    end
end)

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('MythicPlusHelper', { monitoring = false, debug = false, glow = { r=1, g=0.85, b=0, a=0.9, pulse=false }, spec = "DPS", recruitInterval = 60, recruitChannel = 1, recruitNeedTank = false, recruitNeedHealer = false, recruitNeedDPS = false, shareEnabled = true, shareNotify = false }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.MythicPlusHelper or { monitoring = false, shareEnabled = true, shareNotify = false }
end

function addon:MPlus_GetSettings()
    return GetSettings()
end

function addon:MPlus_IsShareEnabled()
    local s = GetSettings()
    return s.shareEnabled ~= false
end

function addon:MPlus_SetShareEnabled(state, silent)
    local s = GetSettings()
    local newVal = state and true or false
    if s.shareEnabled == newVal then return end
    s.shareEnabled = newVal
    if addon.Notify and not silent then
        addon:Notify("Party info sharing "..(newVal and "ON" or "OFF"), newVal and 'success' or 'info', addon:GetCurrentKeystoneIcon())
    end
    if newVal then
        addon:MPlus_BroadcastFull()
    end
    if addon._MPlusPartyWindow and addon._MPlusPartyWindow.Refresh then
        addon._MPlusPartyWindow:Refresh()
    end
end

function addon:MPlus_ShouldNotifySharing()
    local s = GetSettings()
    return s.shareNotify and true or false
end

function addon:MPlus_SetShareNotify(state)
    local s = GetSettings()
    s.shareNotify = state and true or false
end

-- Scan bags for an item whose name contains "Keystone"
local function ScanForKeystone()
    keystoneInfo.id, keystoneInfo.name, keystoneInfo.link, keystoneInfo.texture = nil,nil,nil,nil
    for bag=0,4 do
        local slots = GetContainerNumSlots(bag)
        for slot=1,slots do
            local itemID = GetContainerItemID(bag, slot)
            if itemID then
                local name, link, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
                if name and name:lower():find("keystone") then
                    keystoneInfo.id = itemID
                    keystoneInfo.name = name
                    keystoneInfo.link = link
                    keystoneInfo.texture = texture
                    return
                end
            end
        end
    end
end

local function UpdateIconAppearance()
    local btn = _G["HAKToolbarBtn_MythicPlusHelper"]
    if not btn then return end
    if not keystoneInfo.texture then
        btn.texture:SetTexture(KEY_FALLBACK_ICON)
    else
        btn.texture:SetTexture(keystoneInfo.texture)
    end
    local s = GetSettings()
    if s.monitoring then
        if not btn._hakGlow then
            local glow = btn:CreateTexture(nil, "OVERLAY")
            glow:SetTexture("Interface/Buttons/UI-Quickslot2")
            glow:SetBlendMode("ADD")
            glow:ClearAllPoints()
            glow:SetPoint("CENTER", btn, "CENTER")
            glow:SetWidth(btn:GetWidth()+8)
            glow:SetHeight(btn:GetHeight()+8)
            btn._hakGlow = glow
        end
        btn._hakGlow:SetVertexColor(s.glow.r, s.glow.g, s.glow.b, 1) -- force full alpha for visibility
        btn._hakGlow:Show()
        -- Optional shine overlay
        if not btn._hakGlowShine then
            local shine = btn:CreateTexture(nil, "OVERLAY")
            shine:SetTexture("Interface/Buttons/UI-ActionButton-Border")
            shine:SetBlendMode("ADD")
            shine:SetPoint("CENTER")
            shine:SetWidth(btn:GetWidth()+4)
            shine:SetHeight(btn:GetHeight()+4)
            shine:SetVertexColor(s.glow.r, s.glow.g, s.glow.b, 0.6)
            btn._hakGlowShine = shine
        end
        btn._hakGlowShine:Show()
        -- Add an inner highlight for strong indication
        if not btn._hakInnerHighlight then
            local inner = btn:CreateTexture(nil, "ARTWORK")
            inner:SetTexture("Interface/Buttons/UI-ActionButton-Highlight")
            inner:SetBlendMode("ADD")
            inner:SetAllPoints(btn.texture)
            inner:SetVertexColor(s.glow.r, s.glow.g, s.glow.b, 0.35)
            btn._hakInnerHighlight = inner
        end
        btn._hakInnerHighlight:Show()
        -- Status badge (monitoring active or suspended)
        local suspended = addon.MPlusMonitoringSuspended
        if not btn._hakStatusBadge then
            local badge = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            badge:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 4, 4)
            badge:SetText("ON")
            badge:SetAlpha(0.95)
            btn._hakStatusBadge = badge
        end
        -- Create distinct ring indicator (always visible when monitoring)
        if not btn._hakMonitorRing then
            local ring = btn:CreateTexture(nil, "ARTWORK")
            ring:SetTexture("Interface/Artifacts/Artifacts-PointsRing")
            ring:SetPoint("CENTER", btn, "CENTER")
            ring:SetSize(btn:GetWidth()+12, btn:GetHeight()+12)
            ring:SetAlpha(0.9)
            btn._hakMonitorRing = ring
        end
        -- Hard border ring for clear visibility
        if not btn._hakHardBorder then
            local hb = btn:CreateTexture(nil, "OVERLAY")
            hb:SetTexture("Interface/Buttons/UI-ActionButton-Border")
            hb:SetBlendMode("ADD")
            hb:SetPoint("CENTER", btn, "CENTER")
            hb:SetSize(btn:GetWidth()+14, btn:GetHeight()+14)
            btn._hakHardBorder = hb
        end
        btn._hakHardBorder:Show()
        if not suspended then
            -- Strong active monitoring aura with animation
            if not btn._hakActiveAura then
                local aura = btn:CreateTexture(nil, "OVERLAY")
                aura:SetTexture("Interface/SpellActivationOverlay/GenericArc_01")
                aura:SetPoint("CENTER", btn, "CENTER")
                aura:SetSize(btn:GetWidth()+26, btn:GetHeight()+26)
                aura:SetBlendMode("ADD")
                aura:SetAlpha(0.85)
                btn._hakActiveAura = aura
            end
            btn._hakActiveAura:Show()
            btn._hakActiveAura:SetVertexColor(0.2, 1, 0.2, 0.85)
            if not btn._hakAuraAnim then
                local animFrame = CreateFrame("Frame", nil, btn)
                animFrame.t = 0
                animFrame:SetScript("OnUpdate", function(self, elapsed)
                    self.t = self.t + elapsed
                    local angle = self.t * 1.2 -- slow rotation
                    if btn._hakActiveAura and btn._hakActiveAura.SetRotation then
                        btn._hakActiveAura:SetRotation(angle)
                    end
                    local pulse = (math.sin(self.t*3) + 1)/2 -- 0..1
                    local alpha = 0.70 + 0.25 * pulse
                    if btn._hakActiveAura then btn._hakActiveAura:SetAlpha(alpha) end
                end)
                btn._hakAuraAnim = animFrame
            end
        else
            if btn._hakActiveAura then btn._hakActiveAura:Hide() end
            if btn._hakAuraAnim then btn._hakAuraAnim:SetScript("OnUpdate", nil); btn._hakAuraAnim = nil end
        end
        if suspended then
            btn._hakStatusBadge:SetText("S") -- suspended indicator
            btn._hakStatusBadge:SetTextColor(1, 0.2, 0.2, 1) -- red
            if btn._hakGlow then btn._hakGlow:SetVertexColor(0.6,0.15,0.15,1) end
            if btn._hakGlowShine then btn._hakGlowShine:SetVertexColor(0.8,0.2,0.2,0.5) end
            if btn._hakInnerHighlight then btn._hakInnerHighlight:SetVertexColor(0.8,0.2,0.2,0.25) end
            if btn._hakMonitorRing then btn._hakMonitorRing:SetVertexColor(1,0.25,0.25,0.85) end
            if btn._hakHardBorder then btn._hakHardBorder:SetVertexColor(1,0.2,0.2,0.9) end
            if btn._hakActiveAura then btn._hakActiveAura:Hide() end
            if btn._hakAuraAnim then btn._hakAuraAnim:SetScript("OnUpdate", nil); btn._hakAuraAnim = nil end
        else
            btn._hakStatusBadge:SetText("ON")
            btn._hakStatusBadge:SetTextColor(0.2, 1, 0.2, 1) -- green
            if btn._hakMonitorRing then btn._hakMonitorRing:SetVertexColor(0.2,1,0.2,0.85) end
            if btn._hakHardBorder then btn._hakHardBorder:SetVertexColor(0.2,1,0.2,0.9) end
        end
        btn._hakStatusBadge:Show()
        if s.glow.pulse then
            if not btn._hakPulseFrame then
                local pf = CreateFrame("Frame", nil, btn)
                pf.t = 0
                pf:SetScript("OnUpdate", function(self, elapsed)
                    self.t = self.t + elapsed
                    local phase = (math.sin(self.t*3) + 1)/2 -- 0..1
                    local a = 0.6 + 0.4*phase
                    if btn._hakGlow then btn._hakGlow:SetVertexColor(s.glow.r, s.glow.g, s.glow.b, 1) end -- keep outer border solid
                    if btn._hakGlowShine then btn._hakGlowShine:SetVertexColor(s.glow.r, s.glow.g, s.glow.b, a) end
                    if btn._hakInnerHighlight then btn._hakInnerHighlight:SetVertexColor(s.glow.r, s.glow.g, s.glow.b, 0.25 + 0.2*phase) end
                end)
                btn._hakPulseFrame = pf
            end
        elseif btn._hakPulseFrame then
            btn._hakPulseFrame:SetScript("OnUpdate", nil)
            btn._hakPulseFrame = nil
            btn._hakGlow:SetVertexColor(s.glow.r, s.glow.g, s.glow.b, 1)
            if btn._hakGlowShine then btn._hakGlowShine:SetVertexColor(s.glow.r, s.glow.g, s.glow.b, 0.6) end
            if btn._hakInnerHighlight then btn._hakInnerHighlight:SetVertexColor(s.glow.r, s.glow.g, s.glow.b, 0.35) end
        end
    else
        if btn._hakGlow then btn._hakGlow:Hide() end
        if btn._hakGlowShine then btn._hakGlowShine:Hide() end
        if btn._hakInnerHighlight then btn._hakInnerHighlight:Hide() end
        if btn._hakPulseFrame then btn._hakPulseFrame:SetScript("OnUpdate", nil); btn._hakPulseFrame = nil end
        if btn._hakStatusBadge then btn._hakStatusBadge:Hide() end
        if btn._hakMonitorRing then btn._hakMonitorRing:Hide() end
        -- Show a subtle neutral border even when monitoring is off for consistency
        if not btn._hakHardBorder then
            local hb = btn:CreateTexture(nil, "OVERLAY")
            hb:SetTexture("Interface/Buttons/UI-ActionButton-Border")
            hb:SetBlendMode("ADD")
            hb:SetPoint("CENTER", btn, "CENTER")
            hb:SetSize(btn:GetWidth()+14, btn:GetHeight()+14)
            btn._hakHardBorder = hb
        end
        btn._hakHardBorder:Show()
        btn._hakHardBorder:SetVertexColor(0.6,0.6,0.6,0.5)
        if btn._hakActiveAura then btn._hakActiveAura:Hide() end
        if btn._hakAuraAnim then btn._hakAuraAnim:SetScript("OnUpdate", nil); btn._hakAuraAnim = nil end
    end
end

-- Player item level helper
local function GetPlayerItemLevel()
    -- Prefer built-in API if present (some 3.3.5 cores backport this)
    if GetAverageItemLevel then
        local overall, equipped = GetAverageItemLevel()
        local val = equipped or overall
        if val and val > 0 then return math.floor(val + 0.5) end
    end
    -- Fallback manual scan of equipped inventory slots (ignore shirt/tabard)
    local slots = {
        1, -- Head
        2, -- Neck
        3, -- Shoulder
        5, -- Chest (skip 4 shirt)
        6, -- Waist
        7, -- Legs
        8, -- Feet
        9, -- Wrist
        10, -- Hands
        11, -- Finger 1
        12, -- Finger 2
        13, -- Trinket 1
        14, -- Trinket 2
        15, -- Back
        16, -- Main hand
        17, -- Off hand
        18, -- Ranged / Relic
    }
    local total, count = 0, 0
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local name, itemLink, quality, itemLevel = GetItemInfo(link)
            if itemLevel and itemLevel > 0 then
                total = total + itemLevel
                count = count + 1
            end
        end
    end
    if count > 0 then
        return math.floor((total / count) + 0.5)
    end
    return nil
end
function addon:GetPlayerItemLevel()
    return GetPlayerItemLevel()
end
-- Public keystone icon accessor for notifications
function addon:GetCurrentKeystoneIcon()
    return keystoneInfo.texture or KEY_FALLBACK_ICON
end

function addon:GetCurrentKeystoneLink()
    return keystoneInfo.link
end

-- Unified monitoring state management
function addon:MPlus_SetMonitoring(state, silent)
    local s = GetSettings()
    local newVal = state and true or false
    if s.monitoring ~= newVal then
        s.monitoring = newVal
    end
    addon.MPlusMonitoringActive = s.monitoring
    UpdateIconAppearance()
    if addon.Notify and not silent then
        addon:Notify("Mythic+ monitoring "..(s.monitoring and "ON" or "OFF"), s.monitoring and 'success' or 'info', keystoneInfo.texture or KEY_FALLBACK_ICON)
    end
    -- sync options checkbox if it exists
    if _G.HAK_MPlus_MonitorCB then _G.HAK_MPlus_MonitorCB:SetChecked(s.monitoring) end
    if addon.MPlusLFMQueue and addon.MPlusLFMQueue.OnMonitoringChanged then
        addon.MPlusLFMQueue:OnMonitoringChanged(s.monitoring)
    end
end

function addon:MPlus_ToggleMonitoring()
    local s = GetSettings()
    addon:MPlus_SetMonitoring(not s.monitoring)
end

-- Role/spec management
function addon:MPlus_SetSpec(role)
    local valid = { HEALER=true, TANK=true, DPS=true }
    if not role then return end
    local up = role:upper()
    if not valid[up] then return end
    local s = GetSettings()
    if s.spec ~= up then
        s.spec = up
        addon.MPlusSpec = up
        if addon.Notify then addon:Notify("Role set to "..up, 'info', addon:GetCurrentKeystoneIcon()) end
        if addon:MPlus_IsShareEnabled() and addon.MPlus_BroadcastFull then
            addon:MPlus_BroadcastFull()
        end
    end
end

local function BuildContextMenu(btn)
    local s = GetSettings()
    local specSub = {
        { text="Healer", func=function() addon:MPlus_SetSpec("HEALER") end, notCheckable=true },
        { text="Tank", func=function() addon:MPlus_SetSpec("TANK") end, notCheckable=true },
        { text="DPS", func=function() addon:MPlus_SetSpec("DPS") end, notCheckable=true },
    }
    local function IsInGroup()
        if GetNumGroupMembers then
            return GetNumGroupMembers() > 0
        end
        local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
        local party = GetNumPartyMembers and GetNumPartyMembers() or 0
        return raid > 0 or party > 0
    end
    local function FindUnitByName(name)
        if not name then return nil end
        name = name:lower()
        -- Raid first
        if GetNumRaidMembers and GetNumRaidMembers() > 0 then
            for i=1, GetNumRaidMembers() do
                local unit = "raid"..i
                local uname = UnitName(unit)
                if uname and uname:lower() == name then return unit end
            end
        else
            -- Party (excluding player handled separately)
            if UnitName("player") and UnitName("player"):lower() == name then return "player" end
            if GetNumPartyMembers then
                for i=1, GetNumPartyMembers() do
                    local unit = "party"..i
                    local uname = UnitName(unit)
                    if uname and uname:lower() == name then return unit end
                end
            end
        end
        return nil
    end
    local function MarkTarget()
        local info = addon.MPlusPartyInfo
        if not info or not next(info) then
            if addon.Notify then addon:Notify("No party role info to mark", 'warn') end
            return
        end
        local tankName, healerName
        for name,data in pairs(info) do
            if data and data.spec == "TANK" and not tankName then tankName = name end
            if data and data.spec == "HEALER" and not healerName then healerName = name end
            if tankName and healerName then break end
        end
        local markedAny
        if tankName then
            local unit = FindUnitByName(tankName)
            if unit and UnitExists(unit) then
                SetRaidTarget(unit, 2) -- Circle
                markedAny = true
            end
        end
        if healerName then
            local unit = FindUnitByName(healerName)
            if unit and UnitExists(unit) then
                SetRaidTarget(unit, 5) -- Moon
                markedAny = true
            end
        end
        if markedAny then
            if addon.Notify then addon:Notify("Marked roles (Circle=Tank, Moon=Healer)", 'success') end
        else
            if addon.Notify then addon:Notify("Could not mark (roles or units missing)", 'error') end
        end
    end
    local inGroup = IsInGroup()
    local menu = {
        { text="Mythic+ Helper", isTitle=true, notCheckable=true },
        { text = s.monitoring and "Disable LFM Monitoring" or "Enable LFM Monitoring", func = function() addon:MPlus_ToggleMonitoring() end, notCheckable=true },
        { text = "Open LFM Monitor", func = function() if addon.MPlus_OpenLFMMonitor then addon:MPlus_OpenLFMMonitor() end end, notCheckable=true },
        { text = "Recruitment", func = function() if addon.MPlus_OpenRecruitment then addon:MPlus_OpenRecruitment() end end, notCheckable=true },
        { text = "Mark Targets", func = MarkTarget, notCheckable=true },
        { text = "Spec ("..(s.spec or "DPS")..")", hasArrow=true, menuList = specSub, notCheckable=true },
        { text = "Party Info", func = function() if addon.MPlus_OpenPartyInfoWindow then addon:MPlus_OpenPartyInfoWindow() end end, notCheckable=true },
        { text = "Link Current Key", func = function()
            if not IsInGroup() then
                if addon.Notify then addon:Notify("Must be in a party to link key", 'warn') end
                return
            end
            if keystoneInfo.link then
                SendChatMessage("My key: "..keystoneInfo.link, "PARTY")
                if addon.Notify then addon:Notify("Key linked to party", 'success', keystoneInfo.texture or KEY_FALLBACK_ICON) end
            else
                if addon.Print then addon.Print("No keystone found to link.") end
                if addon.Notify then addon:Notify("No keystone found", 'error') end
            end
        end, notCheckable=true, disabled = not inGroup },
        { text = "Close", notCheckable=true },
    }
    addon:ShowAnchoredMenu(btn, menu, "HAK_MPlus_Context")
end

-- Small party info window listing all current members; shows spec & ilvl if shared via addon
function addon:MPlus_OpenPartyInfoWindow()
    if not addon._MPlusPartyWindow then
        local w = addon.CreateThemedFrame and addon:CreateThemedFrame(UIParent, "HAK_MPlusPartyInfo", 420, 260, 'panel') or CreateFrame("Frame", "HAK_MPlusPartyInfo", UIParent, "BackdropTemplate")
        w:SetPoint("CENTER", UIParent, "CENTER", 60, 40)
        if not w:GetWidth() or w:GetWidth() <= 0 then w:SetSize(420, 260) end
        local container
        if addon.ApplyStandardPanelChrome then
            container = addon:ApplyStandardPanelChrome(w, "Party Info", { bodyPadding = { left = 18, right = 20, top = 74, bottom = 22 }, dragBody = true })
        end
        if not container then
            w:EnableMouse(true)
            w:SetMovable(true)
            w:SetClampedToScreen(true)
            w:RegisterForDrag("LeftButton")
            w:SetScript("OnDragStart", function(self) self:StartMoving() end)
            w:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
            w:SetSize(420, 260)
            local title = w:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            title:SetPoint("TOP", w, "TOP", 0, -6)
            title:SetText("Party Info")
            local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
            close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -6, -6)
            close:SetScript("OnClick", function() w:Hide() end)
            container = CreateFrame("Frame", nil, w)
            container:SetPoint("TOPLEFT", w, "TOPLEFT", 18, -74)
            container:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -20, 22)
        end
        container = container or w
        local rightInset = 16

        w.header = CreateFrame("Frame", nil, container)
        w.header:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        w.header:SetPoint("TOPRIGHT", container, "TOPRIGHT", -rightInset, 0)
        w.header:SetHeight(18)
        local headerName = w.header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        headerName:SetPoint("LEFT", w.header, "LEFT", 6, 0)
        headerName:SetText("Name")
        local headerSpec = w.header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        headerSpec:SetPoint("LEFT", w.header, "LEFT", 172, 0)
        headerSpec:SetText("Spec")
        local headerIlvl = w.header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        headerIlvl:SetPoint("LEFT", headerSpec, "RIGHT", 20, 0)
        headerIlvl:SetText("ilvl")
        local headerUpdated = w.header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        headerUpdated:SetPoint("RIGHT", w.header, "RIGHT", -6, 0)
        headerUpdated:SetText("Updated")
        local headerLine = container:CreateTexture(nil, "ARTWORK")
        headerLine:SetColorTexture(1, 1, 1, 0.08)
        headerLine:SetPoint("TOPLEFT", w.header, "BOTTOMLEFT", 0, -4)
        headerLine:SetPoint("TOPRIGHT", w.header, "BOTTOMRIGHT", 0, -4)
        headerLine:SetHeight(1)

        local footer = CreateFrame("Frame", nil, container)
        footer:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        footer:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -rightInset, 0)
        footer:SetHeight(64)

        w.missingHint = footer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        w.missingHint:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, -6)
        w.missingHint:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, -6)
        w.missingHint:SetJustifyH("LEFT")
        w.missingHint:SetText("|cffB5B5B5Party members without the addon appear as \"No data\".|r")
        w.missingHint:Hide()

        w.refreshBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
        w.refreshBtn:SetSize(120, 22)
        w.refreshBtn:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", 0, 0)
        w.refreshBtn:SetText("Request Update")
        w.refreshBtn:SetScript("OnClick", function()
            if addon:MPlus_IsShareEnabled() and addon.MPlus_BroadcastFull then
                addon:MPlus_BroadcastFull()
                if addon.Notify then addon:Notify("Requested party data refresh.", 'info', addon:GetCurrentKeystoneIcon()) end
            end
        end)
        if addon.StyleButton then addon:StyleButton(w.refreshBtn) end

        w.statusText = footer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        w.statusText:SetPoint("BOTTOMLEFT", footer, "BOTTOMLEFT", 0, 6)
        w.statusText:SetPoint("RIGHT", w.refreshBtn, "LEFT", -12, 0)
        w.statusText:SetJustifyH("LEFT")

        w.scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
        w.scroll:SetPoint("TOPLEFT", w.header, "BOTTOMLEFT", 0, -10)
        w.scroll:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, -12)
        w.scroll:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, -12)
        local content = CreateFrame("Frame", nil, w.scroll)
        content:SetSize(240, 10)
        w.scroll:SetScrollChild(content)
        w.content = content
        w.rows = {}
        w.emptyText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        w.emptyText:SetPoint("TOP", content, "TOP", 0, -20)
        w.emptyText:SetWidth(280)
        w.emptyText:SetJustifyH("CENTER")
        w.emptyText:Hide()

        w.scroll:SetScript("OnSizeChanged", function(_, width)
            if width and width > 0 then
                w.content:SetWidth(width)
            end
        end)

        local function GetRoster()
            local names = {}
            if GetNumRaidMembers and GetNumRaidMembers() > 0 then
                for i=1, GetNumRaidMembers() do
                    local unit = "raid"..i
                    local n = UnitName(unit)
                    if n then table.insert(names, n) end
                end
            else
                local playerName = UnitName("player")
                if playerName then table.insert(names, playerName) end
                if GetNumPartyMembers then
                    for i=1, GetNumPartyMembers() do
                        local unit = "party"..i
                        local n = UnitName(unit)
                        if n then table.insert(names, n) end
                    end
                end
            end
            return names
        end

        local specColorMap = { TANK = "|cff4D94FF", HEALER = "|cff33FF99", DPS = "|cffFF6A00" }
        local specLabelMap = { TANK = "Tank", HEALER = "Healer", DPS = "DPS" }

        local function SpecText(spec)
            if not spec then return "|cffB5B5B5Unknown|r" end
            local up = spec:upper()
            local color = specColorMap[up] or "|cffB5B5B5"
            local label = specLabelMap[up] or (spec:gsub("^%l", string.upper))
            return color .. label .. "|r"
        end

        local function ColorIlvl(ilvl)
            if not ilvl or ilvl <= 0 then return "|cffB5B5B5--|r" end
            local color
            if ilvl >= 260 then color = "|cff00FFDC"
            elseif ilvl >= 240 then color = "|cff00D1FF"
            elseif ilvl >= 220 then color = "|cff3399FF"
            elseif ilvl >= 200 then color = "|cff9966FF"
            elseif ilvl >= 180 then color = "|cff66CC33"
            else color = "|cffB5B5B5" end
            return color .. ilvl .. "|r"
        end

        local function FormatAgo(ts, hasData, pending)
            if pending then return "|cffFFD200Pending broadcast...|r" end
            if not hasData or not ts then return "|cffFF5555No data|r" end
            local diff = math.max(0, time() - ts)
            local color
            if diff <= 30 then color = "|cff66FF66"
            elseif diff <= 90 then color = "|cffFFD200"
            else color = "|cffFF5555" end
            local label
            if diff < 1 then
                label = "Just now"
            else
                if SecondsToTimeAbbrev then
                    label = SecondsToTimeAbbrev(diff)
                else
                    if diff >= 3600 then label = string.format("%dh", math.floor(diff/3600))
                    elseif diff >= 60 then label = string.format("%dm", math.floor(diff/60))
                    else label = string.format("%ds", diff) end
                end
                label = (label or "0s") .. " ago"
            end
            return color .. label .. "|r"
        end

        local function SetButtonEnabled(btn, enabled)
            if not btn then return end
            if btn.SetEnabled then btn:SetEnabled(enabled) end
            if enabled then btn:Enable() else btn:Disable() end
        end

        function w:AcquireRow(index)
            local row = self.rows[index]
            if not row then
                row = CreateFrame("Frame", nil, self.content)
                row:SetHeight(20)
                row.alt = row:CreateTexture(nil, "BACKGROUND")
                row.alt:SetAllPoints()
                row.alt:SetColorTexture(1, 1, 1, 0.04)
                row.selfHighlight = row:CreateTexture(nil, "BACKGROUND")
                row.selfHighlight:SetAllPoints()
                row.selfHighlight:SetColorTexture(0.2, 0.6, 1, 0.08)
                row.selfHighlight:Hide()
                row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.name:SetPoint("LEFT", row, "LEFT", 6, 0)
                row.name:SetWidth(150)
                row.name:SetJustifyH("LEFT")
                row.spec = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.spec:SetPoint("LEFT", row, "LEFT", 172, 0)
                row.spec:SetWidth(130)
                row.spec:SetJustifyH("LEFT")
                row.ilvl = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.ilvl:SetPoint("LEFT", row.spec, "RIGHT", 20, 0)
                row.ilvl:SetWidth(52)
                row.ilvl:SetJustifyH("RIGHT")
                row.updated = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.updated:SetPoint("LEFT", row.ilvl, "RIGHT", 16, 0)
                row.updated:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                row.updated:SetJustifyH("RIGHT")
                self.rows[index] = row
            end
            return row
        end

        function w:UpdateStatusLine()
            local shareEnabled = addon:MPlus_IsShareEnabled()
            if not self._hasGroup then
                self.statusText:SetText("|cffB5B5B5Not in a party.|r")
            else
                if not shareEnabled then
                    self.statusText:SetText("|cffFF5555Sharing disabled|r – enable in options to broadcast your role.")
                else
                    local playerName = UnitName("player") or ""
                    local info = addon.MPlusPartyInfo and addon.MPlusPartyInfo[playerName]
                    if info and info.last then
                        self.statusText:SetText("|cff66FF66Sharing active|r – broadcasting latest spec & ilvl.")
                    else
                        self.statusText:SetText("|cffFFD200Sharing enabled – awaiting replies from party.")
                    end
                end
            end
            SetButtonEnabled(self.refreshBtn, shareEnabled)
            if self.missingHint then
                self.missingHint:SetShown(self._missingOthers and self._hasGroup)
            end
        end

        function w:Refresh()
            for _, row in ipairs(self.rows) do row:Hide() end
            local roster = GetRoster()
            local rosterCount = #roster
            local entries = {}
            local playerName = UnitName("player")
            local s = GetSettings()
            for _, name in ipairs(roster) do
                local isSelf = (playerName and name == playerName)
                local data = addon.MPlusPartyInfo and addon.MPlusPartyInfo[name]
                local spec = data and data.spec or (isSelf and (s.spec or addon.MPlusSpec)) or nil
                local ilvl = data and data.ilvl or (isSelf and addon:GetPlayerItemLevel()) or nil
                local hasData = data ~= nil
                local pending = false
                if isSelf and addon:MPlus_IsShareEnabled() and rosterCount > 1 and not hasData then
                    pending = true
                end
                entries[#entries+1] = {
                    name = name,
                    spec = spec,
                    ilvl = ilvl,
                    last = data and data.last or nil,
                    isSelf = isSelf,
                    hasData = hasData,
                    pending = pending,
                }
            end
            table.sort(entries, function(a, b)
                local order = { TANK = 1, HEALER = 2, DPS = 3 }
                local aSpec = a.spec and a.spec:upper() or ""
                local bSpec = b.spec and b.spec:upper() or ""
                local ao = order[aSpec] or 4
                local bo = order[bSpec] or 4
                if ao == bo then
                    if a.isSelf ~= b.isSelf then return a.isSelf end
                    return a.name < b.name
                end
                return ao < bo
            end)

            if rosterCount <= 1 then entries = {} end

            local y = 0
            for idx, entry in ipairs(entries) do
                local row = self:AcquireRow(idx)
                row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
                row:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -y)
                row.alt:SetShown(idx % 2 == 0)
                row.selfHighlight:SetShown(entry.isSelf)
                row.name:SetText(entry.name)
                row.spec:SetText(SpecText(entry.spec))
                row.ilvl:SetText(ColorIlvl(entry.ilvl))
                row.updated:SetText(FormatAgo(entry.last, entry.hasData, entry.pending))
                row:Show()
                y = y + row:GetHeight()
            end

            if y < 10 then y = 10 end
            self.content:SetHeight(y)
            if self.scroll and self.scroll.UpdateScrollChildRect then self.scroll:UpdateScrollChildRect() end

            if #entries == 0 then
                if rosterCount <= 1 then
                    self.emptyText:SetText("Join a party to exchange data.")
                else
                    self.emptyText:SetText("Waiting for party members to broadcast...")
                end
                self.emptyText:Show()
            else
                self.emptyText:Hide()
            end

            local missingOthers = false
            for _, entry in ipairs(entries) do
                if not entry.hasData and not entry.pending and not entry.isSelf then
                    missingOthers = true
                    break
                end
            end
            self._missingOthers = missingOthers
            self._hasGroup = rosterCount > 1
            self:UpdateStatusLine()
        end

        local ev = CreateFrame("Frame")
        ev:RegisterEvent("PARTY_MEMBERS_CHANGED")
        ev:RegisterEvent("RAID_ROSTER_UPDATE")
        ev:SetScript("OnEvent", function()
            if w:IsShown() then w:Refresh() end
        end)

        w:SetScript("OnShow", function(self) self:Refresh() end)
        addon._MPlusPartyWindow = w
    end
    addon._MPlusPartyWindow:Show()
    addon._MPlusPartyWindow:Refresh()
end

local function OnClick(btn)
    local s = GetSettings()
    -- Left click toggles monitoring, right click opens submenu
    local button = GetMouseButtonClicked()
    if button == "RightButton" then
        if not addon._MPlus_DropDown then
            addon._MPlus_DropDown = CreateFrame("Frame", "HAK_MPlus_Context", UIParent, "UIDropDownMenuTemplate")
        end
        BuildContextMenu(btn)
    else
        addon:MPlus_ToggleMonitoring()
    end
end

local function OnTooltip(btn)
    ScanForKeystone()
    UpdateIconAppearance()
    local s = GetSettings()
    local lines = { "Mythic+ Helper" }
    if keystoneInfo.link then
        table.insert(lines, "Keystone: "..keystoneInfo.link)
    else
        table.insert(lines, "No keystone found.")
    end
    -- Affix detection (heuristic)
    local affixes = {}
    if keystoneInfo.link then
        local scanTip = _G.HAK_MPlusScanTip or CreateFrame("GameTooltip", "HAK_MPlusScanTip", UIParent, "GameTooltipTemplate")
        scanTip:SetOwner(UIParent, "ANCHOR_NONE")
        scanTip:ClearLines()
        scanTip:SetHyperlink(keystoneInfo.link)
        for i=2, scanTip:NumLines() do -- skip first line (item name)
            local line = _G["HAK_MPlusScanTipTextLeft"..i]
            if state then
                local txt = line:GetText()
                if txt and #txt>0 then
                    -- Simple heuristic: affix keywords or capitalized single words
                    if txt:find("Affix") or txt:find("Fortified") or txt:find("Tyrannical") or txt:find("Bolstering") or txt:find("Sanguine") or txt:find("Bursting") or txt:find("Grievous") or txt:find("Explosive") or txt:find("Raging") or txt:find("Necrotic") then
                        table.insert(affixes, txt)
                    end
                end
            end
            -- Update visual indicator border
            addon.MPlus_UpdateMonitoringIndicator()
        end
    end
    if #affixes > 0 then
        table.insert(lines, "Affixes:")
        for _, a in ipairs(affixes) do table.insert(lines, " - "..a) end
    end
    do
        local stateLine
        if s.monitoring then
            if addon.MPlusMonitoringSuspended then
                stateLine = "|cffFF4500Monitoring: SUSPENDED|r" -- orange/red for suspended
            else
                stateLine = "|cff33FF33Monitoring: ON|r" -- green for active
            end
        else
            stateLine = "|cffB5B5B5Monitoring: OFF|r" -- grey for disabled
        end
        table.insert(lines, stateLine)
    end
    do
        local shareLine
        if addon:MPlus_IsShareEnabled() then
            shareLine = "|cff33FF33Sharing: ON|r"
        else
            shareLine = "|cffFF5555Sharing: OFF|r"
        end
        table.insert(lines, shareLine)
    end
    -- Separator block
    table.insert(lines, " ")
    table.insert(lines, "|cff888888------------------------------|r")
    -- Party info block (addon-based data)
    if addon.MPlusPartyInfo and next(addon.MPlusPartyInfo) then
        table.insert(lines, "|cffFFE680Party Specs|r")
        for name,data in pairs(addon.MPlusPartyInfo) do
            local specColorMap = { TANK="|cff4D94FF", HEALER="|cff33FF99", DPS="|cffFF6A00" }
            local specHex = specColorMap[data.spec] or "|cffFFFFFF"
            table.insert(lines, specHex..name.." - "..data.spec.." ilvl:"..data.ilvl.."|r")
        end
        table.insert(lines, "|cff888888------------------------------|r")
    end
    table.insert(lines, "|cffFFE680Your Stats|r")
    -- Spec color mapping
    local role = (s.spec or "DPS")
    local roleHexMap = {
        TANK = "|cff4D94FF",   -- steel blue
        HEALER = "|cff33FF99", -- teal/green
        DPS = "|cffFF6A00",    -- fiery orange
    }
    local specLine = (roleHexMap[role] or "|cffFFD700") .. "Spec: " .. role .. "|r"
    table.insert(lines, specLine)
    local ilvl = GetPlayerItemLevel()
    if ilvl then
        -- Dynamic ilvl color tiers
        local tierHex
        if ilvl >= 260 then tierHex = "|cff00FFDC" -- high aqua
        elseif ilvl >= 240 then tierHex = "|cff00D1FF" -- cyan
        elseif ilvl >= 220 then tierHex = "|cff3399FF" -- blue
        elseif ilvl >= 200 then tierHex = "|cff9966FF" -- purple
        elseif ilvl >= 180 then tierHex = "|cff66CC33" -- green
        else tierHex = "|cffB5B5B5" -- grey
        end
        table.insert(lines, tierHex .. "Item Level: " .. ilvl .. "|r")
    end
    table.insert(lines, "|cff888888------------------------------|r")
    table.insert(lines, "Left-click: Toggle LFM Monitoring")
    table.insert(lines, "Right-click: Open submenu")
    if s.debug then table.insert(lines, "Debug: Enabled") end
    return lines
end

-- Perform an early scan so initial icon can reflect keystone if already in bags
ScanForKeystone()
local initialTexture = keystoneInfo.texture or KEY_FALLBACK_ICON
addon:RegisterToolbarIcon("MythicPlusHelper", initialTexture, OnClick, OnTooltip)
-- After registration, ensure appearance (in case item info wasn't cached yet)
UpdateIconAppearance()
addon.MythicPlusHelper_ForceRefresh = function()
    ScanForKeystone(); UpdateIconAppearance()
    addon.MPlus_UpdateMonitoringIndicator()
end

-- External open helper for LFM monitor (manual submenu access)
function addon:MPlus_OpenLFMMonitor()
    if addon.MPlusLFMQueue then
        if addon.MPlusLFMQueue.ManualShow then
            addon.MPlusLFMQueue:ManualShow()
        elseif addon.MPlusLFMQueue.Show then
            addon.MPlusLFMQueue:Show()
        end
    end
end

-- Monitoring state visual indicator (border overlay)
function addon.MPlus_UpdateMonitoringIndicator()
    local btn = _G["HAKToolbarBtn_MythicPlusHelper"]
    if not btn then return end
    -- Create overlay once
    if not btn._mplusMonitorOverlay then
        local ov = btn:CreateTexture(nil, "OVERLAY")
        ov:SetAllPoints(btn.texture)
        ov:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        ov:SetBlendMode("ADD")
        btn._mplusMonitorOverlay = ov
    end
    if not btn._mplusCorner then
        local corner = btn:CreateTexture(nil, "OVERLAY")
        corner:SetSize(8,8)
        corner:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
        corner:SetTexture("Interface\\Buttons\\UI-Quickslot")
        corner:SetBlendMode("ADD")
        btn._mplusCorner = corner
    end
    local s = GetSettings()
    if s.monitoring then
        btn._mplusMonitorOverlay:Show(); btn._mplusMonitorOverlay:SetVertexColor(0, 1, 0, 0.9)
        btn._mplusCorner:Show(); btn._mplusCorner:SetVertexColor(0,1,0,0.9)
    else
        btn._mplusMonitorOverlay:Show(); btn._mplusMonitorOverlay:SetVertexColor(1,0,0,0.5) -- red faint when off
        btn._mplusCorner:Show(); btn._mplusCorner:SetVertexColor(1,0,0,0.8)
    end
end


-- Periodic scan (bag updates)
local scanFrame = CreateFrame("Frame")
scanFrame:RegisterEvent("BAG_UPDATE")
scanFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
local pendingKeystoneScan = false

local function PlayerInCombat()
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitAffectingCombat then return UnitAffectingCombat("player") end
    return false
end

local function RunKeystoneScan()
    pendingKeystoneScan = false
    ScanForKeystone()
    UpdateIconAppearance()
end

scanFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingKeystoneScan then
            RunKeystoneScan()
        end
        return
    end

    if PlayerInCombat() then
        pendingKeystoneScan = true
        return
    end

    RunKeystoneScan()
end)

-- Refresh on PLAYER_LOGIN and when item info becomes available
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
loginFrame:SetScript("OnEvent", function(_, event, itemID)
    if event == "PLAYER_LOGIN" then
        ScanForKeystone(); UpdateIconAppearance()
    elseif event == "GET_ITEM_INFO_RECEIVED" and keystoneInfo.id and itemID == keystoneInfo.id then
        -- Item info for keystone loaded; update texture
        local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
        if texture then keystoneInfo.texture = texture; UpdateIconAppearance() end
    end
end)

if addon.RegisterModuleOptions then
    addon:RegisterModuleOptions("MythicPlusHelper", function(panel)
        local shareSection = addon:CreateSection(panel, "Party Data Sharing", -8, 580)
        shareSection:SetWidth(580)
        local shareCB = CreateFrame("CheckButton", "HAK_MPlus_ShareCB", shareSection, "InterfaceOptionsCheckButtonTemplate")
        shareCB:SetPoint("TOPLEFT", shareSection, "TOPLEFT", 0, 0)
        _G[shareCB:GetName() .. "Text"]:SetText("Share spec & item level with party")
        shareCB:SetChecked(addon:MPlus_IsShareEnabled())
        shareCB:SetScript("OnClick", function(self)
            addon:MPlus_SetShareEnabled(self:GetChecked())
        end)

        local shareNotifyCB = CreateFrame("CheckButton", "HAK_MPlus_ShareNotifyCB", shareSection, "InterfaceOptionsCheckButtonTemplate")
        shareNotifyCB:SetPoint("TOPLEFT", shareCB, "BOTTOMLEFT", 0, -12)
        _G[shareNotifyCB:GetName() .. "Text"]:SetText("Show toast when party data received")
        shareNotifyCB:SetChecked(addon:MPlus_ShouldNotifySharing())
        shareNotifyCB:SetScript("OnClick", function(self)
            addon:MPlus_SetShareNotify(self:GetChecked())
        end)

        local hint = shareSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", shareNotifyCB, "BOTTOMLEFT", 4, -8)
        hint:SetWidth(420)
        hint:SetJustifyH("LEFT")
        hint:SetText("Sharing uses the HAKMP addon channel. Disable to stay silent or in guild runs that forbid external messages.")

        local debugSection = addon:CreateSection(panel, "Debug", -24, 580)
        local dcb = CreateFrame("CheckButton", "HAK_MPlus_DebugCB", debugSection, "InterfaceOptionsCheckButtonTemplate")
        dcb:SetPoint("TOPLEFT", debugSection, "TOPLEFT", 0, 0)
        _G[dcb:GetName() .. "Text"]:SetText("Enable debug info")
        dcb:SetChecked(GetSettings().debug)
        dcb:SetScript("OnClick", function(self)
            local s = GetSettings(); s.debug = self:GetChecked() and true or false
        end)
        local monitorCB = CreateFrame("CheckButton", "HAK_MPlus_MonitorCB", debugSection, "InterfaceOptionsCheckButtonTemplate")
        monitorCB:SetPoint("TOPLEFT", dcb, "BOTTOMLEFT", 0, -16) -- increased spacing below debug checkbox
        _G[monitorCB:GetName() .. "Text"]:SetText("Enable LFM Monitoring")
        monitorCB:SetChecked(GetSettings().monitoring)
        monitorCB:SetScript("OnClick", function(self)
            addon:MPlus_SetMonitoring(self:GetChecked())
        end)
        -- Standard gap before glow section (avoid overflowing panel)
        local glowSection = addon:CreateSection(panel, "Glow Style", -64, 580) -- extra space above glow section title
        glowSection:SetHeight(120)
        local colorBtn = CreateFrame("Button", "HAK_MPlus_GlowColorBtn", glowSection, "UIPanelButtonTemplate")
        colorBtn:SetSize(140,22)
        colorBtn:SetPoint("TOPLEFT", glowSection, "TOPLEFT", 0, -6) -- slight top inset
        colorBtn:SetText("Pick Glow Color")
        local pulseCB = CreateFrame("CheckButton", "HAK_MPlus_PulseCB", glowSection, "InterfaceOptionsCheckButtonTemplate")
        pulseCB:SetPoint("TOPLEFT", colorBtn, "BOTTOMLEFT", 0, -16) -- extra gap under color button
        _G[pulseCB:GetName() .. "Text"]:SetText("Pulse Glow")
        local function RefreshControls()
            local s = GetSettings()
            pulseCB:SetChecked(s.glow.pulse)
            shareCB:SetChecked(addon:MPlus_IsShareEnabled())
            shareNotifyCB:SetChecked(addon:MPlus_ShouldNotifySharing())
        end
        pulseCB:SetScript("OnClick", function(self)
            local s = GetSettings(); s.glow.pulse = self:GetChecked() and true or false; UpdateIconAppearance()
        end)
        colorBtn:SetScript("OnClick", function()
            local s = GetSettings()
            local function ColorPicked(restore)
                local r,g,b
                if restore then
                    r,g,b = unpack(restore)
                else
                    r,g,b = ColorPickerFrame:GetColorRGB()
                end
                s.glow.r, s.glow.g, s.glow.b = r,g,b
                UpdateIconAppearance()
            end
            local function CancelColor(previous)
                if previous then
                    s.glow.r, s.glow.g, s.glow.b = previous[1], previous[2], previous[3]
                    UpdateIconAppearance()
                end
            end
            ColorPickerFrame.func = ColorPicked
            ColorPickerFrame.opacityFunc = nil
            ColorPickerFrame.cancelFunc = CancelColor
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.previousValues = { s.glow.r, s.glow.g, s.glow.b }
            ColorPickerFrame:SetColorRGB(s.glow.r, s.glow.g, s.glow.b)
            ColorPickerFrame:Show()
        end)
        panel:SetScript("OnShow", function() RefreshControls(); UpdateIconAppearance() end)
    end)
end
