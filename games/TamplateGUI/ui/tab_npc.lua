--------------------------------------------------------------------------------
--// ui/tab_npc.lua — Tab NPC: Forge Bypass & NPC Utility Access
-- Berisi shortcut untuk membuka berbagai UI NPC di dalam game Iron Soul.
-- Menggunakan ProximityPrompt bypass (fireproximityprompt).
-- NPC list berdasarkan scan: Sec Island 1 & Sec Island 2
--------------------------------------------------------------------------------
local H            = getgenv().XiFilTemplateGUI_Hub
local _G           = getgenv().XiFilTemplateGUI_G
local Services     = H.Services
local LocalPlayer  = H.LocalPlayer
local CombatEngine = H.CombatEngine
local CustomNotify = H.CustomNotify
local CreateTab    = H.CreateTab
local CreateSection = H.CreateSection
local CreateButton  = H.CreateButton

local Workspace = game:GetService("Workspace")

-- ── Tab ───────────────────────────────────────────────────────────────────────
local NpcPage = CreateTab("🏪 NPC", "tabNpc")

-- ══════════════════════════════════════════════════════════════════════════════
-- HELPER: Buat key pencarian dari ProximityPrompt + 5 level ancestor
-- ══════════════════════════════════════════════════════════════════════════════
local function makeKey(v)
    local parts = { v.ObjectText or "", v.ActionText or "", v.Name or "" }
    local p = v.Parent
    for _ = 1, 5 do
        if p and p ~= Workspace then
            table.insert(parts, p.Name)
            p = p.Parent
        else
            break
        end
    end
    return string.lower(table.concat(parts, " "))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- HELPER: TP ke NPC di dalam container tertentu dan buka GUI-nya
