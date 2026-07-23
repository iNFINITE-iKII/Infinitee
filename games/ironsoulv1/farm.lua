--------------------------------------------------------------------------------
--// farm.lua — S08 Farm Loop + S09 Background Loops
--------------------------------------------------------------------------------
local H                     = getgenv().Hub
local EngineConfig          = H.EngineConfig
local LocalPlayer           = H.LocalPlayer
local Workspace             = H.Workspace
local Services              = H.Services
local PlayerActionRE        = H.PlayerActionRE
local GameMatchRE           = H.GameMatchRE
local WorldPlaceRE          = H.WorldPlaceRE
local MaterialRE            = H.MaterialRE
local EquipmentRE           = H.EquipmentRE
local CombatEngine          = H.CombatEngine
local Navigation            = H.Navigation
local anyActiveTargetExists = H.anyActiveTargetExists
local checkVictoryUi        = H.checkVictoryUi
local DisableAutoFarm       = H.DisableAutoFarm
local CustomNotify          = H.CustomNotify
local GetPositionCFrame     = H.GetPositionCFrame
local ApplyMovement         = H.ApplyMovement
local WORLD_INDEX           = H.WORLD_INDEX
local ROOM_WORLD_KEY        = H.ROOM_WORLD_KEY

-- [EGG] Cari instance "DragonEgg" yang BENAR di Workspace.
-- Server kadang membuat DragonEgg baru (placeholder, belum ada EggModel/Part)
-- SEBELUM DragonEgg lama selesai dihapus setelah proximity/broken → sesaat ada
-- 2 instance bernama sama. FindFirstChild("DragonEgg") tidak bisa diandalkan
-- karena bisa mengembalikan placeholder kosong itu. Jadi kita scan semua anak
-- bernama "DragonEgg" dan ambil yang benar-benar punya EggModel.Part.
local function GetActiveDragonEgg()
    local best = nil
    for _,child in ipairs(Workspace:GetChildren()) do
        if child.Name=="DragonEgg" then
            local eggModel = child:FindFirstChild("EggModel")
            local part = eggModel and eggModel:FindFirstChild("Part")
            if part then
                -- Prioritaskan yang Active & belum Broken; kalau tidak ada,
                -- tetap simpan kandidat pertama yang punya Part sebagai fallback.
                if child:GetAttribute("Active") and not child:GetAttribute("Broken") then
                    return child
                end
                best = best or child
            end
        end
    end
    return best
end

-- [EGG] Ambil CFrame posisi TERENDAH dari egg (anti-model tinggi palsu).
-- Dev bisa sengaja taruh PrimaryPart / Pivot di puncak model setinggi ratusan stud
-- sehingga script snap karakter jauh di atas egg asli. Fix: scan SEMUA BasePart
-- di dalam egg, ambil yang Y-nya paling rendah → posisi fisik egg sesungguhnya.
local function GetEggGroundCFrame(egg)
    local lowestY   = math.huge
    local lowestCF  = nil
    for _, obj in ipairs(egg:GetDescendants()) do
        if obj:IsA("BasePart") and obj.CanCollide == false or obj:IsA("BasePart") then
            local y = obj.Position.Y
            if y < lowestY then
                lowestY  = y
                lowestCF = obj.CFrame
            end
        end
    end
    -- Fallback: pakai pivot jika tidak ada descendant BasePart sama sekali
    return lowestCF or egg:GetPivot()
end

-- ============================================================================
-- [EGG V6] Sistem Trigger Egg — ported dari V6 (ProximityPrompt + HoldKey F)
-- On/Off: EngineConfig.FarmTargetEgg (toggle 🥚 Egg di UI)
-- Terhubung ke: FarmPosition, FarmHeight via GetPositionCFrame + ApplyMovement
-- ============================================================================

-- State variables
local _eggIsExtracting = false   -- true saat TriggerEggIfNeeded sedang jalan
local _eggLastTriggered = nil    -- referensi egg terakhir yang di-trigger
local _eggLockEnd      = 0       -- os.clock() deadline cooldown setelah trigger (12 detik)
local _eggTriggeredAt  = -math.huge  -- os.clock() saat trigger terakhir; 2 detik pertama = fase diam bawah egg
local _eggRayParams    = RaycastParams.new()
_eggRayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Cari ProximityPrompt di dalam model DragonEgg (rekursif)
local function GetEggPrompt(eggModel)
    return eggModel and eggModel:FindFirstChildWhichIsA("ProximityPrompt", true) or nil
end

-- Teleport karakter ke posisi ground di bawah egg via CFrame + Raycast
-- Mengembalikan true jika berhasil
local function MoveToEggGround(eggModel)
    local char  = LocalPlayer.Character
    local myHRP = char and char:FindFirstChild("HumanoidRootPart")
    local myHum = char and char:FindFirstChildOfClass("Humanoid")
    if not myHRP or not myHum then return false end

    local eggCF  = GetEggGroundCFrame(eggModel)
    local eggPos = eggCF.Position

    _eggRayParams.FilterDescendantsInstances = { eggModel, char }
    local ray     = Workspace:Raycast(eggPos + Vector3.new(0, 8, 0), Vector3.new(0, -35, 0), _eggRayParams)
    local groundPos = ray and ray.Position or eggPos

    CombatEngine.ResetPhysics(myHRP)
    myHRP.CFrame = CFrame.new(groundPos + Vector3.new(0, 3, 0), eggPos)
    myHRP.AssemblyLinearVelocity = Vector3.zero
    myHum:ChangeState(Enum.HumanoidStateType.Running)
    task.wait(0.35)
    return true
end

-- Trigger egg: ProximityPrompt (utama) atau HoldKey F 3 detik (fallback).
-- Lock 12 detik setelah trigger agar tidak spam.
local function TriggerEggIfNeeded(eggModel)
    if _eggIsExtracting then return end
    if _eggLastTriggered == eggModel and os.clock() < _eggLockEnd then return end

    _eggIsExtracting = true

    if not MoveToEggGround(eggModel) then
        _eggIsExtracting = false
        return
    end

    local char  = LocalPlayer.Character
    local myHRP = char and char:FindFirstChild("HumanoidRootPart")
    local eggCF = GetEggGroundCFrame(eggModel)
    if not myHRP or (myHRP.Position - eggCF.Position).Magnitude > 24 then
        _eggIsExtracting = false
        return
    end

    _eggLastTriggered = eggModel
    local prompt = GetEggPrompt(eggModel)
    if prompt then
        print("[Egg V6] Triggering ProximityPrompt...")
        pcall(function()
            if fireproximityprompt then
                fireproximityprompt(prompt)
            else
                prompt:InputHoldBegin()
                task.wait((prompt.HoldDuration or 3) + 0.1)
                prompt:InputHoldEnd()
            end
        end)
    else
        print("[Egg V6] Prompt not found — HoldKey F 3s fallback...")
        pcall(function() Services.VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.F, false, game) end)
        task.wait(3.0)
        pcall(function() Services.VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game) end)
    end

    _eggIsExtracting = false
    _eggTriggeredAt  = os.clock()
    _eggLockEnd = os.clock() + 12.0
end

-- [S08] FARM LOOP
-- Satu loop terpadu menangani semua prioritas: Chest > Egg > Enemy.
-- Guard _farmLoopRunning mencegah instance ganda saat toggle dinyalakan ulang.
--------------------------------------------------------------------------------

-- Flag: true saat weapon switch sedang berjalan → tahan auto attack
local _autoAttackPaused = false

-- [WEAPON] Dispatcher serangan berdasarkan EngineConfig.SelectedWeapon.
-- Heavy : fire BaseAttack combo-3 sebanyak 3x per kesempatan.
-- Bow   : fire BaseAttack combo-6 (1x) + BulletShoot dengan target eksplisit.
--         BulletShoot adalah remote yang mendaftarkan damage peluru bow di server.
--         targetModel boleh nil (Kill Aura) → BulletShoot dilewati, fallback ke BaseAttack saja.

local function FireHeavyAttack(targetCFrame)
    for _ = 1, 1 do
        pcall(function()
            PlayerActionRE:FireServer("SkillAction", "BaseAttack", 3, targetCFrame)
        end)
    end
end

local function FireBowAttack(targetModel, targetCFrame)
    -- Langkah 1: BaseAttack combo-6 — trigger animasi + combo bow di server
    pcall(function()
        PlayerActionRE:FireServer("SkillAction", "BaseAttack", 6, targetCFrame)
    end)
    -- Langkah 2: BulletShoot burst — 2x fire, tiap call bawa 2 Idx (4 peluru total)
    -- Hanya dikirim jika ada targetModel; tanpa model server tidak tahu siapa kena.
    if targetModel then
        local args = {
            {["Idx"] = 1, ["Enemy"] = targetModel},
            {["Idx"] = 2, ["Enemy"] = targetModel},
            {["Idx"] = 3, ["Enemy"] = targetModel},
            {["Idx"] = 4, ["Enemy"] = targetModel},
        }
        for _ = 1, 4 do
            pcall(function()
                PlayerActionRE:FireServer(
                    "BulletShoot",
                    "SkywingBow_AtkSkywingBow_Atk_6",
                    args
                )
            end)
        end
    end
