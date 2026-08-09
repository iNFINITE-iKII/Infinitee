--------------------------------------------------------------------------------
-- Mining Hub V1 — tab Upgrades
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub
local ui = Hub.UI
local remotes = Hub.Services.Remotes

local tab = ui.CreateTab("Upgrades", 4483345998)
tab:CreateSection("Air Upgrades")
local airLevel = 1
tab:CreateDropdown({
    Name = "Select Air Upgrade",
    Options = {"+10", "+50", "+100"},
    CurrentOption = {"+10"},
    MultipleOptions = false,
    Callback = function(options)
        airLevel = ({["+10"] = 1, ["+50"] = 2, ["+100"] = 3})[options[1]] or 1
    end,
})
tab:CreateButton({
    Name = "Buy Air Upgrade",
    Callback = function() remotes:WaitForChild("UpgradeBuy"):FireServer("Air", airLevel) end,
})

tab:CreateSection("Bag Upgrades")
local bagLevel = 1
tab:CreateDropdown({
    Name = "Select Bag Upgrade",
    Options = {"+1kg", "+5kg", "+10kg"},
    CurrentOption = {"+1kg"},
    MultipleOptions = false,
    Callback = function(options)
        bagLevel = ({["+1kg"] = 1, ["+5kg"] = 2, ["+10kg"] = 3})[options[1]] or 1
    end,
})
tab:CreateButton({
    Name = "Buy Bag Upgrade",
    Callback = function() remotes:WaitForChild("UpgradeBuy"):FireServer("Weight", bagLevel) end,
})