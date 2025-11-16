local addonName, addon = ...

local panel = addon.CreateThemedFrame and addon:CreateThemedFrame(nil, "HerosArmyKnifeOptionsPanel", 640, 520, 'panel') or CreateFrame("Frame", "HerosArmyKnifeOptionsPanel")
panel._hakNoHeader = true
if not panel:GetWidth() or panel:GetWidth()==0 then panel:SetSize(640,520) end
panel.name = "HerosArmyKnife"
InterfaceOptions_AddCategory(panel)
addon.optionsPanel = panel

-- Generic helper: wrap an options panel in a scroll frame so large content is accessible.
function addon:MakePanelScrollable(p)
	if not p or p._hakScrollApplied then return end
	local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -28, 4)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetPoint("TOPLEFT")
	content:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -16, 0)
	content:SetSize(scroll:GetWidth() - 16, 400) -- initial height; will be resized dynamically
	scroll:SetScrollChild(content)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local step = 30
		local new = self:GetVerticalScroll() - (delta * step)
		if new < 0 then new = 0 end
		local max = self:GetVerticalScrollRange()
		if new > max then new = max end
		self:SetVerticalScroll(new)
	end)
	-- Reparent existing children except scroll itself
	local kids = { p:GetChildren() }
	for _, k in ipairs(kids) do
		if k ~= scroll then k:SetParent(content) end
	end
	-- Adjust existing fontstrings (regions) to content if needed
	local regions = { p:GetRegions() }
	for _, r in ipairs(regions) do
		if r and r.GetObjectType and r:GetObjectType()=="FontString" then r:SetParent(content) end
	end
	p._hakScrollApplied = true
	p._hakScrollContent = content
	p._hakScrollFrame = scroll
	-- Dynamic height calculation function
	p._hakRefreshScrollHeight = function()
		if not content or not scroll then return end
		local cTop = content:GetTop() or 0
		local minBottom = cTop -- will search for lowest bottom
		local widest = 0
		local function consider(region)
			if region and region:IsShown() then
				local b = region:GetBottom()
				local r = region:GetRight()
				if b and b < minBottom then minBottom = b end
				if r and r > widest then widest = r end
			end
		end
		for _, child in ipairs({ content:GetChildren() }) do consider(child) end
		for _, region in ipairs({ content:GetRegions() }) do consider(region) end
		-- If no children adjusted minBottom (still == cTop), force a baseline height
		local neededHeight
		if minBottom == cTop then
			neededHeight = 400
		else
			neededHeight = (cTop - minBottom) + 30
		end
		local viewportH = scroll:GetHeight() or 300
		if neededHeight < viewportH then neededHeight = viewportH + 20 end
		content:SetHeight(neededHeight)
		-- Force scroll frame to update its child rect so vertical range reflects new height
		if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
		-- Optional: widen content if children extended beyond current width
		local cLeft = content:GetLeft() or 0
		if widest > 0 then
			local childWidth = widest - cLeft + 16
			if childWidth > content:GetWidth() then content:SetWidth(childWidth) end
		end
	end
	-- Refresh after a short delay to allow late layout (dropdown init etc.)
	local refresher = CreateFrame("Frame", nil, content)
	refresher.t = 0
	refresher:SetScript("OnUpdate", function(self, e)
		self.t = self.t + e
		if self.t > 0.25 then
			if p._hakRefreshScrollHeight then p._hakRefreshScrollHeight() end
			self:SetScript("OnUpdate", nil)
		end
	end)
end

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -15)
title:SetText("HerosArmyKnife")

local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
desc:SetJustifyH("LEFT")
desc:SetWidth(600)
desc:SetText("Movable toolbar addon. Drag toolbar frame; right-click frame or use /hak options for settings. Icons represent modules; About icon opens this panel.")

local generalHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
-- Ensure settings table exists early to prevent nil errors before ADDON_LOADED
local function safeSettings()
	if not HerosArmyKnifeDB then HerosArmyKnifeDB = {} end
	local db = HerosArmyKnifeDB
	db.settings = db.settings or {}
	local s = db.settings
	s.toolbar = s.toolbar or {}
	local t = s.toolbar
	if t.orientation == nil then t.orientation = "HORIZONTAL_LR" end
	if t.iconScale == nil then t.iconScale = 1 end
	if t.iconSpacing == nil then t.iconSpacing = 6 end
	if t.padTop == nil then t.padTop = 4 end
	if t.padBottom == nil then t.padBottom = 4 end
	if t.padLeft == nil then t.padLeft = 4 end
	if t.padRight == nil then t.padRight = 4 end
	if t.locked == nil then t.locked = false end
	s.themeName = s.themeName or "Default"
	-- Global addon font size (Morpheus) default
	s.fontSize = s.fontSize or 14
	s.modulesEnabled = s.modulesEnabled or {}
	s.moduleSettings = s.moduleSettings or {}
	-- Notifications basic defaults (full color table populated in Core.lua)
	s.notifications = s.notifications or {}
	local n = s.notifications
	n.mode = n.mode or "CHAT"
end
safeSettings()
generalHeader:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
generalHeader:SetText("General Settings")

-- Orientation dropdown
local orientLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
orientLabel:SetPoint("TOPLEFT", generalHeader, "BOTTOMLEFT", 0, -8)
orientLabel:SetText("Growth Orientation")

-- Theme dropdown
local themeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
themeLabel:SetPoint("TOPLEFT", orientLabel, "BOTTOMLEFT", 0, -58)
themeLabel:SetText("Theme")

local themeDrop = CreateFrame("Frame", "HAK_ThemeDropdown", panel, "UIDropDownMenuTemplate")
themeDrop:SetPoint("TOPLEFT", themeLabel, "BOTTOMLEFT", -16, -4)

local function Theme_OnClick(self)
	addon:SetTheme(self.value)
	UIDropDownMenu_SetSelectedValue(themeDrop, self.value)
	UIDropDownMenu_SetText(themeDrop, self.value)
end

local function InitThemeDropdown()
	safeSettings()
	UIDropDownMenu_Initialize(themeDrop, function(self, level)
		for name, data in pairs(addon.themes or {}) do
			local item = UIDropDownMenu_CreateInfo()
			item.text = name
			item.value = name
			item.func = Theme_OnClick
			item.checked = (name == HerosArmyKnifeDB.settings.themeName)
			UIDropDownMenu_AddButton(item)
		end
	end)
	UIDropDownMenu_SetSelectedValue(themeDrop, HerosArmyKnifeDB.settings.themeName)
	UIDropDownMenu_SetText(themeDrop, HerosArmyKnifeDB.settings.themeName)
end
themeDrop:HookScript("OnShow", function() if not themeDrop._initialized then InitThemeDropdown(); themeDrop._initialized = true end end)

local orientDrop = CreateFrame("Frame", "HAK_OrientDropdown", panel, "UIDropDownMenuTemplate")
orientDrop:SetPoint("TOPLEFT", orientLabel, "BOTTOMLEFT", -16, -4)

local orientations = {
	{ value = "HORIZONTAL_LR", text = "Horizontal L->R" },
	{ value = "HORIZONTAL_RL", text = "Horizontal R->L" },
	{ value = "VERTICAL_TB", text = "Vertical Top->Bottom" },
	{ value = "VERTICAL_BT", text = "Vertical Bottom->Top" },
}

local function Orient_OnClick(self)
	HerosArmyKnifeDB.settings.toolbar.orientation = self.value
	UIDropDownMenu_SetSelectedValue(orientDrop, self.value)
	addon:RebuildToolbar()
end

local function InitOrientDropdown()
	safeSettings()
	UIDropDownMenu_Initialize(orientDrop, function(self, level)
		for _, info in ipairs(orientations) do
			local item = UIDropDownMenu_CreateInfo()
			item.text = info.text
			item.value = info.value
			item.func = Orient_OnClick
			item.checked = (info.value == HerosArmyKnifeDB.settings.toolbar.orientation)
			UIDropDownMenu_AddButton(item)
		end
	end)
	UIDropDownMenu_SetSelectedValue(orientDrop, HerosArmyKnifeDB.settings.toolbar.orientation)
end
orientDrop:HookScript("OnShow", function() if not orientDrop._initialized then InitOrientDropdown(); orientDrop._initialized = true end end)

