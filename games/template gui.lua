--[[
    IronSoul GUI Template
    Copied structure from IronSoul V1 / Clover Origins UI:
    MainWindow, TopBar, macOS controls, vertical SideBar,
    ContentFrame, tab buttons with cyan pills, and XIFIL HUB toggle.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then return end

local GUI_NAME = "IronSoulTemplateGUI"
local playerGui = player:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild(GUI_NAME)
if oldGui then oldGui:Destroy() end

local VisualConfig = {
    GuiWidth = 720,
    GuiHeight = 470,
    GuiMinWidth = 520,
    GuiMinHeight = 360,
    Font = Enum.Font.Gotham,
    FontSize = 10,
    Animations = true,
}

local Theme = {
    Primary = Color3.fromRGB(0, 220, 255),
    Main = Color3.fromRGB(13, 13, 20),
    Top = Color3.fromRGB(18, 18, 30),
    Side = Color3.fromRGB(16, 16, 26),
    SideButton = Color3.fromRGB(22, 22, 36),
    SideActive = Color3.fromRGB(28, 28, 48),
    Text = Color3.fromRGB(255, 255, 255),
    Muted = Color3.fromRGB(140, 140, 165),
}

local GuiRoot = Instance.new("ScreenGui")
GuiRoot.Name = GUI_NAME
GuiRoot.ResetOnSpawn = false
GuiRoot.IgnoreGuiInset = true
GuiRoot.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GuiRoot.Parent = playerGui

local ThemeRegistry = {
    panels = {},
    fills = {},
    texts = {},
    strokes = {},
    indicators = {},
    allLabels = {},
    corners = {},
}

local function register(list, object)
    table.insert(list, object)
    return object
end

local function corner(parent, radius)
    local object = Instance.new("UICorner")
    object.CornerRadius = UDim.new(0, radius)
    object.Parent = parent
    register(ThemeRegistry.corners, object)
    return object
end

local function frame(parent, size, position, color, zIndex)
    local object = Instance.new("Frame")
    object.Size = size
    object.Position = position or UDim2.fromOffset(0, 0)
    object.BackgroundColor3 = color or Color3.new(1, 1, 1)
    object.BorderSizePixel = 0
    object.ZIndex = zIndex or 1
    object.Parent = parent
    return object
end

local function label(parent, text, size, position, textSize, color, zIndex)
    local object = Instance.new("TextLabel")
    object.BackgroundTransparency = 1
    object.Size = size
    object.Position = position or UDim2.fromOffset(0, 0)
    object.Text = text
    object.TextColor3 = color or Theme.Text
    object.TextSize = textSize or VisualConfig.FontSize
    object.Font = VisualConfig.Font
    object.TextXAlignment = Enum.TextXAlignment.Left
    object.TextYAlignment = Enum.TextYAlignment.Center
    object.ZIndex = zIndex or 4
    object.Parent = parent
    register(ThemeRegistry.texts, object)
    register(ThemeRegistry.allLabels, object)
    return object
end

local function button(parent, text, size, position, zIndex)
    local object = Instance.new("TextButton")
    object.BackgroundColor3 = Theme.SideButton
    object.Size = size
    object.Position = position or UDim2.fromOffset(0, 0)
    object.Text = text
    object.TextColor3 = Theme.Muted
    object.TextSize = VisualConfig.FontSize
    object.Font = VisualConfig.Font
    object.AutoButtonColor = false
    object.BorderSizePixel = 0
    object.ZIndex = zIndex or 4
    object.Parent = parent
    register(ThemeRegistry.allLabels, object)
    return object
end

local function stroke(parent, color, transparency, thickness)
    local object = Instance.new("UIStroke")
    object.Color = color
    object.Transparency = transparency or 0
    object.Thickness = thickness or 1
    object.Parent = parent
    register(ThemeRegistry.strokes, object)
    return object
end

local function animate(object, properties, duration)
    if not VisualConfig.Animations then
        for property, value in pairs(properties) do object[property] = value end
        return
    end
    TweenService:Create(object, TweenInfo.new(duration or 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), properties):Play()
end

local MainWindow = frame(GuiRoot, UDim2.fromOffset(VisualConfig.GuiWidth, VisualConfig.GuiHeight), UDim2.new(0.5, -VisualConfig.GuiWidth / 2, 0.5, -VisualConfig.GuiHeight / 2), Theme.Main, 2)
MainWindow.Visible = true
MainWindow.ClipsDescendants = true
register(ThemeRegistry.panels, MainWindow)
corner(MainWindow, 12)
stroke(MainWindow, Theme.Primary, 0.78, 1)

local TopBar = frame(MainWindow, UDim2.new(1, 0, 0, 46), nil, Theme.Top, 3)
register(ThemeRegistry.panels, TopBar)
corner(TopBar, 12)
local topFix = frame(TopBar, UDim2.new(1, 0, 0, 12), UDim2.new(0, 0, 1, -12), Theme.Top, 3)
local topAccent = frame(TopBar, UDim2.new(1, 0, 0, 1), UDim2.new(0, 0, 1, -1), Theme.Primary, 4)
topAccent.BackgroundTransparency = 0.6
register(ThemeRegistry.fills, topAccent)

local Title = label(TopBar, "XIFIL HUB  //  IRON SOUL V7", UDim2.new(0.6, 0, 1, 0), UDim2.fromOffset(16, 0), 13, Theme.Text, 4)
Title.Font = Enum.Font.GothamBlack
Title.TextColor3 = Theme.Primary

local WindowControls = frame(TopBar, UDim2.fromOffset(84, 46), UDim2.new(1, -90, 0, 0), nil, 5)
WindowControls.BackgroundTransparency = 1
local controlButtons = {}
local function createMacButton(xOffset, color, text)
    local wrap = button(WindowControls, "", UDim2.fromOffset(22, 22), UDim2.new(0, xOffset, 0.5, 0), 6)
    wrap.AnchorPoint = Vector2.new(0, 0.5)
    wrap.BackgroundTransparency = 1
    local dot = frame(wrap, UDim2.fromOffset(15, 15), UDim2.new(0.5, 0, 0.5, 0), color, 7)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    corner(dot, 8)
    local icon = label(wrap, text, UDim2.fromScale(1, 1), nil, 12, Color3.fromRGB(18, 18, 25), 8)
    icon.TextXAlignment = Enum.TextXAlignment.Center
    icon.Visible = false
    wrap.MouseEnter:Connect(function() icon.Visible = true end)
    wrap.MouseLeave:Connect(function() icon.Visible = false end)
    table.insert(controlButtons, wrap)
    return wrap
end
local BtnClose = createMacButton(4, Color3.fromRGB(255, 96, 88), "×")
local BtnMin = createMacButton(30, Color3.fromRGB(255, 189, 68), "−")
local BtnMax = createMacButton(56, Color3.fromRGB(40, 200, 64), "+")

local isMinimized = false
local normalSize = MainWindow.Size
BtnClose.MouseButton1Click:Connect(function() MainWindow.Visible = false end)
BtnMin.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        normalSize = MainWindow.Size
        animate(MainWindow, {Size = UDim2.new(0, VisualConfig.GuiWidth, 0, 46)}, 0.25)
    else
        animate(MainWindow, {Size = normalSize}, 0.25)
    end
end)
BtnMax.MouseButton1Click:Connect(function()
    local maximized = MainWindow:GetAttribute("Maximized")
    if maximized then
        MainWindow:SetAttribute("Maximized", false)
        animate(MainWindow, {Size = normalSize, Position = UDim2.new(0.5, -VisualConfig.GuiWidth / 2, 0.5, -VisualConfig.GuiHeight / 2)}, 0.25)
    else
        normalSize = MainWindow.Size
        MainWindow:SetAttribute("Maximized", true)
        animate(MainWindow, {Size = UDim2.new(1, -30, 1, -30), Position = UDim2.fromOffset(15, 15)}, 0.25)
    end
end)

local SideBar = Instance.new("ScrollingFrame")
SideBar.Name = "SideBar"
SideBar.BackgroundColor3 = Theme.Side
SideBar.Position = UDim2.new(0, 0, 0, 46)
SideBar.Size = UDim2.new(0, 184, 1, -46)
SideBar.BorderSizePixel = 0
SideBar.ZIndex = 3
SideBar.ScrollBarThickness = 2
SideBar.ScrollBarImageColor3 = Theme.Primary
SideBar.ScrollingDirection = Enum.ScrollingDirection.Y
SideBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
SideBar.CanvasSize = UDim2.new(0, 0, 0, 0)
SideBar.Parent = MainWindow
register(ThemeRegistry.panels, SideBar)

local sideLayout = Instance.new("UIListLayout")
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideLayout.Padding = UDim.new(0, 5)
sideLayout.Parent = SideBar
local sidePadding = Instance.new("UIPadding")
sidePadding.PaddingTop = UDim.new(0, 38)
sidePadding.PaddingLeft = UDim.new(0, 10)
sidePadding.PaddingRight = UDim.new(0, 10)
sidePadding.Parent = SideBar

local content = frame(MainWindow, UDim2.new(1, -194, 1, -56), UDim2.fromOffset(194, 46), Theme.Main, 3)
content.BackgroundTransparency = 0

local avatar = frame(content, UDim2.fromOffset(54, 54), UDim2.new(0, 40, 0, 18), Color3.fromRGB(25, 28, 40), 5)
corner(avatar, 12)
local avatarStroke = stroke(avatar, Theme.Primary, 0.1, 2)
local avatarText = label(avatar, "IS", UDim2.fromScale(1, 1), nil, 14, Theme.Primary, 6)
avatarText.TextXAlignment = Enum.TextXAlignment.Center
avatarText.Font = Enum.Font.GothamBlack

local tabRegistry = {}
local activeTab = nil

local function createPage(tabName)
    local page = Instance.new("ScrollingFrame")
    page.Name = tabName .. "Page"
    page.BackgroundTransparency = 1
    page.Size = UDim2.new(1, -20, 1, -92)
    page.Position = UDim2.fromOffset(10, 84)
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.Primary
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.BorderSizePixel = 0
    page.ZIndex = 4
    page.Visible = false
    page.Parent = content
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = page
    return page
end

local function createSideTab(tabName, page)
    local sideBtn = button(SideBar, tabName, UDim2.new(1, 0, 0, 38), nil, 4)
    sideBtn.TextSize = 10
    sideBtn.TextXAlignment = Enum.TextXAlignment.Left
    sideBtn.BackgroundColor3 = Theme.SideButton
    sideBtn.TextColor3 = Theme.Muted
    corner(sideBtn, 7)
    local sidePill = frame(sideBtn, UDim2.new(0, 3, 0.6, 0), UDim2.new(0, 0, 0.5, 0), Theme.Primary, 5)
    sidePill.AnchorPoint = Vector2.new(0, 0.5)
    sidePill.Visible = false
    corner(sidePill, 2)
    register(ThemeRegistry.indicators, sidePill)
    sideBtn.MouseEnter:Connect(function()
        if activeTab ~= tabName then animate(sideBtn, {BackgroundColor3 = Color3.fromRGB(26, 26, 44)}, 0.15) end
    end)
    sideBtn.MouseLeave:Connect(function()
        if activeTab ~= tabName then animate(sideBtn, {BackgroundColor3 = Theme.SideButton}, 0.15) end
    end)
    tabRegistry[tabName] = {Button = sideBtn, Page = page, Pill = sidePill}
    sideBtn.MouseButton1Click:Connect(function()
        if activeTab == tabName then return end
        activeTab = tabName
        for name, data in pairs(tabRegistry) do
            local selected = name == tabName
            data.Page.Visible = selected
            data.Pill.Visible = selected
            data.Button.TextColor3 = selected and Theme.Text or Theme.Muted
            data.Button.BackgroundColor3 = selected and Theme.SideActive or Theme.SideButton
        end
    end)
    return sideBtn
end

local function section(parent, text)
    local wrapper = frame(parent, UDim2.new(1, 0, 0, 30), nil, Color3.new(1, 1, 1), 4)
    wrapper.BackgroundTransparency = 1
    local line = frame(wrapper, UDim2.new(1, -8, 0, 1), UDim2.fromOffset(8, 17), Theme.Primary, 5)
    line.BackgroundTransparency = 0.65
    local dot = frame(wrapper, UDim2.fromOffset(5, 5), UDim2.fromOffset(6, 15), Theme.Primary, 6)
    corner(dot, 3)
    local textLabel = label(wrapper, text:upper(), UDim2.new(1, -28, 0, 18), UDim2.fromOffset(16, 7), 8, Theme.Primary, 6)
    textLabel.Font = Enum.Font.Code
    return wrapper
end

local function optionRow(parent, titleText, subtitle, order)
    local row = frame(parent, UDim2.new(1, 0, 0, 58), nil, Color3.fromRGB(19, 20, 30), 4)
    row.LayoutOrder = order or 1
    corner(row, 7)
    label(row, titleText, UDim2.new(0.68, 0, 0, 20), UDim2.fromOffset(14, 7), 11, Theme.Text, 5).Font = Enum.Font.GothamMedium
    label(row, subtitle, UDim2.new(0.68, 0, 0, 16), UDim2.fromOffset(14, 29), 9, Theme.Muted, 5)
    return row
end

local function selector(parent, titleText, subtitle, values, initial, order, callback)
    local row = optionRow(parent, titleText, subtitle, order)
    local choose = button(row, initial, UDim2.fromOffset(118, 28), UDim2.new(1, -130, 0, 15), 6)
    choose.TextSize = 9
    choose.TextXAlignment = Enum.TextXAlignment.Center
    choose.BackgroundColor3 = Theme.Main
    choose.TextColor3 = Theme.Primary
    corner(choose, 5)
    stroke(choose, Theme.Primary, 0.7, 1)
    local index = 1
    for i, value in ipairs(values) do if value == initial then index = i end end
    choose.MouseButton1Click:Connect(function()
        index = index % #values + 1
        choose.Text = values[index]
        if callback then callback(values[index]) end
    end)
end

local function toggle(parent, titleText, subtitle, initial, order, callback)
    local row = optionRow(parent, titleText, subtitle, order)
    local track = button(row, "", UDim2.fromOffset(44, 24), UDim2.new(1, -56, 0, 17), 6)
    track.BackgroundColor3 = Color3.fromRGB(31, 33, 47)
    corner(track, 12)
    local knob = frame(track, UDim2.fromOffset(18, 18), UDim2.fromOffset(3, 3), initial and Theme.Primary or Color3.fromRGB(235, 237, 244), 7)
    corner(knob, 9)
    local value = initial
    local function render()
        track.BackgroundColor3 = value and Theme.Primary or Color3.fromRGB(31, 33, 47)
        knob.BackgroundColor3 = value and Color3.fromRGB(244, 246, 250) or Color3.fromRGB(125, 131, 145)
        animate(knob, {Position = value and UDim2.new(1, -21, 0, 3) or UDim2.fromOffset(3, 3)}, 0.18)
    end
    track.MouseButton1Click:Connect(function() value = not value; render(); if callback then callback(value) end end)
    render()
end

local displayPage = createPage("Tampilan")
section(displayPage, "DUNIA")
selector(displayPage, "Tema", "Warna aksen utama GUI", {"Cyan", "Violet", "Ember"}, "Cyan", 2)
section(displayPage, "KONTROL TAMPILAN")
toggle(displayPage, "Panel utama", "Layout vertikal IronSoul", true, 4)
toggle(displayPage, "Rounded panel", "Radius seperti UI asli", true, 5)

local fontPage = createPage("Font")
section(fontPage, "FONT")
selector(fontPage, "Jenis font", "Font komponen GUI", {"Gotham", "Code", "Arcade", "SourceSans"}, "Gotham", 2, function(value)
    local selected = ({Gotham = Enum.Font.Gotham, Code = Enum.Font.Code, Arcade = Enum.Font.Arcade, SourceSans = Enum.Font.SourceSans})[value]
    VisualConfig.Font = selected or Enum.Font.Gotham
    for _, object in ipairs(ThemeRegistry.allLabels) do if object and object.Parent then object.Font = VisualConfig.Font end end
end)
toggle(fontPage, "Teks tebal", "Hierarki label dan tombol", false, 4, function(value)
    for _, object in ipairs(ThemeRegistry.allLabels) do if object and object.Parent then object.Font = value and Enum.Font.GothamBold or VisualConfig.Font end end
end)

local effectPage = createPage("Efek")
section(effectPage, "EFEK")
selector(effectPage, "Animasi", "Transisi GUI dan Floating Button", {"On", "Off"}, "On", 2, function(value) VisualConfig.Animations = value == "On" end)
toggle(effectPage, "Glow cyan", "Indikator mengikuti tema IronSoul", true, 4)
toggle(effectPage, "Partikel", "Opsional, nonaktif secara default", false, 5)

local ToggleGuiBtn = Instance.new("ScreenGui")
ToggleGuiBtn.Name = "IronSoulFloatingButton"
ToggleGuiBtn.ResetOnSpawn = false
ToggleGuiBtn.IgnoreGuiInset = true
ToggleGuiBtn.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ToggleGuiBtn.Parent = playerGui

local BtnContainer = frame(ToggleGuiBtn, UDim2.fromOffset(110, 36), UDim2.new(0.05, 0, 0.15, 0), nil, 20)
BtnContainer.BackgroundTransparency = 1
local floatGlow = frame(BtnContainer, UDim2.new(1, 4, 1, 4), UDim2.new(0.5, 0, 0.5, 0), Theme.Primary, 21)
floatGlow.AnchorPoint = Vector2.new(0.5, 0.5)
floatGlow.BackgroundTransparency = 0.8
corner(floatGlow, 18)
local floatBtn = button(BtnContainer, "", UDim2.fromScale(1, 1), UDim2.new(0.5, 0, 0.5, 0), 22)
floatBtn.AnchorPoint = Vector2.new(0.5, 0.5)
floatBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
floatBtn.Text = ""
corner(floatBtn, 18)
stroke(floatBtn, Theme.Primary, 0.35, 1)
local statusDot = frame(floatBtn, UDim2.fromOffset(6, 6), UDim2.fromOffset(10, 15), Theme.Primary, 24)
corner(statusDot, 3)
local floatingText = label(floatBtn, "XIFIL  HUB", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(20, 0), 12, Theme.Text, 24)
floatingText.Font = Enum.Font.GothamBlack
local floatingSub = label(floatBtn, "", UDim2.fromScale(1, 1), nil, 1, Theme.Primary, 24)
floatingSub.Visible = false

local guiVisible = true
local savedSize = MainWindow.Size
local savedPosition = MainWindow.Position
local function toggleGui()
    guiVisible = not guiVisible
    if guiVisible then
        MainWindow.Visible = true
        MainWindow.Size = UDim2.fromOffset(0, 46)
        MainWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
        animate(MainWindow, {Size = savedSize, Position = savedPosition}, 0.35)
    else
        savedSize = MainWindow.Size
        savedPosition = MainWindow.Position
        animate(MainWindow, {Size = UDim2.fromOffset(0, 46), Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.28)
        task.delay(0.3, function() if not guiVisible then MainWindow.Visible = false end end)
    end
end
floatBtn.MouseEnter:Connect(function() animate(floatGlow, {BackgroundTransparency = 0.5, Size = UDim2.new(1, 10, 1, 10)}, 0.3) end)
floatBtn.MouseLeave:Connect(function() animate(floatGlow, {BackgroundTransparency = 0.8, Size = UDim2.new(1, 4, 1, 4)}, 0.3) end)
floatBtn.MouseButton1Click:Connect(toggleGui)

local draggingWindow, dragStart, windowStart = false, nil, nil
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingWindow = true; dragStart = input.Position; windowStart = MainWindow.Position end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingWindow and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainWindow.Position = UDim2.new(windowStart.X.Scale, windowStart.X.Offset + delta.X, windowStart.Y.Scale, windowStart.Y.Offset + delta.Y)
        savedPosition = MainWindow.Position
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingWindow = false end
end)

local function switchTab(name)
    activeTab = name
    for tabName, data in pairs(tabRegistry) do
        local selected = tabName == name
        data.Page.Visible = selected
        data.Pill.Visible = selected
        data.Button.TextColor3 = selected and Theme.Text or Theme.Muted
        data.Button.BackgroundColor3 = selected and Theme.SideActive or Theme.SideButton
    end
end

for _, name in ipairs({"Tampilan", "Font", "Efek"}) do
    createSideTab(name, pages[name])
end
switchTab("Tampilan")

_G.IronSoulTemplateGUI = {
    Show = function() guiVisible = true; MainWindow.Visible = true end,
    Hide = function() guiVisible = false; MainWindow.Visible = false end,
    Toggle = toggleGui,
    State = VisualConfig,
}
