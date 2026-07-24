--------------------------------------------------------------------------------
--// npc_scanner.lua — Iron Soul NPC ProximityPrompt Scanner
-- Jalankan script ini terpisah di executor untuk mendapatkan daftar semua
-- NPC / ProximityPrompt yang ada di dunia saat ini.
-- Output di console / dev console Roblox.
--
-- Cara pakai:
--   1. Masuk ke dalam game Iron Soul (pastikan sudah berada di World, bukan Lobby)
--   2. Jalankan script ini via executor
--   3. Buka Dev Console (F9 atau Shift+F9) → tab Output
--   4. Salin hasil "=== NPC SCAN RESULT ===" dan kirimkan ke developer
--------------------------------------------------------------------------------

local Workspace    = game:GetService("Workspace")
local LocalPlayer  = game.Players.LocalPlayer

-- Helper: dapatkan path lengkap dari object ke root
local function getPath(obj)
    local parts = {}
    local cur = obj
    while cur and cur ~= game do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return table.concat(parts, " > ")
end

-- Helper: jarak dari HRP ke object
local function distanceTo(part)
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp and part:IsA("BasePart") then
        return math.floor((hrp.Position - part.Position).Magnitude)
    end
    return -1
end

print("\n========================================")
print("  [NPC SCANNER] Memulai scan...")
print("  Dunia : " .. tostring(Workspace:GetAttribute("WorldName") or Workspace.Name))
print("  Player: " .. LocalPlayer.Name)
print("========================================\n")

local results = {}
local seen    = {}

for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("ProximityPrompt") then
        local parent = obj.Parent
        if parent then
            local key = parent:GetFullName()
            if not seen[key] then
                seen[key] = true

                local objText    = tostring(obj.ObjectText or ""):gsub("%s+", " ")
                local actionText = tostring(obj.ActionText or ""):gsub("%s+", " ")
                local parentName = parent.Name
                local path       = getPath(parent)
                local dist       = distanceTo(parent)
                local pos        = parent:IsA("BasePart")
                    and string.format("(%.1f, %.1f, %.1f)", parent.Position.X, parent.Position.Y, parent.Position.Z)
                    or  "N/A"

                table.insert(results, {
                    parentName = parentName,
                    objText    = objText,
                    actionText = actionText,
                    path       = path,
                    pos        = pos,
                    dist       = dist,
                })
            end
        end
    end
end

-- Urutkan berdasarkan jarak (terdekat dulu)
table.sort(results, function(a, b)
    if a.dist < 0 then return false end
    if b.dist < 0 then return true  end
    return a.dist < b.dist
end)

print("=== NPC SCAN RESULT (" .. #results .. " ProximityPrompt ditemukan) ===\n")

for i, r in ipairs(results) do
    print(string.format(
        "[%02d] Nama    : %s",
        i, r.parentName
    ))
    print(string.format(
        "     ObjectText  : %s",
        r.objText ~= "" and r.objText or "(kosong)"
    ))
    print(string.format(
        "     ActionText  : %s",
        r.actionText ~= "" and r.actionText or "(kosong)"
    ))
    print(string.format(
        "     Posisi      : %s  |  Jarak: %s stud",
        r.pos,
        r.dist >= 0 and tostring(r.dist) or "?"
    ))
    print(string.format(
        "     Path        : %s",
        r.path
    ))
    print("")
end

print("=== SELESAI. Salin hasil di atas dan kirim ke developer. ===\n")

-- Juga cetak ringkasan keyword yang terdeteksi untuk saran button baru
print("=== KEYWORD TERDETEKSI (untuk tab NPC) ===")
local keywordHits = {}
local checkwords = {
    "forge","craft","enchant","grocery","grocer","pet","expedition",
    "bless","blessing","guide","merchant","shop","blacksmith","armo",
    "weapon","rank","race","quest","dungeon","altar","shrine","bond",
    "season","potion","material","upgrade","station","hub","npc",
    "vendor","trader","booth","stall","repair","identify","reroll",
}
for _, r in ipairs(results) do
    local combined = (r.parentName .. " " .. r.objText .. " " .. r.actionText):lower()
    for _, kw in ipairs(checkwords) do
        if combined:find(kw) then
            if not keywordHits[kw] then keywordHits[kw] = {} end
            table.insert(keywordHits[kw], r.parentName)
        end
    end
end
for kw, names in pairs(keywordHits) do
    print(string.format("  keyword %-12s → %s", '"'..kw..'"', table.concat(names, ", ")))
end
print("==========================================\n")
