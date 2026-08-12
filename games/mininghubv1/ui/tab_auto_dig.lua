--------------------------------------------------------------------------------
-- Mining Hub V1 — tab Auto Dig
-- Integrasi referensi OMEGA GOD MODE ke sistem tab TemplateGUI.
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub
local state = Hub.State
local ui = Hub.UI
local services = Hub.Services

local Players = services.Players
local RunService = services.RunService
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = services.ReplicatedStorage
local player = Players.LocalPlayer
local toolName = "The Terminus"

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    or ReplicatedStorage:WaitForChild("Remotes", 3)
local remote = remotesFolder
    and (remotesFolder:FindFirstChild("DigRequest")
        or remotesFolder:WaitForChild("DigRequest", 3))

state.AutoDigEnabled = false
state.AutoDigWaypoints = {}
state.AutoDigIsNoclip = false
state.AutoDigActivatedFly = false
state.AutoDigLayerDelay = 0.01
state.AutoDigMoveSpeed = 0.05
state.AutoDigRadius = 1
state.AutoDigStepSize = 2
state.AutoDigForwardStep = 2
state.AutoDigSpeedHeight = 0
state.AutoDigNoclipConnection = nil
state.AutoDigTask = nil

local function setStatus(paragraph, title, status)
    paragraph:Set({
        Title = title,
        Content = "Remote: " .. (remote and "LINKED" or "NOT FOUND")
            .. "\nWaypoints: " .. #state.AutoDigWaypoints
            .. " | Status: " .. status,
    })
end

