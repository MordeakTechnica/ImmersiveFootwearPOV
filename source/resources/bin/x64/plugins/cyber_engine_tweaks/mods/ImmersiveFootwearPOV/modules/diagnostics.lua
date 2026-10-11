-- =============================================================================
-- Immersive Footwear POV - Diagnostics & Reporting Service
-- Formats and outputs system state, framework statuses, and footwear diagnostics
-- =============================================================================

local Diagnostics = {}

--- Generate and output comprehensive diagnostics for all subsystems
---@param sys table Scriptable system reference
---@param modSettings table Mod configuration and state object
---@param ifpIntegration table IFP integration service
---@param transitionMgr table Transition manager service
---@param shoeState table Optional shoe state (defaults to modSettings.currentShoeState)
function Diagnostics.Dump(sys, modSettings, ifpIntegration, transitionMgr, shoeState)
    local shoe = shoeState or (modSettings and modSettings.currentShoeState) or {}
    local tfpPresent = (sys and sys.IsTFPPresent) and sys:IsTFPPresent() or false
    local itpPresent = (sys and sys.IsITPPresent) and sys:IsITPPresent() or false
    local eqExPresent = (sys and sys.IsEquipmentExPresent) and sys:IsEquipmentExPresent() or false
    local ifpInstalled = ifpIntegration and ifpIntegration.IsInstalled and ifpIntegration.IsInstalled() or false
    local ifpEnabled = ifpIntegration and ifpIntegration.IsEnabled and ifpIntegration.IsEnabled() or false
    local ifpHeightEnabled = ifpIntegration and ifpIntegration.IsHeightAdjustmentEnabled and ifpIntegration.IsHeightAdjustmentEnabled() or false
    local ifpBaseHeightCm = 0.0
    if ifpIntegration and ifpIntegration.GetState then
        local baseH, _ = ifpIntegration.GetState()
        ifpBaseHeightCm = baseH or 0.0
    end

    local currentBlend = transitionMgr and transitionMgr.GetBlend and transitionMgr.GetBlend() or 0.50
    local targetBlend = transitionMgr and transitionMgr.targetBlend or 0.50

    print("================ [Immersive Footwear POV Diagnostics] ================")
    print(string.format(" Frameworks Active: IFP: %s (Enabled: %s, Height Adj: %s) | ITP: %s | TFP: %s | Eq-EX: %s",
        ifpInstalled and "INSTALLED" or "ABSENT",
        ifpEnabled and "YES" or "NO",
        ifpHeightEnabled and "YES" or "NO",
        itpPresent and "INSTALLED" or "ABSENT",
        tfpPresent and "INSTALLED" or "ABSENT",
        eqExPresent and "INSTALLED" or "ABSENT"))
    print(string.format(" Debug Logging:     %s", (modSettings and modSettings.debugLogs) and "ENABLED" or "DISABLED"))
    print(string.format(" Photo Mode Active: %s (Auto-Elevate: %s)",
        tostring(modSettings and modSettings.isPhotoModeOpen),
        tostring(modSettings and modSettings.autoElevatePMPlatform)))
    local presetCount = 0
    if modSettings and modSettings.presets then
        for _ in pairs(modSettings.presets) do presetCount = presetCount + 1 end
    end
    local overrideCount = 0
    if modSettings and modSettings.userOverrides then
        for _ in pairs(modSettings.userOverrides) do overrideCount = overrideCount + 1 end
    end

    print(string.format(" Presets Loaded:    %d (from presets.json / preset packs)", presetCount))
    print(string.format(" User Overrides:    %d (from user_shoe_overrides.json)", overrideCount))
    print(string.format(" Equipped Footwear: %s", tostring(shoe.displayName or "None")))
    print(string.format(" Item TDBID String: %s", tostring(shoe.key or "")))
    print(string.format(" Resolution Source: %s (Official Tags: %s)", tostring(shoe.source or "None"), tostring(shoe.isOfficial)))
    print(string.format(" Heel Height (FPP): +%.1f cm (%.4f m)", shoe.heelCm or 0.0, (shoe.heelCm or 0.0) / 100.0))
    print(string.format(" Platform Sole (PM):+%.1f cm (%.4f m)", shoe.platformCm or 0.0, (shoe.platformCm or 0.0) / 100.0))
    print(string.format(" IFP Base Height:   %+d cm", math.floor(ifpBaseHeightCm + 0.5)))
    print(string.format(" Effective Shoe Lift:+%.1f cm", shoe.effectiveCm or 0.0))
    print(string.format(" Current Blend:     %.4f (Stance: %+.1f cm)", currentBlend, (currentBlend - 0.50) * 100.0))
    print(string.format(" Target Blend:      %.4f (Stance: %+.1f cm)", targetBlend, (targetBlend - 0.50) * 100.0))
    print(string.format(" Is Suppressed:     %s (Reason: '%s')", tostring(shoe.isSuppressed), tostring(shoe.suppressionReason or "")))
    print("=====================================================================")
end

return Diagnostics
