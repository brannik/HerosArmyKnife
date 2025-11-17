local addonName, addon = ...

-- Channel 1 feed capture (active only when monitoring enabled)
addon.MPlusLFMQueue = addon.MPlusLFMQueue or {}
local q = addon.MPlusLFMQueue
q.active = false
q.messages = q.messages or {}
q.maxMessages = 200
q.userClosed = q.userClosed or false -- track manual close so we do not auto-pop window if user intentionally hid it

-- Recruit-style pattern filters (adapted from external WeakAura logic)
q.patterns = q.patterns or {
    msLevelingPatterns = {"ms.*lvl", "ms.*level", "ms.*aura", "mana.*lvl", "mana.*level"},
    msGoldPatterns     = {"ms.*gold", "lf.*gold", "mana.*gold"},
    lfmDpsPatterns     = {"lf.*dps", "lf.*%f[%a]dd%f[%A]", "lf.*dmg", "need.*dps", "need.*%f[%a]dd%f[%A]", "need.*dmg", "need.*%f[%a]all%f[%A]", "keystone.*%d+%)].*dps", "keystone.*%d+%)].*%f[%a]dd%f[%A]", "keystone.*%d+%)].*dmg"},
    lfmTankPatterns    = {"lf.*tank", "need.*tank", "keystone.*%d+%)].*tank"},
    lfmHealPatterns    = {"lf.*heal", "need.*heal", "keystone.*%d+%)].*heal"},
    lfmAllPatterns     = {"lf.*kara", "lf.*%f[%a]kc%f[%A]", "keystone.*%d+%)].*%f[%a]all%f[%A]", "lf.*keystone.*%d+%)]", "need.*%f[%a]all%f[%A]", "keystone.*%d+%)].*lf"},
    guildRecruitHints  = {"recruit", "recrut", "recruiting", "recruting", "join", "inv", "invite"},
}

local function IsGuildRecruitment(rawMsg)
    if not rawMsg or rawMsg == "" then return false end
    local msgLower = rawMsg:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("{.-}", "")
    if not msgLower:find("guild") and not msgLower:find("<[^>]+>") then return false end
    -- Require an action hint near guild context to avoid false positives like "guild group"
    local hasAction = false
    for _, h in ipairs(q.patterns.guildRecruitHints) do
        if msgLower:find(h) then hasAction = true break end
    end
    if not hasAction then return false end
    -- Common phrasing checks
    if msgLower:find("join[^%a]*our[^%a]*guild") then return true end
    if msgLower:find("recr%a*[^%a]*for[^%a]*guild") then return true end
    if msgLower:find("guild[^%a]*recr%a*") then return true end
    if msgLower:find("inv[^%a]*to[^%a]*guild") then return true end
    if msgLower:find("<[^>]+>[^%a]*recr%a*") then return true end
    if msgLower:find("recr%a*[^%a]*<[^>]+>") then return true end
    -- Fallback: mention guild plus an action verb
    if msgLower:find("guild") and hasAction then return true end
    return false
end

local function MessageMatchesAnyRecruitPattern(rawMsg)
    if not rawMsg or rawMsg == "" then return false end
    local msgLower = rawMsg:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("{.-}", "")
    -- Exclude guild recruitment from LFG feed
    if IsGuildRecruitment(msgLower) then return false end
    local p = q.patterns
    local matchesMsLeveling, matchesMsGold, matchesLfmDps, matchesLfmTank, matchesLfmHeal = false, false, false, false, false
    for _, pattern in ipairs(p.msLevelingPatterns) do if msgLower:match(pattern) then matchesMsLeveling = true break end end
    for _, pattern in ipairs(p.msGoldPatterns)     do if msgLower:match(pattern) then matchesMsGold     = true break end end
    for _, pattern in ipairs(p.lfmDpsPatterns)     do if msgLower:match(pattern) then matchesLfmDps     = true break end end
    for _, pattern in ipairs(p.lfmTankPatterns)    do if msgLower:match(pattern) then matchesLfmTank    = true break end end
    for _, pattern in ipairs(p.lfmHealPatterns)    do if msgLower:match(pattern) then matchesLfmHeal    = true break end end
    -- If none of the specific role / ms patterns matched, allow lfmAllPatterns to set general interest
    if not (matchesMsLeveling or matchesMsGold or matchesLfmDps or matchesLfmTank or matchesLfmHeal) then
        for _, pattern in ipairs(p.lfmAllPatterns) do
            if msgLower:match(pattern) then
                matchesLfmDps = true; matchesLfmTank = true; matchesLfmHeal = true; break
            end
        end
    end
    -- Recruitment token gating: prevent false positives like "anyone running ms gold farm?"
    -- Only treat msLeveling/msGold patterns as recruitment if a recruiting token/role keyword appears.
    local function HasRecruitToken(m)
        -- Core tokens: lfm, lfg, lf (as standalone), need, role keywords
        return m:find("lfm") or m:find("lfg") or m:find("lf ") or m:find(" need ") or m:find("need%s")
            or m:find("%f[%a]dps%f[%A]") or m:find("%f[%a]tank%f[%A]") or m:find("%f[%a]heal%f[%A]")
            or m:find("looking for") or m:find("looking for more")
    end
    if matchesMsGold and not HasRecruitToken(msgLower) then matchesMsGold = false end
    if matchesMsLeveling and not HasRecruitToken(msgLower) then matchesMsLeveling = false end
    return (matchesMsLeveling or matchesMsGold or matchesLfmDps or matchesLfmTank or matchesLfmHeal)
