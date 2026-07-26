--------------------------------------------------------------------------------
--// ui/tab_sell.lua — S20 Tab 4: Sell
--------------------------------------------------------------------------------
local H            = getgenv().Hub
local EngineConfig = H.EngineConfig
local Services     = H.Services
local LocalPlayer  = H.LocalPlayer
local EquipmentRE  = H.EquipmentRE
local MaterialRE   = H.MaterialRE
local CustomNotify = H.CustomNotify
local ForgeRF          = H.ForgeRF
local Workspace        = H.Workspace
local CombatEngine     = H.CombatEngine
local CreateTab        = H.CreateTab
local CreateSection    = H.CreateSection
local CreateDropdownUI = H.CreateDropdownUI
local CreateCycleUI      = H.CreateCycleUI
local CreateButton       = H.CreateButton
local CreateToggleUI     = H.CreateToggleUI
local CreateInputUI      = H.CreateInputUI
local CreateScrollableMultiSelectUI = H.CreateScrollableMultiSelectUI
local RegisterTranslation = H.RegisterTranslation

-- [S20] TAB 4 — SELL
--------------------------------------------------------------------------------
local SellPage = CreateTab("💰 Jual", "tabSell")

-- ════════════════════════════════════════════════════════════════════════════
-- [AUTO SELL BY RARITY — V2] — Live data via Framework, tahan update game
-- Baca ore dari DataUtil (live), filter by rarity threshold + per-ore override.
-- Remote: ForgeRF:InvokeServer("Sell", list).
-- ════════════════════════════════════════════════════════════════════════════
local RS = game:GetService("ReplicatedStorage")

-- Lazy-load Framework & remote (di-cache setelah pertama kali)
local _Fw, _TaskRE, _ResOres

local function _getFw()
    if not _Fw then _Fw = require(RS:WaitForChild("Framework")) end
    return _Fw
end

local function _getTaskRE()
    if not _TaskRE then
        _TaskRE = RS:WaitForChild("Framework")
            :WaitForChild("Features"):WaitForChild("TaskSystem"):WaitForChild("TaskRE")
    end
    return _TaskRE
end

local _cachedCatalog = nil

local function _getOreCatalog(forceRefresh)
    if _cachedCatalog and not forceRefresh then return _cachedCatalog end
    local fw = _getFw()
    local du, fu, rt = fw.Modules.DataUtil, fw.Modules.ForgeUtil, fw.Modules.RarityTiers
    if not _ResOres then
        _ResOres = require(RS:WaitForChild("Configs"):WaitForChild("ResOres"))
    end
    local ores = du:GetValue(LocalPlayer, {"Ores"}) or {}
    local result, seen = {}, {}
    local function addOre(id)
        if type(id) ~= "string" or id == "" or seen[id] then return end
        seen[id] = true
        local def = fu:GetDef(id) or _ResOres[id]
        if not def then return end
        local rarity = tonumber(def.Rarity) or 0
        local rarityName = tostring(rarity)
        pcall(function() rarityName = rt:GetTierName(rarity) end)
        table.insert(result, {
            ItemId = id, Count = tonumber(ores[id]) or 0,
            Rarity = rarity, RarityName = rarityName, Def = def,
        })
    end
    if type(_ResOres.__index) == "table" then
        for _, id in ipairs(_ResOres.__index) do addOre(id) end
    end
    for id in pairs(_ResOres) do if id ~= "__index" then addOre(id) end end
    for id in pairs(ores) do addOre(id) end
    table.sort(result, function(a, b)
        if a.Count ~= b.Count then return a.Count > b.Count end
        if a.Rarity ~= b.Rarity then return a.Rarity > b.Rarity end
        return tostring(a.ItemId) < tostring(b.ItemId)
    end)
    _cachedCatalog = result
    return result
end

local function _getDisplayName(id)
    local base = string.split(tostring(id or "Unknown"), ":")[1]
    local key  = "K_" .. string.upper(base)
    local name; pcall(function() name = _getFw().Modules.TranslationUtil:TranslateByKey(key) end)
    if type(name) == "string" and name ~= "" and name ~= key then return name end
    return string.gsub(base, "_", " ")
end

local RARITY_SELL_OPTS  = {"OFF","Common","Uncommon","Rare","Epic","Legendary","Mythical","Secret"}
local RARITY_SELL_LEVEL = {OFF=0,Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythical=6,Secret=7,Divine=7}

