local addonName, addon = ...

addon.themes = addon.themes or {}
addon._themedFrames = addon._themedFrames or {}

function addon:RegisterTheme(name, data)
    if not name or type(data) ~= 'table' then return end
    addon.themes[name] = data
end

function addon:ApplyBackdrop(frame, variant)
    if not frame then return end
    if not HerosArmyKnifeDB or not HerosArmyKnifeDB.settings then return end
    local theme = addon.themes[HerosArmyKnifeDB.settings.themeName]
    if not theme then return end
    local bg = theme.backgrounds and theme.backgrounds[variant or 'default'] or theme.background
    local border = theme.borders and theme.borders[variant or 'default'] or theme.border
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({ bgFile = bg.file or "Interface/Tooltips/UI-Tooltip-Background", edgeFile = border.file or "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    local c = bg.color or {0,0,0,0.6}
    frame:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
    local bc = border.color or {1,1,1,0.4}
    frame:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1)
    -- Optional Blizzard-style header decoration (skip if noHeader flag set)
    if frame._hakNoHeader or frame.noHeader then
        if frame._hakHeaderTex then frame._hakHeaderTex:Hide(); frame._hakHeaderTex = nil end
    elseif variant == 'panel' and theme.headers and not frame._hakHeaderTex then
        local hInfo = theme.headers.panel
        if hInfo then
            local tex = frame:CreateTexture(nil, 'ARTWORK')
            tex:SetTexture(hInfo.texture or 'Interface/DialogFrame/UI-DialogBox-Header')
            tex:SetSize(hInfo.width or 256, hInfo.height or 64)
            tex:SetPoint('TOP', frame, 'TOP', 0, (hInfo.offsetY or 12))
            frame._hakHeaderTex = tex
        end
    end
    -- Font styling: apply title font if provided and discover large title fontstrings
    if theme.fonts and theme.fonts.title then
        for _, region in ipairs({frame:GetRegions()}) do
            if region:IsObjectType('FontString') then
                local fs = region
                local text = fs:GetText()
                if text and (text:find('HerosArmyKnife') or text:find('Cache Opener')) then
                    fs:SetFontObject(theme.fonts.title)
                end
            end
        end
    end
    -- Decorative overlays for themes that define them
    if theme.decorations and not frame._hakDecorApplied then
        if theme.decorations.gradient then
            local gTex = frame:CreateTexture(nil, 'BORDER')
            gTex:SetTexture(theme.decorations.gradient.texture or 'Interface/COMMON/StreamHighlight')
            gTex:SetPoint('TOPLEFT', frame, 'TOPLEFT', 4, -4)
            gTex:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -4, 4)
            gTex:SetVertexColor(unpack(theme.decorations.gradient.color or {0.15,0.25,0.35,0.25}))
            frame._hakDecoGradient = gTex
        end
        if theme.decorations.corners then
            local cornerInfo = theme.decorations.corners
            local function MakeCorner(relPoint, x, y, rot)
                local t = frame:CreateTexture(nil, 'ARTWORK')
                t:SetTexture(cornerInfo.texture or 'Interface/Buttons/UI-Quickslot-Depress')
                t:SetSize(cornerInfo.size or 24, cornerInfo.size or 24)
                t:SetPoint(relPoint, frame, relPoint, x, y)
                t:SetVertexColor(unpack(cornerInfo.color or {0.25,0.55,0.9,0.35}))
                if rot and t.SetRotation then t:SetRotation(rot) end
                return t
            end
            frame._hakCornerTL = MakeCorner('TOPLEFT', 4, -4, 0)
            frame._hakCornerTR = MakeCorner('TOPRIGHT', -4, -4, math.pi/2)
            frame._hakCornerBL = MakeCorner('BOTTOMLEFT', 4, 4, -math.pi/2)
            frame._hakCornerBR = MakeCorner('BOTTOMRIGHT', -4, 4, math.pi)
        end
        frame._hakDecorApplied = true
    end
end

function addon:RegisterThemedFrame(frame, variant)
    if not frame then return end
    table.insert(addon._themedFrames, { frame = frame, variant = variant })
    addon:ApplyBackdrop(frame, variant)
end

