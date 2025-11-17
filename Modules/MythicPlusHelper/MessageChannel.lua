local addonName, addon = ...

local PREFIX = "HAKMP" -- dedicated Mythic+ helper prefix
addon.MPlusPartyInfo = addon.MPlusPartyInfo or {} -- [name] = {spec=, ilvl=, last=timestamp}
local rosterPrev = {}
local nextGearBroadcast = 0

local function GetSettings()
    if addon.GetModuleSettings then
        return addon:GetModuleSettings('MythicPlusHelper', { monitoring = false, shareEnabled = true, shareNotify = false })
    end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.moduleSettings and HerosArmyKnifeDB.settings.moduleSettings.MythicPlusHelper or { shareEnabled = true, shareNotify = false }
end

local function IsSharingEnabled()
    if addon.MPlus_IsShareEnabled then return addon:MPlus_IsShareEnabled() end
    local s = GetSettings()
    return s.shareEnabled ~= false
end

local function IsInMythicParty()
    if IsInRaid and IsInRaid() then return false end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then return false end
    if GetNumPartyMembers and GetNumPartyMembers() > 0 then return true end
    if IsInGroup and IsInGroup() then
        return true
    end
    return false
end

local function ShouldNotifySharing()
    if addon.MPlus_ShouldNotifySharing then return addon:MPlus_ShouldNotifySharing() end
    local s = GetSettings()
    return s.shareNotify and true or false
end

-- Register prefix (Wrath classic uses RegisterAddonMessagePrefix)
if RegisterAddonMessagePrefix then pcall(RegisterAddonMessagePrefix, PREFIX) end

-- Unified addon message / chat channel helper
function addon:SendAddonChannel(prefix, payload, channel, target)
    prefix = prefix or PREFIX
    payload = payload or ""
    channel = channel or "PARTY"
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        local distro = (channel == "RAID" and "RAID") or (channel == "GUILD" and "GUILD") or (channel == "PARTY" and "PARTY") or "WHISPER"
        local chatTarget = target or (distro == "WHISPER" and UnitName("player")) or nil
        C_ChatInfo.SendAddonMessage(prefix, payload, distro, chatTarget)
        return true
    elseif SendAddonMessage then
        local distro = (channel == "RAID" and "RAID") or (channel == "GUILD" and "GUILD") or (channel == "PARTY" and "PARTY") or "WHISPER"
        local chatTarget = target or (distro == "WHISPER" and UnitName("player")) or nil
        SendAddonMessage(prefix, payload, distro, chatTarget)
        return true
    else
        local safePayload = ("["..(prefix or PREFIX).."] "..payload):gsub("|", "||")
        SendChatMessage(safePayload, channel)
        return false
    end
end

-- Build data payload: DATA|spec|ilvl
local function BuildDataPayload()
    local spec = addon.MPlusSpec or "DPS"
    local ilvl
    if addon.GetPlayerItemLevel then ilvl = addon:GetPlayerItemLevel() end
    if not ilvl then ilvl = 0 end
    return "DATA|"..spec.."|"..ilvl
end

-- Send full broadcast to group (party/raid) and request everyone
function addon:MPlus_BroadcastFull()
    if not IsSharingEnabled() then return end
    if not IsInMythicParty() then return end
    local payload = BuildDataPayload()
    addon:SendAddonChannel(PREFIX, payload, "PARTY")
    addon:SendAddonChannel(PREFIX, "REQ", "PARTY")
end

-- Send to a single new member (WHISPER) and request only his data
function addon:MPlus_SendTo(name)
    if not name or name == UnitName("player") then return end
    if not IsSharingEnabled() then return end
    if not IsInMythicParty() then return end
    local payload = BuildDataPayload()
    addon:SendAddonChannel(PREFIX, payload, "WHISPER", name)
    addon:SendAddonChannel(PREFIX, "REQ", "WHISPER", name)
end

-- Handle incoming addon messages
local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX then return end
    local p = sender
    if not p or p == UnitName("player") then return end
    if message == "REQ" then
        -- Respond only to requester (WHISPER back)
        if IsSharingEnabled() then addon:MPlus_SendTo(p) end
        return
    end
    local parts = { strsplit("|", message) }
    if parts[1] == "DATA" then
        local spec = parts[2] or "DPS"
        local ilvl = tonumber(parts[3] or "0") or 0
        addon.MPlusPartyInfo[p] = { spec = spec, ilvl = ilvl, last = time() }
        if ShouldNotifySharing() and addon.Notify then addon:Notify(p.." -> "..spec.." ilvl:"..ilvl, 'info') end
        if addon._MPlusPartyWindow and addon._MPlusPartyWindow:IsShown() and addon._MPlusPartyWindow.Refresh then
            addon._MPlusPartyWindow:Refresh()
        end
    end
end

-- Roster scanning
local function CurrentRoster()
    local names = {}
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        for i=1, GetNumRaidMembers() do
            local n = UnitName("raid"..i)
            if n then names[n] = true end
        end
    else
        for i=1, GetNumPartyMembers() do
            local n = UnitName("party"..i)
            if n then names[n] = true end
        end
    end
    return names
end

local function DetectNewMembers()
    if not IsInMythicParty() then
        rosterPrev = {}
        return
    end
    local current = CurrentRoster()
    for n,_ in pairs(current) do
        if not rosterPrev[n] then
            addon:MPlus_SendTo(n)
        end
    end
    for name in pairs(addon.MPlusPartyInfo) do
        if name ~= UnitName("player") and not current[name] then
            addon.MPlusPartyInfo[name] = nil
        end
    end
    if addon._MPlusPartyWindow and addon._MPlusPartyWindow:IsShown() and addon._MPlusPartyWindow.Refresh then
        addon._MPlusPartyWindow:Refresh()
    end
    rosterPrev = current
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        rosterPrev = CurrentRoster()
        addon:MPlus_BroadcastFull()
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        DetectNewMembers()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        OnAddonMessage(prefix, message, channel, sender)
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" and IsSharingEnabled() and IsInMythicParty() then
            local now = GetTime and GetTime() or time()
            if now >= nextGearBroadcast then
                nextGearBroadcast = now + 5
                addon:MPlus_BroadcastFull()
            end
        end
    end
end)

-- Expose simple listing function
function addon:MPlus_ListPartyInfo()
    for name, data in pairs(addon.MPlusPartyInfo) do
        addon:Notify(name..": "..data.spec.." ilvl:"..data.ilvl, 'info')
    end
end