local function toggleNoclip(enabled)
    state.AutoDigIsNoclip = enabled == true
    if state.AutoDigNoclipConnection then
        state.AutoDigNoclipConnection:Disconnect()
        state.AutoDigNoclipConnection = nil
    end
    if not state.AutoDigIsNoclip then
        return
    end

    state.AutoDigNoclipConnection = RunService.Stepped:Connect(function()
        local character = player.Character
        if not character then
            return
        end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
end

local function setAutoDigFly(enabled)
    if enabled then
        if state.IsFlying then
            return
        end

        state.AutoDigActivatedFly = true
        if Hub.UI.FlyToggle then
            Hub.UI.FlyToggle:Set(true)
        else
            state.IsFlying = true
            Hub.Functions.UpdateFly()
        end
        return
    end

    if not state.AutoDigActivatedFly then
        return
    end

    state.AutoDigActivatedFly = false
    if Hub.UI.FlyToggle then
        Hub.UI.FlyToggle:Set(false)
    else
        state.IsFlying = false
        Hub.Functions.UpdateFly()
    end
end

local function equipTool()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local tool = player.Backpack:FindFirstChild(toolName)
    if humanoid and tool then
        humanoid:EquipTool(tool)
    end
end

local function numberValue(value, fallback, minimum)
    local result = tonumber(value) or fallback
    return minimum and math.max(minimum, result) or result
end

local function buildTargets(baseCFrame, radius, stepSize)
    local seen = {}
    local targets = {}
    for xOffset = -radius, radius do
        for yOffset = -radius, radius do
            if xOffset ^ 2 + yOffset ^ 2 <= radius ^ 2 then
                local position = (
                    baseCFrame * CFrame.new(xOffset * stepSize, yOffset * stepSize, 0)
                ).Position
                local x = math.floor(position.X / stepSize + 0.5) * stepSize
                local y = math.floor(position.Y / stepSize + 0.5) * stepSize
                local z = math.floor(position.Z / stepSize + 0.5) * stepSize
                local key = string.format("%.3f,%.3f,%.3f", x, y, z)
                if not seen[key] then
                    seen[key] = true
                    table.insert(targets, Vector3.new(x, y, z))
                end
            end
        end
    end
    return targets
end

local function fireTarget(position)
    if not remote or not remote.Parent then
        remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
        remote = remotesFolder and remotesFolder:FindFirstChild("DigRequest")
    end
    if remote then
        task.spawn(function()
            pcall(function()
                remote:FireServer(toolName, position)
            end)
        end)
    end
end

local function stopDigging()
    state.AutoDigEnabled = false
    if state.AutoDigTask then
        task.cancel(state.AutoDigTask)
        state.AutoDigTask = nil
    end
    setAutoDigFly(false)
end

local function executeDigging()
    local layerDelay = numberValue(state.AutoDigLayerDelay, 0.01, 0)
    local moveSpeed = numberValue(state.AutoDigMoveSpeed, 0.05, 0)
    local radius = math.floor(numberValue(state.AutoDigRadius, 1, 1))
    local stepSize = numberValue(state.AutoDigStepSize, 2, 0.1)
    local forwardStep = numberValue(state.AutoDigForwardStep, 2, 0.1)
    local speedHeight = tonumber(state.AutoDigSpeedHeight) or 0
    equipTool()

    while state.AutoDigEnabled do
        for _, waypoint in ipairs(state.AutoDigWaypoints) do
            if not state.AutoDigEnabled then
                break
            end

            local baseCFrame = waypoint.CFrame
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local targetCFrame = baseCFrame * CFrame.new(0, speedHeight, 0)
            if root then
                if moveSpeed <= 0 then
                    root.CFrame = targetCFrame
                else
                    local tween = TweenService:Create(
                        root,
                        TweenInfo.new(moveSpeed, Enum.EasingStyle.Linear),
                        {CFrame = targetCFrame}
                    )
                    tween:Play()
                    tween.Completed:Wait()
                end
            end

            for index, position in ipairs(buildTargets(baseCFrame, radius, stepSize)) do
                if not state.AutoDigEnabled then
                    break
                end
                fireTarget(position)
                if index % 12 == 0 then
                    RunService.Heartbeat:Wait()
                end
            end

            waypoint.CFrame = baseCFrame * CFrame.new(0, 0, -forwardStep)
            if layerDelay <= 0 then
                RunService.Heartbeat:Wait()
            else
                task.wait(layerDelay)
            end
        end
    end
end

local tab = ui.CreateTab("Auto Dig", 4483345998)
tab:CreateSection("Status & Controls")
local statusParagraph = tab:CreateParagraph({
    Title = "OMEGA GOD MODE V15",
    Content = "Remote: " .. (remote and "LINKED" or "NOT FOUND")
        .. "\nWaypoints: 0 | Status: IDLE",
})

local startToggle
startToggle = tab:CreateToggle({
    Name = "AWAKEN GOD MODE",
    CurrentValue = false,
    Callback = function(enabled)
        if not enabled then
            stopDigging()
            setStatus(statusParagraph, "OMEGA GOD MODE V15", "STOPPED")
            return
        end
        if #state.AutoDigWaypoints == 0 then
            startToggle:Set(false)
            ui.Notify({
                Title = "No Waypoint",
                Content = "Set ascension point terlebih dahulu.",
                Duration = 2,
            })
            return
        end
        state.AutoDigEnabled = true
        setAutoDigFly(true)
        setStatus(statusParagraph, "OMEGA GOD MODE V15 — ACTIVE", "DIGGING")
        state.AutoDigTask = task.spawn(executeDigging)
    end,
})

tab:CreateToggle({
    Name = "Noclip",
    CurrentValue = false,
    Callback = toggleNoclip,
})
tab:CreateButton({
    Name = "SET ASCENSION POINT",
    Callback = function()
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local camera = workspace.CurrentCamera
        if not root or not camera then
            return
        end
        state.AutoDigWaypoints = {
            {CFrame = CFrame.new(root.Position, root.Position + camera.CFrame.LookVector)},
        }
        setStatus(statusParagraph, "OMEGA GOD MODE V15", "READY")
        ui.Notify({
            Title = "Point Set",
            Content = "Ascension point tersimpan.",
            Duration = 2,
        })
    end,
})
tab:CreateButton({
    Name = "Clear Waypoints",
    Callback = function()
        stopDigging()
        state.AutoDigWaypoints = {}
        setStatus(statusParagraph, "OMEGA GOD MODE V15", "IDLE")
    end,
})

tab:CreateSection("Digging Settings")
tab:CreateInput({
    Name = "Delay Antar Layer (detik)",
    CurrentValue = tostring(state.AutoDigLayerDelay),
    Callback = function(text)
        local value = tonumber(text)
        if value then state.AutoDigLayerDelay = math.max(0, value) end
    end,
})
tab:CreateInput({
    Name = "Kecepatan Jalan (0 = instant)",
    CurrentValue = tostring(state.AutoDigMoveSpeed),
    Callback = function(text)
        local value = tonumber(text)
        if value then state.AutoDigMoveSpeed = math.max(0, value) end
    end,
})
tab:CreateInput({
    Name = "Radius Bor (Lingkaran)",
    CurrentValue = tostring(state.AutoDigRadius),
    Callback = function(text)
        local value = tonumber(text)
        if value then state.AutoDigRadius = math.max(1, math.floor(value)) end
    end,
})
tab:CreateInput({
    Name = "Jarak Antar Blok",
    CurrentValue = tostring(state.AutoDigStepSize),
    Callback = function(text)
        local value = tonumber(text)
        if value then state.AutoDigStepSize = math.max(0.1, value) end
    end,
})
tab:CreateInput({
    Name = "Jarak Maju Per Layer",
    CurrentValue = tostring(state.AutoDigForwardStep),
    Callback = function(text)
        local value = tonumber(text)
        if value then state.AutoDigForwardStep = math.max(0.1, value) end
    end,
})
tab:CreateInput({
    Name = "Speed Height (Y-Offset)",
    CurrentValue = tostring(state.AutoDigSpeedHeight),
    Callback = function(text)
        local value = tonumber(text)
        if value then state.AutoDigSpeedHeight = value end
    end,
})