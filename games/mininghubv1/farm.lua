--------------------------------------------------------------------------------
-- Mining Hub V1 — target scanner dan farm loop
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub
local Workspace = Hub.Services.Workspace
local RunService = Hub.Services.RunService
local LocalPlayer = Hub.Services.LocalPlayer
local Remotes = Hub.Services.Remotes
local state = Hub.State
local cache = Hub.Cache
local stats = Hub.Stats
local config = Hub.Config
local Vector3_new = Vector3.new
local CFrame_lookAt = CFrame.lookAt

local Things = Workspace:WaitForChild("Things", 5)
local crystalsFolder = Things and Things:WaitForChild("Crystals", 5) or nil

local function getDroppedFolder()
    return Workspace:FindFirstChild("DroppedCrystals")
end

local function getAttribute(object, name)
    if not cache.Attribute[object] then
        cache.Attribute[object] = {}
    end

    if cache.Attribute[object][name] == nil then
        cache.Attribute[object][name] = object:GetAttribute(name)
    end

    return cache.Attribute[object][name]
end

local function getUniqueAttributes(name, prefix, suffix)
    local results = {"All"}
    local seen = {}

    local function scanFolder(folder)
        if not folder then
            return
        end

        for _, object in ipairs(folder:GetChildren()) do
            local attribute = getAttribute(object, name)
            if attribute then
                local value = tostring(attribute)
                if not seen[value] then
                    seen[value] = true
                    table.insert(results, (prefix or "") .. value .. (suffix or ""))
                end
            end
        end
    end

    scanFolder(crystalsFolder)
    scanFolder(getDroppedFolder())
    table.sort(results)
    return results
end

local function getUniqueCrystalNames(folder, filterTier)
    local names = {"All"}
    local seen = {}

    if folder then
        for _, object in ipairs(folder:GetChildren()) do
            local crystalName = getAttribute(object, "CrystalName") or object.Name
            local tierName = getAttribute(object, "TierName") or "Unknown"
            if (filterTier == "All" or tierName == filterTier) and not seen[crystalName] then
                seen[crystalName] = true
                table.insert(names, tostring(crystalName))
            end
        end
    end

    table.sort(names)
    return names
end

local function matchesFilters(object)
    if state.SelectedSize ~= "All" then
        local size = getAttribute(object, "SizeClass")
        if not size or ("[" .. tostring(size) .. "]" ~= state.SelectedSize) then
            return false
        end
    end

    if state.SelectedWeight ~= "All" and state.SelectedWeight ~= "MAX" then
        local weight = tonumber(getAttribute(object, "WeightKg"))
        local range = config.WeightRanges[state.SelectedWeight]
        if not weight or not range or weight < range[1] or weight > range[2] then
            return false
        end
    end

    if state.SelectedValue ~= "All" then
        local value = tonumber(getAttribute(object, "Value"))
        local range = config.ValueRanges[state.SelectedValue]
        if not value or not range or value < range[1] or value > range[2] then
            return false
        end
    end

    return true
end

local function updateTargetCache()
    table.clear(cache.ValidTargets)
    cache.PoolIndex = 0

    local function processFolder(folder, selectedName)
        if not folder then
            return
        end

        for _, object in ipairs(folder:GetChildren()) do
            local crystalName = tostring(getAttribute(object, "CrystalName") or object.Name)
            local tierName = tostring(getAttribute(object, "TierName") or "Unknown")
            local validName = selectedName == "All" or crystalName == selectedName
            local validTier = state.SelectedTier == "All" or tierName == state.SelectedTier

            if validName and validTier and matchesFilters(object) then
                local prompt = object:FindFirstChildWhichIsA("ProximityPrompt", true)
                local part = object:IsA("BasePart") and object or object:FindFirstChildWhichIsA("BasePart", true)

                if prompt and part then
                    cache.PoolIndex += 1
                    if not cache.TargetPool[cache.PoolIndex] then
                        cache.TargetPool[cache.PoolIndex] = {}
                    end

                    local entry = cache.TargetPool[cache.PoolIndex]
                    entry.Obj = object
                    entry.Part = part
                    entry.Prompt = prompt
                    table.insert(cache.ValidTargets, entry)
                end
            end
        end
    end

    processFolder(crystalsFolder, state.SelectedCrystalName)
    processFolder(getDroppedFolder(), state.SelectedDroppedName)