end

q.entries = q.entries or {}
q.declined = q.declined or {}
q.expireSeconds = 120
q.rowPool = q.rowPool or {}
q.activeRows = q.activeRows or {}
q._declinedLastTrim = q._declinedLastTrim or 0
q.suspended = q.suspended or false
q._lastSoundTime = q._lastSoundTime or 0
q.acceptThrottleSeconds = q.acceptThrottleSeconds or 3 -- minimum seconds between accepts of same entry

-- Forward declare to allow early use in EvaluateActivation
local EnsureWindow

local function IsInGroup()
    local partyCount = (GetNumPartyMembers and GetNumPartyMembers() or 0)
    local raidCount = (GetNumRaidMembers and GetNumRaidMembers() or 0)
    return (partyCount > 0) or (raidCount > 0)
end

function q:EvaluateActivation()
    local monitoringDesired = addon.MPlusMonitoringActive and true or false
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
    local grouped = IsInGroup()
    q.suspended = monitoringDesired and (inCombat or grouped) or false
    addon.MPlusMonitoringSuspended = q.suspended
    local shouldBeActive = monitoringDesired and not q.suspended
    if shouldBeActive then
        EnsureWindow()
        -- Reset manual close flag when (re)activating monitoring
        if not q.active then q.userClosed = false end
        q.frame:Show()
    else
        if q.frame then q.frame:Hide() end
    end
    q.active = shouldBeActive
    if addon.MythicPlusHelper_ForceRefresh then addon.MythicPlusHelper_ForceRefresh() end
end

local function ExtractKey(msg)
    if not msg then return "" end
    -- Try to find a keystone-like pattern: [Keystone: ...] or item link containing 'keystone'
    local link = msg:match("(|Hitem:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+|h[^|]+|h)")
    if link and link:lower():match("keystone") then return link end
    local k = msg:match("keystone[^%[]*%[(.-)%]")
    if k then return k end
    local plain = msg:match("keystone[%w%s%%%-%(%)]*")
    return plain or ""
end

local function Normalize(sender, msg)
    if not msg then return "" end
    msg = msg:lower():gsub("|c%x%x%x%x%x%x%x%x"," "):gsub("|r"," "):gsub("{.-}","")
    return (sender or "?" ).."|"..msg
end

