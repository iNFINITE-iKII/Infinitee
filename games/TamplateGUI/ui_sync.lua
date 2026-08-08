--------------------------------------------------------------------------------
--// ui_sync.lua — Synchronize the visual TemplateGUI controls
--------------------------------------------------------------------------------
local H = getgenv().XiFilTemplateGUI_Hub
local _G = getgenv().XiFilTemplateGUI_G
local VisualConfig = H.VisualConfig
local ApplyAllVisuals = H.ApplyAllVisuals

function SyncAllVisualUI()
    pcall(function()
        if _G.BgColorDropdown then
            _G.BgColorDropdown:SetValue(VisualConfig.CurrentBg)
        end
        if _G.ThemeColorDropdown then
            _G.ThemeColorDropdown:SetValue(VisualConfig.CurrentTheme)
        end
        if _G.TranspToggleUI then
            _G.TranspToggleUI:SetValue(VisualConfig.TransparentMode)
        end
        if _G.TranspSliderUI then
            _G.TranspSliderUI:SetValue(math.floor(VisualConfig.TransparencyLevel * 100))
        end
        if _G.GestureModeDropdown then
            _G.GestureModeDropdown:SetValue(VisualConfig.GestureMode)
        end
        if _G.TabModeDropdownUI then
            _G.TabModeDropdownUI:SetValue(VisualConfig.TabMode)
        end
        if _G.NotifEnabledToggleUI then
            _G.NotifEnabledToggleUI:SetValue(VisualConfig.NotifEnabled)
        end
        if _G.LangDropdownUI then
            _G.LangDropdownUI:SetValue(VisualConfig.Language)
        end
        if _G.FontDropdownUI then
            _G.FontDropdownUI:SetValue(VisualConfig.CurrentFont)
        end
        if _G.FontSizeInput then
            _G.FontSizeInput:SetValue(tostring(VisualConfig.FontSize or 8))
        end
        if _G.ToggleShapeDropdownUI then
            _G.ToggleShapeDropdownUI:SetValue(VisualConfig.ToggleShape)
        end
        if _G.BtnShapeDropdownUI then
            _G.BtnShapeDropdownUI:SetValue(VisualConfig.ButtonShape)
        end
        if _G.AnimStyleDropdownUI then
            _G.AnimStyleDropdownUI:SetValue(VisualConfig.AnimStyle)
        end
        if _G.BgEffectDropdownUI then
            _G.BgEffectDropdownUI:SetValue(VisualConfig.BgEffect)
        end
    end)

    pcall(ApplyAllVisuals)
end

H.SyncAllVisualUI = SyncAllVisualUI