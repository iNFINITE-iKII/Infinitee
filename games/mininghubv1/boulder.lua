--------------------------------------------------------------------------------
-- Mining Hub V1 — Boulder ESP, Rune Farm, dan Boulder Nuke Farm
-- UI tetap berada di tab Farm; modul ini hanya menyediakan state dan logic.
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub
local Workspace = Hub.Services.Workspace
local RunService = Hub.Services.RunService
local LocalPlayer = Hub.Services.LocalPlayer
local ReplicatedStorage = Hub.Services.ReplicatedStorage
local Remotes = Hub.Services.Remotes
local state = Hub.State

local decorations = Workspace:FindFirstChild("MountainDecorations")
local bouldersFolder = decorations and decorations:FindFirstChild("Boulders")
local digRequest = Remotes:FindFirstChild("DigRequest")

local BoulderDefinitions = {
    {Name = "Mossite", Color = Color3.fromRGB(100, 255, 100)},
    {Name = "Voltite", Color = Color3.fromRGB(0, 220, 255)},
    {Name = "Gildrite", Color = Color3.fromRGB(255, 215, 0)},
    {Name = "Rimeveil", Color = Color3.fromRGB(180, 220, 255)},
    {Name = "Nocturnite", Color = Color3.fromRGB(180, 50, 255)},
}

local activeESP = {}
local espConnection
local folderConnection
local descendantRemovingConnection

local function getBoulderName(model)
    return tostring(model:GetAttribute("BoulderName") or model.Name)
end

