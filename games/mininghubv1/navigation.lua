--------------------------------------------------------------------------------
-- Mining Hub V1 — navigation, NPC, GUI target, dan backpack
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub
local Workspace = Hub.Services.Workspace
local LocalPlayer = Hub.Services.LocalPlayer
local PlayerGui = Hub.Services.PlayerGui
local Remotes = Hub.Services.Remotes

local function findNPCTarget(keywords, isSell)
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("ProximityPrompt") then
            local parentName = object.Parent and object.Parent.Name or ""
            local grandParentName = object.Parent and object.Parent.Parent and object.Parent.Parent.Name or ""
            local fullText = (
                object.ObjectText .. " " ..
                object.ActionText .. " " ..
                object.Name .. " " ..
                parentName .. " " ..
                grandParentName
            ):lower()

            if not (isSell and fullText:find("crystal") and not fullText:find("buyer") and not fullText:find("sell")) then
                for _, keyword in ipairs(keywords) do
                    if fullText:find(keyword:lower()) then
                        local parent = object.Parent
                        local part = parent and (
                            parent:IsA("BasePart") and parent or parent:FindFirstChildWhichIsA("BasePart")
                        )
                        if part then
                            return part
                        end
                    end
                end
            end
        end
    end

    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("Model") or object:IsA("BasePart") then
            local name = object.Name:lower()
            if not (isSell and name:find("crystal") and not name:find("buyer") and not name:find("sell")) then
                for _, keyword in ipairs(keywords) do
                    if name:find(keyword:lower()) then
                        local part = object:IsA("BasePart") and object or (
                            object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
                        )
                        if part then
                            return part
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function teleportToNPC(keywords, remoteName, isSell)
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local targetPart = findNPCTarget(keywords, isSell)
    if not targetPart then
        warn("Target CFrame tidak ditemukan:", table.concat(keywords, ", "))
        return
    end

    if isSell then
        root.CFrame = targetPart.CFrame * CFrame.new(0, 1, 2.5)
    else
        root.CFrame = targetPart.CFrame * CFrame.new(0, 1, -2.5) * CFrame.Angles(0, math.rad(180), 0)
    end

    task.wait(0.2)

    local nearestPrompt
    local shortestDistance = 15

    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") and prompt.Parent and prompt.Parent:IsA("BasePart") then
            local distance = (prompt.Parent.Position - root.Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                nearestPrompt = prompt
            end
        end
    end

    if nearestPrompt and type(fireproximityprompt) == "function" then
        nearestPrompt.RequiresLineOfSight = false
        nearestPrompt.MaxActivationDistance = 9999
        task.wait(0.05)
        fireproximityprompt(nearestPrompt)
    elseif remoteName and Remotes:FindFirstChild(remoteName) then
        Remotes[remoteName]:FireServer()
    end
end

local function getTargetObject(path)
    local current = PlayerGui

    for _, name in ipairs(path) do
        current = current:FindFirstChild(name)
        if not current then
            return nil
        end
    end

    return current
end

local function isBackpackFull()
    local hud = PlayerGui:FindFirstChild("ExplorerHud")
    local panel = hud and hud:FindFirstChild("BackpackPanel")
    local valueLabel = panel and panel:FindFirstChild("Value")
    if not valueLabel then
        return false
    end

    local text = ""
    pcall(function()
        text = valueLabel.Text
    end)

    if not text or text == "" then
        pcall(function()
            text = tostring(valueLabel.Value)
        end)
    end

    if type(text) ~= "string" or text == "" then
        return false
    end

    local numbers = {}
    for numberText in string.gmatch(string.gsub(text, ",", ""), "%d+%.?%d*") do
        local number = tonumber(numberText)
        if number then
            table.insert(numbers, number)
        end
    end

    if #numbers >= 2 then
        return numbers[1] >= (numbers[2] - 1)
    end

    return false
end

Hub.Functions.FindNPCTarget = findNPCTarget
Hub.Functions.TeleportToNPC = teleportToNPC
Hub.Functions.GetTargetObject = getTargetObject
Hub.Functions.IsBackpackFull = isBackpackFull