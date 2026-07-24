--------------------------------------------------------------------------------
--// ui/tab_npc.lua — Tab NPC: Forge Bypass & NPC Utility Access
-- Berisi shortcut untuk membuka berbagai UI NPC di dalam game Iron Soul.
-- Menggunakan ProximityPrompt bypass (fireproximityprompt).
--------------------------------------------------------------------------------
local H            = getgenv().Hub
local Services     = H.Services
local LocalPlayer  = H.LocalPlayer
local CombatEngine = H.CombatEngine
local CustomNotify = H.CustomNotify
local CreateTab           = H.CreateTab
local CreateSection       = H.CreateSection
local CreateButton        = H.CreateButton

local Workspace = game:GetService("Workspace")

-- ── Tab ───────────────────────────────────────────────────────────────────────
local NpcPage = CreateTab("🏪 NPC", "tabNpc")

-- ══════════════════════════════════════════════════════════════════════════════
-- HELPER: TP ke NPC dan buka GUI-nya via ProximityPrompt
-- ══════════════════════════════════════════════════════════════════════════════
local function TPAndOpenByKeyword(keywords, notifTitle)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart")
    local prompt = nil
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local txt = string.lower(v.ObjectText .. v.ActionText .. (v.Parent.Name))
            local matched = false
            for _, kw in ipairs(keywords) do
                if txt:find(kw) then matched = true; break end
            end
            if matched then prompt = v; break end
        end
    end
    if prompt and prompt.Parent:IsA("BasePart") then
        CombatEngine.ResetPhysics(hrp)
        hrp.CFrame = prompt.Parent.CFrame * CFrame.new(0, 2, 0)
        task.wait(0.3)
        if fireproximityprompt then
            fireproximityprompt(prompt)
            CustomNotify(notifTitle, "UI berhasil dibuka!", 3)
        else
            CustomNotify("⚠️ WARN", "Executor tidak support fireproximityprompt", 3)
        end
    else
        CustomNotify(notifTitle .. " ERROR", "NPC tidak ditemukan di dunia ini!", 4)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SECTION 1: UTILITAS TEMPA (Forge Bypass)
-- ══════════════════════════════════════════════════════════════════════════════
CreateSection(NpcPage, "Utilitas Tempa", "secForgeUtil")

CreateButton(NpcPage, "🔨 Buka Forge", function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart")
    local prompt = nil
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local txt = (v.ObjectText .. v.ActionText):lower()
            if v.Parent.Name:lower():match("forge") or txt:match("forge")
               or v.Parent.Name:lower():match("craft") or txt:match("craft") then
                prompt = v; break
            end
        end
    end
    if prompt and prompt.Parent:IsA("BasePart") then
        CombatEngine.ResetPhysics(hrp)
        hrp.CFrame = prompt.Parent.CFrame * CFrame.new(0, 2, 0)
        task.wait(0.3)
        if fireproximityprompt then fireproximityprompt(prompt) end
    else
        -- Fallback ke koordinat Forge default
        CombatEngine.ResetPhysics(hrp)
        hrp.CFrame = CFrame.new(122.5, 12, -45.8)
        task.wait(0.3)
    end
    -- Paksa buka ScreenForging jika ada
    pcall(function()
        local TaskRE = Services.ReplicatedStorage
            :WaitForChild("Framework"):WaitForChild("Features")
            :WaitForChild("TaskSystem"):WaitForChild("TaskRE")
        TaskRE:FireServer("UpdateTaskProgress", "OpenGUIWindow", "ScreenForging")
    end)
    pcall(function()
        local FUI = LocalPlayer.PlayerGui:FindFirstChild("ScreenForging")
                 or LocalPlayer.PlayerGui:FindFirstChild("ForgeGui")
        if FUI then
            for _, obj in pairs(FUI:GetChildren()) do
                if obj:IsA("Frame") then obj.Visible = true end
            end
        end
    end)
    CustomNotify("⚒️ FORGE", "TP & Bypass Forge Berhasil.", 3)
end, "btnForgeBypass")

-- ══════════════════════════════════════════════════════════════════════════════
-- SECTION 2: AKSES NPC UTILITAS
-- ══════════════════════════════════════════════════════════════════════════════
CreateSection(NpcPage, "Akses NPC Utilitas", "secNpcUtil")

CreateButton(NpcPage, "🔮 Buka Enchantment & Rune",
    function() TPAndOpenByKeyword({"enchant"}, "ENCHANTMENT") end,
    "btnOpenEnchant")

CreateButton(NpcPage, "🛒 Buka Toko Bahan",
    function() TPAndOpenByKeyword({"grocery", "grocer"}, "GROCERY") end,
    "btnOpenGrocery")

CreateButton(NpcPage, "🐾 Buka Upgrade Pet",
    function() TPAndOpenByKeyword({"pet", "upgrade", "petupgrade"}, "PET UPGRADE") end,
    "btnOpenPetUpgrade")

CreateButton(NpcPage, "🏕️ Buka Ekspedisi Pet",
    function() TPAndOpenByKeyword({"expedition", "petexp"}, "PET EXPEDITION") end,
    "btnOpenPetExp")

CreateButton(NpcPage, "✨ Buka Upgrade Equipment",
    function() TPAndOpenByKeyword({"bless", "blessing"}, "BLESS EQUIPMENT") end,
    "btnOpenBless")

CreateButton(NpcPage, "✨ Buka The Guide",
    function() TPAndOpenByKeyword({"guide", "the"}, "THE GUIDE") end,
    "btnOpenGuide")
