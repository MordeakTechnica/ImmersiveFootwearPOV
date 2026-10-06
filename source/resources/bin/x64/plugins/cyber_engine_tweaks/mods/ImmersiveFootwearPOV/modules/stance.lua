-- =============================================================================
-- Immersive Footwear POV - Stance Resolution Service (Strategy Pattern)
-- Evaluates perspective context, active footwear, suppression, and framework states
-- to determine target skeletal blend (ifp_height_blend) and puppet elevation (foot_elevation_offset)
-- =============================================================================

local StanceResolver = {}

-- -----------------------------------------------------------------------------
-- Strategy: Forced Console / Diagnostic Stance Override
-- -----------------------------------------------------------------------------
local function ResolveForcedStance(forcedBlend)
    local targetBlend = forcedBlend
    local footElevationMeters = (targetBlend - 0.50) * 1.00
    local reason = string.format("Forced Stance Override (Blend: %.3f)", forcedBlend)
    return targetBlend, footElevationMeters, reason
end

-- -----------------------------------------------------------------------------
-- Strategy: Third Person Perspective (ITP Active)
-- Lifts character model puppet by platform sole thickness
-- -----------------------------------------------------------------------------
local function ResolveTPPStance(context)
    local sys = context.sys
    local shoeState = context.shoeState
    local isSuppressed = context.isSuppressed
    local heightLimits = context.heightLimits
    local ifpIntegration = context.ifpIntegration

    local maxPlatMeters = (heightLimits.MAX_PLATFORM_CM or 30.0) / 100.0

    local platOffset = (sys and sys.GetEffectivePlatformOffset and sys:GetEffectivePlatformOffset()) or 0.0
    if platOffset <= 0.0 and shoeState and shoeState.platformCm then
        platOffset = (shoeState.platformCm or 0.0) / 100.0
    end
    platOffset = math.min(math.max(0.0, platOffset), maxPlatMeters)

    local footElevationMeters = isSuppressed and 0.0 or platOffset
    local targetBlend, _ = ifpIntegration.CalculateTargetBlend(platOffset, 0.0, isSuppressed, maxPlatMeters)

    local reason
    if context.isPhotoModeOpen then
        reason = "Photo Mode Active (Locomotion Neutralized)"
    elseif shoeState.isSuppressed then
        reason = "Suppression (" .. tostring(shoeState.suppressionReason) .. ")"
    else
        reason = string.format("ITP 3rd-Person Active (Platform: +%.1f cm)", (shoeState.platformCm or 0.0))
    end

    return targetBlend, footElevationMeters, reason
end

-- -----------------------------------------------------------------------------
-- Strategy: First Person Perspective (FPP / IFP / TFP)
-- Elevates first-person eye height and body via heel height + IFP base slider
-- -----------------------------------------------------------------------------
local function ResolveFPPStance(context)
    local sys = context.sys
    local shoeState = context.shoeState
    local isSuppressed = context.isSuppressed
    local heightLimits = context.heightLimits
    local ifpIntegration = context.ifpIntegration
    local ifpInstalled = context.ifpInstalled
    local ifpHeightAdjustmentEnabled = context.ifpHeightAdjustmentEnabled
    local isTFP = context.isTFP

    local footElevationMeters = 0.0
    local targetBlend = 0.50
    local reason = "Neutral Baseline"

    if isTFP then
        -- True First Person handles camera height via native REDscript camera matrices
        targetBlend = 0.50
        reason = "True First Person Native (Skeletal Blend Neutral)"
    elseif ifpInstalled and not ifpHeightAdjustmentEnabled then
        -- IFP is installed, but height adjustment is disabled:
        -- Strictly reset skeletal stance to neutral baseline (0.0 cm / blend 0.50)
        targetBlend = 0.50
        reason = "IFP Height Adjustment Disabled (Neutral Baseline)"
    elseif sys and sys.IsITPPresent and sys:IsITPPresent() and not ifpInstalled then
        -- Pure ITP without IFP installed: First Person operates with zero skeletal offset
        targetBlend = 0.50
        reason = "First Person Neutral Baseline (Identical as in ITP)"
    else
        -- IFP Active (or Standalone): Combine footwear heel height + IFP base slider
        -- In IFP, height offset must strictly not exceed 25cm (0.25m)
        local maxIFPMeters = (heightLimits.MAX_IFP_CM or 25.0) / 100.0
        local currentOffset = sys and sys:GetEffectiveOffset() or 0.0
        local ifpFootwearOffset = math.min(math.max(0.0, currentOffset), maxIFPMeters)
        targetBlend, _ = ifpIntegration.CalculateTargetBlend(ifpFootwearOffset, context.ifpBaseHeightCm, isSuppressed, maxIFPMeters)

        if context.isPhotoModeOpen then
            reason = "Photo Mode Active (Locomotion Neutralized)"
        elseif shoeState.isSuppressed then
            reason = "Suppression (" .. tostring(shoeState.suppressionReason) .. ")"
        elseif shoeState.hasShoe then
            reason = string.format("Footwear Active (%s: +%.1f cm)", tostring(shoeState.displayName), (shoeState.heelCm or 0.0))
        else
            reason = "Barefoot / Neutral Stance"
        end
    end

    return targetBlend, footElevationMeters, reason
end

-- -----------------------------------------------------------------------------
-- Public Evaluator Dispatcher
-- -----------------------------------------------------------------------------
--- Resolve the target blend, puppet elevation, and human-readable trigger reason
---@param context table
---@return number targetBlend, number footElevationMeters, string reason
function StanceResolver.ResolveTarget(context)
    if context.forcedBlend ~= nil then
        return ResolveForcedStance(context.forcedBlend)
    end

    if context.isITPActive then
        return ResolveTPPStance(context)
    else
        return ResolveFPPStance(context)
    end
end

return StanceResolver
