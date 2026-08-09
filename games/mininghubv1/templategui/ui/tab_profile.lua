--------------------------------------------------------------------------------
--// ui/tab_profile.lua — Profile / Config System
--------------------------------------------------------------------------------
local H = getgenv().XiFilTemplateGUI_Hub
local _G = getgenv().XiFilTemplateGUI_G
local ConfigSystem = H.ConfigSystem
local CustomNotify = H.CustomNotify
local CreateTab = H.CreateTab
local CreateSection = H.CreateSection
local CreateInputUI = H.CreateInputUI
local CreateDropdownUI = H.CreateDropdownUI
local CreateButton = H.CreateButton
local SyncAllVisualUI = function(...) return H.SyncAllVisualUI(...) end

local ProfilePage = CreateTab("💾 Profil", "tabProfile")
CreateSection(ProfilePage, "Data Profiles", "secDataProfile")

local selectedConfig = "None"
local newConfigName = ""
local ConfigDropdown

local function RefreshConfigDropdown(selectName)
    ConfigDropdown:SetValues(ConfigSystem.GetConfigList())
    if selectName then
        selectedConfig = selectName
        ConfigDropdown:SetValue(selectName)
    end
end

ConfigDropdown = CreateDropdownUI(
    ProfilePage,
    "Selected Profile",
    ConfigSystem.GetConfigList(),
    "None",
    function(value) selectedConfig = value end,
    "lblSelectedProfile"
)

CreateInputUI(ProfilePage, "New Profile Name", "", false, function(value)
    newConfigName = tostring(value)
end)

CreateButton(ProfilePage, "➕ Save New Profile", function()
    if newConfigName == "" then
        CustomNotify("CONFIG WARN", "Ketik nama profile!", 3)
        return
    end
    local ok, err = ConfigSystem.SaveNew(newConfigName)
    if ok then
        CustomNotify("CONFIG", "'" .. newConfigName .. "' disimpan!", 3)
        RefreshConfigDropdown(newConfigName)
    else
        CustomNotify("SAVE ERROR", err, 4)
    end
end, "btnSaveProfile")

CreateButton(ProfilePage, "📂 Load Profile", function()
    if selectedConfig == "None" then
        CustomNotify("CONFIG WARN", "Pilih profile!", 3)
        return
    end
    if ConfigSystem.Load(selectedConfig, SyncAllVisualUI) then
        CustomNotify("CONFIG", "Dimuat: " .. selectedConfig, 3)
    else
        CustomNotify("CONFIG ERROR", "File profile tidak valid.", 3)
    end
end, "btnLoadProfile")

CreateButton(ProfilePage, "⚡ Set as Autoload", function()
    if selectedConfig == "None" then
        CustomNotify("AUTOLOAD", "Pilih profile!", 3)
        return
    end
    ConfigSystem.SaveAutoLoadPointer(selectedConfig)
    CustomNotify("AUTOLOAD SET", "'" .. selectedConfig .. "' autoload aktif.", 3)
end, "btnSetAutoload")

CreateButton(ProfilePage, "❌ Reset Autoload", function()
    ConfigSystem.SaveAutoLoadPointer("None")
    CustomNotify("AUTOLOAD OFF", "Autoload di-reset.", 3)
end, "btnResetAutoload")

CreateButton(ProfilePage, "🔄 Overwrite Profile", function()
    local target = newConfigName ~= "" and newConfigName or selectedConfig
    if target == "" or target == "None" then
        CustomNotify("CONFIG WARN", "Pilih profile valid!", 3)
        return
    end
    local ok, err = ConfigSystem.OverwriteExisting(target)
    if ok then
        CustomNotify("CONFIG", "'" .. target .. "' ditimpa!", 3)
        RefreshConfigDropdown(target)
    else
        CustomNotify("OVERWRITE ERROR", err, 4)
    end
end, "btnOverwriteProfile")

CreateButton(ProfilePage, "🗑️ Hapus Profile", function()
    if selectedConfig == "None" then
        CustomNotify("CONFIG WARN", "Pilih target!", 3)
        return
    end
    if ConfigSystem.Delete(selectedConfig) then
        CustomNotify("CONFIG", "Profile dihapus.", 3)
        selectedConfig = "None"
        RefreshConfigDropdown("None")
    else
        CustomNotify("CONFIG ERROR", "Gagal menghapus profile.", 3)
    end
end, "btnDeleteProfile")