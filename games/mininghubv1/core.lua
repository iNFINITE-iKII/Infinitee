--------------------------------------------------------------------------------
-- Mining Hub V1 — core
-- Service Roblox, state bersama, konfigurasi, dan utilitas dasar.
--------------------------------------------------------------------------------

local env = getgenv and getgenv() or _G
local Hub = env.MiningHub or {}
env.MiningHub = Hub

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

Hub.Services = {
    Players = Players,
    Workspace = Workspace,
    RunService = RunService,
    ReplicatedStorage = ReplicatedStorage,
    UserInputService = UserInputService,
    LocalPlayer = localPlayer,
    PlayerGui = localPlayer:WaitForChild("PlayerGui"),
    Remotes = ReplicatedStorage:WaitForChild("Remotes"),
}

Hub.State = {
    IsAutoSellOn = false,
    IsAutoSelling = false,
    AutoSellStatus = "Disabled",
    AutoSellCooldown = 2,
    AutoSellTask = nil,
    AutoSellLastAt = 0,
    StatusTask = nil,
    IsTargetLocked = false,
    IsFlying = false,
    IsFarmOn = false,
    FlySpeed = 50,
    SpeedHeight = 2.5,
    PromptSpamCount = 15,
    BlacklistDuration = 1.5,
    FarmSpeedMs = 33,
    SelectedTier = "All",
    SelectedCrystalName = "All",
    SelectedDroppedName = "All",
    SelectedSize = "All",
    SelectedWeight = "All",
    SelectedValue = "All",
    CurrentTarget = nil,
    CurrentPart = nil,
    CurrentPrompt = nil,
    FarmTask = nil,
    NukeStatsParagraph = nil,
}

Hub.Config = {
    ValueRanges = {
        ["1 - 1K"] = {1, 1000},
        ["1K - 10K"] = {1000, 10000},
        ["10K - 100K"] = {10000, 100000},
        ["100K - 1M"] = {100000, 1000000},
        ["1M - 10M"] = {1000000, 10000000},
        ["10M - 1B"] = {10000000, 1000000000},
        ["100M - 10B"] = {100000000, 10000000000},
        ["1B - 100B"] = {1000000000, 100000000000},
    },
    ValueOptions = {
        "All", "1 - 1K", "1K - 10K", "10K - 100K", "100K - 1M",
        "1M - 10M", "10M - 1B", "100M - 10B", "1B - 100B",
    },
    WeightRanges = {
        ["1-10"] = {1, 10},
        ["10-100"] = {10, 100},
        ["100-350"] = {100, 350},
        ["350-1100"] = {350, 1100},
        ["1100-3600"] = {1100, 3600},
        ["3600-7500"] = {3600, 7500},
    },
    WeightOptions = {
        "All", "MAX", "1-10", "10-100", "100-350",
        "350-1100", "1100-3600", "3600-7500",
    },
}

Hub.Cache = {
    Attribute = {},
    ValidTargets = {},
    BlacklistedCrystals = {},
    TargetPool = {},
    PoolIndex = 0,
}

Hub.Stats = {
    Attempts = 0,
    LocalSuccess = 0,
    ServerSuccess = 0,
    PendingTarget = nil,
    PendingPrompt = nil,
    PendingAt = 0,
}

Hub.Data = {}
Hub.Functions = {}
Hub.UI = {}
Hub.Connections = {}
Hub.Loaded = false