-- Scale slider
local scaleSlider = CreateFrame("Slider", "HAK_ScaleSlider", panel, "OptionsSliderTemplate")
scaleSlider:SetPoint("TOPLEFT", themeDrop, "BOTTOMLEFT", 16, -24)
scaleSlider:SetMinMaxValues(0.5, 2.0)
scaleSlider:SetValueStep(0.05)
if scaleSlider.SetObeyStepOnDrag then scaleSlider:SetObeyStepOnDrag(true) end
_G[scaleSlider:GetName() .. 'Low']:SetText('0.5')
_G[scaleSlider:GetName() .. 'High']:SetText('2.0')
_G[scaleSlider:GetName() .. 'Text']:SetText('Icon Scale')
scaleSlider:SetScript("OnValueChanged", function(self, value)
	HerosArmyKnifeDB.settings.toolbar.iconScale = value
	addon:RebuildToolbar()
	if scaleSlider.valueText then scaleSlider.valueText:SetText(string.format("%.2f", value)) end
end)
-- Value display for scale slider
scaleSlider.valueText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
scaleSlider.valueText:SetPoint("LEFT", scaleSlider, "RIGHT", 18, 0)
do
    local f, size, flags = GameFontNormal:GetFont()
    scaleSlider.valueText:SetFont(f, (size or 13)+1, flags)
    scaleSlider.valueText:SetTextColor(1, 0.95, 0.2)
end
scaleSlider.valueText:SetText(string.format("%.2f", HerosArmyKnifeDB.settings.toolbar.iconScale))

-- Icon spacing slider
local spacingSlider = CreateFrame("Slider", "HAK_SpacingSlider", panel, "OptionsSliderTemplate")
spacingSlider:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -36)
spacingSlider:SetMinMaxValues(0, 32)
spacingSlider:SetValueStep(1)
if spacingSlider.SetObeyStepOnDrag then spacingSlider:SetObeyStepOnDrag(true) end
_G[spacingSlider:GetName() .. 'Low']:SetText('0')
_G[spacingSlider:GetName() .. 'High']:SetText('32')
_G[spacingSlider:GetName() .. 'Text']:SetText('Icon Spacing')
spacingSlider:SetScript("OnValueChanged", function(self, value)
	HerosArmyKnifeDB.settings.toolbar.iconSpacing = value
	addon:RebuildToolbar()
	if spacingSlider.valueText then spacingSlider.valueText:SetText(string.format("%d", value)) end
end)
-- Value display for spacing slider
spacingSlider.valueText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
spacingSlider.valueText:SetPoint("LEFT", spacingSlider, "RIGHT", 18, 0)
do
    local f, size, flags = GameFontNormal:GetFont()
    spacingSlider.valueText:SetFont(f, (size or 13)+1, flags)
    spacingSlider.valueText:SetTextColor(1, 0.95, 0.2)
end
spacingSlider.valueText:SetText(string.format("%d", HerosArmyKnifeDB.settings.toolbar.iconSpacing))

-- Font size slider (global Morpheus size)
local fontSizeSlider = CreateFrame("Slider", "HAK_FontSizeSlider", panel, "OptionsSliderTemplate")
fontSizeSlider:SetPoint("TOPLEFT", spacingSlider, "BOTTOMLEFT", 0, -40)
fontSizeSlider:SetMinMaxValues(10, 24)
fontSizeSlider:SetValueStep(1)
if fontSizeSlider.SetObeyStepOnDrag then fontSizeSlider:SetObeyStepOnDrag(true) end
_G[fontSizeSlider:GetName() .. 'Low']:SetText('10')
_G[fontSizeSlider:GetName() .. 'High']:SetText('24')
_G[fontSizeSlider:GetName() .. 'Text']:SetText('Font Size')
fontSizeSlider:SetScript("OnValueChanged", function(self, value)
	HerosArmyKnifeDB.settings.fontSize = value
	if fontSizeSlider.valueText then fontSizeSlider.valueText:SetText(string.format("%d", value)) end
	if addon.ForceGlobalFont then addon:ForceGlobalFont() end
end)
fontSizeSlider.valueText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fontSizeSlider.valueText:SetPoint("LEFT", fontSizeSlider, "RIGHT", 18, 0)
do
	local f, size, flags = GameFontNormal:GetFont()
	fontSizeSlider.valueText:SetFont(f, (size or 13)+1, flags)
	fontSizeSlider.valueText:SetTextColor(1, 0.95, 0.2)
