--------------------------------------------------------------------------------
--// XiFil Hub — IronSoul V1 | loader.lua (TANPA DRM / key)
--------------------------------------------------------------------------------

-- Tunggu game & LocalPlayer siap (cegah crash first-run / Xeno executor)
if not game:IsLoaded() then
    pcall(function() game.Loaded:Wait() end)
end
if not game.Players.LocalPlayer then
    repeat task.wait(0.5) until game.Players.LocalPlayer
end

-- Anti-duplicate guard
if getgenv().XiFilHub_Executed then
    if getgenv().XiFil_CustomNotify then
        getgenv().XiFil_CustomNotify("⚠️ XIFIL HUB", "Script sudah berjalan!", 4)
    end
    return
end
getgenv().XiFilHub_Executed = true

-- Shared state container
getgenv().Hub = {}

--------------------------------------------------------------------------------
--// Load modul
--------------------------------------------------------------------------------
local BASE = "https://xifil-hub-production.up.railway.app/api/lua/module/ironsoulv1/"

local function load(path)
    local ok, err = pcall(function()
        loadstring(game:HttpGet(BASE .. path, true))()
    end)
    if not ok then
        warn("[XiFil] Gagal load: " .. path .. "\n" .. tostring(err))
    end
end

  ----------------------------------------------------------------------------
    -- Load modul secara berurutan (urutan PENTING)
    ----------------------------------------------------------------------------
    load("core.lua")             -- Services, EngineConfig, konstanta
    load("maid.lua")             -- Maid & RuntimeMaid
    load("notify.lua")           -- CustomNotify
    load("config_system.lua")    -- ConfigSystem (save/load profile)
    load("combat.lua")           -- CombatEngine, helper posisi
    load("navigation.lua")       -- Navigation engine (search world)
    load("farm.lua")             -- Farm loop + background loops
    load("buff_card.lua")        -- Auto Buff Card selector
    load("auto_potion.lua")      -- Auto Potion engine
    load("auto_forge.lua")       -- Auto Forge V6 engine
    load("translate.lua")        -- Sistem translate multi-bahasa

    -- UI — core dulu, lalu tiap tab
    load("ui/ui_core.lua")       -- S11-S16: VisualConfig, builder, window, tab system, BG effects
    load("ui/tab_farm.lua")       -- Tab 1: Farm
    load("ui/tab_vector.lua")    -- Tab 2: Vector Config
    load("ui/tab_autopotion.lua") -- Tab 3: Auto Potion
    load("ui/tab_forge.lua")     -- Tab 4: Auto Forge V6
    load("ui/tab_profile.lua")   -- Tab 5: Profile / Config System
    load("ui/tab_util.lua")      -- Tab 6: Utilitas (Redeem, Lottery, Reward, Race)
    load("ui/tab_sell.lua")      -- Tab 7: Sell
    load("ui/tab_room.lua")      -- Tab 8: Room Hub
    load("ui/tab_autobuy.lua")   -- Tab 9: Auto Buy
    load("ui/tab_visual.lua")    -- Tab 10-11: Tampilan, Font, Efek

    load("ui_sync.lua")          -- Sync semua visual UI + floating toggle button
    load("init.lua")             -- Intro animation, RGB loop, inisialisasi akhir

end)