function EnsureWindow()
    if q.frame then return end
    local f = addon.CreateThemedFrame and addon:CreateThemedFrame(UIParent, "HAK_LFMChannelFeed", 460, 360, 'panel') or CreateFrame("Frame", "HAK_LFMChannelFeed", UIParent, "BackdropTemplate")
    f:SetPoint("CENTER", UIParent, "CENTER", 320, -40)
    if not f:GetWidth() or f:GetWidth() <= 0 then f:SetSize(460, 360) end
    local container
    if addon.ApplyStandardPanelChrome then
        container = addon:ApplyStandardPanelChrome(f, "LFG Monitor", { bodyPadding = { left = 18, right = 24, top = 78, bottom = 22 }, dragBody = true })
    end
    local manualClose
    if not container then
        f:EnableMouse(true)
        f:SetMovable(true)
        f:SetClampedToScreen(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOP", f, "TOP", 0, -6)
        title:SetText("LFG Monitor")
        manualClose = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        manualClose:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
        container = CreateFrame("Frame", nil, f)
        container:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -78)
        container:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 22)
    end
    container = container or f
    local function HandleClose()
        -- Mark all current entries declined and clear list
        for _, e in ipairs(q.entries) do
            if not e.norm then
                e.norm = (e.sender or "?").."|"..((e.msg or ""):lower():gsub("|c%x%x%x%x%x%x%x%x"," "):gsub("|r"," "):gsub("{.-}",""))
            end
            if e.norm then q.declined[e.norm] = time() end
        end
        q.entries = {}
        q:RefreshList()
        f:Hide()
        q.userClosed = true -- user intentionally closed; suppress auto re-open on new messages
    end
    if f.closeButton then
        f.closeButton:SetScript("OnClick", HandleClose)
    elseif manualClose then
        manualClose:SetScript("OnClick", HandleClose)
    end
    -- Scroll container
    local scrollFrame = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -18, 0)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(10,10)
    scrollFrame:SetScrollChild(content)
    q.content = content
    q.scrollFrame = scrollFrame
    q.frame = f
    -- Periodic expiry driver
    f._accum = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        f._accum = f._accum + elapsed
        if f._accum < 1 then return end
        f._accum = 0
        local now = time()
        if #q.entries == 0 then
            if now - q._declinedLastTrim > 10 then
                q._declinedLastTrim = now
                local count = 0
                for _ in pairs(q.declined) do count = count + 1 end
                if count > 500 then
                    for k, t in pairs(q.declined) do if now - t > 600 then q.declined[k] = nil end end
                end
            end
            return
        end
        local changed
        for i = #q.entries, 1, -1 do
            local e = q.entries[i]
            if now - e.time > q.expireSeconds then
                if not e.norm then
                    e.norm = (e.sender or "?").."|"..((e.msg or ""):lower():gsub("|c%x%x%x%x%x%x%x%x"," "):gsub("|r"," "):gsub("{.-}",""))
                end
                if e.norm then q.declined[e.norm] = now end
                table.remove(q.entries, i)
                changed = true
            end
        end
        if changed then q:RefreshList() end
        if now - q._declinedLastTrim > 10 then
            q._declinedLastTrim = now
            local count = 0
            for _ in pairs(q.declined) do count = count + 1 end
            if count > 500 then
                for k, t in pairs(q.declined) do if now - t > 600 then q.declined[k] = nil end end
            end
        end
    end)
end

local function AcquireRow()
    local row = table.remove(q.rowPool)
    if row then
        row:Show()
        return row
    end
    row = CreateFrame("Frame", nil, q.content, "BackdropTemplate")
    row:SetBackdrop({ bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=12, insets={left=3,right=3,top=3,bottom=3} })
    row:SetBackdropColor(0,0,0,0.55)
    row:SetBackdropBorderColor(0.3,0.55,0.9,0.9)
    row.senderText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.senderText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -6)
    row.keyText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.keyText:SetPoint("LEFT", row.senderText, "RIGHT", 12, 0)
    row.msgText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.msgText:SetPoint("TOPLEFT", row.senderText, "BOTTOMLEFT", 0, -4)
    row.msgText:SetJustifyH("LEFT")
    row.msgText:SetWordWrap(true)
    row.acceptBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.acceptBtn:SetSize(60,22)
    row.declineBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.declineBtn:SetSize(60,22)
    row.declineBtn:SetPoint("RIGHT", row.acceptBtn, "LEFT", -8, 0)
    if addon.StyleButton then
        addon:StyleButton(row.acceptBtn)
        addon:StyleButton(row.declineBtn)
    end
    return row
end

