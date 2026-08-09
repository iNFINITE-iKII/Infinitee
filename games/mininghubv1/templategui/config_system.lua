--------------------------------------------------------------------------------
--// config_system.lua — Visual profile storage
--------------------------------------------------------------------------------
local H = getgenv().XiFilTemplateGUI_Hub
local Services = H.Services
local VisualConfig = function()
    return H.VisualConfig
end
local CustomNotify = H.CustomNotify

local HttpService = Services.HttpService
local FOLDER_NAME = "XiFilTemplateGUI_Configs"

pcall(function()
    if not isfolder(FOLDER_NAME) then makefolder(FOLDER_NAME) end
end)

local ConfigSystem = {}

local function getPath(name)
    return FOLDER_NAME .. "/" .. name .. ".json"
end

function ConfigSystem.GetAutoLoadPointer()
    local path = FOLDER_NAME .. "/autoload_pointer.txt"
    if isfile(path) then
        local ok, content = pcall(readfile, path)
        if ok and content and content ~= "" then return content end
    end
    return "None"
end

function ConfigSystem.SaveAutoLoadPointer(name)
    return pcall(writefile, FOLDER_NAME .. "/autoload_pointer.txt", tostring(name))
end

function ConfigSystem.GetConfigList()
    local list = { "None" }
    local ok, files = pcall(listfiles, FOLDER_NAME)
    if ok and files then
        for _, file in ipairs(files) do
            local name = file:match("([^\\/]+)%.json$")
            if name and name ~= "autoload_pointer" then
                table.insert(list, name)
            end
        end
    end
    table.sort(list, function(a, b)
        if a == "None" then return true end
        if b == "None" then return false end
        return a < b
    end)
    return list
end

local function snapshotVisualConfig()
    local snapshot = {}
    for key, value in pairs(VisualConfig()) do
        if type(value) ~= "function" then snapshot[key] = value end
    end
    return snapshot
end

function ConfigSystem.SaveNew(name)
    if name == "" or name == "None" then return false, "Nama profile tidak valid." end
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, snapshotVisualConfig())
    if not ok then return false, "Gagal membuat data profile." end
    local written = pcall(writefile, getPath(name), encoded)
    return written, written and nil or "Gagal menyimpan file profile."
end

ConfigSystem.OverwriteExisting = ConfigSystem.SaveNew

function ConfigSystem.Load(name, callback)
    if name == "None" or name == "" then return false end
    local path = getPath(name)
    if not isfile(path) then return false end

    local readOk, content = pcall(readfile, path)
    if not readOk or not content then return false end
    local decodeOk, data = pcall(HttpService.JSONDecode, HttpService, content)
    if not decodeOk or type(data) ~= "table" then return false end

    local visual = VisualConfig()
    -- Also accept the old { visual = {...} } format if a previous profile exists.
    local source = data.visual or data
    for key, value in pairs(source) do
        if visual[key] ~= nil then visual[key] = value end
    end
    if callback then callback() end
    return true
end

function ConfigSystem.Delete(name)
    if name == "None" or name == "" then return false end
    local path = getPath(name)
    if not isfile(path) then return false end
    return pcall(delfile, path)
end

function ConfigSystem.ExecuteAutoLoad(callback)
    local target = ConfigSystem.GetAutoLoadPointer()
    if target and target ~= "None" then
        task.spawn(function()
            task.wait(0.5)
            if ConfigSystem.Load(target, callback) then
                CustomNotify("AUTOLOAD", "Profil: " .. target, 3)
            end
        end)
    end
end

H.ConfigSystem = ConfigSystem
H.HttpService = HttpService
H.FOLDER_NAME = FOLDER_NAME