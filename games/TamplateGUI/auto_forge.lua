--------------------------------------------------------------------------------
--// auto_forge.lua — Auto Forge V6 Engine
-- Ported dari V6 monolithic script ke arsitektur modul TemplateGUI.
-- Menyediakan sistem forge otomatis: pilih resep, komposisi ore, jalankan batch.
-- Mendukung Target Mode: simpan hasil yang cocok dengan profil, buang yang tidak.
--------------------------------------------------------------------------------
local H            = getgenv().XiFilTemplateGUI_Hub
local _G           = getgenv().XiFilTemplateGUI_G
local EngineConfig = H.EngineConfig
local Services     = H.Services
local LocalPlayer  = H.LocalPlayer
local ForgeRF      = H.ForgeRF

local ReplicatedStorage = Services.ReplicatedStorage
local HttpService = game:GetService("HttpService")

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function CopyMap(Source)
    local Result = {}
    for Key, Value in pairs(Source or {}) do Result[Key] = Value end
    return Result
end

local function ClampNumber(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return math.clamp(value, minimum, maximum)
end

-- Inventory values are normally numbers, but some game updates expose
-- stack data as a small record.  Keep all forge checks on one normalized value
-- so the UI and the server request cannot disagree about owned materials.
local function ReadInventoryCount(Value)
    if type(Value) == "number" then
        return math.max(0, math.floor(Value))
    end
    if type(Value) == "table" then
        for _, Key in ipairs({"Count", "Amount", "Quantity", "Value", 1}) do
            local Count = tonumber(Value[Key])
            if Count then return math.max(0, math.floor(Count)) end
        end
    end
    return 0
end

local _cachedFramework = nil
local function GetFrameworkModule()
    if not _cachedFramework then
        local ok, fw = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Framework", 10))
        end)
        if ok and fw then _cachedFramework = fw end
    end
    return _cachedFramework
end

local _cachedGameEnum = nil
local function GetGameEnum()
    if not _cachedGameEnum then
        pcall(function()
            _cachedGameEnum = require(ReplicatedStorage:WaitForChild("Enum"):WaitForChild("GameEnum"))
        end)
    end
    return _cachedGameEnum or {}
end

local function GetItemDisplayName(ItemId)
    if H.GetItemDisplayName then return H.GetItemDisplayName(ItemId) end
    local s = tostring(ItemId or "")
    return s:gsub("([A-Z])", " %1"):match("^%s*(.-)%s*$")
end

local function IsInLobby()
    local ws = Services.Workspace
    return ws:FindFirstChild("MatchRoom") ~= nil
        and ws:FindFirstChild("WorldEnemys") == nil
        and ws:FindFirstChild("DragonEgg") == nil
end

-- ── Ore Catalog ───────────────────────────────────────────────────────────────

local _cachedOreCatalog = nil

local function GetOreCatalog(forceRefresh)
    if _cachedOreCatalog and not forceRefresh then return _cachedOreCatalog end
    local ok, result = pcall(function()
        local Framework = GetFrameworkModule()
        if not Framework then return nil end
        local DataUtil    = Framework.Modules.DataUtil
        local ForgeUtil   = Framework.Modules.ForgeUtil
        local RarityTiers = Framework.Modules.RarityTiers
        local Ores        = DataUtil:GetValue(LocalPlayer, {"Ores"}) or {}
        local ResOres     = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("ResOres"))
        local Out, Seen   = {}, {}

        local function AddOre(OreId)
            if type(OreId) ~= "string" or OreId == "" or OreId == "__index" or Seen[OreId] then return end
            Seen[OreId] = true
            local Def = ForgeUtil:GetDef(OreId) or ResOres[OreId]
            if not Def then return end
            local Rarity = tonumber(Def.Rarity) or 0
            local RarityName = tostring(Rarity)
            pcall(function() RarityName = RarityTiers:GetTierName(Rarity) end)
            table.insert(Out, {
                ItemId = OreId,
                Count  = ReadInventoryCount(Ores[OreId]),
                Rarity = Rarity, RarityName = RarityName,
                Level  = tonumber(Def.Level or Def[6]) or 0,
                Sort   = tonumber(Def.Sort  or Def[5]) or 0,
            })
        end

        for OreId in pairs(Ores) do AddOre(OreId) end
        if type(ResOres) == "table" then
            for OreId in pairs(ResOres) do AddOre(OreId) end
        end

        table.sort(Out, function(A, B)
            if A.Count ~= B.Count then return A.Count > B.Count end
            if A.Rarity ~= B.Rarity then return A.Rarity < B.Rarity end
            if A.Sort   ~= B.Sort   then return A.Sort   < B.Sort   end
            return A.ItemId < B.ItemId
        end)
        return Out
    end)
    if ok and result then _cachedOreCatalog = result; return result end
    return {}
