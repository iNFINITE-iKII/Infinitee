--------------------------------------------------------------------------------
--// ui/tab_autobuy.lua — S22 Tab 6: Auto Buy
--------------------------------------------------------------------------------
local H            = getgenv().Hub
local EngineConfig = H.EngineConfig
local Services     = H.Services
local LocalPlayer  = H.LocalPlayer
local CustomNotify = H.CustomNotify
local RegisterTranslation          = H.RegisterTranslation
local FindGoldShopScrollingFrame   = H.FindGoldShopScrollingFrame
local FindSeasonShopScrollingFrame = H.FindSeasonShopScrollingFrame
local GetGoldShopCatalog           = H.GetGoldShopCatalog    -- catalog Gold via module
local GetBondShopCatalog           = H.GetBondShopCatalog    -- catalog Bond via module
local GetSeasonShopCatalog         = H.GetSeasonShopCatalog  -- catalog Season via config module
local GetItemDisplayName           = H.GetItemDisplayName    -- nama visual dari ItemId
local HttpService  = H.HttpService
local FOLDER_NAME  = H.FOLDER_NAME or "XiFilHub_Configs"
local SCAN_CACHE_PATH = FOLDER_NAME .. "/autobuy_scan_cache.json"
local CreateTab      = H.CreateTab
local CreateSection  = H.CreateSection
local CreateToggleUI = H.CreateToggleUI
local CreateCycleUI  = H.CreateCycleUI
local CreateButton   = H.CreateButton

-- [S22] TAB 6 — AUTO BUY
--------------------------------------------------------------------------------
local BuyPage = CreateTab("🛒 Auto Buy", "tabBuy")
CreateSection(BuyPage, "Gold Shop Auto-Buyer", "secGoldShop")

-- Kategori aktif: "Gold", "Bond", atau "Both"
local BuyCategory = "Gold"

-- Pilihan kategori (tab mini)
local CatFrame = Instance.new("Frame", BuyPage)
CatFrame.Size = UDim2.new(1,0,0,30); CatFrame.BackgroundTransparency = 1
local CatLayout = Instance.new("UIListLayout", CatFrame)
CatLayout.FillDirection = Enum.FillDirection.Horizontal
CatLayout.Padding = UDim.new(0,4); CatLayout.SortOrder = Enum.SortOrder.LayoutOrder

local catButtons = {}
-- [UPDATE] Menambahkan dukungan 'langKey' untuk Auto-Translate
local function makeCatBtn(label, cat, langKey)
    local b = Instance.new("TextButton", CatFrame)
    b.Size = UDim2.new(0,80,1,0); b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamMedium; b.TextSize = 11
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.BackgroundColor3 = cat == BuyCategory and Color3.fromRGB(40,100,180) or Color3.fromRGB(35,35,55)
    b.Text = label
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,5)
    catButtons[cat] = b
    
    -- Mendaftarkan tombol ini ke S10 Translate System
    if langKey then RegisterTranslation(langKey, b, "Text") end

    b.MouseButton1Click:Connect(function()
        BuyCategory = cat
        for k, cb in pairs(catButtons) do
            cb.BackgroundColor3 = k == cat and Color3.fromRGB(40,100,180) or Color3.fromRGB(35,35,55)
        end
    end)
end

-- Menyisipkan langKey ke masing-masing tombol
makeCatBtn("💰 Grocery",  "Gold",    "btnCatGrocery")  -- Gold via module catalog (tanpa GUI)
makeCatBtn("💎 Bond Shop", "Bond",   "btnCatBond")
makeCatBtn("🌸 Season",   "Season", "btnCatSeason")
makeCatBtn("🌐 All",      "Both",   "btnCatAll")

local BuyButtonsRef = {}
local ShopListContainer = Instance.new("ScrollingFrame", BuyPage)
ShopListContainer.Name = "SLC"; ShopListContainer.Size = UDim2.new(1,0,0,200); ShopListContainer.BackgroundTransparency = 1
ShopListContainer.ScrollBarThickness = 3; ShopListContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
local SLL = Instance.new("UIListLayout",ShopListContainer); SLL.Padding = UDim.new(0,4); SLL.SortOrder = Enum.SortOrder.LayoutOrder

