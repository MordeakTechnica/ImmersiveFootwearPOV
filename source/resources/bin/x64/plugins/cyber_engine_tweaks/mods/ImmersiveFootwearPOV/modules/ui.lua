-- =============================================================================
-- Immersive Footwear POV - CET ImGui Fallback Interface (Presenter Pattern)
-- Single Responsibility: Renders shoe calibration controls, mod settings,
-- diagnostics, and DigitalVixen environment status when native DV mods are missing.
-- =============================================================================

local UIManager = {
    sliderHeelCm = 0.0,
    sliderPlatCm = 0.0,
    lastShoeKey = "",
    lastSyncedHeelCm = -1.0,
    lastSyncedPlatCm = -1.0,
}

--- Clamp a numerical input to [0.0, maxVal]
local function Clamp(val, maxVal)
    local n = tonumber(val) or 0.0
    if n < 0.0 then return 0.0 end
    if n > maxVal then return maxVal end
    return n
end

--- Render status banner indicating which DigitalVixen mods triggered this fallback
local function DrawFallbackBanner(sys)
    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.15, 0.10, 0.05, 0.8)
    if ImGui.BeginChild("DV_Banner", 0, 54, true) then
        ImGui.TextColored(1.0, 0.75, 0.2, 1.0, "CET Fallback Interface Active")
        local missing = sys and sys.GetMissingDigitalVixenSummary and sys:GetMissingDigitalVixenSummary() or "Unknown"
        ImGui.TextDisabled(string.format("Triggered by missing native mod(s): %s", missing))
    end
    ImGui.EndChild()
    ImGui.PopStyleColor()
end

--- Render active shoe summary header
local function DrawShoeHeader(sys)
    local shoeName = sys and sys.GetResolvedShoeDisplayName and sys:GetResolvedShoeDisplayName() or "Unknown"
    local shoeKey = sys and sys.GetResolvedShoeTDBIDString and sys:GetResolvedShoeTDBIDString() or ""
    local source = sys and sys.GetSettingsSource and sys:GetSettingsSource() or "None"
    local modTag = sys and sys.GetActiveModTag and sys:GetActiveModTag() or ""

    ImGui.Text(string.format("Equipped: %s", shoeName))
    ImGui.TextDisabled(string.format("Source: [%s] | ID: %s %s", source, shoeKey, modTag))
    ImGui.Separator()
end

