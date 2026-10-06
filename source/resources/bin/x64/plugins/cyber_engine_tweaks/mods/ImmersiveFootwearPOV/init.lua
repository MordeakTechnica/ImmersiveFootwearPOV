-- =============================================================================
-- Immersive Footwear POV - Cyber Engine Tweaks (CET) Core Orchestrator
-- Dynamically combines IFP base height slider + footwear heel height
-- Features smooth 0.20s transitions and context-aware suppression
-- Modular architecture following SOLID principles and design patterns
-- High-performance runtime: zero per-frame heap allocations, optimized polling
-- =============================================================================

local Config = require("modules/config")
local Logger = require("modules/logger")
local Transition = require("modules/transition")
local State = require("modules/state")
local Stride = require("modules/stride")
local Perspective = require("modules/perspective")
if not Perspective then
    print("[ImmersiveFootwearPOV] CRITICAL: Failed to load Perspective module!")
end
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
    ifpHeightAdjustmentEnabled = true,
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

-- Cached engine singletons & FFI state tracking
local cachedSys = nil
local lastSentITP = nil
local lastSentIFP = nil

-- Pre-allocated reusable stance context table (Zero per-frame table allocations)
local stanceContext = {
    forcedBlend = nil,
    isTPPActive = false,
    sys = nil,
    shoeState = nil,
    isSuppressed = false,
    isPhotoModeOpen = false,
    heightLimits = FootwearHeightLimits,
    ifpIntegration = IFPIntegration,
    ifpInstalled = false,
    ifpHeightAdjustmentEnabled = true,
    ifpBaseHeightCm = 0.0,
    isTFP = false,
}

-- Reusable static logging callbacks (Zero per-frame closure allocations)
local function LogTransitionTarget(msg)
    local isTFP = mod.currentShoeState and mod.currentShoeState.isTFP
    Logger.LogFPP(isTFP, "%s", msg)
    Logger.LogFile("%s", msg)
end

local function LogTransitionSettled(msg)
    local isTFP = mod.currentShoeState and mod.currentShoeState.isTFP
    Logger.LogFPP(isTFP, "%s", msg)
    Logger.LogFile("%s", msg)
end

local function GetSystem()
    if not cachedSys then
        pcall(function()
            cachedSys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
        end)
    end
    return cachedSys
end

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
    mod.ifpHeightAdjustmentEnabled = IFPIntegration.IsHeightAdjustmentEnabled(false)
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
    local sys = GetSystem()
    ConsoleManager.DumpState(sys, mod, IFPIntegration, Transition)
end

function mod.ForceStance(cm, extra)
    return ConsoleManager.ForceStance(mod, IFPIntegration, cm, extra)
end

