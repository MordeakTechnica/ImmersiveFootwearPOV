-- =============================================================================
-- Immersive Footwear POV - Shoe State & REDscript Bridge Module
-- Tracks equipped footwear metadata, suppression contexts, and custom overrides
-- =============================================================================

local State = {
    lastEquippedKey = "",
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
        suppressionReason = "",
        isTFP = false,
    },
}

function State.GetShoeState()
    return State.currentShoeState
end

function State.ApplyCustomOverride(player, sys, shoeKey, overrides)
    local saved = overrides and overrides[shoeKey]
    local shoeState = State.currentShoeState

    if saved then
        local heelCm = tonumber(saved.heel) or 0.0
        local platCm = tonumber(saved.platform) or 0.0
        local heelMeters = heelCm / 100.0
        local platMeters = platCm / 100.0

        if not sys:HasCustomOverride() or shoeKey ~= State.lastEquippedKey
           or math.abs(sys:GetCurrentHeelHeight() - heelMeters) > 0.0005
           or math.abs(sys:GetCurrentPlatformHeight() - platMeters) > 0.0005 then
            sys:SetCustomHeightOverride(player, heelMeters, platMeters)
        end
        shoeState.heelCm = heelCm
        shoeState.platformCm = platCm
    else
        if sys:HasCustomOverride() or shoeKey ~= State.lastEquippedKey then
            sys:ClearCustomHeightOverride(player)
        end
        shoeState.heelCm = 0.0
        shoeState.platformCm = 0.0
    end
end

function State.Sync(player, sys, overrides, modSettings, ifpIntegration, saveOverridesCallback)
    if not player or not sys then return end

    -- Synchronize debug logging mode with REDscript system
    pcall(function()
        if sys.SetDebugLogging and sys:IsDebugLogging() ~= modSettings.debugLogs then
            sys:SetDebugLogging(modSettings.debugLogs)
        end
    end)

    local shoeID = sys:GetEquippedFootwearID()
    local shoeKey = sys:GetResolvedShoeTDBIDString() or ""
    local hasShoe = (#shoeKey > 0)
        or (shoeID and ItemID and ItemID.IsValid and ItemID.IsValid(shoeID))
        or false
    local isOfficial = sys:HasOfficialTweakTags()
    local sourceName = sys:GetActiveSource()
    local displayName = sys:GetResolvedShoeDisplayName()

    -- Check suppression from REDscript system, IFP bridge, and Photo Mode
    local isRedscriptSuppressed = sys:IsSuppressed()
    local redscriptReason = sys:GetSuppressionReason()
    local ifpHeight, ifpSuppressedReason = ifpIntegration.GetState()

    local isSuppressed = isRedscriptSuppressed or (ifpSuppressedReason ~= nil) or modSettings.isPhotoModeOpen
    local suppressionReason = isRedscriptSuppressed and redscriptReason or (ifpSuppressedReason or (modSettings.isPhotoModeOpen and "Photo Mode" or ""))

    local shoeState = State.currentShoeState
    shoeState.hasShoe = hasShoe
    shoeState.key = shoeKey
    shoeState.source = sourceName
    shoeState.displayName = displayName
    shoeState.isOfficial = isOfficial
    shoeState.isSuppressed = isSuppressed
    shoeState.suppressionReason = suppressionReason
    shoeState.isTFP = (sys and sys.IsTFPPresent) and sys:IsTFPPresent() or false

    if hasShoe and #shoeKey > 0 then
        if isOfficial then
            if overrides and overrides[shoeKey] then
                overrides[shoeKey] = nil
                if saveOverridesCallback then saveOverridesCallback() end
            end
            shoeState.heelCm = sys:GetCurrentHeelHeight() * 100.0
            shoeState.platformCm = sys:GetCurrentPlatformHeight() * 100.0
        else
            State.ApplyCustomOverride(player, sys, shoeKey, overrides)
        end
        State.lastEquippedKey = shoeKey
    else
        if sys:HasCustomOverride() then
            sys:ClearCustomHeightOverride(player)
        end
        shoeState.heelCm = 0.0
        shoeState.platformCm = 0.0
        State.lastEquippedKey = ""
    end

    shoeState.effectiveCm = sys:GetEffectiveOffset() * 100.0
    return ifpHeight
end

local Diagnostics = require("modules/diagnostics")

function State.DumpDiagnostics(sys, modSettings, ifpIntegration, transitionMgr)
    Diagnostics.Dump(sys, modSettings, ifpIntegration, transitionMgr, State.currentShoeState)
end

return State
