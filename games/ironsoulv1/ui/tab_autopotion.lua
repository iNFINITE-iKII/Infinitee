--------------------------------------------------------------------------------
--// ui/tab_autopotion.lua — Tab: Auto Potion
-- Menampilkan daftar buff potion yang bisa dipilih user untuk dipakai otomatis.
-- Bergantung pada auto_potion.lua yang sudah di-load lebih dulu.
--------------------------------------------------------------------------------
local H            = getgenv().Hub
local EngineConfig = H.EngineConfig
local AutoPotion   = H.AutoPotion
local CustomNotify = H.CustomNotify
local CreateTab      = H.CreateTab
local CreateSection  = H.CreateSection
local CreateToggleUI = H.CreateToggleUI
local CreateButton   = H.CreateButton
local GetThemeColor          = H.GetThemeColor
local RegisterThemeElement   = H.RegisterThemeElement

-- ── Tab ───────────────────────────────────────────────────────────────────────
local PotionPage = CreateTab("🧪 Auto Potion", "tabPotion")
CreateSection(PotionPage, "Auto Potion Control", "secPotionCtrl")

-- ── Status bar ────────────────────────────────────────────────────────────────
local StatusFrame = Instance.new("Frame", PotionPage)
StatusFrame.BackgroundColor3    = Color3.fromRGB(18, 18, 28)
StatusFrame.BorderSizePixel     = 0
StatusFrame.Size                = UDim2.new(1, -10, 0, 28)
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
StatusLabel.Text           = "Status: OFF"

local function UpdateStatusUI()
    local st = AutoPotion.Status or "OFF"
    StatusLabel.Text = "Status: " .. st
    if st == "OFF" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(80,  80,  100)
        StatusLabel.TextColor3     = Color3.fromRGB(120, 120, 140)
    elseif st == "READY" or st:sub(1,5) == "READY" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(60,  200, 100)
        StatusLabel.TextColor3     = Color3.fromRGB(60,  200, 100)
    elseif st:sub(1,6) == "ACTIVE" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(80,  180, 255)
        StatusLabel.TextColor3     = Color3.fromRGB(80,  180, 255)
    elseif st:sub(1,7) == "BLOCKED" or st:sub(1,5) == "GRACE" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(220, 160, 40)
        StatusLabel.TextColor3     = Color3.fromRGB(220, 160, 40)
    elseif st:sub(1,7) == "TIMEOUT" then
        StatusDot.BackgroundColor3 = Color3.fromRGB(220, 60,  60)
        StatusLabel.TextColor3     = Color3.fromRGB(220, 80,  80)
    else
        StatusDot.BackgroundColor3 = Color3.fromRGB(180, 160, 255)
        StatusLabel.TextColor3     = Color3.fromRGB(180, 160, 255)
    end
end

-- Sambungkan ke engine — dipanggil setiap kali Status berubah
AutoPotion.Refresh = UpdateStatusUI

-- ── Master toggle ─────────────────────────────────────────────────────────────
_G.AutoPotionToggle = CreateToggleUI(PotionPage, "🧪 Enable Auto Potion",
    EngineConfig.AutoPotionActive,
    function(v)
        if v then
            local anySelected = false
            for _ in pairs(AutoPotion.Selected) do anySelected = true; break end
            if not anySelected then
                CustomNotify("AUTO POTION", "Pilih minimal 1 potion dulu!", 3)
                EngineConfig.AutoPotionActive = false
                _G.AutoPotionToggle:SetValue(false)
                return
            end
            AutoPotion.SetEnabled(true)
            CustomNotify("🧪 AUTO POTION", "Aktif! Memantau buff...", 3)
        else
            AutoPotion.SetEnabled(false)
            CustomNotify("🧪 AUTO POTION", "Dimatikan.", 2)
        end
    end,
    "lblAutoPotion"
)

-- ── Potion list ───────────────────────────────────────────────────────────────
CreateSection(PotionPage, "Buff Potions", "secPotionList")

-- Forward-declare RebuildPotionUI agar bisa direferensikan di CreateButton
local RebuildPotionUI

CreateButton(PotionPage, "🔄 Refresh Potion List", function()
    AutoPotion.BuildCatalog(true)
    task.spawn(RebuildPotionUI)
    CustomNotify("AUTO POTION", "List di-refresh!", 2)
end, "btnRefreshPotion")

-- ScrollingFrame untuk daftar potion
local PotionScroll = Instance.new("ScrollingFrame", PotionPage)
PotionScroll.Name                   = "PotionScroll"
PotionScroll.BackgroundTransparency = 1
PotionScroll.Size                   = UDim2.new(1, -10, 0, 220)
PotionScroll.ScrollBarThickness     = 3
PotionScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
if GetThemeColor then
    PotionScroll.ScrollBarImageColor3 = GetThemeColor("Primary")
end

local PotionLayout = Instance.new("UIListLayout", PotionScroll)
PotionLayout.Padding   = UDim.new(0, 4)
PotionLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Warna background berdasarkan state potion
local STATE_BG = {
    Active          = Color3.fromRGB(25, 80, 145),   -- biru (buff aktif)
    Pending         = Color3.fromRGB(90, 65, 15),    -- kuning (sedang di-queue)
    Inactive        = Color3.fromRGB(28, 28, 42),    -- default
    ["Out of Stock"] = Color3.fromRGB(50, 20, 20),   -- merah gelap
    Unavailable     = Color3.fromRGB(22, 22, 30),
}

-- Refs UI per potion untuk update real-time
local PotionButtonRefs = {}  -- PotionId → { Btn, OwnedBadge }