end
fontSizeSlider.valueText:SetText(string.format("%d", HerosArmyKnifeDB.settings.fontSize))

-- Padding sliders
local function CreatePadSlider(name, label, anchor, x, y)
	local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
	s:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
	s:SetMinMaxValues(0, 32)
	s:SetValueStep(1)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	_G[name .. 'Low']:SetText('0')
	_G[name .. 'High']:SetText('32')
	_G[name .. 'Text']:SetText(label)
	s:SetScript("OnValueChanged", function(self, value)
		local k = self.padKey
		HerosArmyKnifeDB.settings.toolbar[k] = value
		addon:RebuildToolbar()
		if self.valueText then self.valueText:SetText(string.format("%d", value)) end
	end)
	-- Add value text display
	s.valueText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	s.valueText:SetPoint("LEFT", s, "RIGHT", 18, 0)
	do
		local f, size, flags = GameFontNormal:GetFont()
		s.valueText:SetFont(f, (size or 13)+1, flags)
		s.valueText:SetTextColor(1, 0.95, 0.2)
	end
	s.valueText:SetText("0")
	return s
end

-- Reflow padding sliders into 2 columns to reduce vertical space
local padTop = CreatePadSlider("HAK_PadTop", "Pad Top", fontSizeSlider, 0, -28); padTop.padKey = 'padTop'
-- Vertical stack: Left, Bottom, Right beneath Top
local padLeft = CreatePadSlider("HAK_PadLeft", "Pad Left", padTop, 0, -24); padLeft.padKey = 'padLeft'
local padBottom = CreatePadSlider("HAK_PadBottom", "Pad Bottom", padLeft, 0, -24); padBottom.padKey = 'padBottom'
local padRight = CreatePadSlider("HAK_PadRight", "Pad Right", padBottom, 0, -24); padRight.padKey = 'padRight'

-- Lock checkbox
local RIGHT_COL_X = 300 -- shift right column a bit left to reclaim space

-- Font dropdown (addon-only font for HAK windows/tooltips) placed above Notifications
local fontLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fontLabel:SetPoint("TOPLEFT", themeDrop, "TOPLEFT", RIGHT_COL_X, -2)
fontLabel:SetText("Font")

local fontDrop = CreateFrame("Frame", "HAK_FontDropdown", panel, "UIDropDownMenuTemplate")
fontDrop:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -16, -4)

local function Font_OnClick(self)
	HerosArmyKnifeDB.settings.fontName = self.value
	UIDropDownMenu_SetSelectedValue(fontDrop, self.value)
	UIDropDownMenu_SetText(fontDrop, self.value)
	if addon.ApplyTheme then addon:ApplyTheme() end -- reapply fonts to addon windows
	if addon.Notify then addon:Notify("Font set to "..tostring(self.value), 'success') end
end

local function InitFontDropdown()
	safeSettings()
	UIDropDownMenu_Initialize(fontDrop, function(self, level)
		for name, info in pairs(addon.fontsAvailable or {}) do
			local item = UIDropDownMenu_CreateInfo()
			item.text = name
			item.value = name
			item.func = Font_OnClick
			item.checked = (name == HerosArmyKnifeDB.settings.fontName)
			UIDropDownMenu_AddButton(item)
		end
	end)
	UIDropDownMenu_SetSelectedValue(fontDrop, HerosArmyKnifeDB.settings.fontName)
	UIDropDownMenu_SetText(fontDrop, HerosArmyKnifeDB.settings.fontName)
end
fontDrop:HookScript("OnShow", function() if not fontDrop._initialized then InitFontDropdown(); fontDrop._initialized = true end end)

-- Notifications section
local notifyHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
-- Place notifications below the font dropdown in the right column
notifyHeader:SetPoint("TOPLEFT", fontDrop, "BOTTOMLEFT", 16, -12)
notifyHeader:SetText("Notifications")

local notifyModeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
notifyModeLabel:SetPoint("TOPLEFT", notifyHeader, "BOTTOMLEFT", 0, -8)
notifyModeLabel:SetText("Display Mode")

local notifyDrop = CreateFrame("Frame", "HAK_NotifyDropdown", panel, "UIDropDownMenuTemplate")
notifyDrop:SetPoint("TOPLEFT", notifyModeLabel, "BOTTOMLEFT", -16, -4)

