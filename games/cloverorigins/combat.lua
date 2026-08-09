--------------------------------------------------------------------------------
--// combat.lua — Clover Origins
--// S01: Equip weapon V1
--// S02: Perform attack (burst)
--// S03: Auto skill
--// S04: Export ke Hub
--------------------------------------------------------------------------------
local H            = getgenv().Hub
local EngineConfig = H.EngineConfig
local State        = H.State
local API          = H.API
local allSkillKeys = H.allSkillKeys
local LocalPlayer  = H.LocalPlayer

-- [S01] EQUIP WEAPON V1
--------------------------------------------------------------------------------
local function equipWeaponV1()
    if not EngineConfig.SelectedWeapon or EngineConfig.SelectedWeapon == "None" then return end
    if not State.Character or not State.Humanoid or State.Humanoid.Health <= 0 then return end

    local weaponInChar = State.Character:FindFirstChild(EngineConfig.SelectedWeapon)
    if not weaponInChar then
        local weaponInBackpack = LocalPlayer.Backpack:FindFirstChild(EngineConfig.SelectedWeapon)
        if weaponInBackpack then
            task.spawn(function()
                if State.Humanoid and State.Humanoid.Health > 0 then
                    State.Humanoid:EquipTool(weaponInBackpack)
                end
            end)
        end
    end
end

-- [S02] BURST ATTACK
--------------------------------------------------------------------------------
local function PerformAttack(target)
    if not EngineConfig.UseAttack or not target then return end

    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    local targetHum  = target:FindFirstChild("Humanoid")
    if not (targetRoot and targetHum and targetHum.Health > 0) then return end

    local weapon = EngineConfig.SelectedWeaponV2 or EngineConfig.SelectedWeapon
    if not weapon then return end

    local targetPosY     = math.floor(targetRoot.Position.Y * 100) + 2
    local lockedTarget   = target
    local currentMultiplier = EngineConfig.HitMultiplier or 10

    local hyperTargetPack = {}
    for i = 1, currentMultiplier do
        table.insert(hyperTargetPack, lockedTarget)
    end

    for i = 1, 5 do
        task.spawn(function()
            API.Combat:FireServer(weapon, hyperTargetPack, 5, 0, targetPosY)
        end)
    end
end

-- [S03] AUTO SKILL
--------------------------------------------------------------------------------
local function useAutoSkills(target)
    if not EngineConfig.AutoSkill or not target or not API.Skills then return end

    local weaponName = EngineConfig.SelectedWeapon
    if not weaponName then return end

    local weaponObj = State.Character:FindFirstChild(weaponName)
                   or LocalPlayer.Backpack:FindFirstChild(weaponName)
    if not weaponObj then return end

    if tick() - State.LastSkill > 1.2 then
        State.LastSkill = tick()
        task.spawn(function()
            for _, key in pairs(allSkillKeys) do
                if not target.Parent or not target:FindFirstChild("Humanoid") then break end
                if target.Humanoid.Health <= 0 then break end

                if EngineConfig.EnabledSkills[key] and EngineConfig.AutoSkill then
                    local tRoot = target:FindFirstChild("HumanoidRootPart")
                    if not tRoot then break end

                    API.Skills:FireServer(weaponObj, key, "Begin", tRoot.Position)
                    task.wait(0.1)
                    API.Skills:FireServer(weaponObj, key, "End", tRoot.Position)
                    task.wait(0.2)
                end
            end
        end)
    end
end

-- [S04] EXPORT KE HUB
--------------------------------------------------------------------------------
H.equipWeaponV1 = equipWeaponV1
H.PerformAttack  = PerformAttack
H.useAutoSkills  = useAutoSkills