end

local function GetOreRarityLevels(Catalog)
    Catalog = Catalog or GetOreCatalog()
    local Seen, Levels = {}, {0}
    for _, E in ipairs(Catalog) do
        if E.Rarity and not Seen[E.Rarity] then
            Seen[E.Rarity] = true
            table.insert(Levels, E.Rarity)
        end
    end
    table.sort(Levels)
    return Levels
end

-- ── EngineConfig: AutoForge fields ───────────────────────────────────────────

if EngineConfig.AutoForgeRecipeId == nil then
    EngineConfig.AutoForgeActive          = false
    EngineConfig.PerfectForgeActive       = true
    EngineConfig.AutoForgeRecipeId        = "WeaponSword"
    EngineConfig.AutoForgeOreComposition  = {}
    EngineConfig.AutoForgeRequestedCrafts = 1
    EngineConfig.AutoForgeTargetMode      = false
    EngineConfig.AutoForgeAutoDeleteNonMatch = false
    EngineConfig.AutoForgeProfiles        = {}
end

-- Sync _G globals from EngineConfig on load
_G.AutoForge    = EngineConfig.AutoForgeActive
_G.PerfectForge = EngineConfig.PerfectForgeActive

-- ── AutoForge Object ─────────────────────────────────────────────────────────

local AutoForge = {
    Recipes = {
        WeaponSword      = {Label="Sword",            Category="Weapon", OreCount=3,  Chance=100},
        WeaponStaff      = {Label="Staff",            Category="Weapon", OreCount=10, Chance=80},
        WeaponAxeHammer  = {Label="Axe/Hammer",       Category="Weapon", OreCount=16, Chance=100},
        WeaponFist       = {Label="Fist",             Category="Weapon", OreCount=18, Chance=5},
        WeaponFistCommon = {Label="Fist + Common Relic",  Category="Weapon", OreCount=18, Chance=20,  RelicId="FistRelic_1"},
        WeaponBow        = {Label="Bow",              Category="Weapon", OreCount=18, Chance=5},
        WeaponBowRelic   = {Label="Bow + Bow Relic",  Category="Weapon", OreCount=18, Chance=20,  RelicId="BowRelic_1"},
        WeaponFistLuxury = {Label="Fist + Luxury Relic", Category="Weapon", OreCount=18, Chance=58, RelicId="FistRelic_2"},
        ArmorLightHelmet = {Label="Light Helmet",     Category="Armor",  OreCount=3,  Chance=100},
        ArmorLightArmor  = {Label="Light Armor",      Category="Armor",  OreCount=10, Chance=80},
        ArmorHeavyHelmet = {Label="Heavy Helmet",     Category="Armor",  OreCount=15, Chance=80},
        ArmorHeavyArmor  = {Label="Heavy Armor",      Category="Armor",  OreCount=22, Chance=100},
    },
    RecipeOrder = {
        "WeaponSword","WeaponStaff","WeaponAxeHammer","WeaponFist","WeaponFistCommon",
        "WeaponBow","WeaponBowRelic","WeaponFistLuxury",
        "ArmorLightHelmet","ArmorLightArmor","ArmorHeavyHelmet","ArmorHeavyArmor",
    },
    -- Runtime (synced from EngineConfig on load)
    RecipeId         = EngineConfig.AutoForgeRecipeId,
    Composition      = CopyMap(EngineConfig.AutoForgeOreComposition),
    RequestedCrafts  = EngineConfig.AutoForgeRequestedCrafts,
    TargetMode       = EngineConfig.AutoForgeTargetMode,
    AutoDeleteNonMatch = EngineConfig.AutoForgeAutoDeleteNonMatch,
    Profiles         = {},
    StatCatalog      = {},
    DiscoveredStats  = {},
    Groups           = {Offensive = {AtkBonus=true, CHDmgBonus=true, CHIRate=true, SkillDmgBonus=true}},
    TargetFoundData  = nil,
    TargetRefresh    = nil,
    KeyString        = nil,
    State = {
        Running   = false,
        Status    = "IDLE",
        Completed = 0,
        Planned   = 0,
        Refresh   = nil,
        Token     = {Alive = true},
    },
}

-- ── Config sync helpers ───────────────────────────────────────────────────────

