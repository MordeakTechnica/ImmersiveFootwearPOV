-- =============================================================================
-- Immersive Footwear POV - Cyber Engine Tweaks (CET) Core Orchestrator
-- Dynamically combines IFP base height slider + footwear heel height
-- Features smooth 0.20s transitions and context-aware suppression
-- Modular architecture with dedicated subsystems in ./modules/ and ./integrations/
-- =============================================================================

local Config = require("modules/config")
local Logger = require("modules/logger")
local Transition = require("modules/transition")
local State = require("modules/state")
local IFPIntegration = require("integrations/ifp")
local PMIntegration = require("integrations/pm")

-- -----------------------------------------------------------------------------
-- Global Height Configuration Limits (Configurable Enum)
-- -----------------------------------------------------------------------------
local FootwearHeightLimits = {
    MAX_HEEL_CM = 25.0,
    MAX_PLATFORM_CM = 25.0,
}

local mod = {
    pollTimer = 0.0,
    ifpPollTimer = 0.0,
    ifpBaseHeightCm = 0.0,
    isOverlayOpen = false,
    overrides = {},
    autoElevatePMPlatform = true,
    debugLogs = false,
    isPhotoModeOpen = false,
}

-- Expose currentShoeState for integrations / UI
mod.currentShoeState = State.GetShoeState()

local function SaveAllOverrides()
    Config.Save(Config.FILE_NAME, mod.overrides, {
        autoElevatePM = mod.autoElevatePMPlatform,
        debugLogs = mod.debugLogs,
    })
end

local function RefreshIFPBaseHeight()
    local height, _ = IFPIntegration.GetState()
    mod.ifpBaseHeightCm = height
    return height
end

-- -----------------------------------------------------------------------------
-- Console API & Diagnostics Functions
-- -----------------------------------------------------------------------------
function mod.SetDebug(enabled)
    mod.debugLogs = Logger.SetDebug(enabled, function(newVal)
        mod.debugLogs = newVal
        SaveAllOverrides()
    end)
    return mod.debugLogs
end

function mod.ToggleDebug()
    return mod.SetDebug(not mod.debugLogs)
end

function mod.GetDebug()
    return mod.debugLogs
end

function mod.DumpState()
    local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
    State.DumpDiagnostics(sys, mod, IFPIntegration, Transition)
end

-- Global CET Console shortcut aliases
ToggleIFPDebug = function() return mod.ToggleDebug() end
IFPDebug = function(enabled) return mod.SetDebug(enabled) end
IFPStatus = function() mod.DumpState() end

-- -----------------------------------------------------------------------------
-- CET Lifecycle Events
-- -----------------------------------------------------------------------------
registerForEvent("onInit", function()
    local overrides, settings = Config.Load(Config.FILE_NAME)
    mod.overrides = overrides
    mod.autoElevatePMPlatform = settings.autoElevatePM
    mod.debugLogs = settings.debugLogs
    Logger.Init(mod.debugLogs)

    PMIntegration.Init(mod)
    RefreshIFPBaseHeight()

    local ifpInstalled = IFPIntegration.IsInstalled()
    local ifpEnabled = IFPIntegration.IsEnabled and IFPIntegration.IsEnabled() or false
    print(string.format("[ImmersiveFootwearPOV] Initialized | IFP: %s (Enabled: %s, Base: %.1f cm) | Debug: %s",
        ifpInstalled and "ACTIVE" or "ABSENT",
        ifpEnabled and "YES" or "NO",
        mod.ifpBaseHeightCm, mod.debugLogs and "ENABLED" or "DISABLED"))
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
        State.Sync(player, sys, mod.overrides, mod, IFPIntegration, SaveAllOverrides)
    end

    -- Update Photo Mode platform lift once per frame
    PMIntegration.OnUpdate(deltaTime)

    -- Continuously drive 3rd-person stance elevation (ITP foot_elevation_offset)
    local currentOffset = sys:GetEffectiveOffset()
    local isSuppressed = mod.currentShoeState.isSuppressed or mod.isPhotoModeOpen
    if AnimationControllerComponent and AnimationControllerComponent.SetInputFloat then
        local itpOffset = isSuppressed and 0.0 or currentOffset
        pcall(AnimationControllerComponent.SetInputFloat, player, CName.new("foot_elevation_offset"), itpOffset)
    end

    local isTFP = (sys.IsTFPPresent and sys:IsTFPPresent()) or false

    -- When True First Person is active, camera elevation is handled 100% natively in REDscript.
    -- We skip the IFP animgraph skeletal blend to prevent double-height conflicts.
    if isTFP then
        return
    end

    -- Poll IFP base height periodically (or every frame in overlay)
    mod.ifpPollTimer = mod.ifpPollTimer + deltaTime
    if mod.ifpPollTimer >= 0.10 or mod.isOverlayOpen then
        mod.ifpPollTimer = 0.0
        RefreshIFPBaseHeight()
    end

    -- Calculate target blend based on current shoe offset, IFP base slider, and suppression state
    local currentOffset = sys:GetEffectiveOffset()
    local isSuppressed = mod.currentShoeState.isSuppressed or mod.isPhotoModeOpen
    local targetBlend, _ = IFPIntegration.CalculateTargetBlend(currentOffset, mod.ifpBaseHeightCm, isSuppressed)

    local reason = "Stance Update"
    if mod.isPhotoModeOpen then
        reason = "Photo Mode Active (Locomotion Neutralized)"
    elseif mod.currentShoeState.isSuppressed then
        reason = "Suppression (" .. tostring(mod.currentShoeState.suppressionReason) .. ")"
    elseif mod.currentShoeState.hasShoe then
        reason = "Footwear Active (" .. tostring(mod.currentShoeState.displayName) .. ")"
    else
        reason = "Barefoot / Neutral Stance"
    end

    local isTFPForLog = mod.currentShoeState and mod.currentShoeState.isTFP
    Transition.SetTarget(targetBlend, reason, function(msg) Logger.LogFPP(isTFPForLog, "%s", msg) end)
    local activeBlend = Transition.Update(deltaTime, function(msg) Logger.LogFPP(isTFPForLog, "%s", msg) end)

    mod.currentShoeState.totalStanceCm = Transition.GetStanceCm()
    IFPIntegration.ApplyBlend(player, activeBlend)
end)

-- -----------------------------------------------------------------------------
-- Dear ImGui Overlay Event
-- -----------------------------------------------------------------------------
registerForEvent("onDraw", function()
    if not mod.isOverlayOpen then return end

    RefreshIFPBaseHeight()

    local player = Game.GetPlayer()
    local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")

    IFPIntegration.DrawUI(mod, player, sys, FootwearHeightLimits, SaveAllOverrides)
end)

return mod
