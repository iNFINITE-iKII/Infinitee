--------------------------------------------------------------------------------
-- Mining Hub V1 — entry point
-- Jalankan file ini. Modul lain dimuat dari folder games/mininghubv1/.
--------------------------------------------------------------------------------

local BASE_URL = "https://raw.githubusercontent.com/iNFINITE-iKII/Infinitee/main/games/mininghubv1/"
local CACHE_BUSTER = "?v=20260810-autosell-v2"

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

-- DRM harus menjadi tahap pertama. Loader ini menampilkan GUI key dan hanya
-- menjalankan modul MiningHub setelah key tersimpan/tervalidasi.
local source = fetch(BASE_URL .. "templategui/loader.lua" .. CACHE_BUSTER)
local loader, err = loadstring(source)

if not loader then
    error("MiningHub loader gagal dikompilasi:\n" .. tostring(err))
end

local ok, runtimeError = pcall(loader, BASE_URL, CACHE_BUSTER)
if not ok then
    error("MiningHub gagal dijalankan:\n" .. tostring(runtimeError))
end