--------------------------------------------------------------------------------
--// ui/tab_forge.lua — S23 Tab 7: NPC Utilities
--------------------------------------------------------------------------------
local H            = getgenv().Hub
local EngineConfig = H.EngineConfig
local Services     = H.Services
local LocalPlayer  = H.LocalPlayer
local Workspace    = H.Workspace
local ForgeRF      = H.ForgeRF
local CombatEngine = H.CombatEngine
local CustomNotify = H.CustomNotify
local CreateTab     = H.CreateTab
local CreateSection = H.CreateSection
local CreateButton  = H.CreateButton

-- [S23] TAB 7 — NPC UTILITIES
--------------------------------------------------------------------------------
local ForgePage = CreateTab("🏪 NPC", "tabForge")

-- Patch QTE Forge agar auto-complete (tidak berubah)
local ForgeUtil = require(Services.ReplicatedStorage:WaitForChild("Framework"):WaitForChild("Features"):WaitForChild("ForgeSystem"):WaitForChild("ForgeUtil"))
if not _G.OriginalQTE then _G.OriginalQTE = ForgeUtil.QTE end
ForgeUtil.QTE = function(...)
    local args = {...}; local data = nil
    for _, v in pairs(args) do if type(v) == "table" and v.UUID then data = v; break end end
    if data then
        task.spawn(function()
            for _=1,1 do ForgeRF:InvokeServer("QTE",{UUID=data.UUID,Rating=15}); task.wait() end
            for _=1,1 do ForgeRF:InvokeServer("ForgeFinish"); task.wait() end
            for _=1,1 do ForgeRF:InvokeServer("ForgeResult",true); task.wait() end
        end)
    end; return _G.OriginalQTE(...)
end

--------------------------------------------------------------------------------
-- Open Forge — tombol khusus dengan fallback CFrame & patch ForgeGui
--------------------------------------------------------------------------------
CreateSection(ForgePage, "Forge", "secForgeUtil")

CreateButton(ForgePage, "🔨 Open Forge", function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart"); local prompt = nil
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local txt = (v.ObjectText..v.ActionText):lower()
            if v.Parent.Name:lower():match("forge") or txt:match("forge")
            or v.Parent.Name:lower():match("craft") or txt:match("craft") then
                prompt = v; break
            end
        end
    end
    if prompt and prompt.Parent:IsA("BasePart") then
        CombatEngine.ResetPhysics(hrp); hrp.CFrame = prompt.Parent.CFrame*CFrame.new(0,2,0); task.wait(0.3)
        if fireproximityprompt then fireproximityprompt(prompt) end
    else
        CombatEngine.ResetPhysics(hrp); hrp.CFrame = CFrame.new(122.5,12,-45.8); task.wait(0.3)
    end
    pcall(function()
        local TaskRE = Services.ReplicatedStorage:WaitForChild("Framework"):WaitForChild("Features"):WaitForChild("TaskSystem"):WaitForChild("TaskRE")
        TaskRE:FireServer("UpdateTaskProgress","OpenGUIWindow","ScreenForging")
    end)
    pcall(function()
        local FUI = LocalPlayer.PlayerGui:FindFirstChild("ScreenForging") or LocalPlayer.PlayerGui:FindFirstChild("ForgeGui")
        if FUI then for _, obj in pairs(FUI:GetChildren()) do if obj:IsA("Frame") then obj.Visible = true end end end
    end)
    CustomNotify("FORGE","UI berhasil dibuka!",3)
end, "btnForgeBypass")

--------------------------------------------------------------------------------
-- NPC Utility — scan dinamis ProximityPrompt di Workspace
-- Label tombol diambil langsung dari teks in-game → otomatis sesuai bahasa game
--------------------------------------------------------------------------------
CreateSection(ForgePage, "NPC Utility Access", "secNpcUtil")

local NpcButtonsRef = {}
local RunNpcScan    -- forward declaration

local NpcListContainer = Instance.new("ScrollingFrame", ForgePage)
NpcListContainer.Name               = "NpcLC"
NpcListContainer.Size               = UDim2.new(1,0,0,220)
NpcListContainer.BackgroundTransparency = 1
NpcListContainer.ScrollBarThickness = 3
NpcListContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
local NpcLL = Instance.new("UIListLayout", NpcListContainer)
NpcLL.Padding    = UDim.new(0,4)
NpcLL.SortOrder  = Enum.SortOrder.LayoutOrder

-- Factory tombol: satu tombol = satu ProximityPrompt
local function AddNpcButton(prompt, labelText)
    local btn = Instance.new("TextButton", NpcListContainer)
    btn.Size              = UDim2.new(1,-10,0,30)
    btn.Font              = Enum.Font.GothamMedium
    btn.TextSize          = 11
    btn.TextXAlignment    = Enum.TextXAlignment.Left
    btn.BorderSizePixel   = 0
    btn.BackgroundColor3  = Color3.fromRGB(28,28,40)
    btn.TextColor3        = Color3.fromRGB(255,255,255)
    btn.Text              = "  🏪 " .. labelText
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    btn.MouseButton1Click:Connect(function()
        -- Pastikan prompt masih valid (tidak di-destroy saat server hop)
        if not prompt or not prompt.Parent then
            CustomNotify("NPC ERROR","NPC tidak lagi tersedia. Scan ulang.",4)
            return
        end
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hrp  = char:WaitForChild("HumanoidRootPart")
        CombatEngine.ResetPhysics(hrp)
        hrp.CFrame = prompt.Parent.CFrame * CFrame.new(0,2,0)
        task.wait(0.3)
        if fireproximityprompt then
            fireproximityprompt(prompt)
            CustomNotify("NPC", labelText .. " berhasil dibuka!", 3)
        else
            CustomNotify("WARN","Executor tidak support fireproximityprompt",3)
        end
    end)

    table.insert(NpcButtonsRef, { prompt = prompt, btn = btn, label = labelText })
    return btn
end

-- Scan semua ProximityPrompt di Workspace — label diambil dari ObjectText/ActionText game
RunNpcScan = function()
    -- Bersihkan tombol lama
    for _, c in ipairs(NpcListContainer:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    table.clear(NpcButtonsRef)

    local seen  = {}
    local total = 0

    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") and v.Parent and v.Parent:IsA("BasePart") then
            -- Label: ObjectText utama, fallback ActionText, fallback nama Part
            local obj = v.ObjectText ~= "" and v.ObjectText or nil
            local act = v.ActionText ~= "" and v.ActionText or nil
            local label = obj and (act and (obj.." — "..act) or obj)
                       or act
                       or v.Parent.Name

            -- Deduplikasi berdasarkan nama Parent (satu NPC satu tombol)
            local key = v.Parent:GetFullName()
            if not seen[key] then
                seen[key] = true
                AddNpcButton(v, label)
                total = total + 1
            end
        end
    end

    if total == 0 then
        CustomNotify("NPC SCAN","Tidak ada NPC ditemukan di map!",4)
    else
        CustomNotify("🏪 NPC SCAN", total.." NPC ditemukan.",3)
    end
end

-- Tombol scan manual (jika user ingin refresh setelah pindah area/server)
CreateButton(ForgePage, "🔄 Scan NPC", function()
    RunNpcScan()
end)

-- Auto-scan saat script pertama jalan
task.defer(RunNpcScan)

--------------------------------------------------------------------------------
