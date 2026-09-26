-- =============================================================================
-- Immersive Footwear POV - Easing & Transition Module
-- Manages smoothstep mathematical easing and linear blend transition state
-- =============================================================================

local Transition = {
    DURATION = 0.20,
    currentBlend = 0.50,
    startBlend = 0.50,
    targetBlend = 0.50,
    elapsed = 0.20,
    isTransitioning = false,
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
    return target
end

function Transition.SetTarget(newTarget, reason, onLogCallback)
    newTarget = math.max(0.0, math.min(1.0, newTarget))
    if math.abs(newTarget - Transition.targetBlend) < 0.0001 then
        return
    end

    local startStanceCm = (Transition.currentBlend * 1.00 - 0.50) * 100.0
    local targetStanceCm = (newTarget * 1.00 - 0.50) * 100.0
    if onLogCallback and type(onLogCallback) == "function" then
        onLogCallback(string.format("Transition started: Blend %.3f (%+.1f cm) -> %.3f (%+.1f cm) over %.2fs | Trigger: %s",
            Transition.currentBlend, startStanceCm, newTarget, targetStanceCm, Transition.DURATION, reason or "State Update"))
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
            if onLogCallback and type(onLogCallback) == "function" then
                onLogCallback(string.format("Transition settled: Blend %.3f (Stance: %+.1f cm)", Transition.targetBlend, settledStanceCm))
            end
        end
    else
        Transition.currentBlend = Transition.targetBlend
    end
    return Transition.currentBlend
end

return Transition