function AutoForge.SaveToEngineConfig()
    EngineConfig.AutoForgeActive          = _G.AutoForge == true
    EngineConfig.PerfectForgeActive       = _G.PerfectForge ~= false
    EngineConfig.AutoForgeRecipeId        = AutoForge.RecipeId
    EngineConfig.AutoForgeOreComposition  = CopyMap(AutoForge.Composition)
    EngineConfig.AutoForgeRequestedCrafts = AutoForge.RequestedCrafts
    EngineConfig.AutoForgeTargetMode      = AutoForge.TargetMode
    EngineConfig.AutoForgeAutoDeleteNonMatch = AutoForge.AutoDeleteNonMatch
    EngineConfig.AutoForgeProfiles        = AutoForge.Profiles
end

-- ── Stat / composition normalizers (V6 port) ─────────────────────────────────

function AutoForge.NormalizeStatId(AttributeKey)
    if type(AttributeKey) ~= "string" or AttributeKey == "" then return nil end
    return string.split(AttributeKey, "_")[1]
end

function AutoForge.NormalizeComposition(Value)
    local Result = {}
    if type(Value) ~= "table" then return Result end
    for ItemId, Count in pairs(Value) do
        Count = math.floor(tonumber(Count) or 0)
        if type(ItemId) == "string" and Count > 0 then
            Result[ItemId] = Count
        end
    end
    return Result
end

function AutoForge.GetCompositionTotal(Composition)
    local Total = 0
    for _, Count in pairs(Composition or {}) do
        Total = Total + math.max(0, math.floor(tonumber(Count) or 0))
    end
    return Total
end

function AutoForge.GetDefaultPoolStats()
    return {"AtkBonus","CHDmgBonus","CHIRate","SkillDmgBonus"}
end

function AutoForge.CreateDefaultProfile(Index)
    return {
        Id        = HttpService:GenerateGUID(false),
        Name      = "Profile " .. tostring(Index or 1),
        Enabled   = false,
        SlotMode  = "Any",
        SlotCount = 1,
        PoolPreset = "Offensive",
        PoolStats = AutoForge.GetDefaultPoolStats(),
        Rules     = {{Kind="PoolAtLeast", MinCount=3}},
    }
end

function AutoForge.BuildPoolLookup(PoolStats)
    local Lookup = {}
    for _, StatId in ipairs(type(PoolStats)=="table" and PoolStats or {}) do
        if type(StatId)=="string" and StatId~="" then
            Lookup[AutoForge.NormalizeStatId(StatId) or StatId] = true
        end
    end
    return Lookup
end

function AutoForge.NormalizeProfile(Profile, Index)
    local Source = type(Profile)=="table" and Profile or {}
    local Result = AutoForge.CreateDefaultProfile(Index)
    Result.Id        = type(Source.Id)=="string" and Source.Id or Result.Id
    Result.Name      = type(Source.Name)=="string" and Source.Name or Result.Name
    Result.Enabled   = Source.Enabled == true
    Result.SlotMode  = Source.SlotMode=="Exact" and "Exact" or (Source.SlotMode=="AtLeast" and "AtLeast" or "Any")
    Result.SlotCount = math.floor(ClampNumber(Source.SlotCount, 1, 10, 1))
    Result.PoolPreset = type(Source.PoolPreset)=="string" and Source.PoolPreset or "Offensive"

    Result.PoolStats = {}
    local PoolSeen = {}
    local function PushStat(StatId)
        StatId = AutoForge.NormalizeStatId(StatId)
        if StatId and not PoolSeen[StatId] then
            PoolSeen[StatId] = true
            table.insert(Result.PoolStats, StatId)
        end
    end
    for _, s in ipairs(type(Source.PoolStats)=="table" and Source.PoolStats or {}) do PushStat(s) end

    if #Result.PoolStats <= 0 and Result.PoolPreset == "Offensive" then
        for _, s in ipairs(AutoForge.GetDefaultPoolStats()) do PushStat(s) end
    end

    Result.Rules = {}
    local PoolRuleAdded = false
    local RequireByStat = {}
    for _, SrcRule in ipairs(type(Source.Rules)=="table" and Source.Rules or {}) do
        if type(SrcRule)=="table" then
            local Kind     = SrcRule.Kind
            local MinCount = math.floor(ClampNumber(SrcRule.MinCount, 1, 10, 1))
            if Kind=="RequireStat" or Kind=="Specific" then
                local StatId = AutoForge.NormalizeStatId(SrcRule.StatId)
                if StatId then
                    local Ex = RequireByStat[StatId]
                    if Ex then Ex.MinCount = math.max(Ex.MinCount, MinCount)
                    else
                        local Rule = {Kind="RequireStat", StatId=StatId, MinCount=MinCount}
                        RequireByStat[StatId] = Rule
                        table.insert(Result.Rules, Rule)
                    end
                end
            elseif Kind=="PoolAtLeast" or Kind=="TotalGroup" or Kind=="AdditionalGroup" then
                if not PoolRuleAdded then PoolRuleAdded=true; table.insert(Result.Rules, {Kind="PoolAtLeast", MinCount=MinCount}) end
            elseif Kind=="PoolOnly" or Kind=="AllSlotsGroup" then
                if not PoolRuleAdded then PoolRuleAdded=true; table.insert(Result.Rules, {Kind="PoolOnly"}) end
            end
        end
    end
    if #Result.Rules <= 0 then Result.Rules = {{Kind="PoolAtLeast", MinCount=3}} end
    return Result