end

-- Dispatcher utama — pakai di semua titik serangan.
-- targetModel : Model instance target (monster/chest/egg), atau nil jika tidak ada.
-- targetCFrame: CFrame posisi target untuk BaseAttack.
local function FireWeaponAttack(targetModel, targetCFrame)
    if EngineConfig.SelectedWeapon == "Bow" then
        FireBowAttack(targetModel, targetCFrame)
    else
        FireHeavyAttack(targetCFrame)
    end
end

-- Loop: Auto Attack Only (fire remote saja, tanpa movement)
-- Dibatasi 1x setiap 0.8 detik; berhenti selama jendela weapon switch.
task.spawn(function()
    while true do
        task.wait(0.5)  -- 1 serangan per 0.8 detik
        if EngineConfig.AutoAttackOnly and not _autoAttackPaused then
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- Kill Aura: tidak ada targetModel (tidak tahu monster mana) →
                -- Bow hanya fire BaseAttack combo-6; BulletShoot dilewati.
                task.defer(function() FireWeaponAttack(nil, hrp.CFrame) end)
            end
        end
    end
end)

-- Guard: cegah loop dobel
local _farmLoopRunning=false

-- [AUTO-OFF ZONES] Zona XZ yang otomatis mematikan Auto Farm setelah 2 detik di area aman.
-- Jika player keluar zona sebelum 2 detik → timer direset, farm TIDAK dimatikan.
-- Cek pakai squared-distance (tanpa sqrt) agar efisien setiap frame.
-- r2 = radius² (stud²).
local AUTO_OFF_ZONES = {
    { cx = 9972.75, cz = -7.75, r2 = 62500 },  -- Zone 1, radius 250 stud
    { cx = -5.75,   cz = 27.25, r2 = 62500 },  -- Zone 2, radius 250 stud
}
-- tick() saat Auto Farm dinyalakan; zona aman hanya aktif 4 detik pertama.
local _farmStartedAt = nil

-- Timer serangan farm: pisahkan interval attack dari interval movement
-- Satu konstanta dipakai semua titik (Chest / Egg / Monster)
local _lastFarmAttack      = 0
local FARM_ATTACK_INTERVAL = 0.5   -- detik minimum antar attack untuk Heavy
local BOW_ATTACK_INTERVAL  = 0.000000001   -- bow lebih cepat; masih aman dari rate-limit server

-- Cek apakah loop masih harus berjalan
local function anyFarmToggleActive()
    return EngineConfig.AutoFarmActive
end

