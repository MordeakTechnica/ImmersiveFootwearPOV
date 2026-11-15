-- =============================================================================
-- Immersive Footwear POV - Cyber Engine Tweaks (CET) Fallback Orchestrator
-- Single Responsibility: Mod lifecycle, DigitalVixen availability probe, and
-- activating the configuration fallback interface ONLY when a native DigitalVixen
-- mod (RedWindows, RedscriptConfigFramework, RedFunctions) is missing.
-- =============================================================================

local Config = require("modules/config")
local UIManager = require("modules/ui")

local mod = {
    isFallbackActive = false,
    isOverlayOpen = false,
    cachedSys = nil,
    cachedPreGame = nil,
    checkedIFP = nil,
    hasIFP = false,
    ifpSyncedSys = false,
}

local function IsPreGame()
    local ok, pre = pcall(function()
        if not GetSingleton then
            return true
        end
        local scenario = GetSingleton("inkMenuScenario")
        local req = scenario and scenario:GetSystemRequestsHandler()
        if not req then
            return true
        end
        return req:IsPreGame()
    end)
    if not ok then
        return true
    end
    return pre == true
end

local function IsPausedOrInMenu()
    local ok, blocked = pcall(function()
        if Game and Game.GetAllBlackboardDefs and Game.GetBlackboardSystem then
            local defs = Game.GetAllBlackboardDefs()
            local uiSys = defs and defs.UI_System
            if uiSys then
                local bb = Game.GetBlackboardSystem():Get(uiSys)
                if bb and bb:GetBool(uiSys.IsInMenu) then
                    return true
                end
            end
        end
        if Game and Game.GetTimeSystem then
            local ts = Game.GetTimeSystem()
            if ts and ts.IsPausedState and ts:IsPausedState() then
                return true
            end
        end
        return false
    end)
    return ok and blocked == true
end

--- Retrieve the singleton ImmersiveFootwearPOVSystem instance without leaking pre-game handles across sessions
---@return any
local function GetSystem()
    local preGame = IsPreGame()
    if mod.cachedSys ~= nil and mod.cachedPreGame ~= preGame then
        mod.cachedSys = nil
        mod.ifpSyncedSys = false
    end
    if not mod.cachedSys then
        pcall(function()
            local container = Game and Game.GetScriptableSystemsContainer and Game.GetScriptableSystemsContainer()
            if container then
                mod.cachedSys = container:Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
                mod.cachedPreGame = preGame
                mod.ifpSyncedSys = false
            end
        end)
    end
    return mod.cachedSys
end

--- Evaluate whether the CET fallback configuration should be active
local function EvaluateFallbackState()
    local sys = GetSystem()
    if not sys then
        -- Before game session attaches or systems container is ready, assume fallback pending
        mod.isFallbackActive = true
        return
    end

    if sys.IsCetFallbackActive then
        mod.isFallbackActive = sys:IsCetFallbackActive()
    else
        mod.isFallbackActive = true
    end

    if not mod.isFallbackActive then
        -- All required DigitalVixen mods are installed; CET stands down
        return
    end

    -- If RedFunctions is missing, populate REDscript in-memory state from local CET JSON
    if sys.HasRedFunctions and not sys:HasRedFunctions() then
        local settings = Config.LoadSettings()
        local cfg = sys.GetConfig and sys:GetConfig() or nil
        if cfg and settings then
            if settings.enableFPP ~= nil then cfg.enableFPP = settings.enableFPP end
            if settings.transitionSpeed ~= nil then cfg.transitionSpeed = settings.transitionSpeed end
            if settings.enableITP ~= nil then cfg.enableITP = settings.enableITP end
            if settings.autoElevatePM ~= nil then cfg.autoElevatePM = settings.autoElevatePM end
            if settings.autoElevateNTP ~= nil then cfg.autoElevateNTP = settings.autoElevateNTP end
            if settings.enableHipSway ~= nil then cfg.enableHipSway = settings.enableHipSway end
            if settings.swayLow ~= nil then cfg.swayLow = settings.swayLow end
            if settings.swayMid ~= nil then cfg.swayMid = settings.swayMid end
            if settings.swayHigh ~= nil then cfg.swayHigh = settings.swayHigh end
            if settings.suppressVehicles ~= nil then cfg.suppressVehicles = settings.suppressVehicles end
            if settings.suppressWorkspots ~= nil then cfg.suppressWorkspots = settings.suppressWorkspots end
            if settings.suppressScenes ~= nil then cfg.suppressScenes = settings.suppressScenes end
            if settings.debugLogs ~= nil then cfg.debugLogs = settings.debugLogs end
            if sys.OnConfigUpdated then sys:OnConfigUpdated(cfg) end
        end

        local overrides = Config.LoadOverrides()
        if overrides and sys.RegisterCustomOverride then
            for key, data in pairs(overrides) do
                if type(data) == "table" and data.heel and data.platform then
                    sys:RegisterCustomOverride(key, (tonumber(data.heel) or 0.0) / 100.0, (tonumber(data.platform) or 0.0) / 100.0)
                end
            end
        end
    end
