-- =============================================================================
-- Immersive Footwear POV - ImGui Presentation & UI Subsystem (Presenter Pattern)
-- Renders shoe summary, custom calibration controls, locomotion tabs, and readouts
-- Handles both IFP-attached extension and standalone overlay windows
-- =============================================================================

local UIManager = {}

--- Clamp a numerical input to [0.0, maxVal]
---@param val number|string
---@param maxVal number
---@return number
local function ClampHeightInput(val, maxVal)
    local n = tonumber(val) or 0.0
    if n < 0.0 then
        return 0.0
    elseif n > maxVal then
        return maxVal
    end
    return n
end

--- Apply custom footwear height changes and persist to overrides table
local function ApplyCustomFootwearHeight(modState, player, sys, shoeState, shoeKey, heelCm, platCm, saveOverridesCallback)
    shoeState.heelCm = heelCm
    shoeState.platformCm = platCm
    if not modState.overrides[shoeKey] then
        modState.overrides[shoeKey] = {}
    end
    modState.overrides[shoeKey].heel = heelCm
    modState.overrides[shoeKey].platform = platCm

    if modState.userOverrides then
        if not modState.userOverrides[shoeKey] then
            modState.userOverrides[shoeKey] = {}
        end
        modState.userOverrides[shoeKey].heel = heelCm
        modState.userOverrides[shoeKey].platform = platCm
    end

    if saveOverridesCallback then
        saveOverridesCallback()
    end

    local heelMeters = heelCm / 100.0
    local platMeters = platCm / 100.0
    if player and sys and sys.SetCustomHeightOverride then
        sys:SetCustomHeightOverride(player, heelMeters, platMeters)
    end
end

--- Render summary header for equipped footwear
local function DrawShoeSummary(shoeState)
    ImGui.Text(string.format("Equipped: %s", shoeState.displayName))
    ImGui.TextDisabled(string.format("Source: %s | ID: %s", shoeState.source, shoeState.key))
end

--- Render read-only view for footwear with official game metadata tags
local function DrawOfficialFootwearView(shoeState)
    ImGui.TextColored(0.2, 0.9, 0.3, 1.0, "Tags: Official TweakDB Metadata (Locked)")
    if shoeState.heelCm > 25.0 then
        ImGui.Text(string.format("Heel Height:     +%.1f cm (FPP Eye Lift: 25.0 cm max | Sway Pitch: +%.1f cm)", shoeState.heelCm, math.max(0.0, shoeState.heelCm - shoeState.platformCm)))
    else
        ImGui.Text(string.format("Heel Height:     +%.1f cm (Active FPP Eye Lift)", shoeState.heelCm))
    end
    if shoeState.platformCm > 0.0 then
        ImGui.Text(string.format("Platform Sole:   +%.1f cm (Photo Mode Puppet Lift)", shoeState.platformCm))
    end
end

