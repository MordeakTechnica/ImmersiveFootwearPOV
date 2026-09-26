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

function mod.ForceStance(cm, extra)
    -- Support both mod.ForceStance(val) and mod:ForceStance(val)
    if type(cm) == "table" and cm == mod then
        cm = extra
    end
    if cm == nil or tostring(cm):lower() == "clear" or tostring(cm):lower() == "reset" then
        mod.forcedBlend = nil
        local player = Game.GetPlayer()
        if player then
            IFPIntegration.ApplyBlend(player, 0.50, 0.0)
        end
        print("[ImmersiveFootwearPOV] Stance override CLEARED. Dynamic footwear logic resumed.")
        return "Cleared"
    else
        local cmNum = tonumber(cm) or 0.0
        local meters = cmNum / 100.0
        local blend = math.max(0.0, math.min(1.0, (meters + 0.50) / 1.00))
        mod.forcedBlend = blend
        local player = Game.GetPlayer()
        if player then
            IFPIntegration.ApplyBlend(player, blend, meters)
        end
        local msg = string.format("FORCED stance to %+.1f cm (Offset: %.3f m | Blend: %.3f)", cmNum, meters, blend)
        print(string.format("[ImmersiveFootwearPOV] %s", msg))
        Logger.LogFile("%s", msg)
        return msg
    end
end

-- Export global CET Console shortcut aliases to both _G and mod environment
local function RegisterConsoleShortcuts()
    local shortcuts = {
        ToggleIFPDebug = function() return mod.ToggleDebug() end,
        IFPDebug = function(enabled) return mod.SetDebug(enabled) end,
        IFPStatus = function() return mod.DumpState() end,
        ForceStance = function(cm) return mod.ForceStance(cm) end,
        IFPForceStance = function(cm) return mod.ForceStance(cm) end,
    }
    for name, fn in pairs(shortcuts) do
        if _G then
            rawset(_G, name, fn)
        end
    end
end
RegisterConsoleShortcuts()
ToggleIFPDebug = function() return mod.ToggleDebug() end
IFPDebug = function(enabled) return mod.SetDebug(enabled) end
IFPStatus = function() return mod.DumpState() end
ForceStance = function(cm) return mod.ForceStance(cm) end
IFPForceStance = function(cm) return mod.ForceStance(cm) end

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
    RegisterConsoleShortcuts()
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

local function GetCameraWorldPosition(camera)
    if not camera or not camera.GetLocalToWorld then return nil end
    local okTransform, transform = pcall(function() return camera:GetLocalToWorld() end)
    if not okTransform or not transform or not transform.GetTranslation then return nil end
    local okTranslation, translation = pcall(function() return transform:GetTranslation() end)
    if okTranslation and translation and translation.x ~= nil then
        return translation
    end
    return nil
end

local function CheckIsTPPActive(player)
    if not player then return false end

    -- Primary: REDengine CameraSystem distance to active camera
    local cameraSystem = Game.GetCameraSystem and Game.GetCameraSystem()
    if cameraSystem and cameraSystem.GetActiveCameraWorldTransform then
        local transform = (Transform and Transform.new and Transform.new())
            or (WorldTransform and WorldTransform.new and WorldTransform.new())
        if transform and cameraSystem:GetActiveCameraWorldTransform(transform) then
            local activePos = transform.position
            if activePos == nil and transform.GetPosition then activePos = transform:GetPosition() end
            if activePos == nil and transform.GetTranslation then activePos = transform:GetTranslation() end
            if activePos == nil and transform.GetWorldPosition and WorldPosition and WorldPosition.ToVector4 then
                activePos = WorldPosition.ToVector4(transform:GetWorldPosition())
            end
            if activePos and activePos.x ~= nil then
                -- Check against both camera components (matches ITP mod.activeCameraOwner)
                local fppCam = player:FindComponentByName(CName.new("camera"))
                local tppCam = player:FindComponentByName(CName.new("tppCamera"))
                if fppCam and tppCam then
                    local fppWorld = GetCameraWorldPosition(fppCam)
                    local tppWorld = GetCameraWorldPosition(tppCam)
                    if fppWorld and tppWorld then
                        local dfx, dfy, dfz = activePos.x - fppWorld.x, activePos.y - fppWorld.y, activePos.z - fppWorld.z
                        local dtx, dty, dtz = activePos.x - tppWorld.x, activePos.y - tppWorld.y, activePos.z - tppWorld.z
                        local distFPP2 = dfx * dfx + dfy * dfy + dfz * dfz
                        local distTPP2 = dtx * dtx + dty * dty + dtz * dtz
                        return distTPP2 < distFPP2
                    end
                end

                local playerPos = player:GetWorldPosition()
                if playerPos and playerPos.x ~= nil then
                    local dx = activePos.x - playerPos.x
                    local dy = activePos.y - playerPos.y
                    local dz = activePos.z - (playerPos.z + 1.55)
                    local distSq = dx * dx + dy * dy + dz * dz
                    return distSq >= 0.64
                end
            end
        end
    end

    -- Fallback: tppCamera component Y offset (behind player)
    local tppCam = player:FindComponentByName(CName.new("tppCamera"))
    if tppCam and tppCam.GetLocalPosition then
        local ok, pos = pcall(function() return tppCam:GetLocalPosition() end)
        if ok and pos and pos.y ~= nil then
            return (pos.y <= -0.75 or (pos.x ~= nil and math.abs(pos.x) >= 0.40))
        end
    end

    return false