end

function AutoForge.ValidateProfile(Profile)
    if type(Profile)~="table" then return false,"Invalid profile" end
    if Profile.SlotMode~="Any" and Profile.SlotMode~="Exact" and Profile.SlotMode~="AtLeast" then
        return false,"Invalid slot mode"
    end
    if Profile.SlotMode~="Any" and (tonumber(Profile.SlotCount) or 0) < 1 then
        return false,"Slot count must be positive"
    end
    if type(Profile.Rules)~="table" or #Profile.Rules<=0 then
        return false,"Add at least one rule"
    end
    local HasPoolRule = false
    local PoolLookup = AutoForge.BuildPoolLookup(Profile.PoolStats)
    for _, Rule in ipairs(Profile.Rules) do
        if Rule.Kind=="RequireStat" then
            if type(Rule.StatId)~="string" or Rule.StatId=="" then return false,"Require Stat needs a stat" end
            if (tonumber(Rule.MinCount) or 0) < 1 or (tonumber(Rule.MinCount) or 0) > 10 then return false,"Minimum must be 1-10" end
        elseif Rule.Kind=="PoolAtLeast" then
            HasPoolRule = true
            if (tonumber(Rule.MinCount) or 0) < 1 or (tonumber(Rule.MinCount) or 0) > 10 then return false,"Minimum must be 1-10" end
        elseif Rule.Kind=="PoolOnly" then HasPoolRule = true
        else return false,"Invalid rule type"
        end
    end
    if HasPoolRule and next(PoolLookup)==nil then return false,"Pool needs at least one stat" end
    return true
end

function AutoForge.NormalizeProfiles(Value)
    local Profiles = {}
    if type(Value)~="table" then return Profiles end
    for Index, Source in ipairs(Value) do
        local Profile = AutoForge.NormalizeProfile(Source, Index)
        local Valid, Err = AutoForge.ValidateProfile(Profile)
        Profile.ValidationError = Valid and nil or Err
        Profile.Enabled = Profile.Enabled and Valid
        table.insert(Profiles, Profile)
    end
    return Profiles
end

-- Restore profiles from EngineConfig
AutoForge.Profiles = AutoForge.NormalizeProfiles(EngineConfig.AutoForgeProfiles or {})

-- ── Stat catalog ──────────────────────────────────────────────────────────────

function AutoForge.BuildStatCatalog(ResultData)
    local Seen = {}
    local function AddStat(Value)
        local StatId = AutoForge.NormalizeStatId(Value)
        if StatId and StatId~="SpecialEntry" then Seen[StatId] = true end
    end
    pcall(function()
        local AttrEntry = GetGameEnum().AttrEntry or {}
        for K, V in pairs(AttrEntry) do AddStat(K); AddStat(V) end
    end)
    for StatId in pairs(AutoForge.Groups.Offensive) do AddStat(StatId) end
    for StatId in pairs(AutoForge.DiscoveredStats) do AddStat(StatId) end
    if type(ResultData)=="table" and type(ResultData.Attr)=="table" then
        for AttrKey in pairs(ResultData.Attr) do AddStat(AttrKey) end
    end

    local Catalog = {}
    pcall(function()
        local TransUtil = GetFrameworkModule().Modules.TranslationUtil
        for StatId in pairs(Seen) do
            local DisplayName = StatId
            pcall(function()
                local T = TransUtil:TranslateByKey("K_"..string.upper(StatId))
                if type(T)=="string" and T~="" and T~="K_"..string.upper(StatId) then DisplayName=T end
            end)
            table.insert(Catalog, {StatId=StatId, DisplayName=DisplayName})
        end
    end)
    if #Catalog == 0 then
        for StatId in pairs(Seen) do
            table.insert(Catalog, {StatId=StatId, DisplayName=StatId})
        end
    end
    table.sort(Catalog, function(A,B) return string.lower(A.DisplayName) < string.lower(B.DisplayName) end)
    AutoForge.StatCatalog = Catalog
    return Catalog