-- Helper to create a themed frame consistently. Usage:
-- local f = addon:CreateThemedFrame(parent, "MyFrameName", width, height, "panel")
function addon:CreateThemedFrame(parent, name, width, height, variant)
    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    if width and height then f:SetSize(width, height) end
    addon:RegisterThemedFrame(f, variant)
    return f
end

function addon:ApplyTheme()
    if not HerosArmyKnifeDB or not HerosArmyKnifeDB.settings then return end
    for _, info in ipairs(addon._themedFrames) do
        addon:ApplyBackdrop(info.frame, info.variant)
    end
    -- Reapply toolbar buttons texture coloring if theme offers tint
    local theme = addon.themes[HerosArmyKnifeDB.settings.themeName]
    if theme and theme.iconTint then
        for _, btn in ipairs(addon.toolbarButtons or {}) do
            local r,g,b,a = unpack(theme.iconTint)
            btn.texture:SetVertexColor(r,g,b,a or 1)
        end
    else
        for _, btn in ipairs(addon.toolbarButtons or {}) do
            btn.texture:SetVertexColor(1,1,1,1)
        end
    end
    if addon.ApplyTooltipTheme then addon:ApplyTooltipTheme() end
end

function addon:SetTheme(name)
    if addon.themes[name] then
        HerosArmyKnifeDB.settings.themeName = name
        addon:ApplyTheme()
    end
end

function addon:InitTheme()
    if addon._themeInitialized then return end
    -- Register sample themes
    -- "Blizzlike" Default theme: closer to stock frame & tooltip styling
    addon:RegisterTheme('Default', {
        backgrounds = {
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.06,0.06,0.06,0.80} },
            panel    = { file = "Interface/DialogFrame/UI-DialogBox-Background", color = {0.10,0.10,0.10,0.88} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.07,0.07,0.07,0.82} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.06,0.06,0.06,0.78} },
            tooltip  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.05,0.05,0.05,0.92} },
        },
        borders = {
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.85,0.85,0.85,0.95} },
            panel    = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.85,0.85,0.85,0.95} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.82,0.82,0.82,0.95} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.85,0.85,0.85,0.95} },
            tooltip  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.85,0.85,0.85,0.95} },
        },
        iconTint = {1,1,1,1},
        headers = {
            panel = { texture = 'Interface/DialogFrame/UI-DialogBox-Header', width = 256, height = 64, offsetY = 12 },
        },
        fonts = {
            title = GameFontNormalLarge,
        },
    })
    addon:RegisterTheme('Dark', {
        backgrounds = {
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.05,0.05,0.05,0.92} },
            panel    = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.04,0.04,0.04,0.94} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.04,0.04,0.04,0.90} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.06,0.06,0.06,0.88} },
            tooltip  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.03,0.03,0.03,0.96} },
        },
        borders = {
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.15,0.45,0.85,0.9} },
            panel    = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.18,0.5,0.9,0.85} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.14,0.42,0.8,0.85} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.2,0.6,1,0.7} },
            tooltip  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.20,0.55,1.0,0.95} },
        },
        iconTint = {0.85,0.9,1,1},
        headers = {
            panel = { texture = 'Interface/DialogFrame/UI-DialogBox-Header', width = 256, height = 64, offsetY = 12 },
        },
        fonts = {
            title = GameFontHighlightOutline,
        },
        decorations = {
            gradient = { texture = 'Interface/Buttons/UI-SliderBar-Background', color = {0.08,0.12,0.18,0.35} },
            corners = { texture = 'Interface/Buttons/UI-Quickslot-Depress', size = 20, color = {0.25,0.55,0.9,0.40} },
        },
    })
    addon:RegisterTheme('Light', {
        backgrounds = {
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.90,0.92,0.98,0.95} },
            panel    = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.95,0.96,1.00,0.96} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.92,0.94,0.99,0.94} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.94,0.96,1.00,0.94} },
            tooltip  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.97,0.98,1.00,0.98} },
        },
        borders = {
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.75,0.78,0.85,1.0} },
            panel    = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.72,0.76,0.84,0.98} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.70,0.74,0.82,0.96} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.75,0.78,0.85,0.98} },
            tooltip  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.76,0.80,0.88,1.0} },
        },
        iconTint = {1,1,1,1},
        headers = {
            panel = { texture = 'Interface/DialogFrame/UI-DialogBox-Header', width = 256, height = 64, offsetY = 12 },
        },
        fonts = {
            title = GameFontNormalLarge,
        },
        decorations = {
            gradient = { texture = 'Interface/Buttons/UI-SliderBar-Background', color = {0.75,0.80,0.95,0.30} },
            corners = { texture = 'Interface/Buttons/UI-Quickslot-Depress', size = 18, color = {0.65,0.72,0.90,0.30} },
        },
    })
    addon:RegisterTheme('Stone', {
        backgrounds = {
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.16,0.17,0.19,0.95} },
            panel    = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.18,0.19,0.22,0.95} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.15,0.16,0.18,0.92} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.17,0.18,0.20,0.93} },
            tooltip  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.14,0.15,0.17,0.96} },
        },
        borders = {
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.55,0.58,0.62,0.95} },
            panel    = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.60,0.62,0.66,0.95} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.50,0.54,0.58,0.90} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.58,0.60,0.64,0.92} },
            tooltip  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.62,0.64,0.68,0.96} },
        },
        iconTint = {0.92,0.92,0.95,1},
        headers = {
            panel = { texture = 'Interface/DialogFrame/UI-DialogBox-Header', width = 256, height = 64, offsetY = 12 },
        },
        fonts = {
            title = GameFontNormalLarge,
        },
        decorations = {
            gradient = { texture = 'Interface/Buttons/UI-SliderBar-Background', color = {0.22,0.24,0.28,0.35} },
            corners = { texture = 'Interface/Buttons/UI-Quickslot-Depress', size = 20, color = {0.60,0.62,0.66,0.35} },
        },
    })
    addon:RegisterTheme('Parchment', {
        backgrounds = {
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.95,0.91,0.80,0.95} },
            panel    = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.96,0.92,0.82,0.96} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.94,0.90,0.78,0.94} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.96,0.92,0.82,0.94} },
            tooltip  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.97,0.93,0.83,0.98} },
        },
        borders = {
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.55,0.42,0.26,0.95} },
            panel    = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.60,0.46,0.28,0.95} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.52,0.40,0.24,0.92} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.58,0.45,0.27,0.94} },
            tooltip  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.62,0.48,0.30,0.98} },
        },
        iconTint = {1,0.98,0.95,1},
        headers = {
            panel = { texture = 'Interface/DialogFrame/UI-DialogBox-Header', width = 256, height = 64, offsetY = 12 },
        },
        fonts = {
            title = GameFontNormalLarge,
        },
        decorations = {
            gradient = { texture = 'Interface/Buttons/UI-SliderBar-Background', color = {0.70,0.58,0.35,0.25} },
            corners = { texture = 'Interface/Buttons/UI-Quickslot-Depress', size = 18, color = {0.65,0.52,0.32,0.35} },
        },
    })
    addon._themeInitialized = true
    if not addon.themes[HerosArmyKnifeDB.settings.themeName] then
        HerosArmyKnifeDB.settings.themeName = 'Default'
    end
    addon:ApplyTheme()
