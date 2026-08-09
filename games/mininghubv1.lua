--------------------------------------------------------------------------------
-- Mining Hub V1 — entry point
-- Jalankan file ini. Modul lain dimuat dari folder games/mininghubv1/.
--------------------------------------------------------------------------------

local BASE_URL = "https://raw.githubusercontent.com/iNFINITE-iKII/Infinitee/d4d4889072709f6040d0f9c479330a6b314aa4c7/games/mininghubv1/"
local CACHE_BUSTER = "?v=20260809-immutable"

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

local source = fetch(BASE_URL .. "loader.lua" .. CACHE_BUSTER)
local loader, err = loadstring(source)

if not loader then
    error("MiningHub loader gagal dikompilasi:\n" .. tostring(err))
end

local ok, runtimeError = pcall(loader, BASE_URL, CACHE_BUSTER)
if not ok then
    error("MiningHub gagal dijalankan:\n" .. tostring(runtimeError))
end