-- Bangun ulang list dari catalog saat ini
RebuildPotionUI = function()
    -- Bersihkan tombol lama
    for _, child in ipairs(PotionScroll:GetChildren()) do
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    table.clear(PotionButtonRefs)

    local Order   = AutoPotion.Order
    local Catalog = AutoPotion.Catalog

    if #Order == 0 then
        local EmptyLbl = Instance.new("TextLabel", PotionScroll)
        EmptyLbl.BackgroundTransparency = 1
        EmptyLbl.Size         = UDim2.new(1, -10, 0, 34)
        EmptyLbl.Font         = Enum.Font.Gotham
        EmptyLbl.TextSize     = 11
        EmptyLbl.TextColor3   = Color3.fromRGB(80, 80, 100)
        EmptyLbl.Text         = "Tidak ada potion buff. Klik Refresh."
        EmptyLbl.TextWrapped  = true
        return
    end

    for idx, PotionId in ipairs(Order) do
        local Entry      = Catalog[PotionId]
        local isSelected = AutoPotion.Selected[PotionId] == true
        local State      = AutoPotion.GetEntryState(Entry)

        -- Row: tombol kiri + badge stok kanan
        local Row = Instance.new("Frame", PotionScroll)
        Row.BackgroundTransparency = 1
        Row.Size        = UDim2.new(1, -6, 0, 32)
        Row.LayoutOrder = idx

        local Btn = Instance.new("TextButton", Row)
        Btn.Size             = UDim2.new(1, -62, 1, 0)
        Btn.Font             = Enum.Font.GothamMedium
        Btn.TextSize         = 11
        Btn.TextXAlignment   = Enum.TextXAlignment.Left
        Btn.BorderSizePixel  = 0
        Btn.Text             = "  🧪 " .. (Entry.DisplayName or PotionId)
        Btn.TextColor3       = Color3.fromRGB(220, 220, 230)
        Btn.BackgroundColor3 = isSelected
            and Color3.fromRGB(30, 100, 55)
            or  (STATE_BG[State] or STATE_BG.Inactive)
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

        local OwnedBadge = Instance.new("TextLabel", Row)
        OwnedBadge.Size           = UDim2.new(0, 58, 1, 0)
        OwnedBadge.Position       = UDim2.new(1, -58, 0, 0)
        OwnedBadge.BackgroundTransparency = 1
        OwnedBadge.Font           = Enum.Font.Gotham
        OwnedBadge.TextSize       = 10
        OwnedBadge.TextXAlignment = Enum.TextXAlignment.Right
        OwnedBadge.TextColor3     = (Entry.Owned or 0) <= 0
            and Color3.fromRGB(200, 70, 70)
            or  Color3.fromRGB(100, 180, 100)
        OwnedBadge.Text = tostring(Entry.Owned or 0) .. " stok"

        PotionButtonRefs[PotionId] = { Btn = Btn, OwnedBadge = OwnedBadge }

        -- Klik: toggle pilih / batal
        local capturedId = PotionId
        Btn.MouseButton1Click:Connect(function()
            if AutoPotion.Selected[capturedId] then
                AutoPotion.Selected[capturedId]              = nil
                EngineConfig.AutoPotionSelected[capturedId]  = nil
                Btn.BackgroundColor3 = STATE_BG.Inactive
            else
                AutoPotion.Selected[capturedId]              = true
                EngineConfig.AutoPotionSelected[capturedId]  = true
                Btn.BackgroundColor3 = Color3.fromRGB(30, 100, 55)
                -- Langsung evaluate jika engine sudah aktif
                if EngineConfig.AutoPotionActive then
                    task.spawn(function()
                        AutoPotion.RebuildSignals()
                        AutoPotion.EvaluatePotion(capturedId)
                    end)
                end
            end
        end)
    end
end

-- ── Polling update state per-potion (setiap 2 detik) ─────────────────────────
task.spawn(function()
    while true do
        task.wait(2)
        for PotionId, refs in pairs(PotionButtonRefs) do
            local Entry = AutoPotion.Catalog[PotionId]
            if Entry and refs.Btn and refs.Btn.Parent then
                local State      = AutoPotion.GetEntryState(Entry)
                local isSelected = AutoPotion.Selected[PotionId] == true
                if isSelected then
                    refs.Btn.BackgroundColor3 = (State == "Active")
                        and STATE_BG.Active
                        or  Color3.fromRGB(30, 100, 55)
                else
                    refs.Btn.BackgroundColor3 = STATE_BG[State] or STATE_BG.Inactive
                end
                refs.OwnedBadge.Text = tostring(Entry.Owned or 0) .. " stok"
                refs.OwnedBadge.TextColor3 = (Entry.Owned or 0) <= 0
                    and Color3.fromRGB(200, 70, 70)
                    or  Color3.fromRGB(100, 180, 100)
            end
        end
        UpdateStatusUI()
    end
end)

-- Build catalog & list saat modul pertama kali dimuat.
-- Retry hingga 5x (jeda 2 detik) karena Framework Roblox mungkin
-- belum siap saat task.defer pertama kali berjalan.
task.defer(function()
    local retries = 0
    repeat
        AutoPotion.BuildCatalog(true)
        if #AutoPotion.Order == 0 then
            task.wait(2)
            retries = retries + 1
        end
    until #AutoPotion.Order > 0 or retries >= 5
    RebuildPotionUI()
end)

-- Ekspor RebuildPotionUI ke Hub agar SyncAllVisualUI bisa
-- memanggil ulang setelah profil di-load (restore checkmark).
H.RebuildPotionUI = RebuildPotionUI

--------------------------------------------------------------------------------