--[[
  SISTEM BARU — 1 Toggle (AutoFarmActive) + pilihan target (Monster/Chest/Egg)

  PRIORITAS (per frame) saat ada target yang dipilih:
    1. Chest   — jika FarmTargetChest=true DAN ada chest
    2. Egg     — jika FarmTargetEgg=true DAN ada DragonEgg
    3. Monster — jika FarmTargetMonster=true DAN ada monster
    4. Find    — Auto Farm aktif tapi tidak ada satupun target ditemukan → navigasi cari

  ATURAN:
  · Chest & Egg HANYA aktif jika AutoFarmActive=true.
  · Find otomatis berjalan saat tidak ada target, selalu.
  · Jika hanya Monster dipilih → setelah tidak ada monster langsung Find.
  · Jika Chest/Egg dipilih → Chest > Egg lebih dulu, Monster setelahnya, baru Find.
]]
local function startFarmLoop()
    if _farmLoopRunning then return end
    _farmLoopRunning=true

    -- Nol-kan velocity setiap Heartbeat selama Auto Farm aktif
    -- supaya gravity tidak narik karakter turun saat idle / CFrame / stall.
    local _physicsConn = Services.RunService.Heartbeat:Connect(function()
        if not EngineConfig.AutoFarmActive then return end
        local c   = LocalPlayer.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)

    local noTargetTimer=0
    _safeZoneEnteredAt = nil  -- reset timer zona aman saat sesi farm baru dimulai
    _farmStartedAt     = tick() -- catat waktu farm dinyalakan; zona aman aktif 4 detik pertama
    -- [WORLD3 ORBIT] Mulai sebagai "sudah selesai" agar orbit hanya muncul
    -- SETELAH ada monster World3 yang dibunuh, bukan dari awal loop kosong.
    _G._world3OrbitDone    = true
    _G._world3LastMonsterPos = nil   -- posisi monster terakhir yang dilawan di World3
    -- [WORLD3 RESPAWN] Counter round respawn berurutan (Round1, Round2, ...).
    -- Naik 1 setiap kali SearchWorld3 dipanggil (tidak ada musuh setelah stall).
    _G._world3GroundIdx = 1
    -- [WORLD1 GROUND] Counter indeks Ground berurutan untuk World 1 (workspace.World.<subfolder>.Ground).
    _G._world1GroundIdx = 1
    -- [WORLD2 ROOM] Counter indeks Room berurutan untuk World 2 (workspace.World.<room>.Portal.Root.TouchInterest).
    _G._world2RoomIdx = 1
    -- [WORLD4 GROUND] Counter indeks posisi berurutan untuk World 4 (Tartarus).
    _G._world4GroundIdx = 1
    -- [TARTARUS Y-LOCK] State per-session
    _G._tartarusFixedY      = nil  -- Y terkunci saat farm monster Tartarus
    _G._tartarusLastPart    = nil  -- Instance target terakhir; reset Y lock saat target ganti
    _G._tartarusMonsterBaseY= nil  -- Y monster saat lock dibuat; reset lock jika monster pindah lantai
    _G._tartarusYLockSetAt  = nil  -- tick() saat Y lock terakhir dibuat; reset setiap 2 detik
    if _G._tartarusYLockConn then pcall(function() _G._tartarusYLockConn:Disconnect() end) end
    _G._tartarusYLockConn = nil -- Heartbeat koreksi Y drift Tartarus
    -- [CHEST GUARD]
    _G._worldHasFind    = false
    _G._worldHasMonster = false
    -- [EGG V6] Reset state per sesi farm baru
    _eggIsExtracting = false
    _eggLastTriggered = nil
    _eggLockEnd      = 0
    _eggTriggeredAt  = -math.huge

    -- [ENDLESS TOWER] State per-session
    _G._endlessTowerWaitUntil    = 0     -- tick() kapan CFrame pertama boleh jalan (delay setelah target habis)
    _G._endlessTowerDone         = false -- true setelah CFrame Portal; reset saat monster baru muncul
    _G._endlessTowerHadTarget    = false -- flag: target baru saja habis
    _G._endlessTowerFollowStartAt= 0     -- tick() saat Fase 1 dimulai
    _G._endlessTowerFollowEndAt  = 0     -- tick() akhir Fase 1 (start + 4 detik)
    _G._endlessTowerFreezePos    = nil   -- posisi freeze saat akhir detik ke-1
    _G._endlessTowerFixedY       = nil   -- Y terkunci saat Fase 2 (X,Z tetap ikut monster, Y tidak berubah)
    _G._endlessTowerYLockSetAt   = nil   -- tick() saat Y lock terakhir dibuat; reset setiap 3 detik
    _G._endlessTowerPortalAt     = 0     -- tick() terakhir CFrame ke Portal (untuk retry setiap 7 detik)
    _G._endlessTowerLastPos      = nil   -- posisi musuh terakhir saat mati (jadi pusat Y=35)
    if _G._endlessTowerHoverConn then pcall(function() _G._endlessTowerHoverConn:Disconnect() end) end
    _G._endlessTowerHoverConn    = nil   -- Heartbeat connection pengunci CFrame selama countdown
    if _G._endlessTowerYLockConn then pcall(function() _G._endlessTowerYLockConn:Disconnect() end) end
    _G._endlessTowerYLockConn    = nil   -- Heartbeat koreksi Y drift saat Fase 2

    while anyFarmToggleActive() do
        if checkVictoryUi() then DisableAutoFarm("Victory UI Found"); break end

        local char=LocalPlayer.Character
        local myHRP=char and char:FindFirstChild("HumanoidRootPart")
        local myHum=char and char:FindFirstChildOfClass("Humanoid")
        if not myHRP or not myHum then task.wait(0.1); continue end

        -- [AUTO-OFF ZONES] Hanya aktif 4 detik pertama sejak Auto Farm dinyalakan.
        -- Setelah 4 detik, deteksi zona berhenti sepenuhnya — farm bebas jalan ke mana saja.
        -- Masuk zona → langsung matikan farm (tidak ada delay).
        if tick() - (_farmStartedAt or 0) < 4 then
            local _px, _pz = myHRP.Position.X, myHRP.Position.Z
            for _, _z in ipairs(AUTO_OFF_ZONES) do
                local _dx, _dz = _px - _z.cx, _pz - _z.cz
                if _dx*_dx + _dz*_dz <= _z.r2 then
                    DisableAutoFarm("Area aman — Auto Farm dimatikan otomatis")
                    break
                end
            end
        end
        if not anyFarmToggleActive() then break end

        local worldIdx=WORLD_INDEX[EngineConfig.SelectedWorld] or 1

        -- == GUARD World 2 IsLockDelay ==
        if worldIdx==2 and EngineConfig.IsLockDelay and not anyActiveTargetExists() then
            CombatEngine.ResetPhysics(myHRP); Services.RunService.Heartbeat:Wait()

        -- ──────────────── PRIORITAS 1: CHEST ────────────────
        elseif EngineConfig.FarmTargetChest and #CombatEngine.GetValidChests() > 0 then
            noTargetTimer=0; EngineConfig.IsLockDelay=false
            -- Ambil chest pertama yang tersedia (tanpa batasan jarak)
            local nearestChest = CombatEngine.GetValidChests()[1]
            local chestRoot = nearestChest and nearestChest.Root
            local chestObj  = nearestChest and nearestChest.Object
            if chestRoot and chestRoot:IsA("BasePart") then
                if not _autoAttackPaused then myHum.PlatformStand=true end

                -- Cek per-model: chest BARU = butuh approach phase.
                local _chestKey = nearestChest.Object
                if _G._chestApproached ~= _chestKey then
                    _G._chestApproached = _chestKey
                    -- ▶ FASE 1: CFrame ke chest + attack selama 1 detik (tanpa proximity prompt)
                    CombatEngine.ResetPhysics(myHRP)
                    myHRP.CFrame = CFrame.new(chestRoot.Position+Vector3.new(0,-3,0), chestRoot.Position)
                    local elapsed = 0
                    while elapsed < 1 do
                        if not EngineConfig.AutoFarmActive then break end
                        -- Kirim attack ke chest
                        FireWeaponAttack(chestObj, chestRoot.CFrame)
                        task.wait(0.1)
                        elapsed = elapsed + 0.1
                    end
                end

                -- ▶ FASE 2: Orbit di sekitar chest sambil terus menyerang.
                -- Guard: jika farm dimatikan saat fase 1, lewati fase 2.
                if EngineConfig.AutoFarmActive then
                    local targetCF=GetPositionCFrame(chestRoot.Position,EngineConfig.FarmPosition)
                    ApplyMovement(myHRP,targetCF)
                    -- Attack dibatasi per interval weapon: Bow lebih cepat (BOW_ATTACK_INTERVAL), Heavy normal
                    local now=tick()
                    local _atkInterval = EngineConfig.SelectedWeapon=="Bow" and BOW_ATTACK_INTERVAL or FARM_ATTACK_INTERVAL
                    if now-_lastFarmAttack >= _atkInterval and not _autoAttackPaused then
                        _lastFarmAttack=now
                        local atkCF=chestRoot.CFrame
                        task.defer(function() FireWeaponAttack(chestObj, atkCF) end)
                    end
                    task.wait(EngineConfig.CFrameDelay)
                else
                    Services.RunService.Heartbeat:Wait()
                end
            else Services.RunService.Heartbeat:Wait() end

        -- ──────────────── PRIORITAS 2: EGG (V6 Method) ────────────────
        -- On/Off : toggle 🥚 Egg di UI (EngineConfig.FarmTargetEgg)
        -- Deteksi: GetActiveDragonEgg() — scan workspace, cek Broken attribute
        -- Trigger: ProximityPrompt (utama) atau HoldKey F 3s (fallback) — sekali per 12 detik
        -- Orbit  : selama menunggu cooldown, karakter orbit egg sesuai FarmPosition & FarmHeight
        elseif EngineConfig.FarmTargetEgg and (function()
            local e = GetActiveDragonEgg()
            return e and not e:GetAttribute("Broken")
        end)() then
            noTargetTimer=0; EngineConfig.IsLockDelay=false
            local egg = GetActiveDragonEgg()
            if not egg or egg:GetAttribute("Broken") then
                Services.RunService.Heartbeat:Wait()
            else
                if not _autoAttackPaused then myHum.PlatformStand = true end
                -- Trigger awal: approach + ProximityPrompt/HoldKey sekali (jika belum cooldown)
                if not _eggIsExtracting and os.clock() >= _eggLockEnd then
                    task.spawn(function() TriggerEggIfNeeded(egg) end)
                end
                local eggGroundCF = GetEggGroundCFrame(egg)
                local eggPivot    = eggGroundCF.Position
                if os.clock() - _eggTriggeredAt < 2 then
                    -- ▶ FASE 1 (2 detik pertama setelah trigger):
                    -- CFrame diam di bawah egg (height +3) + trigger terus-menerus setiap frame
                    local belowEggCF = CFrame.new(eggPivot + Vector3.new(0, 3, 0), eggPivot)
                    CombatEngine.ResetPhysics(myHRP)
                    myHRP.CFrame = belowEggCF
                    pcall(function()
                        local prompt = GetEggPrompt(egg)
                        if prompt then
                            if fireproximityprompt then
                                fireproximityprompt(prompt)
                            else
                                prompt:InputHoldBegin()
                            end
                        end
                    end)
                else
                    -- ▶ FASE 2 (setelah 2 detik): orbit sesuai Posisi Farm + Auto Attack ke egg
                    local dropCF = GetPositionCFrame(eggPivot, EngineConfig.FarmPosition)
                    if (myHRP.Position - eggPivot).Magnitude > 50 then
                        CombatEngine.ResetPhysics(myHRP)
                        myHRP.CFrame = dropCF
                    else
                        ApplyMovement(myHRP, dropCF)
                    end
                    local now = tick()
                    local _atkInterval = EngineConfig.SelectedWeapon == "Bow" and BOW_ATTACK_INTERVAL or FARM_ATTACK_INTERVAL
                    if now - _lastFarmAttack >= _atkInterval and not _autoAttackPaused then
                        _lastFarmAttack = now
                        task.defer(function() FireWeaponAttack(egg, eggGroundCF) end)
                    end
                end
                task.wait(EngineConfig.CFrameDelay)
            end

        -- ──────────────── PRIORITAS 3: MONSTER ────────────────
        elseif EngineConfig.FarmTargetMonster and #CombatEngine.GetValidMonsters()>0 then
            noTargetTimer=0; EngineConfig.IsLockDelay=false
            -- Tandai: monster terdeteksi → chest & egg boleh diproses
            _G._worldHasMonster = true
            -- Tandai: ada monster di World3 → orbit akan dipicu saat monster habis
            if worldIdx==3 then _G._world3OrbitDone=false end
            if not _autoAttackPaused then myHum.PlatformStand=true end
            local monsters=CombatEngine.GetValidMonsters()
            local target=monsters[1]
            local tPart=target and (target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart)
            local tHum=target and target:FindFirstChildOfClass("Humanoid")
            if tPart and (not tHum or tHum.Health>0) then
                -- Simpan posisi monster terakhir (World3 & Endless Tower)
                if worldIdx==3 then _G._world3LastMonsterPos = tPart.Position end
                if worldIdx==5 then _G._endlessTowerLastPos  = tPart.Position end
                local _endlessTowerFollowing = false
                if worldIdx==5 then
                    if _G._endlessTowerDone then
                        -- Monster pertama wave baru → mulai Fase 1 (4 detik: 1s ikut, 2s diam, 1s ikut)
                        local t = tick()
                        _G._endlessTowerFollowStartAt = t
                        _G._endlessTowerFollowEndAt   = t + 4
                        _G._endlessTowerFreezePos     = nil
                        _G._endlessTowerFixedY        = nil
                        _G._endlessTowerYLockSetAt    = nil
                        if _G._endlessTowerYLockConn then pcall(function() _G._endlessTowerYLockConn:Disconnect() end) end
                        _G._endlessTowerYLockConn     = nil
                    end
                    -- Monster hadir → matikan Heartbeat hover (jika masih aktif dari countdown sebelumnya)
                    if _G._endlessTowerHoverConn then
                        pcall(function() _G._endlessTowerHoverConn:Disconnect() end)
                        _G._endlessTowerHoverConn = nil
                    end
                    _G._endlessTowerHadTarget = true
                    _G._endlessTowerDone      = false
                    _endlessTowerFollowing = tick() < (_G._endlessTowerFollowEndAt or 0)
                    -- Jika musuh muncul saat countdown 10 detik masih aktif →
                    -- skip Fase 1 (-50), langsung masuk Fase 2 Y-locked (FarmPosition)
                    -- _endlessTowerFixedY dibiarkan nil agar Fase 2 snap ke FarmPosition
                    if tick() < (_G._endlessTowerWaitUntil or 0) then
                        _endlessTowerFollowing     = false
                        _G._endlessTowerFixedY     = nil
                        _G._endlessTowerYLockSetAt = nil
                    end
                end
                if worldIdx==5 and _endlessTowerFollowing then
                    -- [ENDLESS TOWER] Fase 1 — 4 detik: 1s ikut → 2s diam → 1s ikut
                    local elapsed = tick() - (_G._endlessTowerFollowStartAt or 0)
                    CombatEngine.ResetPhysics(myHRP)
                    if elapsed < 1 or elapsed >= 3 then
                        -- Detik 0-1 dan 3-4: ikut monster (offset -50)
                        local pos = tPart.Position + Vector3.new(0, -50, 0)
                        if elapsed < 1 then
                            _G._endlessTowerFreezePos = pos  -- simpan untuk fase diam
                        end
                        local dir = (tPart.Position - pos)
                        if dir.Magnitude < 0.01 then dir = Vector3.new(1,0,0) end
                        myHRP.CFrame = CFrame.new(pos, pos + dir.Unit)
                    else
                        -- Detik 1-3: diam di posisi terakhir
                        local fpos = _G._endlessTowerFreezePos or (tPart.Position + Vector3.new(0,-50,0))
                        local dir  = (tPart.Position - fpos)
                        if dir.Magnitude < 0.01 then dir = Vector3.new(1,0,0) end
                        myHRP.CFrame = CFrame.new(fpos, fpos + dir.Unit)
                    end
                elseif worldIdx==5 then
                    -- [ENDLESS TOWER] Fase 2 — Y-Locked Follow (setelah fase follow selesai):
                    -- Y dikunci di ketinggian sesuai FarmPosition (Orbit Atas/Bawah/Diam Atas/dll),
                    -- sedangkan X dan Z tetap mengikuti monster yang bergerak.
                    -- Frame pertama: snap langsung ke posisi benar agar tidak ada artefak naik dari bawah.
                    if not _G._endlessTowerFixedY or (tick() - (_G._endlessTowerYLockSetAt or 0)) > (EngineConfig.ResetLockW5 or 3) then
                        if _G._endlessTowerYLockConn then pcall(function() _G._endlessTowerYLockConn:Disconnect() end) end
                        _G._endlessTowerYLockConn = nil
                        local snapCF = GetPositionCFrame(tPart.Position, EngineConfig.FarmPosition)
                        _G._endlessTowerFixedY   = snapCF.Position.Y
                        _G._endlessTowerYLockSetAt = tick()
                        CombatEngine.ResetPhysics(myHRP)
                        myHRP.CFrame = snapCF
                        -- Spawn Heartbeat koreksi Y: jika drift > 2 stud dari Y terkunci → snap kembali
                        if _G._endlessTowerYLockConn then pcall(function() _G._endlessTowerYLockConn:Disconnect() end) end
                        _G._endlessTowerYLockConn = Services.RunService.Heartbeat:Connect(function()
                            local lockedY = _G._endlessTowerFixedY
                            if not lockedY then
                                pcall(function() _G._endlessTowerYLockConn:Disconnect() end)
                                _G._endlessTowerYLockConn = nil
                                return
                            end
                            local c   = LocalPlayer.Character
                            local hrp = c and c:FindFirstChild("HumanoidRootPart")
                            if hrp and math.abs(hrp.Position.Y - lockedY) > 2 then
                                hrp.AssemblyLinearVelocity  = Vector3.zero
                                hrp.AssemblyAngularVelocity = Vector3.zero
                                local cf = hrp.CFrame
                                hrp.CFrame = CFrame.new(cf.Position.X, lockedY, cf.Position.Z) * cf.Rotation
                            end
                        end)
                    end
                    -- Hitung posisi setiap frame: X,Z ikut monster, Y terkunci
                    local r     = EngineConfig.OrbitRadius
                    local locY  = _G._endlessTowerFixedY
                    local angle = tick() * EngineConfig.OrbitSpeed
                    local mode  = EngineConfig.FarmPosition
                    local pos
                    if mode=="Orbit Atas" or mode=="Orbit Bawah" or mode=="Orbit Samping" then
                        pos = Vector3.new(
                            tPart.Position.X + math.cos(angle) * r,
                            locY,
                            tPart.Position.Z + math.sin(angle) * r
                        )
                    elseif mode=="Depan Target" then
                        pos = Vector3.new(tPart.Position.X + r, locY, tPart.Position.Z)
                    elseif mode=="Belakang Target" then
                        pos = Vector3.new(tPart.Position.X - r, locY, tPart.Position.Z)
                    else
                        -- Diam Atas, Diam Bawah, Acak, default
                        pos = Vector3.new(tPart.Position.X, locY, tPart.Position.Z)
                    end
                    local dir = (tPart.Position - pos)
                    if dir.Magnitude < 0.01 then dir = Vector3.new(1, 0, 0) end
                    local targetCF = CFrame.new(pos, pos + dir.Unit)
                    ApplyMovement(myHRP, targetCF)
                elseif worldIdx==4 then
                    -- [TARTARUS] Y-Locked Follow — Y dikunci sesuai FarmPosition,
                    -- X dan Z mengikuti monster. Perilaku identik dengan Endless Tower Fase 2
                    -- tapi tanpa mekanisme Fase 1 (tidak ada follow -50 di awal wave).
                    -- Reset Y lock saat: (1) target monster berganti, atau
                    -- (2) monster pindah lantai (Y shift > 10 stud) — mencegah bug "tiba-tiba ke atas".
                    local monsterY = tPart.Position.Y
                    local needReset = (_G._tartarusLastPart ~= tPart)
                        or (_G._tartarusMonsterBaseY ~= nil and math.abs(monsterY - _G._tartarusMonsterBaseY) > 10)
                        or (tick() - (_G._tartarusYLockSetAt or 0)) > (EngineConfig.ResetLockW4 or 2)
                    if needReset then
                        _G._tartarusLastPart     = tPart
                        _G._tartarusFixedY       = nil
                        _G._tartarusMonsterBaseY = nil
                        _G._tartarusYLockSetAt   = nil
                        if _G._tartarusYLockConn then
                            pcall(function() _G._tartarusYLockConn:Disconnect() end)
                            _G._tartarusYLockConn = nil
                        end
                    end
                    if not _G._tartarusFixedY then
                        local snapCF = GetPositionCFrame(tPart.Position, EngineConfig.FarmPosition)
                        _G._tartarusFixedY       = snapCF.Position.Y
                        _G._tartarusMonsterBaseY = monsterY  -- simpan Y monster saat lock dibuat
                        _G._tartarusYLockSetAt   = tick()   -- catat waktu lock dibuat
                        CombatEngine.ResetPhysics(myHRP)
                        myHRP.CFrame = snapCF
                        -- Spawn Heartbeat koreksi Y drift
                        if _G._tartarusYLockConn then pcall(function() _G._tartarusYLockConn:Disconnect() end) end
                        _G._tartarusYLockConn = Services.RunService.Heartbeat:Connect(function()
                            local lockedY = _G._tartarusFixedY
                            if not lockedY then
                                pcall(function() _G._tartarusYLockConn:Disconnect() end)
                                _G._tartarusYLockConn = nil
                                return
                            end
                            local c   = LocalPlayer.Character
                            local hrp = c and c:FindFirstChild("HumanoidRootPart")
                            if hrp and math.abs(hrp.Position.Y - lockedY) > 2 then
                                hrp.AssemblyLinearVelocity  = Vector3.zero
                                hrp.AssemblyAngularVelocity = Vector3.zero
                                local cf = hrp.CFrame
                                hrp.CFrame = CFrame.new(cf.Position.X, lockedY, cf.Position.Z) * cf.Rotation
                            end
                        end)
                    end
                    -- X,Z ikut monster, Y terkunci
                    local r     = EngineConfig.OrbitRadius
                    local locY  = _G._tartarusFixedY
                    local angle = tick() * EngineConfig.OrbitSpeed
                    local mode  = EngineConfig.FarmPosition
                    local pos
                    if mode=="Orbit Atas" or mode=="Orbit Bawah" or mode=="Orbit Samping" then
                        pos = Vector3.new(
                            tPart.Position.X + math.cos(angle) * r,
                            locY,
                            tPart.Position.Z + math.sin(angle) * r
                        )
                    elseif mode=="Depan Target" then
                        pos = Vector3.new(tPart.Position.X + r, locY, tPart.Position.Z)
                    elseif mode=="Belakang Target" then
                        pos = Vector3.new(tPart.Position.X - r, locY, tPart.Position.Z)
                    else
                        pos = Vector3.new(tPart.Position.X, locY, tPart.Position.Z)
                    end
                    local dir = (tPart.Position - pos)
                    if dir.Magnitude < 0.01 then dir = Vector3.new(1, 0, 0) end
                    local targetCF = CFrame.new(pos, pos + dir.Unit)
                    ApplyMovement(myHRP, targetCF)
                else
                    local isBoss=CombatEngine.GetLevelType(target)=="boss"
                    local savedH=EngineConfig.StandHeight
                    if isBoss then EngineConfig.StandHeight=EngineConfig.BossHeight end
                    local targetCF=GetPositionCFrame(tPart.Position,EngineConfig.FarmPosition)
                    EngineConfig.StandHeight=savedH
                    ApplyMovement(myHRP,targetCF)
                end
                -- Attack dibatasi per interval weapon: Bow lebih cepat (BOW_ATTACK_INTERVAL), Heavy normal
                -- [ENDLESS TOWER] Selama fase follow (5 detik pertama), attack & skill
                -- dijeda total — baru mulai lagi setelah fase follow selesai.
                local now=tick()
                local _atkInterval = EngineConfig.SelectedWeapon=="Bow" and BOW_ATTACK_INTERVAL or FARM_ATTACK_INTERVAL
                if now-_lastFarmAttack >= _atkInterval and not _autoAttackPaused then
                    _lastFarmAttack=now
                    local atkCF=tPart.CFrame
                    -- Bow: BaseAttack combo-6 + BulletShoot ke Model monster yang nyata
                    task.defer(function() FireWeaponAttack(target, atkCF) end)
                end
                task.wait(EngineConfig.CFrameDelay)
            else Services.RunService.Heartbeat:Wait() end

        -- ──────────────── TIDAK ADA TARGET → AUTO FIND ────────────────
        else
            -- [FIX] Tetap PlatformStand=true tepat saat target hilang, sama
            -- seperti fase Chest/Egg/Monster di atas — supaya karakter
            -- langsung "melayang" di posisi terakhir (gravity efektif
            -- di-nolkan lewat ResetPhysics setiap tick) dan tidak sempat
            -- jatuh ke tanah sebelum Auto Find / orbit World3 mengambil alih.
            if not _autoAttackPaused then myHum.PlatformStand=true end
            CombatEngine.ResetPhysics(myHRP)

            -- [ENDLESS TOWER] Tidak ada monster:
            --   • Saat monster baru saja habis → set delay 10 detik, tandai wave selesai.
            --   • Selama hitung mundur 10 detik → tahan karakter di Y=35 (siap menyambut wave baru).
            --     Jika musuh muncul di tengah hitung mundur, loop langsung masuk MONSTER branch
            --     dan Fase 1 (-50) aktif otomatis karena _endlessTowerDone=true sudah terset.
            --   • Setelah delay 10 detik → CFrame ke Portal, ulangi setiap 7 detik
            --     selama masih tidak ada monster (terpisah dari logika Fase 1).
            if worldIdx==5 then
                -- Guard: jangan set _endlessTowerDone=true saat masih dalam Fase 1
                -- (NPC baru spawn kadang belum punya HumanoidRootPart → GetValidMonsters()
                -- return 0 sesaat → tanpa guard ini _endlessTowerDone=true akan restart Fase 1)
                -- PENTING: countdown 10 detik SELALU dimulai saat hadTarget=true,
                -- tidak peduli fase1Active — supaya tidak langsung CFrame ke portal.
                local fase1Active = tick() < (_G._endlessTowerFollowEndAt or 0)
                if _G._endlessTowerHadTarget then
                    _G._endlessTowerHadTarget = false
                    _G._endlessTowerWaitUntil = tick() + 10
                    if not fase1Active then
                        -- Aman di-mark selesai (bukan window flicker NPC)
                        _G._endlessTowerDone = true  -- wave selesai; monster berikutnya trigger Fase 1
                    end
                    -- Monster habis → hentikan Y-lock (hover conn mengambil alih)
                    if _G._endlessTowerYLockConn then pcall(function() _G._endlessTowerYLockConn:Disconnect() end) end
                    _G._endlessTowerYLockConn  = nil
                    _G._endlessTowerYLockSetAt = nil
                    -- Spawn Heartbeat connection: kunci CFrame setiap frame (~60Hz)
                    -- supaya karakter benar-benar diam, bukan jitter 10fps dari task.wait(0.1)
                    if _G._endlessTowerHoverConn then pcall(function() _G._endlessTowerHoverConn:Disconnect() end) end
                    local _hoverCenter = _G._endlessTowerLastPos or myHRP.Position
                    local _hoverY      = _hoverCenter.Y + EngineConfig.EndlessTowerHoverY
                    local _hoverCF     = CFrame.new(_hoverCenter.X, _hoverY, _hoverCenter.Z)
                    _G._endlessTowerHoverConn = Services.RunService.Heartbeat:Connect(function()
                        if tick() >= (_G._endlessTowerWaitUntil or 0) then
                            pcall(function() _G._endlessTowerHoverConn:Disconnect() end)
                            _G._endlessTowerHoverConn = nil
                            return
                        end
                        local c   = LocalPlayer.Character
                        local hrp = c and c:FindFirstChild("HumanoidRootPart")
                        local hum = c and c:FindFirstChildOfClass("Humanoid")
                        if hrp then
                            if hum then hum.PlatformStand = true end
                            hrp.AssemblyLinearVelocity  = Vector3.zero
                            hrp.AssemblyAngularVelocity = Vector3.zero
                            hrp.CFrame = _hoverCF
                        end
                    end)
                end
                -- Selama hitung mundur 10 detik: Heartbeat connection sudah mengurus CFrame.
                -- Blok ini hanya sebagai fallback jika connection belum spawn (frame pertama).
                if tick() < (_G._endlessTowerWaitUntil or 0) then
                    local center = _G._endlessTowerLastPos or myHRP.Position
                    CombatEngine.ResetPhysics(myHRP)
                    myHRP.CFrame = CFrame.new(center.X, center.Y + EngineConfig.EndlessTowerHoverY, center.Z)
                else
                    -- Countdown selesai → pastikan done=true supaya wave berikutnya dapat Fase 1
                    -- (menangani kasus monster mati di dalam window fase1Active sehingga
                    --  done belum di-set di blok atas)
                    _G._endlessTowerDone = true
                    -- Setelah delay 10 detik: CFrame ke Portal setiap 7 detik
                    local now = tick()
                    if now - (_G._endlessTowerPortalAt or 0) >= 7 then
                        pcall(function()
                            local fxPart = Workspace.World.Start.Portal.EnemySpawnPortal.FX_SlowAOE
                            CombatEngine.ResetPhysics(myHRP)
                            myHRP.CFrame = fxPart.CFrame
                        end)
                        _G._endlessTowerPortalAt = now
                    end
                end
            end

            -- [TARTARUS] Reset Y-lock saat tidak ada monster agar Y dihitung ulang
            -- dari FarmPosition ketika monster berikutnya muncul.
            if worldIdx==4 and (_G._tartarusFixedY or _G._tartarusLastPart or _G._tartarusMonsterBaseY or _G._tartarusYLockSetAt) then
                _G._tartarusFixedY       = nil
                _G._tartarusLastPart     = nil
                _G._tartarusMonsterBaseY = nil
                _G._tartarusYLockSetAt   = nil
                if _G._tartarusYLockConn then
                    pcall(function() _G._tartarusYLockConn:Disconnect() end)
                    _G._tartarusYLockConn = nil
                end
            end

            -- [WORLD3] Orbit 1x cepat sesaat setelah monster habis.
            -- Orbit mengelilingi posisi monster terakhir (statis) agar tidak
            -- drift mengikuti karakter yang bergerak.
            -- Hanya berjalan sekali per wave (flag direset di blok MONSTER di atas).
            if worldIdx==3 and EngineConfig.FarmTargetMonster and not _G._world3OrbitDone then
                _G._world3OrbitDone = true
                local orbitCenter = _G._world3LastMonsterPos or myHRP.Position
                -- Durasi 1 putaran penuh (2π / speed), dibatasi max 3 detik agar selalu "cepat"
                local orbitDur = math.min(
                    math.max((2 * math.pi) / math.max(EngineConfig.OrbitSpeed, 0.5), 0.5),
                    3
                )
                local t0 = tick()
                while tick() - t0 < orbitDur and anyFarmToggleActive()
                      and #CombatEngine.GetValidMonsters() == 0 do
                    local c2 = LocalPlayer.Character
                    local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                    if h2 then
                        ApplyMovement(h2, GetPositionCFrame(orbitCenter, EngineConfig.FarmPosition))
                    end
                    task.wait(math.max(EngineConfig.CFrameDelay, 0.05))
                end
            end

            noTargetTimer=noTargetTimer+0.1
            task.wait(0.1)
            -- World Search hanya aktif jika FarmTargetMonster ON
            -- (jika hanya Chest/Egg yang on, tidak perlu cari world baru)
            if noTargetTimer>=3 and EngineConfig.FarmTargetMonster then
                noTargetTimer=0
                -- Tandai: karakter sudah melakukan find → chest & egg boleh diproses
                _G._worldHasFind = true
                if worldIdx==1 then Navigation.SearchWorld1(myHRP,myHum)
                elseif worldIdx==2 then Navigation.SearchWorld2(myHRP,myHum)
                elseif worldIdx==3 then Navigation.SearchWorld3(myHRP,myHum)
                elseif worldIdx==4 then Navigation.SearchWorld4(myHRP,myHum)
                end
            elseif noTargetTimer>=3 then
                noTargetTimer=0  -- reset timer meski tidak search, agar tidak numpuk
            end
        end
    end

    -- Cleanup saat Auto Farm dimatikan
    pcall(function() _physicsConn:Disconnect() end)
    if _G._endlessTowerHoverConn then
        pcall(function() _G._endlessTowerHoverConn:Disconnect() end)
        _G._endlessTowerHoverConn = nil
    end
    if _G._tartarusYLockConn then
        pcall(function() _G._tartarusYLockConn:Disconnect() end)
        _G._tartarusYLockConn = nil
    end
    _G._tartarusFixedY       = nil
    _G._tartarusLastPart     = nil
    _G._tartarusMonsterBaseY = nil
    _G._tartarusYLockSetAt   = nil
    pcall(function()
        local char=LocalPlayer.Character
        local myHum=char and char:FindFirstChildOfClass("Humanoid")
        -- Jangan reset PlatformStand jika Fly masih aktif
        if myHum and not EngineConfig.FlyActive then myHum.PlatformStand=false end
        EngineConfig.IsLockDelay=false
    end)
    -- Reset egg V6 state saat farm dimatikan
    _eggIsExtracting = false
    _eggLockEnd      = 0
    _eggTriggeredAt  = -math.huge
    _G._chestApproached=nil  -- reset agar chest berikutnya di-approach ulang
    _farmLoopRunning=false
