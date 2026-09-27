-- =============================================================================
-- Immersive Footwear POV - Feminine Stride & Procedural Hip Sway Module
-- Computes real-time pelvic roll, yaw, and pitch oscillating with locomotion speed
-- Scales dynamically with footwear heel height and respects first-person camera preferences
-- =============================================================================

local Stride = {
    -- State variables
    phase = 0.0,
    currentBlend = 0.0,
    currentRoll = 0.0,
    currentYaw = 0.0,
    currentSpineCounterYaw = 0.0,
    currentSpineCounterRoll = 0.0,
    statusText = "Idle",

    -- Cached CNames for native animation variable publication
    rollVarName = nil,
    yawVarName = nil,
    spineCounterYawVarName = nil,
    spineCounterRollVarName = nil,
    blendVarName = nil,

    -- Anatomical baseline amplitudes (at 10 cm heel height, 1.0x intensity)
    BASE_ROLL_DEG = 2.8,   -- Frontal plane pelvic drop / tilt (Y_Axis, Forward rotation)
    BASE_YAW_DEG = 3.4,    -- Transverse plane pelvic swivel (Z_Axis, Up rotation)
    COUNTER_YAW_RATIO = -0.45,   -- Thoracic spine counter-yaw (stabilizes shoulders)
    COUNTER_ROLL_RATIO = -0.35,  -- Thoracic spine counter-roll (keeps shoulders level)
}

function Stride.Init()
    if not Stride.rollVarName then
        Stride.rollVarName = CName.new("ifp_hip_sway_roll")
        Stride.yawVarName = CName.new("ifp_hip_sway_yaw")
        Stride.spineCounterYawVarName = CName.new("ifp_spine_counter_yaw")
        Stride.spineCounterRollVarName = CName.new("ifp_spine_counter_roll")
        Stride.blendVarName = CName.new("ifp_hip_sway_blend")
    end
end

-- -----------------------------------------------------------------------------
-- Evaluates Locomotion States (Blackboard & Velocity)
-- Returns: canSway (boolean), suppressionReason (string), speed (float)
-- -----------------------------------------------------------------------------
local function EvaluateLocomotion(player, isSuppressed)
    if isSuppressed then
        return false, "Suppressed (External)", 0.0
    end

    if not player or not player.GetVelocity then
        return false, "No Player", 0.0
    end

    local vel = player:GetVelocity()
    if not vel or vel.x == nil then
        return false, "Invalid Velocity", 0.0
    end

    local speed = math.sqrt(vel.x * vel.x + vel.y * vel.y)

    -- Threshold for locomotion detection
    if speed < 0.15 then
        return false, "Standing Still", speed
    end

    -- Check player state machine blackboard for crouch, sprint, jump, aiming
    local psmBlackboard = player.GetPlayerStateMachineBlackboard and player:GetPlayerStateMachineBlackboard()
    if psmBlackboard and GetAllBlackboardDefs then
        local psmDefs = GetAllBlackboardDefs().PlayerStateMachine
        if psmDefs then
            -- 1. Locomotion State (0 = Default/Stand, 1 = Crouch, 2 = Sprint, 3 = Jump/Fall)
            local loco = psmBlackboard:GetInt(psmDefs.Locomotion)
            if loco == 1 then
                return false, "Crouching", speed
            elseif loco == 2 or speed > 5.5 then
                return false, "Sprinting", speed
            elseif loco == 3 then
                return false, "Airborne / Jumping", speed
            end

            -- 2. Detailed Locomotion (Dodge, Slide, Vault)
            local detailedLoco = psmBlackboard:GetInt(psmDefs.LocomotionDetailed)
            if detailedLoco == 5 or detailedLoco == 6 then
                return false, "Dodging / Sliding", speed
            elseif detailedLoco >= 8 and detailedLoco <= 13 then
                return false, "Climbing / Vaulting", speed
            end

            -- 3. Combat Weapon Aiming (ADS)
            local weapon = psmBlackboard:GetInt(psmDefs.Weapon)
            if weapon == 2 then -- Aiming Down Sights
                return false, "Aiming Weapon", speed
            end
        end
    end

    -- Speed-based sprint safeguard
    if speed > 5.2 then
        return false, "Sprinting", speed
    end

    return true, "Walking / Jogging", speed