local function SetupRow(row, entry, yOffset)
    local baseWidth = q.content:GetParent():GetWidth() - 4
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", q.content, "TOPLEFT", 0, -yOffset)
    row.senderText:SetText(entry.sender)
    row.keyText:SetText(entry.key ~= "" and ("|cffffd200"..entry.key.."|r") or "")
    row.msgText:SetWidth(baseWidth - 180)
    row.msgText:SetText(entry.msg)
    local textHeight = row.msgText:GetStringHeight() or 12
    local minHeight = 48
    local totalHeight = textHeight + 26
    if totalHeight < minHeight then totalHeight = minHeight end
    row:SetSize(baseWidth, totalHeight)
    local btnY = (totalHeight > minHeight) and - (totalHeight/2 - 11) or -6
    row.acceptBtn:ClearAllPoints()
    row.acceptBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, btnY)
    row.acceptBtn:SetText("Accept")
    row.acceptBtn:SetScript("OnClick", function()
        local now = time()
        if entry._lastAccept and (now - entry._lastAccept) < (q.acceptThrottleSeconds or 3) then
            if addon.Notify then addon:Notify("Accept throttled ("..(q.acceptThrottleSeconds or 3).."s)", 'warn') end
            return
        end
        entry._lastAccept = now
        local spec = addon.MPlusSpec or (addon.GetModuleSettings and addon:GetModuleSettings('MythicPlusHelper', {}).spec) or "DPS"
        local ilvl = addon:GetPlayerItemLevel() or "?"
        local whisper = string.format("hi, im %s and ilvl %s - inv", spec, ilvl)
        SendChatMessage(whisper, "WHISPER", nil, entry.sender)
        -- Mark declined to suppress reappearance, ensure norm exists
        if not entry.norm then
            entry.norm = (entry.sender or "?").."|"..((entry.msg or ""):lower():gsub("|c%x%x%x%x%x%x%x%x"," "):gsub("|r"," "):gsub("{.-}",""))
        end
        if entry.norm then q.declined[entry.norm] = now end
        -- Auto-hide: remove entry from active list
        for i,e in ipairs(q.entries) do if e == entry then table.remove(q.entries,i) break end end
        q:RefreshList()
        if addon.Notify then addon:Notify("Whisper sent to "..entry.sender, 'success') end
    end)
    row.declineBtn:SetText("Decline")
    row.declineBtn:SetScript("OnClick", function()
        if not entry.norm then
            entry.norm = (entry.sender or "?").."|"..((entry.msg or ""):lower():gsub("|c%x%x%x%x%x%x%x%x"," "):gsub("|r"," "):gsub("{.-}",""))
        end
        if entry.norm then q.declined[entry.norm] = time() end
        for i, e in ipairs(q.entries) do if e == entry then table.remove(q.entries, i) break end end
        q:RefreshList()
    end)
    return totalHeight
end

function q:RefreshList()
    if not q.content then return end
    for _, row in ipairs(q.activeRows) do row:Hide(); row:SetParent(q.content); table.insert(q.rowPool, row) end
    q.activeRows = {}
    local yOffset = 0
    for _, entry in ipairs(q.entries) do
        local row = AcquireRow()
        local h = SetupRow(row, entry, yOffset)
        table.insert(q.activeRows, row)
        yOffset = yOffset + h + 6
    end
    if yOffset < 10 then yOffset = 10 end
    q.content:SetHeight(yOffset)
end

function q:OnMonitoringChanged(state)
    q:EvaluateActivation()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")
eventFrame:SetScript("OnEvent", function(_, event, msg, sender, languageName, channelName, senderName, flags, zoneChannelID, channelIndex)
    if not q.active then return end
    if channelIndex ~= 1 and channelIndex ~= 2 then return end
    if not MessageMatchesAnyRecruitPattern(msg) then return end
    EnsureWindow()
    local norm = Normalize(sender, msg)
    if q.declined[norm] and time() - q.declined[norm] < 120 then return end -- suppress re-add for 2 minutes
    for _, e in ipairs(q.entries) do if e.norm == norm then return end end -- duplicate across channels
    local entry = { sender = sender or "?", msg = msg, key = ExtractKey(msg), norm = norm, channel = channelIndex, time = time() }
    table.insert(q.entries, entry)
    local now = time()
    if now - q._lastSoundTime > 1 then
        if PlaySound then
            if SOUNDKIT and SOUNDKIT.RAID_WARNING then
                PlaySound(SOUNDKIT.RAID_WARNING, "Master")
            else
                PlaySound(8959, "Master") -- fallback kit id
            end
        elseif PlaySoundFile then
            PlaySoundFile("Sound\\Interface\\RaidWarning.ogg", "Master")
        end
        q._lastSoundTime = now
    end
    -- prune oldest beyond maxMessages
    if #q.entries > q.maxMessages then table.remove(q.entries, 1) end
    q:RefreshList()
    -- Auto-show if monitoring active and window hidden (unless user manually closed it)
    if q.frame and not q.userClosed and not q.frame:IsShown() then
        q.frame:Show()
    end
end)

-- Expose manual show (optional)
function q:Show()
    EnsureWindow(); q.userClosed = false; q.frame:Show(); q:RefreshList()
end

-- Manual show helper (distinct naming for external calls)
function q:ManualShow()
    q:Show()
end

-- State change monitoring for combat/group transitions
local stateFrame = CreateFrame("Frame")
stateFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
stateFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
stateFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
stateFrame:RegisterEvent("RAID_ROSTER_UPDATE")
stateFrame:SetScript("OnEvent", function()
    q:EvaluateActivation()
end)