end

-- Tooltip theming: applies theme's tooltip background/border to common tooltips
function addon:ApplyTooltipTheme()
    if not HerosArmyKnifeDB or not HerosArmyKnifeDB.settings then return end
    local theme = addon.themes[HerosArmyKnifeDB.settings.themeName]
    if not theme then return end
    local bg = (theme.backgrounds and theme.backgrounds.tooltip) or (theme.backgrounds and theme.backgrounds.default) or theme.background
    local border = (theme.borders and theme.borders.tooltip) or (theme.borders and theme.borders.default) or theme.border
    local tooltips = {
        _G.GameTooltip,
        _G.ItemRefTooltip,
        _G.ShoppingTooltip1,
        _G.ShoppingTooltip2,
        _G.ShoppingTooltip3,
    }
    local function SkinTip(tt)
        if not tt or not tt.SetBackdrop then return end
        tt:SetBackdrop({
            bgFile = (bg and bg.file) or "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = (border and border.file) or "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        local c = (bg and bg.color) or {0,0,0,0.8}
        tt:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
        local bc = (border and border.color) or {1,1,1,0.9}
        tt:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1)
    end
    for _, tt in ipairs(tooltips) do
        if tt and not tt._hakTooltipHooked then
            tt:HookScript("OnShow", function(self) SkinTip(self) end)
            tt._hakTooltipHooked = true
        end
        if tt and tt:IsShown() then SkinTip(tt) end
    end
end