end

function AutoForge.BuildResultSummary(ResultData)
    local Summary = {Slots={}, Counts={}, GroupCounts={Offensive=0}, TotalSlots=0}
    for AttrKey in pairs(type(ResultData)=="table" and type(ResultData.Attr)=="table" and ResultData.Attr or {}) do
        local StatId = AutoForge.NormalizeStatId(AttrKey)
        if StatId then
            table.insert(Summary.Slots, StatId)
            Summary.Counts[StatId] = (Summary.Counts[StatId] or 0) + 1
            Summary.TotalSlots = Summary.TotalSlots + 1
            AutoForge.DiscoveredStats[StatId] = true
            if AutoForge.Groups.Offensive[StatId] then
                Summary.GroupCounts.Offensive = Summary.GroupCounts.Offensive + 1
            end
        end
    end
    table.sort(Summary.Slots)
    AutoForge.BuildStatCatalog(ResultData)
    return Summary
end

function AutoForge.BuildProfileSummary(Profile)
    Profile = AutoForge.NormalizeProfile(Profile)
    local Parts = {
        Profile.SlotMode=="Any" and "Any Slots"
        or (Profile.SlotMode=="Exact" and ("Exact "..tostring(Profile.SlotCount).." Slots")
        or ("≥"..tostring(Profile.SlotCount).." Slots"))
    }
    for _, Rule in ipairs(Profile.Rules or {}) do
        if Rule.Kind=="PoolAtLeast" then table.insert(Parts, "≥"..tostring(Rule.MinCount).." Pool")
        elseif Rule.Kind=="PoolOnly"  then table.insert(Parts, "Only Pool")
        elseif Rule.Kind=="RequireStat" then
            table.insert(Parts, GetItemDisplayName(Rule.StatId).." ≥"..tostring(Rule.MinCount))
        end
    end
    return table.concat(Parts, " · ")
end

function AutoForge.MatchProfile(Profile, Summary)
    local Valid = AutoForge.ValidateProfile(Profile)
    if not Valid or type(Summary)~="table" then return false end
    if Profile.SlotMode=="Exact"   and Summary.TotalSlots ~= Profile.SlotCount then return false end
    if Profile.SlotMode=="AtLeast" and Summary.TotalSlots <  Profile.SlotCount then return false end
    local PoolLookup = AutoForge.BuildPoolLookup(Profile.PoolStats)
    local PoolCount = 0
    for _, StatId in ipairs(Summary.Slots or {}) do
        if PoolLookup[StatId] then PoolCount = PoolCount + 1 end
    end
    for _, Rule in ipairs(Profile.Rules or {}) do
        if Rule.Kind=="RequireStat" then
            if (Summary.Counts[Rule.StatId] or 0) < Rule.MinCount then return false end
        elseif Rule.Kind=="PoolAtLeast" then
            if PoolCount < Rule.MinCount then return false end
        elseif Rule.Kind=="PoolOnly" then
            if Summary.TotalSlots<=0 or PoolCount~=Summary.TotalSlots then return false end
        end
    end
    return true
end

function AutoForge.FindMatchingProfile(ResultData)
    local Summary = AutoForge.BuildResultSummary(ResultData)
    for _, Profile in ipairs(AutoForge.Profiles) do
        local N = AutoForge.NormalizeProfile(Profile)
        if N.Enabled and AutoForge.MatchProfile(N, Summary) then return N, Summary end
    end
    return nil, Summary
end

function AutoForge.CopyResultData(ResultData)
    local Copy = {}
    for Key, Value in pairs(ResultData or {}) do
        Copy[Key] = Key=="Attr" and CopyMap(Value) or Value
    end
    return Copy
end

function AutoForge.CheckEquipmentStorage()
    local ok, Result = pcall(function()
        return GetFrameworkModule().Modules.EquipmentUtil:CheckCanAdd(LocalPlayer)
    end)
    return ok and Result == true
end

function AutoForge.GetKeyString()
    if not AutoForge.KeyString then
        pcall(function()
            AutoForge.KeyString = require(ReplicatedStorage:WaitForChild("Enum"):WaitForChild("KeyString"))
        end)
    end
    return AutoForge.KeyString
end

