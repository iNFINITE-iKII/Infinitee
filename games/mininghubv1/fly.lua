--------------------------------------------------------------------------------
-- Mining Hub V1 — fly controller
--------------------------------------------------------------------------------

local Hub = getgenv().MiningHub
local LocalPlayer = Hub.Services.LocalPlayer
local Workspace = Hub.Services.Workspace
local RunService = Hub.Services.RunService
local UserInputService = Hub.Services.UserInputService
local Vector3_new = Vector3.new
local CFrame_lookAt = CFrame.lookAt
local state = Hub.State

local bodyVelocity
local bodyGyro

local function updateFly()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    if state.IsFlying then
        if not bodyVelocity or not bodyVelocity.Parent then
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3_new(9e9, 9e9, 9e9)
            bodyVelocity.Velocity = Vector3_new(0, 0, 0)
            bodyVelocity.Parent = root
        end

        if not bodyGyro or not bodyGyro.Parent then
            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.P = 9e4
            bodyGyro.MaxTorque = Vector3_new(9e9, 9e9, 9e9)
            bodyGyro.CFrame = root.CFrame
            bodyGyro.Parent = root
        end
    else
        if bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
        if bodyGyro then
            bodyGyro:Destroy()
            bodyGyro = nil
        end
    end
end

Hub.Functions.UpdateFly = updateFly

table.insert(Hub.Connections, LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if state.IsFlying then
        updateFly()
    end
end))

table.insert(Hub.Connections, RunService.Heartbeat:Connect(function()
    if not state.IsFlying then
        return
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not bodyVelocity or not bodyGyro then
        return
    end

    if state.IsFarmOn then
        bodyGyro.MaxTorque = Vector3_new(0, 0, 0)
        bodyVelocity.Velocity = Vector3_new(0, 0, 0)
        return
    end

    local camera = Workspace.CurrentCamera
    local moveDirection = Vector3_new(0, 0, 0)

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveDirection += camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveDirection -= camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveDirection -= camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveDirection += camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        moveDirection += Vector3_new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        moveDirection -= Vector3_new(0, 1, 0)
    end

    bodyGyro.MaxTorque = Vector3_new(9e9, 9e9, 9e9)

    if moveDirection.Magnitude > 0 then
        moveDirection = moveDirection.Unit
        bodyVelocity.Velocity = moveDirection * state.FlySpeed
        bodyGyro.CFrame = CFrame_lookAt(root.Position, root.Position + moveDirection)
    else
        bodyVelocity.Velocity = Vector3_new(0, 0, 0)
        bodyGyro.CFrame = root.CFrame
    end
end))