end


--------------------------------------------------------------------------------
-- [S09] BACKGROUND LOOPS
--------------------------------------------------------------------------------

-- Loop: Auto Skill — hanya aktif saat menargetkan monster/chest/egg (bukan saat Find)
task.spawn(function()
    while true do
        if EngineConfig.AutoSkillActive and EngineConfig.AutoFarmActive then
            -- Cek apakah ada target aktif yang sedang di-farm (monster / chest / egg)
            local hasActiveTarget = false
            if EngineConfig.FarmTargetMonster and #CombatEngine.GetValidMonsters()>0 then
                hasActiveTarget = true
            end
            if not hasActiveTarget and EngineConfig.FarmTargetChest then
                local char=LocalPlayer.Character
                local hrp=char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    for _,c in ipairs(CombatEngine.GetValidChests()) do
                        if c.Root and (c.Root.Position-hrp.Position).Magnitude<=500 then
                            hasActiveTarget=true; break
                        end
                    end
                end
            end
            if not hasActiveTarget and EngineConfig.FarmTargetEgg then
                local char=LocalPlayer.Character
                local hrp=char and char:FindFirstChild("HumanoidRootPart")
                local egg=GetActiveDragonEgg()
                -- Pakai posisi terendah egg (bukan Part yang bisa sengaja ditaruh tinggi)
                if hrp and egg then
                    local groundCF = GetEggGroundCFrame(egg)
                    if (groundCF.Position - hrp.Position).Magnitude <= 500 then
                        hasActiveTarget = true
                    end
                end
            end

            if hasActiveTarget then
                local skills={}
                if EngineConfig.SkillActive1  then table.insert(skills,"Skill1")  end
                if EngineConfig.SkillActive2  then table.insert(skills,"Skill2")  end
                if EngineConfig.SkillActiveU  then table.insert(skills,"SkillU")  end
                if EngineConfig.SkillActiveAW then table.insert(skills,"SkillAW") end
                for _,skillName in ipairs(skills) do
                    for combo=1,3 do
                        pcall(function() PlayerActionRE:FireServer("SkillAction",skillName,combo) end)
                        task.wait(EngineConfig.SkillCooldownDelay)
                    end
                end
                task.wait(5)
            else
                task.wait(0.5)  -- tidak ada target aktif, tunggu dulu
            end
        else task.wait(0.5) end
    end
end)

