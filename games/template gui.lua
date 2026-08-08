--[[
    IronSoul GUI Template
    Layout mengikuti GUI IronSoul V1 pada screenshot:
    panel tengah compact, header XIFIL HUB, tab horizontal,
    section cyan, toggle gelap, serta Floating Button.
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

local state = {
    activeTab = "Tampilan",
    visible = true,
    theme = "Cyan",
    font = "Gotham",
    fontSize = 11,
    transparency = 0.04,
    rounded = true,
    glow = true,
    particles = false,
    animations = true,
    backgroundEffect = "None",
}

local themes = {
    Cyan = {
        accent = Color3.fromRGB(0, 220, 255),
        accentDark = Color3.fromRGB(0, 92, 112),
        background = Color3.fromRGB(9, 10, 16),
        panel = Color3.fromRGB(15, 16, 24),
        surface = Color3.fromRGB(20, 21, 31),
        row = Color3.fromRGB(24, 25, 36),
        muted = Color3.fromRGB(126, 133, 151),
    },
    Violet = {
        accent = Color3.fromRGB(168, 112, 255),
        accentDark = Color3.fromRGB(88, 48, 145),
        background = Color3.fromRGB(12, 9, 20),
        panel = Color3.fromRGB(23, 17, 34),
        surface = Color3.fromRGB(31, 23, 46),
        row = Color3.fromRGB(42, 29, 59),
        muted = Color3.fromRGB(145, 132, 167),
    },
    Ember = {
        accent = Color3.fromRGB(255, 148, 64),
        accentDark = Color3.fromRGB(145, 65, 25),
        background = Color3.fromRGB(20, 10, 7),
        panel = Color3.fromRGB(34, 18, 13),
        surface = Color3.fromRGB(45, 24, 17),
        row = Color3.fromRGB(58, 29, 19),
        muted = Color3.fromRGB(169, 139, 122),
    },
}

local fonts = {
    Gotham = Enum.Font.Gotham,
    SourceSans = Enum.Font.SourceSans,
    Code = Enum.Font.Code,
    Arcade = Enum.Font.Arcade,
    Fantasy = Enum.Font.Fantasy,
}

local function theme()
    return themes[state.theme] or themes.Cyan
end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local refs = {
    panels = {},
    surfaces = {},
    accentObjects = {},
    accentTexts = {},
    labels = {},
    buttons = {},
    corners = {},
    strokes = {},
}

local function remember(list, object)
    table.insert(list, object)
    return object
end

local function rounded(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = object
    remember(refs.corners, corner)
    return corner
end

local function outline(object, color, transparency, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.new(1, 1, 1)
    stroke.Transparency = transparency or 0
    stroke.Thickness = thickness or 1
    stroke.Parent = object
    remember(refs.strokes, stroke)
    return stroke
end

local function makeFrame(parent, name, size, position)
    local object = Instance.new("Frame")
    object.Name = name
    object.Size = size
    object.Position = position or UDim2.fromOffset(0, 0)
    object.BorderSizePixel = 0
    object.Parent = parent
    return object
end

local function makeLabel(parent, text, size, position, textSize, color)
    local object = Instance.new("TextLabel")
    object.Name = "Label"
    object.BackgroundTransparency = 1
    object.Size = size
    object.Position = position or UDim2.fromOffset(0, 0)
    object.Text = text
    object.TextSize = textSize or state.fontSize
    object.TextColor3 = color or Color3.fromRGB(230, 233, 241)
    object.TextXAlignment = Enum.TextXAlignment.Left
    object.TextYAlignment = Enum.TextYAlignment.Center
    object.Font = fonts[state.font]
    object.Parent = parent
    remember(refs.labels, object)
    return object
end

local function makeButton(parent, text, size, position)
    local object = Instance.new("TextButton")
    object.Name = "Button"
    object.Size = size
    object.Position = position or UDim2.fromOffset(0, 0)
    object.BorderSizePixel = 0
    object.AutoButtonColor = false
    object.Text = text
    object.TextSize = state.fontSize
    object.TextColor3 = Color3.fromRGB(220, 225, 235)
    object.Font = fonts[state.font]
    object.Parent = parent
    remember(refs.buttons, object)
    return object
end

local function animate(object, properties, duration)
    if not state.animations then
        for property, value in pairs(properties) do object[property] = value end
        return
    end
    TweenService:Create(object, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), properties):Play()
end

local background = makeFrame(gui, "Background", UDim2.fromScale(1, 1))
background.BackgroundTransparency = 1
background.ZIndex = 0

local main = makeFrame(gui, "MainWindow", UDim2.fromOffset(394, 310), UDim2.new(0.5, -197, 0.5, -155))
main.BackgroundColor3 = theme().background
main.BackgroundTransparency = state.transparency
main.ZIndex = 5
remember(refs.panels, main)
rounded(main, 10)
outline(main, theme().accentDark, 0.12, 1)

local header = makeFrame(main, "Header", UDim2.new(1, 0, 0, 45))
header.BackgroundColor3 = theme().panel
header.ZIndex = 6
remember(refs.panels, header)
rounded(header, 10)

local title = makeLabel(header, "XIFIL HUB", UDim2.fromOffset(100, 22), UDim2.fromOffset(14, 7), 14, theme().accent)
title.Font = Enum.Font.GothamBold
remember(refs.accentTexts, title)
local version = makeLabel(header, "// IRON SOUL V7", UDim2.fromOffset(95, 15), UDim2.fromOffset(83, 12), 7, Color3.fromRGB(135, 145, 164))
version.Font = Enum.Font.Code

local trafficColors = {
    Color3.fromRGB(255, 83, 97),
    Color3.fromRGB(255, 184, 30),
    Color3.fromRGB(0, 220, 72),
}
for index, color in ipairs(trafficColors) do
    local dot = makeButton(header, "", UDim2.fromOffset(15, 15), UDim2.new(1, -18 - ((index - 1) * 24), 0, 14))
    dot.BackgroundColor3 = color
    dot.ZIndex = 8
    rounded(dot, 9)
end

local tabsBar = makeFrame(main, "TabsBar", UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 49))
tabsBar.BackgroundColor3 = theme().panel
tabsBar.ZIndex = 6
rounded(tabsBar, 6)
local tabs = {"Tampilan", "Font", "Efek"}
local tabButtons = {}
local pages = {}

for index, tabName in ipairs(tabs) do
    local tab = makeButton(tabsBar, tabName, UDim2.new(1 / #tabs, -5, 1, -8), UDim2.new((index - 1) / #tabs, 3, 0, 4))
    tab.TextSize = 9
    tab.TextXAlignment = Enum.TextXAlignment.Center
    tab.ZIndex = 8
    rounded(tab, 4)
    tabButtons[tabName] = tab
end

local content = makeFrame(main, "Content", UDim2.new(1, -16, 1, -98), UDim2.fromOffset(8, 94))
content.BackgroundColor3 = theme().background
content.ZIndex = 6
rounded(content, 6)

local function makePage(name)
    local page = makeFrame(content, name .. "Page", UDim2.fromScale(1, 1))
    page.BackgroundTransparency = 1
    page.Visible = false
    page.ZIndex = 7
    pages[name] = page
    return page
end

local function sectionTitle(parent, text, y)
    local line = makeFrame(parent, "SectionLine", UDim2.new(1, -22, 0, 1), UDim2.fromOffset(11, y + 12))
    line.BackgroundColor3 = theme().accentDark
    remember(refs.accentObjects, line)
    local dot = makeFrame(parent, "SectionDot", UDim2.fromOffset(5, 5), UDim2.fromOffset(9, y + 10))
    dot.BackgroundColor3 = theme().accent
    rounded(dot, 3)
    remember(refs.accentObjects, dot)
    local label = makeLabel(parent, text:upper(), UDim2.fromOffset(100, 16), UDim2.fromOffset(20, y + 3), 8, theme().accent)
    label.Font = Enum.Font.Code
    remember(refs.accentTexts, label)
end

local function controlRow(parent, titleText, subtitle, y)
    local row = makeFrame(parent, "ControlRow", UDim2.new(1, -20, 0, 43), UDim2.fromOffset(10, y))
    row.BackgroundColor3 = theme().row
    remember(refs.surfaces, row)
    rounded(row, 6)
    makeLabel(row, titleText, UDim2.new(0.55, 0, 0, 18), UDim2.fromOffset(10, 5), 10, Color3.fromRGB(220, 224, 232)).Font = Enum.Font.GothamMedium
    makeLabel(row, subtitle, UDim2.new(0.62, 0, 0, 13), UDim2.fromOffset(10, 24), 8, theme().muted)
    return row
end

local function addSelector(parent, titleText, subtitle, options, initial, y, callback)
    local row = controlRow(parent, titleText, subtitle, y)
    local button = makeButton(row, tostring(initial), UDim2.fromOffset(128, 29), UDim2.new(1, -138, 0, 7))
    button.TextSize = 8
    button.TextXAlignment = Enum.TextXAlignment.Center
    button.BackgroundColor3 = theme().background
    button.TextColor3 = theme().accent
    rounded(button, 5)
    outline(button, theme().accentDark, 0.35, 1)
    local selected = 1
    for index, value in ipairs(options) do if value == initial then selected = index end end
    button.MouseButton1Click:Connect(function()
        selected = selected % #options + 1
        button.Text = tostring(options[selected])
        if callback then callback(options[selected]) end
    end)
    return row
end

local function addToggle(parent, titleText, subtitle, initial, y, callback)
    local row = controlRow(parent, titleText, subtitle, y)
    local track = makeButton(row, "", UDim2.fromOffset(42, 22), UDim2.new(1, -52, 0, 11))
    rounded(track, 11)
    local thumb = makeFrame(track, "Thumb", UDim2.fromOffset(16, 16), UDim2.fromOffset(3, 3))
    rounded(thumb, 8)
    local value = initial
    local function render()
        track.BackgroundColor3 = value and theme().accentDark or Color3.fromRGB(43, 45, 57)
        thumb.BackgroundColor3 = value and Color3.fromRGB(240, 242, 248) or Color3.fromRGB(119, 126, 143)
        animate(thumb, {Position = value and UDim2.new(1, -19, 0, 3) or UDim2.fromOffset(3, 3)}, 0.16)
    end
    track.MouseButton1Click:Connect(function()
        value = not value
        render()
        if callback then callback(value) end
    end)
    render()
    return row
end

local function addSlider(parent, titleText, subtitle, minimum, maximum, initial, y, callback)
    local row = controlRow(parent, titleText, subtitle, y)
    local valueText = makeLabel(row, tostring(initial), UDim2.fromOffset(32, 18), UDim2.new(1, -42, 0, 4), 9, theme().accent)
    valueText.TextXAlignment = Enum.TextXAlignment.Right
    local bar = makeFrame(row, "SliderBar", UDim2.new(1, -20, 0, 4), UDim2.fromOffset(10, 35))
    bar.BackgroundColor3 = Color3.fromRGB(54, 57, 70)
    rounded(bar, 3)
    local ratio = (initial - minimum) / (maximum - minimum)
    local fill = makeFrame(bar, "SliderFill", UDim2.new(ratio, 0, 1, 0))
    fill.BackgroundColor3 = theme().accent
    rounded(fill, 3)
    local knob = makeFrame(bar, "SliderKnob", UDim2.fromOffset(9, 9), UDim2.new(ratio, -4, 0.5, -4))
    knob.BackgroundColor3 = theme().accent
    rounded(knob, 5)
    local dragging = false
    local function setValue(x)
        local nextRatio = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(minimum + ((maximum - minimum) * nextRatio) + 0.5)
        fill.Size = UDim2.new(nextRatio, 0, 1, 0)
        knob.Position = UDim2.new(nextRatio, -4, 0.5, -4)
        valueText.Text = tostring(value)
        if callback then callback(value) end
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; setValue(input.Position.X) end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setValue(input.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    return row
end

local displayPage = makePage("Tampilan")
sectionTitle(displayPage, "DUNIA", 8)
addSelector(displayPage, "Tema warna", "Cyan / Violet / Ember", {"Cyan", "Violet", "Ember"}, state.theme, 25, function(value) state.theme = value; applyAppearance() end)
sectionTitle(displayPage, "KONTROL TAMPILAN", 78)
addToggle(displayPage, "Panel compact", "Ukuran panel mengikuti layout IronSoul", true, 93, function(value) state.compact = value; applyAppearance() end)
addToggle(displayPage, "Sudut membulat", "Bentuk komponen lebih lembut", state.rounded, 143, function(value) state.rounded = value; applyAppearance() end)

local fontPage = makePage("Font")
sectionTitle(fontPage, "FONT", 8)
addSelector(fontPage, "Keluarga font", "Gotham / Code / Arcade", {"Gotham", "SourceSans", "Code", "Arcade", "Fantasy"}, state.font, 25, function(value) state.font = value; applyTypography() end)
addSlider(fontPage, "Ukuran font", "Atur keterbacaan teks", 9, 15, state.fontSize, 78, function(value) state.fontSize = value; applyTypography() end)
addToggle(fontPage, "Font tebal", "Perkuat label dan tombol utama", false, 128, function(value) state.bold = value; applyTypography() end)

local effectsPage = makePage("Efek")
sectionTitle(effectsPage, "EFEK LATAR", 8)
addSelector(effectsPage, "Background", "None / Aurora / Grid", {"None", "Aurora", "Grid"}, state.backgroundEffect, 25, function(value) state.backgroundEffect = value; renderBackground() end)
addToggle(effectsPage, "Glow aksen", "Garis cyan seperti GUI IronSoul", state.glow, 78, function(value) state.glow = value; applyAppearance() end)
addToggle(effectsPage, "Partikel ambient", "Opsional, nonaktif sebagai default", state.particles, 128, function(value) state.particles = value; renderBackground() end)
addToggle(effectsPage, "Animasi transisi", "Toggle dan Floating Button bergerak halus", state.animations, 178, function(value) state.animations = value end)

local floating = makeButton(gui, "IS", UDim2.fromOffset(42, 42), UDim2.new(1, -58, 1, -58))
floating.BackgroundColor3 = theme().accentDark
floating.TextColor3 = theme().accent
floating.TextSize = 11
floating.ZIndex = 20
rounded(floating, 7)
outline(floating, theme().accent, 0.25, 1)

local function setActiveTab(name)
    state.activeTab = name
    for tabName, button in pairs(tabButtons) do
        local active = tabName == name
        button.BackgroundColor3 = active and theme().accentDark or theme().surface
        button.TextColor3 = active and theme().accent or Color3.fromRGB(145, 151, 167)
        pages[tabName].Visible = active
    end
end

for name, button in pairs(tabButtons) do
    button.MouseButton1Click:Connect(function() setActiveTab(name) end)
end

floating.MouseButton1Click:Connect(function()
    state.visible = not state.visible
    if state.visible then
        main.Visible = true
        main.Size = UDim2.fromOffset(365, 285)
        animate(main, {Size = UDim2.fromOffset(394, 310)}, 0.22)
    else
        main.Visible = false
    end
end)

local dragStart, startPosition, dragging = nil, nil, false
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

function applyTypography()
    local selected = fonts[state.font] or Enum.Font.Gotham
    for _, object in ipairs(refs.labels) do
        if object and object.Parent then
            object.Font = state.bold and Enum.Font.GothamBold or selected
            object.TextSize = math.clamp(state.fontSize, 8, 16)
        end
    end
    for _, object in ipairs(refs.buttons) do
        if object and object.Parent then
            object.Font = state.bold and Enum.Font.GothamBold or selected
            object.TextSize = math.clamp(state.fontSize, 8, 16)
        end
    end
    title.Font = Enum.Font.GothamBold
    version.Font = Enum.Font.Code
end

function applyAppearance()
    local t = theme()
    main.BackgroundColor3 = t.background
    main.BackgroundTransparency = state.transparency
    header.BackgroundColor3 = t.panel
    tabsBar.BackgroundColor3 = t.panel
    content.BackgroundColor3 = t.background
    floating.BackgroundColor3 = t.accentDark
    floating.TextColor3 = t.accent
    for _, object in ipairs(refs.panels) do if object and object.Parent then object.BackgroundColor3 = t.panel end end
    for _, object in ipairs(refs.surfaces) do if object and object.Parent then object.BackgroundColor3 = t.row end end
    for _, object in ipairs(refs.accentObjects) do if object and object.Parent then object.BackgroundColor3 = t.accent end end
    for _, object in ipairs(refs.accentTexts) do if object and object.Parent then object.TextColor3 = t.accent end end
    for _, button in pairs(tabButtons) do button.BackgroundColor3 = button == tabButtons[state.activeTab] and t.accentDark or t.surface; button.TextColor3 = button == tabButtons[state.activeTab] and t.accent or Color3.fromRGB(145,151,167) end
    for _, stroke in ipairs(refs.strokes) do if stroke and stroke.Parent then stroke.Color = state.glow and t.accentDark or Color3.fromRGB(58,62,78); stroke.Transparency = state.glow and .25 or .78 end end
    for _, corner in ipairs(refs.corners) do if corner and corner.Parent then corner.CornerRadius = UDim.new(0, state.rounded and 7 or 2) end end
    applyTypography()
    renderBackground()
end

function renderBackground()
    for _, child in ipairs(background:GetChildren()) do child:Destroy() end
    local t = theme()
    if state.backgroundEffect == "Aurora" then
        local wash = makeFrame(background, "Aurora", UDim2.fromScale(1, 1))
        wash.BackgroundColor3 = t.accentDark
        wash.BackgroundTransparency = .94
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, t.accent), ColorSequenceKeypoint.new(.5, t.background), ColorSequenceKeypoint.new(1, t.accentDark)})
        gradient.Rotation = 25
        gradient.Parent = wash
    elseif state.backgroundEffect == "Grid" then
        for x = 0, 22 do local line = makeFrame(background, "GridLine", UDim2.fromOffset(1, 900), UDim2.new(x / 22, 0, 0, 0)); line.BackgroundColor3 = t.accent; line.BackgroundTransparency = .96 end
        for y = 0, 14 do local line = makeFrame(background, "GridLine", UDim2.fromOffset(1400, 1), UDim2.new(0, 0, y / 14, 0)); line.BackgroundColor3 = t.accent; line.BackgroundTransparency = .96 end
    end
    if state.particles then
        for index = 1, 12 do
            local dot = makeFrame(background, "Particle", UDim2.fromOffset(3, 3), UDim2.new(math.random(), 0, math.random(), 0))
            dot.BackgroundColor3 = t.accent
            dot.BackgroundTransparency = .65
            rounded(dot, 3)
            if state.animations then TweenService:Create(dot, TweenInfo.new(math.random(5, 9), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position = UDim2.new(math.random(), 0, math.random(), 0)}):Play() end
        end
    end
end

setActiveTab("Tampilan")
applyTypography()
applyAppearance()
renderBackground()

_G.IronSoulTemplateGUI = {
    Show = function() state.visible = true; main.Visible = true end,
    Hide = function() state.visible = false; main.Visible = false end,
    Toggle = function() state.visible = not state.visible; main.Visible = state.visible end,
    State = state,
}