function AutoForge.GetInventory()
    local Framework = GetFrameworkModule()
    local DataUtil  = Framework.Modules.DataUtil
    local KeyString = AutoForge.GetKeyString()
    local Ores     = DataUtil:GetValue(LocalPlayer, {"Ores"}) or {}
    local Crystals = KeyString
        and (DataUtil:GetValue(LocalPlayer, {KeyString.EquipmentUtil.Crystals}) or {})
        or {}
    return Ores, Crystals
end

function AutoForge.GetOwnedCount(Inventory, ItemId)
    if type(Inventory) ~= "table" then return 0 end
    return ReadInventoryCount(Inventory[ItemId])
end

function AutoForge.GetCompositionIssue(Recipe, Composition, Ores, Crystals)
    if not Recipe then return "Recipe not found" end

    local Selected = AutoForge.GetCompositionTotal(Composition)
    if Selected <= 0 then return "Select at least 1 ore" end
    if Selected ~= Recipe.OreCount then
        return "Need exactly "..tostring(Recipe.OreCount)
            .." ore (selected "..tostring(Selected)..")"
    end

    for OreId, PerCraft in pairs(Composition or {}) do
        PerCraft = math.floor(tonumber(PerCraft) or 0)
        if PerCraft > 0 then
            local Owned = AutoForge.GetOwnedCount(Ores, OreId)
            if Owned < PerCraft then
                return "Need "..tostring(PerCraft).."x "..GetItemDisplayName(OreId)
                    .." (owned "..tostring(Owned)..")"
            end
        end
    end

    if Recipe.RelicId then
        local RelicCount = AutoForge.GetOwnedCount(Crystals, Recipe.RelicId)
        if RelicCount < 1 then
            return "Need 1x "..GetItemDisplayName(Recipe.RelicId)
                .." (owned "..tostring(RelicCount)..")"
        end
    end
    return nil
end

function AutoForge.CalculateLimit(Recipe, Composition, Ores, Crystals)
    local CompositionIssue = AutoForge.GetCompositionIssue(Recipe, Composition, Ores, Crystals)
    if CompositionIssue then
        return 0, nil, CompositionIssue
    end
    local MaxCrafts, LimitingItemId = math.huge, nil
    for OreId, PerCraft in pairs(Composition) do
        PerCraft = math.floor(tonumber(PerCraft) or 0)
        if PerCraft > 0 then
            local Owned = AutoForge.GetOwnedCount(Ores, OreId)
            local N     = math.floor(Owned / PerCraft)
            if N < MaxCrafts then MaxCrafts=N; LimitingItemId=OreId end
        end
    end
    if Recipe.RelicId then
        local RelicCount = AutoForge.GetOwnedCount(Crystals, Recipe.RelicId)
        if RelicCount < MaxCrafts then MaxCrafts=RelicCount; LimitingItemId=Recipe.RelicId end
    end
    MaxCrafts = math.max(0, math.floor(MaxCrafts == math.huge and 0 or MaxCrafts))
    return MaxCrafts, LimitingItemId, MaxCrafts>0 and nil
        or "Insufficient materials for the selected composition"
end

-- ── Engine state ──────────────────────────────────────────────────────────────

function AutoForge.RefreshState()
    if AutoForge.State.Refresh then pcall(AutoForge.State.Refresh) end
end

function AutoForge.SetStatus(Status)
    AutoForge.State.Status = Status
    AutoForge.RefreshState()
end

function AutoForge.WaitForData(ForgeUtil, ExpectedOreCount, PreviousUUID, Timeout)
    local Deadline = os.clock() + Timeout
    repeat
        local ok, ForgeData = pcall(ForgeUtil.GetForgeData, ForgeUtil, LocalPlayer)
        if ok and type(ForgeData)=="table" and ForgeData.ForgeState=="QTE"
            and ForgeData.OresNum == ExpectedOreCount
            and type(ForgeData.QTE)=="table" and ForgeData.QTE.UUID
            and ForgeData.QTE.UUID ~= PreviousUUID then
            return ForgeData
        end
        task.wait(0.1)
    until os.clock() >= Deadline
    return nil
end

function AutoForge.WaitForQTEProgress(ForgeUtil, ExpectedTimes, PreviousUUID, Timeout)
    local Deadline = os.clock() + Timeout
    repeat
        local ok, QTEData = pcall(ForgeUtil.GetQTE, ForgeUtil, LocalPlayer)
        if ok and type(QTEData)=="table" and (tonumber(QTEData.Times) or 0) >= ExpectedTimes
            and QTEData.UUID ~= PreviousUUID then
            return QTEData
        end
        task.wait(0.05)
    until os.clock() >= Deadline
    return nil
end

