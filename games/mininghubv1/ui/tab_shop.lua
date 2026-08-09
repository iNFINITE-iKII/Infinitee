--------------------------------------------------------------------------------
-- Mining Hub V1 — tab Shop & Equip
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub
local data = Hub.Data
local ui = Hub.UI
local remotes = Hub.Services.Remotes

local tab = ui.CreateTab("Shop & Equip", 4483345998)
tab:CreateSection("Live Pickaxe Menu")

local pickaxeBuyText = data.Pickaxes.Options[1]
local pickaxeBuyId = data.Pickaxes.Map[pickaxeBuyText]
tab:CreateDropdown({
    Name = "Select Pickaxe to Buy",
    Options = data.Pickaxes.Options,
    CurrentOption = {pickaxeBuyText},
    MultipleOptions = false,
    Callback = function(options)
        pickaxeBuyText = options[1]
        pickaxeBuyId = data.Pickaxes.Map[pickaxeBuyText]
    end,
})
tab:CreateButton({
    Name = "Buy Selected Pickaxe",
    Callback = function()
        if pickaxeBuyId then
            remotes:WaitForChild("ShopBuy"):FireServer(pickaxeBuyId)
        end
    end,
})

local pickaxeEquipText = data.Pickaxes.Options[1]
local pickaxeEquipId = data.Pickaxes.Map[pickaxeEquipText]
tab:CreateDropdown({
    Name = "Select Pickaxe to Equip",
    Options = data.Pickaxes.Options,
    CurrentOption = {pickaxeEquipText},
    MultipleOptions = false,
    Callback = function(options)
        pickaxeEquipText = options[1]
        pickaxeEquipId = data.Pickaxes.Map[pickaxeEquipText]
    end,
})
tab:CreateButton({
    Name = "Equip Selected Pickaxe",
    Callback = function()
        if pickaxeEquipId then
            remotes:WaitForChild("ShopEquip"):FireServer(pickaxeEquipId)
        end
    end,
})

tab:CreateSection("Live Consumables Menu")
local bombBuyText = data.Bombs.Options[1]
local bombBuyId = data.Bombs.Map[bombBuyText]
tab:CreateDropdown({
    Name = "Select Bomb to Buy",
    Options = data.Bombs.Options,
    CurrentOption = {bombBuyText},
    MultipleOptions = false,
    Callback = function(options)
        bombBuyText = options[1]
        bombBuyId = data.Bombs.Map[bombBuyText]
    end,
})
tab:CreateButton({
    Name = "Buy Selected Bomb",
    Callback = function()
        if bombBuyId then
            remotes:WaitForChild("BombBuyRequest"):InvokeServer(bombBuyId)
        end
    end,
})

local radarBuyText = data.Radars.Options[1]
local radarBuyId = data.Radars.Map[radarBuyText]
tab:CreateDropdown({
    Name = "Select Radar to Buy",
    Options = data.Radars.Options,
    CurrentOption = {radarBuyText},
    MultipleOptions = false,
    Callback = function(options)
        radarBuyText = options[1]
        radarBuyId = data.Radars.Map[radarBuyText]
    end,
})
tab:CreateButton({
    Name = "Buy Selected Radar",
    Callback = function()
        if radarBuyId then
            remotes:WaitForChild("RadarBuyRequest"):InvokeServer(radarBuyId, 1)
        end
    end,
})