local function Notify_OnClick(self)
	HerosArmyKnifeDB.settings.notifications.mode = self.value
	UIDropDownMenu_SetSelectedValue(notifyDrop, self.value)
	UIDropDownMenu_SetText(notifyDrop, self.value)
	if addon.Notify then addon:Notify("Notification mode set to "..self.value, 'success') end
end

local function InitNotifyDropdown()
	safeSettings()
	local modes = { {value='CHAT', text='Chat Frame'}, {value='CENTER', text='Center Screen'} }
	UIDropDownMenu_Initialize(notifyDrop, function(self, level)
		for _, m in ipairs(modes) do
			local item = UIDropDownMenu_CreateInfo()
			item.text = m.text
			item.value = m.value
			item.func = Notify_OnClick
			item.checked = (HerosArmyKnifeDB.settings.notifications.mode == m.value)
			UIDropDownMenu_AddButton(item)
		end
	end)
	UIDropDownMenu_SetSelectedValue(notifyDrop, HerosArmyKnifeDB.settings.notifications.mode)
	UIDropDownMenu_SetText(notifyDrop, HerosArmyKnifeDB.settings.notifications.mode)
end
notifyDrop:HookScript("OnShow", function() if not notifyDrop._initialized then InitNotifyDropdown(); notifyDrop._initialized = true end end)

-- Test buttons for severity preview
local testBtnInfo = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
testBtnInfo:SetSize(110,20)
testBtnInfo:SetPoint("TOPLEFT", notifyDrop, "BOTTOMLEFT", 16, -10)
testBtnInfo:SetText("Test Info")
testBtnInfo:SetScript("OnClick", function() if addon.Notify then addon:Notify("Info notification", 'info') end end)
local testBtnWarn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
testBtnWarn:SetSize(110,20)
testBtnWarn:SetPoint("TOPLEFT", testBtnInfo, "BOTTOMLEFT", 0, -6)
testBtnWarn:SetText("Test Warn")
testBtnWarn:SetScript("OnClick", function() if addon.Notify then addon:Notify("Warning notification", 'warn') end end)
local testBtnError = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
testBtnError:SetSize(110,20)
testBtnError:SetPoint("TOPLEFT", testBtnWarn, "BOTTOMLEFT", 0, -6)
testBtnError:SetText("Test Error")
testBtnError:SetScript("OnClick", function() if addon.Notify then addon:Notify("Error notification", 'error') end end)
local testBtnSuccess = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
testBtnSuccess:SetSize(110,20)
testBtnSuccess:SetPoint("TOPLEFT", testBtnError, "BOTTOMLEFT", 0, -6)
testBtnSuccess:SetText("Test Success")
testBtnSuccess:SetScript("OnClick", function() if addon.Notify then addon:Notify("Success notification", 'success') end end)

-- Move lock checkbox below notifications test buttons
local lockCB = CreateFrame("CheckButton", "HAK_LockToolbarCB", panel, "InterfaceOptionsCheckButtonTemplate")
lockCB:SetPoint("TOPLEFT", testBtnSuccess, "BOTTOMLEFT", -16, -18)
_G[lockCB:GetName() .. "Text"]:SetText("Lock Toolbar (disable drag)")
lockCB:SetScript("OnClick", function(self)
	HerosArmyKnifeDB.settings.toolbar.locked = self:GetChecked() and true or false
end)

-- (Module enable list moved to separate 'Modules' sub panel)
function addon:FormatModuleName(key)
	if not key then return "" end
	-- Insert space before capital letters following a lowercase
	local spaced = key:gsub("(%l)(%u)", "%1 %2")
	-- Special tweaks if needed
	spaced = spaced:gsub("UI", "UI")
	return spaced
end