-- Loop: Weapon Switcher
-- Pause auto attack selama 1 detik saat switch agar tidak tabrakan.
task.spawn(function()
    while true do
        if EngineConfig.AutoWeaponSwitchActive then
            -- Tahan auto attack dulu
            _autoAttackPaused = true
            -- Lepas PlatformStand agar server menerima weapon switch
            local char=LocalPlayer.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand=false end
            task.wait(0.05)
            pcall(function() EquipmentRE:FireServer("ChangeWeaponSlot") end)
            -- Jendela 1 detik: auto attack berhenti, beri waktu switch selesai
            task.wait(1)
            _autoAttackPaused = false
            -- Farm loop akan kembalikan PlatformStand=true otomatis di iterasi berikutnya
            task.wait(3)
        else task.wait(0.5) end
    end
end)

-- [NOTE] Auto Egg sekarang ditangani oleh startFarmLoop() di [S08] dengan prioritas Chest>Egg>Enemy.
-- Loop terpisah tidak diperlukan lagi.

-- Dapatkan RemoteEvent ConsumableShop (path baru v4.0+)
local function FindGoldShopRemote()
    local ok, re = pcall(function()
        return Services.ReplicatedStorage
            :WaitForChild("Framework", 3):WaitForChild("Features", 3)
            :WaitForChild("ConsumableShopSystem", 3):WaitForChild("ConsumableShopUtil", 3)
            :WaitForChild("RemoteEvent", 3)
    end)
    if ok and re then return re end
    return nil
