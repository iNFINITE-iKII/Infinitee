--------------------------------------------------------------------------------
--// auto_potion.lua — Auto Potion System
-- Ported dari V6 script, disesuaikan dengan arsitektur ironsoulv1.
-- Secara otomatis menggunakan potion buff yang dipilih user saat buff habis.
--
-- Alur:
--   1. BuildCatalog  — scan ResPotion config, filter PotionType=="Buff"
--   2. RebuildSignals — pasang listener perubahan buff attribute di PlayerAttrEntry
--   3. StartScanner   — loop 15 detik sebagai fallback
--   4. Saat buff habis / masuk dungeon → Scan → Enqueue → UseOne
--------------------------------------------------------------------------------
local H            = getgenv().Hub
local EngineConfig = H.EngineConfig
local Services     = H.Services
local LocalPlayer  = H.LocalPlayer

local ReplicatedStorage = Services.ReplicatedStorage

-- ── Framework helper ─────────────────────────────────────────────────────────
local _cachedFramework = nil
local function GetFramework()
    if not _cachedFramework then
        local ok, fw = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Framework", 10))
        end)
        if ok and fw then _cachedFramework = fw end
    end
    return _cachedFramework
end

local function GetItemDisplayName(ItemId)
    if H.GetItemDisplayName then return H.GetItemDisplayName(ItemId) end
    return tostring(ItemId)
end

-- ── State ────────────────────────────────────────────────────────────────────
local AutoPotion = {
    ScanInterval         = 15,
    QueueSpacing         = 0.65,
    ConfirmTimeout       = 5,
    DungeonGraceSeconds  = 10,
    -- Runtime state
    Selected             = {},   -- PotionId → bool; sync ke EngineConfig.AutoPotionSelected
    Catalog              = {},   -- PotionId → Entry
    Order                = {},   -- sorted list of PotionId
    ByBuffId             = {},   -- AttributeId → {PotionId, ...}
    Pending              = {},   -- PotionId → bool (UseOne sedang jalan)
    ActivationPending    = {},   -- PotionId → bool (potion sudah dikirim, nunggu buff aktif)
    RetryOnScan          = {},   -- PotionId → bool (timeout, coba lagi di scan berikutnya)
    Queue                = {},   -- list PotionId menunggu diproses
    Queued               = {},   -- PotionId → bool (sudah di Queue)
    Connections          = {},   -- AttributeId → RBXScriptConnection
    LifecycleConnections = {},   -- {RBXScriptConnection, ...}
    WorkerRunning        = false,
    ScanGeneration       = 0,
    GraceGeneration      = 0,
    GraceStartedAt       = nil,
    GraceCharacter       = nil,
    GraceAttrEntry       = nil,
    LastRequestAt        = -math.huge,
    Status               = "OFF",
    Refresh              = nil,  -- callback ke UI untuk update status label
    Token                = { Alive = true },
}

-- ── Catalog helpers ───────────────────────────────────────────────────────────
function AutoPotion.ShouldCatalog(Definition)
    return type(Definition) == "table" and Definition.PotionType == "Buff"
end

-- Baca semua BuffId/Duration dari definisi potion (BuffId1/Duration1, dst.)
function AutoPotion.GetBuffFields(Definition)
    local BuffIds, Durations = {}, {}
    local Index = 1
    while true do
        local BuffId   = Definition["BuffId"   .. Index]
        local Duration = Definition["Duration" .. Index]
        if BuffId == nil or Duration == nil then break end
        if BuffId ~= "" and Duration ~= "" then
            table.insert(BuffIds,   tostring(BuffId))
            table.insert(Durations, tonumber(Duration) or 0)
        end
        Index = Index + 1
    end
    return BuffIds, Durations
end

-- "Buff_DropRateBoost_1" → {"Buff_DropRateBoost_1", "DropRateBoost"}
function AutoPotion.GetBuffAttributeIds(BuffId)
    local Ids               = { BuffId }
    local NativeAttributeId = string.match(BuffId, "^Buff_(.+)_%d+$")
    if NativeAttributeId and NativeAttributeId ~= BuffId then
        table.insert(Ids, NativeAttributeId)
    end
    return Ids
end

