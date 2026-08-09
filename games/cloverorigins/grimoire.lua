--------------------------------------------------------------------------------
--// grimoire.lua — Clover Origins
--// S01: Auto Spin (Reroll Grimoire)
--// S02: Auto Broom Quest
--// S03: Export ke Hub
--------------------------------------------------------------------------------
local H            = getgenv().Hub
local EngineConfig = H.EngineConfig
local API          = H.API
local State        = H.State
local allGrimoire  = H.allGrimoire
local LocalPlayer  = H.LocalPlayer
local CustomNotify = function(...) if H.CustomNotify then H.CustomNotify(...) end end

-- [S01] AUTO SPIN (REROLL GRIMOIRE)
--------------------------------------------------------------------------------
local function getOwnedGrimoire()
    local locations = {LocalPlayer.Backpack, State.Character}
    for _, loc in pairs(locations) do
        if loc then
            for _, name in pairs(allGrimoire) do
                local found = loc:FindFirstChild(name)
                if found then return found end
            end
        end
    end
    return nil
end

task.spawn(function()
    local lastGrimoireName = ""

    while task.wait(1.2) do
        if EngineConfig.AutoSpin then
            local grimoire = getOwnedGrimoire()

            if grimoire then
                -- Cek apakah ini target yang dicari?
                if EngineConfig.TargetGrimoires[grimoire.Name] then
                    EngineConfig.AutoSpin = false
                    if H.CO_RerollToggle then H.CO_RerollToggle:SetValue(false) end
                    CustomNotify("✅ BERHASIL", "Dapat target: " .. grimoire.Name, 5)
                    continue
                end

                -- Jeda jika nama sama (menunggu replikasi server)
                if grimoire.Name == lastGrimoireName then
                    task.wait(0.8)
                end

                lastGrimoireName = grimoire.Name

                -- Spin
                API.Spin:FireServer("PreSpinChoice", "Grimoire", "Reroll")
                task.wait(0.5)
                API.Spin:FireServer("Grimoire")
                task.wait(1.2)
            else
                API.Spin:FireServer("Grimoire")
                task.wait(2.0)
            end
        end
    end
end)

-- [S02] AUTO BROOM QUEST
--------------------------------------------------------------------------------
local function RunBroomQuest()
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Root      = Character:WaitForChild("HumanoidRootPart", 5)
    local QuestEvent = H.API.Quest

    if not Root then
        EngineConfig.AutoBroom = false
        if H.CO_BroomToggle then H.CO_BroomToggle:SetValue(false) end
        return
    end

    QuestEvent:FireServer("cancel")
    task.wait(0.5)
    if not EngineConfig.AutoBroom then return end

    QuestEvent:FireServer("giveQuest", "BroomQuest")
    task.wait(0.5)
    if not EngineConfig.AutoBroom then return end

    local BroomFolder = workspace:FindFirstChild("BroomQuestCircles")
    if not BroomFolder then
        warn("[XiFil-CO] Folder BroomQuestCircles tidak ditemukan!")
        EngineConfig.AutoBroom = false
        if H.CO_BroomToggle then H.CO_BroomToggle:SetValue(false) end
        return
    end

    for i = 1, 16 do
        if not EngineConfig.AutoBroom then break end

        local targetCircle = BroomFolder:FindFirstChild(tostring(i))
        if targetCircle then
            local targetPart = targetCircle:IsA("BasePart")
                and targetCircle
                or targetCircle:FindFirstChildOfClass("BasePart")

            if targetPart then
                Root.AssemblyLinearVelocity  = Vector3.zero
                Root.AssemblyAngularVelocity = Vector3.zero
                Root.CFrame = targetPart.CFrame * CFrame.new(0, 3, 0)
                task.wait(0.6)
            end
        else
            warn("[XiFil-CO] Circle " .. i .. " tidak ditemukan, lanjut.")
        end
    end

    EngineConfig.AutoBroom = false
    if H.CO_BroomToggle then H.CO_BroomToggle:SetValue(false) end
    CustomNotify("🧹 BROOM QUEST", "Selesai! Semua circle sudah dikunjungi.", 3)
end

-- [S03] EXPORT KE HUB
--------------------------------------------------------------------------------
H.RunBroomQuest = RunBroomQuest