end

-- -----------------------------------------------------------------------------
-- CET Lifecycle Callbacks
-- -----------------------------------------------------------------------------

registerForEvent("onInit", function()
    EvaluateFallbackState()
    if mod.isFallbackActive then
        local sys = GetSystem()
        local missing = sys and sys.GetMissingDigitalVixenSummary and sys:GetMissingDigitalVixenSummary() or "DigitalVixen mod(s)"
        print(string.format("[ImmersiveFootwearPOV] Missing native mod(s): %s. CET fallback configuration is ACTIVE.", missing))
    else
        print("[ImmersiveFootwearPOV] Complete native DigitalVixen suite detected (RedWindows, RCF, RedFunctions). CET fallback is DORMANT.")
    end
end)

registerForEvent("onOverlayOpen", function()
    mod.isOverlayOpen = true
    EvaluateFallbackState()
end)

registerForEvent("onOverlayClose", function()
    mod.isOverlayOpen = false
    local sys = GetSystem()
    if sys and sys.FlushPendingOverrideSave then
        sys:FlushPendingOverrideSave()
    end
end)

registerForEvent("onDraw", function()
    -- CET interface is strictly suppressed when native DigitalVixen suite is complete
    if not mod.isFallbackActive then
        return
    end

    local sys = GetSystem()
    UIManager.Draw(mod, sys, Config)
end)

-- -----------------------------------------------------------------------------
-- IFP (Immersive First Person) Runtime Bridge
-- When third-party IFP is installed, its 60 FPS Lua runtime loop continuously
-- sends 'ifp_height_blend = 0.50'. We re-assert REDscript's authoritative blend
-- right after IFP runs in the CET tick sequence to prevent IFP from clobbering elevation.
-- -----------------------------------------------------------------------------

local ifpBlendName = nil

registerForEvent("onShutdown", function()
    mod.isOverlayOpen = false
    mod.cachedSys = nil
    mod.cachedPreGame = nil
    mod.checkedIFP = nil
    mod.hasIFP = false
    mod.ifpSyncedSys = false
    ifpBlendName = nil
end)

registerForEvent("onUpdate", function(delta)
    if IsPreGame() then
        mod.cachedSys = nil
        mod.cachedPreGame = true
        mod.ifpSyncedSys = false
        return
    end

    if mod.checkedIFP == nil then
        local ifp = GetMod("ImmersiveFirstPerson") or GetMod("immersive_first_person")
        mod.hasIFP = (ifp ~= nil)
        mod.checkedIFP = true
    end

    local sys = GetSystem()
    if not sys then return end

    if not mod.ifpSyncedSys and sys.SetIFPPresent then
        pcall(function()
            sys:SetIFPPresent(mod.hasIFP)
        end)
        mod.ifpSyncedSys = true
    end

    if not mod.hasIFP or not sys.GetActiveFppBlend then
        return
    end

    -- Never call Game.GetPlayer() during menus, pause screens, or loading/teardown frames
    if IsPausedOrInMenu() then
        return
    end

    local okPlayer, player = pcall(Game.GetPlayer)
    if not okPlayer or not player then return end
    if player.IsAttached and not player:IsAttached() then return end

    if not ifpBlendName and CName and CName.new then
        ifpBlendName = CName.new("ifp_height_blend")
    end
    local blend = sys:GetActiveFppBlend()
    local effOffset = sys.GetActiveFppOffset and sys:GetActiveFppOffset() or 0.0
    if ifpBlendName and AnimationControllerComponent and AnimationControllerComponent.SetInputFloat then
        pcall(function()
            AnimationControllerComponent.SetInputFloat(player, ifpBlendName, blend)
        end)
    end
    if player.ImmersiveFirstPersonSetInteractionHeight then
        pcall(function()
            player:ImmersiveFirstPersonSetInteractionHeight(effOffset)
        end)
    end
end)

-- -----------------------------------------------------------------------------
-- Fallback Hotkey & Console API (Only functional when fallback is active)
-- -----------------------------------------------------------------------------

registerHotkey("toggle_ifp_calibrator", "Toggle Shoe Calibrator (Fallback)", function()
    if not mod.isFallbackActive then
        print("[ImmersiveFootwearPOV] CET hotkeys are disabled because native RedWindows is handling UI.")
        return
    end
    mod.isOverlayOpen = not mod.isOverlayOpen
end)

return mod
