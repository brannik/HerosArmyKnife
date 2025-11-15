local addonName, addon = ...

local btnSize = 24
addon.toolbarButtons = {}
addon.moduleRegistry = addon.moduleRegistry or {}

-- Helper: derive coloring for action hint lines in tooltips
local function HAK_ColorizeTooltipLine(line)
    if not line or line == "" then return line, 1,1,1 end
    -- Preserve explicit color codes provided by module authors
    if line:find("^|cff%x%x%x%x%x%x") then return line, 1,1,1 end
    local l = line:gsub("^%s+","")
    local lower = l:lower()
    -- Inline ON/OFF state coloring (replace standalone words)
    local function colorStateTokens(src)
        -- Replace whole-word ON / OFF (any case) with colored tokens
        src = src:gsub("%f[%a][Oo][Nn]%f[%A]", "|cff00ff00ON|r")
        src = src:gsub("%f[%a][Oo][Ff][Ff]%f[%A]", "|cffff2020OFF|r")
        return src
    end
    line = colorStateTokens(line)
    -- Map leading action verbs / modifiers to distinct colors
    if lower:find("^click") or lower:find("^left") then
        return line, 0.15, 0.95, 0.15
    elseif lower:find("^right") then
        return line, 1, 0.55, 0.1
    elseif lower:find("^shift") then
        return line, 0.85, 0.5, 1
    elseif lower:find("^ctrl") or lower:find("^control") then
        return line, 1, 1, 0.3
    elseif lower:find("^alt") then
        return line, 0.25, 0.9, 0.9
    elseif lower:find("^drag") or lower:find("^drag frame") then
        return line, 0.6, 0.8, 1
    elseif lower:find("^debug") then
        return line, 1, 0.3, 0.8
    end
    return line, 0.95, 0.95, 0.95
end

-- Normalize action lines: ensure each action hint appears on its own row.
local function HAK_ExpandActionLines(lines)
    if type(lines) ~= 'table' then return lines end
    if #lines == 0 then return lines end
    local expanded = {}
    for i, line in ipairs(lines) do
        if i == 1 then
            table.insert(expanded, line)
        else
            local work = line
            -- Split first on semicolons which commonly separate actions
            local didSplit = false
            if work:find(';') then
                for part in work:gmatch("[^;]+") do
                    local trimmed = part:gsub("^%s+", ""):gsub("%s+$", "")
                    if trimmed ~= "" then table.insert(expanded, trimmed) end
                end
                didSplit = true
            end
            -- If not split yet, attempt split on ' | '
            if not didSplit and work:find('%s|%s') then
                for part in work:gmatch("[^|]+") do
                    local trimmed = part:gsub("^%s+", ""):gsub("%s+$", "")
                    if trimmed ~= "" then table.insert(expanded, trimmed) end
                end
                didSplit = true
            end
            -- If still not split and contains multiple comma-separated action tokens (heuristic: contains ':' and ',')
            if not didSplit and work:find(':') and work:find(',') then
                local prefix, rest = work:match("^(.-:%s*)(.+)$")
                if prefix and rest then
                    local firstInserted = false
                    for part in rest:gmatch("[^,]+") do
                        local trimmed = part:gsub("^%s+", ""):gsub("%s+$", "")
                        if trimmed ~= "" then
                            local combined = firstInserted and trimmed or (prefix .. trimmed)
                            table.insert(expanded, combined)
                            firstInserted = true
                        end
                    end
                    didSplit = true
                end
            end
            -- Fallback: just add original line
            if not didSplit then
                table.insert(expanded, work)
            end
        end
    end
    return expanded
end

function addon:RegisterToolbarIcon(key, texture, onClick, onTooltip)
    if not key then return end
    addon.moduleRegistry[key] = { key = key, texture = texture, onClick = onClick, onTooltip = onTooltip }
    local enabled = HerosArmyKnifeDB and HerosArmyKnifeDB.settings and HerosArmyKnifeDB.settings.modulesEnabled[key] ~= false
    if addon.toolbarFrame and addon.toolbarFrame.initialized and enabled then
        addon:CreateToolbarButton(key, texture, onClick, onTooltip)
    else
        addon._pendingButtons = addon._pendingButtons or {}
        table.insert(addon._pendingButtons, { key = key, texture = texture, onClick = onClick, onTooltip = onTooltip })
    end
end

