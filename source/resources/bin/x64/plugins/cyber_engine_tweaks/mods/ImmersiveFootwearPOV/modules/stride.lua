-- =============================================================================
-- Immersive Footwear POV - Catwalk Locomotion & Feminine Stride Module
-- Computes real-time pelvic roll, yaw, spine counter-balance, and femoral counter-rotation
-- Powered by native REDscript SwayEvaluator; active exclusively in Immersive Third Person (ITP)
-- Optimized: avoids idle FFI publishing when stationary/zeroed, defers status string formatting
-- =============================================================================

local Stride = {
    -- State variables
    phase = 0.0,
    currentBlend = 0.0,
    currentRoll = 0.0,
    currentYaw = 0.0,
    currentSpineCounterYaw = 0.0,
    currentSpineCounterRoll = 0.0,
    currentLegCounterRoll = 0.0,
    currentHeelScale = 0.0,
    currentPitchCm = 0.0,
    statusText = "Idle",
    hasZeroPublished = false,

    -- Cached CNames for native animation variable publication
    rollVarName = nil,
    yawVarName = nil,
    spineCounterYawVarName = nil,
    spineCounterRollVarName = nil,
    legCounterRollVarName = nil,
    blendVarName = nil,

    -- Catwalk baseline amplitudes (at 10 cm heel height, 1.0x intensity)
    BASE_ROLL_DEG = 4.8,            -- Frontal plane pelvic teeter-totter (Y_Axis, ~4.8° provides ~3cm see-saw difference)
    BASE_YAW_DEG = 3.0,             -- Transverse plane pelvic swivel (Z_Axis, 3.0° forward reach guides stepping leg forward)
    COUNTER_YAW_RATIO = -0.55,      -- Thoracic spine counter-yaw on Spine2 (stabilizes shoulders & arm swing)
    COUNTER_ROLL_RATIO = -1.25,     -- Thoracic spine counter-roll on Spine2 (-1.25 absorbs 100% hip roll + 25% opposite tilt to shoulders)
    COUNTER_LEG_ROLL_RATIO = -0.75, -- Thigh counter-roll on LeftUpLeg & RightUpLeg (stabilizes legs to track straight under pelvis)
}

function Stride.Init()
    if not Stride.rollVarName then
        Stride.rollVarName = CName.new("ifp_hip_sway_roll")
        Stride.yawVarName = CName.new("ifp_hip_sway_yaw")
        Stride.spineCounterYawVarName = CName.new("ifp_spine_counter_yaw")
        Stride.spineCounterRollVarName = CName.new("ifp_spine_counter_roll")
        Stride.legCounterRollVarName = CName.new("ifp_leg_counter_roll")
        Stride.blendVarName = CName.new("ifp_hip_sway_blend")
    end
end