--------------------------------------------------------------------------------
-- [CACHE] Shared button factory — dipakai scan maupun load-from-cache
--------------------------------------------------------------------------------
local function AddBuyButton(key, labelText, meta)
    local btn = Instance.new("TextButton", ShopListContainer)
    btn.Size = UDim2.new(1,-10,0,30)
    btn.Font = Enum.Font.GothamMedium; btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left; btn.BorderSizePixel = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    btn.Text            = labelText
    btn.BackgroundColor3 = EngineConfig.AutoBuyTargetList[key] and Color3.fromRGB(30,100,50) or Color3.fromRGB(28,28,40)
    btn.TextColor3      = Color3.fromRGB(255,255,255)
    btn.MouseButton1Click:Connect(function()
        if EngineConfig.AutoBuyTargetList[key] then
            EngineConfig.AutoBuyTargetList[key] = nil
            btn.BackgroundColor3 = Color3.fromRGB(28,28,40)
        else
            EngineConfig.AutoBuyTargetList[key] = true
            btn.BackgroundColor3 = Color3.fromRGB(30,100,50)
        end
    end)
    meta.Button = btn
    BuyButtonsRef[key] = meta
    return btn
end

-- Catalog sources — dimuat ulang dari module saat startup, tidak perlu di-cache
local CATALOG_SOURCES = { GoldV2 = true, BondV2 = true, SeasonV2 = true }

-- Simpan metadata item non-catalog ke file JSON (hanya legacy GoldBond/Season dari GUI)
local function SaveScanCache()
    local data = {}
    for k, v in pairs(BuyButtonsRef) do
        if not CATALOG_SOURCES[v.Source] then
            data[k] = {
                Name        = v.Name,
                Badge       = v.Badge,
                Source      = v.Source,
                Price       = v.Price,
                SeasonFrame = v.SeasonFrame,
            }
        end
    end
    pcall(function()
        if not isfolder(FOLDER_NAME) then makefolder(FOLDER_NAME) end
        writefile(SCAN_CACHE_PATH, HttpService:JSONEncode(data))
    end)
end