function addon:CreateToolbarButton(key, texture, onClick, onTooltip)
    local f = CreateFrame("Button", "HAKToolbarBtn_" .. key, addon.toolbarFrame)
    local scale = HerosArmyKnifeDB.settings.toolbar.iconScale or 1
    f:SetSize(btnSize * scale, btnSize * scale)
    -- Ensure we receive both left and right clicks (needed for context menus)
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f.texture = f:CreateTexture(nil, "BACKGROUND")
    f.texture:SetAllPoints()
    f.texture:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    f:SetScript("OnClick", function()
        if onClick then onClick(f) end
    end)
    -- Hover overlay
    if not f.hoverOverlay then
        local hov = f:CreateTexture(nil, "OVERLAY")
        hov:SetAllPoints()
        hov:SetTexture("Interface/Buttons/UI-Common-MouseHilight")
        hov:SetBlendMode("ADD")
        hov:SetAlpha(0.0)
        f.hoverOverlay = hov
    end
    local originalEnter
    originalEnter = function()
        if f.hoverOverlay then
            f.hoverOverlay:SetAlpha(0.55)
        end
        if f.texture then f.texture:SetVertexColor(1,1,1) end
        if f._hakHardBorder then f._hakHardBorder:SetAlpha(1) end
        if onTooltip then
            local anchor = addon:GetTooltipAnchor(f)
            GameTooltip:SetOwner(f, anchor)
            -- Mark tooltip as addon-owned so font pass can target it
            GameTooltip._hakAddonTooltip = true
            local lines = onTooltip(f)
            if type(lines) == "table" then
                GameTooltip:ClearLines()
                local linesExpanded = HAK_ExpandActionLines(lines)
                for i, line in ipairs(linesExpanded) do
                    if i == 1 then
                        -- Title line stays green unless explicitly colored
                        local title = line
                        if title:find("^|cff%x%x%x%x%x%x") then
                            GameTooltip:AddLine(title)
                        else
                            GameTooltip:AddLine(title, 0, 1, 0)
                        end
                    else
                        local colored, r,g,b = HAK_ColorizeTooltipLine(line)
                        GameTooltip:AddLine(colored, r, g, b, true)
                    end
                end
                GameTooltip:Show()
                if addon.ApplyTooltipFont then addon:ApplyTooltipFont(GameTooltip) end
                -- Clear flag afterward to avoid styling unrelated future tooltips
                GameTooltip._hakAddonTooltip = nil
            end
        end
    end
    local originalLeave = function()
        if f.hoverOverlay then f.hoverOverlay:SetAlpha(0) end
        if f.texture then f.texture:SetVertexColor(0.9,0.9,0.9) end
        if f._hakHardBorder and addon.MPlusMonitoringActive then f._hakHardBorder:SetAlpha(0.9) elseif f._hakHardBorder then f._hakHardBorder:SetAlpha(0.5) end
        GameTooltip:Hide()
    end
    f:SetScript("OnEnter", originalEnter)
    f:SetScript("OnLeave", originalLeave)
    -- Slight press visual
    f:SetScript("OnMouseDown", function() if f.texture then f.texture:SetVertexColor(0.75,0.75,0.75) end end)
    f:SetScript("OnMouseUp", function() if f.texture then f.texture:SetVertexColor(1,1,1) end end)
    table.insert(addon.toolbarButtons, f)
    addon:LayoutToolbar()
    return f
end

function addon:LayoutToolbar()
    if not addon.toolbarFrame then return end
    local t = HerosArmyKnifeDB.settings.toolbar
    local orient = t.orientation or "HORIZONTAL_LR"
    local padTop, padBottom = t.padTop or 4, t.padBottom or 4
    local padLeft, padRight = t.padLeft or 4, t.padRight or 4
    local scale = t.iconScale or 1
    local spacing = t.iconSpacing or 6
    local btnPixel = btnSize * scale
    local prev
    local count = #addon.toolbarButtons
    local totalPrimary = 0
    for _, b in ipairs(addon.toolbarButtons) do
        b:ClearAllPoints()
        if orient == "HORIZONTAL_LR" then
            if not prev then b:SetPoint("LEFT", addon.toolbarFrame, "LEFT", padLeft, 0) else b:SetPoint("LEFT", prev, "RIGHT", spacing, 0) end
        elseif orient == "HORIZONTAL_RL" then
            if not prev then b:SetPoint("RIGHT", addon.toolbarFrame, "RIGHT", -padRight, 0) else b:SetPoint("RIGHT", prev, "LEFT", -spacing, 0) end
        elseif orient == "VERTICAL_TB" then
            if not prev then b:SetPoint("TOP", addon.toolbarFrame, "TOP", 0, -padTop) else b:SetPoint("TOP", prev, "BOTTOM", 0, -spacing) end
        elseif orient == "VERTICAL_BT" then
            if not prev then b:SetPoint("BOTTOM", addon.toolbarFrame, "BOTTOM", 0, padBottom) else b:SetPoint("BOTTOM", prev, "TOP", 0, spacing) end
        end
        prev = b
        totalPrimary = totalPrimary + btnPixel + spacing
    end
    local width = (orient:find("HORIZONTAL") and (padLeft + padRight + (count>0 and (btnPixel*count + (count-1)*spacing) or 0)) or (btnPixel + padLeft + padRight))
    local height = (orient:find("VERTICAL") and (padTop + padBottom + (count>0 and (btnPixel*count + (count-1)*spacing) or 0)) or (btnPixel + padTop + padBottom))
    addon.toolbarFrame:SetSize(width, height)