end

local function resetFireStats()
    stats.Attempts = 0
    stats.LocalSuccess = 0
    stats.ServerSuccess = 0
end

local function updateFireStatus()
    local localRate = stats.Attempts > 0 and math.floor((stats.LocalSuccess / stats.Attempts) * 100 + 0.5) or 0
    local serverRate = stats.LocalSuccess > 0 and math.floor((stats.ServerSuccess / stats.LocalSuccess) * 100 + 0.5) or 0
    local lockStatus = state.IsTargetLocked and "[LOCKED]" or "[AUTO-SWITCH]"
    local line1 = "Nuke: " .. localRate .. "% | Server Hit: " .. serverRate .. "% [" ..
        stats.ServerSuccess .. "/" .. stats.LocalSuccess .. "]"
    local line2 = "Targets: " .. #cache.ValidTargets .. " | Mode: " .. lockStatus

    if state.NukeStatsParagraph then
        state.NukeStatsParagraph:Set({
            Title = "Nuke Stats & Status",
            Content = line1 .. "\n" .. line2,
        })
    end
end

local function firePromptBurst(prompt)
    if type(fireproximityprompt) ~= "function" then
        return false
    end

    stats.Attempts += 1
    task.spawn(function()
        for _ = 1, state.PromptSpamCount do
            pcall(fireproximityprompt, prompt)
        end
    end)

    stats.LocalSuccess += 1
    updateFireStatus()
    return true
end

local function instantTeleport(root, targetPosition)
    local offsetPosition = targetPosition + Vector3_new(0, state.SpeedHeight, 0)
    root.AssemblyLinearVelocity = Vector3_new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3_new(0, 0, 0)
    root.CFrame = CFrame_lookAt(offsetPosition, targetPosition)
end

local function applyNoclip(character)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end

