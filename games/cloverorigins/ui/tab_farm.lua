--------------------------------------------------------------------------------
--// ui/tab_farm.lua — Clover Origins
--// S01: Tab Farm (NPC, Player, Quest, farm toggles)
--// S02: Tab Combat (weapon, burst, skill)
--// S03: Refresh section
--------------------------------------------------------------------------------
local H             = getgenv().Hub
local EngineConfig  = H.EngineConfig
local State         = H.State
local allSkillKeys  = H.allSkillKeys
local TargetService = H.TargetService
local CustomNotify  = H.CustomNotify
local UpdateLists   = H.UpdateLists
local ScanConfigs   = H.ScanConfigs
local ConfigScanner = H.ConfigScanner

local CreateTab                     = H.CreateTab
local CreateSection                 = H.CreateSection
local CreateToggleUI                = H.CreateToggleUI
local CreateDropdownUI              = H.CreateDropdownUI
local CreateInputUI                 = H.CreateInputUI
local CreateButton                  = H.CreateButton
local CreateSliderUI                = H.CreateSliderUI
local CreateScrollableMultiSelectUI = H.CreateScrollableMultiSelectUI
local CreateMultiCheckUI            = H.CreateMultiCheckUI

-- ============================================================
-- [S01] TAB FARM
-- ============================================================
local FarmPage = CreateTab("🌾 Farm", "tabFarm")

CreateSection(FarmPage, "Konfigurasi Gerakan", "secFarmMove")

CreateSliderUI(FarmPage, "⚡ Speed (Lerp)", 0.1, 1, EngineConfig.LerpSpeed, function(v)
    EngineConfig.LerpSpeed = v
end, "sldLerp")

CreateSliderUI(FarmPage, "📐 Height Distance", -15, 15, EngineConfig.Height, function(v)
    EngineConfig.Height = v
end, "sldHeight")

CreateInputUI(FarmPage, "⏱ Attack Delay (detik)", tostring(EngineConfig.AttackDelay), function(v)
    EngineConfig.AttackDelay = tonumber(v) or 0
end, "inpDelay")

--------------------------------------------------------------------------------
CreateSection(FarmPage, "Target Mob", "secMob")

H.CO_NPCDropdown = CreateScrollableMultiSelectUI(FarmPage, "👹 Pilih Mob",
    State.Lists.NPCs,
    {},
    H.makeNPCCallbacks(State.Lists.NPCs),
    "dropNPC"
)

--------------------------------------------------------------------------------
CreateSection(FarmPage, "Target Boss", "secBoss")

H.CO_BossDropdown = CreateScrollableMultiSelectUI(FarmPage, "👑 Pilih Boss",
    State.Lists.Bosses,
    {},
    H.makeBossCallbacks(State.Lists.Bosses),
    "dropBoss"
)

--------------------------------------------------------------------------------
CreateSection(FarmPage, "Target Player", "secPlayer")

H.CO_PlayerDropdown = CreateScrollableMultiSelectUI(FarmPage, "🧑 Pilih Player",
    State.Lists.Players,
    {},
    H.makePlayerCallbacks(State.Lists.Players),
    "dropPlayer"
)

--------------------------------------------------------------------------------
CreateSection(FarmPage, "Quest", "secQuest")

H.CO_QuestDropdown = CreateDropdownUI(FarmPage, "📜 Pilih Quest",
    State.Lists.Quests,
    EngineConfig.SelectedQuest,
    function(v)
        EngineConfig.SelectedQuest = v
        if v then CustomNotify("Quest Selected", "Auto akan menggunakan: " .. v, 2) end
    end,
    "dropQuest"
)

CreateToggleUI(FarmPage, "🔁 Auto Repeat Quest", EngineConfig.AutoQuest, function(v)
    EngineConfig.AutoQuest = v
end, "togAutoQuest")

CreateToggleUI(FarmPage, "🌾 Auto Farm", EngineConfig.AutoFarm, function(v)
    EngineConfig.AutoFarm = v
end, "togAutoFarm")

--------------------------------------------------------------------------------
CreateSection(FarmPage, "Refresh Daftar", "secRefresh")

CreateButton(FarmPage, "🔍 Scan Res Config", function()
    local registry = ScanConfigs and ScanConfigs() or nil
    if not registry then
        CustomNotify("Scanner", "Scanner config tidak tersedia.", 3)
        return
    end

    local summary = ConfigScanner.GetSummary()
    CustomNotify(
        "Scanner",
        string.format(
            "%d object Config ditemukan | %d module dibaca | %d error (lihat console)",
            summary.Objects,
            summary.Readable,
            summary.Errors
        ),
        4
    )
end, "btnScanResConfig")

CreateButton(FarmPage, "🔄 Refresh Monster & Quest", function()
    TargetService.UpdateCache()
    UpdateLists()
    CustomNotify("System", "Daftar monster & quest diperbarui!", 2)
end, "btnRefreshMob")

-- ============================================================
-- [S02] TAB COMBAT
-- ============================================================
local CombatPage = CreateTab("⚔️ Combat", "tabCombat")

CreateSection(CombatPage, "Burst Attack", "secBurst")

H.CO_WeaponV2 = CreateDropdownUI(CombatPage, "💥 Burst Weapon (Grimoire)",
    State.Lists.WeaponsV2 or {},
    EngineConfig.SelectedWeaponV2,
    function(v) EngineConfig.SelectedWeaponV2 = v end,
    "dropWeaponV2"
)

CreateInputUI(CombatPage, "🔢 Burst Multiplier (1–5000)",
    tostring(EngineConfig.HitMultiplier or 10),
    function(v)
        local n = tonumber(v) or 1
        EngineConfig.HitMultiplier = math.clamp(n, 1, 5000)
    end,
    "inpMultiplier"
)

CreateToggleUI(CombatPage, "💥 Burst Attack", EngineConfig.UseAttack, function(v)
    EngineConfig.UseAttack = v
end, "togBurst")

--------------------------------------------------------------------------------
CreateSection(CombatPage, "Skill", "secSkill")

H.CO_WeaponV1 = CreateDropdownUI(CombatPage, "🗡 Skill Weapon",
    State.Lists.Weapons,
    EngineConfig.SelectedWeapon,
    function(v) EngineConfig.SelectedWeapon = v end,
    "dropWeaponV1"
)

-- Multi-check skill keys
local skillLabels    = {"Z", "X", "C", "V", "E", "G"}
local skillDefaults  = {}
local skillCallbacks = {}
for i, key in ipairs(skillLabels) do
    skillDefaults[i]  = EngineConfig.EnabledSkills[key] or false
    local k = key
    skillCallbacks[i] = function(v) EngineConfig.EnabledSkills[k] = v end
end

CreateMultiCheckUI(CombatPage, skillLabels, skillDefaults, skillCallbacks, "chkSkill")

CreateToggleUI(CombatPage, "🎯 Auto Skill", EngineConfig.AutoSkill, function(v)
    EngineConfig.AutoSkill = v
end, "togAutoSkill")

-- ============================================================
-- [S03] REFRESH ALL (di tab Combat juga)
-- ============================================================
CreateSection(CombatPage, "Refresh Daftar", "secRefreshCombat")

CreateButton(CombatPage, "🔄 Refresh Semua List", function()
    UpdateLists()
    CustomNotify("System", "Semua dropdown diperbarui!", 2)
end, "btnRefreshAll")
