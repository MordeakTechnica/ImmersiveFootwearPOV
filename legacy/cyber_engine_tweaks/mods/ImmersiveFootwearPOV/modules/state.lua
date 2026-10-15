-- =============================================================================
-- Immersive Footwear POV - Shoe State & REDscript Bridge Module
-- Tracks equipped footwear metadata, suppression contexts, and custom overrides
-- =============================================================================

local Logger = require("modules/logger")

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
    if not saved and overrides and shoeKey and #shoeKey > 0 then
        local lowerKey = string.lower(shoeKey)
        for k, v in pairs(overrides) do
            if string.lower(k) == lowerKey then
                saved = v
                break
            end
        end
    end
    local shoeState = State.currentShoeState

    if saved then
        local heelCm = tonumber(saved.heel) or 0.0
        local platCm = tonumber(saved.platform) or 0.0
        local heelMeters = heelCm / 100.0
        local platMeters = platCm / 100.0

        if sys and sys.RegisterCustomOverride then
            sys:RegisterCustomOverride(shoeKey, heelMeters, platMeters)
        end
        if not sys:HasCustomOverride() or shoeKey ~= State.lastEquippedKey
           or math.abs(sys:GetCurrentHeelHeight() - heelMeters) > 0.0005
           or math.abs(sys:GetCurrentPlatformHeight() - platMeters) > 0.0005 then
            sys:SetCustomHeightOverride(player, heelMeters, platMeters, true)
        end
        shoeState.heelCm = heelCm
        shoeState.platformCm = platCm
    else
        if sys:HasCustomOverride() or shoeKey ~= State.lastEquippedKey then
            if sys and sys.RemoveCustomOverride then
                sys:RemoveCustomOverride(shoeKey)
            end
            sys:ClearCustomHeightOverride(player, true)
        end
        shoeState.heelCm = 0.0
        shoeState.platformCm = 0.0
    end
end

function State.Sync(player, sys, overrides, modSettings, ifpIntegration, saveOverridesCallback)
    if not player or not sys then
        if not player then
            Logger.Warn("STATE", "State.Sync aborted: player entity is nil")
        end
        if not sys then
            Logger.Warn("STATE", "State.Sync aborted: ImmersiveFootwearPOVSystem is nil")
        end
        return
    end

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
    if modSettings then
        modSettings.ifpSuppressedReason = ifpSuppressedReason
    end

    local isSuppressed = isRedscriptSuppressed or (ifpSuppressedReason ~= nil) or (modSettings and modSettings.isPhotoModeOpen)
    local suppressionReason = isRedscriptSuppressed and redscriptReason or (ifpSuppressedReason or (modSettings and modSettings.isPhotoModeOpen and "Photo Mode" or ""))

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
            local hadOverride = false
            if overrides and overrides[shoeKey] then
                overrides[shoeKey] = nil
                hadOverride = true
            end
            if modSettings and modSettings.userOverrides and modSettings.userOverrides[shoeKey] then
                modSettings.userOverrides[shoeKey] = nil
                hadOverride = true
            end
            if hadOverride and saveOverridesCallback then
                saveOverridesCallback()
            end
            shoeState.heelCm = sys:GetCurrentHeelHeight() * 100.0
            shoeState.platformCm = sys:GetCurrentPlatformHeight() * 100.0
        else
            State.ApplyCustomOverride(player, sys, shoeKey, overrides)
        end
        State.lastEquippedKey = shoeKey

        if (shoeState.heelCm or 0.0) > 40.0 then
            Logger.Warn("STATE", "Equipped footwear '%s' heel height %.1f cm exceeds 40.0 cm limit", tostring(shoeState.displayName), shoeState.heelCm)
        end
        if (shoeState.platformCm or 0.0) > 30.0 then
            Logger.Warn("STATE", "Equipped footwear '%s' platform height %.1f cm exceeds 30.0 cm limit", tostring(shoeState.displayName), shoeState.platformCm)
        end
    else
        if sys:HasCustomOverride() then
            sys:ClearCustomHeightOverride(player, true)
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
