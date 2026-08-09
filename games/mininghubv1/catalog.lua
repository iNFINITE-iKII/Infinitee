--------------------------------------------------------------------------------
-- Mining Hub V1 — live catalog reader
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub
local ReplicatedStorage = Hub.Services.ReplicatedStorage

local function getLiveModuleData(path)
    local current = ReplicatedStorage

    for segment in string.gmatch(path, "[^%.]+") do
        current = current:FindFirstChild(segment)
        if not current then
            return nil
        end
    end

    if current and current:IsA("ModuleScript") then
        local ok, result = pcall(require, current)
        if ok and type(result) == "table" then
            return result
        end
    end

    return nil
end

local function getFormattedPickaxes()
    local data = getLiveModuleData("Modules.Shop.ShopCatalog")
    local options = {}
    local idMap = {}

    if data and data.Pickaxes then
        for _, item in pairs(data.Pickaxes) do
            local rawId = item.id or item.name or "Unknown"
            local cleanId = string.gsub(tostring(rawId), "%s+", "")
            local name = item.name or "Unknown"
            local price = item.price or 0
            local digPower = (item.stats and item.stats.DigPower) or 0
            local tier = (item.stats and item.stats.MaterialTier) or 0
            local rarityRank = (data.PickaxeRarityRank and data.PickaxeRarityRank[cleanId]) or 1

            if not data.PickaxeRarityRank or not data.PickaxeRarityRank[cleanId] then
                rarityRank = (data.PickaxeRarityRank and data.PickaxeRarityRank[name]) or 1
            end

            local rarityName = (data.RarityNames and data.RarityNames[rarityRank]) or "Common"
            local display = string.format(
                "%s - $%s\n%s | Power: %s | Tier: %s",
                name,
                tostring(price),
                rarityName,
                tostring(digPower),
                tostring(tier)
            )

            table.insert(options, display)
            idMap[display] = cleanId
        end
    else
        local fallback = "Singularity - $2500000000000\nInfinity | Power: 10.5 | Tier: 3"
        options = {fallback}
        idMap[fallback] = "Singularity"
    end

    return options, idMap
end

local function getFormattedBombs()
    local data = getLiveModuleData("Modules.BombMaterials")
    local options = {}
    local idMap = {}

    if data and data.BY_MATERIAL then
        for _, item in pairs(data.BY_MATERIAL) do
            local name = item.bombName or "Unknown"
            local id = item.bombId
            local rarity = item.rarity or "Common"
            local materialName = item.matName or "Unknown"

            if id then
                local cleanId = string.gsub(tostring(id), "%s+", "")
                local display = string.format("%s\n%s | Mat: %s", name, rarity, materialName)
                table.insert(options, display)
                idMap[display] = cleanId
            end
        end
    else
        local fallback = "Classic Bomb\nCommon | Mat: Gunpowder Stone"
        options = {fallback}
        idMap[fallback] = "ClassicBomb"
    end

    return options, idMap
end

local function getFormattedRadars()
    local data = getLiveModuleData("Modules.RadarShopConfig")
    local options = {}
    local idMap = {}

    if data and data.RADARS then
        for id, item in pairs(data.RADARS) do
            local cleanId = string.gsub(tostring(id), "%s+", "")
            local name = item.displayName or "Unknown"
            local price = item.cashPrice or 0
            local rarity = item.rarity or "Common"
            local duration = item.durationSeconds or 0
            local display = string.format(
                "%s - $%s\n%s | Duration: %ss",
                name,
                tostring(price),
                rarity,
                tostring(duration)
            )

            table.insert(options, display)
            idMap[display] = cleanId
        end
    else
        local fallback = "Crystal Radar - $300000\nCommon | Duration: 45s"
        options = {fallback}
        idMap[fallback] = "CrystalRadar"
    end

    return options, idMap
end

local pickaxeOptions, pickaxeMap = getFormattedPickaxes()
local bombOptions, bombMap = getFormattedBombs()
local radarOptions, radarMap = getFormattedRadars()

Hub.Data.Pickaxes = {Options = pickaxeOptions, Map = pickaxeMap}
Hub.Data.Bombs = {Options = bombOptions, Map = bombMap}
Hub.Data.Radars = {Options = radarOptions, Map = radarMap}
Hub.Functions.GetLiveModuleData = getLiveModuleData