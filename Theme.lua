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
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0,0,0,0.75} },
            panel    = { file = "Interface/DialogFrame/UI-DialogBox-Background", color = {0.09,0.09,0.09,0.85} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0.05,0.05,0.05,0.80} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Background", color = {0,0,0,0.70} },
        },
        borders = {
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.8,0.8,0.8,0.9} },
            panel    = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.75,0.75,0.75,0.9} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.7,0.7,0.7,0.9} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.8,0.8,0.8,0.9} },
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
        },
        borders = {
            toolbar  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.15,0.45,0.85,0.9} },
            panel    = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.18,0.5,0.9,0.85} },
            subpanel = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.14,0.42,0.8,0.85} },
            default  = { file = "Interface/Tooltips/UI-Tooltip-Border", color = {0.2,0.6,1,0.7} },
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
    addon._themeInitialized = true
    if not addon.themes[HerosArmyKnifeDB.settings.themeName] then
        HerosArmyKnifeDB.settings.themeName = 'Default'
    end
    addon:ApplyTheme()
end
