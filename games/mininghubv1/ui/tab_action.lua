--------------------------------------------------------------------------------
-- Mining Hub V1 — tab Sell & Action
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub
local state = Hub.State
local data = Hub.Data
local ui = Hub.UI
local remotes = Hub.Services.Remotes
local player = Hub.Services.LocalPlayer

local tab = ui.CreateTab("Sell & Action", 4483345998)
tab:CreateSection("Sell Options")
tab:CreateButton({
    Name = "Sell All",
    Callback = function() remotes:WaitForChild("SellRequest"):FireServer("all") end,
})
tab:CreateButton({
    Name = "Sell Held Item",
    Callback = function() remotes:WaitForChild("SellRequest"):FireServer("held") end,
})

tab:CreateSection("Live Item Actions")
local selectedRadarText = data.Radars.Options[1]
local selectedRadarId = data.Radars.Map[selectedRadarText]
tab:CreateDropdown({
    Name = "Select Radar (Activate)",
    Options = data.Radars.Options,
    CurrentOption = {selectedRadarText},
    MultipleOptions = false,
    Callback = function(options)
        selectedRadarText = options[1]
        selectedRadarId = data.Radars.Map[selectedRadarText]
    end,
})
tab:CreateButton({
    Name = "Activate Selected Radar",
    Callback = function()
        if selectedRadarId then
            remotes:WaitForChild("RadarActivate"):FireServer(selectedRadarId, true)
        end
    end,
})

local selectedBombText = data.Bombs.Options[1]
local selectedBombId = data.Bombs.Map[selectedBombText]
tab:CreateDropdown({
    Name = "Select Bomb (Activate)",
    Options = data.Bombs.Options,
    CurrentOption = {selectedBombText},
    MultipleOptions = false,
    Callback = function(options)
        selectedBombText = options[1]
        selectedBombId = data.Bombs.Map[selectedBombText]
    end,
})
tab:CreateButton({
    Name = "Activate Selected Bomb",
    Callback = function()
        if selectedBombId then
            remotes:WaitForChild("BombActivate"):FireServer(selectedBombId)
        end
    end,
})

tab:CreateSection("Place Crystal")
local function getInventoryTools()
    local tools = {}
    for _, item in ipairs(player.Backpack:GetChildren()) do
        if item:IsA("Tool") then
            table.insert(tools, item.Name)
        end
    end
    if player.Character then
        for _, item in ipairs(player.Character:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(tools, item.Name)
            end
        end
    end
    return #tools > 0 and tools or {"No Tools Found"}
end

local selectedTool = getInventoryTools()[1]
local toolDropdown = tab:CreateDropdown({
    Name = "Select Item/Crystal from Bag",
    Options = getInventoryTools(),
    CurrentOption = {selectedTool},
    MultipleOptions = false,
    Callback = function(options) selectedTool = options[1] end,
})
tab:CreateButton({
    Name = "Refresh Bag Items",
    Callback = function() toolDropdown:Refresh(getInventoryTools(), true) end,
})
tab:CreateButton({
    Name = "Place Selected Crystal",
    Callback = function()
        local tool = player.Backpack:FindFirstChild(selectedTool) or (
            player.Character and player.Character:FindFirstChild(selectedTool)
        )
        if tool then
            remotes:WaitForChild("PlotPlaceRequest"):FireServer(
                selectedTool,
                -104.5569,
                25.0939,
                1071.0616,
                0,
                tool
            )
        else
            ui.Notify({
                Title = "Error",
                Content = "Pegang toolnya atau taruh di tas.",
                Duration = 3,
            })
        end
    end,
})