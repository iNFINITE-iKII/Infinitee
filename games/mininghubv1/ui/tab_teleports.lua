--------------------------------------------------------------------------------
-- Mining Hub V1 — tab Teleports
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub
local ui = Hub.UI
local remotes = Hub.Services.Remotes

local tab = ui.CreateTab("Teleports", 4483345998)
tab:CreateSection("NPC Locations")

local npcTargets = {
    {name = "Sell Crystals", keywords = {"crystal buyer", "sell crystals", "buyer"}, remote = "SellOpen", isSell = true, useNativeHome = true},
    {name = "Radars Shop", keywords = {"radar", "randy", "radars"}, remote = "RadarOpen", isSell = false},
    {name = "Bombs Shop", keywords = {"bomb", "barry", "bomber", "bombs"}, remote = "BombOpen", isSell = false},
    {name = "Upgrades", keywords = {"upgrade", "proclimber", "warmth", "upgrades"}, remote = "UpgradeOpen", isSell = false},
    {name = "Pickaxes Shop", keywords = {"pickaxe", "pickaxes", "toolworker", "tool", "pickaxeshop"}, remote = "ShopOpen", isSell = false},
}

for _, npc in ipairs(npcTargets) do
    tab:CreateButton({
        Name = "Teleport to " .. npc.name,
        Callback = function()
            if npc.useNativeHome then
                remotes:WaitForChild("GoHome"):FireServer("sell")
            else
                Hub.Functions.TeleportToNPC(npc.keywords, npc.remote, npc.isSell)
            end
        end,
    })
end