-- -----------------------------------------------------------------------------
-- Main Per-Frame Update Loop
-- Called from init.lua onUpdate
-- Context, suppression, velocity, and heel-scaling are queried from native REDscript
-- -----------------------------------------------------------------------------
function Stride.Update(deltaTime, player, sys, settings)
    if not player or not sys then return end

    local enabled = settings and (settings.enableHipSway ~= false)
    local isOverlayOpen = settings and settings.isOverlayOpen or false

    if sys.UpdateStride then
        local low = tonumber(settings and settings.swayLow) or 1.0
        local mid = tonumber(settings and settings.swayMid) or 1.0
        local high = tonumber(settings and settings.swayHigh) or 1.0

        sys:UpdateStride(player, deltaTime, enabled, low, mid, high, isOverlayOpen)
        return
    end

    Stride.Init()

    -- Master enable check from user settings
    if not enabled then
        if not Stride.hasZeroPublished then
            Stride.currentBlend = 0.0
            Stride.currentRoll = 0.0
            Stride.currentYaw = 0.0
            Stride.currentSpineCounterYaw = 0.0
            Stride.currentSpineCounterRoll = 0.0
            Stride.currentLegCounterRoll = 0.0
            Stride.currentHeelScale = 0.0
            Stride.currentPitchCm = 0.0
            Stride.statusText = "Disabled by User Setting"
            Stride.Publish(player)
        end
        return
    end

    if not sys or not sys.GetSwayContext then
        if not Stride.hasZeroPublished then
            Stride.currentBlend = 0.0
            Stride.currentRoll = 0.0
            Stride.currentYaw = 0.0
            Stride.currentSpineCounterYaw = 0.0
            Stride.currentSpineCounterRoll = 0.0
            Stride.currentLegCounterRoll = 0.0
            Stride.currentHeelScale = 0.0
            Stride.currentPitchCm = 0.0
            Stride.statusText = "System Unavailable"
            Stride.Publish(player)
        end
        return
    end

    -- Query authoritative sway context from native REDscript (SwayEvaluator)
    local ctx = sys:GetSwayContext(player)
    if not ctx then
        return
    end

    local canSway = ctx.canSway
    local heelScale = ctx.heelScale or 0.0
    local speed = ctx.speed or 0.0
    local reason = ctx.suppressionReason or ""
    local pitchCm = ctx.heelPitchCm or 0.0

    Stride.currentHeelScale = heelScale
    Stride.currentPitchCm = pitchCm

    local targetBlend = canSway and 1.0 or 0.0

    -- Smooth attack (0.20s) and decay (0.16s) blend transition
    local blendSpeed = (targetBlend > Stride.currentBlend) and 5.0 or 6.0
    if math.abs(targetBlend - Stride.currentBlend) > 0.001 then
        local delta = (targetBlend - Stride.currentBlend) * blendSpeed * deltaTime
        Stride.currentBlend = Stride.currentBlend + delta
        if Stride.currentBlend < 0.0 then Stride.currentBlend = 0.0 end
        if Stride.currentBlend > 1.0 then Stride.currentBlend = 1.0 end
    else
        Stride.currentBlend = targetBlend
    end

    -- Advance stride phase if moving
    if speed >= 0.15 then
        -- Stride frequency scales with velocity: ~0.8 Hz at walk, ~1.4 Hz at jog
        local freq = math.max(0.6, math.min(2.2, 0.55 + 0.32 * speed))
        Stride.phase = Stride.phase + (2.0 * math.pi * freq * deltaTime)
        if Stride.phase > 2.0 * math.pi then
            Stride.phase = Stride.phase - 2.0 * math.pi
        end
    end

    -- User intensity multiplier per heel category (Low, Mid, High)
    local intensity = 1.0
    if settings then
        local low = tonumber(settings.swayLow) or 1.0
        local mid = tonumber(settings.swayMid) or 1.0
        local high = tonumber(settings.swayHigh) or 1.0

        if pitchCm >= 7.50 then
            intensity = high
        elseif pitchCm >= 5.08 then
            intensity = mid
        elseif pitchCm >= 2.0 then
            intensity = low
        else
            intensity = 0.0
        end
    end

    -- Compute instantaneous anatomical angles
    if Stride.currentBlend > 0.001 then
        -- Smoothly taper down during fast jogging so it doesn't look frantic
        local speedDamp = 1.0
        if speed > 3.0 then
            speedDamp = math.max(0.40, 1.0 - (speed - 3.0) * 0.30)
        end

        local masterScale = heelScale * intensity * Stride.currentBlend * speedDamp
        -- Inverted sine aligns positive Z-rotation with the forward-reaching left leg and negative with the right leg
        Stride.currentYaw = -Stride.BASE_YAW_DEG * math.sin(Stride.phase) * masterScale
        Stride.currentRoll = Stride.BASE_ROLL_DEG * math.cos(Stride.phase) * masterScale
        Stride.currentSpineCounterYaw = Stride.currentYaw * Stride.COUNTER_YAW_RATIO
        Stride.currentSpineCounterRoll = Stride.currentRoll * Stride.COUNTER_ROLL_RATIO
        Stride.currentLegCounterRoll = Stride.currentRoll * Stride.COUNTER_LEG_ROLL_RATIO

        -- Only format detailed status string when the overlay is actually open
        if settings and settings.isOverlayOpen then
            local pitchInches = pitchCm / 2.54
            Stride.statusText = string.format("Active (Roll: %+.1f°, Yaw: %+.1f°, Leg: %+.1f°, Pitch: %.1f cm / %.1f\", Scale: %.0f%%, Speed: %.1f m/s)",
                Stride.currentRoll, Stride.currentYaw, Stride.currentLegCounterRoll, pitchCm, pitchInches, heelScale * 100, speed)
        end
    else
        Stride.currentRoll = 0.0
        Stride.currentYaw = 0.0
        Stride.currentSpineCounterYaw = 0.0
        Stride.currentSpineCounterRoll = 0.0
        Stride.currentLegCounterRoll = 0.0
        if settings and settings.isOverlayOpen then
            Stride.statusText = string.format("Inactive (%s)", reason)
        end
    end

    Stride.Publish(player)