-- Semua buff dalam list harus > 0 agar dianggap aktif
function AutoPotion.AreBuffsActive(BuffIds, GetValue)
    if type(BuffIds) ~= "table" or #BuffIds <= 0 then return false end
    for _, BuffId in ipairs(BuffIds) do
        if (tonumber(GetValue(BuffId)) or 0) <= 0 then return false end
    end
    return true
end

-- Logika pusat: apakah potion harus di-queue?
function AutoPotion.ShouldQueueState(Selected, Owned, Active, Queued, Pending, ActivationPending)
    return Selected == true
        and (tonumber(Owned) or 0) > 0
        and not Active
        and not Queued
        and not Pending
        and not ActivationPending
end

-- ── Status & Refresh ──────────────────────────────────────────────────────────
function AutoPotion.RefreshState()
    if AutoPotion.Refresh then pcall(AutoPotion.Refresh) end
end

function AutoPotion.SetStatus(Status)
    if AutoPotion.Status == Status then return end
    AutoPotion.Status = Status
    AutoPotion.RefreshState()
end

-- ── Build Catalog ─────────────────────────────────────────────────────────────
function AutoPotion.BuildCatalog(ForceRefresh)
    local fw = GetFramework()
    if not fw then return {}, {} end
    local PotionUtil = fw.Modules and fw.Modules.PotionUtil
    if not PotionUtil then return {}, {} end

    -- Refresh hanya owned count jika catalog sudah ada dan tidak dipaksa rebuild
    if not ForceRefresh and #AutoPotion.Order > 0 then
        for _, PotionId in ipairs(AutoPotion.Order) do
            local Entry = AutoPotion.Catalog[PotionId]
            if Entry then
                Entry.Owned = tonumber(PotionUtil:GetOwnedAmount(LocalPlayer, PotionId)) or 0
            end
        end
        return AutoPotion.Catalog, AutoPotion.Order
    end

    local ok, ResPotion = pcall(function()
        return require(
            ReplicatedStorage:WaitForChild("Configs", 10)
                             :WaitForChild("ResPotion", 10)
        )
    end)
    if not ok or not ResPotion then return {}, {} end

    local Catalog, Order, ByBuffId, Seen = {}, {}, {}, {}

    local function AddPotion(PotionId)
        if type(PotionId) ~= "string" or Seen[PotionId] then return end
        Seen[PotionId] = true
        local Definition = ResPotion[PotionId]
        if not AutoPotion.ShouldCatalog(Definition) then return end
        local BuffIds, Durations = AutoPotion.GetBuffFields(Definition)
        local Entry = {
            PotionId    = PotionId,
            DisplayName = GetItemDisplayName(PotionId),
            Icon        = Definition.Icon,
            BuffIds     = BuffIds,
            Durations   = Durations,
            Definition  = Definition,
            Owned       = tonumber(PotionUtil:GetOwnedAmount(LocalPlayer, PotionId)) or 0,
        }
        Catalog[PotionId] = Entry
        table.insert(Order, PotionId)
        for _, BuffId in ipairs(BuffIds) do
            for _, AttributeId in ipairs(AutoPotion.GetBuffAttributeIds(BuffId)) do
                ByBuffId[AttributeId] = ByBuffId[AttributeId] or {}
                table.insert(ByBuffId[AttributeId], PotionId)
            end
        end
    end

    -- Iterasi ordered index dulu, lalu key-value pairs sebagai fallback
    for _, PotionId in ipairs(ResPotion.__index or {}) do AddPotion(PotionId) end
    for PotionId in pairs(ResPotion) do AddPotion(PotionId) end

    -- Sort alfabetis berdasarkan DisplayName
    table.sort(Order, function(L, R)
        local LeftName  = string.lower((Catalog[L] and Catalog[L].DisplayName) or L)
        local RightName = string.lower((Catalog[R] and Catalog[R].DisplayName) or R)
        if LeftName == RightName then return L < R end
        return LeftName < RightName
    end)

    -- Hapus potion dipilih yang sudah tidak ada di catalog (update config)
    local SelectionChanged = false
    for PotionId in pairs(AutoPotion.Selected) do
        if not Catalog[PotionId] then
            AutoPotion.Selected[PotionId] = nil
            SelectionChanged = true
        end
    end

    AutoPotion.Catalog  = Catalog
    AutoPotion.Order    = Order
    AutoPotion.ByBuffId = ByBuffId

    if SelectionChanged then
        EngineConfig.AutoPotionSelected = AutoPotion.Selected
    end

    return Catalog, Order
