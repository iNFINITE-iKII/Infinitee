--------------------------------------------------------------------------------
-- Mining Hub V1 — module loader
--------------------------------------------------------------------------------

local function loadModule(baseUrl, path)
    local source = game:HttpGet(baseUrl .. path)
    local chunk, err = loadstring(source)

    assert(chunk, "Gagal memuat " .. path .. ": " .. tostring(err))
    local ok, runtimeErr = pcall(chunk)
    assert(ok, "Error saat menjalankan " .. path .. ": " .. tostring(runtimeErr))
end

return function(baseUrl)
    local env = getgenv()
    local existing = env.MiningHub

    if existing and existing.Loaded then
        return existing
    end

    loadModule(baseUrl, "core.lua")
    loadModule(baseUrl, "catalog.lua")
    loadModule(baseUrl, "navigation.lua")
    loadModule(baseUrl, "fly.lua")
    loadModule(baseUrl, "farm.lua")
    loadModule(baseUrl, "ui/ui_core.lua")
    loadModule(baseUrl, "ui/tab_action.lua")
    loadModule(baseUrl, "ui/tab_shop.lua")
    loadModule(baseUrl, "ui/tab_upgrades.lua")
    loadModule(baseUrl, "ui/tab_gui.lua")
    loadModule(baseUrl, "ui/tab_teleports.lua")
    loadModule(baseUrl, "ui/tab_farm.lua")
    loadModule(baseUrl, "init.lua")

    return env.MiningHub
end