end

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

    -- Detect if Immersive Third Person (ITP) camera is currently active
    local isITPActive = CheckIsTPPActive(player)
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
            -- Returning to First Person (FPP):
            -- Immediately zero out 3rd-person puppet elevation variable
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

    -- Determine stance height based on perspective:
    -- Third Person (ITP Active): Elevate character model with platform height (or forced override)
    -- First Person (FPP): Drive eye level and body via heel height + IFP base slider
    local isTFP = (sys.IsTFPPresent and sys:IsTFPPresent()) or false
    local ifpInstalled = IFPIntegration.IsInstalled()
    local isSuppressed = mod.currentShoeState.isSuppressed or mod.isPhotoModeOpen

    local targetBlend = 0.50
    local footElevationMeters = 0.0
    local reason = "Neutral Baseline"

    if isITPActive then
        -- -------------------------------------------------------------------------
        -- Third Person Perspective (ITP Active)
        -- Elevate character model puppet by platform sole height
        -- -------------------------------------------------------------------------
        if mod.forcedBlend ~= nil then
            targetBlend = mod.forcedBlend
            footElevationMeters = (targetBlend - 0.50) * 1.00
            reason = string.format("Forced Stance Override (Blend: %.3f)", mod.forcedBlend)
        else
            local platOffset = (sys.GetEffectivePlatformOffset and sys:GetEffectivePlatformOffset()) or 0.0
            if platOffset <= 0.0 and mod.currentShoeState and mod.currentShoeState.platformCm then
                platOffset = (mod.currentShoeState.platformCm or 0.0) / 100.0
            end
            footElevationMeters = isSuppressed and 0.0 or platOffset
            targetBlend, _ = IFPIntegration.CalculateTargetBlend(platOffset, 0.0, isSuppressed)
            if mod.isPhotoModeOpen then
                reason = "Photo Mode Active (Locomotion Neutralized)"
            elseif mod.currentShoeState.isSuppressed then
                reason = "Suppression (" .. tostring(mod.currentShoeState.suppressionReason) .. ")"
            else
                reason = string.format("ITP 3rd-Person Active (Platform: +%.1f cm)", (mod.currentShoeState.platformCm or 0.0))
            end
        end
    else
        -- -------------------------------------------------------------------------
        -- First Person Perspective (FPP)
        -- -------------------------------------------------------------------------
        footElevationMeters = 0.0

        if isTFP then
            -- True First Person handles camera height via native REDscript camera matrices
            targetBlend = 0.50
            reason = "True First Person Native (Skeletal Blend Neutral)"
        elseif sys.IsITPPresent and sys:IsITPPresent() and not ifpInstalled then
            -- Pure ITP without IFP installed: First Person operates with zero skeletal offset
            targetBlend = 0.50
            reason = "First Person Neutral Baseline (Identical as in ITP)"
        else
            -- IFP Active (or Standalone): Combine footwear heel height + IFP base slider
            local currentOffset = sys:GetEffectiveOffset()
            targetBlend, _ = IFPIntegration.CalculateTargetBlend(currentOffset, mod.ifpBaseHeightCm, isSuppressed)

            if mod.isPhotoModeOpen then
                reason = "Photo Mode Active (Locomotion Neutralized)"
            elseif mod.currentShoeState.isSuppressed then
                reason = "Suppression (" .. tostring(mod.currentShoeState.suppressionReason) .. ")"
            elseif mod.currentShoeState.hasShoe then
                reason = string.format("Footwear Active (%s: +%.1f cm)", tostring(mod.currentShoeState.displayName), (mod.currentShoeState.heelCm or 0.0))
            else
                reason = "Barefoot / Neutral Stance"
            end
        end
    end

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
