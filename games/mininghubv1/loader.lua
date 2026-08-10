--------------------------------------------------------------------------------
-- Mining Hub V1 — module loader
--------------------------------------------------------------------------------

local function fetch(url)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(result) == "string" and #result > 0 then
        return result
    end

    local requestFunction = request or http_request or (syn and syn.request)
    if type(requestFunction) == "function" then
        local response = requestFunction({Url = url, Method = "GET"})
        if response and response.Success ~= false and response.Body then
            return response.Body
        end
    end

    error("HTTP GET gagal: " .. url .. "\n" .. tostring(result))
end

local function loadModule(baseUrl, cacheBuster, path)
    local source = fetch(baseUrl .. path .. cacheBuster)
    local chunk, err = loadstring(source)

    if not chunk then
        error("Gagal mengompilasi " .. path .. ":\n" .. tostring(err))
    end

    local ok, runtimeErr = pcall(chunk)
    if not ok then
        error("Error saat menjalankan " .. path .. ":\n" .. tostring(runtimeErr))
    end
end

return function(baseUrl, cacheBuster)
    cacheBuster = cacheBuster or "?v=20260810-1"
    local env = getgenv and getgenv() or _G
    local existing = env.MiningHub

    if existing and existing.Loaded then
        return existing
    end

    loadModule(baseUrl, cacheBuster, "core.lua")
    loadModule(baseUrl, cacheBuster, "catalog.lua")
    loadModule(baseUrl, cacheBuster, "navigation.lua")
    loadModule(baseUrl, cacheBuster, "fly.lua")
    loadModule(baseUrl, cacheBuster, "farm.lua")
    loadModule(baseUrl, cacheBuster, "boulder.lua")
    loadModule(baseUrl, cacheBuster, "templategui/bridge.lua")
    loadModule(baseUrl, cacheBuster, "templategui/core.lua")
    loadModule(baseUrl, cacheBuster, "templategui/maid.lua")
    loadModule(baseUrl, cacheBuster, "templategui/notify.lua")
    loadModule(baseUrl, cacheBuster, "templategui/config_system.lua")
    loadModule(baseUrl, cacheBuster, "templategui/translate.lua")
    loadModule(baseUrl, cacheBuster, "templategui/ui/ui_core.lua")
    loadModule(baseUrl, cacheBuster, "templategui/ui/tab_visual.lua")
    loadModule(baseUrl, cacheBuster, "templategui/ui/tab_profile.lua")
    loadModule(baseUrl, cacheBuster, "templategui/ui_sync.lua")
    loadModule(baseUrl, cacheBuster, "templategui/init.lua")
    loadModule(baseUrl, cacheBuster, "ui/ui_core.lua")
    loadModule(baseUrl, cacheBuster, "ui/tab_action.lua")
    loadModule(baseUrl, cacheBuster, "ui/tab_shop.lua")
    loadModule(baseUrl, cacheBuster, "ui/tab_upgrades.lua")
    loadModule(baseUrl, cacheBuster, "ui/tab_gui.lua")
    loadModule(baseUrl, cacheBuster, "ui/tab_teleports.lua")
    loadModule(baseUrl, cacheBuster, "ui/tab_farm.lua")
    loadModule(baseUrl, cacheBuster, "init.lua")

    return env.MiningHub
end