-- =============================================================================
-- Immersive Footwear POV - Cyber Engine Tweaks (CET) Core Orchestrator
-- Dynamically combines IFP base height slider + footwear heel height
-- Features smooth 0.20s transitions and context-aware suppression
-- Modular architecture with dedicated integrations in ./integrations/
-- =============================================================================

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
    overridesFile = "user_shoe_overrides.json",
    overrides = {},
    lastEquippedKey = "",
    debugLogs = false,
    
    -- Smooth Transition State
    TRANSITION_DURATION = 0.20,
    currentBlend = 0.50,
    startBlend = 0.50,
    targetBlend = 0.50,
    transitionElapsed = 0.20,
    isTransitioning = false,

    -- Photo Mode State
    isPhotoModeOpen = false,
    autoElevatePMPlatform = true,

    currentShoeState = {
        key = "",
        displayName = "None",
        source = "None",
        isOfficial = false,
        hasShoe = false,
        heelCm = 0.0,
        platformCm = 0.0,
        effectiveCm = 0.0,
        totalStanceCm = 0.0,
        isSuppressed = false,
        suppressionReason = ""
    }
}

-- -----------------------------------------------------------------------------
-- Debug Logging Helper
-- -----------------------------------------------------------------------------
local function LogFPP(fmt, ...)
    if mod.debugLogs then
        print(string.format("[ImmersiveFootwearPOV][FPP] " .. fmt, ...))
    end
end

-- -----------------------------------------------------------------------------
-- Mathematical Easing Function (Smoothstep)
-- -----------------------------------------------------------------------------
local function smoothstep(t)
    t = math.max(0.0, math.min(1.0, t))
    return t * t * (3.0 - 2.0 * t)
end

-- -----------------------------------------------------------------------------
-- JSON Persistence for Custom Per-Shoe Height Overrides & Settings
-- -----------------------------------------------------------------------------
local function LoadOverrides()
    local file = io.open(mod.overridesFile, "r")
    if file then
        local content = file:read("*a")
        file:close()
        if content and #content > 0 then
            local success, data = pcall(function() return json.decode(content) end)
            if success and type(data) == "table" then
                mod.overrides = data
                if data["__settings"] then
                    if data["__settings"].autoElevatePM ~= nil then
                        mod.autoElevatePMPlatform = data["__settings"].autoElevatePM
                    else
                        mod.autoElevatePMPlatform = true
                    end
                    if data["__settings"].debugLogs ~= nil then
                        mod.debugLogs = (data["__settings"].debugLogs == true)
                    else
                        mod.debugLogs = false
                    end
                else
                    mod.autoElevatePMPlatform = true
                    mod.debugLogs = false
                end
                local count = 0
                for k in pairs(mod.overrides) do
                    if k ~= "__settings" then count = count + 1 end
                end
                print(string.format("[ImmersiveFootwearPOV] Loaded %d custom shoe override(s) from %s (Debug Logs: %s).",
                    count, mod.overridesFile, mod.debugLogs and "ON" or "OFF"))
                return
            end
        end
    end
    mod.overrides = {}
    mod.autoElevatePMPlatform = true
    mod.debugLogs = false
end

local function SaveOverrides()
    local file = io.open(mod.overridesFile, "w")
    if file then
        mod.overrides["__settings"] = {
            autoElevatePM = (mod.autoElevatePMPlatform ~= false),
            debugLogs = (mod.debugLogs == true)
        }
        local success, encoded = pcall(function() return json.encode(mod.overrides) end)
        if success and encoded then
            file:write(encoded)
        end
        file:close()
    end
end

-- -----------------------------------------------------------------------------
-- Smooth Transition Management
-- -----------------------------------------------------------------------------
local function SetTargetBlend(newTarget, reason)
    newTarget = math.max(0.0, math.min(1.0, newTarget))
    if math.abs(newTarget - mod.targetBlend) < 0.0001 then
        return
    end

    local startStanceCm = (mod.currentBlend * 1.00 - 0.50) * 100.0
    local targetStanceCm = (newTarget * 1.00 - 0.50) * 100.0
    LogFPP("Transition started: Blend %.3f (%+.1f cm) -> %.3f (%+.1f cm) over %.2fs | Trigger: %s",
        mod.currentBlend, startStanceCm, newTarget, targetStanceCm, mod.TRANSITION_DURATION, reason or "State Update")

    mod.startBlend = mod.currentBlend
    mod.targetBlend = newTarget
    mod.transitionElapsed = 0.0
    mod.isTransitioning = true
end

