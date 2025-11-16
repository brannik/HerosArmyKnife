local addonName, addon = ...

-- Keystone detection cache
local keystoneInfo = { id = nil, name = nil, link = nil, texture = nil }
local KEY_FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Key_03"

addon:RegisterInit(function()
    local s = addon.GetModuleSettings and addon:GetModuleSettings('MythicPlusHelper', { monitoring = false, debug = false, glow = { r=1, g=0.85, b=0, a=0.9, pulse=false }, spec = "DPS", recruitInterval = 60, recruitChannel = 1, recruitNeedTank = false, recruitNeedHealer = false, recruitNeedDPS = false }) or (HerosArmyKnifeDB.settings.moduleSettings.MythicPlusHelper or {})
    if s.monitoring == nil then s.monitoring = false end
    if s.debug == nil then s.debug = false end
    if not s.glow then s.glow = { r=1, g=0.85, b=0, a=0.9, pulse=false } end
    if not s.spec then s.spec = "DPS" end
    if s.recruitInterval == nil then s.recruitInterval = 60 end
    if s.recruitChannel == nil then s.recruitChannel = 1 end
    if s.recruitNeedTank == nil then s.recruitNeedTank = false end
    if s.recruitNeedHealer == nil then s.recruitNeedHealer = false end
    if s.recruitNeedDPS == nil then s.recruitNeedDPS = false end
    addon.MPlusSpec = s.spec
    -- Auto-apply saved monitoring state silently on init
    if s.monitoring then
        addon:MPlus_SetMonitoring(true, true) -- silent
    end
end)

local function GetSettings()
    if addon.GetModuleSettings then return addon:GetModuleSettings('MythicPlusHelper', { monitoring = false, debug = false, glow = { r=1, g=0.85, b=0, a=0.9, pulse=false }, spec = "DPS", recruitInterval = 60, recruitChannel = 1, recruitNeedTank = false, recruitNeedHealer = false, recruitNeedDPS = false }) end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings.MythicPlusHelper or { monitoring = false }
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
        local w = addon.CreateThemedFrame and addon:CreateThemedFrame(UIParent, "HAK_MPlusPartyInfo", 260, 180, 'panel') or CreateFrame("Frame", "HAK_MPlusPartyInfo", UIParent, "BackdropTemplate")
        w:SetPoint("CENTER", UIParent, "CENTER", 60, 40)
        w:EnableMouse(true)
        w:SetMovable(true)
        local title = w:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOP", w, "TOP", 0, 0)
        title:SetText("Party Info")
        local drag = CreateFrame("Frame", nil, w)
        drag:SetPoint("TOPLEFT", w, "TOPLEFT", 0, 0)
        drag:SetPoint("TOPRIGHT", w, "TOPRIGHT", -34, 0)
        drag:SetHeight(34)
        drag:EnableMouse(true)
        drag:RegisterForDrag("LeftButton")
        drag:SetScript("OnDragStart", function() w:StartMoving() end)
        drag:SetScript("OnDragStop", function() w:StopMovingOrSizing() end)
        local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -4, -4)
        close:SetFrameLevel(w:GetFrameLevel()+10)
        close:SetScript("OnClick", function() w:Hide() end)
        w.scroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
        w.scroll:SetPoint("TOPLEFT", w, "TOPLEFT", 12, -40)
        w.scroll:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -30, 12)
        local content = CreateFrame("Frame", nil, w.scroll)
        content:SetSize(200, 10)
        w.scroll:SetScrollChild(content)
        w.content = content
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
        function w:Refresh()
            for _, c in ipairs({ w.content:GetChildren() }) do c:Hide(); c:SetParent(nil) end
            local roster = GetRoster()
            local y = 0
            for _, name in ipairs(roster) do
                local row = CreateFrame("Frame", nil, w.content)
                row:SetPoint("TOPLEFT", w.content, "TOPLEFT", 0, -y)
                row:SetSize(200, 18)
                local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                fs:SetPoint("LEFT", row, "LEFT", 4, 0)
                local pdata = addon.MPlusPartyInfo and addon.MPlusPartyInfo[name]
                if pdata then
                    local col = specColorMap[pdata.spec] or "|cffFFFFFF"
                    local ilvl = pdata.ilvl or "?"
                    fs:SetText(col .. name .. "|r - " .. pdata.spec .. " ilvl:" .. ilvl)
                else
                    fs:SetText(name)
                end
                y = y + 20
            end
            if y < 10 then y = 10 end
            w.content:SetHeight(y)
        end
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("PARTY_MEMBERS_CHANGED")
        ev:RegisterEvent("RAID_ROSTER_UPDATE")
        ev:SetScript("OnEvent", function()
            if w:IsShown() then w:Refresh() end
        end)
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
scanFrame:SetScript("OnEvent", function()
    ScanForKeystone(); UpdateIconAppearance()
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
        local debugSection = addon:CreateSection(panel, "Debug", -8, 580)
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