--- Render calibration sliders and manual inputs for custom footwear
local function DrawCustomFootwearControls(modState, player, sys, shoeState, heightLimits, saveOverridesCallback)
    local shoeKey = shoeState.key
    local canEdit = player and sys and #shoeKey > 0

    local hasUserOverride = modState.userOverrides and (modState.userOverrides[shoeKey] ~= nil)
    local hasPreset = modState.presets and (modState.presets[shoeKey] ~= nil)

    if hasUserOverride then
        ImGui.TextColored(1.0, 0.85, 0.2, 1.0, "Tags: Custom Calibration (User Override)")
    elseif hasPreset then
        ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "Tags: Optional Preset Pack (Default)")
    else
        ImGui.TextColored(1.0, 0.85, 0.2, 1.0, "Tags: None Found (Custom Override)")
    end

    local maxHeel = heightLimits.MAX_HEEL_CM or 40.0
    local maxPlat = heightLimits.MAX_PLATFORM_CM or 30.0

    -- Custom Heel Height Controls (Slider + Manual Numerical Input)
    local heelVal, heelChanged = ImGui.SliderFloat("Custom Heel Slider##ifp_custom_heel", shoeState.heelCm, 0.0, maxHeel, "%.1f cm")
    if heelChanged and canEdit then
        local clampedHeel = ClampHeightInput(heelVal, maxHeel)
        ApplyCustomFootwearHeight(modState, player, sys, shoeState, shoeKey, clampedHeel, shoeState.platformCm, saveOverridesCallback)
    end

    local manualHeel, manualHeelChanged = ImGui.InputFloat("Manual Heel (cm)##ifp_manual_heel", shoeState.heelCm, 0.5, 2.0, "%.1f")
    if manualHeelChanged and canEdit then
        local clampedHeel = ClampHeightInput(manualHeel, maxHeel)
        ApplyCustomFootwearHeight(modState, player, sys, shoeState, shoeKey, clampedHeel, shoeState.platformCm, saveOverridesCallback)
    end
    ImGui.TextDisabled(string.format("  -> Total heel: drives catwalk sway pitch; elevates FPP camera up to %.1f cm max in IFP", heightLimits.MAX_IFP_CM or 25.0))
    ImGui.TextDisabled(string.format("  -> Manual input: Type exact cm or use +/- (Auto-clamps: 0.0 to %.1f cm; negative values disallowed)", maxHeel))

    ImGui.Spacing()

    -- Custom Platform Height Controls (Slider + Manual Numerical Input)
    local platVal, platChanged = ImGui.SliderFloat("Custom Platform Slider##ifp_custom_plat", shoeState.platformCm, 0.0, maxPlat, "%.1f cm")
    if platChanged and canEdit then
        local clampedPlat = ClampHeightInput(platVal, maxPlat)
        ApplyCustomFootwearHeight(modState, player, sys, shoeState, shoeKey, shoeState.heelCm, clampedPlat, saveOverridesCallback)
    end

    local manualPlat, manualPlatChanged = ImGui.InputFloat("Manual Platform (cm)##ifp_manual_plat", shoeState.platformCm, 0.5, 2.0, "%.1f")
    if manualPlatChanged and canEdit then
        local clampedPlat = ClampHeightInput(manualPlat, maxPlat)
        ApplyCustomFootwearHeight(modState, player, sys, shoeState, shoeKey, shoeState.heelCm, clampedPlat, saveOverridesCallback)
    end
    ImGui.TextDisabled("  -> Front sole thickness: lifts character puppet in Third Person & Photo Mode")
    ImGui.TextDisabled(string.format("  -> Manual input: Type exact cm or use +/- (Auto-clamps: 0.0 to %.1f cm; negative values disallowed)", maxPlat))

    ImGui.Spacing()

    -- Reset custom overrides for current shoe
    if hasPreset and hasUserOverride then
        if ImGui.Button("Reset to Preset##ifp_reset_shoe") and canEdit then
            if modState.userOverrides then
                modState.userOverrides[shoeKey] = nil
            end
            local preset = modState.presets[shoeKey]
            local pHeel = preset.heel or 0.0
            local pPlat = preset.platform or 0.0
            shoeState.heelCm = pHeel
            shoeState.platformCm = pPlat
            modState.overrides[shoeKey] = { heel = pHeel, platform = pPlat }
            sys:SetCustomHeightOverride(player, pHeel / 100.0, pPlat / 100.0)
            if saveOverridesCallback then
                saveOverridesCallback()
            end
        end
        ImGui.SameLine()
        ImGui.TextDisabled(string.format("(Reverts to preset: Heel %.1f cm, Plat %.1f cm)",
            modState.presets[shoeKey].heel or 0.0, modState.presets[shoeKey].platform or 0.0))
    else
        if ImGui.Button("Reset Height to 0.0 cm##ifp_reset_shoe") and canEdit then
            shoeState.heelCm = 0.0
            shoeState.platformCm = 0.0
            if modState.userOverrides and modState.userOverrides[shoeKey] then
                modState.userOverrides[shoeKey] = nil
            end
            if modState.overrides[shoeKey] then
                modState.overrides[shoeKey] = nil
            end
            sys:ClearCustomHeightOverride(player)
            if saveOverridesCallback then
                saveOverridesCallback()
            end
        end
        ImGui.SameLine()
        ImGui.TextDisabled("(Auto-saved per shoe)")
    end
end

