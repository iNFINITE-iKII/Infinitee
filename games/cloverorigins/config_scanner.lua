--------------------------------------------------------------------------------
--// config_scanner.lua — Clover Origins
--// Scanner untuk seluruh isi ReplicatedStorage.Configs.
--
--// Scanner ini:
--//   1. mencatat semua object di dalam Configs beserta path dan class-nya;
--//   2. membaca semua ModuleScript di dalam Configs dengan pcall;
--//   3. menyimpan error per module tanpa menghentikan script utama.
--
--// Scanner ini TIDAK:
--//   - memanggil RemoteEvent/RemoteFunction;
--//   - mengubah inventory, player, atau konfigurasi game;
--//   - membaca object di luar ReplicatedStorage.Configs.
--------------------------------------------------------------------------------
local H = getgenv().Hub

local Services = H.Services
local ReplicatedStorage = Services.ReplicatedStorage

local ConfigScanner = {}

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

local function formatKey(key)
    if type(key) == "string" and key:match("^[%a_][%w_]*$") then
        return key
    end
    return "[" .. tostring(key) .. "]"
end

local function appendValueLines(value, indent, depth, seen, lines, budget, maxDepth)
    if budget.count >= budget.maxEntries then
        table.insert(lines, indent .. "... output dibatasi oleh MaxEntries")
        return
    end

    if type(value) ~= "table" then
        table.insert(lines, indent .. tostring(value))
        budget.count = budget.count + 1
        return
    end

    if seen[value] then
        table.insert(lines, indent .. "<cycle>")
        return
    end

    if depth >= maxDepth then
        table.insert(lines, indent .. "<table depth limit>")
        return
    end

    seen[value] = true
    table.insert(lines, indent .. "{")

    local keys = {}
    for key in pairs(value) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    for _, key in ipairs(keys) do
        if budget.count >= budget.maxEntries then
            table.insert(lines, indent .. "  ... output dibatasi oleh MaxEntries")
            break
        end

        local childLines = {}
        table.insert(childLines, indent .. "  " .. formatKey(key) .. " = ")
        appendValueLines(
            value[key],
            indent .. "    ",
            depth + 1,
            seen,
            childLines,
            budget,
            maxDepth
        )
        for _, line in ipairs(childLines) do
            table.insert(lines, line)
        end
    end

    table.insert(lines, indent .. "}")
end

local function printRegistry(registry, options)
    options = options or {}
    if options.Print == false then return end

    local maxDepth = tonumber(options.MaxDepth) or 6
    local maxEntries = tonumber(options.MaxEntries) or 10000
    local budget = { count = 0, maxEntries = maxEntries }

    print("\n========== [XiFil-CO CONFIG SCAN] ==========")
    print("Root: " .. tostring(registry.Root))
    print(string.format(
        "Objects: %d | Modules: %d | Readable: %d | Errors: %d",
        #registry.Objects,
        #registry.Modules,
        registry.Readable or 0,
        #registry.Errors
    ))

    if #registry.Objects == 0 then
        print("Tidak ada object di ReplicatedStorage.Configs.")
    end

    for index, record in ipairs(registry.Objects) do
        print(string.format(
            "[%03d] %s | %s | children=%d | %s",
            index,
            record.Path,
            record.ClassName,
            record.ChildCount,
            record.ReadReason or "not_read"
        ))

        if record.Value ~= nil then
            local lines = {}
            appendValueLines(
                record.Value,
                "  ",
                0,
                {},
                lines,
                budget,
                maxDepth
            )
            for _, line in ipairs(lines) do
                print("      " .. line)
            end
        end
    end

    for _, errorRecord in ipairs(registry.Errors) do
        print(string.format(
            "[ERROR] %s | %s",
            errorRecord.Path,
            errorRecord.Error
        ))
    end

    print(string.format(
        "========== [SCAN SELESAI | %d/%d value entries] ==========\n",
        budget.count,
        maxEntries
    ))
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
        Readable = 0,
    }
end

local function addError(registry, name, path, message)
    table.insert(registry.Errors, {
        Name = name,
        Path = path,
        Error = tostring(message),
    })
end

local function readModule(instance, record, registry)
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

function ConfigScanner.Scan(options)
    options = options or {}
    -- Default true: baca semua ModuleScript di dalam Configs. Set ReadModules=false jika
    -- hanya ingin daftar metadata tanpa menjalankan require pada module.
    local readModules = options.ReadModules ~= false
    local registry = makeRegistry()
    local configRoot = ReplicatedStorage:FindFirstChild("Configs")
        or ReplicatedStorage:WaitForChild("Configs", options.Timeout or 10)

    if not configRoot then
        registry.Root = "ReplicatedStorage.Configs"
        addError(
            registry,
            "Configs",
            registry.Root,
            "Folder Configs tidak ditemukan"
        )
        H.ConfigRegistry = registry
        printRegistry(registry, options)
        return registry
    end

    registry.Root = getFullName(configRoot)
    registry.ReadModules = readModules

    local ok, descendants = pcall(function()
        return configRoot:GetDescendants()
    end)
    if not ok then
        addError(registry, "Configs", registry.Root, descendants)
        H.ConfigRegistry = registry
        printRegistry(registry, options)
        return registry
    end

    for _, instance in ipairs(descendants) do
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
            if readModules then
                readModule(instance, record, registry)
                if record.Read then
                    registry.Readable = registry.Readable + 1
                end
            else
                record.Read = false
                record.ReadReason = "module_read_disabled"
            end
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

    table.sort(registry.Objects, function(a, b)
        return a.Path < b.Path
    end)
    table.sort(registry.Errors, function(a, b)
        return a.Path < b.Path
    end)
    registry.LastScan = os.time()

    H.ConfigRegistry = registry
    printRegistry(registry, options)
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
        Readable = registry.Readable or 0,
        Errors = #registry.Errors,
    }
end

H.ConfigScanner = ConfigScanner
H.ConfigRegistry = makeRegistry()
H.ScanConfigs = ConfigScanner.Scan
H.PrintConfigScan = printRegistry

-- Scan awal dilakukan sebelum modul Farm/UI dimuat, sehingga hasil pertama
-- langsung muncul di console dan modul lain dapat membaca registry.
ConfigScanner.Scan()