local function BuildModuleCheckboxes(container)
	if not addon.moduleRegistry or not container then return end
	if container.checks then for _, c in ipairs(container.checks) do c:Hide() end end
	container.checks = {}
	local last
	for key, info in pairs(addon.moduleRegistry) do
		local cb = CreateFrame("CheckButton", "HAK_ModuleCB_"..key, container, "InterfaceOptionsCheckButtonTemplate")
		if not last then cb:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0) else cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4) end
		local defaultText = _G[cb:GetName() .. "Text"]
		if defaultText then defaultText:Hide() end
		local label = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
		label:SetText(addon:FormatModuleName(key))
		cb:SetChecked(HerosArmyKnifeDB.settings.modulesEnabled[key] ~= false)
		cb:SetScript("OnClick", function(self)
			HerosArmyKnifeDB.settings.modulesEnabled[key] = self:GetChecked() and true or false
			addon:RebuildToolbar()
		end)
		cb.label = label
		table.insert(container.checks, cb)
		last = cb
	end
end

panel.refresh = function()
	safeSettings()
	local t = HerosArmyKnifeDB.settings.toolbar
	if orientDrop._initialized then
		UIDropDownMenu_SetSelectedValue(orientDrop, t.orientation)
		UIDropDownMenu_SetText(orientDrop, (function()
			for _, v in ipairs(orientations) do if v.value == t.orientation then return v.text end end
			return "Orientation"
		end)())
	end
	if themeDrop._initialized then
		UIDropDownMenu_SetSelectedValue(themeDrop, HerosArmyKnifeDB.settings.themeName)
		UIDropDownMenu_SetText(themeDrop, HerosArmyKnifeDB.settings.themeName)
	end
	if fontDrop and fontDrop._initialized then
		UIDropDownMenu_SetSelectedValue(fontDrop, HerosArmyKnifeDB.settings.fontName)
		UIDropDownMenu_SetText(fontDrop, HerosArmyKnifeDB.settings.fontName)
	end
	scaleSlider:SetValue(t.iconScale)
	spacingSlider:SetValue(t.iconSpacing or 6)
	padTop:SetValue(t.padTop); padBottom:SetValue(t.padBottom); padLeft:SetValue(t.padLeft); padRight:SetValue(t.padRight)
	lockCB:SetChecked(t.locked)
	if notifyDrop and notifyDrop._initialized then
		UIDropDownMenu_SetSelectedValue(notifyDrop, HerosArmyKnifeDB.settings.notifications.mode)
		UIDropDownMenu_SetText(notifyDrop, HerosArmyKnifeDB.settings.notifications.mode)
	end
	if scaleSlider.valueText then scaleSlider.valueText:SetText(string.format("%.2f", t.iconScale)) end
	if spacingSlider.valueText then spacingSlider.valueText:SetText(string.format("%d", t.iconSpacing or 6)) end
	if padTop.valueText then padTop.valueText:SetText(string.format("%d", t.padTop)) end
	if padBottom.valueText then padBottom.valueText:SetText(string.format("%d", t.padBottom)) end
	if padLeft.valueText then padLeft.valueText:SetText(string.format("%d", t.padLeft)) end
	if padRight.valueText then padRight.valueText:SetText(string.format("%d", t.padRight)) end
	if fontSizeSlider then fontSizeSlider:SetValue(HerosArmyKnifeDB.settings.fontSize or 14) end
	if fontSizeSlider.valueText then fontSizeSlider.valueText:SetText(string.format("%d", HerosArmyKnifeDB.settings.fontSize or 14)) end
	-- Explicit bottom anchor based height recalculation to ensure all elements fit & scrolling range updates
	if panel._hakScrollContent and panel._hakScrollFrame and lockCB and lockCB:IsShown() then
		local top = panel._hakScrollContent:GetTop() or 0
		local bottom = lockCB:GetBottom() or 0
		if bottom and top then
			local needed = (top - bottom) + 60 -- padding below last element
			local viewportH = panel._hakScrollFrame:GetHeight() or 300
			if needed < viewportH then needed = viewportH + 20 end
			panel._hakScrollContent:SetHeight(needed)
			if panel._hakScrollFrame.UpdateScrollChildRect then panel._hakScrollFrame:UpdateScrollChildRect() end
		end
	end
	-- Fallback to generic refresh if still present
	if panel._hakRefreshScrollHeight then panel._hakRefreshScrollHeight() end
end

panel:SetScript("OnShow", panel.refresh)
panel.okay = function() end
panel.cancel = function() end

-- Apply scrolling to main options panel after initial widgets created
addon:MakePanelScrollable(panel)

