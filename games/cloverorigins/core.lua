--------------------------------------------------------------------------------
--// core.lua — Clover Origins
--// S01: Services, APIs, State
--// S02: EngineConfig (Config)
--// S03: TargetService, CachedFolders
--// S04: Character setup, UpdateLists
--// S05: Export ke Hub
--------------------------------------------------------------------------------
local H = getgenv().Hub

-- [S01] SERVICES & APIS
--------------------------------------------------------------------------------
local Services = setmetatable({}, {
    __index = function(self, key)
        local s = game:GetService(key)
        if s then self[key] = s end
        return s
    end
})

local LocalPlayer  = Services.Players.LocalPlayer
local TweenService = Services.TweenService
local HttpService  = Services.HttpService

-- Matikan pause notification
pcall(function()
    Services.GuiService:SetGameplayPausedNotificationEnabled(false)
end)

-- Helper: tunggu child dengan timeout
local function waitChain(root, ...)
    local names = {...}
    local ok, result = pcall(function()
        local node = root
        for _, name in ipairs(names) do
            node = node:WaitForChild(name, 15)
            if not node then error("timeout: " .. name) end
        end
        return node
    end)
    if not ok then
        warn("[XiFil-CO] Remote tidak ditemukan: " .. table.concat(names, "/"))
        return nil
    end
    return result
end

-- Remotes Clover Origins
local EventsFolder  = waitChain(Services.ReplicatedStorage, "Events")
local RemotesFolder = waitChain(Services.ReplicatedStorage, "Remotes")

local API = {
    Quest  = EventsFolder  and waitChain(EventsFolder,  "Quests")  or nil,
    Combat = EventsFolder  and waitChain(EventsFolder,  "Combat")  or nil,
    Spin   = EventsFolder  and waitChain(EventsFolder,  "Spins")   or nil,
    Stats  = EventsFolder  and waitChain(EventsFolder,  "Stats")   or nil,
    Skills = RemotesFolder and waitChain(RemotesFolder, "Skills")  or nil,
}

-- [S02] ENGINE CONFIG (setara Config di script lama)
--------------------------------------------------------------------------------
local allGrimoire = {
    "ImperialSword", "Wand", "Rifle", "Regen", "Reinforcement",
    "Earth", "Fire", "Water", "Lightning", "Dark", "FireMagna",
    "AntiMagic", "FireMareleona", "Wind", "TimeMagic", "Light", "SwordMagic"
}
local allSkillKeys = {"Z", "X", "C", "V", "E", "G"}

local EngineConfig = {
    -- Farm
    AutoFarm       = false,
    AutoQuest      = false,
    LerpSpeed      = 1,
    Height         = 10,
    AttackDelay    = 0,
    SelectedQuest  = nil,

    -- Combat
    UseAttack       = false,
    MaxCombo        = 1,
    HitMultiplier   = 10,
    SelectedWeapon  = nil,
    SelectedWeaponV2 = nil,
    AutoSkill       = false,
    EnabledSkills   = {["Z"]=true, ["X"]=true, ["C"]=true, ["V"]=false, ["E"]=false, ["G"]=false},

    -- Grimoire
    AutoSpin        = false,
    TargetGrimoires = {},
    AutoBroom       = false,

    -- Stats
    SelectedStat    = {},
    StatAmount      = 1,
    AutoUpgrade     = false,

    -- Config System (dipakai config_system.lua)
    ConfigName      = "None",
    AutoLoadName    = "None",
}

-- State karakter & target
local State = {
    Character    = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait(),
    Root         = nil,
    Humanoid     = nil,
    CurrentTarget = nil,
    LastTarget   = nil,
    LastAttack   = 0,
    LastSkill    = 0,
    LastTargetSwitch = 0,
    ComboCount   = 1,
    TargetList   = {},
    Lists = {
        NPCs    = {},
        Quests  = {},
        Weapons = {},
        WeaponsV2 = allGrimoire,
        Players = {},
    }
}

-- [S03] TARGET SERVICE
--------------------------------------------------------------------------------
local CachedFolders = {}

local TargetService = {}

function TargetService.UpdateCache()
    table.clear(CachedFolders)
    local names = {"Npcs", "Monsters", "Enemies"}
    for _, name in ipairs(names) do
        local folder = workspace:FindFirstChild(name)
        if folder then table.insert(CachedFolders, folder) end
    end
end

function TargetService.IsAttackable(entity, targetList)
    if not entity or not table.find(targetList, entity.Name) then return false end
    local hum  = entity:FindFirstChildOfClass("Humanoid")
    local root = entity:FindFirstChild("HumanoidRootPart")
    return hum and hum.Health > 0 and root and entity.Parent ~= nil
end

function TargetService.GetDistance(p1, p2)
    if not p1 or not p2 then return math.huge end
    return (p1.Position - p2.Position).Magnitude
end

-- [S04] CHARACTER SETUP & UPDATE LISTS
--------------------------------------------------------------------------------
local function SetupCharacter(char)
    if not char then return end
    State.Character = char
    State.Root      = char:WaitForChild("HumanoidRootPart", 5)
    State.Humanoid  = char:WaitForChild("Humanoid", 5)
    State.CurrentTarget = nil
end

LocalPlayer.CharacterAdded:Connect(SetupCharacter)
SetupCharacter(State.Character)

