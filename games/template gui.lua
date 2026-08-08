--[[
      IronSoul GUI Template
      Entry point resmi: menjalankan sumber ironsoulv1 asli.
      Tidak menggambar ulang atau membuat layout custom.
      Semua ukuran, warna, tab, Floating Button, dan animasi
      berasal langsung dari games/ironsoulv1.lua.
    ]]

    if not game:IsLoaded() then
      pcall(function()
          game.Loaded:Wait()
      end)
    end

    if not game.Players.LocalPlayer then
      repeat task.wait(0.5) until game.Players.LocalPlayer
    end

    local SOURCE = "https://raw.githubusercontent.com/iNFINITE-iKII/Infinitee/main/games/ironsoulv1.lua"
    local ok, err = pcall(function()
      loadstring(game:HttpGet(SOURCE, true))()
    end)

    if not ok then
      warn("[IronSoul GUI Template] Gagal menjalankan sumber asli: " .. tostring(err))
    end
    