end

-- -----------------------------------------------------------------------------
-- Main Per-Frame Update Loop
-- Called from init.lua onUpdate
-- -----------------------------------------------------------------------------
function Stride.Update(deltaTime, player, shoeState, isITPActive, settings, isSuppressed)
    Stride.Init()

    -- Master enable check
    local enabled = settings and (settings.enableHipSway ~= false)
    if not enabled then
        Stride.currentBlend = 0.0
        Stride.currentRoll = 0.0
        Stride.currentYaw = 0.0
        Stride.currentSpineCounterYaw = 0.0
        Stride.currentSpineCounterRoll = 0.0
        Stride.statusText = "Disabled by User Setting"
        Stride.Publish(player)
        return
    end

    -- First-person camera head bob check:
    -- In Immersive Third Person (ITP), hip sway is always permitted.
    -- In Immersive First Person (FPP), if the player has disabled 1st-person head bob,
    -- clamp sway to 0.0 to guarantee steady-cam horizon stabilization with zero motion sickness.
    local allowPerspective = true
    if not isITPActive then
        local headBobEnabled = settings and (settings.enableFPPHeadBob == true)
        if not headBobEnabled then
            allowPerspective = false
        end
    end

    -- Heel height scaling (0cm -> 0.0, 5cm -> 0.5, 10cm -> 1.0, 12cm+ -> 1.15)
    local heelCm = (shoeState and shoeState.heelCm) or 0.0
    local heelScale = 0.0
    if heelCm > 0.0 then
        heelScale = math.min(1.20, heelCm / 10.0)
    end

    if heelScale <= 0.001 then
        -- Flat footwear / barefoot has no hip sway (standard neutral walk)
        Stride.currentBlend = 0.0
        Stride.currentRoll = 0.0
        Stride.currentYaw = 0.0
        Stride.currentSpineCounterYaw = 0.0
        Stride.currentSpineCounterRoll = 0.0
        Stride.statusText = "Neutral Stride (Flat Footwear / 0 cm)"
        Stride.Publish(player)
        return
    end

    -- Evaluate locomotion and suppression contexts
    local canSway, locoReason, speed = EvaluateLocomotion(player, isSuppressed)

    local targetBlend = 0.0
    if canSway and allowPerspective then
        targetBlend = 1.0
    end

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

    -- User intensity multiplier (0.5x - 1.5x)
    local intensity = (settings and settings.hipSwayIntensity) or 1.0

    -- Instantaneous anatomical angles (Yaw = advancing leg swivel, Roll = stance leg weight-bearing tilt)
    if Stride.currentBlend > 0.001 then
        local masterScale = heelScale * intensity * Stride.currentBlend
        Stride.currentYaw = Stride.BASE_YAW_DEG * math.sin(Stride.phase) * masterScale
        Stride.currentRoll = Stride.BASE_ROLL_DEG * math.cos(Stride.phase) * masterScale
        Stride.currentSpineCounterYaw = Stride.currentYaw * Stride.COUNTER_YAW_RATIO
        Stride.currentSpineCounterRoll = Stride.currentRoll * Stride.COUNTER_ROLL_RATIO

        if not allowPerspective then
            Stride.statusText = "Steady-Cam in First Person (Head Bob Disabled)"
        else
            Stride.statusText = string.format("Active (Roll: %+.1f°, Yaw: %+.1f°, Speed: %.1f m/s)",
                Stride.currentRoll, Stride.currentYaw, speed)
        end
    else
        Stride.currentRoll = 0.0
        Stride.currentYaw = 0.0
        Stride.currentSpineCounterYaw = 0.0
        Stride.currentSpineCounterRoll = 0.0
        if not allowPerspective then
            Stride.statusText = "Steady-Cam in First Person (Head Bob Disabled)"
        else
            Stride.statusText = string.format("Suppressed (%s)", locoReason)
        end
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
    Stride.statusText = "Reset"
    if player then
        Stride.Publish(player)
    end
end

function Stride.GetStatus()
    return Stride.statusText, Stride.currentRoll, Stride.currentYaw, Stride.currentBlend
end

return Stride
