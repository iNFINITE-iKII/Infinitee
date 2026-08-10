--------------------------------------------------------------------------------
-- Mining Hub V1 — entry point
-- Loader utama berada di folder games/mininghubv1/.
--------------------------------------------------------------------------------

local BASE_URL = "https://raw.githubusercontent.com/iNFINITE-iKII/Infinitee/main/games/mininghubv1/"
local CACHE_BUSTER = "?v=20260810-farm-parity"

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

-- Gunakan loader utama MiningHub. Loader ini mengatur urutan modul gameplay,
-- TemplateGUI, dan validasi startup dari satu tempat.
local source = fetch(BASE_URL .. "loader.lua" .. CACHE_BUSTER)
local loader, err = loadstring(source)

if not loader then
    error("MiningHub loader gagal dikompilasi:\n" .. tostring(err))
end

local ok, runtimeError = pcall(loader, BASE_URL, CACHE_BUSTER)
if not ok then
    error("MiningHub gagal dijalankan:\n" .. tostring(runtimeError))
end