local function _shouldSell(id, def)
    local mode = EngineConfig.OreSellModes[id] or "OFF"
    if mode == "SIMPAN" then return false end
    if mode == "JUAL"   then return true end
    local threshold = RARITY_SELL_LEVEL[EngineConfig.SellByRarity] or 0
    local r = def and tonumber(def.Rarity)
    return threshold > 0 and r and r <= threshold
end

local _lastCtxFire = 0
local function doSellByRarity()
    local ok, fw = pcall(_getFw)
    if not ok or not fw then
        CustomNotify("⚠️ SELL RARITY", "Framework belum siap", 3); return 0
    end
    local du, fu = fw.Modules.DataUtil, fw.Modules.ForgeUtil
    local ores = du:GetValue(LocalPlayer, {"Ores"}) or {}
    local sellList = {}
    for id, count in pairs(ores) do
        if (tonumber(count) or 0) > 0 then
            local def = fu:GetDef(id)
            if _shouldSell(id, def) then table.insert(sellList, id) end
        end
    end
    if #sellList == 0 then return 0 end
    -- Picu context TaskSystem tiap 10 detik agar NPC sell tidak timeout
    if (os.clock() - _lastCtxFire) >= 10 then
        _lastCtxFire = os.clock()
        pcall(function()
            local tre = _getTaskRE()
            tre:FireServer("UpdateTaskProgress", "DialogNpc",    "EquipmentSellNpc1|1")
            tre:FireServer("UpdateTaskProgress", "DialogNpc",    "EquipmentSellNpc1|0")
            tre:FireServer("UpdateTaskProgress", "OpenGUIWindow","ScreenEquipSell")
            tre:FireServer("UpdateTaskProgress", "OpenGUIWindow","ScreenTips")
        end)
        task.wait(0.25)
    end
    local sold = 0
    if pcall(function() ForgeRF:InvokeServer("Sell", sellList) end) then
        sold = #sellList
        CustomNotify("🗑️ SELL RARITY", "Terjual " .. sold .. " jenis Ore", 2)
    end
    return sold
end

-- ─── UI ──────────────────────────────────────────────────────────────────────
CreateSection(SellPage, "Auto Sell by Rarity (Live)", "secSellByRarity")

-- Dropdown threshold rarity (cycle seperti World di tab Farm)
_G.SellByRarityDropdown = CreateCycleUI(SellPage,
    "Sell Rarity ≤", RARITY_SELL_OPTS, EngineConfig.SellByRarity, function(v)
        EngineConfig.SellByRarity = v
    end)

-- Ore list per-item (OFF / JUAL / SIMPAN) — embedded ScrollingFrame
local _OreList = Instance.new("ScrollingFrame", SellPage)
_OreList.Name                = "OreListSR"
_OreList.Size                = UDim2.new(1, 0, 0, 220)
_OreList.BackgroundTransparency = 1
_OreList.ScrollBarThickness  = 3
_OreList.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UIListLayout", _OreList).Padding = UDim.new(0, 4)

local _MODE_CLR = {
    JUAL   = Color3.fromRGB(230, 157, 52),  -- oranye = dijual
    SIMPAN = Color3.fromRGB(200, 60,  60),  -- merah  = dikecualikan
}
local _MODE_CLR_DEFAULT = Color3.fromRGB(55, 85, 170)  -- biru = ikut threshold

