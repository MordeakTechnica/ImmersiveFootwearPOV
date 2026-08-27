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
}

function PM.IsActive()
    return PM.isPhotoModeActive
end

function PM.ForceAttribute(attribute, value)
    if not PM.controller or not PM.isPhotoModeActive then
        return false
    end

    local itemOk, item = pcall(function()
        return PM.controller:GetMenuItem(attribute)
    end)

    if itemOk and item ~= nil then
        local forceOk = pcall(function()
            item:ForceValue(value, true)
        end)
        if forceOk then
            return true
        end
    end

    local callbackOk = pcall(function()
        PM.controller:OnForceAttributeVaulue(attribute, value, true)
    end)
    return callbackOk
end

function PM.Init(modState)
    Observe("gameuiPhotoModeMenuController", "OnShow", function(controller)
        PM.isPhotoModeActive = true
        PM.controller = controller
        if modState then
            modState.isPhotoModeOpen = true
        end

        local shoeState = modState and modState.currentShoeState or {}
        local platformCm = shoeState.platformCm or 0.0
        local autoElevate = modState and (modState.autoElevatePMPlatform ~= false) or true

        if autoElevate and platformCm > 0.0 then
            PM.pendingElevation = platformCm / 100.0
            PM.pendingPlatformCm = platformCm
            PM.elevationFrames = 0
        else
            PM.pendingElevation = nil
            PM.pendingPlatformCm = 0.0
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnHide", function()
        if PM.isPhotoModeActive then
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
        if PM.elevationFrames >= 2 then
            local success = PM.ForceAttribute(PM.ATTR_V_UP_DOWN, PM.pendingElevation)
            if success and PM.pendingPlatformCm > 0.0 then
                print(string.format("[ImmersiveFootwearPOV] Photo Mode character elevated: +%.1f cm (+%.2f m)", PM.pendingPlatformCm, PM.pendingElevation))
            end
            PM.pendingElevation = nil
        end
    end
end

return PM
