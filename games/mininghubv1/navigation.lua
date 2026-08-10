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

local function parseBackpackCapacity(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local normalized = text:gsub(",", ""):gsub("%s+", " ")
    local upper = normalized:upper()
    if upper:match("^FULL!?$") or upper:match("^FULL[%s!%.%-]*$") then
        return nil, nil, true
    end

    local current, capacity = normalized:match("([%d%.]+)%s*/%s*([%d%.]+)")

    if not current or not capacity then
        current, capacity = normalized:match("([%d%.]+)%s+[Oo][Ff]%s+([%d%.]+)")
    end

    current = tonumber(current)
    capacity = tonumber(capacity)
    if not current or not capacity or capacity <= 0 then
        return nil
    end

    return current, capacity, current >= (capacity - 1)
end

local function isBackpackFull(current, capacity, full)
    return full == true or (current ~= nil and capacity ~= nil and full == true)
end

local function getGuiText(object)
    if not object then
        return nil
    end

    local text
    pcall(function()
        if type(object.Text) == "string" then
            text = object.Text
        elseif object:IsA("ValueBase") then
            text = tostring(object.Value)
        end
    end)
    return text
end

local function getBackpackStatus()
    local hud = PlayerGui:FindFirstChild("ExplorerHud")
    local panel = hud and hud:FindFirstChild("BackpackPanel")
    if not panel then
        return {
            Full = false,
            Text = "",
        }
    end

    -- Jalur utama mengikuti live backpack GUI:
    -- PlayerGui > ExplorerHud > BackpackPanel > Value.Text
    local valueLabel = panel:FindFirstChild("Value")
    local valueText = getGuiText(valueLabel)
    local current, capacity, full = parseBackpackCapacity(valueText)
    if valueText and valueText ~= "" then
        return {
            Full = isBackpackFull(current, capacity, full),
            Current = current,
            Capacity = capacity,
            Text = valueText,
        }
    end

    local candidates = {}
    local seen = {}
    local function addCandidate(object)
        if object and not seen[object] then
            seen[object] = true
            table.insert(candidates, object)
        end
    end

    addCandidate(panel:FindFirstChild("Value"))
    for _, object in ipairs(panel:GetDescendants()) do
        local name = object.Name:lower()
        if name == "value"
            or name == "capacity"
            or name == "count"
            or name == "backpackvalue"
            or name == "backpackcapacity" then
            addCandidate(object)
        end
    end

    for _, object in ipairs(candidates) do
        local text = getGuiText(object)
        local current, capacity, full = parseBackpackCapacity(text)
        if text and text ~= "" then
            return {
                Full = isBackpackFull(current, capacity, full),
                Current = current,
                Capacity = capacity,
                Text = text,
            }
        end
    end

    return {
        Full = false,
        Text = "",
    }
end

local function isBackpackFull()
    return getBackpackStatus().Full
end

local function getBackpackStatusText()
    local status = getBackpackStatus()
    if status.Text and status.Text ~= "" then
        return status.Text
    end
    return "Unknown"
end

Hub.Functions.FindNPCTarget = findNPCTarget
Hub.Functions.TeleportToNPC = teleportToNPC
Hub.Functions.GetTargetObject = getTargetObject
Hub.Functions.IsBackpackFull = isBackpackFull
Hub.Functions.GetBackpackStatus = getBackpackStatus
Hub.Functions.GetBackpackStatusText = getBackpackStatusText