function AutoForge.RunCraft(Recipe, Composition, AttemptIndex)
    if not AutoForge.CheckEquipmentStorage() then
        return {Stop=true, Status="STOPPED - EQUIPMENT BAG FULL"}
    end

    local Framework = GetFrameworkModule()
    local ForgeUtil = Framework.Modules.ForgeUtil
    local Remote    = ForgeRF

    -- Cek apakah ada QTE yang sedang menunggu dari sebelumnya
    local ExistingData = ForgeUtil:GetForgeData(LocalPlayer)
    local ForgeData    = nil

    if AttemptIndex==1 and type(ExistingData)=="table"
        and ExistingData.ForgeState=="QTE"
        and type(ExistingData.QTE)=="table" and ExistingData.QTE.UUID then
        ForgeData = ExistingData
        AutoForge.SetStatus("RESUMING PENDING QTE")
    else
        local PrevUUID = type(ExistingData)=="table" and type(ExistingData.QTE)=="table"
            and ExistingData.QTE.UUID or nil
        local Accepted = Remote:InvokeServer("DropOres", Composition, Recipe.Category, Recipe.RelicId)
        if Accepted ~= true then error("DropOres rejected") end
        AutoForge.SetStatus("WAITING FOR QTE DATA")
        ForgeData = AutoForge.WaitForData(ForgeUtil, Recipe.OreCount, PrevUUID, 10.0)
        if not ForgeData then error("fresh QTE data timeout") end
    end

    -- Selesaikan semua QTE step
    local QTEConfig      = ForgeUtil:GetForgeQTE(ForgeData.OresNum)
    local CompletedQTE   = tonumber(ForgeData.QTE.Times) or 0
    local TotalQTE       = tonumber(QTEConfig and QTEConfig.QT) or 0

    for QTEIndex = CompletedQTE+1, TotalQTE do
        AutoForge.SetStatus("QTE "..tostring(QTEIndex).."/"..tostring(TotalQTE))
        local QTEData = ForgeUtil:GetQTE(LocalPlayer)
        if type(QTEData)~="table" or not QTEData.UUID then error("missing QTE UUID") end
        local PrevUUID = QTEData.UUID
        Remote:InvokeServer("QTE", {UUID=QTEData.UUID, Rating=15})
        if not AutoForge.WaitForQTEProgress(ForgeUtil, QTEIndex, PrevUUID, 10.0) then
            error("QTE progress timeout "..tostring(QTEIndex).."/"..tostring(TotalQTE))
        end
    end

    local Finished, ResultData = Remote:InvokeServer("ForgeFinish")
    if Finished~=true or type(ResultData)~="table" or not ResultData.ID then
        error("ForgeFinish rejected")
    end

    local ResultCopy     = AutoForge.CopyResultData(ResultData)
    local MatchedProfile = nil
    local Summary        = nil
    local AcceptResult   = true
    local Stop           = false

    if AutoForge.TargetMode then
        AutoForge.SetStatus("CHECKING TARGETS")
        MatchedProfile, Summary = AutoForge.FindMatchingProfile(ResultCopy)
        if MatchedProfile then
            AutoForge.SetStatus("TARGET FOUND - "..tostring(MatchedProfile.Name))
            Stop = true
        elseif AutoForge.AutoDeleteNonMatch then
            AcceptResult = false
            AutoForge.SetStatus("NON-MATCH - DELETED")
        else
            AutoForge.SetStatus("NON-MATCH - ACCEPTED")
        end
    else
        Summary = AutoForge.BuildResultSummary(ResultCopy)
        AutoForge.SetStatus("DONE - "..GetItemDisplayName(ResultCopy.ID))
    end

    Remote:InvokeServer("ForgeResult", AcceptResult)

    if MatchedProfile then
        AutoForge.TargetFoundData = {
            ProfileName = MatchedProfile.Name,
            ItemId      = ResultCopy.ID,
            Attempt     = AttemptIndex,
            Summary     = Summary,
            Result      = ResultCopy,
        }
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title    = "TARGET FOUND",
                Text     = tostring(MatchedProfile.Name).." - "..GetItemDisplayName(ResultCopy.ID),
                Duration = 10,
            })
        end)
        if AutoForge.TargetRefresh then pcall(AutoForge.TargetRefresh) end
    end

    return {Stop=Stop, MatchedProfile=MatchedProfile, Summary=Summary, Result=ResultCopy}
end

