-- =============================================================================
-- Immersive Footwear POV - Easing & Transition Module
-- Manages smoothstep mathematical easing and linear blend transition state
-- =============================================================================

local Logger = require("modules/logger")

local Transition = {
    DURATION = 0.20,
    currentBlend = 0.50,
    startBlend = 0.50,
    targetBlend = 0.50,
    elapsed = 0.20,
    isTransitioning = false,
    lastLoggedTargetStanceCm = nil,
    lastLoggedBaseReason = nil,
    lastLoggedSettledStanceCm = nil,
}

local function smoothstep(t)
    t = math.max(0.0, math.min(1.0, t))
    return t * t * (3.0 - 2.0 * t)
end

function Transition.GetBlend()
    return Transition.currentBlend
end

function Transition.GetStanceCm()
    return (Transition.currentBlend * 1.00 - 0.50) * 100.0
end

function Transition.SetImmediate(newTarget)
    local target = math.max(0.0, math.min(1.0, tonumber(newTarget) or 0.50))
    Transition.currentBlend = target
    Transition.startBlend = target
    Transition.targetBlend = target
    Transition.elapsed = Transition.DURATION
    Transition.isTransitioning = false
    Transition.lastLoggedTargetStanceCm = nil
    Transition.lastLoggedBaseReason = nil
    Transition.lastLoggedSettledStanceCm = nil
    return target
end

function Transition.SetTarget(newTarget, reason, onLogCallback)
    if newTarget == nil or newTarget ~= newTarget then
        Logger.Warn("TRANSITION", "Invalid blend target received: %s (defaulting to 0.50)", tostring(newTarget))
        newTarget = 0.50
    end
    if newTarget < 0.0 or newTarget > 1.0 then
        Logger.Warn("TRANSITION", "Blend target out of range [0.0, 1.0]: %.3f (clamping)", newTarget)
    end
    newTarget = math.max(0.0, math.min(1.0, newTarget))
    if math.abs(newTarget - Transition.targetBlend) < 0.0001 then
        return
    end

    local startStanceCm = (Transition.currentBlend * 1.00 - 0.50) * 100.0
    local targetStanceCm = (newTarget * 1.00 - 0.50) * 100.0

    -- Divide the metric measurement (in cm) by 0.5, and only log if the modulo is 0
    local metricUnits = math.floor(math.abs(targetStanceCm) * 10.0 + 0.5)
    local isModuloZero = (metricUnits % 5 == 0)

    -- Ignore embedded stance cm numbers in reason when checking for state transitions
    local baseReason = string.gsub(reason or "", "%+%d+%.?%d*%s*cm", "")
    local stateChanged = (baseReason ~= Transition.lastLoggedBaseReason)
    local stanceChanged = (Transition.lastLoggedTargetStanceCm == nil or math.abs(targetStanceCm - Transition.lastLoggedTargetStanceCm) > 0.05)

    if (stateChanged or (stanceChanged and isModuloZero)) and onLogCallback and type(onLogCallback) == "function" then
        Transition.lastLoggedTargetStanceCm = targetStanceCm
        Transition.lastLoggedBaseReason = baseReason
        local actionDesc = (targetStanceCm < startStanceCm) and "Lowering stance" or ((targetStanceCm > startStanceCm) and "Elevating stance" or "Adjusting stance")
        if math.abs(targetStanceCm) < 0.05 and math.abs(startStanceCm) >= 0.05 then
            actionDesc = "Neutralizing stance (0.0 cm)"
        end
        onLogCallback(string.format("Transition started: %s (Blend %.3f [%+.1f cm] -> %.3f [%+.1f cm] over %.2fs) | Trigger: %s",
            actionDesc, Transition.currentBlend, startStanceCm, newTarget, targetStanceCm, Transition.DURATION, reason or "State Update"))
    end

    Transition.startBlend = Transition.currentBlend
    Transition.targetBlend = newTarget
    Transition.elapsed = 0.0
    Transition.isTransitioning = true
end

function Transition.Update(deltaTime, onLogCallback)
    if Transition.isTransitioning then
        Transition.elapsed = math.min(
            Transition.DURATION,
            Transition.elapsed + math.max(tonumber(deltaTime) or 0.0, 0.0)
        )
        local progress = (Transition.DURATION <= 0.0)
            and 1.0
            or (Transition.elapsed / Transition.DURATION)
        local eased = smoothstep(progress)
        Transition.currentBlend = Transition.startBlend + (Transition.targetBlend - Transition.startBlend) * eased

        if Transition.elapsed >= Transition.DURATION then
            Transition.isTransitioning = false
            Transition.currentBlend = Transition.targetBlend
            local settledStanceCm = (Transition.targetBlend * 1.00 - 0.50) * 100.0

            local metricUnits = math.floor(math.abs(settledStanceCm) * 10.0 + 0.5)
            local isModuloZero = (metricUnits % 5 == 0)
            local settledChanged = (Transition.lastLoggedSettledStanceCm == nil or math.abs(settledStanceCm - Transition.lastLoggedSettledStanceCm) > 0.05)

            if (settledChanged and isModuloZero) and onLogCallback and type(onLogCallback) == "function" then
                Transition.lastLoggedSettledStanceCm = settledStanceCm
                local actionDesc = math.abs(settledStanceCm) < 0.05 and "Neutral baseline settled" or "Elevation settled"
                onLogCallback(string.format("Transition settled: %s (Blend %.3f | Stance: %+.1f cm)", actionDesc, Transition.targetBlend, settledStanceCm))
            end
        end
    else
        Transition.currentBlend = Transition.targetBlend
    end
    return Transition.currentBlend
end

return Transition