end

--------------------------------------------------------------------------------
-- [GoldV2] Sistem Auto Buy V2 — via module snapshot, tidak butuh GUI terbuka
-- Metode ported dari V6: GetShopSnapshot → FireServer("BuyShopItem","Gold",ItemKey)
--------------------------------------------------------------------------------
local _ShopUtilModule = nil
local _ShopUtilRE     = nil

local function GetShopUtilModule()
    if not _ShopUtilModule then
        local ok, m = pcall(function()
            return Services.ReplicatedStorage
                :WaitForChild("Framework", 3):WaitForChild("Features", 3)
                :WaitForChild("ConsumableShopSystem", 3):WaitForChild("ConsumableShopUtil", 3)
        end)
        _ShopUtilModule = (ok and m) or nil
    end
    return _ShopUtilModule
end

local function GetShopUtil()
    local m = GetShopUtilModule()
    return m and require(m) or nil
end

local function GetShopUtilRE()
    if not _ShopUtilRE then
        local m = GetShopUtilModule()
        _ShopUtilRE = m and m:FindFirstChild("RemoteEvent") or nil
    end
    return _ShopUtilRE
end

-- [GoldV2] Terjemahkan ItemId ke nama visual via TranslationUtil game
-- Ported dari V6: GetItemDisplayName — prioritas TranslationUtil, fallback underscore→spasi
local _FrameworkModuleCache = nil
local function GetFrameworkSafe()
    if not _FrameworkModuleCache then
        pcall(function()
            _FrameworkModuleCache = require(
                Services.ReplicatedStorage:WaitForChild("Framework", 5)
            )
        end)
    end
    return _FrameworkModuleCache
end

local function GetItemDisplayName(ItemId)
    local RawId  = tostring(ItemId or "Unknown")
    local BaseId = string.split(RawId, ":")[1]
    local Key    = "K_" .. string.upper(BaseId)
    local DisplayName = nil
    pcall(function()
        local fw = GetFrameworkSafe()
        if fw and fw.Modules and fw.Modules.TranslationUtil then
            DisplayName = fw.Modules.TranslationUtil:TranslateByKey(Key)
        end
    end)
    if type(DisplayName) == "string" and DisplayName ~= "" and DisplayName ~= Key then
        return DisplayName
    end
    -- Fallback: ganti underscore dengan spasi (e.g. "Gold_HealthPotion" → "Gold HealthPotion")
    return string.gsub(BaseId, "_", " ")
end

-- Ambil katalog lengkap Gold Shop via module (tanpa perlu GUI terbuka)
-- Prioritas: getupvalues(ShopUtil.BuyItem) → fallback GetShopSnapshot
local _CachedGoldV2Catalog = nil
local function GetGoldShopCatalog(ForceRefresh)
    if _CachedGoldV2Catalog and not ForceRefresh then
        return _CachedGoldV2Catalog
    end
    local ShopUtil = GetShopUtil()
    if not ShopUtil then return {} end

    local ById = {}
    local function AddItem(ItemKey, Item)
        if type(Item) ~= "table" or type(Item.ItemId) ~= "string" then return end
        if not ById[Item.ItemId] then
            ById[Item.ItemId] = {
                ItemId   = Item.ItemId,
                ItemType = Item.ItemType,
                Price    = Item.Price,
                StockMin = Item.StockMin or Item.Stock,
                StockMax = Item.StockMax or Item.Stock,
                ItemKey  = ItemKey,
            }
        end
    end

    -- Coba getupvalues terlebih dahulu (lebih lengkap, tanpa butuh login snapshot)
    local FullPool = nil
    if getupvalues and type(ShopUtil.BuyItem) == "function" then
        pcall(function()
            local Upvalues = getupvalues(ShopUtil.BuyItem)
            local ShopItems = type(Upvalues) == "table" and Upvalues[2]
            FullPool = type(ShopItems) == "table" and ShopItems.Gold or nil
        end)
    end

    if type(FullPool) == "table" then
        for _, ItemKey in ipairs(FullPool.__index or {}) do
            AddItem(ItemKey, FullPool[ItemKey])
        end
        for ItemKey, Item in pairs(FullPool) do
            if ItemKey ~= "__index" then AddItem(ItemKey, Item) end
        end
    else
        -- Fallback: ambil dari snapshot live
        pcall(function()
            local Snapshot = ShopUtil:GetShopSnapshot(LocalPlayer, "Gold")
            if Snapshot and type(Snapshot.Items) == "table" then
                for ItemKey, Item in pairs(Snapshot.Items) do
                    AddItem(ItemKey, Item)
                end
            end
        end)
    end

    local result = {}
    for _, v in pairs(ById) do table.insert(result, v) end
    table.sort(result, function(a, b) return a.ItemId < b.ItemId end)
    _CachedGoldV2Catalog = result
    return result