local function RefreshOreList()
    local savedScroll = _OreList.CanvasPosition
    for _, c in ipairs(_OreList:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local catalog = _getOreCatalog(true)  -- force refresh: baca live dari DataUtil
    for _, entry in ipairs(catalog) do
        local row = Instance.new("Frame", _OreList)
        row.Size             = UDim2.new(1, -4, 0, 44)
        row.BackgroundColor3 = Color3.fromRGB(28, 33, 43)
        row.BorderSizePixel  = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

        local lbl = Instance.new("TextLabel", row)
        lbl.Size              = UDim2.new(1, -72, 0, 22)
        lbl.Position          = UDim2.fromOffset(8, 3)
        lbl.BackgroundTransparency = 1
        lbl.Text              = _getDisplayName(entry.ItemId)
        lbl.TextColor3        = Color3.fromRGB(235, 239, 247)
        lbl.Font              = Enum.Font.GothamMedium
        lbl.TextSize          = 11
        lbl.TextXAlignment    = Enum.TextXAlignment.Left
        lbl.TextTruncate      = Enum.TextTruncate.AtEnd

        local detail = Instance.new("TextLabel", row)
        detail.Size           = UDim2.new(1, -72, 0, 16)
        detail.Position       = UDim2.fromOffset(8, 25)
        detail.BackgroundTransparency = 1
        detail.Text           = tostring(entry.RarityName) .. " · ×" .. entry.Count
        detail.TextColor3     = Color3.fromRGB(147, 158, 179)
        detail.Font           = Enum.Font.Gotham
        detail.TextSize       = 9
        detail.TextXAlignment = Enum.TextXAlignment.Left

        local modeBtn = Instance.new("TextButton", row)
        modeBtn.Size           = UDim2.fromOffset(58, 24)
        modeBtn.Position       = UDim2.new(1, -64, 0.5, -12)
        modeBtn.AutoButtonColor = false
        modeBtn.BorderSizePixel = 0
        modeBtn.Font           = Enum.Font.GothamBold
        modeBtn.TextSize       = 9
        modeBtn.TextColor3     = Color3.new(1, 1, 1)
        Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0, 5)

        local eid = entry.ItemId
        local function updateModeBtn()
            local m = EngineConfig.OreSellModes[eid] or "OFF"
            modeBtn.Text             = m
            modeBtn.BackgroundColor3 = _MODE_CLR[m] or _MODE_CLR_DEFAULT
        end
        updateModeBtn()

        modeBtn.Activated:Connect(function()
            local m = EngineConfig.OreSellModes[eid] or "OFF"
            if     m == "OFF"   then EngineConfig.OreSellModes[eid] = "JUAL"
            elseif m == "JUAL"  then EngineConfig.OreSellModes[eid] = "SIMPAN"
            else                     EngineConfig.OreSellModes[eid] = nil end
            updateModeBtn()
        end)
    end
    task.spawn(function() task.wait(); _OreList.CanvasPosition = savedScroll end)
end

CreateButton(SellPage, "🗑️ Sell Sekarang (Rarity)", function()
    doSellByRarity()
    task.spawn(function() task.wait(0.5); pcall(RefreshOreList) end)
end, "btnSellByRarityNow")

_G.SellByRarityIntervalInput = CreateInputUI(SellPage, "Interval Auto Sell (detik)",
    tostring(EngineConfig.SellByRarityInterval), false, function(v)
        local n = tonumber(v); if n and n >= 1 then EngineConfig.SellByRarityInterval = n end
    end)

_G.SellByRarityToggle = CreateToggleUI(SellPage, "⚡ Auto Sell by Rarity",
    EngineConfig.SellByRarityActive, function(v)
        EngineConfig.SellByRarityActive = v
        if v then CustomNotify("⚡ AUTO SELL RARITY","Aktif!",2)
        else      CustomNotify("⚡ AUTO SELL RARITY","Nonaktif",2) end
    end, "lblSellByRarityAuto")

task.spawn(function()
    local elapsed = 0
    while true do
        task.wait(1)
        if EngineConfig.SellByRarityActive then
            elapsed = elapsed + 1
            if elapsed >= math.max(EngineConfig.SellByRarityInterval or 5, 1) then
                elapsed = 0
                pcall(doSellByRarity)
                task.spawn(function() task.wait(0.5); pcall(RefreshOreList) end)
            end
        else
            elapsed = 0
        end
    end
end)

-- Auto-load ore list saat script dijalankan
task.spawn(function() task.wait(1); pcall(RefreshOreList) end)

-- ─────────────────────────────────────────────────────────────────────────────
CreateSection(SellPage, "Inventory Management", "secInventory")

local MainGui = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainGui")
local EquipmentScroll = MainGui:FindFirstChild("ScreenBackpack") and MainGui.ScreenBackpack:FindFirstChild("InventoryFrame") and MainGui.ScreenBackpack.InventoryFrame:FindFirstChild("EquipmentContent") and MainGui.ScreenBackpack.InventoryFrame.EquipmentContent:FindFirstChild("ScrollingFrame")
local OresScroll      = MainGui:FindFirstChild("ScreenEquipSell") and MainGui.ScreenEquipSell:FindFirstChild("SellFrame") and MainGui.ScreenEquipSell.SellFrame:FindFirstChild("OresContent") and MainGui.ScreenEquipSell.SellFrame.OresContent:FindFirstChild("ScrollingFrame")
local MaterialsScroll = MainGui:FindFirstChild("ScreenEquipSell") and MainGui.ScreenEquipSell:FindFirstChild("SellFrame") and MainGui.ScreenEquipSell.SellFrame:FindFirstChild("MaterialContent") and MainGui.ScreenEquipSell.SellFrame.MaterialContent:FindFirstChild("ScrollingFrame")