end

-- Decide tooltip anchor based on orientation and screen position
function addon:GetTooltipAnchor(frame)
    local t = HerosArmyKnifeDB.settings.toolbar
    local orient = t.orientation or "HORIZONTAL_LR"
    local uiW, uiH = UIParent:GetWidth(), UIParent:GetHeight()
    local x, y = frame:GetCenter()
    if orient:find("VERTICAL") then
        -- Prefer side away from screen edge
        if x > uiW/2 then
            return "ANCHOR_LEFT" -- frame on right half, show tooltip to its left
        else
            return "ANCHOR_RIGHT"
        end
    else
        -- Horizontal orientations: choose above if in lower half, else below
        if y < uiH/2 then
            return "ANCHOR_TOP"
        else
            return "ANCHOR_BOTTOM"
        end
    end
end

function addon:ClearToolbarButtons()
    for _, b in ipairs(addon.toolbarButtons) do
        b:Hide()
        b:SetParent(nil)
    end
    addon.toolbarButtons = {}
end

function addon:RebuildToolbar()
    if not addon.toolbarFrame then return end
    addon:ClearToolbarButtons()
    for key, info in pairs(addon.moduleRegistry) do
        local enabled = HerosArmyKnifeDB.settings.modulesEnabled[key] ~= false
        if enabled then
            addon:CreateToolbarButton(info.key, info.texture, info.onClick, info.onTooltip)
        end
    end
    addon:LayoutToolbar()
    if addon.ApplyTheme then addon:ApplyTheme() end
    -- Post-build hook: allow modules to refresh visuals (e.g., MythicPlusHelper glow)
        if addon.MythicPlusHelper_ForceRefresh and addon:IsModuleEnabled("MythicPlusHelper") then addon:MythicPlusHelper_ForceRefresh() end
        if addon.MPlus_UpdateMonitoringIndicator and addon:IsModuleEnabled("MythicPlusHelper") then addon.MPlus_UpdateMonitoringIndicator() end
        if _G.RareTracker_UpdateIndicator then _G.RareTracker_UpdateIndicator() end
end

function addon:BuildToolbar()
    if addon.toolbarFrame then return end
    local db = HerosArmyKnifeDB.settings.toolbar
    local f = CreateFrame("Frame", "HerosArmyKnifeToolbar", UIParent, "BackdropTemplate")
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if not HerosArmyKnifeDB.settings.toolbar.locked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        HerosArmyKnifeDB.settings.toolbar.point = point
        HerosArmyKnifeDB.settings.toolbar.x = x
        HerosArmyKnifeDB.settings.toolbar.y = y
    end)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            -- If a child button has focus, let it handle (context menus, etc.) and do not open options
            local focus = GetMouseFocus()
            if focus and focus ~= self then return end
            if InterfaceOptionsFrame then
                InterfaceOptionsFrame_OpenToCategory("HerosArmyKnife")
                InterfaceOptionsFrame_OpenToCategory("HerosArmyKnife")
            end
        end
    end)
    if addon.RegisterThemedFrame then
        addon:RegisterThemedFrame(f, 'toolbar')
    end
    f:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 0)
    addon.toolbarFrame = f
    addon.toolbarFrame.initialized = true
    f:Show()
    if addon._pendingButtons then
        local pending = addon._pendingButtons
        addon._pendingButtons = nil
        for _, info in ipairs(pending) do
            local enabled = HerosArmyKnifeDB.settings.modulesEnabled[info.key] ~= false
            if enabled then
                addon:CreateToolbarButton(info.key, info.texture, info.onClick, info.onTooltip)
            end
        end
    end
    addon:LayoutToolbar()
end