--- Render expandable guide accordion explaining shoe anatomy and height measurement
local function DrawHeightGuideAccordion()
    ImGui.Spacing()
    if ImGui.TreeNode("Shoe Height Guide & Anatomy##ifp_height_guide") then
        ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "Heel Height (FPP Gameplay):")
        ImGui.TextWrapped("Total vertical elevation from the ground to V's heel inside the shoe. Elevates 1st-person camera and skeleton stance.")
        ImGui.Spacing()
        ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "Platform Height (Photo Mode):")
        ImGui.TextWrapped("Thickness of the front sole under the ball/toes. Elevates V's 3rd-person model in Photo Mode so thick soles don't sink into the ground.")
        ImGui.Spacing()
        ImGui.TextColored(1.0, 0.85, 0.3, 1.0, "Photo Mode Measurement:")
        ImGui.TextWrapped("1. Platform: Move PM 'V Up/Down' UP until front sole touches floor = Platform Height.")
        ImGui.TextWrapped("2. Heel: Move PM 'V Up/Down' DOWN until heel touches floor + Platform = Total Heel Height.")
        ImGui.TreePop()
    end
end

--- Render Photo Mode auto-elevation toggle and live status
local function DrawPhotoModeOptions(modState, shoeState, saveSettingsCallback)
    ImGui.Spacing()
    local pmChanged
    modState.autoElevatePMPlatform, pmChanged = ImGui.Checkbox("Auto-Elevate Platform Sole in Photo Mode##ifp_pm_elevate", modState.autoElevatePMPlatform)
    if pmChanged and saveSettingsCallback then
        saveSettingsCallback()
    end

    if modState.isPhotoModeOpen then
        ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.9, 1.0, 1.0)
        if shoeState.platformCm > 0.0 and modState.autoElevatePMPlatform then
            ImGui.Text(string.format("Photo Mode: Active (+%.1f cm Platform Sole Elevated)", shoeState.platformCm))
        else
            ImGui.Text("Photo Mode: Active (Flat/Stiletto Sole Grounded)")
        end
        ImGui.PopStyleColor(1)
    end
end

--- Render active stance status and elevation readout
local function DrawStanceReadout(modState, shoeState, isAppended, sys, heightAdjustmentEnabled)
    ImGui.Separator()
    if shoeState.isSuppressed then
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.75, 0.2, 1.0)
        ImGui.Text(string.format("Stance Elevation: Temporarily Suppressed (%s)", shoeState.suppressionReason))
        ImGui.PopStyleColor(1)
        ImGui.TextDisabled("Elevation will smoothly restore upon standing / exiting.")
    elseif isAppended and heightAdjustmentEnabled == false then
        ImGui.TextDisabled("First-Person Footwear Lift: 0.0 cm (Disabled in IFP settings)")
        if sys and sys.IsITPPresent and sys:IsITPPresent() then
            local platCm = shoeState.isSuppressed and 0.0 or (shoeState.platformCm or 0.0)
            local statusStr = modState.isITPActive and "[ACTIVE VIEW]" or "[FPP Active]"
            ImGui.TextColored(0.4, 0.8, 1.0, 1.0, string.format("3rd-Person (ITP):  +%.1f cm (Platform Lift) %s", platCm, statusStr))
        end
    else
        if isAppended then
            ImGui.Text(string.format("Base Height (IFP): %+d cm", math.floor(modState.ifpBaseHeightCm + 0.5)))
            ImGui.Text(string.format("Footwear Lift:     +%.1f cm", shoeState.effectiveCm))
            ImGui.TextColored(0.2, 1.0, 0.4, 1.0, string.format("Total Stance Lift: %+d cm (Base + Shoes)", math.floor(shoeState.totalStanceCm + 0.5)))
        else
            ImGui.TextColored(0.2, 1.0, 0.4, 1.0, string.format("Footwear Stance Lift: +%.1f cm", shoeState.effectiveCm))
        end

        if sys and sys.IsITPPresent and sys:IsITPPresent() then
            local platCm = shoeState.isSuppressed and 0.0 or (shoeState.platformCm or 0.0)
            local statusStr = modState.isITPActive and "[ACTIVE VIEW]" or "[FPP Active]"
            ImGui.TextColored(0.4, 0.8, 1.0, 1.0, string.format("3rd-Person (ITP):  +%.1f cm (Platform Lift) %s", platCm, statusStr))
        end
    end
end

