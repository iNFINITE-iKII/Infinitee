--------------------------------------------------------------------------------
--// ui/tab_stats.lua — Clover Origins
--// S01: Tab Stats (Auto Stats Upgrade)
--------------------------------------------------------------------------------
local H            = getgenv().Hub
local EngineConfig = H.EngineConfig
local CustomNotify = H.CustomNotify

local CreateTab                     = H.CreateTab
local CreateSection                 = H.CreateSection
local CreateToggleUI                = H.CreateToggleUI
local CreateInputUI                 = H.CreateInputUI
local CreateScrollableMultiSelectUI = H.CreateScrollableMultiSelectUI

-- ============================================================
-- [S01] TAB STATS
-- ============================================================
local StatsPage = CreateTab("📊 Stats", "tabStats")

CreateSection(StatsPage, "Auto Upgrade Statistics", "secAutoStats")

-- Multi-select stat yang ingin dinaikkan
-- Format: { ["StatName"] = true/false }
CreateScrollableMultiSelectUI(
    StatsPage,
    "🎯 Pilih Stat Target",
    {"Melee", "Defense", "Blade", "Magic", "Mana"},
    {},
    function(selectedMap)
        EngineConfig.SelectedStat = selectedMap
    end,
    "dropStatSelect"
)

CreateInputUI(StatsPage, "🔢 Jumlah Point per Upgrade",
    tostring(EngineConfig.StatAmount),
    function(v)
        EngineConfig.StatAmount = tonumber(v) or 1
    end,
    "inpStatAmount"
)

CreateToggleUI(StatsPage, "⬆️ Enable Auto Stats",
    EngineConfig.AutoUpgrade,
    function(v)
        EngineConfig.AutoUpgrade = v
        if v then
            local fn = H.StartAutoStats
            if fn then fn() end
        end
    end,
    "togAutoStats"
)