--- Render live shoe height calibrator tab
local function DrawCalibratorTab(sys, configMgr)
    local shoeKey = sys and sys.GetResolvedShoeTDBIDString and sys:GetResolvedShoeTDBIDString() or ""
    local canEdit = #shoeKey > 0

    if not canEdit then
        ImGui.Spacing()
        ImGui.TextColored(0.7, 0.7, 0.7, 1.0, "No footwear equipped or player not loaded.")
        ImGui.TextDisabled("Equip footwear on V in your inventory or wardrobe to calibrate heel and platform heights.")
        return
    end

    local curHeelCm = (sys and sys.GetCurrentHeelHeight and sys:GetCurrentHeelHeight() or 0.0) * 100.0
    local curPlatCm = (sys and sys.GetCurrentPlatformHeight and sys:GetCurrentPlatformHeight() or 0.0) * 100.0

    -- Synchronize sliders on shoe swap or first render
    if shoeKey ~= UIManager.lastShoeKey or UIManager.lastSyncedHeelCm < 0.0 then
        UIManager.lastShoeKey = shoeKey
        UIManager.sliderHeelCm = curHeelCm
        UIManager.sliderPlatCm = curPlatCm
        UIManager.lastSyncedHeelCm = curHeelCm
        UIManager.lastSyncedPlatCm = curPlatCm
    end

    ImGui.Spacing()
    ImGui.Text("Adjust sliders for instant live preview on V:")

    -- Heel Height slider
    local newHeel, heelChanged = ImGui.SliderFloat("Heel Height (cm)", UIManager.sliderHeelCm, 0.0, 40.0, "%.1f cm")
    if heelChanged then
        UIManager.sliderHeelCm = Clamp(newHeel, 40.0)
        if sys and sys.ApplyLiveCalibration then
            sys:ApplyLiveCalibration(UIManager.sliderHeelCm / 100.0, UIManager.sliderPlatCm / 100.0)
        end
    end

    -- Platform Sole slider
    local newPlat, platChanged = ImGui.SliderFloat("Platform Sole (cm)", UIManager.sliderPlatCm, 0.0, 30.0, "%.1f cm")
    if platChanged then
        UIManager.sliderPlatCm = Clamp(newPlat, 30.0)
        if sys and sys.ApplyLiveCalibration then
            sys:ApplyLiveCalibration(UIManager.sliderHeelCm / 100.0, UIManager.sliderPlatCm / 100.0)
        end
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Action Buttons
    if ImGui.Button("Save as Permanent Custom Override", 320, 30) then
        local heelMeters = UIManager.sliderHeelCm / 100.0
        local platMeters = UIManager.sliderPlatCm / 100.0

        if sys then
            if sys.ClearPendingOverrideSave then sys:ClearPendingOverrideSave() end
            if sys.GetStorageManager and sys:GetStorageManager().SaveUserOverride then
                sys:GetStorageManager():SaveUserOverride(shoeKey, heelMeters, platMeters)
            end
            if sys.RegisterCustomOverride then
                sys:RegisterCustomOverride(shoeKey, heelMeters, platMeters)
            end
        end

        -- Save to local CET user_shoe_overrides.json when RedFunctions is missing
        if configMgr and (not sys or not sys.HasRedFunctions or not sys:HasRedFunctions()) then
            local overrides = configMgr.LoadOverrides()
            overrides[shoeKey] = { heel = UIManager.sliderHeelCm, platform = UIManager.sliderPlatCm }
            configMgr.SaveOverrides(overrides)
        end
    end

    ImGui.SameLine()
    if ImGui.Button("Revert to Tag/Preset Default", 240, 30) then
        if sys then
            if sys.ClearPendingOverrideSave then sys:ClearPendingOverrideSave() end
            if sys.GetStorageManager and sys:GetStorageManager().RemoveUserOverride then
                sys:GetStorageManager():RemoveUserOverride(shoeKey)
            end
            if sys.RevertFootwearToDefault then
                sys:RevertFootwearToDefault()
            end
            UIManager.sliderHeelCm = (sys.GetCurrentHeelHeight and sys:GetCurrentHeelHeight() or 0.0) * 100.0
            UIManager.sliderPlatCm = (sys.GetCurrentPlatformHeight and sys:GetCurrentPlatformHeight() or 0.0) * 100.0
            UIManager.lastSyncedHeelCm = UIManager.sliderHeelCm
            UIManager.lastSyncedPlatCm = UIManager.sliderPlatCm
        end

        if configMgr and (not sys or not sys.HasRedFunctions or not sys:HasRedFunctions()) then
            local overrides = configMgr.LoadOverrides()
            overrides[shoeKey] = nil
            configMgr.SaveOverrides(overrides)
        end
    end
end

