--------------------------------------------------------------------------------
--// ui/tab_util.lua — Tab Utilitas: Redeem Code, Lottery, Reward, Race Reroll
--------------------------------------------------------------------------------
local H            = getgenv().Hub
local EngineConfig = H.EngineConfig
local Services     = H.Services
local LocalPlayer  = H.LocalPlayer
local CustomNotify = H.CustomNotify
local CreateTab                     = H.CreateTab
local CreateSection                 = H.CreateSection
local CreateToggleUI                = H.CreateToggleUI
local CreateInputUI                 = H.CreateInputUI
local CreateButton                  = H.CreateButton
local CreateScrollableMultiSelectUI = H.CreateScrollableMultiSelectUI
local CreateDropdownUI              = H.CreateDropdownUI
local RegisterTranslation           = H.RegisterTranslation

-- [UTIL] REMOTE EVENTS — lazy, di-cache setelah berhasil
--------------------------------------------------------------------------------
local _codeRE, _lotteryRE, _raceRE, _rewardRE = nil, nil, nil, nil

local function getCodeRE()
    if _codeRE then return _codeRE end
    local ok, re = pcall(function()
        return Services.ReplicatedStorage
            :WaitForChild("Framework",3):WaitForChild("Systems",3)
            :WaitForChild("CodesSystem",3):WaitForChild("CodeRE",3)
    end)
    if ok and re then _codeRE = re end
    return _codeRE
end

local function getLotteryRE()
    if _lotteryRE then return _lotteryRE end
    local ok, re = pcall(function()
        return Services.ReplicatedStorage
            :WaitForChild("Framework",3):WaitForChild("Features",3)
            :WaitForChild("SeasonSystem",3):WaitForChild("SeasonUtil",3)
            :WaitForChild("RemoteEvent",3)
    end)
    if ok and re then _lotteryRE = re end
    return _lotteryRE
end

local function getRaceRE()
    if _raceRE then return _raceRE end
    local ok, re = pcall(function()
        return Services.ReplicatedStorage
            :WaitForChild("Framework",3):WaitForChild("Gameplay",3)
            :WaitForChild("RaceSystem",3):WaitForChild("RaceRE",3)
    end)
    if ok and re then _raceRE = re end
    return _raceRE
end

local function getRewardRE()
    if _rewardRE then return _rewardRE end
    local ok, re = pcall(function()
        return Services.ReplicatedStorage
            :WaitForChild("Framework",3):WaitForChild("Features",3)
            :WaitForChild("UpdateLogSystem",3):WaitForChild("RemoteEvent",3)
    end)
    if ok and re then _rewardRE = re end
    return _rewardRE
end

-- [UTIL] DATA LISTS — tambah item baru di sini saja, tidak perlu ubah kode lain
--------------------------------------------------------------------------------

-- Kode redeem (terbaru di atas)
local CODE_LIST = {
    "CELEBRATEFOR150KMEMBER", "NEWMAPEXPAND",      "IRONSOULWEEKEND16",
    "SEASON2EXPAND",          "SEASON2OPEN",       "SEASON2LIVE",
    "IRONSOULWEEKEND13",      "NEWMAP",            "IRONSOULWEEKEND17",
    "SCYTHEWEAPON",
}

-- Versi reward update (tambah versi baru di sini)
local REWARD_VERSIONS = {
    "V10.1", "V10", "V9.5", "V9.4", "V9.3", "V9.2",
}

-- [UTIL] RACE LIST — dibangun dari ResRace (ReplicatedStorage.Configs.ResRace)
-- Otomatis sinkron saat game tambah race baru; tidak perlu edit manual.
-- Sort besar = langka = tampil di atas daftar.
--------------------------------------------------------------------------------
local RARITY_NAMES = {
    [1]="Common", [2]="Uncommon", [3]="Rare",
    [4]="Epic",   [5]="Legendary",[6]="Mythical", [7]="Secret",
}

