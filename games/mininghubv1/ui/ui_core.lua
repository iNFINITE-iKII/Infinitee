--------------------------------------------------------------------------------
-- Mining Hub V1 — shared UI setup
--------------------------------------------------------------------------------

local Hub = getgenv().MiningHub
local Rayfield = Hub.Rayfield

local window = Rayfield:CreateWindow({
    Name = "Mining Mobile Hub [ALL IN ONE]",
    LoadingTitle = "Loading Ultimate Hub...",
    LoadingSubtitle = "By Sirius Rayfield",
    ConfigurationSaving = {Enabled = false},
    KeySystem = false,
})

Hub.UI.Window = window
Hub.UI.CreateTab = function(name, icon)
    return window:CreateTab(name, icon)
end
Hub.UI.Notify = function(options)
    Rayfield:Notify(options)
end

return window