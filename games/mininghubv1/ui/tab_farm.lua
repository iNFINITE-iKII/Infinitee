--------------------------------------------------------------------------------
-- Mining Hub V1 — tab Farm
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub
local state = Hub.State
local config = Hub.Config
local ui = Hub.UI
local data = Hub.Data

local tab = ui.CreateTab("⛏️ Auto Farm Mining", 4483345998)
state.NukeStatsParagraph = tab:CreateParagraph({
    Title = "🔥 Nuke Stats & Status",
    Content = "Nuke: 0% | Server Hit: 0% [0/0]\nTargets: 0 | Mode: [AUTO-SWITCH]\nLive Value: Loading...\nAuto Sell: Off",
})
Hub.Functions.StartStatusLoop()

tab:CreateSection("SEC 1 — NUKE FARM CRYSTAL")
local nukeToggle
tab:CreateToggle({
    Name = "💰 Auto Sell (Tas Penuh)",
    CurrentValue = false,
    Flag = "AutoSellFlag",
    Callback = function(value)
        state.IsAutoSellOn = value
        if value then
            Hub.Functions.StartAutoSellLoop()
        else
            Hub.Functions.StopAutoSellLoop()
        end
    end,
})
tab:CreateToggle({
    Name = "🔒 Lock Target (Tetap di 1 Crystal)",
    CurrentValue = false,
    Flag = "LockTargetToggle",
    Callback = function(value)
        state.IsTargetLocked = value
        Hub.Functions.UpdateFireStatus()
        if value and state.CurrentTarget then
            ui.Notify({
                Title = "Target Locked",
                Content = "Script tidak akan berpindah dari target saat ini.",
                Duration = 2,
            })
        end
    end,
})
tab:CreateToggle({
    Name = "🕊️ Enable Fly (Anti-Fall & Anti-Gravity)",
    CurrentValue = false,
    Flag = "FlyToggle",
    Callback = function(value)
        state.IsFlying = value
        Hub.Functions.UpdateFly()
    end,
})
nukeToggle = tab:CreateToggle({
    Name = "⚡ ACTIVATE NUKE FARM CRYSTAL",
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
tab:CreateInput({
    Name = "Auto Sell Cooldown (detik)",
    CurrentValue = tostring(state.AutoSellCooldown),
    PlaceholderText = "2",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local value = tonumber(text)
        if value and value >= 1 then
            state.AutoSellCooldown = value
        end
    end,
})
tab:CreateInput({
    Name = "Kecepatan Farm (milidetik)",
    CurrentValue = tostring(state.FarmSpeedMs),
    PlaceholderText = "33 (0 = Max)",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local value = tonumber(text)
        if value then state.FarmSpeedMs = value end
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
        if value then state.PromptSpamCount = value end
    end,
})
tab:CreateInput({
    Name = "Anti-Stuck Delay",
    CurrentValue = tostring(state.BlacklistDuration),
    PlaceholderText = "1.5",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local value = tonumber(text)
        if value then state.BlacklistDuration = value end
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
tab:CreateButton({
    Name = "⏭️ Switch Target (Pindah Paksa)",
    Callback = function()
        Hub.Functions.SwitchTarget()
        ui.Notify({
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
        if value then state.FlySpeed = value end
    end,
})
tab:CreateButton({
    Name = "🔄 Refresh Target List",
    Callback = function()
        local refreshed = Hub.Functions.RefreshTargetData()
        sizeDropdown:Refresh(refreshed.Sizes, true)
        tierDropdown:Refresh(refreshed.Tiers, true)
        crystalDropdown:Refresh(refreshed.Crystals, true)
        droppedDropdown:Refresh(refreshed.Dropped, true)
        Hub.Functions.UpdateFireStatus()
    end,
})

local boulderNames = {}
for _, definition in ipairs(data.Boulders or {}) do
    table.insert(boulderNames, definition.Name)
end
if #boulderNames == 0 then
    boulderNames = {"Mossite", "Voltite", "Gildrite", "Rimeveil", "Nocturnite"}
end

local function setFarmBoulder(name)
    for _, boulderName in ipairs(boulderNames) do
        state.BoulderFarmEnabled[boulderName] = boulderName == name
    end
end

local function setESPBoulder(name)
    for _, boulderName in ipairs(boulderNames) do
        state.BoulderESPEnabled[boulderName] = name == "All" or boulderName == name
    end
end

tab:CreateSection("SEC 2 — FARM RUNE & BOULDER BUILDER")
tab:CreateToggle({
    Name = "🪨 Auto Rune (Prioritas)",
    CurrentValue = state.IsRuneFarmOn,
    Flag = "BoulderRuneToggle",
    Callback = function(value)
        state.IsRuneFarmOn = value == true
        if state.IsRuneFarmOn or state.IsBoulderFarmOn then
            Hub.Functions.StartBoulderFarmLoop()
        else
            Hub.Functions.StopBoulderFarmLoop()
        end
    end,
})
tab:CreateDropdown({
    Name = "🧱 Auto Farm Boulder Builder",
    Options = (function()
        local options = {"None"}
        for _, name in ipairs(boulderNames) do
            table.insert(options, name)
        end
        return options
    end)(),
    CurrentOption = {"None"},
    MultipleOptions = false,
    Callback = function(options)
        setFarmBoulder(options[1])
    end,
})
tab:CreateToggle({
    Name = "⚒️ Enable Auto Farm Boulder Builder",
    CurrentValue = state.IsBoulderFarmOn,
    Flag = "BoulderBuilderFarmToggle",
    Callback = function(value)
        state.IsBoulderFarmOn = value == true
        if state.IsBoulderFarmOn or state.IsRuneFarmOn then
            Hub.Functions.StartBoulderFarmLoop()
        else
            Hub.Functions.StopBoulderFarmLoop()
        end
    end,
})
tab:CreateInput({
    Name = "Boulder Prompt Spam / Burst",
    CurrentValue = tostring(state.BoulderPromptSpamCount),
    PlaceholderText = "10",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local value = tonumber(text)
        if value and value >= 1 then
            state.BoulderPromptSpamCount = math.floor(value)
        end
    end,
})
tab:CreateInput({
    Name = "Boulder Farm Delay (detik)",
    CurrentValue = tostring(state.BoulderFarmDelay),
    PlaceholderText = "0.1",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        local value = tonumber(text)
        if value and value >= 0 then
            state.BoulderFarmDelay = value
        end
    end,
})
tab:CreateToggle({
    Name = "⚡ ACTIVATE BOULDER NUKE FARM",
    CurrentValue = state.IsBoulderFarmOn,
    Flag = "BoulderNukeFarmToggle",
    Callback = function(value)
        state.IsBoulderFarmOn = value == true
        if state.IsBoulderFarmOn or state.IsRuneFarmOn then
            Hub.Functions.StartBoulderFarmLoop()
        else
            Hub.Functions.StopBoulderFarmLoop()
        end
    end,
})

tab:CreateSection("SEC 3 — BOULDER ESP")
tab:CreateToggle({
    Name = "👁️ Master Boulder ESP",
    CurrentValue = state.BoulderMasterESP,
    Flag = "BoulderMasterESP",
    Callback = function(value)
        state.BoulderMasterESP = value == true
    end,
})
local espOptions = {"All"}
for _, name in ipairs(boulderNames) do
    table.insert(espOptions, name)
end
tab:CreateDropdown({
    Name = "👁️ ESP Boulder Builder",
    Options = espOptions,
    CurrentOption = {"All"},
    MultipleOptions = false,
    Callback = function(options)
        setESPBoulder(options[1])
    end,
})
tab:CreateButton({
    Name = "🔄 Refresh Boulder ESP",
    Callback = function()
        Hub.Functions.ScanBoulders()
        ui.Notify({
            Title = "Boulder ESP",
            Content = "Daftar boulder dan ESP sudah diperbarui.",
            Duration = 2,
        })
    end,
})

Hub.UI.NukeToggle = nukeToggle