local RACE_LIST, RACE_DISPLAY = (function()
    local ok, res = pcall(function()
        return require(Services.ReplicatedStorage
            :WaitForChild("Configs", 10)
            :WaitForChild("ResRace",  10))
    end)

    if not ok or type(res) ~= "table" then
        warn("[XiFil] ResRace gagal dimuat — pakai fallback statis")
        return
            { "Lucifer","Archdruid","Elf","Demon","Angel","DragonKnight",
              "Fairy","Curse","Dragonborn","Undead","Goblin","Orc","Human" },
            { "Lucifer (Mythical)","Archdruid (Secret)","Elf (Mythical)",
              "Demon (Mythical)","Angel (Mythical)","DragonKnight (Secret)",
              "Fairy (Legendary)","Curse (Legendary)","Dragonborn (Epic)",
              "Undead (Rare)","Goblin (Uncommon)","Orc (Uncommon)","Human (Common)" }
    end

    -- Kumpulkan entry valid: harus punya Id (string) dan Sort (number)
    local entries = {}
    for _, data in pairs(res) do
        if type(data) == "table"
            and type(data.Id)   == "string"
            and type(data.Sort) == "number" then
            table.insert(entries, data)
        end
    end
    -- Sort descending: nilai Sort besar = race langka = tampil di atas
    table.sort(entries, function(a, b) return a.Sort > b.Sort end)

    local ids, display = {}, {}
    for _, data in ipairs(entries) do
        local rName = RARITY_NAMES[data.Rarity] or ("R"..tostring(data.Rarity or "?"))
        table.insert(ids,     data.Id)
        table.insert(display, data.Id .. " (" .. rName .. ")")
    end
    return ids, display
end)()

-- Export lists ke Hub agar ui_sync bisa sync tanpa duplikat konstanta
H.UtilCodeList = CODE_LIST
H.UtilRaceList = RACE_LIST

-- [UTIL] HELPER: baca race karakter dari billboard di kepala
--------------------------------------------------------------------------------
local function getCurrentRace()
    local char = LocalPlayer.Character
    if not char then return "Unknown" end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return "Unknown" end
    local gui    = hrp:FindFirstChild("PlayerTitleGUI")
    local root   = gui   and gui:FindFirstChild("Root")
    local title  = root  and root:FindFirstChild("Title")
    local lbl    = title and title:FindFirstChild("Race")
    if lbl and (lbl:IsA("TextLabel") or lbl:IsA("TextBox")) then
        return lbl.Text
    end
    return "Unknown"
end

-- [UTIL] TAB
--------------------------------------------------------------------------------
local UtilPage = CreateTab("🔧 Utilitas", "tabUtil")

-- ════════════════════════════════════════════════════════════════════════════
-- [SEKSI 1] REDEEM CODE
-- ════════════════════════════════════════════════════════════════════════════
CreateSection(UtilPage, "Redeem Code", "secUtilCode")

local _codeInitVals, _codeCbs = {}, {}
for _, code in ipairs(CODE_LIST) do
    table.insert(_codeInitVals, EngineConfig.UtilSelectedCodes[code] == true)
    local _code = code
    table.insert(_codeCbs, function(v)
        EngineConfig.UtilSelectedCodes[_code] = (v == true)
    end)
end
_G.UtilCodeChecks = CreateScrollableMultiSelectUI(
    UtilPage, "Pilih Kode Redeem", CODE_LIST, _codeInitVals, _codeCbs
)

