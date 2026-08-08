--------------------------------------------------------------------------------
--// core.lua — Shared services for the visual TemplateGUI
--------------------------------------------------------------------------------
local H = getgenv().XiFilTemplateGUI_Hub

local Services = setmetatable({}, {
    __index = function(self, key)
        local service = game:GetService(key)
        if service then self[key] = service end
        return service
    end,
})

local LocalPlayer = Services.Players.LocalPlayer
local Workspace = Services.Workspace
local TweenService = Services.TweenService

-- Only the GUI startup preference remains. Game automation state and remotes
-- were intentionally removed together with the non-visual tabs.
local EngineConfig = {
    GuiStartHidden = false,
}

H.Services = Services
H.LocalPlayer = LocalPlayer
H.Workspace = Workspace
H.TweenService = TweenService
H.EngineConfig = EngineConfig