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

local function loadModule(baseUrl, path)
    local source = fetch(baseUrl .. path)
    local chunk, err = loadstring(source)

    if not chunk then
        error("Gagal mengompilasi " .. path .. ":\n" .. tostring(err))
    end

    local ok, runtimeErr = pcall(chunk)
    if not ok then
        error("Error saat menjalankan " .. path .. ":\n" .. tostring(runtimeErr))
    end
end

return function(baseUrl)
    local env = getgenv and getgenv() or _G
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