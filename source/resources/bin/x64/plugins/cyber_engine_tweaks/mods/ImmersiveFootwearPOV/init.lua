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
}

--- Retrieve the singleton ImmersiveFootwearPOVSystem instance
---@return any
local function GetSystem()
    if not mod.cachedSys then
        pcall(function()
            mod.cachedSys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
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

registerForEvent("onUpdate", function(delta)
    local sys = GetSystem()
    if not sys then return end

    local player = Game.GetPlayer()
    if not player then return end

    if mod.checkedIFP == nil then
        local ifp = GetMod("ImmersiveFirstPerson") or GetMod("immersive_first_person")
        mod.hasIFP = (ifp ~= nil)
        mod.checkedIFP = true
        if sys.SetIFPPresent then
            sys:SetIFPPresent(mod.hasIFP)
        end
    end

    if mod.hasIFP and sys.GetActiveFppBlend then
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