--- Render Tab 1: Footwear Calibration & Stance Settings
local function DrawFootwearTab(modState, player, sys, heightLimits, saveOverridesCallback, saveSettingsCallback, isAppended, heightAdjustmentEnabled)
    local shoeState = modState.currentShoeState

    if not shoeState.hasShoe or #shoeState.key == 0 then
        ImGui.Spacing()
        ImGui.TextDisabled("Equipped Footwear: Barefoot / None (Flat 0.0 cm)")
        if isAppended and not shoeState.isSuppressed and modState.ifpBaseHeightCm ~= 0.0 then
            ImGui.Text(string.format("Base Height (IFP): %+d cm", math.floor(modState.ifpBaseHeightCm + 0.5)))
        end
        return
    end

    DrawShoeSummary(shoeState)

    if isAppended and heightAdjustmentEnabled == false then
        ImGui.Spacing()
        ImGui.TextColored(1.0, 0.75, 0.2, 1.0, "[!] First-Person Height Adjustment is DISABLED in IFP settings.")
        ImGui.TextDisabled("V's camera eye-line and skeletal stance height are neutral (0.0 cm).")
        ImGui.Spacing()
    end

    if shoeState.isOfficial then
        DrawOfficialFootwearView(shoeState)
    else
        DrawCustomFootwearControls(modState, player, sys, shoeState, heightLimits, saveOverridesCallback)
    end

    DrawHeightGuideAccordion()
    DrawPhotoModeOptions(modState, shoeState, saveSettingsCallback)
    DrawStanceReadout(modState, shoeState, isAppended, sys, heightAdjustmentEnabled)
end

--- Render Tab 2: Catwalk Locomotion & Feminine Stride Settings
local function DrawCatwalkLocomotionTab(modState, sys, saveSettingsCallback)
    ImGui.Spacing()

    -- Check if ITP is installed
    local itpInstalled = (sys and sys.IsITPPresent and sys:IsITPPresent())
        or (modState and modState.isITPActive)
        or false
    if not itpInstalled then
        ImGui.TextColored(1.0, 0.75, 0.2, 1.0, "[!] Immersive Third Person (ITP) Required")
        ImGui.Spacing()
        ImGui.TextWrapped("Catwalk locomotion and dynamic feminine hip sway require the Immersive Third Person (ITP) mod.")
        ImGui.Spacing()
        ImGui.TextDisabled("Please install Immersive Third Person from Nexus Mods to enable 3rd-person catwalk stride, pelvic teeter-totter, and femoral counter-rotation.")
        return
    end

    local changed = false

    -- Master enable toggle (3rd-person catwalk sway)
    local swayVal, swayChanged = ImGui.Checkbox("Enable Catwalk Hip Sway (3rd-Person)##sway_enable", modState.enableHipSway)
    if swayVal ~= modState.enableHipSway or swayChanged then
        modState.enableHipSway = swayVal
        changed = true
    end

    if modState.enableHipSway then
        -- Multipliers per Heel Size
        local lowVal, lowChanged = ImGui.SliderFloat("Low Heel##sway_low", modState.swayLow or 1.0, 0.0, 1.50, "%.2fx")
        if lowChanged then
            modState.swayLow = lowVal
            changed = true
        end

        local midVal, midChanged = ImGui.SliderFloat("Mid Heel##sway_mid", modState.swayMid or 1.0, 0.0, 1.50, "%.2fx")
        if midChanged then
            modState.swayMid = midVal
            changed = true
        end

        local highVal, highChanged = ImGui.SliderFloat("High Heel##sway_high", modState.swayHigh or 1.0, 0.0, 1.50, "%.2fx")
        if highChanged then
            modState.swayHigh = highVal
            changed = true
        end

        -- Heel Size & Sway Information
        local shoeState = modState.currentShoeState
        local heelCm = shoeState and shoeState.heelCm or 0.0
        local platCm = shoeState and shoeState.platformCm or 0.0
        local pitchCm = math.max(0.0, heelCm - platCm)

        ImGui.Spacing()
        ImGui.Separator()
        if pitchCm < 2.0 then
            ImGui.Text(string.format("Current Footwear: Flat / Platform (%.1f cm) -> 0%% Sway", pitchCm))
            ImGui.TextDisabled("Flat shoes, bare feet, and flat platforms have no hip sway.")
        elseif pitchCm < 5.08 then
            local pct = math.floor(35 * ((pitchCm - 2.0) / (2.54 - 2.0)) + 0.5)
            if pitchCm >= 2.54 then
                pct = math.floor(35 + 35 * ((pitchCm - 2.54) / (5.08 - 2.54)) + 0.5)
            end
            ImGui.Text(string.format("Current Heel: %.1f cm (Low Heel) -> %d%% Base Sway (%.2fx)", pitchCm, pct, modState.swayLow or 1.0))
            ImGui.TextDisabled("Controlled by the Low Heel multiplier.")
        elseif pitchCm < 7.50 then
            local pct = math.floor(70 + 30 * ((pitchCm - 5.08) / (7.50 - 5.08)) + 0.5)
            ImGui.Text(string.format("Current Heel: %.1f cm (Mid Heel) -> %d%% Base Sway (%.2fx)", pitchCm, pct, modState.swayMid or 1.0))
            ImGui.TextDisabled("Controlled by the Mid Heel multiplier.")
        else
            ImGui.Text(string.format("Current Heel: %.1f cm (High Heel) -> 100%% Base Sway (%.2fx)", pitchCm, modState.swayHigh or 1.0))
            ImGui.TextDisabled("Controlled by the High Heel multiplier.")
        end
    else
        ImGui.TextDisabled("Procedural catwalk hip sway is disabled. Standard neutral walk cycle active.")
    end

    if changed and saveSettingsCallback then
        saveSettingsCallback()
    end
