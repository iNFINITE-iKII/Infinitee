--------------------------------------------------------------------------------
-- Mining Hub V1 — entry point
-- Jalankan file ini. Modul lain dimuat dari folder games/mininghubv1/.
--------------------------------------------------------------------------------

local BASE_URL = "https://raw.githubusercontent.com/iNFINITE-iKII/Infinitee/main/games/mininghubv1/"

local source = game:HttpGet(BASE_URL .. "loader.lua")
local loader, err = loadstring(source)

assert(loader, "MiningHub loader gagal dimuat: " .. tostring(err))
loader(BASE_URL)