-- Rebuild button list dari cache file — tidak butuh toko terbuka
local function LoadScanCache()
    if not (isfile and isfile(SCAN_CACHE_PATH)) then return 0 end
    local ok, raw = pcall(readfile, SCAN_CACHE_PATH)
    if not ok or not raw or raw == "" then return 0 end
    local dok, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not dok or type(data) ~= "table" then return 0 end

    -- Hapus tombol lama sebelum rebuild
    for _, c in ipairs(ShopListContainer:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    table.clear(BuyButtonsRef)

    local count = 0
    for key, meta in pairs(data) do
        if type(meta) == "table" and meta.Source and meta.Source ~= "GoldV2" then
            local labelText
            if meta.Source == "Season" then
                local priceTag = (meta.Price and meta.Price ~= "") and ("  🎫"..meta.Price) or ""
                labelText = "  🌸 " .. (meta.Name or key) .. priceTag
            else
                -- GoldBond
                labelText = "  " .. (meta.Badge or "💰") .. " " .. (meta.Name or key)
            end
            AddBuyButton(key, labelText, {
                Name        = meta.Name or key,
                Badge       = meta.Badge or "💰",
                Source      = meta.Source,
                Price       = meta.Price,
                SeasonFrame = meta.SeasonFrame,
            })
            count = count + 1
        end
    end
    return count
end

-- [UPDATE] Menyisipkan "lblEnableAutoBuy" di akhir parameter untuk auto translate
_G.AutoBuyToggle = CreateToggleUI(BuyPage, "🛒 Enable Multi Auto-Buy", EngineConfig.AutoBuyActive, function(v)
    local cnt = 0; for _ in pairs(EngineConfig.AutoBuyTargetList) do cnt = cnt+1 end
    if v and cnt == 0 then CustomNotify("AUTO BUY WARN","Pilih item dulu!",3); EngineConfig.AutoBuyActive = false; _G.AutoBuyToggle:SetValue(false); return end
    -- Semua kategori kini via FireServer (tidak butuh GUI terbuka)
    -- needsShop = true hanya untuk legacy item cached dari GUI lama (tanpa prefix catalog)
    local needsShop = false
    for k in pairs(EngineConfig.AutoBuyTargetList) do
        if not k:find("^SeasonShop_") and not k:find("^GoldV2_")
           and not k:find("^BondV2_") and not k:find("^SeasonV2_") then
            needsShop = true; break
        end
    end
    if v and needsShop and not FindGoldShopScrollingFrame() then CustomNotify("AUTO BUY WARN","Buka toko Consumable dulu!",3); EngineConfig.AutoBuyActive = false; _G.AutoBuyToggle:SetValue(false); return end
    EngineConfig.AutoBuyActive = v; CustomNotify("AUTO BUY", v and ("Berjalan! ("..cnt.." item)") or "Dimatikan.",2)
end, "lblEnableAutoBuy")

CreateButton(BuyPage, "🔄 Scan Shop", function()
    for _, c in ipairs(ShopListContainer:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    table.clear(BuyButtonsRef)

    local total = 0

    -- Cari nama visual dari item GUI: coba NameTXT dulu, lalu fallback ke
    -- TextLabel/TextButton pertama yang non-numerik dan non-kosong.
    local function getVisualName(item, fallback)
        local nameTXT = item:FindFirstChild("NameTXT", true)
        if nameTXT and nameTXT.Text ~= "" then return nameTXT.Text end
        -- Rekursif cari TextLabel/TextButton bermakna
        local function search(parent)
            for _, child in ipairs(parent:GetChildren()) do
                if (child:IsA("TextLabel") or child:IsA("TextButton"))
                    and child.Text ~= ""
                    and not child.Text:match("^%s*%d+%s*$")   -- bukan angka murni
                    and not child.Text:match("^%s*[×x]")      -- bukan quantity marker
                then
                    return child.Text
                end
                local found = search(child)
                if found then return found end
            end
        end
        return search(item) or fallback
    end

    -- Helper: scan satu ScrollingFrame, buat tombol item via AddBuyButton
    local function scanSF(sf, prefixes, source)
        for _, item in ipairs(sf:GetChildren()) do
            local match = false
            for _, pfx in ipairs(prefixes) do
                if item.Name:find(pfx, 1, true) then match = true; break end
            end
            if match then
                local stockTXT    = item:FindFirstChild("StockTXT", true)
                local stok        = tonumber(stockTXT and stockTXT.Text:match("%d+"))
                local displayName = getVisualName(item, item.Name)
                local badge = item.Name:sub(1,5) == "Gold_" and "💰"
                           or item.Name:find("SeasonShop_", 1, true) and "🌸"
                           or "💎"
                total = total + 1
                local labelText = (not stockTXT or stok == 0 or stok == 10)
                    and ("  " .. badge .. " " .. displayName)
                    or  ("  " .. badge .. " " .. displayName .. "  [" .. stok .. "]")
                AddBuyButton(item.Name, labelText, {
                    Name   = displayName,
                    Badge  = badge,
                    Source = source,
                })
            end
        end
    end

    -- Grocery (Gold) — via module catalog, tidak butuh GUI terbuka.
    -- Jika toko GUI kebetulan terbuka, stok real-time di-overlay ke label tombol.
    if BuyCategory == "Gold" or BuyCategory == "Both" then
        local catalog = GetGoldShopCatalog and GetGoldShopCatalog(true) or {}
        if #catalog == 0 then
            CustomNotify("ERROR","Grocery: Gagal ambil catalog. Pastikan sudah masuk game!",5)
            if BuyCategory ~= "Both" then return end
        else
            local sf = FindGoldShopScrollingFrame()  -- opsional: overlay stok jika toko terbuka
            for _, item in ipairs(catalog) do
                local itemId     = item.ItemId
                local key        = "GoldV2_" .. itemId
                local visualName = GetItemDisplayName(itemId)
                local priceStr   = item.Price and ("  💰"..tostring(item.Price)) or ""

                -- Overlay stok real-time dari GUI jika toko terbuka
                local stockStr = ""
                if sf then
                    for _, guiItem in ipairs(sf:GetChildren()) do
                        if guiItem.Name:find(itemId, 1, true) then
                            local stockTXT = guiItem:FindFirstChild("StockTXT", true)
                            local stok = tonumber(stockTXT and stockTXT.Text:match("%d+"))
                            if stok and stok >= 1 and stok <= 9 then
                                stockStr = "  ["..stok.."]"
                            end
                            break
                        end
                    end
                end

                total = total + 1
                AddBuyButton(key, "  💰 "..visualName..priceStr..stockStr, {
                    Name   = visualName,
                    Badge  = "💰",
                    Source = "GoldV2",
                    ItemId = itemId,
                    Price  = priceStr,
                })
            end
        end
    end

    -- Bond — via module catalog, tidak butuh GUI terbuka
    if BuyCategory == "Bond" or BuyCategory == "Both" then
        local catalog = GetBondShopCatalog and GetBondShopCatalog(true) or {}
        if #catalog == 0 then
            CustomNotify("ERROR","Bond: Gagal ambil catalog. Pastikan sudah masuk game!",5)
            if BuyCategory ~= "Both" then return end
        else
            for _, item in ipairs(catalog) do
                local itemId     = item.ItemId
                local key        = "BondV2_" .. itemId
                local visualName = GetItemDisplayName(itemId)
                local priceStr   = item.Price and ("  💎"..tostring(item.Price)) or ""
                total = total + 1
                AddBuyButton(key, "  💎 "..visualName..priceStr, {
                    Name   = visualName,
                    Badge  = "💎",
                    Source = "BondV2",
                    ItemId = itemId,
                    Price  = priceStr,
                })
            end
        end
    end

    -- Season — via ResSeasonShop config module, tidak butuh GUI terbuka
    -- Key = ShopId (e.g. SeasonShop_01) agar kompatibel dengan buy loop FireServer
    if BuyCategory == "Season" or BuyCategory == "Both" then
        local catalog = GetSeasonShopCatalog and GetSeasonShopCatalog(true) or {}
        if #catalog == 0 then
            CustomNotify("ERROR","Season: Gagal ambil catalog. Pastikan sudah masuk game!",5)
            if BuyCategory ~= "Both" then return end
        else
            for _, item in ipairs(catalog) do
                local shopId     = item.ShopId
                local visualName = GetItemDisplayName(item.ItemId)
                local priceTag   = item.Price and ("  🎫"..tostring(item.Price)) or ""
                local limitTag   = item.LimitTimes and ("  [L:"..tostring(item.LimitTimes).."]") or ""
                total = total + 1
                AddBuyButton(shopId, "  🌸 "..visualName..priceTag..limitTag, {
                    Name       = visualName,
                    Badge      = "🌸",
                    Source     = "SeasonV2",
                    ItemId     = item.ItemId,
                    Price      = tostring(item.Price or ""),
                    LimitTimes = item.LimitTimes,
                })
            end
        end
    end

    if total == 0 then
        CustomNotify("SCAN","0 item cocok. Cek nama di Output!",5)
    else
        CustomNotify("SHOP","Memuat "..total.." item ("..BuyCategory..").",3)
        SaveScanCache()
    end
end, "btnScanGoldShop")

-- Background Loop untuk Update Stok Real-time (Anti Geser & Warna Aman)
-- Catalog sources (GoldV2/BondV2/SeasonV2): tampil badge+nama+harga, overlay stok dari GUI jika ada
-- Legacy sources (GoldBond/Season): GUI lookup seperti sebelumnya
task.spawn(function()
    while true do
        task.wait(2)
        if EngineConfig.AutoBuyActive and BuyButtonsRef then
            local sf = FindGoldShopScrollingFrame()

            for itemName, data in pairs(BuyButtonsRef) do
                local btn = data.Button
                if btn and btn.Parent then

                    if CATALOG_SOURCES[data.Source] then
                        -- Catalog item: badge+nama+harga, overlay stok GUI jika relevan
                        local stockOverlay = ""
                        if sf and data.ItemId and (data.Source == "GoldV2" or data.Source == "BondV2") then
                            for _, guiItem in ipairs(sf:GetChildren()) do
                                if guiItem.Name:find(data.ItemId, 1, true) then
                                    local stockTXT = guiItem:FindFirstChild("StockTXT", true)
                                    local stok = tonumber(stockTXT and stockTXT.Text:match("%d+"))
                                    if stok and stok >= 1 and stok <= 9 then
                                        stockOverlay = "  ["..stok.."]"
                                    end
                                    break
                                end
                            end
                        end
                        btn.Text = "  "..(data.Badge or "💰").." "..data.Name..(data.Price or "")..stockOverlay
                        btn.BackgroundColor3 = EngineConfig.AutoBuyTargetList[itemName] and Color3.fromRGB(30,100,50) or Color3.fromRGB(28,28,40)
                    else
                        -- Legacy: lookup langsung di GUI SF
                        if sf then
                            local item = sf:FindFirstChild(itemName)
                            if item then
                                local stockTXT = item:FindFirstChild("StockTXT", true)
                                local stok     = tonumber(stockTXT and stockTXT.Text:match("%d+"))
                                if not stockTXT or stok == 0 or stok == 10 then
                                    btn.Text = "  "..(data.Badge or "💰").." "..data.Name
                                else
                                    btn.Text = "  "..(data.Badge or "💰").." "..data.Name.."  ["..stok.."]"
                                end
                                btn.BackgroundColor3 = EngineConfig.AutoBuyTargetList[itemName] and Color3.fromRGB(30,100,50) or Color3.fromRGB(28,28,40)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- [STARTUP] Auto-load semua catalog saat script pertama jalan — tidak perlu Scan manual
task.defer(function()
    local counts = { gold = 0, bond = 0, season = 0 }

    -- Gold
    for _, item in ipairs(GetGoldShopCatalog and GetGoldShopCatalog(false) or {}) do
        local key = "GoldV2_" .. item.ItemId
        if not BuyButtonsRef[key] then
            local name  = GetItemDisplayName(item.ItemId)
            local price = item.Price and ("  💰"..tostring(item.Price)) or ""
            AddBuyButton(key, "  💰 "..name..price, { Name=name, Badge="💰", Source="GoldV2", ItemId=item.ItemId, Price=price })
            counts.gold = counts.gold + 1
        end
    end

    -- Bond
    for _, item in ipairs(GetBondShopCatalog and GetBondShopCatalog(false) or {}) do
        local key = "BondV2_" .. item.ItemId
        if not BuyButtonsRef[key] then
            local name  = GetItemDisplayName(item.ItemId)
            local price = item.Price and ("  💎"..tostring(item.Price)) or ""
            AddBuyButton(key, "  💎 "..name..price, { Name=name, Badge="💎", Source="BondV2", ItemId=item.ItemId, Price=price })
            counts.bond = counts.bond + 1
        end
    end

    -- Season
    for _, item in ipairs(GetSeasonShopCatalog and GetSeasonShopCatalog(false) or {}) do
        local key = item.ShopId
        if not BuyButtonsRef[key] then
            local name     = GetItemDisplayName(item.ItemId)
            local priceTag = item.Price and ("  🎫"..tostring(item.Price)) or ""
            local limitTag = item.LimitTimes and ("  [L:"..tostring(item.LimitTimes).."]") or ""
            AddBuyButton(key, "  🌸 "..name..priceTag..limitTag, { Name=name, Badge="🌸", Source="SeasonV2", ItemId=item.ItemId, Price=tostring(item.Price or ""), LimitTimes=item.LimitTimes })
            counts.season = counts.season + 1
        end
    end

    local total = counts.gold + counts.bond + counts.season
    if total > 0 then
        CustomNotify("🛒 AUTO BUY",
            "📂 "..total.." item dimuat ("..counts.gold.." Grocery · "..counts.bond.." Bond · "..counts.season.." Season).", 5)
    end
end)

--------------------------------------------------------------------------------
