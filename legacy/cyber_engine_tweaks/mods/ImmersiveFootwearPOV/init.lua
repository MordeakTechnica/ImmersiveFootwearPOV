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
local ITPIntegration = require("integrations/itp")

-- -----------------------------------------------------------------------------
-- Global Height Configuration Limits
-- -----------------------------------------------------------------------------
local FootwearHeightLimits = {
    MAX_HEEL_CM = 40.0,
    MAX_PLATFORM_CM = 30.0,
    MAX_IFP_CM = 25.0,
}

local mod = {
    lastEquippedKey = "",
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
local lastPlayerHash = nil
local lastSentITP = nil
local lastSentIFP = nil
local cachedIsTFP = nil

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

local function SaveSettings()
    Config.SaveSettings({
        autoElevatePM = mod.autoElevatePMPlatform,
        debugLogs = mod.debugLogs,
        enableHipSway = mod.enableHipSway,
        swayLow = mod.swayLow,
        swayMid = mod.swayMid,
        swayHigh = mod.swayHigh,
    })
end

local function SyncOverridesToREDscript()
    local sys = GetSystem()
    if not sys or not sys.ClearCustomOverrides then return end
    sys:ClearCustomOverrides()
    if mod.overrides then
        for key, data in pairs(mod.overrides) do
            local heel = (tonumber(data.heel) or 0.0) / 100.0
            local plat = (tonumber(data.platform) or 0.0) / 100.0
            sys:RegisterCustomOverride(key, heel, plat)
        end
    end
    local player = Game.GetPlayer()
    if player and sys.UpdateEquippedFootwear then
        sys:UpdateEquippedFootwear(player)
    end
end
mod.SyncOverridesToREDscript = SyncOverridesToREDscript

local function SaveOverrides()
    Config.SaveOverrides(mod.userOverrides or mod.overrides)
    SyncOverridesToREDscript()
end

-- Maintained for backward compatibility
local function SaveAllOverrides()
    SaveOverrides()
    SaveSettings()
end

local function RefreshIFPBaseHeight()
    local height, suppressed = IFPIntegration.GetState()
    mod.ifpBaseHeightCm = height
    mod.ifpSuppressedReason = suppressed
    mod.ifpHeightAdjustmentEnabled = IFPIntegration.IsHeightAdjustmentEnabled(false)
    return height
end

-- -----------------------------------------------------------------------------
-- Console API & Diagnostics (Delegated to ConsoleManager)
-- -----------------------------------------------------------------------------
function mod.SetDebug(enabled)
    return ConsoleManager.SetDebug(mod, enabled, SaveSettings)
end

function mod.ToggleDebug()
    return ConsoleManager.ToggleDebug(mod, SaveSettings)
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
    return ConsoleManager.SetCustomHeight(mod, sys, player, FootwearHeightLimits, heelCm, platformCm, SaveOverrides)
end

function mod.ReloadPresets()
    local overrides, settings, presets, userOverrides = Config.Load(Config.FILE_NAME)
    mod.overrides = overrides
    mod.presets = presets or {}
    mod.userOverrides = userOverrides or {}
    SyncOverridesToREDscript()
    local count = 0
    for _ in pairs(mod.presets) do count = count + 1 end
    local msg = string.format("Reloaded presets: %d total preset(s) active in master presets.", count)
    print(string.format("[ImmersiveFootwearPOV] %s", msg))
    return msg
end

function mod.GetPresetCount()
    local count = 0
    if mod.presets then
        for _ in pairs(mod.presets) do count = count + 1 end
    end
    local userCount = 0
    if mod.userOverrides then
        for _ in pairs(mod.userOverrides) do userCount = userCount + 1 end
    end
    local msg = string.format("Presets Loaded: %d | User Overrides: %d", count, userCount)
    print(string.format("[ImmersiveFootwearPOV] %s", msg))
    return msg
end

-- Register global CET Console shortcuts
ConsoleManager.RegisterShortcuts(mod)

-- -----------------------------------------------------------------------------
-- Lifecycle Events
-- -----------------------------------------------------------------------------
registerForEvent("onInit", function()
    -- Check if config.json exists; if not, run migration script before settings and config are read
    local configPath = Config.SETTINGS_FILE or "config.json"
    local configFile = io.open(configPath, "r")
    if not configFile then
        Config.MigrateLegacySettings()
    else
        configFile:close()
    end

    local overrides, settings, presets, userOverrides = Config.Load(Config.FILE_NAME)
    mod.overrides = overrides
    mod.presets = presets or {}
    mod.userOverrides = userOverrides or {}
    mod.autoElevatePMPlatform = settings.autoElevatePM
    mod.debugLogs = settings.debugLogs
    mod.enableHipSway = settings.enableHipSway
    mod.swayLow = settings.swayLow or 1.0
    mod.swayMid = settings.swayMid or 1.0
    mod.swayHigh = settings.swayHigh or 1.0
    Logger.Init(mod.debugLogs)
    Stride.Init()

    PMIntegration.Init(mod)
    ITPIntegration.modState = mod
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

    SyncOverridesToREDscript()

    local player = Game.GetPlayer()
    if player and sys then
        State.Sync(player, sys, mod.overrides, mod, IFPIntegration, SaveOverrides)
    end

    ConsoleManager.RegisterShortcuts(mod)

    print(string.format("[ImmersiveFootwearPOV] Initialized | ITP: %s (API: %s) | IFP: %s (Enabled: %s, Height Adj: %s, Base: %.1f cm) | Hip Sway: %s | Debug: %s",
        itpInstalled and "ACTIVE" or "ABSENT",
        ITPIntegration.HasGroundLevelApi() and "AVAILABLE" or "LEGACY",
        ifpInstalled and "ACTIVE" or "ABSENT",
        ifpEnabled and "YES" or "NO",
        ifpHeightEnabled and "YES" or "NO",
        mod.ifpBaseHeightCm,
        mod.enableHipSway and "ENABLED" or "DISABLED",
        mod.debugLogs and "ENABLED" or "DISABLED"))
end)

registerForEvent("onSessionStart", function()
    mod.isSyncedToREDscript = false
    lastPlayerHash = nil
    mod.lastEquippedKey = ""
    mod.lastSysHeel = nil
    mod.lastSysPlat = nil
    mod.lastSysSuppressed = nil
    mod.lastSysInVehicle = nil
    mod.lastSysInWorkspot = nil
    mod.lastIsSuppressed = nil
    mod.ifpSuppressedReason = nil
    mod.footwearPollTimer = 0.0
    cachedIsTFP = nil
end)

registerForEvent("onSessionEnd", function()
    ITPIntegration.ReleaseGroundOffset()
    mod.isSyncedToREDscript = false
    lastPlayerHash = nil
    mod.lastEquippedKey = ""
    mod.lastSysHeel = nil
    mod.lastSysPlat = nil
    mod.lastSysSuppressed = nil
    mod.lastSysInVehicle = nil
    mod.lastSysInWorkspot = nil
    mod.lastIsSuppressed = nil
    mod.ifpSuppressedReason = nil
    mod.footwearPollTimer = 0.0
    cachedSys = nil
    cachedIsTFP = nil
end)

registerForEvent("onOverlayOpen", function()
    mod.isOverlayOpen = true
    RefreshIFPBaseHeight()
    local player = Game.GetPlayer()
    local sys = GetSystem()
    if player and sys then
        State.Sync(player, sys, mod.overrides, mod, IFPIntegration, SaveOverrides)
    end
end)

registerForEvent("onOverlayClose", function()
    mod.isOverlayOpen = false
    RefreshIFPBaseHeight()
    SyncOverridesToREDscript()
end)

local function DetermineViewSwitchContext(player, sys, mod, isITPActive)
    local inVehicle = (sys and sys.IsInVehicle and sys:IsInVehicle()) or false
    if not inVehicle and player and VehicleComponent and VehicleComponent.IsMountedToVehicle then
        pcall(function() inVehicle = VehicleComponent.IsMountedToVehicle(player:GetGame(), player) end)
    end
    if inVehicle then
        return isITPActive and "Vehicle Occupancy (Vehicle 3rd-Person Chase Camera)" or "Vehicle Occupancy (Vehicle 1st-Person Cockpit Camera)"
    end

    local inWorkspot = (sys and sys.IsInWorkspot and sys:IsInWorkspot()) or false
    if not inWorkspot and player and Game.GetWorkspotSystem then
        pcall(function() inWorkspot = Game.GetWorkspotSystem():IsActorInWorkspot(player) end)
    end
    if inWorkspot then
        return isITPActive and "Authored Workspot (3rd-Person / External Camera: Chair, Vending Machine, Furniture)" or "Authored Workspot (1st-Person Workspot Camera)"
    end

    if mod.isPhotoModeOpen or (sys and sys.IsPhotoModeActive and sys:IsPhotoModeActive()) then
        return "Photo Mode Camera"
    end

    local isScene = false
    pcall(function()
        if player and player.GetPlayerStateMachineBlackboard then
            local psm = player:GetPlayerStateMachineBlackboard()
            local psmDefs = GetAllBlackboardDefs().PlayerStateMachine
            if psm and psmDefs then
                local sceneTier = psm:GetInt(psmDefs.SceneTier)
                if sceneTier >= 3 or sceneTier <= 0 then
                    isScene = true
                end
            end
        end
    end)
    if isScene then
        return "Scripted Dialogue / Quest Scene Camera"
    end

    return isITPActive and "Manual Camera Toggle / ITP Activated (On-Foot 3rd Person)" or "Manual Camera Toggle / ITP Deactivated (On-Foot 1st Person)"
end

registerForEvent("onUpdate", function(deltaTime)
    local player = Game.GetPlayer()
    if not player then
        lastPlayerHash = nil
        return
    end

    local sys = GetSystem()
    if not sys then return end

    -- Extract stable 64-bit entity hash for player identity comparison
    -- (Comparing Sol userdata wrappers with ~= always evaluates to true, breaking per-frame caching)
    local playerHash = nil
    pcall(function()
        local entityId = player:GetEntityID()
        if entityId then
            playerHash = entityId.hash
        end
    end)

    -- Initial synchronization when player and system become available in gameplay
    -- Runs ONCE per session load, or when the player entity changes (e.g. cutscene puppet change)
    if not mod.isSyncedToREDscript or (playerHash and playerHash ~= lastPlayerHash) then
        local isInitialSessionSync = not mod.isSyncedToREDscript
        lastPlayerHash = playerHash
        mod.isSyncedToREDscript = true

        if isInitialSessionSync then
            SyncOverridesToREDscript()
        else
            if sys.UpdateEquippedFootwear then
                sys:UpdateEquippedFootwear(player)
            end
        end

        State.Sync(player, sys, mod.overrides, mod, IFPIntegration, SaveOverrides)
        mod.lastEquippedKey = (sys.GetResolvedShoeTDBIDString and sys:GetResolvedShoeTDBIDString()) or ""
        mod.lastSysHeel = (sys.GetCurrentHeelHeight and sys:GetCurrentHeelHeight()) or 0.0
        mod.lastSysPlat = (sys.GetCurrentPlatformHeight and sys:GetCurrentPlatformHeight()) or 0.0
        mod.lastSysSuppressed = (sys.IsSuppressed and sys:IsSuppressed()) or false
    end

    -- Lightweight footwear polling timer (0.25s)
    -- Guarantees equipped shoes and heights are resolved as soon as items stream in after loading
    mod.footwearPollTimer = (mod.footwearPollTimer or 0.0) + deltaTime
    if mod.footwearPollTimer >= 0.25 then
        mod.footwearPollTimer = 0.0
        if sys.UpdateEquippedFootwear then
            sys:UpdateEquippedFootwear(player)
        end
    end

    -- Event-driven footwear state sync: syncs when footwear, heights, or suppression change in REDscript
    local shoeKey = (sys.GetResolvedShoeTDBIDString and sys:GetResolvedShoeTDBIDString()) or ""
    local currentSysHeel = (sys.GetCurrentHeelHeight and sys:GetCurrentHeelHeight()) or 0.0
    local currentSysPlat = (sys.GetCurrentPlatformHeight and sys:GetCurrentPlatformHeight()) or 0.0
    local currentSysSuppressed = (sys.IsSuppressed and sys:IsSuppressed()) or false

    if shoeKey ~= mod.lastEquippedKey
       or math.abs(currentSysHeel - (mod.lastSysHeel or 0.0)) > 0.0005
       or math.abs(currentSysPlat - (mod.lastSysPlat or 0.0)) > 0.0005
       or currentSysSuppressed ~= mod.lastSysSuppressed then
        mod.lastEquippedKey = shoeKey
        mod.lastSysHeel = currentSysHeel
        mod.lastSysPlat = currentSysPlat
        mod.lastSysSuppressed = currentSysSuppressed
        State.Sync(player, sys, mod.overrides, mod, IFPIntegration, SaveOverrides)
    end

    -- Update Photo Mode platform lift once per frame (very cheap 2 booleans when inactive)
    PMIntegration.OnUpdate(deltaTime)

    -- Check vehicle and workspot state from REDscript system
    local currentSysInVehicle = (sys.IsInVehicle and sys:IsInVehicle()) or false
    local currentSysInWorkspot = (sys.IsInWorkspot and sys:IsInWorkspot()) or false

    -- Detect and log Vehicle entry/exit with explicit actions taken
    if mod.lastSysInVehicle ~= nil and currentSysInVehicle ~= mod.lastSysInVehicle then
        if currentSysInVehicle then
            Logger.LogFile("Vehicle entered: Action: Enforcing Vehicle Occupancy suppression (neutralizing stance to 0.0 cm / blend 0.50). Releasing ITP ground lease | Shoe: %s | Heel: %.1f cm | Platform: %.1f cm",
                tostring(mod.currentShoeState.displayName),
                mod.currentShoeState.heelCm or 0.0,
                mod.currentShoeState.platformCm or 0.0)
        else
            Logger.LogFile("Vehicle exited: Action: Clearing Vehicle Occupancy suppression (restoring footwear elevation). Setting target stance to %+.1f cm | Shoe: %s | Heel: %.1f cm | Platform: %.1f cm",
                mod.currentShoeState.heelCm or 0.0,
                tostring(mod.currentShoeState.displayName),
                mod.currentShoeState.heelCm or 0.0,
                mod.currentShoeState.platformCm or 0.0)
        end
    end
    mod.lastSysInVehicle = currentSysInVehicle

    -- Detect and log Workspot entry/exit with explicit actions taken
    if mod.lastSysInWorkspot ~= nil and currentSysInWorkspot ~= mod.lastSysInWorkspot then
        if currentSysInWorkspot then
            Logger.LogFile("Workspot activated (Chair/Vending Machine/Furniture): Action: Enforcing Authored Workspot suppression (neutralizing stance to 0.0 cm / blend 0.50). Releasing ITP ground lease | Shoe: %s | Heel: %.1f cm | Platform: %.1f cm",
                tostring(mod.currentShoeState.displayName),
                mod.currentShoeState.heelCm or 0.0,
                mod.currentShoeState.platformCm or 0.0)
        else
            Logger.LogFile("Workspot finished (Standing/Exited): Action: Clearing Authored Workspot suppression (restoring footwear elevation). Setting target stance to %+.1f cm | Shoe: %s | Heel: %.1f cm | Platform: %.1f cm",
                mod.currentShoeState.heelCm or 0.0,
                tostring(mod.currentShoeState.displayName),
                mod.currentShoeState.heelCm or 0.0,
                mod.currentShoeState.platformCm or 0.0)
        end
    end
    mod.lastSysInWorkspot = currentSysInWorkspot

    -- Resolve suppression state and reason
    local isSuppressed = currentSysSuppressed or (mod.ifpSuppressedReason ~= nil) or mod.isPhotoModeOpen or currentSysInVehicle or currentSysInWorkspot
    mod.currentShoeState.isSuppressed = isSuppressed
    if isSuppressed then
        if currentSysInVehicle then
            mod.currentShoeState.suppressionReason = "Vehicle Occupancy"
        elseif currentSysInWorkspot then
            mod.currentShoeState.suppressionReason = "Authored Workspot"
        elseif currentSysSuppressed then
            mod.currentShoeState.suppressionReason = (sys.GetSuppressionReason and sys:GetSuppressionReason()) or "Suppressed"
        elseif mod.ifpSuppressedReason ~= nil then
            mod.currentShoeState.suppressionReason = mod.ifpSuppressedReason
        elseif mod.isPhotoModeOpen then
            mod.currentShoeState.suppressionReason = "Photo Mode"
        end
    else
        mod.currentShoeState.suppressionReason = ""
    end

    -- Safety check: ensure suppression is active if player is in vehicle or workspot
    if (currentSysInVehicle or currentSysInWorkspot) and not isSuppressed then
        Logger.Warn("SUPPRESSION", "Player is in vehicle (%s) or workspot (%s) but isSuppressed was false! Forcing suppression.", tostring(currentSysInVehicle), tostring(currentSysInWorkspot))
        isSuppressed = true
        mod.currentShoeState.isSuppressed = true
        mod.currentShoeState.suppressionReason = currentSysInVehicle and "Vehicle Occupancy" or "Authored Workspot"
    end

    -- Detect and log generic suppression changes (e.g. Scenes, Ladders)
    if mod.lastIsSuppressed ~= nil and isSuppressed ~= mod.lastIsSuppressed and currentSysInVehicle == mod.lastSysInVehicle and currentSysInWorkspot == mod.lastSysInWorkspot then
        local reason = mod.currentShoeState.suppressionReason or "Suppressed"
        if isSuppressed then
            Logger.LogFile("Suppression activated ('%s'): Action: Neutralizing footwear elevation (0.0 cm / blend 0.50). Releasing ITP ground lease | Shoe: %s",
                reason, tostring(mod.currentShoeState.displayName))
        else
            Logger.LogFile("Suppression cleared: Action: Restoring footwear elevation to %+.1f cm | Shoe: %s",
                mod.currentShoeState.heelCm or 0.0, tostring(mod.currentShoeState.displayName))
        end
    end
    mod.lastIsSuppressed = isSuppressed

    -- Detect if Immersive Third Person (ITP) camera is currently active
    local isITPActive = (Perspective and Perspective.IsTPPActive and Perspective.IsTPPActive(player, sys)) or false
    if isITPActive ~= mod.isITPActive then
        local wasITP = mod.isITPActive
        mod.isITPActive = isITPActive

        local triggerContext = DetermineViewSwitchContext(player, sys, mod, isITPActive)
        local shoeName = tostring(mod.currentShoeState.displayName)
        local heelCm = mod.currentShoeState.heelCm or 0.0
        local platCm = mod.currentShoeState.platformCm or 0.0
        local actionTaken = ""

        if isITPActive then
            if isSuppressed then
                actionTaken = string.format("Suppression active ('%s') -> 3rd-person elevation neutralized (0.0 cm), FPP skeletal blend held neutral (0.50), ITP ground lease released, stride/sway reset",
                    tostring(mod.currentShoeState.suppressionReason))
            else
                if ITPIntegration.IsLeaseHeld() and platCm > 0.05 then
                    actionTaken = string.format("Active ITP ground elevation lease (+%.1f mm, priority %d), held FPP skeletal blend neutral (0.50), reset IFP blend cache and stride/sway",
                        platCm * 10.0, ITPIntegration.PRIORITY)
                elseif platCm > 0.05 then
                    actionTaken = string.format("Applying 3rd-person platform elevation (+%.1f cm via foot_elevation_offset/ITP), held FPP skeletal blend neutral (0.50), reset IFP blend cache and stride/sway",
                        platCm)
                else
                    actionTaken = "Neutral 3rd-person elevation (0.0 cm platform), held FPP skeletal blend neutral (0.50), reset stride/sway"
                end
            end
        else
            if isSuppressed then
                actionTaken = string.format("Released ITP ground lease, reset puppet foot_elevation_offset to 0.0m, suppression active ('%s') -> FPP skeletal blend held neutral (0.50)",
                    tostring(mod.currentShoeState.suppressionReason))
            else
                local estTarget = 0.50 + ((mod.ifpBaseHeightCm or 0.0) + heelCm) / 100.0
                actionTaken = string.format("Released ITP ground lease, reset puppet foot_elevation_offset to 0.0m, restoring FPP skeletal height blend to target %.3f (%+.1f cm) [Heel: %+.1f cm, IFP Base: %+.1f cm], reset IFP blend cache and stride",
                    estTarget, (estTarget - 0.50) * 100.0, heelCm, mod.ifpBaseHeightCm or 0.0)
            end
        end

        Logger.LogFile("View Switched: %s -> %s | Trigger: %s | Action Taken: %s | Shoe: %s | Heel: %.1f cm | Platform: %.1f cm",
            wasITP and "3rd Person (ITP/TPP)" or "1st Person (FPP)",
            isITPActive and "3rd Person (ITP/TPP)" or "1st Person (FPP)",
            triggerContext,
            actionTaken,
            shoeName, heelCm, platCm)

        IFPIntegration.ResetBlendCache()
        Stride.Reset(player, sys)

        if not isITPActive then
            -- Returning to First Person (FPP): release ITP ground offset and zero out 3rd-person puppet elevation variable
            ITPIntegration.ReleaseGroundOffset()
            if AnimationControllerComponent and AnimationControllerComponent.SetInputFloat then
                local ok, err = pcall(AnimationControllerComponent.SetInputFloat, player, CName.new("foot_elevation_offset"), 0.0)
                if not ok then
                    Logger.Error("INIT", "Failed to reset foot_elevation_offset to 0.0: %s", tostring(err))
                end
            else
                Logger.Warn("INIT", "AnimationControllerComponent or SetInputFloat unavailable when resetting foot_elevation_offset")
            end
        end
    end

    -- Poll IFP base height periodically (0.25s), or every frame when overlay is open
    mod.ifpPollTimer = mod.ifpPollTimer + deltaTime
    if mod.ifpPollTimer >= 0.25 or mod.isOverlayOpen then
        mod.ifpPollTimer = 0.0
        RefreshIFPBaseHeight()
    end

    stanceContext.forcedBlend = mod.forcedBlend
    stanceContext.isTPPActive = isITPActive
    stanceContext.sys = sys
    stanceContext.shoeState = mod.currentShoeState
    stanceContext.isSuppressed = isSuppressed
    stanceContext.isPhotoModeOpen = mod.isPhotoModeOpen
    stanceContext.ifpInstalled = IFPIntegration.IsInstalled()
    stanceContext.ifpHeightAdjustmentEnabled = mod.ifpHeightAdjustmentEnabled
    stanceContext.ifpBaseHeightCm = mod.ifpBaseHeightCm
    if cachedIsTFP == nil and sys and sys.IsTFPPresent then
        cachedIsTFP = sys:IsTFPPresent()
    end
    stanceContext.isTFP = cachedIsTFP or false

    local targetBlend, footElevationMeters, reason = StanceResolver.ResolveTarget(stanceContext)

    -- Smooth transition handling with static logging callbacks (zero closure allocation)
    Transition.SetTarget(targetBlend, reason, LogTransitionTarget)
    local activeBlend = Transition.Update(deltaTime, LogTransitionSettled)

    mod.currentShoeState.totalStanceCm = Transition.GetStanceCm()

    -- Third-Person Ground Level via ITP API (or animgraph fallback)
    if isITPActive and not isSuppressed then
        local apiActive = ITPIntegration.SetGroundOffset(footElevationMeters, false)
        if apiActive then
            -- Ground level is actively handled by ITP native placed components.
            -- Keep animgraph foot_elevation_offset neutral (0.0) to prevent double elevation.
            IFPIntegration.ApplyBlend(player, activeBlend, 0.0)
        else
            -- Animgraph fallback
            IFPIntegration.ApplyBlend(player, activeBlend, footElevationMeters)
        end
    else
        ITPIntegration.ReleaseGroundOffset()
        IFPIntegration.ApplyBlend(player, activeBlend, 0.0)
    end

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

    UIManager.DrawUI(mod, player, sys, FootwearHeightLimits, SaveOverrides, IFPIntegration, SaveSettings)
end)

return mod