end

-- ── Dungeon Eligibility ───────────────────────────────────────────────────────
function AutoPotion.GetPlayerAttrEntry()
    return LocalPlayer:FindFirstChild("PlayerAttrEntry")
end

function AutoPotion.IsEndlessTower()
    local World = workspace:FindFirstChild("World")
    return World ~= nil and World:FindFirstChild("Start") ~= nil
end

function AutoPotion.IsSettlementVisible()
    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local ResultGui = PlayerGui and PlayerGui:FindFirstChild("ResultGui")
    local ScreenSet = ResultGui and ResultGui:FindFirstChild("ScreenSettlement")
    if not ScreenSet then return false end
    local Current = ScreenSet
    while Current and Current ~= game do
        if Current:IsA("GuiObject")      and not Current.Visible  then return false end
        if Current:IsA("LayerCollector") and not Current.Enabled  then return false end
        Current = Current.Parent
    end
    return true
end

function AutoPotion.ResetDungeonGrace()
    if AutoPotion.GraceStartedAt or AutoPotion.GraceCharacter or AutoPotion.GraceAttrEntry then
        AutoPotion.GraceGeneration = AutoPotion.GraceGeneration + 1
    end
    AutoPotion.GraceStartedAt = nil
    AutoPotion.GraceCharacter = nil
    AutoPotion.GraceAttrEntry = nil
end

-- Tunda pakai potion DungeonGraceSeconds detik setelah masuk dungeon baru
function AutoPotion.CheckDungeonGrace(Character, PlayerAttrEntry)
    if AutoPotion.GraceCharacter ~= Character
        or AutoPotion.GraceAttrEntry ~= PlayerAttrEntry
        or not AutoPotion.GraceStartedAt then
        AutoPotion.GraceGeneration = AutoPotion.GraceGeneration + 1
        local Generation = AutoPotion.GraceGeneration
        AutoPotion.GraceStartedAt = os.clock()
        AutoPotion.GraceCharacter = Character
        AutoPotion.GraceAttrEntry = PlayerAttrEntry
        task.delay(AutoPotion.DungeonGraceSeconds, function()
            if AutoPotion.Token.Alive
                and EngineConfig.AutoPotionActive
                and Generation == AutoPotion.GraceGeneration
                and AutoPotion.GraceCharacter == Character
                and AutoPotion.GraceAttrEntry == PlayerAttrEntry then
                pcall(AutoPotion.Scan, false)
            end
        end)
    end
    local Remaining = AutoPotion.DungeonGraceSeconds - (os.clock() - AutoPotion.GraceStartedAt)
    if Remaining > 0 then
        return false, "GRACE " .. tostring(math.ceil(Remaining)) .. "S"
    end
    return true
end

-- Kembalikan true jika kondisi dungeon valid untuk pakai potion
function AutoPotion.IsDungeonEligible()
    if workspace:GetAttribute("LoadingEnd") ~= true then
        AutoPotion.ResetDungeonGrace()
        return false, "BLOCKED - LOADING"
    end
    if AutoPotion.IsEndlessTower() then
        AutoPotion.ResetDungeonGrace()
        return false, "BLOCKED - ENDLESS TOWER"
    end
    if AutoPotion.IsSettlementVisible() then
        AutoPotion.ResetDungeonGrace()
        return false, "BLOCKED - SETTLEMENT"
    end
    local Character       = LocalPlayer.Character
    local PlayerAttrEntry = AutoPotion.GetPlayerAttrEntry()
    if not Character or not PlayerAttrEntry then
        AutoPotion.ResetDungeonGrace()
        return false, "BLOCKED - LOADING"
    end
    return AutoPotion.CheckDungeonGrace(Character, PlayerAttrEntry)
end

