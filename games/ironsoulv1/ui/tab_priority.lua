--------------------------------------------------------------------------------
--// ui/tab_priority.lua — S18 Tab: Prioritas Musuh
-- Scan monster saat dalam round → centang mana yang diprioritaskan.
-- List Normal dan Boss terpisah. Key disimpan di EngineConfig (npcId).
--------------------------------------------------------------------------------
local H               = getgenv().Hub
local EngineConfig    = H.EngineConfig
local GameLists       = H.GameLists
local CombatEngine    = H.CombatEngine
local CustomNotify    = H.CustomNotify
local Workspace       = H.Workspace
local CreateTab                     = H.CreateTab
local CreateSection                 = H.CreateSection
local CreateButton                  = H.CreateButton
local CreateScrollableMultiSelectUI = H.CreateScrollableMultiSelectUI

-- [S18] TAB: PRIORITAS MUSUH
--------------------------------------------------------------------------------
local PriorityPage = CreateTab("🎯 Prioritas", "tabPriority")

CreateSection(PriorityPage, "Scan Monster", "secPriorityScan")

CreateButton(PriorityPage, "🔍 Scan Monster Sekarang", function()
    if H.ScanPriorityMonsters then H.ScanPriorityMonsters() end
end, "lblScanMonsters")

-- ── Section Normal ────────────────────────────────────────────────────────────
CreateSection(PriorityPage, "Normal Monster", "secNormalNpc")

local _normalHolder = Instance.new("Frame", PriorityPage)
_normalHolder.BackgroundTransparency = 1
_normalHolder.Size                   = UDim2.new(1, 0, 0, 0)
_normalHolder.AutomaticSize          = Enum.AutomaticSize.Y
_normalHolder.BorderSizePixel        = 0

-- ── Section Boss ──────────────────────────────────────────────────────────────
CreateSection(PriorityPage, "Boss Monster", "secBossNpc")

local _bossHolder = Instance.new("Frame", PriorityPage)
_bossHolder.BackgroundTransparency = 1
_bossHolder.Size                   = UDim2.new(1, 0, 0, 0)
_bossHolder.AutomaticSize          = Enum.AutomaticSize.Y
_bossHolder.BorderSizePixel        = 0

-- ── Helper: placeholder teks saat belum scan ─────────────────────────────────
local function _makePlaceholder(parent, text)
    local ph = Instance.new("TextLabel", parent)
    ph.BackgroundTransparency = 1
    ph.Size                   = UDim2.new(1, 0, 0, 28)
    ph.Font                   = Enum.Font.Gotham
    ph.Text                   = text
    ph.TextColor3             = Color3.fromRGB(100, 100, 120)
    ph.TextSize               = 11
    ph.TextXAlignment         = Enum.TextXAlignment.Center
end

-- ── Rebuild Normal UI ─────────────────────────────────────────────────────────
local function _rebuildNormalUI()
    for _, c in ipairs(_normalHolder:GetChildren()) do c:Destroy() end
    local names = GameLists.NormalNPCNames
    if not names or #names == 0 then
        _makePlaceholder(_normalHolder, "Belum ada data — tekan Scan dulu")
        _G.NormalNpcChecks = nil
        return
    end

    local states, callbacks = {}, {}
    for i, _ in ipairs(names) do
        local npcId  = GameLists.NormalNPCs[i]
        states[i]    = EngineConfig.PriorityNormalNpcIds[npcId] == true
        local idx    = i
        callbacks[i] = function(v)
            local id = GameLists.NormalNPCs[idx]
            if id then EngineConfig.PriorityNormalNpcIds[id] = v end
        end
    end

    _G.NormalNpcChecks = CreateScrollableMultiSelectUI(
        _normalHolder,
        "⚔️ Normal  (" .. #names .. " monster)",
        names, states, callbacks,
        "lblNormalNpcSelect"
    )
end

-- ── Rebuild Boss UI ───────────────────────────────────────────────────────────
local function _rebuildBossUI()
    for _, c in ipairs(_bossHolder:GetChildren()) do c:Destroy() end
    local names = GameLists.BossNPCNames
    if not names or #names == 0 then
        _makePlaceholder(_bossHolder, "Belum ada data — tekan Scan dulu")
        _G.BossNpcChecks = nil
        return
    end

    local states, callbacks = {}, {}
    for i, _ in ipairs(names) do
        local npcId  = GameLists.BossNPCs[i]
        states[i]    = EngineConfig.PriorityBossNpcIds[npcId] == true
        local idx    = i
        callbacks[i] = function(v)
            local id = GameLists.BossNPCs[idx]
            if id then EngineConfig.PriorityBossNpcIds[id] = v end
        end
    end

    _G.BossNpcChecks = CreateScrollableMultiSelectUI(
        _bossHolder,
        "💀 Boss  (" .. #names .. " monster)",
        names, states, callbacks,
        "lblBossNpcSelect"
    )
end

-- ── Scanner runtime ───────────────────────────────────────────────────────────
-- Scan Workspace.EnemyNpc → isi GameLists → rebuild UI kedua section.
-- Dipanggil manual (tombol) atau otomatis saat EnemyNpc muncul.
local function ScanMonsters()
    local ef = Workspace:FindFirstChild("EnemyNpc")
    if not ef or #ef:GetChildren() == 0 then
        CustomNotify("🎯 PRIORITAS", "EnemyNpc tidak ada. Pastikan sudah dalam round!", 4)
        return
    end

    local seenIds    = {}
    local normals,  normalNames = {}, {}
    local bosses,   bossNames   = {}, {}

    for _, monster in ipairs(ef:GetChildren()) do
        if monster:FindFirstChild("HumanoidRootPart") then
            local npcId      = CombatEngine.GetNpcId(monster)
            local levelType  = CombatEngine.GetLevelType(monster)
            local displayName = monster.Name

            if not seenIds[npcId] then
                seenIds[npcId] = true
                if levelType == "boss" then
                    table.insert(bosses,    npcId)
                    table.insert(bossNames, displayName)
                else
                    table.insert(normals,    npcId)
                    table.insert(normalNames, displayName)
                end
            end
        end
    end

    -- Simpan ke GameLists (dipakai ui_sync saat load profile)
    GameLists.NormalNPCs     = normals
    GameLists.NormalNPCNames = normalNames
    GameLists.BossNPCs       = bosses
    GameLists.BossNPCNames   = bossNames

    _rebuildNormalUI()
    _rebuildBossUI()

    local total = #normals + #bosses
    CustomNotify(
        "🎯 PRIORITAS",
        total .. " monster ditemukan  (" .. #normals .. " Normal · " .. #bosses .. " Boss)",
        4
    )
end

-- Expose ke Hub agar bisa dipanggil dari tombol dan auto-scan
H.ScanPriorityMonsters = ScanMonsters

-- ── Auto-scan saat masuk round ────────────────────────────────────────────────
-- Jika EnemyNpc sudah ada, scan langsung. Kalau belum, tunggu sampai muncul.
task.spawn(function()
    local ef = Workspace:FindFirstChild("EnemyNpc")
    if ef then
        task.wait(1.5) -- beri waktu monster spawn
        ScanMonsters()
    else
        local conn
        conn = Workspace.ChildAdded:Connect(function(child)
            if child.Name == "EnemyNpc" then
                conn:Disconnect()
                task.wait(1.5)
                ScanMonsters()
            end
        end)
    end
end)

-- Tampilkan placeholder awal sebelum scan
_rebuildNormalUI()
_rebuildBossUI()

--------------------------------------------------------------------------------
