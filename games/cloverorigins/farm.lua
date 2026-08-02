--------------------------------------------------------------------------------
--// farm.lua — Clover Origins
--// S01: GetClosestTarget
--// S02: Heartbeat farm loop
--// S03: Quest repeat loop
--// S04: Export ke Hub
--------------------------------------------------------------------------------
local H             = getgenv().Hub
local EngineConfig  = H.EngineConfig
local State         = H.State
local API           = H.API
local TargetService = H.TargetService
local CachedFolders = H.CachedFolders
local Services      = H.Services
local LocalPlayer   = H.LocalPlayer
local CustomNotify  = function(...) if H.CustomNotify then H.CustomNotify(...) end end

-- Lazy-bind combat helpers (loaded sebelum farm.lua)
local function getEquipWeaponV1() return H.equipWeaponV1 end
local function getPerformAttack()  return H.PerformAttack  end
local function getUseAutoSkills()  return H.useAutoSkills  end

-- [S01] CLOSEST TARGET
--------------------------------------------------------------------------------
local function GetClosestTarget()
    if not State.Root or #State.TargetList == 0 then return nil end

    local nearestTarget   = nil
    local shortestDistance = math.huge

    local function process(candidate)
        if TargetService.IsAttackable(candidate, State.TargetList) then
            local dist = TargetService.GetDistance(State.Root, candidate.HumanoidRootPart)
            if dist < shortestDistance then
                shortestDistance = dist
                nearestTarget    = candidate
            end
        end
    end

    if #CachedFolders == 0 then TargetService.UpdateCache() end
    for i = 1, #CachedFolders do
        local folder = CachedFolders[i]
        if folder and folder.Parent then
            for _, child in ipairs(folder:GetChildren()) do
                process(child)
            end
        else
            TargetService.UpdateCache()
        end
    end

    for _, p in pairs(Services.Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            process(p.Character)
        end
    end

    return nearestTarget
end

-- [S02] HEARTBEAT FARM LOOP
--------------------------------------------------------------------------------
local lastSelectedQuest = EngineConfig.SelectedQuest

Services.RunService.Heartbeat:Connect(function()
    if not State.Root then
        State.LastTarget = nil
        return
    end

    -- Auto equip senjata saat AutoFarm aktif
    if EngineConfig.AutoFarm and EngineConfig.SelectedWeapon then
        local fn = getEquipWeaponV1()
        if fn then fn() end
    end

    -- Validasi target saat ini
    local isTargetValid = false
    if State.CurrentTarget and State.CurrentTarget.Parent
       and State.CurrentTarget:FindFirstChild("Humanoid") then
        local isAlive      = State.CurrentTarget.Humanoid.Health > 0
        local isStillInList = table.find(State.TargetList, State.CurrentTarget.Name)
        if isAlive and isStillInList then
            isTargetValid = true
        end
    end

    -- Cari target baru jika yang lama tidak valid
    if EngineConfig.AutoFarm and not isTargetValid then
        State.CurrentTarget = GetClosestTarget()
    end

    -- Auto Quest (fire)
    if EngineConfig.AutoQuest and EngineConfig.SelectedQuest then
        local hasQuest = LocalPlayer:FindFirstChild("CurrentQuest")
        if not hasQuest then
            API.Quest:FireServer("giveQuest", EngineConfig.SelectedQuest)
        end
    end

    -- Farm: gerak + serang
    if EngineConfig.AutoFarm and State.CurrentTarget then
        local targetRoot = State.CurrentTarget:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end

        -- Stop velocity
        State.Root.AssemblyLinearVelocity  = Vector3.zero
        State.Root.AssemblyAngularVelocity = Vector3.zero

        local goalCF = CFrame.lookAt(
            targetRoot.Position + Vector3.new(0, EngineConfig.Height, 0),
            targetRoot.Position
        )

        -- Pindahkan langsung dengan CFrame. Lerp membuat karakter masih
        -- beberapa frame berada di luar range Burst Attack.
        State.Root.CFrame = goalCF
        State.LastTarget  = State.CurrentTarget

        -- Hitung ulang setelah perpindahan agar Burst Attack tidak menunggu
        -- Heartbeat berikutnya hanya karena jarak sebelum teleport masih jauh.
        local dist = (State.Root.Position - targetRoot.Position).Magnitude

        -- Serang jika sudah cukup dekat
        if dist <= 15 then
            if tick() - State.LastAttack > EngineConfig.AttackDelay then
                State.LastAttack = tick()
                local atk = getPerformAttack()
                if atk then atk(State.CurrentTarget) end
                local skl = getUseAutoSkills()
                if skl then skl(State.CurrentTarget) end
            end
        else
            State.ComboCount = 1
        end
    else
        if State.LastTarget ~= nil then
            State.ComboCount = 1
            State.LastTarget = nil
        end
    end
end)

-- [S03] QUEST REPEAT LOOP
--------------------------------------------------------------------------------
task.spawn(function()
    while task.wait(1) do
        -- Backup equip
        if EngineConfig.AutoFarm then
            local fn = getEquipWeaponV1()
            if fn then fn() end
        end

        -- Quest switcher
        if EngineConfig.AutoQuest and EngineConfig.SelectedQuest
           and EngineConfig.SelectedQuest ~= "None" then

            local hasChanged = (EngineConfig.SelectedQuest ~= lastSelectedQuest)
            if hasChanged then
                API.Quest:FireServer("cancel")
                task.wait(0.5)
                API.Quest:FireServer("giveQuest", EngineConfig.SelectedQuest)
                lastSelectedQuest = EngineConfig.SelectedQuest
                CustomNotify("Quest Switched", "Pindah ke: " .. EngineConfig.SelectedQuest, 2)
            elseif not LocalPlayer:FindFirstChild("CurrentQuest") then
                API.Quest:FireServer("giveQuest", EngineConfig.SelectedQuest)
            end
        end
    end
end)

-- [S04] EXPORT KE HUB
--------------------------------------------------------------------------------
H.GetClosestTarget = GetClosestTarget