-- ── Buff State ────────────────────────────────────────────────────────────────
function AutoPotion.IsEntryActive(Entry)
    local PlayerAttrEntry = AutoPotion.GetPlayerAttrEntry()
    if not Entry or not PlayerAttrEntry then return false end
    return AutoPotion.AreBuffsActive(Entry.BuffIds, function(BuffId)
        for _, AttributeId in ipairs(AutoPotion.GetBuffAttributeIds(BuffId)) do
            local Value = tonumber(PlayerAttrEntry:GetAttribute(AttributeId)) or 0
            if Value > 0 then return Value end
        end
        return 0
    end)
end

-- State yang ditampilkan di UI per-potion
function AutoPotion.GetEntryState(Entry)
    if not Entry or #Entry.BuffIds <= 0 or not AutoPotion.GetPlayerAttrEntry() then
        return "Unavailable"
    end
    if AutoPotion.Pending[Entry.PotionId] or AutoPotion.ActivationPending[Entry.PotionId] then
        return "Pending"
    end
    if AutoPotion.IsEntryActive(Entry)             then return "Active"       end
    if (tonumber(Entry.Owned) or 0) <= 0           then return "Out of Stock" end
    return "Inactive"
end

-- ── Queue & Use ───────────────────────────────────────────────────────────────
function AutoPotion.Enqueue(PotionId)
    if AutoPotion.Queued[PotionId] or AutoPotion.Pending[PotionId] then return false end
    AutoPotion.Queued[PotionId] = true
    table.insert(AutoPotion.Queue, PotionId)
    if not AutoPotion.WorkerRunning then
        AutoPotion.WorkerRunning = true
        task.spawn(AutoPotion.RunQueue)
    end
    AutoPotion.RefreshState()
    return true
end

function AutoPotion.EvaluatePotion(PotionId, AllowRetry)
    local Entry = AutoPotion.Catalog[PotionId]
    if not Entry or not AutoPotion.Selected[PotionId] then return false end
    if AutoPotion.RetryOnScan[PotionId] then
        if not AllowRetry then return false end
        AutoPotion.RetryOnScan[PotionId] = nil
    end
    local fw         = GetFramework()
    local PotionUtil = fw and fw.Modules and fw.Modules.PotionUtil
    if PotionUtil then
        Entry.Owned = tonumber(PotionUtil:GetOwnedAmount(LocalPlayer, PotionId)) or 0
    end
    local Active = AutoPotion.IsEntryActive(Entry)
    if Active then AutoPotion.ActivationPending[PotionId] = nil end
    if AutoPotion.ShouldQueueState(
        true, Entry.Owned, Active,
        AutoPotion.Queued[PotionId],
        AutoPotion.Pending[PotionId],
        AutoPotion.ActivationPending[PotionId]
    ) then
        return AutoPotion.Enqueue(PotionId)
    end
    return false
end

function AutoPotion.Scan(ForceRefresh, AllowRetry)
    if not EngineConfig.AutoPotionActive or not AutoPotion.Token.Alive then return end
    AutoPotion.BuildCatalog(ForceRefresh == true)
    local Eligible, Reason = AutoPotion.IsDungeonEligible()
    if not Eligible then
        AutoPotion.SetStatus(Reason or "BLOCKED")
        return
    end
    local QueuedAny = false
    for _, PotionId in ipairs(AutoPotion.Order) do
        if AutoPotion.Selected[PotionId] and AutoPotion.EvaluatePotion(PotionId, AllowRetry) then
            QueuedAny = true
        end
    end
    if not QueuedAny and not AutoPotion.WorkerRunning then
        AutoPotion.SetStatus("READY")
    end
    AutoPotion.RefreshState()
end

