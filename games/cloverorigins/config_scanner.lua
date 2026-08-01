--------------------------------------------------------------------------------
--// config_scanner.lua — Clover Origins
--// Scanner aman untuk konfigurasi Res* di ReplicatedStorage.
--
--// Scanner ini:
--//   1. mencatat semua object Res* beserta path dan class-nya;
--//   2. hanya me-require ModuleScript yang masuk whitelist;
--//   3. menyimpan error per module tanpa menghentikan script utama.
--
--// Scanner ini TIDAK:
--//   - memanggil RemoteEvent/RemoteFunction;
--//   - mengubah inventory, player, atau konfigurasi game;
--//   - menganggap semua Res* sebagai ModuleScript.
--------------------------------------------------------------------------------
local H = getgenv().Hub

local Services = H.Services
local ReplicatedStorage = Services.ReplicatedStorage

local ConfigScanner = {}

-- Mulai dari config yang paling relevan dan formatnya paling berguna untuk
-- reader/farm. Tambahkan nama baru setelah formatnya diverifikasi.
local MODULE_WHITELIST = {
    ResEnemy       = true,
    ResDropLoot    = true,
    ResChestLoot   = true,
    ResDragonEggLoot = true,
    ResOres        = true,
    ResWeapon      = true,
    ResArmor       = true,
    ResSkill       = true,
}

local function getFullName(instance)
    local ok, result = pcall(function()
        return instance:GetFullName()
    end)
    return ok and result or instance.Name
end

local function isResConfig(instance)
    return type(instance.Name) == "string"
       and instance.Name:match("^Res[%w_%-]*$") ~= nil
end

local function valueType(value)
    local ok, result = pcall(function()
        return typeof(value)
    end)
    return ok and result or type(value)
end

local function makeRegistry()
    return {
        LastScan = 0,
        Root = nil,
        Objects = {},
        Modules = {},
        Folders = {},
        Packages = {},
        Errors = {},
        ByName = {},
    }
end

local function addError(registry, name, path, message)
    table.insert(registry.Errors, {
        Name = name,
        Path = path,
        Error = tostring(message),
    })
end

local function readWhitelistedModule(instance, record, registry)
    if not MODULE_WHITELIST[instance.Name] then
        record.Read = false
        record.ReadReason = "not_whitelisted"
        return
    end

    local ok, result = pcall(require, instance)
    record.Read = ok
    if not ok then
        record.ReadReason = "require_failed"
        addError(registry, instance.Name, record.Path, result)
        return
    end

    record.ReadReason = "ok"
    record.ValueType = valueType(result)
    record.Value = result
end

function ConfigScanner.Scan()
    local registry = makeRegistry()
    registry.Root = getFullName(ReplicatedStorage)

    local ok, descendants = pcall(function()
        return ReplicatedStorage:GetDescendants()
    end)
    if not ok then
        addError(registry, "ReplicatedStorage", registry.Root, descendants)
        H.ConfigRegistry = registry
        return registry
    end

    for _, instance in ipairs(descendants) do
        if isResConfig(instance) then
            local path = getFullName(instance)
            local record = {
                Name = instance.Name,
                Path = path,
                ClassName = instance.ClassName,
                ChildCount = #instance:GetChildren(),
            }

            table.insert(registry.Objects, record)
            registry.ByName[instance.Name] = record

            if instance:IsA("ModuleScript") then
                table.insert(registry.Modules, record)
                readWhitelistedModule(instance, record, registry)
            elseif instance:IsA("Folder") then
                table.insert(registry.Folders, record)
                record.Read = false
                record.ReadReason = "folder"
            elseif instance.ClassName == "PackageLink" then
                table.insert(registry.Packages, record)
                record.Read = false
                record.ReadReason = "package_link"
            else
                record.Read = false
                record.ReadReason = "unsupported_class"
            end
        end
    end

    table.sort(registry.Objects, function(a, b)
        return a.Path < b.Path
    end)
    table.sort(registry.Errors, function(a, b)
        return a.Path < b.Path
    end)
    registry.LastScan = os.time()

    H.ConfigRegistry = registry
    return registry
end

function ConfigScanner.Get(name)
    local registry = H.ConfigRegistry
    local record = registry and registry.ByName[name]
    return record and record.Value or nil
end

function ConfigScanner.GetRecord(name)
    local registry = H.ConfigRegistry
    return registry and registry.ByName[name] or nil
end

function ConfigScanner.GetSummary()
    local registry = H.ConfigRegistry or makeRegistry()
    return {
        Objects = #registry.Objects,
        Modules = #registry.Modules,
        Folders = #registry.Folders,
        Packages = #registry.Packages,
        Readable = (function()
            local count = 0
            for _, record in ipairs(registry.Modules) do
                if record.Read then count = count + 1 end
            end
            return count
        end)(),
        Errors = #registry.Errors,
    }
end

H.ConfigScanner = ConfigScanner
H.ConfigRegistry = makeRegistry()
H.ScanConfigs = ConfigScanner.Scan

-- Scan awal dilakukan sebelum modul Farm/UI dimuat, sehingga modul lain dapat
-- membaca H.ConfigRegistry tanpa menunggu tombol UI ditekan.
ConfigScanner.Scan()