local function getRootPart(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getEquippedToolName()
    local character = LocalPlayer.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    return tool and tool.Name or "The Terminus"
end

local function getObjectPosition(object)
    if not object or not object.Parent then
        return nil
    end

    local ok, result = pcall(function()
        if object:IsA("BasePart") then
            return object.Position
        end
        return object:GetPivot().Position
    end)
    return ok and result or nil
end

local function getRuneObject(prompt)
    return prompt:FindFirstAncestorOfClass("Model")
        or prompt:FindFirstAncestorOfClass("BasePart")
        or prompt.Parent
end

local function findRunePrompt()
    local droppedRunes = Workspace:FindFirstChild("DroppedRunes")
    if droppedRunes then
        for _, item in ipairs(droppedRunes:GetDescendants()) do
            if item:IsA("ProximityPrompt") then
                return item
            end
        end
    end

    for _, item in ipairs(Workspace:GetChildren()) do
        if string.find(string.lower(item.Name), "rune") then
            local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                return prompt
            end
        end
    end

    return nil
end

local function cleanupESP(model)
    local record = activeESP[model]
    if not record then
        return
    end

    if record.Highlight then
        record.Highlight:Destroy()
    end
    if record.Billboard then
        record.Billboard:Destroy()
    end
    activeESP[model] = nil
end

local function applyESP(model)
    if not model or not model:IsA("Model") or activeESP[model] then
        return
    end

    local name = getBoulderName(model)
    local definition
    for _, item in ipairs(BoulderDefinitions) do
        if item.Name == name then
            definition = item
            break
        end
    end
    if not definition then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "MiningHub_BoulderESP"
    highlight.FillColor = definition.Color
    highlight.OutlineColor = definition.Color
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = model

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MiningHub_BoulderLabel"
    billboard.Size = UDim2.new(0, 200, 0, 42)
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.Parent = model

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.SourceSansBold
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextSize = 13
    label.Parent = billboard

    activeESP[model] = {
        Highlight = highlight,
        Billboard = billboard,
        Label = label,
        Name = name,
    }
end

local function updateESP()
    local character = LocalPlayer.Character
    local root = getRootPart(character)

    for model, record in pairs(activeESP) do
        if not model.Parent then
            cleanupESP(model)
        else
            local enabled = state.BoulderMasterESP
                and state.BoulderESPEnabled[record.Name] == true
            record.Highlight.Enabled = enabled
            record.Billboard.Enabled = enabled

            if enabled and root then
                local position = getObjectPosition(model)
                if position then
                    local distance = math.floor((root.Position - position).Magnitude)
                    local hp = model:GetAttribute("HP")
                    local maxHP = model:GetAttribute("MaxHP")
                    local hpText = "N/A"

                    if type(hp) == "number" and type(maxHP) == "number" and maxHP > 0 then
                        hpText = string.format(
                            "%.2fB / %.2fB (%d%%)",
                            hp / 1e9,
                            maxHP / 1e9,
                            math.floor((hp / maxHP) * 100)
                        )
                    elseif type(hp) == "number" then
                        hpText = string.format("%.2fB", hp / 1e9)
                    end

                    record.Label.Text = string.format(
                        "%s [%dm]\nHP: %s",
                        record.Name,
                        distance,
                        hpText
                    )
                end
            end
        end
    end
end

local function scanBoulders()
    if not bouldersFolder then
        local currentDecorations = Workspace:FindFirstChild("MountainDecorations")
        bouldersFolder = currentDecorations and currentDecorations:FindFirstChild("Boulders")
    end
    if not bouldersFolder then
        return
    end

    for _, item in ipairs(bouldersFolder:GetDescendants()) do
        if item:IsA("Model") then
            applyESP(item)
        end
    end
end

local function getNearestFarmTarget(root)
    local closest
    local shortest = math.huge

    for model, record in pairs(activeESP) do
        if model.Parent
            and state.BoulderFarmEnabled[record.Name] == true then
            local position = getObjectPosition(model)
            if position then
                local distance = (root.Position - position).Magnitude
                if distance < shortest then
                    closest = model
                    shortest = distance
                end
            end
        end
    end

    return closest
end

local function stopBoulderFarmLoop()
    if state.BoulderFarmTask then
        task.cancel(state.BoulderFarmTask)
        state.BoulderFarmTask = nil
    end
    state.BoulderCurrentTarget = nil
end

local function collectRune(root)
    if not state.IsRuneFarmOn then
        return false
    end

    local prompt = findRunePrompt()
    local runeObject = prompt and getRuneObject(prompt)
    if not prompt or not runeObject then
        return false
    end

    while state.IsRuneFarmOn and prompt.Parent and runeObject.Parent do
        local position = getObjectPosition(runeObject)
        if not position then
            break
        end

        root.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        pcall(function()
            prompt.HoldDuration = 0
        end)
        if type(fireproximityprompt) == "function" then
            pcall(fireproximityprompt, prompt)
        end
        RunService.Heartbeat:Wait()
    end

    return true
end

local function farmBoulder(root, character)
    local target = state.BoulderCurrentTarget
    if not target or not target.Parent then
        target = getNearestFarmTarget(root)
        state.BoulderCurrentTarget = target
    end
    if not target then
        return false
    end

    local position = getObjectPosition(target)
    if not position then
        state.BoulderCurrentTarget = nil
        return false
    end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end

    root.CFrame = CFrame.new(position + Vector3.new(0, 4.5, 0))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    if digRequest then
        local toolName = getEquippedToolName()
        for _ = 1, math.max(1, tonumber(state.BoulderPromptSpamCount) or 10) do
            pcall(function()
                digRequest:FireServer(toolName, position)
            end)
        end
    end

    task.wait(math.max(0, tonumber(state.BoulderFarmDelay) or 0.1))
    return true
end

local function startBoulderFarmLoop()
    stopBoulderFarmLoop()
    state.BoulderFarmTask = task.spawn(function()
        while state.IsBoulderFarmOn or state.IsRuneFarmOn do
            local character = LocalPlayer.Character
            local root = getRootPart(character)
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if not root or not humanoid or humanoid.Health <= 0 then
                task.wait(0.1)
                continue
            end

            if collectRune(root) then
                continue
            end

            if not state.IsBoulderFarmOn then
                task.wait(0.1)
                continue
            end

            if not farmBoulder(root, character) then
                scanBoulders()
                task.wait(0.2)
            end
        end

        state.BoulderFarmTask = nil
        state.BoulderCurrentTarget = nil
    end)
end

local function getBoulderSelectionData(key)
    local selected = key == "ESP" and state.BoulderESPEnabled or state.BoulderFarmEnabled
    local names, states, callbacks = {}, {}, {}

    for index, definition in ipairs(BoulderDefinitions) do
        names[index] = definition.Name
        states[index] = selected[definition.Name] == true
        callbacks[index] = function(value)
            selected[definition.Name] = value == true
        end
    end

    return names, states, callbacks
end

Hub.Data.Boulders = BoulderDefinitions
Hub.Functions.GetBoulderSelectionData = getBoulderSelectionData
Hub.Functions.ScanBoulders = scanBoulders
Hub.Functions.StartBoulderFarmLoop = startBoulderFarmLoop
Hub.Functions.StopBoulderFarmLoop = stopBoulderFarmLoop

scanBoulders()
if bouldersFolder then
    folderConnection = bouldersFolder.DescendantAdded:Connect(function(item)
        task.defer(function()
            if item:IsA("Model") then
                applyESP(item)
            end
        end)
    end)
end
descendantRemovingConnection = Workspace.DescendantRemoving:Connect(function(item)
    if activeESP[item] then
        cleanupESP(item)
    end
end)
espConnection = RunService.RenderStepped:Connect(updateESP)

return Hub.Data.Boulders