local BulkSelectedUUIDs = {}
local SELL_CATEGORIES   = {"All","Weapon","Helmet","Breastplate","Ore","Material"}

-- Warna aktif item scan mengikut tema (primary gelap)
local function _scanActiveBg()
    local p = H.CurrentThemePrimary or Color3.fromRGB(80, 100, 220)
    return Color3.new(p.R * 0.28, p.G * 0.28, p.B * 0.28)
end

_G.SellCategoryDropdown = CreateDropdownUI(SellPage, "Kategori", SELL_CATEGORIES, EngineConfig.SellCategory, function(v) EngineConfig.SellCategory = v end, "lblSellCategory")

local ItemResultContainer = Instance.new("ScrollingFrame", SellPage)
ItemResultContainer.Name = "IRC"; ItemResultContainer.Size = UDim2.new(1, 0, 0, 200)
ItemResultContainer.BackgroundTransparency = 1; ItemResultContainer.ScrollBarThickness = 3; ItemResultContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UIListLayout", ItemResultContainer).Padding = UDim.new(0, 5)

local function sellSpesifikNamaItem(listUUIDs, tipeItem)
    if not listUUIDs or #listUUIDs == 0 then return end
    if tipeItem == "Material" then pcall(function() MaterialRE:FireServer("Sell", listUUIDs, {}) end)
    elseif tipeItem == "Ore" then pcall(function() ForgeRF:InvokeServer("Sell", listUUIDs) end)
    else pcall(function() EquipmentRE:FireServer("Sell", listUUIDs) end) end
end