-- Module-specific options panels API
addon.moduleOptionBuilders = addon.moduleOptionBuilders or {}
addon.moduleOptionPanels = addon.moduleOptionPanels or {}

function addon:RegisterModuleOptions(key, builderFunc)
	if not key or type(builderFunc) ~= 'function' then return end
	addon.moduleOptionBuilders[key] = builderFunc
	if addon.optionsPanelBuiltChildren then
		addon:BuildModuleOptionsPanels()
	end
end

function addon:BuildModuleOptionsPanels()
	if not addon.moduleOptionBuilders then return end
	for key, builder in pairs(addon.moduleOptionBuilders) do
		if not addon.moduleOptionPanels[key] then
			local child = addon.CreateThemedFrame and addon:CreateThemedFrame(nil, "HAK_ModuleOptions_"..key, 640, 520, 'panel') or CreateFrame("Frame", "HAK_ModuleOptions_"..key)
			if not child:GetWidth() or child:GetWidth()==0 then child:SetSize(640,520) end
			child.name = key
			child.parent = panel.name
			InterfaceOptions_AddCategory(child)
			addon.moduleOptionPanels[key] = child
			-- Wrap child in scroll frame before building contents
			addon:MakePanelScrollable(child)
			local content = child._hakScrollContent or child
			local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
			if key == 'CacheOpener' then
				title:SetPoint("TOPLEFT", 16, 0)
			else
				title:SetPoint("TOPLEFT", 16, -15)
			end
			title:SetText("HerosArmyKnife - " .. key)
			builder(content)
			child._hakNoHeader = true
			if child._hakRefreshScrollHeight then child._hakRefreshScrollHeight() end
		end
	end
	addon.optionsPanelBuiltChildren = true
end

-- Dedicated Modules sub options panel
if not addon.modulesOptionsPanel then
	local mPanel = addon.CreateThemedFrame and addon:CreateThemedFrame(nil, "HerosArmyKnifeModulesPanel", 640, 520, 'panel') or CreateFrame("Frame", "HerosArmyKnifeModulesPanel")
	mPanel._hakNoHeader = true
	if not mPanel:GetWidth() or mPanel:GetWidth()==0 then mPanel:SetSize(640,520) end
	mPanel.name = "Modules"
	mPanel.parent = panel.name
	InterfaceOptions_AddCategory(mPanel)
	addon.modulesOptionsPanel = mPanel
	addon:MakePanelScrollable(mPanel)
	local content = mPanel._hakScrollContent or mPanel
	local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -15)
	title:SetText("HerosArmyKnife - Modules")
	local desc = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
	desc:SetWidth(500)
	desc:SetJustifyH("LEFT")
	desc:SetText("Enable or disable modules. Disabling hides its toolbar icon and prevents its interactive features. (Underlying code remains loaded until next UI reload.)")
	local container = addon.CreateThemedFrame and addon:CreateThemedFrame(content, "HAK_ModulesEnableContainer", 600, 360, 'subpanel') or CreateFrame("Frame", "HAK_ModulesEnableContainer", content)
	container:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
	if not container:GetWidth() or container:GetWidth()==0 then container:SetSize(600,360) end
	mPanel._hakRefreshScrollHeight = function()
		local bottomMost = container:GetBottom() or content:GetBottom()
		local heightNeeded = (title:GetTop() or 0) - (bottomMost or 0)
		if heightNeeded < 300 then heightNeeded = 300 end
		content:SetHeight(heightNeeded + 60)
	end
	mPanel._hakRefreshScrollHeight()
	mPanel.refresh = function()
		BuildModuleCheckboxes(container)
	end
	mPanel:SetScript("OnShow", mPanel.refresh)
end

-- Build existing module option panels if builders were registered before PLAYER_LOGIN
addon:BuildModuleOptionsPanels()

-- Helper: create a titled section inside a module options panel
function addon:CreateSection(parent, titleText, yOffset, width)
	local y = yOffset or -8
	local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	local lastAnchor = parent._lastSection or parent._sectionAnchor or parent
	if lastAnchor == parent then
		header:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -48)
	else
		header:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, y)
	end
	header:SetText(titleText or "Section")
	local container = CreateFrame("Frame", nil, parent)
	container:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
	local w = width or 420
	container:SetSize(w, 10) -- will expand with children
	parent._lastSection = container
	return container, header
end