end

-- -----------------------------------------------------------------------------
-- Publishes Current Sway Variables to Character Animation Controller
-- Optimized: skips 6 FFI calls per frame when values are already settled at zero
-- -----------------------------------------------------------------------------
function Stride.Publish(player)
    if not player or not AnimationControllerComponent or not AnimationControllerComponent.SetInputFloat then
        return
    end

    local isZero = (Stride.currentBlend <= 0.0001 and Stride.currentRoll == 0.0 and Stride.currentYaw == 0.0)

    if isZero then
        if Stride.hasZeroPublished then
            return -- Already zeroed out in animgraph, skip redundant native FFI calls
        end
        Stride.hasZeroPublished = true
    else
        Stride.hasZeroPublished = false
    end

    AnimationControllerComponent.SetInputFloat(player, Stride.rollVarName, Stride.currentRoll)
    AnimationControllerComponent.SetInputFloat(player, Stride.yawVarName, Stride.currentYaw)
    AnimationControllerComponent.SetInputFloat(player, Stride.spineCounterYawVarName, Stride.currentSpineCounterYaw)
    AnimationControllerComponent.SetInputFloat(player, Stride.spineCounterRollVarName, Stride.currentSpineCounterRoll)
    AnimationControllerComponent.SetInputFloat(player, Stride.legCounterRollVarName, Stride.currentLegCounterRoll)
    AnimationControllerComponent.SetInputFloat(player, Stride.blendVarName, Stride.currentBlend)
end

-- -----------------------------------------------------------------------------
-- Reset State (On Perspective Switch, Teleport, Death)
-- -----------------------------------------------------------------------------
function Stride.Reset(player, sys)
    if sys and sys.ResetStride and player then
        sys:ResetStride(player)
    end
    Stride.Init()
    Stride.phase = 0.0
    Stride.currentBlend = 0.0
    Stride.currentRoll = 0.0
    Stride.currentYaw = 0.0
    Stride.currentSpineCounterYaw = 0.0
    Stride.currentSpineCounterRoll = 0.0
    Stride.currentLegCounterRoll = 0.0
    Stride.currentHeelScale = 0.0
    Stride.currentPitchCm = 0.0
    Stride.statusText = "Reset"
    Stride.hasZeroPublished = false
    if player and Stride.Publish then
        Stride.Publish(player)
    end
end

function Stride.GetStatus(sys)
    if sys and sys.GetStrideStatus then
        return sys:GetStrideStatus(),
               sys:GetStrideRoll(),
               sys:GetStrideYaw(),
               sys:GetStrideBlend(),
               sys:GetStrideLegCounterRoll(),
               sys:GetStrideHeelScale(),
               sys:GetStridePitchCm()
    end
    return Stride.statusText, Stride.currentRoll, Stride.currentYaw, Stride.currentBlend, Stride.currentLegCounterRoll, Stride.currentHeelScale, Stride.currentPitchCm
end

return Stride