-- Tombol "Semua": pilih semua kode sekaligus lalu langsung redeem
CreateButton(UtilPage, "✅ Semua — Pilih & Redeem", function()
    -- Centang semua
    for i, code in ipairs(CODE_LIST) do
        EngineConfig.UtilSelectedCodes[code] = true
        if _G.UtilCodeChecks and _G.UtilCodeChecks[i] then
            _G.UtilCodeChecks[i]:SetValue(true)
        end
    end
    -- Langsung trigger redeem
    local re = getCodeRE()
    if not re then CustomNotify("⚠️ UTIL","CodeRE tidak ditemukan!",3); return end
    task.spawn(function()
        CustomNotify("🎁 REDEEM SEMUA","Memulai "..#CODE_LIST.." kode (15d jeda)...",4)
        for i, code in ipairs(CODE_LIST) do
            pcall(function() re:FireServer({event="usecode", code=code}) end)
            if i < #CODE_LIST then
                for cd = 15, 1, -1 do
                    CustomNotify("🎁 REDEEM","["..i.."/"..#CODE_LIST.."] "..code.." | Berikutnya: "..cd.."d",1)
                    task.wait(1)
                end
            end
        end
        CustomNotify("🎁 REDEEM SEMUA","Selesai! "..#CODE_LIST.." kode di-redeem.",4)
    end)
end, "btnUtilRedeemAll")

local _redeemBusy = false
CreateButton(UtilPage, "🎁 Redeem Kode Terpilih", function()
    if _redeemBusy then return end
    local re = getCodeRE()
    if not re then CustomNotify("⚠️ UTIL","CodeRE tidak ditemukan!",3); return end
    local selected = {}
    for _, code in ipairs(CODE_LIST) do
        if EngineConfig.UtilSelectedCodes[code] then
            table.insert(selected, code)
        end
    end
    if #selected == 0 then CustomNotify("⚠️ UTIL","Pilih minimal 1 kode!",3); return end
    _redeemBusy = true
    task.spawn(function()
        CustomNotify("🎁 REDEEM","Memulai "..#selected.." kode (15d jeda)...",4)
        for i, code in ipairs(selected) do
            pcall(function() re:FireServer({event="usecode", code=code}) end)
            if i < #selected then
                -- Hitung mundur agar terlihat
                for cd = 15, 1, -1 do
                    CustomNotify("🎁 REDEEM","["..i.."/"..#selected.."] "..code.." | Berikutnya: "..cd.."d",1)
                    task.wait(1)
                end
            end
        end
        CustomNotify("🎁 REDEEM","Selesai! "..#selected.." kode di-redeem.",4)
        _redeemBusy = false
    end)
end, "btnUtilRedeem")

-- ════════════════════════════════════════════════════════════════════════════
-- [SEKSI 2] AUTO REROLL LOTTERY
-- ════════════════════════════════════════════════════════════════════════════
CreateSection(UtilPage, "Auto Reroll Lottery", "secUtilLottery")

_G.UtilLotteryCountInput = CreateInputUI(
    UtilPage, "Jumlah Reroll Sekaligus", tostring(EngineConfig.UtilLotteryCount), true,
    function(v)
        local n = tonumber(v)
        if n and n >= 1 then EngineConfig.UtilLotteryCount = math.floor(n) end
    end
)

local _lotteryBusy = false
CreateButton(UtilPage, "🎰 Reroll Lottery Sekarang", function()
    if _lotteryBusy then return end
    local re = getLotteryRE()
    if not re then CustomNotify("⚠️ UTIL","LootRE tidak ditemukan!",3); return end
    local count = math.max(math.floor(EngineConfig.UtilLotteryCount or 15), 1)
    _lotteryBusy = true
    task.spawn(function()
        for i = 1, count do
            pcall(function() re:FireServer("TrySeasonLottery", 1) end)
            task.wait(0.05)
        end
        CustomNotify("🎰 LOTTERY","Selesai "..count.." reroll!",3)
        _lotteryBusy = false
    end)
end, "btnUtilLottery")

-- ════════════════════════════════════════════════════════════════════════════
-- [SEKSI 3] CLAIM REWARD UPDATE
-- ════════════════════════════════════════════════════════════════════════════
CreateSection(UtilPage, "Claim Reward Update", "secUtilReward")

local _rewardBusy = false
CreateButton(UtilPage, "🏆 Claim Semua Reward Update", function()
    if _rewardBusy then return end
    local re = getRewardRE()
    if not re then CustomNotify("⚠️ UTIL","RewardRE tidak ditemukan!",3); return end
    _rewardBusy = true
    task.spawn(function()
        for _, ver in ipairs(REWARD_VERSIONS) do
            CustomNotify("🏆 REWARD","Mengklaim: "..ver,1)
            pcall(function() re:FireServer("ClaimReward", ver) end)
            task.wait(0.5)
        end
        CustomNotify("🏆 REWARD","Semua reward berhasil diklaim!",4)
        _rewardBusy = false
    end)
end, "btnUtilClaimReward")

-- ════════════════════════════════════════════════════════════════════════════
-- [SEKSI 4] AUTO REROLL RACE
-- ════════════════════════════════════════════════════════════════════════════
CreateSection(UtilPage, "Auto Reroll Race", "secUtilRace")

-- Dropdown pilih slot (hanya 2 opsi: Free_1 dan 1)
local SLOT_LIST        = {"Free 1", "Slot 1"}
local SLOT_KEY_MAP     = { ["Free 1"]="Free_1", ["Slot 1"]="1" }
local SLOT_DISPLAY_MAP = { ["Free_1"]="Free 1", ["1"]="Slot 1" }
-- Konversi default lama (integer) ke display string jika diperlukan
local _slotDefault = (EngineConfig.UtilRaceSlot == "1") and "Slot 1" or "Free 1"
_G.UtilRaceSlotDropdown = CreateDropdownUI(
    UtilPage, "🎰 Race Slot", SLOT_LIST,
    _slotDefault,
    function(val)
        local sk = SLOT_KEY_MAP[val] or "Free_1"
        EngineConfig.UtilRaceSlot = sk
        -- FireServer SelectSlot HANYA dari sini — saat user memilih dari dropdown
        local re = getRaceRE()
        if re then pcall(function() re:FireServer("SelectSlot", sk) end) end
    end, "lblUtilRaceSlot"
)

-- Dropdown multi-select (scrollable) — tampilkan RACE_DISPLAY (ada %)
-- tapi simpan state lewat RACE_LIST (nama asli)
local _raceInitVals, _raceCbs = {}, {}
for _, race in ipairs(RACE_LIST) do
    table.insert(_raceInitVals, EngineConfig.UtilTargetRaces[race] == true)
    local _race = race
    table.insert(_raceCbs, function(v)
        EngineConfig.UtilTargetRaces[_race] = (v == true)
    end)
end
_G.UtilRaceChecks = CreateScrollableMultiSelectUI(
    UtilPage, "Target Race", RACE_DISPLAY, _raceInitVals, _raceCbs
)

_G.UtilAutoRerollToggle = CreateToggleUI(
    UtilPage, "🎲 Auto Reroll Race", EngineConfig.UtilAutoRerollActive,
    function(v)
        EngineConfig.UtilAutoRerollActive = v
        if v then CustomNotify("🎲 AUTO REROLL","Aktif — roll sampai target!",3)
        else      CustomNotify("🎲 AUTO REROLL","Nonaktif",2) end
    end, "lblUtilAutoReroll"
)

-- Loop auto reroll race (background)
task.spawn(function()
    while true do
        task.wait(1)
        if not EngineConfig.UtilAutoRerollActive then continue end

        local re = getRaceRE()
        if not re then task.wait(3); continue end

        -- Cek setidaknya 1 target race dipilih
        local anyTarget = false
        for _, race in ipairs(RACE_LIST) do
            if EngineConfig.UtilTargetRaces[race] then anyTarget = true; break end
        end
        if not anyTarget then
            EngineConfig.UtilAutoRerollActive = false
            if _G.UtilAutoRerollToggle then _G.UtilAutoRerollToggle:SetValue(false) end
            CustomNotify("⚠️ AUTO REROLL","Pilih target race dulu!",4)
            continue
        end

        -- Baca race saat ini
        local currentRace = getCurrentRace()
        local raceLower   = string.lower(currentRace)

        -- Cek kecocokan
        local isMatch = false
        for _, race in ipairs(RACE_LIST) do
            if EngineConfig.UtilTargetRaces[race] then
                if string.find(raceLower, string.lower(race), 1, true) then
                    isMatch = true; break
                end
            end
        end

        if isMatch then
            -- Verifikasi 2x untuk hindari desync
            task.wait(0.5)
            local doubleRace = getCurrentRace()
            local dlLower    = string.lower(doubleRace)
            local verified   = false
            for _, race in ipairs(RACE_LIST) do
                if EngineConfig.UtilTargetRaces[race] then
                    if string.find(dlLower, string.lower(race), 1, true) then
                        verified = true; break
                    end
                end
            end
            if verified then
                EngineConfig.UtilAutoRerollActive = false
                if _G.UtilAutoRerollToggle then _G.UtilAutoRerollToggle:SetValue(false) end
                CustomNotify("🎉 RACE MATCH!","Dapat race: "..doubleRace,8)
            end
        else
            -- Belum cocok → fire Rolling pada slot yang dipilih
            local slotKey = EngineConfig.UtilRaceSlot
            if slotKey ~= "Free_1" and slotKey ~= "1" then slotKey = "Free_1" end
            pcall(function() re:FireServer("Rolling", slotKey) end)
        end
    end
end)

--------------------------------------------------------------------------------
-- Export ke Hub
--------------------------------------------------------------------------------
H.UtilCodeList = CODE_LIST
H.UtilRaceList = RACE_LIST