end

-- [SeasonV2] Catalog Season Shop via ResSeasonShop config module — tidak butuh GUI terbuka
local _CachedSeasonCatalog = nil
local function GetSeasonShopCatalog(ForceRefresh)
    if _CachedSeasonCatalog and not ForceRefresh then
        return _CachedSeasonCatalog
    end
    local ok, ResSeasonShop = pcall(function()
        return require(
            Services.ReplicatedStorage
                :WaitForChild("Configs", 5)
                :WaitForChild("ResSeasonShop", 5)
        )
    end)
    if not ok or type(ResSeasonShop) ~= "table" then return {} end

    local ById = {}
    for ShopId, Item in pairs(ResSeasonShop) do
        if ShopId ~= "__index" and type(Item) == "table" and type(Item.ItemId) == "string" then
            if not ById[Item.ItemId] then
                ById[Item.ItemId] = {
                    ItemId     = Item.ItemId,
                    ItemType   = Item.ItemType,
                    Price      = Item.Price,
                    ItemCount  = Item.ItemCount,
                    LimitTimes = Item.LimitTimes,
                    IsSpecial  = Item.IsSpecial == true,
                    ShopId     = ShopId,
                }
            end
        end
    end

    local result = {}
    for _, v in pairs(ById) do table.insert(result, v) end
    table.sort(result, function(a, b) return tostring(a.ShopId) < tostring(b.ShopId) end)
    _CachedSeasonCatalog = result
    return result
end

-- [BondV2] Catalog Bond Shop via ConsumableShopUtil — tidak butuh GUI terbuka
-- Prioritas: getupvalues(ShopUtil.BuyItem).Bond → fallback GetShopSnapshot("Bond")
local _CachedBondCatalog = nil
local function GetBondShopCatalog(ForceRefresh)
    if _CachedBondCatalog and not ForceRefresh then
        return _CachedBondCatalog
    end
    local ShopUtil = GetShopUtil()
    if not ShopUtil then return {} end

    local ById = {}
    local function AddItem(ItemKey, Item)
        if type(Item) ~= "table" or type(Item.ItemId) ~= "string" then return end
        if not ById[Item.ItemId] then
            ById[Item.ItemId] = {
                ItemId   = Item.ItemId,
                ItemType = Item.ItemType,
                Price    = Item.Price,
                StockMin = Item.StockMin or Item.Stock,
                StockMax = Item.StockMax or Item.Stock,
                ItemKey  = ItemKey,
            }
        end
    end

    local FullPool = nil
    if getupvalues and type(ShopUtil.BuyItem) == "function" then
        pcall(function()
            local Upvalues = getupvalues(ShopUtil.BuyItem)
            local ShopItems = type(Upvalues) == "table" and Upvalues[2]
            FullPool = type(ShopItems) == "table" and ShopItems.Bond or nil
        end)
    end

    if type(FullPool) == "table" then
        for _, ItemKey in ipairs(FullPool.__index or {}) do
            AddItem(ItemKey, FullPool[ItemKey])
        end
        for ItemKey, Item in pairs(FullPool) do
            if ItemKey ~= "__index" then AddItem(ItemKey, Item) end
        end
    else
        pcall(function()
            local Snapshot = ShopUtil:GetShopSnapshot(LocalPlayer, "Bond")
            if Snapshot and type(Snapshot.Items) == "table" then
                for ItemKey, Item in pairs(Snapshot.Items) do
                    AddItem(ItemKey, Item)
                end
            end
        end)
    end

    local result = {}
    for _, v in pairs(ById) do table.insert(result, v) end
    table.sort(result, function(a, b) return a.ItemId < b.ItemId end)
    _CachedBondCatalog = result
    return result
end

-- Dapatkan ScrollingFrame Season Shop
-- Path: PlayerGui.MainGuiIgnoreGuiInset.ScreenSeasonPass.StoreStatistics.NormalFrame.ScrollingFrame
local function FindSeasonShopScrollingFrame()
    local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pgui then return nil end
    local ok, sf = pcall(function()
        return pgui
            :FindFirstChild("MainGuiIgnoreGuiInset")
            :FindFirstChild("ScreenSeasonPass")
            :FindFirstChild("StoreStatistics")
            :FindFirstChild("NormalFrame")
            :FindFirstChild("ScrollingFrame")
    end)
    return (ok and sf) or nil
end

-- Dapatkan ScrollingFrame toko (ScreenConsumableShop)
local function FindGoldShopScrollingFrame()
    local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pgui then return nil end
    local mainGui = pgui:FindFirstChild("MainGui")
    if mainGui then
        local screen = mainGui:FindFirstChild("ScreenConsumableShop")
        if screen then
            local content = screen:FindFirstChild("Content")
            if content then
                local sf = content:FindFirstChildWhichIsA("ScrollingFrame")
                if sf then return sf end
            end
        end
    end
    return nil
end

-- Loop: Auto Join Room — TP ke room → buat room sesuai setting → tunggu 30 detik → ulang
task.spawn(function()
    while true do
        task.wait(1)
        if EngineConfig.AutoJoinRoomActive then
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")

            -- Step 1: TP ke target room
            local targetRoom = EngineConfig.RoomTarget or "Room1"
            local mrf = Workspace:FindFirstChild("MatchRoom")
            local rf  = mrf and mrf:FindFirstChild(targetRoom)
            local tm  = rf  and rf:FindFirstChild("Touch")
            local tp  = tm  and tm:FindFirstChild("Part")
            if hrp and tp and tp:IsA("BasePart") then
                CombatEngine.ResetPhysics(hrp)
                hrp.CFrame = tp.CFrame
                CustomNotify("🔁 AUTO JOIN","TP ke "..targetRoom,2)
            end
            task.wait(1)

            -- Step 2: Buat room sesuai setting yang dipilih
            local key = ROOM_WORLD_KEY and ROOM_WORLD_KEY[EngineConfig.RoomWorldDisplay] or "World1"
            pcall(function()
                GameMatchRE:FireServer("CreatRoom", key, EngineConfig.RoomMode, EngineConfig.RoomPlayers)
                CustomNotify("🔁 AUTO JOIN","Room: "..tostring(EngineConfig.RoomWorldDisplay).." [M:"..tostring(EngineConfig.RoomMode).."]",3)
            end)

            -- Step 3: Tunggu 30 detik sebelum siklus berikutnya
            local elapsed = 0
            while elapsed < 30 and EngineConfig.AutoJoinRoomActive do
                task.wait(1); elapsed = elapsed + 1
            end
        end
    end
end)

