-- =============================================================================
-- Immersive Footwear POV - Catwalk Locomotion & Feminine Stride Module
-- Computes real-time pelvic roll, yaw, spine counter-balance, and femoral counter-rotation
-- Powered by native REDscript SwayEvaluator; active exclusively in Immersive Third Person (ITP)
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
    statusText = "Idle",

    -- Cached CNames for native animation variable publication
    rollVarName = nil,
    yawVarName = nil,
    spineCounterYawVarName = nil,
    spineCounterRollVarName = nil,
    legCounterRollVarName = nil,
    blendVarName = nil,

    -- Catwalk baseline amplitudes (at 10 cm heel height, 1.0x intensity)
    BASE_ROLL_DEG = 4.8,            -- Frontal plane pelvic teeter-totter (Y_Axis, ~4.8° provides ~3cm see-saw difference)
    BASE_YAW_DEG = 2.0,             -- Transverse plane pelvic swivel (Z_Axis, subtle 2.0° forward reach guides legs straight forward)
    COUNTER_YAW_RATIO = -0.52,      -- Thoracic spine counter-yaw on Spine2 (stabilizes shoulders & arm swing)
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
    Stride.Init()

    -- Master enable check from user settings
    local enabled = settings and (settings.enableHipSway ~= false)
    if not enabled then
        Stride.currentBlend = 0.0
        Stride.currentRoll = 0.0
        Stride.currentYaw = 0.0
        Stride.currentSpineCounterYaw = 0.0
        Stride.currentSpineCounterRoll = 0.0
        Stride.currentLegCounterRoll = 0.0
        Stride.statusText = "Disabled by User Setting"
        Stride.Publish(player)
        return
    end

    if not sys or not sys.GetSwayContext then
        Stride.currentBlend = 0.0
        Stride.currentRoll = 0.0
        Stride.currentYaw = 0.0
        Stride.currentSpineCounterYaw = 0.0
        Stride.currentSpineCounterRoll = 0.0
        Stride.currentLegCounterRoll = 0.0
        Stride.statusText = "System Unavailable"
        Stride.Publish(player)
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

    -- User intensity multiplier (0.25x - 1.50x)
    local intensity = (settings and settings.hipSwayIntensity) or 1.0

    -- Compute instantaneous anatomical angles
    if Stride.currentBlend > 0.001 then
        -- Smoothly taper down during fast jogging so it doesn't look frantic
        local speedDamp = 1.0
        if speed > 3.0 then
            speedDamp = math.max(0.40, 1.0 - (speed - 3.0) * 0.30)
        end

        local masterScale = heelScale * intensity * Stride.currentBlend * speedDamp
        Stride.currentYaw = Stride.BASE_YAW_DEG * math.sin(Stride.phase) * masterScale
        Stride.currentRoll = Stride.BASE_ROLL_DEG * math.cos(Stride.phase) * masterScale
        Stride.currentSpineCounterYaw = Stride.currentYaw * Stride.COUNTER_YAW_RATIO
        Stride.currentSpineCounterRoll = Stride.currentRoll * Stride.COUNTER_ROLL_RATIO
        Stride.currentLegCounterRoll = Stride.currentRoll * Stride.COUNTER_LEG_ROLL_RATIO

        Stride.statusText = string.format("Active (Roll: %+.1f°, Yaw: %+.1f°, Leg: %+.1f°, Speed: %.1f m/s)",
            Stride.currentRoll, Stride.currentYaw, Stride.currentLegCounterRoll, speed)
    else
        Stride.currentRoll = 0.0
        Stride.currentYaw = 0.0
        Stride.currentSpineCounterYaw = 0.0
        Stride.currentSpineCounterRoll = 0.0
        Stride.currentLegCounterRoll = 0.0
        Stride.statusText = string.format("Inactive (%s)", reason)
    end

    Stride.Publish(player)
end

-- -----------------------------------------------------------------------------
-- Publishes Current Sway Variables to Character Animation Controller
-- -----------------------------------------------------------------------------
function Stride.Publish(player)
    if not player or not AnimationControllerComponent or not AnimationControllerComponent.SetInputFloat then
        return
    end

    pcall(AnimationControllerComponent.SetInputFloat, player, Stride.rollVarName, Stride.currentRoll)
    pcall(AnimationControllerComponent.SetInputFloat, player, Stride.yawVarName, Stride.currentYaw)
    pcall(AnimationControllerComponent.SetInputFloat, player, Stride.spineCounterYawVarName, Stride.currentSpineCounterYaw)
    pcall(AnimationControllerComponent.SetInputFloat, player, Stride.spineCounterRollVarName, Stride.currentSpineCounterRoll)
    pcall(AnimationControllerComponent.SetInputFloat, player, Stride.legCounterRollVarName, Stride.currentLegCounterRoll)
    pcall(AnimationControllerComponent.SetInputFloat, player, Stride.blendVarName, Stride.currentBlend)
end

-- -----------------------------------------------------------------------------
-- Reset State (On Perspective Switch, Teleport, Death)
-- -----------------------------------------------------------------------------
function Stride.Reset(player)
    Stride.Init()
    Stride.phase = 0.0
    Stride.currentBlend = 0.0
    Stride.currentRoll = 0.0
    Stride.currentYaw = 0.0
    Stride.currentSpineCounterYaw = 0.0
    Stride.currentSpineCounterRoll = 0.0
    Stride.currentLegCounterRoll = 0.0
    Stride.statusText = "Reset"
    if player then
        Stride.Publish(player)
    end
end

function Stride.GetStatus()
    return Stride.statusText, Stride.currentRoll, Stride.currentYaw, Stride.currentBlend, Stride.currentLegCounterRoll
end

return Stride
