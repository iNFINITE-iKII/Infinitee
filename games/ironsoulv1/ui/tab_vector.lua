--------------------------------------------------------------------------------
--// ui/tab_vector.lua — S18 Tab 2: Vector Config
--------------------------------------------------------------------------------
local H              = getgenv().Hub
local EngineConfig   = H.EngineConfig
local GameLists      = H.GameLists
local CustomNotify   = H.CustomNotify
local CreateTab                     = H.CreateTab
local CreateSection                 = H.CreateSection
local CreateToggleUI                = H.CreateToggleUI
local CreateInputUI                 = H.CreateInputUI
local CreateButton                  = H.CreateButton
local CreateScrollableMultiSelectUI = H.CreateScrollableMultiSelectUI

-- [S18] TAB 2 — VECTOR CONFIG
--------------------------------------------------------------------------------
local VectorPage = CreateTab("⚙️ Vector", "tabVector")

-- ── Prioritas Monster — dari ResEnemy (LIVE_CONFIG) ──────────────────────────
CreateSection(VectorPage, "Prioritas Monster", "secTargetSel")

local function _formatName(id)
    return (id:gsub("^NPC_", ""):gsub("_", " "))
end

local _resEnemy = nil
local _reOk, _reResult = pcall(function()
    return require(game:GetService("ReplicatedStorage").Configs.ResEnemy)
end)
if _reOk and type(_reResult) == "table" then _resEnemy = _reResult end

local _normalIds, _normalNames = {}, {}
local _bossIds,   _bossNames   = {}, {}

if _resEnemy then
    local normals, bosses = {}, {}
    for _, data in pairs(_resEnemy) do
        if type(data) == "table" and data.ID then
            if tostring(data.LevelType or "Normal") == "Boss" then
                table.insert(bosses, data.ID)
            else
                table.insert(normals, data.ID)
            end
        end
    end
    table.sort(normals)
    table.sort(bosses)
    for _, id in ipairs(normals) do table.insert(_normalIds, id); table.insert(_normalNames, _formatName(id)) end
    for _, id in ipairs(bosses)  do table.insert(_bossIds,   id); table.insert(_bossNames,  _formatName(id)) end
end

-- Simpan ke GameLists agar ui_sync bisa sinkronkan saat load profil
GameLists.NormalNPCs     = _normalIds;   GameLists.NormalNPCNames = _normalNames
GameLists.BossNPCs       = _bossIds;     GameLists.BossNPCNames   = _bossNames

local function _makeStatesCallbacks(ids, configMap)
    local states, callbacks = {}, {}
    for i, npcId in ipairs(ids) do
        states[i] = configMap[npcId] == true
        local id  = npcId
        callbacks[i] = function(v) configMap[id] = v end
    end
    return states, callbacks
end

if #_normalNames > 0 then
    local st, cb = _makeStatesCallbacks(_normalIds, EngineConfig.PriorityNormalNpcIds)
    _G.NormalNpcChecks = CreateScrollableMultiSelectUI(
        VectorPage, "⚔️ Normal  (" .. #_normalNames .. " monster)",
        _normalNames, st, cb, "lblNormalNpcSelect"
    )
end

if #_bossNames > 0 then
    local st, cb = _makeStatesCallbacks(_bossIds, EngineConfig.PriorityBossNpcIds)
    _G.BossNpcChecks = CreateScrollableMultiSelectUI(
        VectorPage, "💀 Boss  (" .. #_bossNames .. " monster)",
        _bossNames, st, cb, "lblBossNpcSelect"
    )
end

-- ── Lock Position ─────────────────────────────────────────────────────────────
CreateSection(VectorPage, "🔒 Lock Position", "secLockPosition")

_G.LockPositionToggle = CreateToggleUI(VectorPage, "🔒 Lock Posisi", EngineConfig.LockPositionActive, function(v)
    EngineConfig.LockPositionActive = v
    if v then
        CustomNotify("🔒 LOCK", "Lock Posisi aktif — karakter dikunci di titik ini.", 3)
    else
        CustomNotify("🔒 LOCK", "Lock Posisi dimatikan.", 2)
    end
end, "lblLockPosition")

-- ── Dodge Dragon ──────────────────────────────────────────────────────────────
CreateSection(VectorPage, "🐉 Dodge Dragon", "secDodgeDragon")

_G.DodgeDragonToggle = CreateToggleUI(VectorPage, "🐉 Dodge Dragon (Skill Bom)",
    EngineConfig.DodgeDragonActive, function(v)
        EngineConfig.DodgeDragonActive = v
        if v then
            CustomNotify("🐉 DODGE", "Dodge Dragon aktif — mendeteksi Skill Bom.", 3)
        else
            CustomNotify("🐉 DODGE", "Dodge Dragon dimatikan.", 2)
        end
    end, "lblDodgeDragon")