function mod.SetCustomHeight(heelCm, platformCm)
    local player = Game.GetPlayer()
    local sys = GetSystem()
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
    local ifpHeightEnabled = IFPIntegration.IsHeightAdjustmentEnabled(true)
    mod.ifpHeightAdjustmentEnabled = ifpHeightEnabled
    local itpInstalled = (Perspective and Perspective.IsITPInstalled and Perspective.IsITPInstalled()) or false

    local sys = GetSystem()
    if sys then
        pcall(function()
            if sys.SetITPPresent then
                sys:SetITPPresent(itpInstalled)
                lastSentITP = itpInstalled
            end
            if sys.SetIFPPresent then
                local ifpActive = ifpInstalled and ifpEnabled and ifpHeightEnabled
                sys:SetIFPPresent(ifpActive)
                lastSentIFP = ifpActive
            end
        end)
    end

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

    local sys = GetSystem()
    if not sys then return end

    -- Fallback periodic sync: check for footwear / state changes (0.40s)
    -- Native equip hooks in REDscript intercept immediately on equip; this poll is a safety fallback
    mod.pollTimer = mod.pollTimer + deltaTime
    if mod.pollTimer >= 0.40 then
        mod.pollTimer = 0.0
        sys:UpdateEquippedFootwear(player)

        -- Only send presence flags across FFI if value has changed
        local itpInstalled = (Perspective and Perspective.IsITPInstalled and Perspective.IsITPInstalled()) or false
        if lastSentITP ~= itpInstalled then
            lastSentITP = itpInstalled
            pcall(function() if sys.SetITPPresent then sys:SetITPPresent(itpInstalled) end end)
        end

        local ifpActive = IFPIntegration.IsInstalled()
            and (IFPIntegration.IsEnabled and IFPIntegration.IsEnabled() or false)
            and (IFPIntegration.IsHeightAdjustmentEnabled(false) or false)
        if lastSentIFP ~= ifpActive then
            lastSentIFP = ifpActive
            pcall(function() if sys.SetIFPPresent then sys:SetIFPPresent(ifpActive) end end)
        end

        mod.ifpHeightAdjustmentEnabled = IFPIntegration.IsHeightAdjustmentEnabled(false)
        State.Sync(player, sys, mod.overrides, mod, IFPIntegration, SaveAllOverrides)
    end

    -- Update Photo Mode platform lift once per frame (very cheap 2 booleans when inactive)
    PMIntegration.OnUpdate(deltaTime)

    -- Detect if Immersive Third Person (ITP) camera is currently active
    local isITPActive = (Perspective and Perspective.IsTPPActive and Perspective.IsTPPActive(player)) or false
    if isITPActive ~= mod.isITPActive then
        local wasITP = mod.isITPActive
        mod.isITPActive = isITPActive
        Logger.LogFile("Perspective changed: %s -> %s | Shoe: %s | Heel: %.1f cm | Platform: %.1f cm",
            wasITP and "3rd Person (ITP Active)" or "1st Person (FPP)",
            isITPActive and "3rd Person (ITP Active)" or "1st Person (FPP)",
            tostring(mod.currentShoeState.displayName),
            mod.currentShoeState.heelCm or 0.0,
            mod.currentShoeState.platformCm or 0.0)

        IFPIntegration.ResetBlendCache()
        Stride.Reset(player)

        if not isITPActive then
            -- Returning to First Person (FPP): zero out 3rd-person puppet elevation variable
            if AnimationControllerComponent and AnimationControllerComponent.SetInputFloat then
                pcall(AnimationControllerComponent.SetInputFloat, player, CName.new("foot_elevation_offset"), 0.0)
            end
        end
    end

    -- Poll IFP base height periodically (0.25s), or every frame when overlay is open
    mod.ifpPollTimer = mod.ifpPollTimer + deltaTime
    if mod.ifpPollTimer >= 0.25 or mod.isOverlayOpen then
        mod.ifpPollTimer = 0.0
        RefreshIFPBaseHeight()
    end

    -- Resolve target stance via StanceResolver (Strategy Pattern)
    -- Mutate static context to eliminate per-frame table allocation
    local isSuppressed = mod.currentShoeState.isSuppressed or mod.isPhotoModeOpen
    stanceContext.forcedBlend = mod.forcedBlend
    stanceContext.isTPPActive = isITPActive
    stanceContext.sys = sys
    stanceContext.shoeState = mod.currentShoeState
    stanceContext.isSuppressed = isSuppressed
    stanceContext.isPhotoModeOpen = mod.isPhotoModeOpen
    stanceContext.ifpInstalled = IFPIntegration.IsInstalled()
    stanceContext.ifpHeightAdjustmentEnabled = mod.ifpHeightAdjustmentEnabled
    stanceContext.ifpBaseHeightCm = mod.ifpBaseHeightCm
    stanceContext.isTFP = (sys.IsTFPPresent and sys:IsTFPPresent()) or false

    local targetBlend, footElevationMeters, reason = StanceResolver.ResolveTarget(stanceContext)

    -- Smooth transition handling with static logging callbacks (zero closure allocation)
    Transition.SetTarget(targetBlend, reason, LogTransitionTarget)
    local activeBlend = Transition.Update(deltaTime, LogTransitionSettled)

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
    local sys = GetSystem()

    UIManager.DrawUI(mod, player, sys, FootwearHeightLimits, SaveAllOverrides, IFPIntegration)
end)

return mod
