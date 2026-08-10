--------------------------------------------------------------------------------
-- Mining Hub V1 — TemplateGUI adapter
-- Memetakan API tab lama ke builder UI TemplateGUI.
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub
local Template = env.XiFilTemplateGUI_Hub

if not Template or not Template.CreateTab then
    error("TemplateGUI belum siap sebelum adapter Mining Hub dimuat.")
end

local function normalizeOptions(value)
    if type(value) == "table" then
        return value[1]
    end
    return value
end

local function createParagraph(parent, options)
    local frame = Instance.new("Frame", parent)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel", frame)
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 14, 0, 7)
    title.Size = UDim2.new(1, -28, 0, 18)
    title.Font = Enum.Font.GothamBold
    title.Text = tostring(options.Title or "")
    title.TextColor3 = Template.GetThemeColor("Text")
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left

    local content = Instance.new("TextLabel", frame)
    content.BackgroundTransparency = 1
    content.Position = UDim2.new(0, 14, 0, 29)
    content.Size = UDim2.new(1, -28, 0, 28)
    content.Font = Enum.Font.Gotham
    content.Text = tostring(options.Content or "")
    content.TextColor3 = Color3.fromRGB(170, 170, 190)
    content.TextSize = 10
    content.TextWrapped = true
    content.TextXAlignment = Enum.TextXAlignment.Left
    content.TextYAlignment = Enum.TextYAlignment.Top

    local function resizeForContent(text)
        local lineCount = 1
        for _ in string.gmatch(tostring(text or ""), "\n") do
            lineCount += 1
        end

        local contentHeight = math.max(28, lineCount * 14)
        frame.Size = UDim2.new(1, 0, 0, contentHeight + 36)
        content.Size = UDim2.new(1, -28, 0, contentHeight)
    end

    resizeForContent(options.Content)

    local api = {}
    function api:Set(nextOptions)
        title.Text = tostring(nextOptions.Title or "")
        content.Text = tostring(nextOptions.Content or "")
        resizeForContent(nextOptions.Content)
    end
    return api
end

local function wrapTab(page)
    local tab = {}

    function tab:CreateSection(title)
        return Template.CreateSection(page, title)
    end

    function tab:CreateParagraph(options)
        return createParagraph(page, options)
    end

    function tab:CreateToggle(options)
        local api = Template.CreateToggleUI(
            page,
            options.Name,
            options.CurrentValue == true,
            options.Callback
        )
        function api:Set(value)
            api:SetValue(value)
        end
        return api
    end

    function tab:CreateInput(options)
        local default = options.CurrentValue or ""
        return Template.CreateInputUI(
            page,
            options.Name,
            default,
            false,
            options.Callback
        )
    end

    function tab:CreateDropdown(options)
        local current = normalizeOptions(options.CurrentOption) or options.Options[1]
        local api = Template.CreateDropdownUI(
            page,
            options.Name,
            options.Options,
            current,
            function(value)
                options.Callback({value})
            end
        )

        function api:Refresh(values, replaceCurrent)
            self:SetValues(values)
            if replaceCurrent and values[1] then
                self:SetValue(values[1])
            end
        end
        return api
    end

    function tab:CreateButton(options)
        return Template.CreateButton(page, options.Name, options.Callback)
    end

    return tab
end

Hub.UI.Window = Template.MainWindow
Hub.UI.CreateTab = function(name)
    return wrapTab(Template.CreateTab(name))
end
Hub.UI.Notify = function(options)
    Template.CustomNotify(
        options.Title or "Mining Hub",
        options.Content or "",
        options.Duration or 3
    )
end

Hub.TemplateGUI = Template
env.XiFilTemplateGUI_State = "running"

return Hub.UI.Window