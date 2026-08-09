--------------------------------------------------------------------------------
-- Mining Hub V1 — tab GUI Controls
--------------------------------------------------------------------------------

local Hub = getgenv().MiningHub
local ui = Hub.UI

local tab = ui.CreateTab("GUI Controls", 4483345998)
tab:CreateSection("Toggle Game Menus")

local guiTargets = {
    {name = "Pickaxe Shop", path = {"PickaxeShop", "Main"}, type = "Frame"},
    {name = "Bomb Shop", path = {"BombShop", "Main"}, type = "Frame"},
    {name = "Radar Shop", path = {"RadarShop", "Main"}, type = "Frame"},
    {name = "Upgrades (Warmth/Carry)", path = {"Upgrades", "Main"}, type = "Frame"},
    {name = "Mountains Menu", path = {"Mountains", "Main"}, type = "Frame"},
    {name = "Index / Collection", path = {"Index", "Main"}, type = "Frame"},
    {name = "Settings Menu", path = {"Settings", "Main"}, type = "Frame"},
    {name = "Compass & Explorer Hud", path = {"ExplorerHud"}, type = "ScreenGui"},
    {name = "Touch Controls", path = {"Actions", "TouchButtons"}, type = "Frame"},
    {name = "Weather Effects UI", path = {"Weathers", "Main"}, type = "Frame"},
}

for _, target in ipairs(guiTargets) do
    tab:CreateToggle({
        Name = target.name,
        CurrentValue = false,
        Flag = "GUI_" .. target.name,
        Callback = function(value)
            local object = Hub.Functions.GetTargetObject(target.path)
            if not object then
                return
            end

            if target.type == "ScreenGui" then
                object.Enabled = value
            else
                local parentGui = object:FindFirstAncestorWhichIsA("ScreenGui")
                if parentGui then
                    parentGui.Enabled = true
                end
                object.Visible = value
            end
        end,
    })
end