-- Listener RedShow: deteksi BombRed lalu ubah radius → 100 selama 2 detik
task.spawn(function()
    local _bombRedVal = nil
    local enumOk, GameEnum = pcall(function()
        return require(game:GetService("ReplicatedStorage")
            :WaitForChild("Enum",     10)
            :WaitForChild("GameEnum", 10))
    end)
    if enumOk and type(GameEnum) == "table"
       and GameEnum.SkillSkinBase then
        _bombRedVal = GameEnum.SkillSkinBase.BombRed
    end

    local RedShow = game:GetService("Workspace"):WaitForChild("RedShow", 30)
    if not RedShow then return end

    local _dodging = false

    RedShow.ChildAdded:Connect(function(bar)
        if not EngineConfig.DodgeDragonActive then return end
        if not EngineConfig.AutoFarmActive     then return end
        if _dodging then return end

        task.defer(function()
            local skin = bar:GetAttribute("Skin")
            if _bombRedVal ~= nil and skin ~= _bombRedVal then return end

            local count = 0
            for _, child in ipairs(RedShow:GetChildren()) do
                local s = child:GetAttribute("Skin")
                if _bombRedVal == nil or s == _bombRedVal then count = count + 1 end
            end
            if count <= 3 then return end

            _dodging = true
            local prevRadius = EngineConfig.OrbitRadius
            EngineConfig.OrbitRadius = 100
            if _G.RadiusInput then _G.RadiusInput:SetValue(100) end
            CustomNotify("🐉 DODGE DRAGON", "Skill Bom! Radius → 100 (4s)", 2)

            task.wait(4)

            EngineConfig.OrbitRadius = prevRadius
            if _G.RadiusInput then _G.RadiusInput:SetValue(prevRadius) end
            _dodging = false
        end)
    end)
end)

CreateSection(VectorPage, "Dodge Boss", "secDodgeBoss")
_G.RadiusInput = CreateInputUI(VectorPage, "Orbit Radius", EngineConfig.OrbitRadius, true, function(v) EngineConfig.OrbitRadius = tonumber(v) or 12 end, "lblOrbitRadius")
CreateButton(VectorPage, "🎯 Dodge Boss Skil (20)",  function() EngineConfig.OrbitRadius = 20;  _G.RadiusInput:SetValue(20)  end, "btnDodge20")
CreateButton(VectorPage, "🎯 Dodge Boss Skil(200)", function() EngineConfig.OrbitRadius = 200; _G.RadiusInput:SetValue(200) end, "btnDodge200")

CreateSection(VectorPage, "Reset Lock", "secResetLock")
_G.ResetLockW4Input = CreateInputUI(VectorPage, "Reset Lock W4 - Tartarus (s)", EngineConfig.ResetLockW4, true, function(v)
    EngineConfig.ResetLockW4 = tonumber(v) or 2
end, "lblResetLockW4")
_G.ResetLockW5Input = CreateInputUI(VectorPage, "Reset Lock W5 - Endless Tower (s)", EngineConfig.ResetLockW5, true, function(v)
    EngineConfig.ResetLockW5 = tonumber(v) or 3
end, "lblResetLockW5")

CreateSection(VectorPage, "Kinematic System Parameters", "secKinematic")
_G.HeightInput        = CreateInputUI(VectorPage, "Height Normal Target (Y)", EngineConfig.StandHeight,        true,  function(v) EngineConfig.StandHeight        = tonumber(v) or 20    end, "lblHeightNormal")
_G.BossHeightInput    = CreateInputUI(VectorPage, "Height Boss Target (Y)",   EngineConfig.BossHeight,         true,  function(v) EngineConfig.BossHeight          = tonumber(v) or 25    end, "lblHeightBoss")
_G.SpeedInput         = CreateInputUI(VectorPage, "Orbit Speed",              EngineConfig.OrbitSpeed,         true,  function(v) EngineConfig.OrbitSpeed          = tonumber(v) or 5     end, "lblOrbitSpeed")
_G.DelayInput         = CreateInputUI(VectorPage, "CFrame Delay",             EngineConfig.CFrameDelay,        false, function(v) EngineConfig.CFrameDelay         = tonumber(v) or 0.001 end, "lblCFrameDelay")
_G.MultiplierInput    = CreateInputUI(VectorPage, "Hit Multiplier",           EngineConfig.HitMultiplier,      true,  function(v) EngineConfig.HitMultiplier       = tonumber(v) or 1     end, "lblHitMultiplier")
_G.LerpAlphaInput     = CreateInputUI(VectorPage, "Lerp Alpha (0–1)",         EngineConfig.LerpAlpha,          false, function(v) EngineConfig.LerpAlpha           = math.clamp(tonumber(v) or 0.3, 0.01, 1) end, "lblLerpAlpha")
_G.SkillCooldownInput = CreateInputUI(VectorPage, "Skill Cooldown (s)",       EngineConfig.SkillCooldownDelay, false, function(v) EngineConfig.SkillCooldownDelay  = tonumber(v) or 0.5   end, "lblSkillCooldown")
_G.ETHoverYInput      = CreateInputUI(VectorPage, "Endless Tower Hover Y",    EngineConfig.EndlessTowerHoverY, false, function(v) EngineConfig.EndlessTowerHoverY   = tonumber(v) or 35    end, "lblETHoverY")

--------------------------------------------------------------------------------