-- containerName = nama child langsung dari Workspace (misal "World" / "Island2" / "Forge")
-- ══════════════════════════════════════════════════════════════════════════════
local function TPAndOpenInContainer(containerName, keywords, notifTitle)
    local char   = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp    = char:WaitForChild("HumanoidRootPart")
    local root   = Workspace:FindFirstChild(containerName)
    if not root then
        CustomNotify(notifTitle, "⚠️ Container '" .. containerName .. "' tidak ditemukan!", 4)
        return
    end
    local prompt = nil
    for _, v in pairs(root:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local key = makeKey(v)
            for _, kw in ipairs(keywords) do
                if key:find(kw, 1, true) then
                    prompt = v
                    break
                end
            end
            if prompt then break end
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
        CustomNotify(notifTitle, "NPC tidak ditemukan di " .. containerName .. "!", 4)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- HELPER: Forge Bypass (TP + paksa buka ScreenForging)
-- ══════════════════════════════════════════════════════════════════════════════
local function ForgeBypass(containerName, fallbackCFrame, notifLabel)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart")
    local root = Workspace:FindFirstChild(containerName)
    local prompt = nil
    if root then
        for _, v in pairs(root:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                local key = makeKey(v)
                if key:find("forge", 1, true) or key:find("craft", 1, true) then
                    prompt = v
                    break
                end
            end
        end
    end
    if prompt and prompt.Parent:IsA("BasePart") then
        CombatEngine.ResetPhysics(hrp)
        hrp.CFrame = prompt.Parent.CFrame * CFrame.new(0, 2, 0)
        task.wait(0.3)
        if fireproximityprompt then fireproximityprompt(prompt) end
    else
        CombatEngine.ResetPhysics(hrp)
        hrp.CFrame = fallbackCFrame
        task.wait(0.3)
    end
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
    CustomNotify(notifLabel, "TP & Bypass Forge Berhasil.", 3)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SECTION 1: SEC ISLAND 1
-- NPC scan: Workspace > World / Workspace > Forge
-- ══════════════════════════════════════════════════════════════════════════════
CreateSection(NpcPage, "🏝️ Sec Island 1", "secIsland1")

-- [04] Forge — Workspace > Forge > ForgingFurnace > Forge > Root
CreateButton(NpcPage, "🔨 Forge (Island 1)", function()
    ForgeBypass("Forge", CFrame.new(57.8, 40.6, 15.4), "⚒️ FORGE ISL.1")
end, "btnForgeIsland1")

-- [01] The Guide — keyword: guide
CreateButton(NpcPage, "🧭 The Guide", function()
    TPAndOpenInContainer("World", {"guide"}, "THE GUIDE")
end, "btnGuideIsland1")

-- [07] Enchantment — keyword: enchant
CreateButton(NpcPage, "🔮 Enchantment", function()
    TPAndOpenInContainer("World", {"enchant"}, "ENCHANTMENT")
end, "btnEnchantIsland1")

-- [08] Merchant — keyword: merchant
CreateButton(NpcPage, "💎 Merchant", function()
    TPAndOpenInContainer("World", {"merchant"}, "MERCHANT")
end, "btnMerchantIsland1")

-- [05] Grocery — keyword: grocery / grocer
CreateButton(NpcPage, "🛒 Grocery", function()
    TPAndOpenInContainer("World", {"grocery", "grocer", "coinstore"}, "GROCERY")
end, "btnGroceryIsland1")

-- [09] Pets Upgrade — keyword: upgrade / pet
CreateButton(NpcPage, "🐾 Pets Upgrade", function()
    TPAndOpenInContainer("World", {"upgrade", "petupgrade", "dialogpet"}, "PET UPGRADE")
end, "btnPetUpgradeIsland1")

-- [06] Pet Expedition — keyword: expedition
CreateButton(NpcPage, "🏕️ Pet Expedition", function()
    TPAndOpenInContainer("World", {"expedition", "boardinteract"}, "PET EXPEDITION")
end, "btnPetExpIsland1")

-- [10] Bless Equipments — keyword: bless
CreateButton(NpcPage, "✨ Bless Equipments", function()
    TPAndOpenInContainer("World", {"bless", "stoneinteract"}, "BLESS EQUIPMENT")
end, "btnBlessIsland1")

-- [02] Spin Wheel — tidak ada keyword terdeteksi, pakai nama
CreateButton(NpcPage, "🎰 Spin Wheel", function()
    TPAndOpenInContainer("World", {"spinwheelinteract", "spinwheel"}, "SPIN WHEEL")
end, "btnSpinWheelIsland1")

-- [13] Fast Pass — tidak ada keyword terdeteksi, pakai ActionText
CreateButton(NpcPage, "🎫 Fast Pass", function()
    TPAndOpenInContainer("World", {"fastpass", "fast pass", "fastpassinteract"}, "FAST PASS")
end, "btnFastPassIsland1")

-- [03] NPC Tempa (DialogEquipmentForgeNpc / Talk) — tidak ada keyword terdeteksi, pakai nama ancestor
CreateButton(NpcPage, "🗡️ NPC Tempa (Talk)", function()
    TPAndOpenInContainer("World", {"dialogequipmentforge", "equipmentforge"}, "NPC TEMPA")
end, "btnForgeNpcIsland1")

-- [15] Cave Talk (DialogCaveNpc) — tidak ada keyword terdeteksi, pakai nama ancestor
CreateButton(NpcPage, "🗿 Cave Talk", function()
    TPAndOpenInContainer("World", {"cave", "dialogcave", "cavenpc"}, "CAVE TALK")
end, "btnCaveTalkIsland1")

-- [11] Tips Fist — tidak ada keyword terdeteksi, pakai nama
CreateButton(NpcPage, "👊 Tips Fist", function()
    TPAndOpenInContainer("World", {"tipsfist", "tipsinteract_fist", "fist"}, "TIPS FIST")
end, "btnTipsFistIsland1")

-- [12] Tips Bow — tidak ada keyword terdeteksi, pakai nama
CreateButton(NpcPage, "🏹 Tips Bow", function()
    TPAndOpenInContainer("World", {"tipsbow", "tipsinteract_bow", "bow"}, "TIPS BOW")
end, "btnTipsBowIsland1")

-- [14] Tips Scroll — tidak ada keyword terdeteksi, pakai nama
CreateButton(NpcPage, "📜 Tips Scroll", function()
    TPAndOpenInContainer("World", {"tipsscroll", "tipsinteract_scroll", "scroll"}, "TIPS SCROLL")
end, "btnTipsScrollIsland1")

-- ══════════════════════════════════════════════════════════════════════════════
-- SECTION 2: SEC ISLAND 2
-- NPC scan: Workspace > Island2
-- ══════════════════════════════════════════════════════════════════════════════
CreateSection(NpcPage, "🏝️ Sec Island 2", "secIsland2")

-- [03] Forge — Workspace > Island2 > Art > ForgingFurnace > Forge > Root
CreateButton(NpcPage, "🔨 Forge (Island 2)", function()
    ForgeBypass("Island2", CFrame.new(9975.8, 15.1, -57.3), "⚒️ FORGE ISL.2")
end, "btnForgeIsland2")

-- [01] The Guide — keyword: guide
CreateButton(NpcPage, "🧭 The Guide", function()
    TPAndOpenInContainer("Island2", {"guide"}, "THE GUIDE")
end, "btnGuideIsland2")

-- [09] Enchantment — keyword: enchant
CreateButton(NpcPage, "🔮 Enchantment", function()
    TPAndOpenInContainer("Island2", {"enchant"}, "ENCHANTMENT")
end, "btnEnchantIsland2")

-- [05] Merchant — keyword: merchant
CreateButton(NpcPage, "💎 Merchant", function()
    TPAndOpenInContainer("Island2", {"merchant"}, "MERCHANT")
end, "btnMerchantIsland2")

-- [07] Grocery — keyword: grocery / grocer
CreateButton(NpcPage, "🛒 Grocery", function()
    TPAndOpenInContainer("Island2", {"grocery", "grocer", "coinstore"}, "GROCERY")
end, "btnGroceryIsland2")

-- [08] Pets Upgrade — keyword: upgrade / pet
CreateButton(NpcPage, "🐾 Pets Upgrade", function()
    TPAndOpenInContainer("Island2", {"upgrade", "petupgrade", "dialogpet"}, "PET UPGRADE")
end, "btnPetUpgradeIsland2")

-- [06] Pet Expedition — keyword: expedition
CreateButton(NpcPage, "🏕️ Pet Expedition", function()
    TPAndOpenInContainer("Island2", {"expedition", "boardinteract"}, "PET EXPEDITION")
end, "btnPetExpIsland2")

-- [10] Bless Equipments — keyword: bless
CreateButton(NpcPage, "✨ Bless Equipments", function()
    TPAndOpenInContainer("Island2", {"bless", "stoneinteract"}, "BLESS EQUIPMENT")
end, "btnBlessIsland2")

-- [04] Spin Wheel — tidak ada keyword terdeteksi, pakai nama
CreateButton(NpcPage, "🎰 Spin Wheel", function()
    TPAndOpenInContainer("Island2", {"spinwheelinteract", "spinwheel"}, "SPIN WHEEL")
end, "btnSpinWheelIsland2")

-- [02] NPC Tempa (DialogEquipmentForgeNpc / Talk) — tidak ada keyword terdeteksi, pakai nama ancestor
CreateButton(NpcPage, "🗡️ NPC Tempa (Talk)", function()
    TPAndOpenInContainer("Island2", {"dialogequipmentforge", "equipmentforge"}, "NPC TEMPA")
end, "btnForgeNpcIsland2")