local function UpdateTransition(deltaTime)
    if mod.transitionElapsed >= mod.TRANSITION_DURATION then
        if mod.isTransitioning then
            mod.isTransitioning = false
            local settledStanceCm = (mod.targetBlend * 1.00 - 0.50) * 100.0
            LogFPP("Transition settled: Blend %.3f (Stance: %+.1f cm)", mod.targetBlend, settledStanceCm)
        end
        mod.currentBlend = mod.targetBlend
    else
        mod.transitionElapsed = math.min(
            mod.TRANSITION_DURATION,
            mod.transitionElapsed + math.max(tonumber(deltaTime) or 0.0, 0.0)
        )
        local progress = mod.TRANSITION_DURATION <= 0.0
            and 1.0
            or mod.transitionElapsed / mod.TRANSITION_DURATION
        local eased = smoothstep(progress)
        mod.currentBlend = mod.startBlend + (mod.targetBlend - mod.startBlend) * eased
        if mod.transitionElapsed >= mod.TRANSITION_DURATION then
            mod.isTransitioning = false
            local settledStanceCm = (mod.targetBlend * 1.00 - 0.50) * 100.0
            LogFPP("Transition settled: Blend %.3f (Stance: %+.1f cm)", mod.targetBlend, settledStanceCm)
        end
    end
    return mod.currentBlend
end

-- -----------------------------------------------------------------------------
-- Synchronize Shoe State with REDscript System
-- -----------------------------------------------------------------------------
local function SyncShoeState(player, sys)
    if not player or not sys then return end

    -- Sync debug mode to REDscript system
    pcall(function()
        if sys.SetDebugLogging and sys:IsDebugLogging() ~= mod.debugLogs then
            sys:SetDebugLogging(mod.debugLogs)
        end
    end)

    local shoeID = sys:GetEquippedFootwearID()
    local hasShoe = shoeID and shoeID.hash ~= 0
    local shoeKey = sys:GetResolvedShoeTDBIDString()
    local isOfficial = sys:HasOfficialTweakTags()
    local sourceName = sys:GetActiveSource()
    local displayName = sys:GetResolvedShoeDisplayName()

    -- Check suppression from both REDscript system and IFP bridge
    local isRedscriptSuppressed = sys:IsSuppressed()
    local redscriptReason = sys:GetSuppressionReason()
    local ifpHeight, ifpSuppressedReason = IFPIntegration.GetState()

    mod.ifpBaseHeightCm = ifpHeight
    local isSuppressed = isRedscriptSuppressed or (ifpSuppressedReason ~= nil) or mod.isPhotoModeOpen
    local suppressionReason = isRedscriptSuppressed and redscriptReason or (ifpSuppressedReason or (mod.isPhotoModeOpen and "Photo Mode" or ""))

    mod.currentShoeState.hasShoe = hasShoe
    mod.currentShoeState.key = shoeKey
    mod.currentShoeState.source = sourceName
    mod.currentShoeState.displayName = displayName
    mod.currentShoeState.isOfficial = isOfficial
    mod.currentShoeState.isSuppressed = isSuppressed
    mod.currentShoeState.suppressionReason = suppressionReason

    if hasShoe and #shoeKey > 0 then
        if isOfficial then
            -- Official TweakDB tags found -> Discard obsolete custom override if one was saved
            if mod.overrides[shoeKey] then
                mod.overrides[shoeKey] = nil
                SaveOverrides()
            end
            mod.currentShoeState.heelCm = sys:GetCurrentHeelHeight() * 100.0
            mod.currentShoeState.platformCm = sys:GetCurrentPlatformHeight() * 100.0
        else
            -- Untagged shoe -> Check persistent JSON overrides
            local saved = mod.overrides[shoeKey]
            if saved then
                local heelCm = tonumber(saved.heel) or 0.0
                local platCm = tonumber(saved.platform) or 0.0
                local heelMeters = heelCm / 100.0
                local platMeters = platCm / 100.0

                -- Ensure custom override is active in REDscript
                if not sys:HasCustomOverride() or shoeKey ~= mod.lastEquippedKey or math.abs(sys:GetCurrentHeelHeight() - heelMeters) > 0.0005 then
                    sys:SetCustomHeightOverride(player, heelMeters, platMeters)
                end
                mod.currentShoeState.heelCm = heelCm
                mod.currentShoeState.platformCm = platCm
            else
                -- No saved override -> Ensure clean 0.0 baseline
                if sys:HasCustomOverride() or shoeKey ~= mod.lastEquippedKey then
                    sys:ClearCustomHeightOverride(player)
                end
                mod.currentShoeState.heelCm = 0.0
                mod.currentShoeState.platformCm = 0.0
            end
        end
        mod.lastEquippedKey = shoeKey
    else
        mod.currentShoeState.heelCm = 0.0
        mod.currentShoeState.platformCm = 0.0
        mod.lastEquippedKey = ""
    end

    mod.currentShoeState.effectiveCm = sys:GetEffectiveOffset() * 100.0
end

-- -----------------------------------------------------------------------------
-- Console API & Diagnostics Functions
-- -----------------------------------------------------------------------------
function mod.SetDebug(enabled)
    if enabled == nil then
        mod.debugLogs = not mod.debugLogs
    else
        mod.debugLogs = (enabled == true)
    end
    SaveOverrides()

    local player = Game.GetPlayer()
    if player then
        local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
        if sys and sys.SetDebugLogging then
            pcall(function() sys:SetDebugLogging(mod.debugLogs) end)
        end
    end

    print(string.format("[ImmersiveFootwearPOV] Debug logging is now: %s", mod.debugLogs and "ENABLED" or "DISABLED"))
    return mod.debugLogs
