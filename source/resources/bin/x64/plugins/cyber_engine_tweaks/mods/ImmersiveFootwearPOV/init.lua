-- =============================================================================
-- Immersive Footwear POV - Cyber Engine Tweaks (CET) Core Orchestrator
-- Dynamically combines IFP base height slider + footwear heel height
-- Features smooth 0.20s transitions and context-aware suppression
-- Modular architecture following SOLID principles and design patterns
-- =============================================================================

local Config = require("modules/config")
local Logger = require("modules/logger")
local Transition = require("modules/transition")
local State = require("modules/state")
local Stride = require("modules/stride")
local Perspective = require("modules/perspective")
local StanceResolver = require("modules/stance")
local ConsoleManager = require("modules/console")
local UIManager = require("modules/ui")
local IFPIntegration = require("integrations/ifp")
local PMIntegration = require("integrations/pm")

-- -----------------------------------------------------------------------------
-- Global Height Configuration Limits
-- -----------------------------------------------------------------------------
local FootwearHeightLimits = {
    MAX_HEEL_CM = 40.0,
    MAX_PLATFORM_CM = 30.0,
    MAX_IFP_CM = 25.0,
}

local mod = {
    pollTimer = 0.0,
    ifpPollTimer = 0.0,
    ifpBaseHeightCm = 0.0,
    isOverlayOpen = false,
    overrides = {},
    autoElevatePMPlatform = true,
    debugLogs = false,
    enableHipSway = true,
    swayLow = 1.0,
    swayMid = 1.0,
    swayHigh = 1.0,
    isPhotoModeOpen = false,
    stride = Stride,
}

-- Expose currentShoeState for integrations / UI
mod.currentShoeState = State.GetShoeState()

local function SaveAllOverrides()
    Config.Save(Config.FILE_NAME, mod.overrides, {
        autoElevatePM = mod.autoElevatePMPlatform,
        debugLogs = mod.debugLogs,
        enableHipSway = mod.enableHipSway,
        swayLow = mod.swayLow,
        swayMid = mod.swayMid,
        swayHigh = mod.swayHigh,
    })
end

local function RefreshIFPBaseHeight()
    local height, _ = IFPIntegration.GetState()
    mod.ifpBaseHeightCm = height
    return height
end

-- -----------------------------------------------------------------------------
-- Console API & Diagnostics (Delegated to ConsoleManager)
-- -----------------------------------------------------------------------------
function mod.SetDebug(enabled)
    return ConsoleManager.SetDebug(mod, enabled, SaveAllOverrides)
end

function mod.ToggleDebug()
    return ConsoleManager.ToggleDebug(mod, SaveAllOverrides)
end

function mod.GetDebug()
    return mod.debugLogs
end

function mod.DumpState()
    local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
    ConsoleManager.DumpState(sys, mod, IFPIntegration, Transition)
end

function mod.ForceStance(cm, extra)
    return ConsoleManager.ForceStance(mod, IFPIntegration, cm, extra)
end

function mod.SetCustomHeight(heelCm, platformCm)
    local player = Game.GetPlayer()
    local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
    return ConsoleManager.SetCustomHeight(mod, sys, player, FootwearHeightLimits, heelCm, platformCm, SaveAllOverrides)
end

-- Register global CET Console shortcuts
ConsoleManager.RegisterShortcuts(mod)

-- -----------------------------------------------------------------------------
-- Lifecycle Events
-- -----------------------------------------------------------------------------
registerForEvent("onInit", function()
    local overrides, settings = Config.Load(Config.FILE_NAME)
    mod.overrides = overrides
    mod.autoElevatePMPlatform = settings.autoElevatePM
    mod.debugLogs = settings.debugLogs
    mod.enableHipSway = settings.enableHipSway
    mod.swayLow = settings.swayLow or 1.0
    mod.swayMid = settings.swayMid or 1.0
    mod.swayHigh = settings.swayHigh or 1.0
    Logger.Init(mod.debugLogs)
    Stride.Init()

    PMIntegration.Init(mod)
    RefreshIFPBaseHeight()

    local ifpInstalled = IFPIntegration.IsInstalled()
    local ifpEnabled = IFPIntegration.IsEnabled and IFPIntegration.IsEnabled() or false
    local ifpHeightEnabled = IFPIntegration.IsHeightAdjustmentEnabled and IFPIntegration.IsHeightAdjustmentEnabled() or false
    local itpInstalled = Perspective.IsITPInstalled()

    pcall(function()
        local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
        if sys then
            if sys.SetITPPresent then
                sys:SetITPPresent(itpInstalled)
            end
            if sys.SetIFPPresent then
                sys:SetIFPPresent(ifpInstalled and ifpEnabled and ifpHeightEnabled)
            end
        end
    end)

    ConsoleManager.RegisterShortcuts(mod)

    print(string.format("[ImmersiveFootwearPOV] Initialized | ITP: %s | IFP: %s (Enabled: %s, Height Adj: %s, Base: %.1f cm) | Hip Sway: %s | Debug: %s",
        itpInstalled and "ACTIVE" or "ABSENT",
        ifpInstalled and "ACTIVE" or "ABSENT",
        ifpEnabled and "YES" or "NO",
        ifpHeightEnabled and "YES" or "NO",
        mod.ifpBaseHeightCm,
        mod.enableHipSway and "ENABLED" or "DISABLED",
        mod.debugLogs and "ENABLED" or "DISABLED"))
end)