-- Referensi dropdown (diisi oleh tab_farm.lua setelah UI dibuat)
-- Disimpan di H agar UpdateLists bisa memperbarui dropdown
local function UpdateLists()
    -- Weapons di Backpack + Character
    local foundWeapons = {}
    local pBackpack = LocalPlayer:FindFirstChild("Backpack")
    if pBackpack then
        for _, v in pairs(pBackpack:GetChildren()) do
            if v:IsA("Tool") and not table.find(foundWeapons, v.Name) then
                table.insert(foundWeapons, v.Name)
            end
        end
    end
    if State.Character then
        for _, v in pairs(State.Character:GetChildren()) do
            if v:IsA("Tool") and not table.find(foundWeapons, v.Name) then
                table.insert(foundWeapons, v.Name)
            end
        end
    end
    State.Lists.Weapons   = foundWeapons
    State.Lists.WeaponsV2 = allGrimoire

    -- NPCs
    local currentNPCs = {}
    local npcFolder   = workspace:FindFirstChild("Npcs")
    if npcFolder then
        for _, v in pairs(npcFolder:GetChildren()) do
            if v:IsA("Model") and v:FindFirstChild("Humanoid") then
                if not table.find(currentNPCs, v.Name) then
                    table.insert(currentNPCs, v.Name)
                end
            end
        end
    end
    State.Lists.NPCs = currentNPCs

    -- Quests
    local foundQuests = {}
    local questFolder = workspace:FindFirstChild("Questgivers", true)
                     or workspace:FindFirstChild("Quests", true)
    if questFolder then
        for _, v in pairs(questFolder:GetChildren()) do
            if not table.find(foundQuests, v.Name) then
                table.insert(foundQuests, v.Name)
            end
        end
    end
    State.Lists.Quests = foundQuests

    -- Players
    local currentPlayers = {}
    for _, p in pairs(Services.Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(currentPlayers, p.Name) end
    end
    State.Lists.Players = currentPlayers

    -- Update dropdown UI jika sudah ada
    if H.CO_NPCDropdown and H.CO_NPCDropdown.SetValues then
        H.CO_NPCDropdown:SetValues(State.Lists.NPCs, H.makeNPCCallbacks(State.Lists.NPCs))
    end
    if H.CO_PlayerDropdown and H.CO_PlayerDropdown.SetValues then
        H.CO_PlayerDropdown:SetValues(State.Lists.Players, H.makePlayerCallbacks(State.Lists.Players))
    end
    if H.CO_QuestDropdown  then H.CO_QuestDropdown:SetValues(State.Lists.Quests) end
    if H.CO_WeaponV1       then H.CO_WeaponV1:SetValues(State.Lists.Weapons) end
end

-- Auto-refresh lists setiap 120 detik
task.spawn(function()
    while task.wait(120) do UpdateLists() end
end)

-- Helper: bangun per-row callbacks untuk NPC multi-select
local function makeNPCCallbacks(list)
    local cbs = {}
    for i, name in ipairs(list) do
        local n = name
        cbs[i] = function(val)
            if val then
                if not table.find(State.TargetList, n) then table.insert(State.TargetList, n) end
            else
                local idx = table.find(State.TargetList, n)
                if idx then table.remove(State.TargetList, idx) end
            end
        end
    end
    return cbs
end

-- Helper: bangun per-row callbacks untuk Player multi-select
local function makePlayerCallbacks(list)
    local cbs = {}
    for i, name in ipairs(list) do
        local n = name
        cbs[i] = function(val)
            if val then
                if not table.find(State.TargetList, n) then table.insert(State.TargetList, n) end
            else
                local idx = table.find(State.TargetList, n)
                if idx then table.remove(State.TargetList, idx) end
            end
        end
    end
    return cbs
end

-- Translation stubs (diperlukan oleh ui_core.lua)
local function noop(...) end
H.RegisterTranslation   = noop
H.RegisterTranslationFn = noop
H.ApplyTranslations     = noop
H.SetLanguage           = noop

-- Config System support
local FOLDER_NAME = "XiFilPro_Configs"

-- [S05] EXPORT KE HUB
--------------------------------------------------------------------------------
H.Services        = Services
H.LocalPlayer     = LocalPlayer
H.TweenService    = TweenService
H.HttpService     = HttpService
H.FOLDER_NAME     = FOLDER_NAME

H.API             = API
H.EngineConfig    = EngineConfig
H.State           = State
H.TargetService   = TargetService
H.CachedFolders   = CachedFolders
H.allGrimoire     = allGrimoire
H.allSkillKeys    = allSkillKeys
H.UpdateLists        = UpdateLists
H.makeNPCCallbacks   = makeNPCCallbacks
H.makePlayerCallbacks= makePlayerCallbacks

-- Populate lists sebelum UI dibangun
TargetService.UpdateCache()
UpdateLists()

-- Konstanta dummy yang mungkin dibutuhkan ui_core.lua
H.WORLD_NAMES     = {}
H.POSITION_MODES  = {}
H.ROOM_WORLD_DISPLAY = {}
H.ROOM_WORLD_KEY     = {}
H.isCaveWorld     = function() return false end
H.isEndlessTower  = function() return false end
H.getModeLabel    = function(v) return tostring(v) end
