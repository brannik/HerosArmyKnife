local addonName, addon = ...

local DEFAULT_HEADER_HEIGHT = 36
local DEFAULT_PADDING = { left = 16, right = 16, top = nil, bottom = 18 }

local function applyDragHandlers(frame, header, draggable)
    if draggable == false then
        header:EnableMouse(false)
        frame:SetMovable(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        return
    end
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        local handler = frame:GetScript("OnDragStart")
        if handler then handler(frame) end
    end)
    header:SetScript("OnDragStop", function()
        local handler = frame:GetScript("OnDragStop")
        if handler then handler(frame) end
    end)
end

local function resolvePadding(headerHeight, opts)
    local pad = {}
    local source = opts.bodyPadding or DEFAULT_PADDING
    pad.left = source.left or DEFAULT_PADDING.left
    pad.right = source.right or DEFAULT_PADDING.right
    pad.bottom = source.bottom or DEFAULT_PADDING.bottom
    if source.top ~= nil then
        pad.top = source.top
    else
        pad.top = (opts.headerHeight or headerHeight) + (opts.bodyTopSpacing or 12)
    end
    return pad
end

function addon:ApplyStandardPanelChrome(frame, title, opts)
    if not frame then return nil end
    opts = opts or {}
    local headerHeight = opts.headerHeight or DEFAULT_HEADER_HEIGHT

    frame._hakNoHeader = true
    if frame._hakHeaderTex then frame._hakHeaderTex:Hide() end
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end

    local header = frame._hakChromeHeader
    if not header then
        header = CreateFrame("Frame", nil, frame)
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        header:SetHeight(headerHeight)
        header:SetFrameLevel(frame:GetFrameLevel() + 1)

        local bg = header:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.82)
        header.bg = bg

        local gloss = header:CreateTexture(nil, "ARTWORK")
        gloss:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
        gloss:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
        gloss:SetColorTexture(0.18, 0.18, 0.18, 0.35)
        header.gloss = gloss

        frame._hakChromeHeader = header
    else
        header:SetHeight(headerHeight)
    end

    applyDragHandlers(frame, header, opts.draggable)

    local titleFS = frame.titleText
    if not titleFS then
        titleFS = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        frame.titleText = titleFS
    end
    titleFS:ClearAllPoints()
    titleFS:SetPoint("CENTER", header, "CENTER", opts.titleOffsetX or 0, opts.titleOffsetY or 0)
    titleFS:SetJustifyH("CENTER")
    if title then titleFS:SetText(title) end

    if opts.hideClose then
        if frame.closeButton then frame.closeButton:Hide() end
    else
        if not frame.closeButton then
            local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
            frame.closeButton = close
        end
        frame.closeButton:ClearAllPoints()
        frame.closeButton:SetPoint("TOPRIGHT", header, "TOPRIGHT", -4, -4)
        frame.closeButton:SetFrameLevel((header:GetFrameLevel() or frame:GetFrameLevel()) + 2)
        frame.closeButton:SetShown(true)
        if opts.onClose then
            frame.closeButton:SetScript("OnClick", opts.onClose)
        else
            frame.closeButton:SetScript("OnClick", function() frame:Hide() end)
        end
    end

    if opts.createBody == false then return nil end

    local padding = resolvePadding(headerHeight, opts)
    local body = frame._hakBody
    if not body then
        body = CreateFrame("Frame", nil, frame)
        frame._hakBody = body
    end
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", padding.left, -padding.top)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -padding.right, padding.bottom)

    if opts.dragBody and body.RegisterForDrag then
        body:EnableMouse(true)
        body:RegisterForDrag("LeftButton")
        body:SetScript("OnDragStart", function()
            local handler = frame:GetScript("OnDragStart")
            if handler then handler(frame) end
        end)
        body:SetScript("OnDragStop", function()
            local handler = frame:GetScript("OnDragStop")
            if handler then handler(frame) end
        end)
    end
    return body
end

function addon:CreatePanelScrollBox(parent, opts)
    if not parent then return nil end
    opts = opts or {}
    local scroll = CreateFrame("ScrollFrame", opts.name or nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", opts.left or 0, -(opts.top or 0))
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(opts.right or 0), opts.bottom or 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(opts.width or 10, opts.height or 10)
    scroll:SetScrollChild(content)
    if opts.onSizeChanged then
        scroll:SetScript("OnSizeChanged", function(_, width, height)
            opts.onSizeChanged(width, height, content)
        end)
    end
    return scroll, content
end

function addon:StyleButton(btn, opts)
    if not btn or btn._hakStyled then return btn end
    opts = opts or {}
    btn._hakStyled = true
    btn:SetMotionScriptsWhileDisabled(true)
    if opts.width then btn:SetWidth(opts.width) end
    if opts.height then btn:SetHeight(opts.height) end
    if btn:GetNormalTexture() then btn:GetNormalTexture():SetVertexColor(1,1,1) end
    if btn:GetHighlightTexture() then btn:GetHighlightTexture():SetAlpha(0.25) end
    btn:SetNormalFontObject(opts.normalFont or "GameFontNormal")
    btn:SetHighlightFontObject(opts.highlightFont or "GameFontHighlight")
    btn:SetDisabledFontObject(opts.disabledFont or "GameFontDisable")
    return btn
end

function addon:StyleCheckbox(checkButton, opts)
    if not checkButton or checkButton._hakStyled then return checkButton end
    opts = opts or {}
    local text = checkButton.Text or (checkButton.GetName and _G[checkButton:GetName() .. "Text"]) or nil
    if text then
        text:SetFontObject(opts.font or "GameFontHighlight")
        text:SetSpacing(1)
    end
    checkButton._hakStyled = true
    return checkButton
end

function addon:CreateDivider(parent, offsetY, opts)
    if not parent then return nil end
    opts = opts or {}
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(opts.r or 1, opts.g or 1, opts.b or 1, opts.a or 0.08)
    line:SetHeight(opts.thickness or 1)
    if opts.insetLeft or opts.insetRight then
        line:SetPoint("LEFT", parent, "LEFT", opts.insetLeft or 0, offsetY or 0)
        line:SetPoint("RIGHT", parent, "RIGHT", -(opts.insetRight or 0), offsetY or 0)
    else
        line:SetPoint("LEFT", parent, "LEFT", 0, offsetY or 0)
        line:SetPoint("RIGHT", parent, "RIGHT", 0, offsetY or 0)
    end
    return line
end