end

--- Render Footwear Configuration Controls with Tabbed Organization
local function DrawFootwearControls(modState, player, sys, heightLimits, saveOverridesCallback, isAppended, heightAdjustmentEnabled, saveSettingsCallback)
    if ImGui.BeginTabBar("##IFP_MainTabBar") then
        if ImGui.BeginTabItem("Footwear & Stance##TabFootwear") then
            DrawFootwearTab(modState, player, sys, heightLimits, saveOverridesCallback, saveSettingsCallback, isAppended, heightAdjustmentEnabled)
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem("Hip Sway##TabHipSway") then
            DrawCatwalkLocomotionTab(modState, sys, saveSettingsCallback)
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
end

--- Render Footwear UI (Standalone Window or Appended to IFP Window)
--- When IFP is installed and TFP is not active: strictly attaches to IFP window.
--- Never show the self-contained config window when IFP is installed and height adjustment is disabled.
---@param modState table
---@param player table
---@param sys table
---@param heightLimits table
---@param saveOverridesCallback function
---@param ifpIntegration table
---@param saveSettingsCallback function|nil
function UIManager.DrawUI(modState, player, sys, heightLimits, saveOverridesCallback, ifpIntegration, saveSettingsCallback)
    saveSettingsCallback = saveSettingsCallback or saveOverridesCallback

    local isTFP = (sys and sys.IsTFPPresent and sys:IsTFPPresent()) or false
    local ifpInstalled = ifpIntegration and ifpIntegration.IsInstalled and ifpIntegration.IsInstalled() or false
    local ifpEnabled = ifpIntegration and ifpIntegration.IsEnabled and ifpIntegration.IsEnabled() or false
    local heightAdjustmentEnabled = ifpIntegration and ifpIntegration.IsHeightAdjustmentEnabled and ifpIntegration.IsHeightAdjustmentEnabled() or false

    -- Strict Rule: When IFP is installed (and TFP is not active), NEVER show
    -- the standalone "Immersive Footwear POV" window!
    if ifpInstalled and not isTFP then
        if ifpEnabled then
            if ImGui.Begin("Immersive First Person") then
                ImGui.Spacing()
                ImGui.Separator()
                ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "[Immersive Footwear POV Extension]")
                DrawFootwearControls(modState, player, sys, heightLimits, saveOverridesCallback, true, heightAdjustmentEnabled, saveSettingsCallback)
            end
            ImGui.End()
        end
        -- Strictly return here so the self-contained window is NEVER spawned when IFP is installed
        return
    end

    -- Standalone window (ONLY when IFP is NOT installed, or TFP is active)
    if ImGui.Begin("Immersive Footwear POV", ImGuiWindowFlags.AlwaysAutoResize) then
        ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "[Immersive Footwear POV]")
        if isTFP then
            ImGui.TextDisabled("Active POV Engine: True First Person (TFP Native REDscript)")
        elseif sys and sys.IsITPPresent and sys:IsITPPresent() then
            ImGui.TextDisabled("Active POV Engine: Immersive Third Person (ITP Active)")
        else
            ImGui.TextDisabled("Active POV Engine: Standalone / Photo Mode (PM)")
        end
        ImGui.Separator()
        DrawFootwearControls(modState, player, sys, heightLimits, saveOverridesCallback, false, true, saveSettingsCallback)
    end
    ImGui.End()
end

return UIManager
