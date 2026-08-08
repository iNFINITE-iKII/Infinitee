--------------------------------------------------------------------------------
--// ui/tab_forge.lua — Tab: Auto Forge V6
-- Menampilkan kontrol Auto Forge: resep, komposisi ore, craft count,
-- start/stop, dan Target Mode dengan manajemen profil.
-- Engine: games/TamplateGUI/auto_forge.lua
--------------------------------------------------------------------------------
local H            = getgenv().XiFilTemplateGUI_Hub
local _G           = getgenv().XiFilTemplateGUI_G
local EngineConfig = H.EngineConfig
local AutoForge    = H.AutoForge
local CustomNotify = H.CustomNotify
local CreateTab      = H.CreateTab
local CreateSection  = H.CreateSection
local CreateToggleUI = H.CreateToggleUI
local CreateButton   = H.CreateButton
local GetThemeColor        = H.GetThemeColor
local RegisterThemeElement = H.RegisterThemeElement
local GetOreCatalog        = H.GetOreCatalog
local GetOreRarityLevels   = H.GetOreRarityLevels

local HttpService = game:GetService("HttpService")

local function CopyMap(Source)
    local Result = {}
    for K, V in pairs(Source or {}) do Result[K] = V end
    return Result
end

local function ClampNumber(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return math.clamp(value, minimum, maximum)
end

local function CopyProfile(Profile)
    local Copy = {
        Id=Profile.Id, Name=Profile.Name, Enabled=Profile.Enabled,
        SlotMode=Profile.SlotMode, SlotCount=Profile.SlotCount,
        PoolPreset=Profile.PoolPreset, PoolStats={}, Rules={}
    }
    for _, s in ipairs(Profile.PoolStats or {}) do table.insert(Copy.PoolStats, s) end
    for _, r in ipairs(Profile.Rules or {}) do
        local rc = {}; for k,v in pairs(r) do rc[k]=v end
        table.insert(Copy.Rules, rc)
    end
    return Copy
end

-- ── Tab ───────────────────────────────────────────────────────────────────────
local ForgePage = CreateTab("⚒️ Forge", "tabForge")

-- ══════════════════════════════════════════════════════════════════════════════
-- SECTION 1: KONTROL UTAMA
-- ══════════════════════════════════════════════════════════════════════════════
CreateSection(ForgePage, "Forge Control", "secForgeCtrl")

-- Status bar
local StatusFrame = Instance.new("Frame", ForgePage)
StatusFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
StatusFrame.BorderSizePixel  = 0
StatusFrame.Size             = UDim2.new(1, -10, 0, 28)
Instance.new("UICorner", StatusFrame).CornerRadius = UDim.new(0, 6)

local StatusStroke = Instance.new("UIStroke", StatusFrame)
StatusStroke.Thickness    = 1
StatusStroke.Transparency = 0.7
StatusStroke.Color        = GetThemeColor and GetThemeColor("Primary") or Color3.fromRGB(80, 130, 255)
if RegisterThemeElement then RegisterThemeElement("Strokes", StatusStroke) end

local StatusDot = Instance.new("Frame", StatusFrame)
StatusDot.Size             = UDim2.fromOffset(6, 6)
StatusDot.Position         = UDim2.new(0, 10, 0.5, -3)
StatusDot.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
StatusDot.BorderSizePixel  = 0
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local StatusLabel = Instance.new("TextLabel", StatusFrame)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position       = UDim2.new(0, 22, 0, 0)
StatusLabel.Size           = UDim2.new(1, -26, 1, 0)
StatusLabel.Font           = Enum.Font.GothamMedium
StatusLabel.TextSize       = 11
StatusLabel.TextColor3     = Color3.fromRGB(140, 140, 160)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Text           = "Status: IDLE"

local function UpdateStatusUI()
    local st = AutoForge.State.Status or "IDLE"
    StatusLabel.Text = "Status: " .. st
    if st == "IDLE" or st == "OFF" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        StatusLabel.TextColor3     = Color3.fromRGB(120, 120, 140)
    elseif st:sub(1,4) == "DONE" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
        StatusLabel.TextColor3     = Color3.fromRGB(60, 200, 100)
    elseif st:sub(1,6) == "FORGI" or st:sub(1,3) == "QTE" or st:sub(1,7) == "WAITING" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(80, 180, 255)
        StatusLabel.TextColor3     = Color3.fromRGB(80, 180, 255)
    elseif st:sub(1,6) == "TARGET" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(220, 180, 40)
        StatusLabel.TextColor3     = Color3.fromRGB(220, 180, 40)
    elseif st:sub(1,5) == "ERROR" or st:sub(1,7) == "STOPPED" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        StatusLabel.TextColor3     = Color3.fromRGB(220, 80, 80)
    else
        StatusDot.BackgroundColor3 = Color3.fromRGB(180, 160, 255)
        StatusLabel.TextColor3     = Color3.fromRGB(180, 160, 255)
    end
end

AutoForge.State.Refresh = UpdateStatusUI

-- Toggle Perfect Forge
_G.PerfectForgeToggle = CreateToggleUI(ForgePage, "⭐ Perfect Forge (Auto Max Rating)",
    EngineConfig.PerfectForgeActive,
    function(v)
        _G.PerfectForge = v
        EngineConfig.PerfectForgeActive = v
        AutoForge.SaveToEngineConfig()
        CustomNotify("PERFECT FORGE", v and "Aktif!" or "Dimatikan.", 2)
    end,
    "lblPerfectForge"
)

-- Toggle Auto Forge
_G.AutoForgeToggle = CreateToggleUI(ForgePage, "⚒️ Enable Auto Forge",
    EngineConfig.AutoForgeActive,
    function(v)
        _G.AutoForge = v
        EngineConfig.AutoForgeActive = v
        AutoForge.SaveToEngineConfig()
        if not v and AutoForge.State.Running then
            AutoForge.SetStatus("STOP AFTER CURRENT CRAFT")
        end
        UpdateStatusUI()
        CustomNotify("AUTO FORGE", v and "Aktif!" or "Dimatikan.", 2)
    end,
    "lblAutoForge"
)

-- ══════════════════════════════════════════════════════════════════════════════
-- SECTION 2: RESEP & CRAFT
-- ══════════════════════════════════════════════════════════════════════════════
CreateSection(ForgePage, "Recipe & Craft", "secForgeRecipe")

-- ── Recipe selector button ────────────────────────────────────────────────────
local CurrentRecipe = AutoForge.Recipes[AutoForge.RecipeId] or AutoForge.Recipes.WeaponSword
local function GetRecipeLabel(RecipeId)
    local R = AutoForge.Recipes[RecipeId]
    if not R then return "?" end
    return R.Category.." - "..R.Label.." ("..tostring(R.OreCount).." Ore, "..tostring(R.Chance).."%)"
end

local RecipeBtn = CreateButton(ForgePage, "📋 "..GetRecipeLabel(AutoForge.RecipeId), nil, "btnForgeRecipe")

local RecipeDropdown = Instance.new("ScrollingFrame", ForgePage)
RecipeDropdown.Name                 = "ForgeRecipeDropdown"
RecipeDropdown.BackgroundColor3     = Color3.fromRGB(18, 18, 28)
RecipeDropdown.BorderSizePixel      = 0
RecipeDropdown.Size                 = UDim2.new(1, -10, 0, 0)
RecipeDropdown.ScrollBarThickness   = 3
RecipeDropdown.AutomaticCanvasSize  = Enum.AutomaticSize.Y
RecipeDropdown.Visible              = false
RecipeDropdown.ZIndex               = 10
if GetThemeColor then
    RecipeDropdown.ScrollBarImageColor3 = GetThemeColor("Primary")
end
Instance.new("UICorner", RecipeDropdown).CornerRadius = UDim.new(0, 6)
local RecipeStroke = Instance.new("UIStroke", RecipeDropdown)
RecipeStroke.Thickness = 1
RecipeStroke.Transparency = 0.5
RecipeStroke.Color = GetThemeColor and GetThemeColor("Primary") or Color3.fromRGB(80, 130, 255)
local RecipeLayout = Instance.new("UIListLayout", RecipeDropdown)
RecipeLayout.Padding   = UDim.new(0, 3)
RecipeLayout.SortOrder = Enum.SortOrder.LayoutOrder
local RecipePadding = Instance.new("UIPadding", RecipeDropdown)
RecipePadding.PaddingTop    = UDim.new(0, 4)
RecipePadding.PaddingBottom = UDim.new(0, 4)
RecipePadding.PaddingLeft   = UDim.new(0, 4)
RecipePadding.PaddingRight  = UDim.new(0, 4)

-- Build recipe option buttons
for Idx, RecipeId in ipairs(AutoForge.RecipeOrder) do
    local R = AutoForge.Recipes[RecipeId]
    local OptBtn = Instance.new("TextButton", RecipeDropdown)
    OptBtn.Name              = "RecipeOpt_"..RecipeId
    OptBtn.Size              = UDim2.new(1, -8, 0, 28)
    OptBtn.BackgroundColor3  = Color3.fromRGB(28, 28, 42)
    OptBtn.BorderSizePixel   = 0
    OptBtn.Font              = Enum.Font.GothamMedium
    OptBtn.TextSize          = 10
    OptBtn.TextXAlignment    = Enum.TextXAlignment.Left
    OptBtn.TextColor3        = Color3.fromRGB(200, 200, 220)
    OptBtn.Text              = "  "..R.Category.." - "..R.Label.." ("..tostring(R.OreCount).." Ore, "..tostring(R.Chance).."%)"
    OptBtn.LayoutOrder       = Idx
    OptBtn.ZIndex            = 11
    Instance.new("UICorner", OptBtn).CornerRadius = UDim.new(0, 5)

    local capturedId = RecipeId
    OptBtn.MouseButton1Click:Connect(function()
        RecipeDropdown.Visible = false
        RecipeDropdown.Size = UDim2.new(1, -10, 0, 0)
        AutoForge.RecipeId  = capturedId
        AutoForge.Composition = {}
        AutoForge.State.Status = "SELECT ORE COMPOSITION"
        EngineConfig.AutoForgeRecipeId = capturedId
        EngineConfig.AutoForgeOreComposition = {}
        AutoForge.SaveToEngineConfig()
        RecipeBtn.Text = "📋 "..GetRecipeLabel(capturedId)
        UpdateStatusUI()
        RebuildOreRows()
    end)
end

RecipeBtn.MouseButton1Click:Connect(function()
    local nowVisible = not RecipeDropdown.Visible
    RecipeDropdown.Visible = nowVisible
    RecipeDropdown.Size = nowVisible and UDim2.new(1, -10, 0, math.min(200, #AutoForge.RecipeOrder * 32 + 12))
        or UDim2.new(1, -10, 0, 0)
end)

-- ── Craft Count + Start ────────────────────────────────────────────────────────
local CraftRow = Instance.new("Frame", ForgePage)
CraftRow.BackgroundTransparency = 1
CraftRow.Size = UDim2.new(1, -10, 0, 34)

-- Craft count box
local CraftBox = Instance.new("TextBox", CraftRow)
CraftBox.Name             = "ForgeCraftCount"
CraftBox.Size             = UDim2.new(0.45, -4, 1, -6)
CraftBox.Position         = UDim2.new(0, 0, 0, 3)
CraftBox.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
CraftBox.BorderSizePixel  = 0
CraftBox.Font             = Enum.Font.GothamMedium
CraftBox.TextSize         = 11
CraftBox.TextColor3       = Color3.fromRGB(210, 210, 230)
CraftBox.PlaceholderText  = "Craft count..."
CraftBox.PlaceholderColor3 = Color3.fromRGB(70, 70, 90)
CraftBox.Text             = "COUNT: "..tostring(AutoForge.RequestedCrafts)
CraftBox.ClearTextOnFocus = false
Instance.new("UICorner", CraftBox).CornerRadius = UDim.new(0, 6)
local CraftBoxStroke = Instance.new("UIStroke", CraftBox)
CraftBoxStroke.Thickness = 1
CraftBoxStroke.Transparency = 0.6
CraftBoxStroke.Color = GetThemeColor and GetThemeColor("Primary") or Color3.fromRGB(80, 130, 255)
if RegisterThemeElement then RegisterThemeElement("Strokes", CraftBoxStroke) end

CraftBox.Focused:Connect(function()
    CraftBox.Text = tostring(AutoForge.RequestedCrafts)
end)
CraftBox.FocusLost:Connect(function()
    AutoForge.RequestedCrafts = math.floor(ClampNumber(CraftBox.Text, 1, 999, 1))
    EngineConfig.AutoForgeRequestedCrafts = AutoForge.RequestedCrafts
    AutoForge.SaveToEngineConfig()
    CraftBox.Text = "COUNT: "..tostring(AutoForge.RequestedCrafts)
end)

-- Start / Stop button
local StartBtn = Instance.new("TextButton", CraftRow)
StartBtn.Name              = "ForgeStartBtn"
StartBtn.Size              = UDim2.new(0.55, -4, 1, -6)
StartBtn.Position          = UDim2.new(0.45, 4, 0, 3)
StartBtn.BackgroundColor3  = Color3.fromRGB(25, 100, 210)
StartBtn.BorderSizePixel   = 0
StartBtn.Font              = Enum.Font.GothamBold
StartBtn.TextSize          = 11
StartBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
StartBtn.Text              = "▶ START FORGE"
Instance.new("UICorner", StartBtn).CornerRadius = UDim.new(0, 6)

StartBtn.MouseButton1Click:Connect(function()
    RecipeDropdown.Visible = false
    RecipeDropdown.Size    = UDim2.new(1, -10, 0, 0)
    AutoForge.StartBatch()
    -- Refresh button visual after half a tick
    task.defer(function()
        StartBtn.Text = AutoForge.State.Running and "⏹ STOP AFTER CRAFT" or "▶ START FORGE"
        StartBtn.BackgroundColor3 = AutoForge.State.Running
            and Color3.fromRGB(180, 50, 50)
            or  Color3.fromRGB(25, 100, 210)
    end)
end)

-- ── Polling untuk refresh tombol Start ────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(0.5)
        if StartBtn and StartBtn.Parent then
            StartBtn.Text = AutoForge.State.Running and "⏹ STOP AFTER CRAFT" or "▶ START FORGE"
            StartBtn.BackgroundColor3 = AutoForge.State.Running
                and Color3.fromRGB(180, 50, 50)
                or  Color3.fromRGB(25, 100, 210)
            UpdateStatusUI()
        end
    end
end)

-- ── Summary bar ───────────────────────────────────────────────────────────────
local SummaryLabel = Instance.new("TextLabel", ForgePage)
SummaryLabel.BackgroundTransparency = 1
SummaryLabel.Size            = UDim2.new(1, -10, 0, 24)
SummaryLabel.Font            = Enum.Font.Gotham
SummaryLabel.TextSize        = 10
SummaryLabel.TextColor3      = Color3.fromRGB(120, 120, 150)
SummaryLabel.TextXAlignment  = Enum.TextXAlignment.Left
SummaryLabel.TextWrapped     = true
SummaryLabel.Text            = ""

local function RefreshSummary()
    local Recipe = AutoForge.Recipes[AutoForge.RecipeId] or AutoForge.Recipes.WeaponSword
    local Total  = AutoForge.GetCompositionTotal(AutoForge.Composition)
    local ok, Ores, Crystals = pcall(function() return AutoForge.GetInventory() end)
    if not ok then Ores, Crystals = {}, {} end
    local MaxCrafts, LimitingItemId, Reason = AutoForge.CalculateLimit(Recipe, AutoForge.Composition, Ores or {}, Crystals or {})
    local RelicText = ""
    if Recipe.RelicId then
        RelicText = " | RELIC "..tostring(tonumber((Crystals or {})[Recipe.RelicId]) or 0)
    end
    SummaryLabel.Text = "ORE "..tostring(Total).."/"..tostring(Recipe.OreCount)
        .." | MAX CRAFT: "..tostring(MaxCrafts)..RelicText
        ..(Reason and " ⚠ "..Reason or "")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SECTION 3: KOMPOSISI ORE
-- ══════════════════════════════════════════════════════════════════════════════
CreateSection(ForgePage, "Ore Composition", "secForgeOre")

-- Search + filter row
local FilterRow = Instance.new("Frame", ForgePage)
FilterRow.BackgroundTransparency = 1
FilterRow.Size = UDim2.new(1, -10, 0, 28)

local OreSearchBox = Instance.new("TextBox", FilterRow)
OreSearchBox.Name              = "ForgeOreSearch"
OreSearchBox.Size              = UDim2.new(1, -68, 1, 0)
OreSearchBox.BackgroundColor3  = Color3.fromRGB(18, 18, 28)
OreSearchBox.BorderSizePixel   = 0
OreSearchBox.Font              = Enum.Font.Gotham
OreSearchBox.TextSize          = 11
OreSearchBox.TextColor3        = Color3.fromRGB(200, 200, 220)
OreSearchBox.PlaceholderText   = "🔍 Search ore..."
OreSearchBox.PlaceholderColor3 = Color3.fromRGB(70, 70, 90)
OreSearchBox.Text              = ""
OreSearchBox.ClearTextOnFocus  = false
Instance.new("UICorner", OreSearchBox).CornerRadius = UDim.new(0, 6)
local OreSearchStroke = Instance.new("UIStroke", OreSearchBox)
OreSearchStroke.Thickness = 1; OreSearchStroke.Transparency = 0.6
OreSearchStroke.Color = GetThemeColor and GetThemeColor("Primary") or Color3.fromRGB(80, 130, 255)

local OreRefreshBtn = Instance.new("TextButton", FilterRow)
OreRefreshBtn.Size              = UDim2.new(0, 60, 1, 0)
OreRefreshBtn.Position          = UDim2.new(1, -60, 0, 0)
OreRefreshBtn.BackgroundColor3  = Color3.fromRGB(28, 28, 42)
OreRefreshBtn.BorderSizePixel   = 0
OreRefreshBtn.Font              = Enum.Font.GothamMedium
OreRefreshBtn.TextSize          = 10
OreRefreshBtn.TextColor3        = Color3.fromRGB(180, 180, 210)
OreRefreshBtn.Text              = "🔄 REFRESH"
Instance.new("UICorner", OreRefreshBtn).CornerRadius = UDim.new(0, 6)

-- Ore ScrollingFrame
local OreScroll = Instance.new("ScrollingFrame", ForgePage)
OreScroll.Name                  = "ForgeOreScroll"
OreScroll.BackgroundTransparency = 1
OreScroll.Size                  = UDim2.new(1, -10, 0, 200)
OreScroll.ScrollBarThickness    = 3
OreScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
if GetThemeColor then
    OreScroll.ScrollBarImageColor3 = GetThemeColor("Primary")
end

local OreLayout = Instance.new("UIListLayout", OreScroll)
OreLayout.Padding   = UDim.new(0, 4)
OreLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Ore row state
local OreRowRefs = {}  -- {Gui, ItemId, OwnedLbl, SelectedLbl, MinusBtn, PlusBtn, SearchText, Rarity}

local function FilterOreRows()
    local Query = string.lower(OreSearchBox.Text or "")
    for _, Row in ipairs(OreRowRefs) do
        local MatchQ = Query=="" or string.find(Row.SearchText, Query, 1, true)
        Row.Gui.Visible = MatchQ and true or false
    end
end

-- Forward-declare RebuildOreRows
RebuildOreRows = function()
    -- Clear existing rows
    for _, Child in ipairs(OreScroll:GetChildren()) do
        if not Child:IsA("UIListLayout") then Child:Destroy() end
    end
    table.clear(OreRowRefs)

    local Catalog = GetOreCatalog(true)
    if #Catalog == 0 then
        local EmptyLbl = Instance.new("TextLabel", OreScroll)
        EmptyLbl.BackgroundTransparency = 1
        EmptyLbl.Size         = UDim2.new(1, -10, 0, 34)
        EmptyLbl.Font         = Enum.Font.Gotham
        EmptyLbl.TextSize     = 11
        EmptyLbl.TextColor3   = Color3.fromRGB(80, 80, 100)
        EmptyLbl.Text         = "Ore tidak ditemukan. Klik REFRESH."
        EmptyLbl.TextWrapped  = true
        return
    end

    local Recipe = AutoForge.Recipes[AutoForge.RecipeId] or AutoForge.Recipes.WeaponSword
    local ok, Ores = pcall(function() return (AutoForge.GetInventory()) end)
    if not ok then Ores = {} end

    for Idx, Entry in ipairs(Catalog) do
        local Owned    = tonumber((Ores or {})[Entry.ItemId]) or 0
        local Selected = tonumber(AutoForge.Composition[Entry.ItemId]) or 0
        local DisplayName = H.GetItemDisplayName and H.GetItemDisplayName(Entry.ItemId) or tostring(Entry.ItemId)
        local RarityTag = Entry.RarityName and ("["..tostring(Entry.RarityName).."] ") or ""

        -- Row frame
        local Row = Instance.new("Frame", OreScroll)
        Row.Name                = "OreRow_"..Entry.ItemId
        Row.BackgroundColor3    = Color3.fromRGB(20, 20, 32)
        Row.BorderSizePixel     = 0
        Row.Size                = UDim2.new(1, -4, 0, 36)
        Row.LayoutOrder         = Idx
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)

        -- Name label
        local NameLbl = Instance.new("TextLabel", Row)
        NameLbl.BackgroundTransparency = 1
        NameLbl.Position       = UDim2.new(0, 8, 0, 0)
        NameLbl.Size           = UDim2.new(1, -152, 1, 0)
        NameLbl.Font           = Enum.Font.GothamMedium
        NameLbl.TextSize       = 10
        NameLbl.TextXAlignment = Enum.TextXAlignment.Left
        NameLbl.TextColor3     = Color3.fromRGB(200, 200, 220)
        NameLbl.Text           = RarityTag..DisplayName
        NameLbl.TextTruncate   = Enum.TextTruncate.AtEnd

        -- Owned count
        local OwnedLbl = Instance.new("TextLabel", Row)
        OwnedLbl.BackgroundTransparency = 1
        OwnedLbl.Position      = UDim2.new(1, -144, 0, 0)
        OwnedLbl.Size          = UDim2.fromOffset(38, 36)
        OwnedLbl.Font          = Enum.Font.Gotham
        OwnedLbl.TextSize      = 10
        OwnedLbl.TextXAlignment = Enum.TextXAlignment.Right
        OwnedLbl.TextColor3    = Color3.fromRGB(120, 120, 150)
        OwnedLbl.Text          = "x"..tostring(Owned)

        -- Minus button
        local MinusBtn = Instance.new("TextButton", Row)
        MinusBtn.Size             = UDim2.fromOffset(26, 24)
        MinusBtn.Position         = UDim2.new(1, -100, 0, 6)
        MinusBtn.BackgroundColor3 = Selected > 0 and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(40, 40, 60)
        MinusBtn.BorderSizePixel  = 0
        MinusBtn.Font             = Enum.Font.GothamBold
        MinusBtn.TextSize         = 14
        MinusBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
        MinusBtn.Text             = "−"
        Instance.new("UICorner", MinusBtn).CornerRadius = UDim.new(0, 5)

        -- Selected count label
        local SelLbl = Instance.new("TextLabel", Row)
        SelLbl.BackgroundTransparency = 1
        SelLbl.Position      = UDim2.new(1, -70, 0, 0)
        SelLbl.Size          = UDim2.fromOffset(34, 36)
        SelLbl.Font          = Enum.Font.GothamBold
        SelLbl.TextSize      = 12
        SelLbl.TextXAlignment = Enum.TextXAlignment.Center
        SelLbl.TextColor3    = Color3.fromRGB(255, 255, 255)
        SelLbl.Text          = tostring(Selected)

        -- Plus button
        local PlusBtn = Instance.new("TextButton", Row)
        PlusBtn.Size             = UDim2.fromOffset(26, 24)
        PlusBtn.Position         = UDim2.new(1, -32, 0, 6)
        PlusBtn.BackgroundColor3 = Owned > 0 and Color3.fromRGB(30, 140, 60) or Color3.fromRGB(40, 40, 60)
        PlusBtn.BorderSizePixel  = 0
        PlusBtn.Font             = Enum.Font.GothamBold
        PlusBtn.TextSize         = 14
        PlusBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
        PlusBtn.Text             = "+"
        Instance.new("UICorner", PlusBtn).CornerRadius = UDim.new(0, 5)

        local RowRef = {
            Gui=Row, ItemId=Entry.ItemId,
            OwnedLbl=OwnedLbl, SelLbl=SelLbl, MinusBtn=MinusBtn, PlusBtn=PlusBtn,
            SearchText=string.lower(DisplayName.." "..tostring(Entry.ItemId).." "..tostring(Entry.RarityName)),
            Rarity=Entry.Rarity,
        }
        table.insert(OreRowRefs, RowRef)

        local capturedEntry = Entry
        MinusBtn.MouseButton1Click:Connect(function()
            local Cnt = tonumber(AutoForge.Composition[capturedEntry.ItemId]) or 0
            if Cnt > 1 then AutoForge.Composition[capturedEntry.ItemId] = Cnt - 1
            else AutoForge.Composition[capturedEntry.ItemId] = nil end
            EngineConfig.AutoForgeOreComposition = AutoForge.Composition
            AutoForge.SaveToEngineConfig()
            local NewSel = tonumber(AutoForge.Composition[capturedEntry.ItemId]) or 0
            SelLbl.Text = tostring(NewSel)
            MinusBtn.BackgroundColor3 = NewSel>0 and Color3.fromRGB(180,50,50) or Color3.fromRGB(40,40,60)
            RefreshSummary()
        end)

        PlusBtn.MouseButton1Click:Connect(function()
            local Recipe = AutoForge.Recipes[AutoForge.RecipeId] or AutoForge.Recipes.WeaponSword
            local OkInv, OresNow = pcall(function() return (AutoForge.GetInventory()) end)
            local OwnedNow = OkInv and AutoForge.GetOwnedCount(OresNow, capturedEntry.ItemId) or 0
            local SelNow   = tonumber(AutoForge.Composition[capturedEntry.ItemId]) or 0
            local Total    = AutoForge.GetCompositionTotal(AutoForge.Composition)
            if SelNow < OwnedNow and Total < Recipe.OreCount then
                AutoForge.Composition[capturedEntry.ItemId] = SelNow + 1
                EngineConfig.AutoForgeOreComposition = AutoForge.Composition
                AutoForge.SaveToEngineConfig()
                SelLbl.Text = tostring(SelNow + 1)
                MinusBtn.BackgroundColor3 = Color3.fromRGB(180,50,50)
            end
            RefreshSummary()
        end)
    end

    FilterOreRows()
    RefreshSummary()
end

OreRefreshBtn.MouseButton1Click:Connect(function()
    CustomNotify("AUTO FORGE", "Refreshing ore list...", 2)
    RebuildOreRows()
end)
OreSearchBox:GetPropertyChangedSignal("Text"):Connect(FilterOreRows)

-- ── Polling update owned counts setiap 3 detik ───────────────────────────────
task.spawn(function()
    while true do
        task.wait(3)
        if not AutoForge.State.Running then
            local ok, Ores = pcall(function() return (AutoForge.GetInventory()) end)
            if ok then
                for _, Row in ipairs(OreRowRefs) do
                    local Owned = AutoForge.GetOwnedCount(Ores, Row.ItemId)
                    if Row.OwnedLbl and Row.OwnedLbl.Parent then
                        Row.OwnedLbl.Text = "x"..tostring(Owned)
                        local Sel = tonumber(AutoForge.Composition[Row.ItemId]) or 0
                        Row.PlusBtn.BackgroundColor3 = Owned > 0 and Color3.fromRGB(30,140,60) or Color3.fromRGB(40,40,60)
                        Row.MinusBtn.BackgroundColor3 = Sel > 0 and Color3.fromRGB(180,50,50) or Color3.fromRGB(40,40,60)
                    end
                end
                RefreshSummary()
            end
        end
    end
end)

-- Auto-build ore rows saat modul pertama kali dimuat
task.defer(function()
    local retries = 0
    repeat
        RebuildOreRows()
        if #OreRowRefs == 0 then task.wait(2); retries=retries+1 end
    until #OreRowRefs > 0 or retries >= 5
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- SECTION 4: TARGET MODE
-- ══════════════════════════════════════════════════════════════════════════════
CreateSection(ForgePage, "Target Mode", "secForgeTarget")

_G.TargetModeToggle = CreateToggleUI(ForgePage, "🎯 Target Mode (Simpan yang cocok)",
    EngineConfig.AutoForgeTargetMode,
    function(v)
        AutoForge.TargetMode = v
        EngineConfig.AutoForgeTargetMode = v
        AutoForge.SaveToEngineConfig()
        CustomNotify("TARGET MODE", v and "Aktif!" or "Dimatikan.", 2)
    end,
    "lblTargetMode"
)

_G.AutoDeleteToggle = CreateToggleUI(ForgePage, "🗑️ Auto Delete Non-Match",
    EngineConfig.AutoForgeAutoDeleteNonMatch,
    function(v)
        AutoForge.AutoDeleteNonMatch = v
        EngineConfig.AutoForgeAutoDeleteNonMatch = v
        AutoForge.SaveToEngineConfig()
    end,
    "lblAutoDelete"
)

-- Target Found indicator
local TargetFoundFrame = Instance.new("Frame", ForgePage)
TargetFoundFrame.BackgroundColor3 = Color3.fromRGB(45, 80, 20)
TargetFoundFrame.BorderSizePixel  = 0
TargetFoundFrame.Size             = UDim2.new(1, -10, 0, 30)
TargetFoundFrame.Visible          = false
Instance.new("UICorner", TargetFoundFrame).CornerRadius = UDim.new(0, 6)

local TargetFoundLabel = Instance.new("TextLabel", TargetFoundFrame)
TargetFoundLabel.BackgroundTransparency = 1
TargetFoundLabel.Size            = UDim2.new(1, -8, 1, 0)
TargetFoundLabel.Position        = UDim2.new(0, 4, 0, 0)
TargetFoundLabel.Font            = Enum.Font.GothamMedium
TargetFoundLabel.TextSize        = 10
TargetFoundLabel.TextXAlignment  = Enum.TextXAlignment.Left
TargetFoundLabel.TextColor3      = Color3.fromRGB(120, 230, 80)
TargetFoundLabel.TextWrapped     = true
TargetFoundLabel.Text            = "🎯 No target found yet."

AutoForge.TargetRefresh = function()
    local Data = AutoForge.TargetFoundData
    if Data then
        TargetFoundFrame.Visible = true
        TargetFoundLabel.Text = "🎯 FOUND! ["..tostring(Data.ProfileName).."] — "..tostring(Data.ItemId)
            .." (Attempt "..tostring(Data.Attempt)..")"
    end
end

-- Profile list
CreateButton(ForgePage, "➕ Add Target Profile", function()
    OpenTargetEditor(AutoForge.CreateDefaultProfile(#AutoForge.Profiles + 1), nil)
end, "btnAddProfile")

local ProfileScroll = Instance.new("ScrollingFrame", ForgePage)
ProfileScroll.Name                  = "ForgeProfileScroll"
ProfileScroll.BackgroundTransparency = 1
ProfileScroll.Size                  = UDim2.new(1, -10, 0, 180)
ProfileScroll.ScrollBarThickness    = 3
ProfileScroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
if GetThemeColor then ProfileScroll.ScrollBarImageColor3 = GetThemeColor("Primary") end

local ProfileLayout = Instance.new("UIListLayout", ProfileScroll)
ProfileLayout.Padding   = UDim.new(0, 4)
ProfileLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Profile refresh function (forward-declared)
local RefreshProfileList

-- ── Profile Editor (overlay) ─────────────────────────────────────────────────
-- Built inline as a modal Frame inside ForgePage at ZIndex 30
local EditorOverlay = Instance.new("Frame", ForgePage)
EditorOverlay.Name              = "ForgeEditorOverlay"
EditorOverlay.BackgroundColor3  = Color3.fromRGB(12, 12, 22)
EditorOverlay.BorderSizePixel   = 0
EditorOverlay.Size              = UDim2.new(1, 0, 1, 0)
EditorOverlay.Position          = UDim2.new(0, 0, 0, 0)
EditorOverlay.Visible           = false
EditorOverlay.ZIndex            = 30
Instance.new("UICorner", EditorOverlay).CornerRadius = UDim.new(0, 8)
local EditorStroke = Instance.new("UIStroke", EditorOverlay)
EditorStroke.Thickness = 1; EditorStroke.Transparency = 0.3
EditorStroke.Color = GetThemeColor and GetThemeColor("Primary") or Color3.fromRGB(80, 130, 255)

local EditorScroll = Instance.new("ScrollingFrame", EditorOverlay)
EditorScroll.BackgroundTransparency = 1
EditorScroll.Size                   = UDim2.new(1, 0, 1, -36)
EditorScroll.Position               = UDim2.new(0, 0, 0, 36)
EditorScroll.ScrollBarThickness     = 3
EditorScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
EditorScroll.ZIndex                 = 31

local EditorLayout = Instance.new("UIListLayout", EditorScroll)
EditorLayout.Padding   = UDim.new(0, 6)
EditorLayout.SortOrder = Enum.SortOrder.LayoutOrder
local EditorPad = Instance.new("UIPadding", EditorScroll)
EditorPad.PaddingTop=UDim.new(0,6); EditorPad.PaddingBottom=UDim.new(0,6)
EditorPad.PaddingLeft=UDim.new(0,6); EditorPad.PaddingRight=UDim.new(0,6)

local EditorTitle = Instance.new("TextLabel", EditorOverlay)
EditorTitle.BackgroundTransparency = 1
EditorTitle.Size     = UDim2.new(1, -70, 0, 32)
EditorTitle.Position = UDim2.new(0, 8, 0, 2)
EditorTitle.Font     = Enum.Font.GothamBold
EditorTitle.TextSize = 13
EditorTitle.TextXAlignment = Enum.TextXAlignment.Left
EditorTitle.TextColor3 = Color3.fromRGB(220, 220, 240)
EditorTitle.Text     = "TARGET PROFILE"
EditorTitle.ZIndex   = 32

local EditorCloseBtn = Instance.new("TextButton", EditorOverlay)
EditorCloseBtn.Size     = UDim2.fromOffset(60, 26)
EditorCloseBtn.Position = UDim2.new(1, -64, 0, 4)
EditorCloseBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
EditorCloseBtn.BorderSizePixel = 0
EditorCloseBtn.Font     = Enum.Font.GothamMedium
EditorCloseBtn.TextSize = 11
EditorCloseBtn.TextColor3 = Color3.fromRGB(200, 100, 100)
EditorCloseBtn.Text     = "✕ CLOSE"
EditorCloseBtn.ZIndex   = 32
Instance.new("UICorner", EditorCloseBtn).CornerRadius = UDim.new(0, 5)
EditorCloseBtn.MouseButton1Click:Connect(function()
    EditorOverlay.Visible = false
end)

-- Helper to create a labeled input inside editor scroll
local function MakeEditorInput(Label, Placeholder, Default, ZIdx)
    local Lbl = Instance.new("TextLabel", EditorScroll)
    Lbl.BackgroundTransparency = 1
    Lbl.Size = UDim2.new(1, 0, 0, 16)
    Lbl.Font = Enum.Font.GothamMedium; Lbl.TextSize = 10
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.TextColor3 = Color3.fromRGB(140, 140, 170)
    Lbl.Text = Label; Lbl.ZIndex = ZIdx or 31

    local Box = Instance.new("TextBox", EditorScroll)
    Box.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
    Box.BorderSizePixel  = 0
    Box.Size             = UDim2.new(1, 0, 0, 28)
    Box.Font             = Enum.Font.Gotham; Box.TextSize = 11
    Box.TextColor3       = Color3.fromRGB(210, 210, 230)
    Box.PlaceholderText  = Placeholder
    Box.PlaceholderColor3 = Color3.fromRGB(70, 70, 90)
    Box.Text             = tostring(Default or "")
    Box.ClearTextOnFocus = false
    Box.ZIndex           = ZIdx or 31
    Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 5)
    local S = Instance.new("UIStroke", Box)
    S.Thickness = 1; S.Transparency = 0.6
    S.Color = GetThemeColor and GetThemeColor("Primary") or Color3.fromRGB(80, 130, 255)
    return Box
end

local EditorNameBox = MakeEditorInput("Profile Name", "e.g. Best Sword", "Profile 1")

local EditorSlotModeBtn = Instance.new("TextButton", EditorScroll)
EditorSlotModeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 45)
EditorSlotModeBtn.BorderSizePixel  = 0
EditorSlotModeBtn.Size             = UDim2.new(1, 0, 0, 28)
EditorSlotModeBtn.Font             = Enum.Font.GothamMedium; EditorSlotModeBtn.TextSize = 10
EditorSlotModeBtn.TextXAlignment   = Enum.TextXAlignment.Left
EditorSlotModeBtn.TextColor3       = Color3.fromRGB(200, 200, 220)
EditorSlotModeBtn.Text             = "  TOTAL SLOTS: Any Total Slots ▼"
EditorSlotModeBtn.ZIndex           = 31
Instance.new("UICorner", EditorSlotModeBtn).CornerRadius = UDim.new(0, 5)

local EditorSlotCountBox = MakeEditorInput("Slot Count (if not Any)", "e.g. 4", "1")

local EditorErrorLabel = Instance.new("TextLabel", EditorScroll)
EditorErrorLabel.BackgroundTransparency = 1
EditorErrorLabel.Size = UDim2.new(1, 0, 0, 18)
EditorErrorLabel.Font = Enum.Font.Gotham; EditorErrorLabel.TextSize = 10
EditorErrorLabel.TextXAlignment = Enum.TextXAlignment.Left
EditorErrorLabel.TextColor3 = Color3.fromRGB(220, 80, 80)
EditorErrorLabel.Text = ""; EditorErrorLabel.TextWrapped = true; EditorErrorLabel.ZIndex = 31

local EditorSaveBtn = Instance.new("TextButton", EditorScroll)
EditorSaveBtn.BackgroundColor3 = Color3.fromRGB(25, 100, 210)
EditorSaveBtn.BorderSizePixel  = 0
EditorSaveBtn.Size             = UDim2.new(1, 0, 0, 30)
EditorSaveBtn.Font             = Enum.Font.GothamBold; EditorSaveBtn.TextSize = 11
EditorSaveBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
EditorSaveBtn.Text             = "💾 SAVE PROFILE"; EditorSaveBtn.ZIndex = 31
Instance.new("UICorner", EditorSaveBtn).CornerRadius = UDim.new(0, 5)

-- Rules section inside editor
local EditorRulesTitle = Instance.new("TextLabel", EditorScroll)
EditorRulesTitle.BackgroundTransparency = 1
EditorRulesTitle.Size = UDim2.new(1, 0, 0, 18)
EditorRulesTitle.Font = Enum.Font.GothamBold; EditorRulesTitle.TextSize = 11
EditorRulesTitle.TextXAlignment = Enum.TextXAlignment.Left
EditorRulesTitle.TextColor3 = Color3.fromRGB(180, 180, 220)
EditorRulesTitle.Text = "RULES"; EditorRulesTitle.ZIndex = 31

local EditorAddRuleBtn = Instance.new("TextButton", EditorScroll)
EditorAddRuleBtn.BackgroundColor3 = Color3.fromRGB(28, 80, 28)
EditorAddRuleBtn.BorderSizePixel  = 0
EditorAddRuleBtn.Size             = UDim2.new(1, 0, 0, 26)
EditorAddRuleBtn.Font             = Enum.Font.GothamMedium; EditorAddRuleBtn.TextSize = 10
EditorAddRuleBtn.TextColor3       = Color3.fromRGB(100, 220, 100)
EditorAddRuleBtn.Text             = "➕ ADD RULE (PoolAtLeast default)"; EditorAddRuleBtn.ZIndex = 31
Instance.new("UICorner", EditorAddRuleBtn).CornerRadius = UDim.new(0, 5)

local EditorRulesContainer = Instance.new("Frame", EditorScroll)
EditorRulesContainer.BackgroundTransparency = 1
EditorRulesContainer.AutomaticSize = Enum.AutomaticSize.Y
EditorRulesContainer.Size = UDim2.new(1, 0, 0, 0)
EditorRulesContainer.ZIndex = 31
local EditorRulesLayout = Instance.new("UIListLayout", EditorRulesContainer)
EditorRulesLayout.Padding = UDim.new(0, 4)

-- Pool Stats section inside editor
local EditorPoolTitle = Instance.new("TextLabel", EditorScroll)
EditorPoolTitle.BackgroundTransparency = 1
EditorPoolTitle.Size = UDim2.new(1, 0, 0, 18)
EditorPoolTitle.Font = Enum.Font.GothamBold; EditorPoolTitle.TextSize = 11
EditorPoolTitle.TextXAlignment = Enum.TextXAlignment.Left
EditorPoolTitle.TextColor3 = Color3.fromRGB(180, 180, 220)
EditorPoolTitle.Text = "POOL STATS (Stats yang dihitung)"; EditorPoolTitle.ZIndex = 31

local EditorPoolHint = Instance.new("TextLabel", EditorScroll)
EditorPoolHint.BackgroundTransparency = 1
EditorPoolHint.Size = UDim2.new(1, 0, 0, 26)
EditorPoolHint.Font = Enum.Font.Gotham; EditorPoolHint.TextSize = 9
EditorPoolHint.TextXAlignment = Enum.TextXAlignment.Left
EditorPoolHint.TextColor3 = Color3.fromRGB(100, 100, 130)
EditorPoolHint.Text = "Centang stat yang termasuk 'pool'. Dipakai oleh rule PoolAtLeast / PoolOnly."
EditorPoolHint.TextWrapped = true; EditorPoolHint.ZIndex = 31

local EditorPoolContainer = Instance.new("Frame", EditorScroll)
EditorPoolContainer.BackgroundTransparency = 1
EditorPoolContainer.AutomaticSize = Enum.AutomaticSize.Y
EditorPoolContainer.Size = UDim2.new(1, 0, 0, 0)
EditorPoolContainer.ZIndex = 31
local EditorPoolLayout = Instance.new("UIListLayout", EditorPoolContainer)
EditorPoolLayout.Padding = UDim.new(0, 3)

-- State for editor
local Draft        = nil
local EditingIndex = nil
local SlotModes    = {"Any", "Exact", "AtLeast"}
local SlotModeLabels = {Any="Any Total Slots", Exact="Exact N Slots", AtLeast="At Least N Slots"}

local function RefreshEditorRulesUI()
    -- Clear rules UI
    for _, c in ipairs(EditorRulesContainer:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    for RuleIdx, Rule in ipairs(Draft and Draft.Rules or {}) do
        local RuleRow = Instance.new("Frame", EditorRulesContainer)
        RuleRow.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
        RuleRow.BorderSizePixel  = 0
        RuleRow.Size             = UDim2.new(1, 0, 0, 56)
        RuleRow.ZIndex           = 31
        Instance.new("UICorner", RuleRow).CornerRadius = UDim.new(0, 5)

        local KindLabel = Instance.new("TextLabel", RuleRow)
        KindLabel.BackgroundTransparency = 1
        KindLabel.Position = UDim2.new(0, 4, 0, 2)
        KindLabel.Size     = UDim2.new(1, -50, 0, 18)
        KindLabel.Font     = Enum.Font.GothamMedium; KindLabel.TextSize = 10
        KindLabel.TextXAlignment = Enum.TextXAlignment.Left
        KindLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
        KindLabel.Text = "Rule "..tostring(RuleIdx)..": "
            ..(Rule.Kind=="PoolAtLeast" and "At Least N From Pool"
            or Rule.Kind=="PoolOnly"    and "Only From Pool"
            or                             "Require Stat")
        KindLabel.ZIndex = 32

        local DelBtn = Instance.new("TextButton", RuleRow)
        DelBtn.Size     = UDim2.fromOffset(38, 18)
        DelBtn.Position = UDim2.new(1, -42, 0, 2)
        DelBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
        DelBtn.BorderSizePixel = 0
        DelBtn.Font = Enum.Font.GothamMedium; DelBtn.TextSize = 9
        DelBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
        DelBtn.Text = "✕ DEL"; DelBtn.ZIndex = 32
        Instance.new("UICorner", DelBtn).CornerRadius = UDim.new(0, 4)
        local capturedRuleIdx = RuleIdx
        DelBtn.MouseButton1Click:Connect(function()
            table.remove(Draft.Rules, capturedRuleIdx)
            RefreshEditorRulesUI()
        end)

        -- MinCount or StatId detail
        local DetailBox = Instance.new("TextBox", RuleRow)
        DetailBox.BackgroundColor3 = Color3.fromRGB(14, 14, 24)
        DetailBox.BorderSizePixel = 0
        DetailBox.Position = UDim2.new(0, 4, 0, 24)
        DetailBox.Size     = UDim2.new(1, -8, 0, 24)
        DetailBox.Font     = Enum.Font.Gotham; DetailBox.TextSize = 10
        DetailBox.TextColor3 = Color3.fromRGB(200, 200, 220)
        DetailBox.ClearTextOnFocus = false
        DetailBox.ZIndex = 32
        Instance.new("UICorner", DetailBox).CornerRadius = UDim.new(0, 4)
        if Rule.Kind == "PoolOnly" then
            DetailBox.Text = "Only pool stats (no count needed)"
            DetailBox.TextEditable = false
        elseif Rule.Kind == "RequireStat" then
            DetailBox.PlaceholderText = "StatId (e.g. AtkBonus)"
            DetailBox.Text = tostring(Rule.StatId or "")
            DetailBox.FocusLost:Connect(function()
                Rule.StatId = DetailBox.Text ~= "" and DetailBox.Text or nil
            end)
        else -- PoolAtLeast
            DetailBox.PlaceholderText = "Min count (1-10)"
            DetailBox.Text = tostring(Rule.MinCount or 3)
            DetailBox.FocusLost:Connect(function()
                Rule.MinCount = math.floor(ClampNumber(DetailBox.Text, 1, 10, 3))
                DetailBox.Text = tostring(Rule.MinCount)
            end)
        end
    end
end

local function RefreshEditorPoolUI()
    for _, c in ipairs(EditorPoolContainer:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    if not Draft then return end
    -- Build stat list: always show defaults + discovered
    local StatCatalog = AutoForge.BuildStatCatalog()
    if #StatCatalog == 0 then
        for _, StatId in ipairs(AutoForge.GetDefaultPoolStats()) do
            table.insert(StatCatalog, {StatId=StatId, DisplayName=StatId})
        end
    end

    local PoolLookup = AutoForge.BuildPoolLookup(Draft.PoolStats)
    for _, Stat in ipairs(StatCatalog) do
        local Checked = PoolLookup[Stat.StatId] == true
        local PoolBtn = Instance.new("TextButton", EditorPoolContainer)
        PoolBtn.BackgroundColor3 = Checked and Color3.fromRGB(25,80,25) or Color3.fromRGB(22,22,35)
        PoolBtn.BorderSizePixel = 0
        PoolBtn.Size = UDim2.new(1, 0, 0, 22)
        PoolBtn.Font = Enum.Font.Gotham; PoolBtn.TextSize = 10
        PoolBtn.TextXAlignment = Enum.TextXAlignment.Left
        PoolBtn.TextColor3 = Checked and Color3.fromRGB(100,220,100) or Color3.fromRGB(160,160,190)
        PoolBtn.Text = "  "..(Checked and "[✓] " or "[ ] ")..Stat.DisplayName.." ("..Stat.StatId..")"
        PoolBtn.ZIndex = 32
        Instance.new("UICorner", PoolBtn).CornerRadius = UDim.new(0, 4)

        local capturedStat = Stat.StatId
        PoolBtn.MouseButton1Click:Connect(function()
            if not Draft then return end
            local NewPool = {}
            local Seen, Removed = {}, false
            for _, s in ipairs(Draft.PoolStats) do
                if s == capturedStat and not Removed then Removed=true
                elseif not Seen[s] then Seen[s]=true; table.insert(NewPool, s) end
            end
            if not Removed then table.insert(NewPool, capturedStat) end
            Draft.PoolStats = NewPool
            RefreshEditorPoolUI()
        end)
    end
end

OpenTargetEditor = function(Profile, Index)
    Draft        = CopyProfile(Profile)
    EditingIndex = Index
    EditorNameBox.Text = Draft.Name or ""
    EditorSlotModeBtn.Text = "  TOTAL SLOTS: "..(SlotModeLabels[Draft.SlotMode] or "Any Total Slots").." ▼"
    EditorSlotCountBox.Text = tostring(Draft.SlotCount or 1)
    EditorErrorLabel.Text = ""
    RefreshEditorRulesUI()
    RefreshEditorPoolUI()
    EditorOverlay.Visible = true
end

EditorSlotModeBtn.MouseButton1Click:Connect(function()
    if not Draft then return end
    local Modes = {
        {k="Any",     l="Any Total Slots"},
        {k="Exact",   l="Exact N Slots"},
        {k="AtLeast", l="At Least N Slots"},
    }
    local Current = Draft.SlotMode
    for Idx, M in ipairs(Modes) do
        if M.k == Current then
            local Next = Modes[(Idx % #Modes) + 1]
            Draft.SlotMode = Next.k
            EditorSlotModeBtn.Text = "  TOTAL SLOTS: "..Next.l.." ▼"
            EditorSlotCountBox.Text = tostring(Draft.SlotCount or 1)
            break
        end
    end
end)

EditorSlotCountBox.FocusLost:Connect(function()
    if Draft then
        Draft.SlotCount = math.floor(ClampNumber(EditorSlotCountBox.Text, 1, 10, 1))
        EditorSlotCountBox.Text = tostring(Draft.SlotCount)
    end
end)

EditorAddRuleBtn.MouseButton1Click:Connect(function()
    if Draft then
        table.insert(Draft.Rules, {Kind="PoolAtLeast", MinCount=3})
        RefreshEditorRulesUI()
    end
end)

EditorSaveBtn.MouseButton1Click:Connect(function()
    if not Draft then return end
    Draft.Name = EditorNameBox.Text ~= "" and EditorNameBox.Text or "Target Profile"
    Draft.SlotCount = math.floor(ClampNumber(EditorSlotCountBox.Text, 1, 10, 1))

    local Normalized = AutoForge.NormalizeProfile(Draft, EditingIndex or (#AutoForge.Profiles + 1))
    local Valid, Err = AutoForge.ValidateProfile(Normalized)
    if not Valid then
        EditorErrorLabel.Text = "⚠ "..tostring(Err)
        return
    end
    EditorErrorLabel.Text = ""
    if EditingIndex then
        AutoForge.Profiles[EditingIndex] = Normalized
    else
        table.insert(AutoForge.Profiles, Normalized)
    end
    EngineConfig.AutoForgeProfiles = AutoForge.Profiles
    AutoForge.SaveToEngineConfig()
    EditorOverlay.Visible = false
    RefreshProfileList()
end)

-- Profile list builder
RefreshProfileList = function()
    for _, c in ipairs(ProfileScroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end

    if #AutoForge.Profiles == 0 then
        local EmptyLbl = Instance.new("TextLabel", ProfileScroll)
        EmptyLbl.BackgroundTransparency = 1
        EmptyLbl.Size = UDim2.new(1,-4,0,34)
        EmptyLbl.Font = Enum.Font.Gotham; EmptyLbl.TextSize = 10
        EmptyLbl.TextColor3 = Color3.fromRGB(80,80,100)
        EmptyLbl.TextWrapped = true
        EmptyLbl.Text = "Belum ada profil. Klik ➕ Add Target Profile."
        return
    end

    for Idx, Profile in ipairs(AutoForge.Profiles) do
        local Row = Instance.new("Frame", ProfileScroll)
        Row.BackgroundColor3 = Profile.Enabled and Color3.fromRGB(20,40,20) or Color3.fromRGB(20,20,35)
        Row.BorderSizePixel = 0
        Row.Size = UDim2.new(1,-4,0,68)
        Row.LayoutOrder = Idx
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 6)

        local NameLbl = Instance.new("TextLabel", Row)
        NameLbl.BackgroundTransparency = 1
        NameLbl.Position = UDim2.new(0,8,0,4); NameLbl.Size = UDim2.new(1,-80,0,20)
        NameLbl.Font = Enum.Font.GothamBold; NameLbl.TextSize = 11
        NameLbl.TextXAlignment = Enum.TextXAlignment.Left
        NameLbl.TextColor3 = Profile.Enabled and Color3.fromRGB(100,220,100) or Color3.fromRGB(180,180,210)
        NameLbl.Text = Profile.Name or "Unnamed"

        local StatusBadge = Instance.new("TextLabel", Row)
        StatusBadge.BackgroundTransparency = 1
        StatusBadge.Position = UDim2.new(1,-70,0,4); StatusBadge.Size = UDim2.fromOffset(66,20)
        StatusBadge.Font = Enum.Font.GothamMedium; StatusBadge.TextSize = 9
        StatusBadge.TextXAlignment = Enum.TextXAlignment.Right
        StatusBadge.TextColor3 = Profile.Enabled and Color3.fromRGB(80,200,80) or Color3.fromRGB(120,120,150)
        StatusBadge.Text = Profile.ValidationError and "⚠ INVALID" or (Profile.Enabled and "✓ ON" or "○ OFF")

        local SummaryLbl = Instance.new("TextLabel", Row)
        SummaryLbl.BackgroundTransparency = 1
        SummaryLbl.Position = UDim2.new(0,8,0,22); SummaryLbl.Size = UDim2.new(1,-16,0,18)
        SummaryLbl.Font = Enum.Font.Gotham; SummaryLbl.TextSize = 9
        SummaryLbl.TextXAlignment = Enum.TextXAlignment.Left
        SummaryLbl.TextColor3 = Color3.fromRGB(100,100,130)
        SummaryLbl.Text = Profile.ValidationError or AutoForge.BuildProfileSummary(Profile)
        SummaryLbl.TextTruncate = Enum.TextTruncate.AtEnd

        -- Action buttons row
        local BtnRow = Instance.new("Frame", Row)
        BtnRow.BackgroundTransparency = 1
        BtnRow.Position = UDim2.new(0,4,0,42); BtnRow.Size = UDim2.new(1,-8,0,22)

        local function MakeSmallBtn(Label, X, W, Color)
            local B = Instance.new("TextButton", BtnRow)
            B.Size = UDim2.new(0,W,1,0); B.Position = UDim2.new(0,X,0,0)
            B.BackgroundColor3 = Color or Color3.fromRGB(28,28,48)
            B.BorderSizePixel = 0; B.Font = Enum.Font.GothamMedium; B.TextSize = 9
            B.TextColor3 = Color3.fromRGB(200,200,220); B.Text = Label
            Instance.new("UICorner", B).CornerRadius = UDim.new(0,4)
            return B
        end

        local Valid = AutoForge.ValidateProfile(Profile)
        local ToggleColor = Profile.Enabled and Color3.fromRGB(40,80,40) or Color3.fromRGB(28,28,48)
        local EnableBtn = MakeSmallBtn(Profile.Enabled and "✓ ON" or "○ OFF", 0, 52, ToggleColor)
        local EditBtn   = MakeSmallBtn("✏ EDIT",  56, 52)
        local CopyBtn   = MakeSmallBtn("⊕ COPY", 112, 52)
        local DelBtn    = MakeSmallBtn("✕ DEL",   168, 52, Color3.fromRGB(60,20,20))
        DelBtn.TextColor3 = Color3.fromRGB(220, 120, 120)

        local capturedIdx = Idx
        EnableBtn.MouseButton1Click:Connect(function()
            if Valid then
                Profile.Enabled = not Profile.Enabled
            else
                Profile.Enabled = false
            end
            EngineConfig.AutoForgeProfiles = AutoForge.Profiles
            AutoForge.SaveToEngineConfig()
            RefreshProfileList()
        end)
        EditBtn.MouseButton1Click:Connect(function()
            OpenTargetEditor(Profile, capturedIdx)
        end)
        CopyBtn.MouseButton1Click:Connect(function()
            local Copy = CopyProfile(Profile)
            Copy.Id      = HttpService:GenerateGUID(false)
            Copy.Name    = Copy.Name.." Copy"
            Copy.Enabled = false
            local N = AutoForge.NormalizeProfile(Copy, #AutoForge.Profiles+1)
            table.insert(AutoForge.Profiles, N)
            EngineConfig.AutoForgeProfiles = AutoForge.Profiles
            AutoForge.SaveToEngineConfig()
            RefreshProfileList()
        end)
        DelBtn.MouseButton1Click:Connect(function()
            table.remove(AutoForge.Profiles, capturedIdx)
            EngineConfig.AutoForgeProfiles = AutoForge.Profiles
            AutoForge.SaveToEngineConfig()
            RefreshProfileList()
        end)
    end
end

AutoForge.TargetRefresh = function()
    local Data = AutoForge.TargetFoundData
    if Data then
        TargetFoundFrame.Visible = true
        TargetFoundLabel.Text = "🎯 FOUND! ["..tostring(Data.ProfileName).."] — "..tostring(Data.ItemId)
            .." (Attempt "..tostring(Data.Attempt)..")"
    end
    RefreshProfileList()
end

RefreshProfileList()

-- ── Initial ore rows load ──────────────────────────────────────────────────────
H.RebuildForgeOreUI = RebuildOreRows
H.RefreshForgeProfileList = RefreshProfileList
