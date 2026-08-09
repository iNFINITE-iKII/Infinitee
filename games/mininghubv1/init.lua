--------------------------------------------------------------------------------
-- Mining Hub V1 — final initialization
--------------------------------------------------------------------------------

local Hub = getgenv().MiningHub
local UserInputService = Hub.Services.UserInputService

if Hub.Connections.InputBegan then
    Hub.Connections.InputBegan:Disconnect()
end

Hub.Connections.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or input.KeyCode ~= Enum.KeyCode.F then
        return
    end

    if Hub.UI.NukeToggle then
        Hub.UI.NukeToggle:Set(not Hub.State.IsFarmOn)
    end
end)

Hub.Loaded = true
Hub.Rayfield:Notify({
    Title = "Mining Hub V1",
    Content = "Modul berhasil dimuat.",
    Duration = 3,
})