function AutoForge.StartBatch()
    if AutoForge.State.Running then
        _G.AutoForge = false
        EngineConfig.AutoForgeActive = false
        AutoForge.SetStatus("STOP AFTER CURRENT CRAFT")
        return false
    end
    if not _G.AutoForge then
        AutoForge.SetStatus("ENABLE AUTO FORGE FIRST")
        return false
    end
    if not IsInLobby() then
        AutoForge.SetStatus("LOBBY ONLY")
        return false
    end
    if AutoForge.TargetMode then
        local HasEnabled = false
        for _, P in ipairs(AutoForge.Profiles) do
            if P.Enabled and AutoForge.ValidateProfile(P) then HasEnabled=true; break end
        end
        if not HasEnabled then
            AutoForge.SetStatus("ENABLE A VALID TARGET PROFILE")
            return false
        end
    end

    local Recipe     = AutoForge.Recipes[AutoForge.RecipeId]
    local Composition = CopyMap(AutoForge.Composition)
    local InventoryOk, Ores, Crystals = pcall(AutoForge.GetInventory)
    if not InventoryOk then
        AutoForge.SetStatus("INVENTORY UNAVAILABLE")
        return false
    end
    local MaxCrafts, LimitingItemId, Reason = AutoForge.CalculateLimit(Recipe, Composition, Ores, Crystals)

    if MaxCrafts <= 0 then
        AutoForge.SetStatus(Reason or "INSUFFICIENT MATERIALS")
        return false
    end

    local Planned = math.min(AutoForge.RequestedCrafts, MaxCrafts)
    AutoForge.State.Running   = true
    AutoForge.State.Completed = 0
    AutoForge.State.Planned   = Planned

    if Planned < AutoForge.RequestedCrafts then
        AutoForge.SetStatus("ADJUSTED TO "..tostring(Planned).." - "..GetItemDisplayName(LimitingItemId))
    else
        AutoForge.SetStatus("STARTING 0/"..tostring(Planned))
    end

    task.spawn(function()
        local FinalStatus = nil
        local ok, Err = pcall(function()
            for CraftIndex = 1, Planned do
                if not AutoForge.State.Token.Alive or not _G.AutoForge then break end
                if not IsInLobby() then error("left lobby") end

                local InventoryOk, CurrOres, CurrCrystals = pcall(AutoForge.GetInventory)
                if not InventoryOk then
                    FinalStatus = "STOPPED - INVENTORY UNAVAILABLE"
                    break
                end
                if AutoForge.CalculateLimit(Recipe, Composition, CurrOres, CurrCrystals) <= 0 then
                    FinalStatus = "STOPPED - MATERIALS EXHAUSTED"
                    break
                end

                AutoForge.SetStatus("FORGING "..tostring(CraftIndex).."/"..tostring(Planned))
                local Decision = AutoForge.RunCraft(Recipe, Composition, CraftIndex)
                if Decision and Decision.Status == "STOPPED - EQUIPMENT BAG FULL" then
                    FinalStatus = Decision.Status; break
                end
                AutoForge.State.Completed = CraftIndex
                AutoForge.RefreshState()
                if Decision and Decision.Stop then
                    FinalStatus = "TARGET FOUND - "..tostring(Decision.MatchedProfile.Name); break
                end
            end
        end)

        AutoForge.State.Running = false
        if not ok then
            AutoForge.SetStatus("ERROR: "..tostring(Err))
        elseif FinalStatus then
            AutoForge.SetStatus(FinalStatus)
        elseif AutoForge.State.Completed >= Planned then
            AutoForge.SetStatus("DONE "..tostring(AutoForge.State.Completed).."/"..tostring(Planned))
        else
            AutoForge.SetStatus("STOPPED "..tostring(AutoForge.State.Completed).."/"..tostring(Planned))
        end
        AutoForge.RefreshState()
    end)

    return true
end

-- ── Perfect Forge hook (V6 port via metamethod) ───────────────────────────────
do
    local envReg = getfenv()
    local hookMM = envReg["hookmetamethod"]
    local getNCM = envReg["getnamecallmethod"]
    if type(hookMM)=="function" and type(getNCM)=="function" then
        local oldCB
        oldCB = hookMM(game, "__namecall", function(self, ...)
            local method = getNCM()
            local args = {...}
            if _G.PerfectForge and self.Name == "ForgeRF" then
                for _, arg in pairs(args) do
                    if type(arg)=="table" and arg.Rating ~= nil then
                        arg.Rating = 15
                    end
                end
            end
            return oldCB(self, unpack(args))
        end)
    end
end

-- ── Export ────────────────────────────────────────────────────────────────────

H.AutoForge         = AutoForge
H.GetOreCatalog     = GetOreCatalog
H.GetOreRarityLevels = GetOreRarityLevels
H.IsInLobby         = IsInLobby