-- Loop: Auto Buy — Gold & Bond (klik BuyBTN di ConsumableShop GUI)
task.spawn(function()
    while true do
        task.wait(0.1)
        if EngineConfig.AutoBuyActive then
            local sf = FindGoldShopScrollingFrame()
            if sf then
                for _, item in pairs(sf:GetChildren()) do
                    if EngineConfig.AutoBuyTargetList[item.Name] then
                        local stockTXT = item:FindFirstChild("StockTXT", true)
                        local stok = tonumber(stockTXT and stockTXT.Text:match("%d+")) or 0
                        if stok >= 1 and stok <= 9 then
                            local buyBtn = item:FindFirstChild("BuyBTN", true)
                            if buyBtn then
                                pcall(function()
                                    for _, conn in ipairs(getconnections(buyBtn.MouseButton1Down)) do
                                        conn:Fire()
                                    end
                                end)
                                task.wait(0.4)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Loop: Auto Buy — Season (FireServer langsung, tidak butuh GUI terbuka)
task.spawn(function()
    local SeasonUtilRE = H.SeasonUtilRE
    while true do
        task.wait(0.5)
        if EngineConfig.AutoBuyActive and SeasonUtilRE then
            for itemName in pairs(EngineConfig.AutoBuyTargetList) do
                if itemName:find("^SeasonShop_") then
                    pcall(function()
                        SeasonUtilRE:FireServer("BuySeasonShopItem", itemName)
                    end)
                    task.wait(0.3)
                end
            end
        end
    end
end)

-- Loop: Auto Buy BondV2 — via GetShopSnapshot → FireServer("BuyShopItem","Bond",ItemKey)
-- Tidak butuh GUI terbuka. Mirror dari loop GoldV2.
local AutoBuyBondDelay = 0.55
task.spawn(function()
    while true do
        task.wait(AutoBuyBondDelay)
        if EngineConfig.AutoBuyActive then
            local hasV2 = false
            for k in pairs(EngineConfig.AutoBuyTargetList) do
                if k:find("^BondV2_") then hasV2 = true; break end
            end
            if hasV2 then
                local ShopUtil = GetShopUtil()
                local RE       = GetShopUtilRE()
                if ShopUtil and RE then
                    pcall(function()
                        local Snapshot = ShopUtil:GetShopSnapshot(LocalPlayer, "Bond")
                        local Items    = Snapshot and Snapshot.Items
                        if type(Items) ~= "table" then return end
                        for ItemKey, Item in pairs(Items) do
                            if type(Item) == "table" and Item.State == "normal" then
                                local wantKey = "BondV2_" .. tostring(Item.ItemId)
                                if EngineConfig.AutoBuyTargetList[wantKey] then
                                    RE:FireServer("BuyShopItem", "Bond", ItemKey)
                                    task.wait(AutoBuyBondDelay)
                                end
                            end
                        end
                    end)
                end
            end
        end
    end
end)

-- Loop: Auto Buy GoldV2 — via GetShopSnapshot → FireServer("BuyShopItem","Gold",ItemKey)
-- Tidak butuh GUI terbuka. Metode ported dari V6.
local AutoBuyV2Delay = 0.55
task.spawn(function()
    while true do
        task.wait(AutoBuyV2Delay)
        if EngineConfig.AutoBuyActive then
            -- Cek cepat: ada item GoldV2_ yang dipilih?
            local hasV2 = false
            for k in pairs(EngineConfig.AutoBuyTargetList) do
                if k:find("^GoldV2_") then hasV2 = true; break end
            end
            if hasV2 then
                local ShopUtil = GetShopUtil()
                local RE       = GetShopUtilRE()
                if ShopUtil and RE then
                    pcall(function()
                        local Snapshot = ShopUtil:GetShopSnapshot(LocalPlayer, "Gold")
                        local Items    = Snapshot and Snapshot.Items
                        if type(Items) ~= "table" then return end
                        for ItemKey, Item in pairs(Items) do
                            if type(Item) == "table" and Item.State == "normal" then
                                local wantKey = "GoldV2_" .. tostring(Item.ItemId)
                                if EngineConfig.AutoBuyTargetList[wantKey] then
                                    RE:FireServer("BuyShopItem", "Gold", ItemKey)
                                    task.wait(AutoBuyV2Delay)
                                end
                            end
                        end
                    end)
                end
            end
        end
    end
end)

--------------------------------------------------------------------------------

-- [S09-FLY] BACKGROUND LOOP: Fly  (Infinite Yield style)
-- BodyVelocity + BodyGyro → hover stabil, gravity sepenuhnya dinetralisir.
-- Mobile: joystick bawaan Roblox (horizontal) + virtual joystick kanan (vertikal).
-- PC    : WASD horizontal · Space naik · Ctrl/Shift turun.
--------------------------------------------------------------------------------
local _UIS = Services.UserInputService

--------------------------------------------------------------------------------
-- Helper: hancurkan BodyMover yang tertinggal di HRP
local function _destroyFlyObjects(hrp)
    if not hrp then return end
    local bv = hrp:FindFirstChild("_XiFilFlyBV")
    local bg = hrp:FindFirstChild("_XiFilFlyBG")
    if bv then bv:Destroy() end
    if bg then bg:Destroy() end
end

-- Helper: kembalikan CanCollide semua part karakter ke true
local function _restoreCollision(char)
    if not char then return end
    for _, p in pairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = true end
    end
end

--------------------------------------------------------------------------------
-- LOOP UTAMA FLY
--------------------------------------------------------------------------------
task.spawn(function()
    local _flyBV   = nil
    local _flyBG   = nil
    local _prevHRP = nil
    local _prevFly = false

    while true do
        Services.RunService.Heartbeat:Wait()

        if EngineConfig.FlyActive then
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum then
                -- ── Setup awal / setelah respawn ──────────────────────────
                if not _prevFly or hrp ~= _prevHRP then
                    if _prevHRP and _prevHRP ~= hrp then
                        _destroyFlyObjects(_prevHRP)
                    end
                    _prevFly = true
                    _prevHRP = hrp

                    hum.PlatformStand = true

                    _flyBV          = Instance.new("BodyVelocity")
                    _flyBV.Name     = "_XiFilFlyBV"
                    _flyBV.Velocity = Vector3.zero
                    _flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                    _flyBV.P        = 1e4
                    _flyBV.Parent   = hrp

                    _flyBG           = Instance.new("BodyGyro")
                    _flyBG.Name      = "_XiFilFlyBG"
                    _flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
                    _flyBG.P         = 1e4
                    _flyBG.D         = 100
                    _flyBG.CFrame    = hrp.CFrame
                    _flyBG.Parent    = hrp

                end

                -- ── Baca input gerak (camera-relative 3D, persis Infinite Yield) ──
                --
                -- Cara IY: joystick/WASD dikali vektor PENUH kamera (termasuk Y).
                -- → Miringkan kamera ke atas + dorong joystick maju = terbang naik.
                -- → Miringkan kamera ke bawah + dorong joystick maju = terbang turun.
                -- Tidak perlu joystick kedua; 1 joystick + rotasi kamera = 6 arah.
                --
                local cam  = Workspace.CurrentCamera
                local move = Vector3.zero

                if cam then
                    local camCF = cam.CFrame

                    -- Proyeksikan MoveDirection (flat world-space) ke sumbu kamera
                    -- agar dapat skalar maju/mundur dan kiri/kanan.
                    local flatLook  = Vector3.new(camCF.LookVector.X,  0, camCF.LookVector.Z)
                    local flatRight = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
                    local md = hum.MoveDirection   -- diisi Roblox dari joystick/WASD/gamepad

                    local fwd   = flatLook.Magnitude  > 0.01
                                  and md:Dot(flatLook.Unit)  or 0
                    local right = flatRight.Magnitude > 0.01
                                  and md:Dot(flatRight.Unit) or 0

                    -- Kalikan dengan vektor kamera PENUH (Y ikut → gerak 3D sejati)
                    move = camCF.LookVector * fwd + camCF.RightVector * right
                end

                -- Vertikal eksplisit: Space/Jump naik · Ctrl/Shift turun (PC & gamepad)
                -- Mobile: miringkan kamera ke atas/bawah + dorong joystick = naik/turun
                local vy = 0
                if _UIS:IsKeyDown(Enum.KeyCode.Space)
                or _UIS:IsKeyDown(Enum.KeyCode.ButtonA)
                   then vy = 1 end
                if _UIS:IsKeyDown(Enum.KeyCode.LeftControl)
                or _UIS:IsKeyDown(Enum.KeyCode.LeftShift)
                or _UIS:IsKeyDown(Enum.KeyCode.DPadDown)
                   then vy = -1 end
                move = move + Vector3.new(0, vy, 0)

                -- ── Terapkan velocity ─────────────────────────────────────
                local speed = math.max(EngineConfig.FlySpeed or 50, 1)
                if _flyBV and _flyBV.Parent then
                    _flyBV.Velocity = if move.Magnitude > 0
                        then move.Unit * speed
                        else Vector3.zero
                end

                -- ── Gyro: hadap arah kamera, karakter tegak ───────────────
                local cam = Workspace.CurrentCamera
                if _flyBG and _flyBG.Parent and cam then
                    local flatLook = Vector3.new(
                        cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
                    if flatLook.Magnitude > 0.01 then
                        _flyBG.CFrame = CFrame.new(Vector3.zero, flatLook)
                    end
                end

                -- ── Noclip ───────────────────────────────────────────────
                for _, p in pairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end

        elseif _prevFly then
            -- ── Cleanup saat fly dimatikan ────────────────────────────────
            _prevFly = false
            _destroyFlyObjects(_prevHRP)
            _flyBV, _flyBG = nil, nil

            local char = _prevHRP and _prevHRP.Parent
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum and not EngineConfig.AutoFarmActive then
                hum.PlatformStand = false
            end
            _restoreCollision(char)
            _prevHRP = nil
        end
    end
end)

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Export ke Hub
--------------------------------------------------------------------------------
H.startFarmLoop              = startFarmLoop
H.FindGoldShopScrollingFrame  = FindGoldShopScrollingFrame    -- digunakan tab_autobuy
H.FindSeasonShopScrollingFrame = FindSeasonShopScrollingFrame -- digunakan tab_autobuy
H.GetGoldShopCatalog          = GetGoldShopCatalog            -- digunakan tab_autobuy (GoldV2)
H.GetBondShopCatalog          = GetBondShopCatalog            -- digunakan tab_autobuy (BondV2)
H.GetSeasonShopCatalog        = GetSeasonShopCatalog          -- digunakan tab_autobuy (SeasonV2)
H.GetShopUtilRE               = GetShopUtilRE                 -- digunakan tab_autobuy (GoldV2/BondV2)
H.GetItemDisplayName          = GetItemDisplayName            -- digunakan tab_autobuy (visual name)
