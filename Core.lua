local addonName, addon = ...
if not addon then
    addon = {}
    _G[addonName] = addon
end

addon.frame = CreateFrame("Frame")
addon.frame:RegisterEvent("ADDON_LOADED")
addon.frame:RegisterEvent("PLAYER_LOGIN")

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99HerosArmyKnife|r: " .. (msg or ""))
end

addon._initCallbacks = addon._initCallbacks or {}
function addon:RegisterInit(cb) if type(cb)=="function" then table.insert(addon._initCallbacks, cb) end end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99HerosArmyKnife|r: " .. (msg or ""))
end
addon.Print = Print

-- Ensure global DB table exists early so other files referencing it do not error
HerosArmyKnifeDB = HerosArmyKnifeDB or {}

-- Utility: shallow/deep defaults assignment and module settings accessor
local function DeepCopy(src)
    if type(src) ~= 'table' then return src end
    local t = {}
    for k,v in pairs(src) do t[k] = DeepCopy(v) end
    return t
end

function addon:AssignDefaults(dst, defaults)
    if type(dst) ~= 'table' then dst = {} end
    if type(defaults) ~= 'table' then return dst end
    for k, v in pairs(defaults) do
        if dst[k] == nil then
            dst[k] = DeepCopy(v)
        elseif type(v) == 'table' and type(dst[k]) == 'table' then
            addon:AssignDefaults(dst[k], v)
        end
    end
    return dst
end

function addon:GetModuleSettings(key, defaults)
    if not key then return {} end
    HerosArmyKnifeDB = HerosArmyKnifeDB or {}
    local db = HerosArmyKnifeDB
    db.settings = db.settings or {}
    local s = db.settings
    s.moduleSettings = s.moduleSettings or {}
    local ms = s.moduleSettings
    ms[key] = addon:AssignDefaults(ms[key] or {}, defaults or {})
    return ms[key]
end

addon.frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            HerosArmyKnifeDB = HerosArmyKnifeDB or {}
            HerosArmyKnifeDB.settings = HerosArmyKnifeDB.settings or {}
            local s = HerosArmyKnifeDB.settings
            s.toolbar = s.toolbar or { point = "CENTER", x = 0, y = 0 }
            local t = s.toolbar
            if t.orientation == nil then t.orientation = "HORIZONTAL_LR" end -- HORIZONTAL_LR, HORIZONTAL_RL, VERTICAL_TB, VERTICAL_BT
            if t.iconScale == nil then t.iconScale = 1 end
            if t.iconSpacing == nil then t.iconSpacing = 6 end
            if t.padTop == nil then t.padTop = 4 end
            if t.padBottom == nil then t.padBottom = 4 end
            if t.padLeft == nil then t.padLeft = 4 end
            if t.padRight == nil then t.padRight = 4 end
            t.locked = t.locked == true -- ensure boolean
            s.modulesEnabled = s.modulesEnabled or {}
            s.themeName = s.themeName or "Default"
            s.moduleSettings = s.moduleSettings or {}
            -- Notifications settings defaults
            s.notifications = s.notifications or { mode = 'CHAT' }
            local n = s.notifications
            if not n.mode then n.mode = 'CHAT' end
            n.colors = n.colors or {
                info    = {0.6,0.8,1},
                success = {0.2,1,0.2},
                warn    = {1,0.8,0.2},
                error   = {1,0.25,0.25},
            }
            -- Remove deprecated exampleEnabled if present
            if HerosArmyKnifeDB.settings.exampleEnabled ~= nil then
                HerosArmyKnifeDB.settings.exampleEnabled = nil
            end
        end
    elseif event == "PLAYER_LOGIN" then
        addon.Print("Loaded. Type /hak for help.")
        if addon.InitTheme then addon:InitTheme() end
        if addon.BuildToolbar then
            addon:BuildToolbar()
            addon:RebuildToolbar() -- ensure pending buttons respect enable settings
        end
        if addon.BuildModuleOptionsPanels then
            addon:BuildModuleOptionsPanels()
        end
        -- Run deferred module init callbacks (settings safe now)
        for _, cb in ipairs(addon._initCallbacks) do pcall(cb) end
        if addon.RebuildToolbar then addon:RebuildToolbar() end
    end
end)

-- Helper to query module enabled state
function addon:IsModuleEnabled(key)
    if not key then return false end
    return HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.modulesEnabled[key] ~= false
end

