--------------------------------------------------------------------------------
-- Mining Hub V1 — tab Farm
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub
local state = Hub.State
local config = Hub.Config
local ui = Hub.UI
local data = Hub.Data
local rayfield = Hub.Rayfield

local tab = ui.CreateTab("Farm", 4483345998)
state.NukeStatsParagraph = tab:CreateParagraph({
    Title = "Nuke Stats & Status",
    Content = "Nuke: 0% | Server Hit: 0% [0/0]\nTargets: 0 | Mode: [AUTO-SWITCH]",
})

tab:CreateSection("Nuke Farm Settings")
tab:CreateToggle({
    Name = "Auto Sell (Jika Tas Penuh)",
    CurrentValue = false,
    Flag = "AutoSellFlag",
    Callback = function(value) state.IsAutoSellOn = value end,
})
tab:CreateInput({
    Name = "Kecepatan Farm (milidetik)",
    CurrentValue = tostring(state.FarmSpeedMs),
    PlaceholderText = "33 (0 = Max)",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local value = tonumber(text)
        if value then state.FarmSpeedMs = math.max(0, value) end
    end,
})
tab:CreateInput({
    Name = "Tinggi Teleport Offset",
    CurrentValue = tostring(state.SpeedHeight),
    PlaceholderText = "2.5",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local value = tonumber(text)
        if value then state.SpeedHeight = value end
    end,
})
tab:CreateInput({
    Name = "Prompt Spam / Burst",
    CurrentValue = tostring(state.PromptSpamCount),
    PlaceholderText = "15",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local value = tonumber(text)
        if value then state.PromptSpamCount = math.max(1, math.floor(value)) end
    end,
})
tab:CreateInput({
    Name = "Anti-Stuck Delay",
    CurrentValue = tostring(state.BlacklistDuration),
    PlaceholderText = "1.5",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local value = tonumber(text)
        if value then state.BlacklistDuration = math.max(0, value) end
    end,
})

tab:CreateSection("Target Filters")
local sizeDropdown = tab:CreateDropdown({
    Name = "Size Filter",
    Options = data.Targets.GetSizes(),
    CurrentOption = {"All"},
    MultipleOptions = false,
    Callback = function(options)
        state.SelectedSize = options[1]
        Hub.Functions.UpdateTargetCache()
        Hub.Functions.UpdateFireStatus()
    end,
})
tab:CreateDropdown({
    Name = "Weight Filter",
    Options = config.WeightOptions,
    CurrentOption = {"All"},
    MultipleOptions = false,
    Callback = function(options)
        state.SelectedWeight = options[1]
        Hub.Functions.UpdateTargetCache()
        Hub.Functions.UpdateFireStatus()
    end,
})
tab:CreateDropdown({
    Name = "Value Filter",
    Options = config.ValueOptions,
    CurrentOption = {"All"},
    MultipleOptions = false,
    Callback = function(options)
        state.SelectedValue = options[1]
        Hub.Functions.UpdateTargetCache()
        Hub.Functions.UpdateFireStatus()
    end,
})

local crystalDropdown
local tierDropdown = tab:CreateDropdown({
    Name = "Tier Filter",
    Options = data.Targets.GetTiers(),
    CurrentOption = {"All"},
    MultipleOptions = false,
    Callback = function(options)
        state.SelectedTier = options[1]
        if crystalDropdown then
            crystalDropdown:Refresh(data.Targets.GetCrystals(state.SelectedTier), true)
        end
        state.SelectedCrystalName = "All"
        Hub.Functions.UpdateTargetCache()
        Hub.Functions.UpdateFireStatus()
    end,
})
crystalDropdown = tab:CreateDropdown({
    Name = "Crystal Filter",
    Options = data.Targets.GetCrystals("All"),
    CurrentOption = {"All"},
    MultipleOptions = false,
    Callback = function(options)
        state.SelectedCrystalName = options[1]
        Hub.Functions.UpdateTargetCache()
        Hub.Functions.UpdateFireStatus()
    end,
})
local droppedDropdown = tab:CreateDropdown({
    Name = "Dropped Crystals",
    Options = data.Targets.GetDropped(),
    CurrentOption = {"All"},
    MultipleOptions = false,
    Callback = function(options)
        state.SelectedDroppedName = options[1]
        Hub.Functions.UpdateTargetCache()
        Hub.Functions.UpdateFireStatus()
    end,
})

tab:CreateSection("Farm Controls & Target Manipulation")
tab:CreateToggle({
    Name = "Lock Target (Tetap di 1 Crystal)",
    CurrentValue = false,
    Flag = "LockTargetToggle",
    Callback = function(value)
        state.IsTargetLocked = value
        Hub.Functions.UpdateFireStatus()
        if value and state.CurrentTarget then
            rayfield:Notify({
                Title = "Target Locked",
                Content = "Script tidak akan berpindah dari target saat ini.",
                Duration = 2,
            })
        end
    end,
})
tab:CreateButton({
    Name = "Switch Target (Pindah Paksa)",
    Callback = function()
        Hub.Functions.SwitchTarget()
        rayfield:Notify({
            Title = "Target Diperbarui",
            Content = "Mencari target terdekat berikutnya.",
            Duration = 2,
        })
    end,
})
tab:CreateInput({
    Name = "Kecepatan Fly Manual",
    CurrentValue = tostring(state.FlySpeed),
    PlaceholderText = "50",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local value = tonumber(text)
        if value then state.FlySpeed = math.max(0, value) end
    end,
})
tab:CreateToggle({
    Name = "Enable Fly (Anti-Fall & Anti-Gravity)",
    CurrentValue = false,
    Flag = "FlyToggle",
    Callback = function(value)
        state.IsFlying = value
        Hub.Functions.UpdateFly()
    end,
})
local nukeToggle
nukeToggle = tab:CreateToggle({
    Name = "ACTIVATE NUKE FARM",
    CurrentValue = false,
    Flag = "NukeFarmToggle",
    Callback = function(value)
        state.IsFarmOn = value
        if value then
            Hub.Functions.ResetFireStats()
            Hub.Functions.UpdateTargetCache()
            Hub.Functions.UpdateFireStatus()
            Hub.Functions.StartFarmLoop()
        else
            Hub.Functions.StopFarmLoop()
            Hub.Functions.UpdateFireStatus()
        end
    end,
})
tab:CreateButton({
    Name = "Refresh Target List",
    Callback = function()
        local refreshed = Hub.Functions.RefreshTargetData()
        sizeDropdown:Refresh(refreshed.Sizes, true)
        tierDropdown:Refresh(refreshed.Tiers, true)
        crystalDropdown:Refresh(refreshed.Crystals, true)
        droppedDropdown:Refresh(refreshed.Dropped, true)
        Hub.Functions.UpdateFireStatus()
    end,
})

Hub.UI.NukeToggle = nukeToggle