end

function mod.ToggleDebug()
    return mod.SetDebug(not mod.debugLogs)
end

function mod.GetDebug()
    return mod.debugLogs
end

function mod.DumpState()
    local shoe = mod.currentShoeState
    print("================ [Immersive Footwear POV Diagnostics] ================")
    print(string.format(" Debug Logging:     %s", mod.debugLogs and "ENABLED" or "DISABLED"))
    print(string.format(" Photo Mode Active: %s (Auto-Elevate: %s)", tostring(mod.isPhotoModeOpen), tostring(mod.autoElevatePMPlatform)))
    print(string.format(" Equipped Footwear: %s", tostring(shoe.displayName)))
    print(string.format(" Item TDBID String: %s", tostring(shoe.key)))
    print(string.format(" Resolution Source: %s (Official Tags: %s)", tostring(shoe.source), tostring(shoe.isOfficial)))
    print(string.format(" Heel Height (FPP): +%.1f cm (%.4f m)", shoe.heelCm, shoe.heelCm / 100.0))
    print(string.format(" Platform Sole (PM):+%.1f cm (%.4f m)", shoe.platformCm, shoe.platformCm / 100.0))
    print(string.format(" IFP Base Height:   %+d cm", math.floor(mod.ifpBaseHeightCm + 0.5)))
    print(string.format(" Effective Shoe Lift:+%.1f cm", shoe.effectiveCm))
    print(string.format(" Current Blend:     %.4f (Stance: %+.1f cm)", mod.currentBlend, (mod.currentBlend - 0.50) * 100.0))
    print(string.format(" Target Blend:      %.4f (Stance: %+.1f cm)", mod.targetBlend, (mod.targetBlend - 0.50) * 100.0))
    print(string.format(" Is Suppressed:     %s (Reason: '%s')", tostring(shoe.isSuppressed), tostring(shoe.suppressionReason)))
    print("=====================================================================")
end

-- Global CET Console shortcut aliases
ToggleIFPDebug = function() return mod.ToggleDebug() end
IFPDebug = function(enabled) return mod.SetDebug(enabled) end
IFPStatus = function() mod.DumpState() end

-- -----------------------------------------------------------------------------
-- CET Lifecycle Events
-- -----------------------------------------------------------------------------
registerForEvent("onInit", function()
    LoadOverrides()
    PMIntegration.Init(mod)
    local height, _ = IFPIntegration.GetState()
    mod.ifpBaseHeightCm = height
    print(string.format("[ImmersiveFootwearPOV] Initialized with IFP Base Height: %.1f cm | Debug: %s",
        mod.ifpBaseHeightCm, mod.debugLogs and "ENABLED" or "DISABLED"))
end)

registerForEvent("onOverlayOpen", function()
    mod.isOverlayOpen = true
    local height, _ = IFPIntegration.GetState()
    mod.ifpBaseHeightCm = height
end)

registerForEvent("onOverlayClose", function()
    mod.isOverlayOpen = false
    local height, _ = IFPIntegration.GetState()
    mod.ifpBaseHeightCm = height
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
        SyncShoeState(player, sys)
    end

    -- Poll IFP base height periodically (or every frame in overlay)
    mod.ifpPollTimer = mod.ifpPollTimer + deltaTime
    if mod.ifpPollTimer >= 0.10 or mod.isOverlayOpen then
        mod.ifpPollTimer = 0.0
        local height, _ = IFPIntegration.GetState()
        mod.ifpBaseHeightCm = height
    end

    -- Calculate target blend based on current shoe offset, IFP base slider, and suppression state
    local currentOffset = sys:GetEffectiveOffset()
    local isSuppressed = mod.currentShoeState.isSuppressed or mod.isPhotoModeOpen
    local targetBlend, totalMeters = IFPIntegration.CalculateTargetBlend(currentOffset, mod.ifpBaseHeightCm, isSuppressed)
    
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

    SetTargetBlend(targetBlend, reason)
    local activeBlend = UpdateTransition(deltaTime)
    
    mod.currentShoeState.totalStanceCm = (activeBlend * 1.00 - 0.50) * 100.0
    IFPIntegration.ApplyBlend(player, activeBlend)
    PMIntegration.OnUpdate(deltaTime)
end)

-- -----------------------------------------------------------------------------
-- Dear ImGui Overlay Event
-- -----------------------------------------------------------------------------
registerForEvent("onDraw", function()
    if not mod.isOverlayOpen then return end

    -- Update IFP base height in real-time while overlay is open
    local liveHeight, _ = IFPIntegration.GetState()
    mod.ifpBaseHeightCm = liveHeight

    local player = Game.GetPlayer()
    local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")

    IFPIntegration.DrawUI(mod, player, sys, FootwearHeightLimits, SaveOverrides)
end)

return mod