-- Center-screen notification stack
local notifyParent
local activeNotes = {}
local function EnsureNotifyParent()
    if notifyParent then return end
    notifyParent = CreateFrame("Frame", "HerosArmyKnifeNotificationFrame", UIParent)
    notifyParent:SetSize(320, 40)
    -- Position nearer top instead of center
    notifyParent:SetPoint("TOP", UIParent, "TOP", 0, -160)
    notifyParent:SetFrameStrata("TOOLTIP")
end

local function ReflowNotes()
    for i, n in ipairs(activeNotes) do
        n:ClearAllPoints()
        n:SetPoint("TOP", notifyParent, "TOP", 0, -(i-1)*34)
    end
end

local function CreateCenterNote(msg, severity, iconTex, color)
    EnsureNotifyParent()
    local f = CreateFrame("Frame", nil, notifyParent, "BackdropTemplate")
    f:SetSize(320, 32)
    f:SetBackdrop({ bgFile="Interface/Tooltips/UI-Tooltip-Background", edgeFile="Interface/Tooltips/UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=12, insets={left=2,right=2,top=2,bottom=2} })
    f:SetBackdropColor(0,0,0,0.85)
    f:SetBackdropBorderColor(color[1],color[2],color[3],0.8)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(26,26)
    f.icon:SetPoint("LEFT", f, "LEFT", 6, 0)
    f.icon:SetTexture(iconTex or "Interface/Icons/INV_Misc_QuestionMark")
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.text:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    f.text:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    f.text:SetJustifyH("LEFT")
    local r,g,b = unpack(color)
    f.text:SetTextColor(r,g,b,1)
    f.text:SetText(msg)
    f.age, f.life, f.fade = 0, 4, 0.7
    f:SetAlpha(0)
    f:SetScript("OnUpdate", function(self, elapsed)
        self.age = self.age + elapsed
        local a
        if self.age < 0.25 then
            a = self.age/0.25
        elseif self.age > self.life then
            local t = self.age - self.life
            a = math.max(0, 1 - t/self.fade)
            if a <= 0 then
                self:SetScript("OnUpdate", nil)
                for i, n in ipairs(activeNotes) do if n == self then table.remove(activeNotes, i) break end end
                self:Hide(); self:SetParent(nil)
                ReflowNotes()
                return
            end
        else
            a = 1
        end
        self:SetAlpha(a)
    end)
    table.insert(activeNotes, f)
    ReflowNotes()
end

function addon:Notify(msg, severity, iconTex)
    if not msg or msg == '' then return end
    local n = HerosArmyKnifeDB.settings.notifications
    severity = severity or 'info'
    local color = (n.colors and n.colors[severity]) and n.colors[severity] or {1,1,1}
    -- Auto keystone icon if none provided and API exists
    if not iconTex and addon.GetCurrentKeystoneIcon then
        iconTex = addon:GetCurrentKeystoneIcon()
    end
    if n.mode == 'CHAT' then
        local r,g,b = unpack(color)
        if iconTex then
            -- Use icon tag; omit addon name prefix
            local tag = "|T"..iconTex..":16:16:0:0|t"
            DEFAULT_CHAT_FRAME:AddMessage(tag.." "..msg, r,g,b)
        else
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ff99HerosArmyKnife|r: %s", msg), r,g,b)
        end
        return
    end
    CreateCenterNote(msg, severity, iconTex, color)
end

-- Unified anchored context menu (submenu) display using same logic as tooltip anchor
function addon:ShowAnchoredMenu(btn, menu, dropdownName)
    if not btn or not menu then return end
    local anchorDir = addon.GetTooltipAnchor and addon:GetTooltipAnchor(btn) or "ANCHOR_BOTTOM"
    if not addon._menuAnchor then
        addon._menuAnchor = CreateFrame("Frame", "HAK_GlobalMenuAnchor", UIParent)
        addon._menuAnchor:SetSize(1,1)
    end
    local a = addon._menuAnchor
    a:ClearAllPoints()
    if anchorDir == "ANCHOR_LEFT" then
        a:SetPoint("RIGHT", btn, "LEFT", -4, 0)
    elseif anchorDir == "ANCHOR_RIGHT" then
        a:SetPoint("LEFT", btn, "RIGHT", 4, 0)
    elseif anchorDir == "ANCHOR_TOP" then
        a:SetPoint("BOTTOM", btn, "TOP", 0, 4)
    else -- bottom or fallback
        a:SetPoint("TOP", btn, "BOTTOM", 0, -4)
    end
    local dropdown = _G[dropdownName] or CreateFrame("Frame", dropdownName or "HAK_ContextMenu", UIParent, "UIDropDownMenuTemplate")
    EasyMenu(menu, dropdown, a, 0, 0, "MENU")
end