function AutoPotion.UseOne(PotionId)
    local Entry    = AutoPotion.Catalog[PotionId]
    local Eligible = AutoPotion.IsDungeonEligible()
    if not EngineConfig.AutoPotionActive
        or not AutoPotion.Selected[PotionId]
        or not Eligible
        or not Entry
        or not AutoPotion.ShouldCatalog(Entry.Definition) then
        return
    end

    local fw         = GetFramework()
    local PotionUtil = fw and fw.Modules and fw.Modules.PotionUtil
    if not PotionUtil then return end

    local BeforeOwned = tonumber(PotionUtil:GetOwnedAmount(LocalPlayer, PotionId)) or 0
    Entry.Owned = BeforeOwned
    if BeforeOwned <= 0 or AutoPotion.IsEntryActive(Entry) then return end

    AutoPotion.Pending[PotionId] = true
    AutoPotion.SetStatus("USING " .. Entry.DisplayName)

    local Success, ErrMsg = pcall(function()
        PotionUtil:UsePotion(LocalPlayer, PotionId, 1, nil)
    end)
    AutoPotion.LastRequestAt = os.clock()

    if not Success then
        warn("[AutoPotion] USE ERROR " .. PotionId .. ": " .. tostring(ErrMsg))
    else
        local RequestAccepted = false
        local Deadline        = os.clock() + AutoPotion.ConfirmTimeout
        repeat
            Entry.Owned    = tonumber(PotionUtil:GetOwnedAmount(LocalPlayer, PotionId)) or 0
            RequestAccepted = RequestAccepted or Entry.Owned < BeforeOwned
            if AutoPotion.IsEntryActive(Entry) then
                -- Buff langsung aktif — selesai
                AutoPotion.ActivationPending[PotionId] = nil
                AutoPotion.RetryOnScan[PotionId]       = nil
                AutoPotion.SetStatus("ACTIVE: " .. Entry.DisplayName)
                AutoPotion.Pending[PotionId] = nil
                AutoPotion.RefreshState()
                return
            end
            task.wait(0.1)
        until os.clock() >= Deadline

        if RequestAccepted then
            -- Potion diterima server, buff belum aktif (delay server)
            AutoPotion.ActivationPending[PotionId] = true
            AutoPotion.RetryOnScan[PotionId]       = nil
            AutoPotion.SetStatus("WAITING BUFF: " .. Entry.DisplayName)
        else
            -- Server tidak merespons → coba lagi di scan berikutnya
            warn("[AutoPotion] TIMEOUT: " .. PotionId)
            AutoPotion.RetryOnScan[PotionId] = true
            AutoPotion.SetStatus("TIMEOUT: " .. Entry.DisplayName)
        end
    end

    AutoPotion.Pending[PotionId] = nil
    AutoPotion.RefreshState()
end

-- Worker: proses queue satu per satu dengan jeda QueueSpacing
function AutoPotion.RunQueue()
    while AutoPotion.Token.Alive
        and EngineConfig.AutoPotionActive
        and #AutoPotion.Queue > 0 do
        local PotionId = table.remove(AutoPotion.Queue, 1)
        AutoPotion.Queued[PotionId] = nil
        local WaitTime = AutoPotion.QueueSpacing - (os.clock() - AutoPotion.LastRequestAt)
        if WaitTime > 0 then task.wait(WaitTime) end
        AutoPotion.UseOne(PotionId)
    end
    AutoPotion.WorkerRunning = false
    AutoPotion.RefreshState()
end

