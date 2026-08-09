--------------------------------------------------------------------------------
-- Mining Hub V1 — TemplateGUI runtime bridge
-- Menyiapkan namespace visual sebelum modul TemplateGUI dimuat.
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local previous = env.XiFilTemplateGUI_Hub

if previous and previous.RuntimeMaid then
    pcall(function()
        previous.RuntimeActive = false
        previous.RuntimeMaid:DoCleaning()
    end)
end

env.XiFilTemplateGUI_Executed = true
env.XiFilTemplateGUI_State = "loading"
env.XiFilTemplateGUI_Hub = {
    RuntimeActive = true,
}
env.XiFilTemplateGUI_G = {}