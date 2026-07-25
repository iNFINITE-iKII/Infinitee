--------------------------------------------------------------------------------
--// ui/tab_priority.lua — S18 Tab: Prioritas Musuh
-- Data diambil dari ResEnemy (ReplicatedStorage.Configs.ResEnemy) — LIVE_CONFIG.
-- Tidak perlu scan runtime. List Normal & Boss terisi saat load.
--------------------------------------------------------------------------------
local H               = getgenv().Hub
local EngineConfig    = H.EngineConfig
local GameLists       = H.GameLists
local CreateTab                     = H.CreateTab
local CreateSection                 = H.CreateSection
local CreateScrollableMultiSelectUI = H.CreateScrollableMultiSelectUI

-- [S18] TAB: PRIORITAS MUSUH
--------------------------------------------------------------------------------
local PriorityPage = CreateTab("🎯 Prioritas", "tabPriority")

-- ── Format display name dari ID ───────────────────────────────────────────────
-- "NPC_Vampire_Champion" → "Vampire Champion"
-- "NPC_Golem_Ice"        → "Golem Ice"
local function formatName(id)
    return (id:gsub("^NPC_", ""):gsub("_", " "))
end

-- ── Baca ResEnemy — LIVE_CONFIG ───────────────────────────────────────────────
local _resEnemy = nil
local ok, result = pcall(function()
    return require(game:GetService("ReplicatedStorage").Configs.ResEnemy)
end)
if ok and type(result) == "table" then
    _resEnemy = result
end

-- ── Pisahkan Normal vs Boss, urutkan alfabetis ────────────────────────────────
local _normalIds,   _normalNames   = {}, {}
local _bossIds,     _bossNames     = {}, {}

if _resEnemy then
    local normals, bosses = {}, {}
    for id, data in pairs(_resEnemy) do
        if type(data) == "table" and data.ID then
            local lt = tostring(data.LevelType or "Normal")
            if lt == "Boss" then
                table.insert(bosses, data.ID)
            else
                table.insert(normals, data.ID)
            end
        end
    end
    table.sort(normals)
    table.sort(bosses)

    for _, id in ipairs(normals) do
        table.insert(_normalIds,   id)
        table.insert(_normalNames, formatName(id))
    end
    for _, id in ipairs(bosses) do
        table.insert(_bossIds,   id)
        table.insert(_bossNames, formatName(id))
    end
end

-- Simpan ke GameLists agar ui_sync bisa sinkronkan saat load profil
GameLists.NormalNPCs     = _normalIds
GameLists.NormalNPCNames = _normalNames
GameLists.BossNPCs       = _bossIds
GameLists.BossNPCNames   = _bossNames

-- ── Bangun states & callbacks ─────────────────────────────────────────────────
local function makeStatesCallbacks(ids, configMap)
    local states, callbacks = {}, {}
    for i, npcId in ipairs(ids) do
        states[i] = configMap[npcId] == true
        local id  = npcId
        callbacks[i] = function(v)
            configMap[id] = v
        end
    end
    return states, callbacks
end

-- ── Section Normal ────────────────────────────────────────────────────────────
CreateSection(PriorityPage, "Normal Monster", "secNormalNpc")

if #_normalNames > 0 then
    local states, callbacks = makeStatesCallbacks(_normalIds, EngineConfig.PriorityNormalNpcIds)
    _G.NormalNpcChecks = CreateScrollableMultiSelectUI(
        PriorityPage,
        "⚔️ Normal  (" .. #_normalNames .. " monster)",
        _normalNames, states, callbacks,
        "lblNormalNpcSelect"
    )
else
    local ph = Instance.new("TextLabel", PriorityPage)
    ph.BackgroundTransparency = 1
    ph.Size = UDim2.new(1, 0, 0, 28)
    ph.Font = Enum.Font.Gotham
    ph.Text = "ResEnemy tidak dapat dimuat."
    ph.TextColor3 = Color3.fromRGB(200, 80, 80)
    ph.TextSize = 11
    ph.TextXAlignment = Enum.TextXAlignment.Center
end

-- ── Section Boss ──────────────────────────────────────────────────────────────
CreateSection(PriorityPage, "Boss Monster", "secBossNpc")

if #_bossNames > 0 then
    local states, callbacks = makeStatesCallbacks(_bossIds, EngineConfig.PriorityBossNpcIds)
    _G.BossNpcChecks = CreateScrollableMultiSelectUI(
        PriorityPage,
        "💀 Boss  (" .. #_bossNames .. " monster)",
        _bossNames, states, callbacks,
        "lblBossNpcSelect"
    )
else
    local ph = Instance.new("TextLabel", PriorityPage)
    ph.BackgroundTransparency = 1
    ph.Size = UDim2.new(1, 0, 0, 28)
    ph.Font = Enum.Font.Gotham
    ph.Text = "ResEnemy tidak dapat dimuat."
    ph.TextColor3 = Color3.fromRGB(200, 80, 80)
    ph.TextSize = 11
    ph.TextXAlignment = Enum.TextXAlignment.Center
end

--------------------------------------------------------------------------------