--- Render mod settings tab
local function DrawSettingsTab(sys, configMgr)
    local cfg = sys and sys.GetConfig and sys:GetConfig() or nil
    if not cfg then
        ImGui.TextDisabled("Configuration state not available.")
        return
    end

    local changed = false

    ImGui.Spacing()
    ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "First-Person Perspective (FPP)")
    local fpp, fppToggled = ImGui.Checkbox("Enable FPP Camera Lift", cfg.enableFPP)
    if fppToggled then cfg.enableFPP = fpp; changed = true end

    local spd, spdChanged = ImGui.SliderFloat("Camera Easing Duration (s)", cfg.transitionSpeed, 0.10, 1.00, "%.2f s")
    if spdChanged then cfg.transitionSpeed = spd; changed = true end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "Third-Person (ITP) & Photo Mode")
    local itp, itpToggled = ImGui.Checkbox("Enable Third-Person Elevation (ITP)", cfg.enableITP)
    if itpToggled then cfg.enableITP = itp; changed = true end

    local pm, pmToggled = ImGui.Checkbox("Auto-Elevate in Photo Mode", cfg.autoElevatePM)
    if pmToggled then cfg.autoElevatePM = pm; changed = true end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "Catwalk Locomotion (Pelvic Hip Sway)")
    local sway, swayToggled = ImGui.Checkbox("Enable Pelvic Hip Sway", cfg.enableHipSway)
    if swayToggled then cfg.enableHipSway = sway; changed = true end

    local sLow, sLowChanged = ImGui.SliderFloat("Low Heel Sway Multiplier", cfg.swayLow, 0.0, 3.0, "%.1fx")
    if sLowChanged then cfg.swayLow = sLow; changed = true end

    local sMid, sMidChanged = ImGui.SliderFloat("Mid Heel Sway Multiplier", cfg.swayMid, 0.0, 3.0, "%.1fx")
    if sMidChanged then cfg.swayMid = sMid; changed = true end

    local sHigh, sHighChanged = ImGui.SliderFloat("High Heel Sway Multiplier", cfg.swayHigh, 0.0, 3.0, "%.1fx")
    if sHighChanged then cfg.swayHigh = sHigh; changed = true end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "Contextual Auto-Suppression")
    local supVeh, vToggled = ImGui.Checkbox("Suppress in Vehicles", cfg.suppressVehicles)
    if vToggled then cfg.suppressVehicles = supVeh; changed = true end

    local supWs, wsToggled = ImGui.Checkbox("Suppress in Workspots (Furniture/Sitting)", cfg.suppressWorkspots)
    if wsToggled then cfg.suppressWorkspots = supWs; changed = true end

    local supSc, scToggled = ImGui.Checkbox("Suppress in Scripted Scenes (Tier 3-5)", cfg.suppressScenes)
    if scToggled then cfg.suppressScenes = supSc; changed = true end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    local dbg, dbgToggled = ImGui.Checkbox("Verbose Debug Logs", cfg.debugLogs)
    if dbgToggled then cfg.debugLogs = dbg; changed = true end

    if changed and sys then
        if sys.OnConfigUpdated then sys:OnConfigUpdated(cfg) end
        if sys.GetStorageManager and sys:GetStorageManager().SaveConfig then
            sys:GetStorageManager():SaveConfig(cfg)
        end
        if configMgr and (not sys.HasRedFunctions or not sys:HasRedFunctions()) then
            configMgr.SaveSettings({
                enableFPP = cfg.enableFPP,
                transitionSpeed = cfg.transitionSpeed,
                enableITP = cfg.enableITP,
                autoElevatePM = cfg.autoElevatePM,
                enableHipSway = cfg.enableHipSway,
                swayLow = cfg.swayLow,
                swayMid = cfg.swayMid,
                swayHigh = cfg.swayHigh,
                suppressVehicles = cfg.suppressVehicles,
                suppressWorkspots = cfg.suppressWorkspots,
                suppressScenes = cfg.suppressScenes,
                debugLogs = cfg.debugLogs,
            })
        end
    end

    ImGui.Spacing()
    if ImGui.Button("Reset Configuration to Recommended Defaults", 340, 26) then
        if cfg.SetDefaults then cfg:SetDefaults() end
        if sys.OnConfigUpdated then sys:OnConfigUpdated(cfg) end
        if sys.GetStorageManager and sys:GetStorageManager().SaveConfig then
            sys:GetStorageManager():SaveConfig(cfg)
        end
    end
end