registerForEvent("onOverlayOpen", function()
    mod.isOverlayOpen = true
    RefreshIFPBaseHeight()
end)

registerForEvent("onOverlayClose", function()
    mod.isOverlayOpen = false
    RefreshIFPBaseHeight()
end)

registerForEvent("onUpdate", function(deltaTime)
    local player = Game.GetPlayer()
    if not player then return end

    local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
    if not sys then return end

    -- Check for footwear / state changes periodically (every 0.15s)
    mod.pollTimer = mod.pollTimer + deltaTime
    if mod.pollTimer >= 0.15 then
        mod.pollTimer = 0.0
        sys:UpdateEquippedFootwear(player)
        pcall(function()
            if sys.SetITPPresent then
                sys:SetITPPresent(Perspective.IsITPInstalled())
            end
            if sys.SetIFPPresent then
                local isIFPActiveAndHeightEnabled = IFPIntegration.IsInstalled()
                    and (IFPIntegration.IsEnabled and IFPIntegration.IsEnabled() or false)
                    and (IFPIntegration.IsHeightAdjustmentEnabled and IFPIntegration.IsHeightAdjustmentEnabled() or false)
                sys:SetIFPPresent(isIFPActiveAndHeightEnabled)
            end
        end)
        State.Sync(player, sys, mod.overrides, mod, IFPIntegration, SaveAllOverrides)
    end

    -- Update Photo Mode platform lift once per frame
    PMIntegration.OnUpdate(deltaTime)

    -- Detect if Immersive Third Person (ITP) camera is currently active
    local isITPActive = Perspective.IsTPPActive(player)
    if isITPActive ~= mod.isITPActive then
        local wasITP = mod.isITPActive
        mod.isITPActive = isITPActive
        Logger.LogFile("Perspective changed: %s -> %s | Shoe: %s | Heel: %.1f cm | Platform: %.1f cm",
            wasITP and "3rd Person (ITP Active)" or "1st Person (FPP)",
            isITPActive and "3rd Person (ITP Active)" or "1st Person (FPP)",
            tostring(mod.currentShoeState.displayName),
            mod.currentShoeState.heelCm or 0.0,
            mod.currentShoeState.platformCm or 0.0)

        if not isITPActive then
            -- Returning to First Person (FPP): zero out 3rd-person puppet elevation variable
            if AnimationControllerComponent and AnimationControllerComponent.SetInputFloat then
                pcall(AnimationControllerComponent.SetInputFloat, player, CName.new("foot_elevation_offset"), 0.0)
            end
        end
    end

    -- Poll IFP base height periodically (or every frame in overlay)
    mod.ifpPollTimer = mod.ifpPollTimer + deltaTime
    if mod.ifpPollTimer >= 0.10 or mod.isOverlayOpen then
        mod.ifpPollTimer = 0.0
        RefreshIFPBaseHeight()
    end

    -- Resolve target stance via StanceResolver (Strategy Pattern)
    local ifpInstalled = IFPIntegration.IsInstalled()
    local stanceContext = {
        forcedBlend = mod.forcedBlend,
        isTPPActive = isITPActive,
        sys = sys,
        shoeState = mod.currentShoeState,
        isSuppressed = mod.currentShoeState.isSuppressed or mod.isPhotoModeOpen,
        isPhotoModeOpen = mod.isPhotoModeOpen,
        heightLimits = FootwearHeightLimits,
        ifpIntegration = IFPIntegration,
        ifpInstalled = ifpInstalled,
        ifpHeightAdjustmentEnabled = ifpInstalled and (IFPIntegration.IsHeightAdjustmentEnabled and IFPIntegration.IsHeightAdjustmentEnabled() or false),
        ifpBaseHeightCm = mod.ifpBaseHeightCm,
        isTFP = (sys.IsTFPPresent and sys:IsTFPPresent()) or false,
    }
    local targetBlend, footElevationMeters, reason = StanceResolver.ResolveTarget(stanceContext)

    -- Smooth transition handling
    local isTFPForLog = mod.currentShoeState and mod.currentShoeState.isTFP
    Transition.SetTarget(targetBlend, reason, function(msg)
        Logger.LogFPP(isTFPForLog, "%s", msg)
        Logger.LogFile("%s", msg)
    end)
    local activeBlend = Transition.Update(deltaTime, function(msg)
        Logger.LogFPP(isTFPForLog, "%s", msg)
        Logger.LogFile("%s", msg)
    end)

    mod.currentShoeState.totalStanceCm = Transition.GetStanceCm()
    IFPIntegration.ApplyBlend(player, activeBlend, footElevationMeters)

    -- Procedural Feminine Stride & Hip Sway
    Stride.Update(deltaTime, player, sys, mod)
end)

-- -----------------------------------------------------------------------------
-- Dear ImGui Overlay Event
-- -----------------------------------------------------------------------------
registerForEvent("onDraw", function()
    if not mod.isOverlayOpen then return end

    RefreshIFPBaseHeight()

    local player = Game.GetPlayer()
    local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")

    UIManager.DrawUI(mod, player, sys, FootwearHeightLimits, SaveAllOverrides, IFPIntegration)
end)

return mod
