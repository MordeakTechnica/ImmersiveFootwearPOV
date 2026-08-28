-- =============================================================================
-- Immersive Footwear POV - Photo Mode (PM) Lifecycle & Native Elevation Integration
-- Observes Photo Mode lifecycle events and drives native Attribute 37 (V Up/Down)
-- Ensures 3rd-person Photo Mode character poses have accurate platform sole elevation
-- =============================================================================

local PM = {
    isPhotoModeActive = false,
    controller = nil,
    pendingElevation = nil,
    pendingPlatformCm = 0.0,
    elevationFrames = 0,
    ATTR_V_UP_DOWN = 37, -- Native Cyberpunk 2077 Photo Mode V Elevation Attribute
    modState = nil,
}

local function LogPM(fmt, ...)
    if PM.modState and PM.modState.debugLogs then
        print(string.format("[ImmersiveFootwearPOV][PM] " .. fmt, ...))
    end
end

function PM.IsActive()
    return PM.isPhotoModeActive
end

function PM.ForceAttribute(attribute, value)
    if not PM.controller or not PM.isPhotoModeActive then
        LogPM("ForceAttribute called but controller is %s, isPhotoModeActive is %s",
            PM.controller and "valid" or "nil", tostring(PM.isPhotoModeActive))
        return false
    end

    local itemOk, item = pcall(function()
        return PM.controller:GetMenuItem(attribute)
    end)

    if itemOk and item ~= nil then
        local forceOk, err = pcall(function()
            item:ForceValue(value, true)
        end)
        if forceOk then
            LogPM("ForceAttribute via item:ForceValue(Attr=%d, Val=%.4f) SUCCEEDED", attribute, value)
            return true
        else
            LogPM("ForceAttribute via item:ForceValue FAILED: %s (falling back to controller:OnForceAttributeVaulue)", tostring(err))
        end
    else
        LogPM("GetMenuItem(%d) returned %s (pcall ok: %s)", attribute, item == nil and "nil" or "found", tostring(itemOk))
    end

    local callbackOk, callbackErr = pcall(function()
        PM.controller:OnForceAttributeVaulue(attribute, value, true)
    end)
    if callbackOk then
        LogPM("ForceAttribute via controller:OnForceAttributeVaulue(Attr=%d, Val=%.4f) SUCCEEDED", attribute, value)
    else
        LogPM("ForceAttribute via controller:OnForceAttributeVaulue FAILED: %s", tostring(callbackErr))
    end
    return callbackOk
end

function PM.Init(modState)
    PM.modState = modState
    Observe("gameuiPhotoModeMenuController", "OnShow", function(controller)
        PM.isPhotoModeActive = true
        PM.controller = controller
        if modState then
            modState.isPhotoModeOpen = true
        end

        local shoeState = modState and modState.currentShoeState or {}
        local platformCm = shoeState.platformCm or 0.0
        local heelCm = shoeState.heelCm or 0.0
        local autoElevate = modState and (modState.autoElevatePMPlatform ~= false) or true

        LogPM("OnShow triggered. Controller: %s | Shoe: '%s' (ID: %s) | Heel: +%.1fcm | Platform: +%.1fcm | AutoElevate: %s",
            controller and "Valid" or "nil",
            tostring(shoeState.displayName or "None"),
            tostring(shoeState.key or "None"),
            heelCm,
            platformCm,
            tostring(autoElevate))

        if autoElevate and platformCm > 0.0 then
            PM.pendingElevation = platformCm / 100.0
            PM.pendingPlatformCm = platformCm
            PM.elevationFrames = 0
            LogPM("Queued Native Attribute %d (+%.1f cm / +%.4f m) platform sole elevation for PM character puppet",
                PM.ATTR_V_UP_DOWN, platformCm, PM.pendingElevation)
        else
            PM.pendingElevation = nil
            PM.pendingPlatformCm = 0.0
            LogPM("No Photo Mode platform elevation queued (Platform: +%.1fcm, AutoElevate: %s)", platformCm, tostring(autoElevate))
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnHide", function()
        if PM.isPhotoModeActive then
            LogPM("OnHide triggered. Exiting Photo Mode. Cleaning up controller and restoring stance.")
            PM.isPhotoModeActive = false
            PM.controller = nil
            PM.pendingElevation = nil
            PM.pendingPlatformCm = 0.0
            PM.elevationFrames = 0
            if modState then
                modState.isPhotoModeOpen = false
            end
        end
    end)
end

function PM.OnUpdate(deltaTime)
    if PM.pendingElevation ~= nil and PM.isPhotoModeActive and PM.controller ~= nil then
        PM.elevationFrames = PM.elevationFrames + 1
        LogPM("OnUpdate frame %d: Waiting to apply Attribute %d (+%.4f m)...", PM.elevationFrames, PM.ATTR_V_UP_DOWN, PM.pendingElevation)
        if PM.elevationFrames >= 2 then
            LogPM("OnUpdate frame %d reached: Dispatching ForceAttribute(%d, +%.4f m)...", PM.elevationFrames, PM.ATTR_V_UP_DOWN, PM.pendingElevation)
            local success = PM.ForceAttribute(PM.ATTR_V_UP_DOWN, PM.pendingElevation)
            if success and PM.pendingPlatformCm > 0.0 then
                print(string.format("[ImmersiveFootwearPOV] Photo Mode character elevated: +%.1f cm (+%.2f m)", PM.pendingPlatformCm, PM.pendingElevation))
            elseif not success then
                print(string.format("[ImmersiveFootwearPOV][ERROR] Failed to apply Photo Mode elevation (+%.1f cm) to Attribute %d", PM.pendingPlatformCm, PM.ATTR_V_UP_DOWN))
            end
            PM.pendingElevation = nil
        end
    end
end

return PM