local function runInventoryScanner(parentFrame, filterCategory)
    for _, c in ipairs(parentFrame:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
    local db = {}; for _, cat in ipairs(SELL_CATEGORIES) do db[cat] = {} end
    local function insertDB(cat, id, uuid, visual)
        if not db[cat][id] then db[cat][id] = {Visual=visual,UUIDs={},OriginalCategory=cat} end
        table.insert(db[cat][id].UUIDs, uuid)
        if not db["All"][id] then db["All"][id] = {Visual=visual,UUIDs={},OriginalCategory=cat} end
        table.insert(db["All"][id].UUIDs, uuid)
    end
    if EquipmentScroll then
        for _, slot in ipairs(EquipmentScroll:GetChildren()) do
            if slot:IsA("GuiObject") and slot.Name ~= "UIListLayout" and slot.Name ~= "UIPadding" then
                local vis = slot.Name; local nl = slot:FindFirstChild("ItemName",true) or slot:FindFirstChild("Name",true)
                if nl and nl:IsA("TextLabel") then vis = nl.Text end
                local uuid = slot:GetAttribute("UUID") or slot.Name
                local uo = slot:FindFirstChild("UUID",true)
                if uo then uuid = uo:IsA("ValueBase") and uo.Value or uo.Text end
                local check = string.lower(vis.." "..slot.Name); local cat = "Weapon"
                if check:find("body") or check:find("plate") or check:find("armor") then cat = "Breastplate"
                elseif check:find("helm") or check:find("head") or check:find("hat") then cat = "Helmet" end
                insertDB(cat, vis, uuid, vis)
            end
        end
    end
    local function scrapeStackables(sg, cn)
        if not sg then return end
        for _, slot in ipairs(sg:GetChildren()) do
            if slot:IsA("GuiObject") and slot.Name ~= "UIListLayout" and slot.Name ~= "UIPadding" then
                local idAsli = slot.Name; local io = slot:FindFirstChild("ID",true)
                if io then idAsli = io:IsA("ValueBase") and tostring(io.Value) or io.Text end
                local nl = slot:FindFirstChild("ItemName",true) or slot:FindFirstChild("Name",true)
                local vis = idAsli; if nl and nl:IsA("TextLabel") then vis = nl.Text end
                insertDB(cn, idAsli, idAsli, vis)
            end
        end
    end
    scrapeStackables(OresScroll, "Ore"); scrapeStackables(MaterialsScroll, "Material")
    for targetID, dataObj in pairs(db[filterCategory]) do
        local storageKey = dataObj.OriginalCategory.."_"..targetID
        if (dataObj.OriginalCategory=="Ore" or dataObj.OriginalCategory=="Material") and EngineConfig.AutoSellStaticList[storageKey] then
            BulkSelectedUUIDs[storageKey] = {UUIDs=dataObj.UUIDs,Type=dataObj.OriginalCategory}
        end
        local totalItem = #dataObj.UUIDs; local btnText = dataObj.Visual.." [x"..totalItem.."]"
        local ItemBtn = Instance.new("TextButton", parentFrame)
        ItemBtn.Name = "IR"; ItemBtn.Size = UDim2.new(1,-10,0,32); ItemBtn.Font = Enum.Font.GothamMedium; ItemBtn.TextSize = 12
        ItemBtn.TextXAlignment = Enum.TextXAlignment.Left; ItemBtn.TextColor3 = Color3.fromRGB(255,255,255); ItemBtn.BorderSizePixel = 0
        Instance.new("UICorner", ItemBtn).CornerRadius = UDim.new(0, 6)
        local function refreshBtnVis()
            if BulkSelectedUUIDs[storageKey] then ItemBtn.BackgroundColor3 = _scanActiveBg(); ItemBtn.Text = "  ✅ "..btnText
            else ItemBtn.BackgroundColor3 = Color3.fromRGB(28,28,40); ItemBtn.Text = "  • "..btnText end
        end
        refreshBtnVis()
        ItemBtn.MouseButton1Click:Connect(function()
            if BulkSelectedUUIDs[storageKey] then
                BulkSelectedUUIDs[storageKey] = nil
                if dataObj.OriginalCategory=="Ore" or dataObj.OriginalCategory=="Material" then EngineConfig.AutoSellStaticList[storageKey] = nil end
            else
                BulkSelectedUUIDs[storageKey] = {UUIDs=dataObj.UUIDs,Type=dataObj.OriginalCategory}
                if dataObj.OriginalCategory=="Ore" or dataObj.OriginalCategory=="Material" then EngineConfig.AutoSellStaticList[storageKey] = true end
            end; refreshBtnVis()
        end)
    end
end

CreateButton(SellPage, "🔄 Scan Inventory", function()
    runInventoryScanner(ItemResultContainer, EngineConfig.SellCategory)
    CustomNotify("SCANNER","Kategori: "..EngineConfig.SellCategory,2)
end, "btnScanInventory")
CreateButton(SellPage, "💰 Execute Sell", function()
    local eq, ore, mat, cnt = {},{},{},0
    for _, d in pairs(BulkSelectedUUIDs) do
        for _, uuid in ipairs(d.UUIDs) do
            if d.Type=="Material" then table.insert(mat,uuid)
            elseif d.Type=="Ore" then table.insert(ore,uuid)
            else table.insert(eq,uuid) end; cnt = cnt+1
        end
    end
    if cnt == 0 then CustomNotify("SELL WARN","Tidak ada item!",3); return end
    if #eq  > 0 then sellSpesifikNamaItem(eq,"Equipment") end
    if #ore > 0 then sellSpesifikNamaItem(ore,"Ore") end
    if #mat > 0 then sellSpesifikNamaItem(mat,"Material") end
    task.wait(0.5); BulkSelectedUUIDs = {}
    runInventoryScanner(ItemResultContainer, EngineConfig.SellCategory)
    CustomNotify("SELL","Jual massal ("..cnt.." item) selesai.",3)
end, "btnExecuteSell")

-- ─── AUTO SELL BY SCAN ───────────────────────────────────────────────────────
-- Jual otomatis item yang dipilih dari hasil Scan Inventory (AutoSellStaticList).
-- Tidak rebuild UI — scan headless per interval.

local function doSellByScan()
    local eq, ore, mat, cnt = {},{},{},0

    -- Equipment (Weapon/Helmet/Breastplate)
    if EquipmentScroll then
        for _, slot in ipairs(EquipmentScroll:GetChildren()) do
            if slot:IsA("GuiObject") and slot.Name ~= "UIListLayout" and slot.Name ~= "UIPadding" then
                local vis = slot.Name
                local nl = slot:FindFirstChild("ItemName",true) or slot:FindFirstChild("Name",true)
                if nl and nl:IsA("TextLabel") then vis = nl.Text end
                local uuid = slot:GetAttribute("UUID") or slot.Name
                local uo = slot:FindFirstChild("UUID",true)
                if uo then uuid = uo:IsA("ValueBase") and uo.Value or uo.Text end
                local check = string.lower(vis.." "..slot.Name)
                local cat = "Weapon"
                if check:find("body") or check:find("plate") or check:find("armor") then cat = "Breastplate"
                elseif check:find("helm") or check:find("head") or check:find("hat") then cat = "Helmet" end
                if EngineConfig.AutoSellStaticList[cat.."_"..vis] then
                    table.insert(eq, uuid); cnt = cnt + 1
                end
            end
        end
    end

    -- Ore & Material (stackable)
    local function scanStack(sg, catName, bucket)
        if not sg then return end
        for _, slot in ipairs(sg:GetChildren()) do
            if slot:IsA("GuiObject") and slot.Name ~= "UIListLayout" and slot.Name ~= "UIPadding" then
                local idAsli = slot.Name
                local io = slot:FindFirstChild("ID",true)
                if io then idAsli = io:IsA("ValueBase") and tostring(io.Value) or io.Text end
                if EngineConfig.AutoSellStaticList[catName.."_"..idAsli] then
                    table.insert(bucket, idAsli); cnt = cnt + 1
                end
            end
        end
    end
    scanStack(OresScroll, "Ore", ore)
    scanStack(MaterialsScroll, "Material", mat)

    if cnt > 0 then
        if #eq  > 0 then sellSpesifikNamaItem(eq, "Equipment") end
        if #ore > 0 then sellSpesifikNamaItem(ore, "Ore") end
        if #mat > 0 then sellSpesifikNamaItem(mat, "Material") end
        CustomNotify("🔄 AUTO SCAN SELL","Terjual "..cnt.." item",2)
    end
    return cnt
end

-- Interval input
_G.AutoSellScanIntervalInput = CreateInputUI(SellPage, "Interval Auto Sell Scan (detik)", tostring(EngineConfig.AutoSellScanInterval), false, function(v)
    local n = tonumber(v); if n and n >= 1 then EngineConfig.AutoSellScanInterval = n end
end, "lblAutoSellScanInterval")

-- Toggle
_G.AutoSellScanToggle = CreateToggleUI(SellPage, "⚡ Auto Sell by Scan", EngineConfig.AutoSellScanActive, function(v)
    EngineConfig.AutoSellScanActive = v
    if v then CustomNotify("⚡ AUTO SCAN SELL","Aktif!",2)
    else      CustomNotify("⚡ AUTO SCAN SELL","Nonaktif",2) end
end, "lblAutoSellScan")

-- Background loop
task.spawn(function()
    local elapsed = 0
    while true do
        task.wait(1)
        if EngineConfig.AutoSellScanActive then
            elapsed = elapsed + 1
            if elapsed >= math.max(EngineConfig.AutoSellScanInterval or 5, 1) then
                elapsed = 0; doSellByScan()
            end
        else
            elapsed = 0
        end
    end
end)

CreateSection(SellPage, "Merchant System", "secMerchant")
CreateButton(SellPage, "🛒 Buka Merchant", function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart"); local prompt = nil
    for _, v in pairs(Workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local txt = (v.ObjectText..v.ActionText):lower()
            if v.Parent.Name:lower():match("merchant") or txt:match("merchant") or v.Parent.Name:lower():match("shop") or txt:match("shop") then
                prompt = v; break end
        end
    end
    if prompt and prompt.Parent:IsA("BasePart") then
        CombatEngine.ResetPhysics(hrp); hrp.CFrame = prompt.Parent.CFrame*CFrame.new(0,2,0); task.wait(0.3)
        if fireproximityprompt then fireproximityprompt(prompt); CustomNotify("MERCHANT","Terbuka!",3)
        else CustomNotify("WARN","Executor tidak support fireproximityprompt",3) end
    else CustomNotify("MERCHANT ERROR","Gagal menemukan Merchant!",4) end
end, "btnOpenMerchant")


--------------------------------------------------------------------------------
