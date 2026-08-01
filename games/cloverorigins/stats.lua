--------------------------------------------------------------------------------
--// stats.lua — Clover Origins
--// S01: Auto Stats Upgrade loop
--// S02: Export ke Hub
--------------------------------------------------------------------------------
local H            = getgenv().Hub
local EngineConfig = H.EngineConfig
local API          = H.API

-- [S01] AUTO STATS UPGRADE
--------------------------------------------------------------------------------
-- Loop ini dimulai ketika toggle diaktifkan dari UI (tab_stats.lua)
-- H.StartAutoStats() dipanggil oleh toggle callback

local function StartAutoStats()
    task.spawn(function()
        while EngineConfig.AutoUpgrade do
            if API.Stats then
                -- EngineConfig.SelectedStat format: { ["StatName"] = true/false }
                for statName, isSelected in pairs(EngineConfig.SelectedStat) do
                    if isSelected and EngineConfig.AutoUpgrade then
                        API.Stats:FireServer(statName, EngineConfig.StatAmount)
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

-- [S02] EXPORT KE HUB
--------------------------------------------------------------------------------
H.StartAutoStats = StartAutoStats