--- Render diagnostics and environment probe tab
local function DrawDiagnosticsTab(sys)
    ImGui.Spacing()
    ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "DigitalVixen Suite Environment Status:")

    local hasRW = sys and sys.HasRedWindows and sys:HasRedWindows() or false
    local hasRCF = sys and sys.HasRCF and sys:HasRCF() or false
    local hasRF = sys and sys.HasRedFunctions and sys:HasRedFunctions() or false
    local hasRL = sys and sys.HasRedLogger and sys:HasRedLogger() or false

    if hasRW then
        ImGui.TextColored(0.2, 0.9, 0.3, 1.0, "[+] RedWindows: Installed (Floating HUD & Native Calibrator)")
    else
        ImGui.TextColored(1.0, 0.4, 0.2, 1.0, "[-] RedWindows: Missing -> CET Fallback Calibrator Active")
    end

    if hasRCF then
        ImGui.TextColored(0.2, 0.9, 0.3, 1.0, "[+] RedscriptConfigFramework: Installed (Settings -> Mods Menu)")
    else
        ImGui.TextColored(1.0, 0.4, 0.2, 1.0, "[-] RedscriptConfigFramework: Missing -> CET Fallback Settings Active")
    end

    if hasRF then
        ImGui.TextColored(0.2, 0.9, 0.3, 1.0, "[+] RedFunctions: Installed (ModStorage JSON Persistence)")
    else
        ImGui.TextColored(1.0, 0.4, 0.2, 1.0, "[-] RedFunctions: Missing -> CET Fallback Local JSON Storage Active")
    end

    if hasRL then
        ImGui.TextColored(0.2, 0.9, 0.3, 1.0, "[+] RedLogger: Installed (Dedicated Mod Log File)")
    else
        ImGui.TextColored(0.7, 0.7, 0.7, 1.0, "[*] RedLogger: Not Installed (Native REDengine Console Logging Active)")
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "Live Footwear Telemetry:")
    local heelCm = (sys and sys.GetCurrentHeelHeight and sys:GetCurrentHeelHeight() or 0.0) * 100.0
    local platCm = (sys and sys.GetCurrentPlatformHeight and sys:GetCurrentPlatformHeight() or 0.0) * 100.0
    local isSuppressed = sys and sys.IsSuppressed and sys:IsSuppressed() or false
    local supReason = sys and sys.GetSuppressionReason and sys:GetSuppressionReason() or "None"
    local stride = sys and sys.GetStrideStatus and sys:GetStrideStatus() or "Idle"

    ImGui.Text(string.format("Authoritative Heel:     +%.1f cm", heelCm))
    ImGui.Text(string.format("Authoritative Platform: +%.1f cm", platCm))
    if isSuppressed then
        ImGui.TextColored(1.0, 0.4, 0.2, 1.0, string.format("Suppression Lock: ACTIVE (Reason: %s)", supReason))
    else
        ImGui.TextColored(0.2, 0.9, 0.3, 1.0, "Suppression Lock: None (Active Elevation)")
    end
    ImGui.Text(string.format("Catwalk Stride:         %s", stride))
end

--- Main draw entry point invoked by init.lua onDraw
---@param modState table
---@param sys any
---@param configMgr table
function UIManager.Draw(modState, sys, configMgr)
    if not modState.isOverlayOpen then
        return
    end

    ImGui.SetNextWindowSize(600, 460, ImGuiCond.FirstUseEver)
    if ImGui.Begin("Immersive Footwear POV — Fallback Configuration", ImGuiWindowFlags.NoCollapse) then
        DrawFallbackBanner(sys)
        DrawShoeHeader(sys)

        if ImGui.BeginTabBar("IFP_Fallback_Tabs") then
            if ImGui.BeginTabItem("Shoe Calibrator") then
                DrawCalibratorTab(sys, configMgr)
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Mod Settings") then
                DrawSettingsTab(sys, configMgr)
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Diagnostics & Status") then
                DrawDiagnosticsTab(sys)
                ImGui.EndTabItem()
            end
            ImGui.EndTabBar()
        end
    end
    ImGui.End()
end

return UIManager