-- ── Signals ───────────────────────────────────────────────────────────────────
function AutoPotion.DisconnectSignals()
    for _, c in pairs(AutoPotion.Connections) do
        pcall(function() c:Disconnect() end)
    end
    for _, c in ipairs(AutoPotion.LifecycleConnections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(AutoPotion.Connections)
    table.clear(AutoPotion.LifecycleConnections)
end

-- Pasang listener perubahan attribute buff → re-evaluate potion terkait
function AutoPotion.RebuildSignals()
    AutoPotion.DisconnectSignals()
    if not EngineConfig.AutoPotionActive or not AutoPotion.Token.Alive then return end
    AutoPotion.BuildCatalog(false)

    local PlayerAttrEntry = AutoPotion.GetPlayerAttrEntry()
    if PlayerAttrEntry then
        for PotionId in pairs(AutoPotion.Selected) do
            local Entry = AutoPotion.Catalog[PotionId]
            if Entry then
                for _, BuffId in ipairs(Entry.BuffIds) do
                    for _, AttributeId in ipairs(AutoPotion.GetBuffAttributeIds(BuffId)) do
                        if not AutoPotion.Connections[AttributeId] then
                            local ObsId = AttributeId
                            AutoPotion.Connections[ObsId] =
                                PlayerAttrEntry:GetAttributeChangedSignal(AttributeId):Connect(function()
                                    for _, RelId in ipairs(AutoPotion.ByBuffId[ObsId] or {}) do
                                        AutoPotion.EvaluatePotion(RelId)
                                    end
                                    AutoPotion.RefreshState()
                                end)
                        end
                    end
                end
            end
        end
    end

    -- Lifecycle: dungeon masuk/keluar, karakter respawn, loading selesai
    local function RefreshContext(Child)
        local Name = Child and Child.Name or ""
        if Name == "MatchRoom" or Name == "WorldEnemys" or Name == "DragonEgg" or Name == "PlayerAttrEntry" then
            if Name == "MatchRoom" or Name == "PlayerAttrEntry" then
                AutoPotion.ResetDungeonGrace()
            end
            task.defer(function()
                AutoPotion.RebuildSignals()
                AutoPotion.Scan(false)
            end)
        end
    end

    local LC = AutoPotion.LifecycleConnections
    table.insert(LC, workspace.ChildAdded:Connect(RefreshContext))
    table.insert(LC, workspace.ChildRemoved:Connect(RefreshContext))
    table.insert(LC, workspace:GetAttributeChangedSignal("LoadingEnd"):Connect(function()
        AutoPotion.ResetDungeonGrace()
        task.defer(function() AutoPotion.Scan(false) end)
    end))
    table.insert(LC, LocalPlayer.ChildAdded:Connect(RefreshContext))
    table.insert(LC, LocalPlayer.ChildRemoved:Connect(RefreshContext))
    table.insert(LC, LocalPlayer.CharacterAdded:Connect(function()
        AutoPotion.ResetDungeonGrace()
        task.defer(function() AutoPotion.Scan(false) end)
    end))
    table.insert(LC, LocalPlayer.CharacterRemoving:Connect(AutoPotion.ResetDungeonGrace))
end

-- Loop fallback setiap 15 detik
function AutoPotion.StartScanner()
    AutoPotion.ScanGeneration = AutoPotion.ScanGeneration + 1
    local Generation = AutoPotion.ScanGeneration
    task.spawn(function()
        while AutoPotion.Token.Alive
            and EngineConfig.AutoPotionActive
            and Generation == AutoPotion.ScanGeneration do
            task.wait(AutoPotion.ScanInterval)
            if AutoPotion.Token.Alive
                and EngineConfig.AutoPotionActive
                and Generation == AutoPotion.ScanGeneration then
                pcall(AutoPotion.Scan, false, true)
            end
        end
    end)
end

-- ── Enable / Disable ──────────────────────────────────────────────────────────
function AutoPotion.SetEnabled(Enabled)
    EngineConfig.AutoPotionActive = Enabled == true
    AutoPotion.ScanGeneration = AutoPotion.ScanGeneration + 1

    if not EngineConfig.AutoPotionActive then
        AutoPotion.DisconnectSignals()
        AutoPotion.ResetDungeonGrace()
        table.clear(AutoPotion.Queue)
        table.clear(AutoPotion.Queued)
        table.clear(AutoPotion.ActivationPending)
        AutoPotion.SetStatus("OFF")
        return
    end

    task.spawn(function()
        AutoPotion.BuildCatalog(true)
        AutoPotion.RebuildSignals()
        AutoPotion.SetStatus("READY")
        AutoPotion.Scan(false)
        AutoPotion.StartScanner()
    end)
end

function AutoPotion.Shutdown()
    AutoPotion.Token.Alive    = false
    AutoPotion.ScanGeneration = AutoPotion.ScanGeneration + 1
    AutoPotion.DisconnectSignals()
    AutoPotion.ResetDungeonGrace()
    table.clear(AutoPotion.Queue)
    table.clear(AutoPotion.Queued)
    table.clear(AutoPotion.Pending)
    table.clear(AutoPotion.ActivationPending)
    AutoPotion.Status = "OFF"
end

-- Sync Selected dari EngineConfig (dipulihkan saat load profil)
AutoPotion.Selected = EngineConfig.AutoPotionSelected

--------------------------------------------------------------------------------
-- Export ke Hub
--------------------------------------------------------------------------------
H.AutoPotion = AutoPotion
