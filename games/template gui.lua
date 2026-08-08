--[[
    IronSoul GUI Template
    Satu file mandiri untuk dijadikan dasar UI.
    Isi: window GUI, Floating Button, tab Tampilan, Font, dan Efek.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then return end

local playerGui = player:WaitForChild("PlayerGui")
local GUI_NAME = "IronSoulTemplateGUI"
local oldGui = playerGui:FindFirstChild(GUI_NAME)
if oldGui then oldGui:Destroy() end

local state = {
    activeTab = "Tampilan",
    visible = true,
    theme = "Cyan",
    transparency = 0.08,
    rounded = true,
    compact = false,
    font = "Gotham",
    fontSize = 14,
    bold = false,
    effect = "Aurora",
    particles = true,
    glow = true,
    animations = true,
}

local themes = {
    Cyan = {accent = Color3.fromRGB(0, 220, 255), accentDark = Color3.fromRGB(0, 95, 120), background = Color3.fromRGB(7, 10, 18), panel = Color3.fromRGB(14, 19, 30), surface = Color3.fromRGB(22, 29, 43)},
    Violet = {accent = Color3.fromRGB(167, 112, 255), accentDark = Color3.fromRGB(86, 46, 145), background = Color3.fromRGB(12, 9, 20), panel = Color3.fromRGB(24, 18, 36), surface = Color3.fromRGB(38, 27, 55)},
    Ember = {accent = Color3.fromRGB(255, 142, 65), accentDark = Color3.fromRGB(143, 63, 25), background = Color3.fromRGB(20, 10, 7), panel = Color3.fromRGB(35, 19, 13), surface = Color3.fromRGB(54, 28, 18)},
    Emerald = {accent = Color3.fromRGB(62, 225, 155), accentDark = Color3.fromRGB(22, 112, 77), background = Color3.fromRGB(6, 16, 14), panel = Color3.fromRGB(12, 29, 25), surface = Color3.fromRGB(18, 46, 38)},
}

local fonts = {
    Gotham = Enum.Font.Gotham,
    SourceSans = Enum.Font.SourceSans,
    Code = Enum.Font.Code,
    Arcade = Enum.Font.Arcade,
    Fantasy = Enum.Font.Fantasy,
}

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local references = {
    panels = {},
    surfaces = {},
    accents = {},
    accentTexts = {},
    labels = {},
    buttons = {},
    strokes = {},
    corners = {},
}

local function remember(list, object)
    table.insert(list, object)
    return object
end

local function tween(object, properties, duration)
    if not state.animations then
        for property, value in pairs(properties) do object[property] = value end
        return
    end
    TweenService:Create(object, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), properties):Play()
end

local function currentTheme()
    return themes[state.theme] or themes.Cyan
end

local function addCorner(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = object
    remember(references.corners, corner)
    return corner
end

local function addStroke(object, color, transparency, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.new(1, 1, 1)
    stroke.Transparency = transparency or 0
    stroke.Thickness = thickness or 1
    stroke.Parent = object
    remember(references.strokes, stroke)
    return stroke
end

local function makeFrame(parent, name, size, position)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Size = size
    frame.Position = position or UDim2.fromOffset(0, 0)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    return frame
end

local function makeLabel(parent, text, size, position, textSize, color)
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.BackgroundTransparency = 1
    label.Size = size
    label.Position = position or UDim2.fromOffset(0, 0)
    label.Text = text
    label.TextSize = textSize or state.fontSize
    label.TextColor3 = color or Color3.fromRGB(225, 231, 240)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Font = fonts[state.font]
    label.Parent = parent
    remember(references.labels, label)
    return label
end

local function makeButton(parent, text, size, position)
    local button = Instance.new("TextButton")
    button.Name = "Button"
    button.Size = size
    button.Position = position or UDim2.fromOffset(0, 0)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Text = text
    button.TextSize = state.fontSize
    button.TextColor3 = Color3.fromRGB(225, 231, 240)
    button.Font = fonts[state.font]
    button.Parent = parent
    remember(references.buttons, button)
    return button
end

local function setPageHeader(parent, title, subtitle)
    makeLabel(parent, title, UDim2.new(1, -28, 0, 32), UDim2.fromOffset(14, 12), 22, Color3.fromRGB(245, 248, 255)).Font = Enum.Font.GothamBold
    makeLabel(parent, subtitle, UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 43), 12, Color3.fromRGB(145, 158, 180))
end

local function addSection(parent, title, subtitle, y)
    local section = makeFrame(parent, "Section", UDim2.new(1, -28, 0, 62), UDim2.fromOffset(14, y))
    section.BackgroundColor3 = currentTheme().panel
    remember(references.panels, section)
    addCorner(section, state.rounded and 10 or 2)
    addStroke(section, currentTheme().accentDark, 0.55, 1)
    makeLabel(section, title, UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 8), 14, Color3.fromRGB(238, 242, 250)).Font = Enum.Font.GothamMedium
    makeLabel(section, subtitle, UDim2.new(1, -24, 0, 19), UDim2.fromOffset(12, 32), 11, Color3.fromRGB(137, 151, 174))
    return section
end

local function addToggle(parent, title, subtitle, defaultValue, callback, y)
    local row = makeFrame(parent, "ToggleRow", UDim2.new(1, -28, 0, 57), UDim2.fromOffset(14, y))
    row.BackgroundColor3 = currentTheme().surface
    remember(references.surfaces, row)
    addCorner(row, state.rounded and 9 or 2)

    makeLabel(row, title, UDim2.new(1, -82, 0, 22), UDim2.fromOffset(12, 7), 13, Color3.fromRGB(236, 240, 247)).Font = Enum.Font.GothamMedium
    makeLabel(row, subtitle, UDim.new(1, -82, 0, 18), UDim2.fromOffset(12, 29), 10, Color3.fromRGB(133, 147, 169))

    local track = makeButton(row, "", UDim2.fromOffset(42, 22), UDim2.new(1, -56, 0.5, -11))
    addCorner(track, 12)
    local thumb = Instance.new("Frame")
    thumb.Name = "Thumb"
    thumb.Size = UDim2.fromOffset(16, 16)
    thumb.BorderSizePixel = 0
    thumb.Parent = track
    addCorner(thumb, 8)

    local value = defaultValue
    local function render()
        local t = currentTheme()
        track.BackgroundColor3 = value and t.accentDark or Color3.fromRGB(49, 58, 73)
        thumb.BackgroundColor3 = value and t.accent or Color3.fromRGB(156, 166, 181)
        tween(thumb, {Position = value and UDim2.new(1, -19, 0.5, -8) or UDim2.fromOffset(3, 3)}, 0.15)
    end
    track.MouseButton1Click:Connect(function()
        value = not value
        render()
        if callback then callback(value) end
    end)
    render()
    return row
end

local function addChoice(parent, title, subtitle, options, initial, callback, y)
    local row = makeFrame(parent, "ChoiceRow", UDim2.new(1, -28, 0, 57), UDim2.fromOffset(14, y))
    row.BackgroundColor3 = currentTheme().surface
    remember(references.surfaces, row)
    addCorner(row, state.rounded and 9 or 2)
    makeLabel(row, title, UDim2.new(0.48, 0, 0, 22), UDim2.fromOffset(12, 7), 13, Color3.fromRGB(236, 240, 247)).Font = Enum.Font.GothamMedium
    makeLabel(row, subtitle, UDim2.new(0.48, 0, 0, 18), UDim2.fromOffset(12, 29), 10, Color3.fromRGB(133, 147, 169))

    local choice = makeButton(row, tostring(initial), UDim2.new(0.42, -4, 0, 34), UDim2.new(0.58, 0, 0.5, -17))
    choice.TextColor3 = currentTheme().accent
    choice.TextXAlignment = Enum.TextXAlignment.Center
    choice.BackgroundColor3 = currentTheme().background
    addCorner(choice, state.rounded and 8 or 2)
    addStroke(choice, currentTheme().accentDark, 0.35, 1)

    local index = 1
    for i, option in ipairs(options) do if option == initial then index = i end end
    choice.MouseButton1Click:Connect(function()
        index = index % #options + 1
        local selected = options[index]
        choice.Text = tostring(selected)
        if callback then callback(selected) end
    end)
    return row
end

local function addSlider(parent, title, subtitle, minimum, maximum, initial, callback, y)
    local row = makeFrame(parent, "SliderRow", UDim2.new(1, -28, 0, 72), UDim2.fromOffset(14, y))
    row.BackgroundColor3 = currentTheme().surface
    remember(references.surfaces, row)
    addCorner(row, state.rounded and 9 or 2)
    makeLabel(row, title, UDim2.new(0.68, 0, 0, 22), UDim2.fromOffset(12, 7), 13, Color3.fromRGB(236, 240, 247)).Font = Enum.Font.GothamMedium
    makeLabel(row, subtitle, UDim2.new(0.68, 0, 0, 17), UDim2.fromOffset(12, 29), 10, Color3.fromRGB(133, 147, 169))

    local valueLabel = makeLabel(row, tostring(initial), UDim2.fromOffset(54, 25), UDim2.new(1, -67, 0, 10), 12, currentTheme().accent)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Font = Enum.Font.GothamBold
    local bar = makeFrame(row, "Bar", UDim2.new(1, -24, 0, 5), UDim2.fromOffset(12, 56))
    bar.BackgroundColor3 = Color3.fromRGB(56, 65, 82)
    addCorner(bar, 4)
    local fill = makeFrame(bar, "Fill", UDim2.new((initial - minimum) / (maximum - minimum), 0, 1, 0))
    fill.BackgroundColor3 = currentTheme().accent
    addCorner(fill, 4)
    local knob = Instance.new("TextButton")
    knob.Name = "Knob"
    knob.Text = ""
    knob.AutoButtonColor = false
    knob.Size = UDim2.fromOffset(16, 16)
    knob.Position = UDim2.new((initial - minimum) / (maximum - minimum), -8, 0.5, -8)
    knob.BackgroundColor3 = currentTheme().accent
    knob.Parent = bar
    addCorner(knob, 8)

    local dragging = false
    local function setFromX(x)
        local ratio = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local value = math.floor(minimum + (maximum - minimum) * ratio + 0.5)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, -8, 0.5, -8)
        valueLabel.Text = tostring(value)
        if callback then callback(value) end
    end
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then setFromX(input.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    return row
end

local background = makeFrame(gui, "Background", UDim2.fromScale(1, 1))
background.BackgroundTransparency = 1
background.ZIndex = 0

local main = makeFrame(gui, "MainWindow", UDim2.fromOffset(720, 470), UDim2.new(0.5, -360, 0.5, -235))
main.BackgroundColor3 = currentTheme().background
main.ZIndex = 5
remember(references.panels, main)
addCorner(main, state.rounded and 14 or 2)
addStroke(main, currentTheme().accentDark, 0.18, 1)

local sidebar = makeFrame(main, "Sidebar", UDim2.fromOffset(178, 470))
sidebar.BackgroundColor3 = currentTheme().panel
sidebar.ZIndex = 6
remember(references.panels, sidebar)
addCorner(sidebar, state.rounded and 14 or 2)

local brand = makeLabel(sidebar, "IRONSOUL", UDim2.new(1, -28, 0, 30), UDim2.fromOffset(14, 17), 19, currentTheme().accent)
brand.Font = Enum.Font.GothamBold
remember(references.accentTexts, brand)
local brandSub = makeLabel(sidebar, "GUI TEMPLATE  /  V1", UDim2.new(1, -28, 0, 18), UDim2.fromOffset(15, 45), 9, Color3.fromRGB(125, 140, 163))
brandSub.Font = Enum.Font.Code

local nav = makeFrame(sidebar, "Navigation", UDim2.new(1, -20, 0, 150), UDim2.fromOffset(10, 92))
nav.BackgroundTransparency = 1
local tabButtons = {}
local pages = {}
local tabs = {"Tampilan", "Font", "Efek"}

local content = makeFrame(main, "Content", UDim2.new(1, -194, 1, -58), UDim2.fromOffset(184, 58))
content.BackgroundTransparency = 1
content.ZIndex = 6

local function makePage(name)
    local page = makeFrame(content, name .. "Page", UDim2.fromScale(1, 1))
    page.BackgroundTransparency = 1
    page.Visible = false
    page.ZIndex = 7
    pages[name] = page
    return page
end

for index, name in ipairs(tabs) do
    local tab = makeButton(nav, name, UDim2.new(1, 0, 0, 38), UDim2.fromOffset(0, (index - 1) * 44))
    tab.TextXAlignment = Enum.TextXAlignment.Left
    tab.TextSize = 12
    tab.ZIndex = 8
    addCorner(tab, state.rounded and 8 or 2)
    tabButtons[name] = tab
end

local displayPage = makePage("Tampilan")
setPageHeader(displayPage, "Tampilan", "Atur warna, bentuk, dan kepadatan panel.")
addChoice(displayPage, "Tema warna", "Aksen utama seluruh GUI", {"Cyan", "Violet", "Ember", "Emerald"}, state.theme, function(value) state.theme = value; applyAppearance() end, 78)
addSlider(displayPage, "Transparansi", "Kejelasan panel utama", 0, 35, math.floor(state.transparency * 100), function(value) state.transparency = value / 100; applyAppearance() end, 143)
addToggle(displayPage, "Sudut membulat", "Gunakan radius lembut pada komponen", state.rounded, function(value) state.rounded = value; applyAppearance() end, 223)
addToggle(displayPage, "Mode compact", "Kurangi ukuran area konten", state.compact, function(value) state.compact = value; applyAppearance() end, 288)

local fontPage = makePage("Font")
setPageHeader(fontPage, "Font", "Atur karakter teks dan keterbacaan.")
addChoice(fontPage, "Keluarga font", "Klik untuk berpindah pilihan", {"Gotham", "SourceSans", "Code", "Arcade", "Fantasy"}, state.font, function(value) state.font = value; applyTypography() end, 78)
addSlider(fontPage, "Ukuran font", "Skala teks seluruh GUI", 10, 20, state.fontSize, function(value) state.fontSize = value; applyTypography() end, 143)
addToggle(fontPage, "Teks tebal", "Perkuat hierarki judul dan tombol", state.bold, function(value) state.bold = value; applyTypography() end, 223)

local effectPage = makePage("Efek")
setPageHeader(effectPage, "Efek", "Tambahkan suasana tanpa mengganggu kontrol.")
addChoice(effectPage, "Latar belakang", "Klik untuk mengganti efek", {"Aurora", "Grid", "None"}, state.effect, function(value) state.effect = value; renderEffects() end, 78)
addToggle(effectPage, "Partikel ambient", "Gerakan kecil di belakang window", state.particles, function(value) state.particles = value; renderEffects() end, 143)
addToggle(effectPage, "Glow aksen", "Sorot lembut pada garis dan tombol", state.glow, function(value) state.glow = value; applyAppearance() end, 208)
addToggle(effectPage, "Animasi transisi", "Gunakan perpindahan yang halus", state.animations, function(value) state.animations = value end, 273)

local topbar = makeFrame(main, "Topbar", UDim2.new(1, -178, 0, 58), UDim2.fromOffset(178, 0))
topbar.BackgroundColor3 = currentTheme().panel
topbar.ZIndex = 7
local topTitle = makeLabel(topbar, "Interface settings", UDim2.new(0.7, 0, 0, 22), UDim2.fromOffset(18, 11), 14, Color3.fromRGB(238, 242, 250))
topTitle.Font = Enum.Font.GothamMedium
makeLabel(topbar, "TEMPLATE / READY TO CUSTOMIZE", UDim2.new(0.7, 0, 0, 15), UDim2.fromOffset(18, 33), 9, Color3.fromRGB(126, 141, 164))
local closeButton = makeButton(topbar, "×", UDim2.fromOffset(32, 32), UDim2.new(1, -44, 0.5, -16))
closeButton.TextSize = 22
closeButton.TextXAlignment = Enum.TextXAlignment.Center
addCorner(closeButton, state.rounded and 8 or 2)
closeButton.MouseButton1Click:Connect(function() main.Visible = false; state.visible = false end)

local statusLine = makeFrame(main, "StatusLine", UDim2.new(1, -194, 0, 2), UDim2.new(0, 184, 1, -2))
statusLine.BackgroundColor3 = currentTheme().accent
statusLine.ZIndex = 10
remember(references.accents, statusLine)

local floating = makeButton(gui, "IS", UDim2.fromOffset(54, 54), UDim2.new(1, -78, 1, -78))
floating.BackgroundColor3 = currentTheme().accentDark
floating.TextColor3 = currentTheme().accent
floating.TextSize = 16
floating.ZIndex = 20
addCorner(floating, 27)
addStroke(floating, currentTheme().accent, state.glow and 0.15 or 0.7, 1)
floating.MouseButton1Click:Connect(function()
    state.visible = not state.visible
    if state.visible then
        main.Visible = true
        main.Size = UDim2.fromOffset(650, 420)
        tween(main, {Size = UDim2.fromOffset(720, 470)}, 0.24)
    else
        main.Visible = false
    end
end)

local dragStart, startPosition, dragging = nil, nil, false
topbar.InputBegan:Connect(function(input)
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
    local selectedFont = fonts[state.font] or Enum.Font.Gotham
    for _, object in ipairs(references.labels) do
        if object and object.Parent then
            object.Font = state.bold and Enum.Font.GothamBold or selectedFont
            object.TextSize = math.clamp(state.fontSize, 10, 20)
        end
    end
    for _, object in ipairs(references.buttons) do
        if object and object.Parent then
            object.Font = state.bold and Enum.Font.GothamBold or selectedFont
            object.TextSize = math.clamp(state.fontSize, 10, 20)
        end
    end
end

function applyAppearance()
    local theme = currentTheme()
    for _, object in ipairs(references.panels) do if object and object.Parent then object.BackgroundColor3 = theme.panel end end
    for _, object in ipairs(references.surfaces) do if object and object.Parent then object.BackgroundColor3 = theme.surface end end
    for _, object in ipairs(references.accents) do if object and object.Parent then object.BackgroundColor3 = theme.accent end end
    for _, object in ipairs(references.accentTexts) do if object and object.Parent then object.TextColor3 = theme.accent end end
    if main and main.Parent then
        main.BackgroundColor3 = theme.background
        main.BackgroundTransparency = state.transparency
    end
    if sidebar and sidebar.Parent then sidebar.BackgroundColor3 = theme.panel end
    if topbar and topbar.Parent then topbar.BackgroundColor3 = theme.panel end
    if floating and floating.Parent then floating.BackgroundColor3 = theme.accentDark; floating.TextColor3 = theme.accent end
    if statusLine and statusLine.Parent then statusLine.BackgroundColor3 = theme.accent end
    for _, button in pairs(tabButtons) do
        button.BackgroundColor3 = button:GetAttribute("Active") and theme.accentDark or theme.surface
        button.TextColor3 = button:GetAttribute("Active") and theme.accent or Color3.fromRGB(158, 171, 192)
    end
    for _, stroke in ipairs(references.strokes) do
        if stroke and stroke.Parent then stroke.Color = state.glow and theme.accentDark or Color3.fromRGB(60, 70, 87); stroke.Transparency = state.glow and 0.35 or 0.75 end
    end
    for _, corner in ipairs(references.corners) do
        if corner and corner.Parent then corner.CornerRadius = UDim.new(0, state.rounded and 9 or 2) end
    end
    content.Size = state.compact and UDim2.new(1, -194, 1, -72) or UDim2.new(1, -194, 1, -58)
    applyTypography()
    renderEffects()
end

function renderEffects()
    for _, child in ipairs(background:GetChildren()) do child:Destroy() end
    local theme = currentTheme()
    if state.effect == "Aurora" then
        local wash = makeFrame(background, "AuroraWash", UDim2.fromScale(1, 1))
        wash.BackgroundColor3 = theme.accentDark
        wash.BackgroundTransparency = 0.92
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, theme.accent), ColorSequenceKeypoint.new(0.5, theme.background), ColorSequenceKeypoint.new(1, theme.accentDark)})
        gradient.Rotation = 25
        gradient.Parent = wash
    elseif state.effect == "Grid" then
        for x = 0, 24 do
            local line = makeFrame(background, "GridLine", UDim2.fromOffset(1, 900), UDim2.new(x / 24, 0, 0, 0))
            line.BackgroundColor3 = theme.accent
            line.BackgroundTransparency = 0.94
        end
        for y = 0, 14 do
            local line = makeFrame(background, "GridLine", UDim2.fromOffset(1400, 1), UDim2.new(0, 0, y / 14, 0))
            line.BackgroundColor3 = theme.accent
            line.BackgroundTransparency = 0.94
        end
    end
    if state.particles then
        for i = 1, 18 do
            local dot = makeFrame(background, "Particle", UDim2.fromOffset(math.random(2, 5), math.random(2, 5)), UDim2.new(math.random(), 0, math.random(), 0))
            dot.BackgroundColor3 = theme.accent
            dot.BackgroundTransparency = math.random(35, 75) / 100
            addCorner(dot, 8)
            if state.animations then
                local destination = UDim2.new(math.random(), 0, math.random(), 0)
                TweenService:Create(dot, TweenInfo.new(math.random(5, 10), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position = destination}):Play()
            end
        end
    end
end

local function setActiveTab(name)
    state.activeTab = name
    for tabName, button in pairs(tabButtons) do
        local active = tabName == name
        button:SetAttribute("Active", active)
        button.BackgroundColor3 = active and currentTheme().accentDark or currentTheme().surface
        button.TextColor3 = active and currentTheme().accent or Color3.fromRGB(158, 171, 192)
        pages[tabName].Visible = active
    end
end

for name, button in pairs(tabButtons) do
    button.MouseButton1Click:Connect(function() setActiveTab(name) end)
end

setActiveTab("Tampilan")
applyTypography()
applyAppearance()
renderEffects()

-- Hook opsional untuk script lain yang ingin membuka atau menyembunyikan GUI.
_G.IronSoulTemplateGUI = {
    Show = function() state.visible = true; main.Visible = true end,
    Hide = function() state.visible = false; main.Visible = false end,
    Toggle = function() floating:Activate() end,
    State = state,
}
