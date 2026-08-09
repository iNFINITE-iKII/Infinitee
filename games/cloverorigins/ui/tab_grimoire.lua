--------------------------------------------------------------------------------
--// ui/tab_grimoire.lua — Clover Origins
--// S01: Tab Grimoire (Auto Spin, Target Grimoire)
--// S02: Broom Quest section
--------------------------------------------------------------------------------
local H            = getgenv().Hub
local EngineConfig = H.EngineConfig
local allGrimoire  = H.allGrimoire
local CustomNotify = H.CustomNotify

local CreateTab                     = H.CreateTab
local CreateSection                 = H.CreateSection
local CreateToggleUI                = H.CreateToggleUI
local CreateDropdownUI              = H.CreateDropdownUI
local CreateScrollableMultiSelectUI = H.CreateScrollableMultiSelectUI

-- ============================================================
-- [S01] TAB GRIMOIRE
-- ============================================================
local GrimoirePage = CreateTab("📖 Grimoire", "tabGrimoire")

CreateSection(GrimoirePage, "Auto Reroll Grimoire", "secReroll")

H.CO_RerollToggle = CreateToggleUI(GrimoirePage, "🎰 Auto Spin Grimoire",
    EngineConfig.AutoSpin,
    function(v)
        EngineConfig.AutoSpin = v
    end,
    "togAutoSpin"
)

-- Target grimoire: multi-select dari daftar allGrimoire
-- Format yang dikembalikan: { ["GrimoireName"] = true/false }
H.CO_TargetGrimoireSelect = CreateScrollableMultiSelectUI(
    GrimoirePage,
    "🎯 Target Grimoire (berhenti jika dapat ini)",
    allGrimoire,
    {},
    function(selectedMap)
        EngineConfig.TargetGrimoires = selectedMap
    end,
    "dropTargetGrim"
)

-- ============================================================
-- [S02] BROOM QUEST
-- ============================================================
CreateSection(GrimoirePage, "Broom Quest", "secBroom")

H.CO_BroomToggle = CreateToggleUI(GrimoirePage, "🧹 Auto Broom Quest (Sekali Jalan)",
    EngineConfig.AutoBroom,
    function(v)
        EngineConfig.AutoBroom = v
        if v then
            local fn = H.RunBroomQuest
            if fn then task.spawn(fn) end
        end
    end,
    "togBroom"
)