local function acquireTarget(root)
    if state.IsTargetLocked
        and state.CurrentTarget
        and state.CurrentTarget.Parent
        and state.CurrentPrompt
        and state.CurrentPrompt.Parent
        and state.CurrentPrompt.Enabled then
        return true
    end

    local rootPosition = root.Position
    local now = os.clock()
    local closestDistance = math.huge
    local bestEntry

    for _, entry in ipairs(cache.ValidTargets) do
        local object = entry.Obj
        local prompt = entry.Prompt
        if object and object.Parent and prompt and prompt:IsDescendantOf(Workspace) and prompt.Enabled then
            if not cache.BlacklistedCrystals[object] or now >= cache.BlacklistedCrystals[object] then
                local distance = (rootPosition - entry.Part.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    bestEntry = entry
                end
            end
        end
    end

    if not bestEntry then
        return false
    end

    state.CurrentTarget = bestEntry.Obj
    state.CurrentPart = bestEntry.Part
    state.CurrentPrompt = bestEntry.Prompt
    pcall(function()
        state.CurrentPrompt.RequiresLineOfSight = false
        state.CurrentPrompt.MaxActivationDistance = math.huge
        state.CurrentPrompt.HoldDuration = 0
    end)

    return true
end

local function stopFarmLoop()
    state.IsFarmOn = false
    if state.FarmTask then
        task.cancel(state.FarmTask)
        state.FarmTask = nil
    end

    state.CurrentTarget = nil
    state.CurrentPart = nil
    state.CurrentPrompt = nil
    table.clear(cache.BlacklistedCrystals)

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        root.AssemblyLinearVelocity = Vector3_new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3_new(0, 0, 0)
    end
end

local function startFarmLoop()
    if state.FarmTask then
        task.cancel(state.FarmTask)
    end

    state.IsFarmOn = true
    state.FarmTask = task.spawn(function()
        while state.IsFarmOn do
            local character = LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChild("Humanoid")

            if not root or not humanoid or humanoid.Health <= 0 then
                task.wait(0.1)
                continue
            end

            if state.IsAutoSellOn and Hub.Functions.IsBackpackFull() then
                root.AssemblyLinearVelocity = Vector3_new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3_new(0, 0, 0)
                Remotes:WaitForChild("GoHome"):FireServer("sell")
                task.wait(1)
                Remotes:WaitForChild("SellRequest"):FireServer("all")
                task.wait(1.5)
                continue
            end

            if #cache.ValidTargets == 0 then
                updateTargetCache()
                if #cache.ValidTargets == 0 then
                    root.AssemblyLinearVelocity = Vector3_new(0, 0, 0)
                    root.AssemblyAngularVelocity = Vector3_new(0, 0, 0)
                    task.wait(0.2)
                    continue
                end
            end

            if acquireTarget(root) then
                applyNoclip(character)
                instantTeleport(root, state.CurrentPart.Position)

                if state.FarmSpeedMs <= 0 then
                    RunService.Heartbeat:Wait()
                else
                    task.wait(state.FarmSpeedMs / 1000)
                end

                if state.CurrentTarget and state.CurrentTarget.Parent and state.CurrentPrompt and state.CurrentPrompt.Enabled then
                    firePromptBurst(state.CurrentPrompt)
                    stats.ServerSuccess += 1
                end

                if not state.IsTargetLocked and state.CurrentTarget then
                    cache.BlacklistedCrystals[state.CurrentTarget] = os.clock() + state.BlacklistDuration
                end
            else
                root.AssemblyLinearVelocity = Vector3_new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3_new(0, 0, 0)
                table.clear(cache.BlacklistedCrystals)
                updateTargetCache()
                task.wait(0.05)
            end

            local now = os.clock()
            for object, expiry in pairs(cache.BlacklistedCrystals) do
                if now >= expiry then
                    cache.BlacklistedCrystals[object] = nil
                end
            end
        end
    end)
end

local function switchTarget()
    if state.CurrentTarget then
        cache.BlacklistedCrystals[state.CurrentTarget] = os.clock() + (state.BlacklistDuration * 4)
    end

    state.CurrentTarget = nil
    state.CurrentPart = nil
    state.CurrentPrompt = nil
    updateTargetCache()
end

local function refreshTargetData()
    table.clear(cache.Attribute)
    updateTargetCache()
    return {
        Sizes = getUniqueAttributes("SizeClass", "[", "]"),
        Tiers = getUniqueAttributes("TierName"),
        Crystals = getUniqueCrystalNames(crystalsFolder, state.SelectedTier),
    Dropped = getUniqueCrystalNames(getDroppedFolder(), "All"),
    }
end

Hub.Data.Targets = {
    GetSizes = function() return getUniqueAttributes("SizeClass", "[", "]") end,
    GetTiers = function() return getUniqueAttributes("TierName") end,
    GetCrystals = function(tier) return getUniqueCrystalNames(crystalsFolder, tier) end,
    GetDropped = function() return getUniqueCrystalNames(getDroppedFolder(), "All") end,
}

Hub.Functions.UpdateTargetCache = updateTargetCache
Hub.Functions.RefreshTargetData = refreshTargetData
Hub.Functions.ResetFireStats = resetFireStats
Hub.Functions.UpdateFireStatus = updateFireStatus
Hub.Functions.StartFarmLoop = startFarmLoop
Hub.Functions.StopFarmLoop = stopFarmLoop
Hub.Functions.SwitchTarget = switchTarget
Hub.Functions.FirePromptBurst = firePromptBurst

Hub.Data.TargetFolders = {
    Crystals = function() return crystalsFolder end,
    Dropped = getDroppedFolder,
}