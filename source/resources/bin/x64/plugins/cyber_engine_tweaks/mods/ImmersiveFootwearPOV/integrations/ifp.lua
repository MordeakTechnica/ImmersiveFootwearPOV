-- =============================================================================
-- Immersive Footwear POV - Immersive First Person (IFP) CET Integration
-- Handles IFP native state polling, additive animgraph blend, and CET UI appending
-- =============================================================================

local IFP = {
    inputName = nil,
}

-- -----------------------------------------------------------------------------
-- Query IFP Installation Status
-- -----------------------------------------------------------------------------
function IFP.IsInstalled()
    local ifp = GetMod("ImmersiveFirstPerson") or GetMod("immersive_first_person")
    return ifp ~= nil
end

-- -----------------------------------------------------------------------------
-- Query IFP Enabled Status via In-Memory API
-- -----------------------------------------------------------------------------
function IFP.IsEnabled()
    local ifp = GetMod("ImmersiveFirstPerson") or GetMod("immersive_first_person")
    if not ifp then
        return false
    end
    if ifp.api and type(ifp.api.IsEnabled) == "function" then
        local success, enabled = pcall(ifp.api.IsEnabled)
        if success then
            return enabled == true
        end
    end
    return true
end

-- -----------------------------------------------------------------------------
-- Query IFP Base Height & Native Suppression via In-Memory API
-- -----------------------------------------------------------------------------
function IFP.GetState()
    local ifp = GetMod("ImmersiveFirstPerson") or GetMod("immersive_first_person")
    if ifp and ifp.api and type(ifp.api.GetHeightState) == "function" then
        local success, state = pcall(ifp.api.GetHeightState)
        if success and type(state) == "table" then
            local height = type(state.effectiveCentimeters) == "number" and state.effectiveCentimeters or 0.0
            local suppressed = state.suppressedBy
            return height, suppressed
        end
    end
    return 0.0, nil
end

-- -----------------------------------------------------------------------------
-- Calculate Animgraph Height Blend (Additive: IFP Base Slider + Footwear Heel)
-- Range: -50cm (-0.50m) to +50cm (+0.50m) mapped to [0.0, 1.0], Neutral = 0.50
-- -----------------------------------------------------------------------------
function IFP.CalculateTargetBlend(shoeOffsetMeters, ifpBaseHeightCm, isSuppressed)
    local totalOffsetMeters = 0.0

    if isSuppressed then
        -- In suppressed contexts (vehicles, workspots, scenes), return to neutral (0.0m)
        totalOffsetMeters = 0.0
    else
        local baseMeters = (ifpBaseHeightCm or 0.0) / 100.0
        totalOffsetMeters = baseMeters + (shoeOffsetMeters or 0.0)
    end

    local blend = (totalOffsetMeters + 0.50) / 1.00
    if blend < 0.0 then blend = 0.0 end
    if blend > 1.0 then blend = 1.0 end
    return blend, totalOffsetMeters
end

-- -----------------------------------------------------------------------------
-- Apply Active Blend Value to Character Animation Component
-- -----------------------------------------------------------------------------
function IFP.ApplyBlend(player, activeBlend, offsetMeters)
    if not IFP.inputName then
        IFP.inputName = CName.new("ifp_height_blend")
    end
    if not IFP.footElevationName then
        IFP.footElevationName = CName.new("foot_elevation_offset")
    end
    AnimationControllerComponent.SetInputFloat(player, IFP.inputName, activeBlend)
    if offsetMeters ~= nil then
        AnimationControllerComponent.SetInputFloat(player, IFP.footElevationName, offsetMeters)
    end
end

-- -----------------------------------------------------------------------------
-- Modular UI Section Renderers
-- -----------------------------------------------------------------------------

local function DrawShoeSummary(shoeState)
    ImGui.Text(string.format("Equipped: %s", shoeState.displayName))
    ImGui.TextDisabled(string.format("Source: %s | ID: %s", shoeState.source, shoeState.key))
end

local function DrawOfficialFootwearView(shoeState)
    ImGui.TextColored(0.2, 0.9, 0.3, 1.0, "Tags: Official TweakDB Metadata (Locked)")
    ImGui.Text(string.format("Heel Height:     +%.1f cm (Active FPP Eye Lift)", shoeState.heelCm))
    if shoeState.platformCm > 0.0 then
        ImGui.Text(string.format("Platform Sole:   +%.1f cm (Photo Mode Puppet Lift)", shoeState.platformCm))
    end
end

local function DrawCustomFootwearControls(modState, player, sys, shoeState, heightLimits, saveOverridesCallback)
    ImGui.TextColored(1.0, 0.85, 0.2, 1.0, "Tags: None Found (Custom Override)")

    local shoeKey = shoeState.key

    -- Custom Heel Height Slider (Elevates 1st-person camera in gameplay)
    local heelVal, heelChanged = ImGui.SliderFloat("Custom Heel (FPP)##ifp_custom_heel", shoeState.heelCm, 0.0, heightLimits.MAX_HEEL_CM, "%.1f cm")
    ImGui.TextDisabled("  -> Total heel lift: elevates V's 1st-person camera in gameplay")
    if heelChanged and player and sys and #shoeKey > 0 then
        shoeState.heelCm = heelVal
        if not modState.overrides[shoeKey] then
            modState.overrides[shoeKey] = {}
        end
        modState.overrides[shoeKey].heel = heelVal
        modState.overrides[shoeKey].platform = shoeState.platformCm
        saveOverridesCallback()

        local heelMeters = heelVal / 100.0
        local platMeters = shoeState.platformCm / 100.0
        sys:SetCustomHeightOverride(player, heelMeters, platMeters)
    end

    ImGui.Spacing()

    -- Custom Platform Height Slider (Lifts character puppet in Third Person & Photo Mode)
    local platVal, platChanged = ImGui.SliderFloat("Custom Platform (3rd Person / PM)##ifp_custom_plat", shoeState.platformCm, 0.0, heightLimits.MAX_PLATFORM_CM, "%.1f cm")
    ImGui.TextDisabled("  -> Front sole thickness: lifts character puppet in Third Person & Photo Mode")
    if platChanged and player and sys and #shoeKey > 0 then
        shoeState.platformCm = platVal
        if not modState.overrides[shoeKey] then
            modState.overrides[shoeKey] = {}
        end
        modState.overrides[shoeKey].heel = shoeState.heelCm
        modState.overrides[shoeKey].platform = platVal
        saveOverridesCallback()

        local heelMeters = shoeState.heelCm / 100.0
        local platMeters = platVal / 100.0
        sys:SetCustomHeightOverride(player, heelMeters, platMeters)
    end

    ImGui.Spacing()

    -- Reset custom overrides for current shoe
    if ImGui.Button("Reset Height to 0.0 cm##ifp_reset_shoe") and player and sys and #shoeKey > 0 then
        shoeState.heelCm = 0.0
        shoeState.platformCm = 0.0
        if modState.overrides[shoeKey] then
            modState.overrides[shoeKey] = nil
            saveOverridesCallback()
        end
        sys:ClearCustomHeightOverride(player)
    end
    ImGui.SameLine()
    ImGui.TextDisabled("(Auto-saved per shoe)")
end

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

local function DrawPhotoModeOptions(modState, shoeState, saveOverridesCallback)
    ImGui.Spacing()
    local pmChanged
    modState.autoElevatePMPlatform, pmChanged = ImGui.Checkbox("Auto-Elevate Platform Sole in Photo Mode##ifp_pm_elevate", modState.autoElevatePMPlatform)
    if pmChanged then
        saveOverridesCallback()
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

local function DrawStanceReadout(modState, shoeState, isAppended, sys)
    ImGui.Separator()
    if shoeState.isSuppressed then
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.75, 0.2, 1.0)
        ImGui.Text(string.format("Stance Elevation: Temporarily Suppressed (%s)", shoeState.suppressionReason))
        ImGui.PopStyleColor(1)
        ImGui.TextDisabled("Elevation will smoothly restore upon standing / exiting.")
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

local function DrawHipSwayControls(modState, saveOverridesCallback)
    ImGui.Spacing()
    ImGui.Separator()
    if ImGui.TreeNodeEx("[Experimental] Feminine Stride & Hip Sway", ImGuiTreeNodeFlags.DefaultOpen) then
        local changed = false

        -- 1. Master enable toggle
        local enabled, clickedEnabled = ImGui.Checkbox("Enable Dynamic Hip Sway (Heels)##sway_enable", modState.enableHipSway)
        if clickedEnabled then
            modState.enableHipSway = enabled
            changed = true
        end

        if modState.enableHipSway then
            -- 2. First-Person Camera Motion / Head Bob toggle
            local headBob, clickedBob = ImGui.Checkbox("Enable First-Person Camera Motion in Immersive First Person##sway_headbob", modState.enableFPPHeadBob)
            if clickedBob then
                modState.enableFPPHeadBob = headBob
                changed = true
            end
            if not modState.enableFPPHeadBob then
                ImGui.TextDisabled("Camera is stabilized steady-cam in First Person (Zero motion sickness).")
            else
                ImGui.TextDisabled("Camera receives natural spine motion matching walking gait.")
            end

            -- 3. Intensity Slider (0.50x to 1.50x)
            local intensity, changedIntensity = ImGui.SliderFloat("Sway Intensity##sway_intensity", modState.hipSwayIntensity, 0.50, 1.50, "%.2fx")
            if changedIntensity then
                modState.hipSwayIntensity = intensity
                changed = true
            end

            -- 4. Live diagnostic status
            local strideMod = modState.stride
            if strideMod and strideMod.GetStatus then
                local status, roll, yaw, blend = strideMod.GetStatus()
                ImGui.Spacing()
                ImGui.TextColored(0.3, 0.9, 0.8, 1.0, string.format("Stride Status: %s", status))
                if blend and blend > 0.01 then
                    ImGui.TextDisabled(string.format("Live Hip Angles: Roll %+.1f° | Yaw %+.1f° | Blend: %.0f%%", roll or 0.0, yaw or 0.0, (blend or 0.0) * 100))
                end
            end
        else
            ImGui.TextDisabled("Procedural hip sway is disabled. Standard neutral walk cycle active.")
        end

        if changed and saveOverridesCallback then
            saveOverridesCallback()
        end

        ImGui.TreePop()
    end
end

-- -----------------------------------------------------------------------------
-- Render Footwear Configuration Controls & Telemetry Readouts
-- -----------------------------------------------------------------------------
local function DrawFootwearControls(modState, player, sys, heightLimits, saveOverridesCallback, isAppended)
    local shoeState = modState.currentShoeState

    if not shoeState.hasShoe or #shoeState.key == 0 then
        ImGui.TextDisabled("Equipped Footwear: Barefoot / None (Flat 0.0 cm)")
        if isAppended and not shoeState.isSuppressed and modState.ifpBaseHeightCm ~= 0.0 then
            ImGui.Text(string.format("Base Height (IFP): %+d cm", math.floor(modState.ifpBaseHeightCm + 0.5)))
        end
        DrawHipSwayControls(modState, saveOverridesCallback)
        return
    end

    DrawShoeSummary(shoeState)

    if shoeState.isOfficial then
        DrawOfficialFootwearView(shoeState)
    else
        DrawCustomFootwearControls(modState, player, sys, shoeState, heightLimits, saveOverridesCallback)
    end

    DrawHeightGuideAccordion()
    DrawPhotoModeOptions(modState, shoeState, saveOverridesCallback)
    DrawHipSwayControls(modState, saveOverridesCallback)
    DrawStanceReadout(modState, shoeState, isAppended, sys)
end

-- -----------------------------------------------------------------------------
-- Render Footwear UI (Standalone Window or Appended to IFP Window)
-- When IFP is enabled (and TFP is not active), config is ONLY attached to IFP window.
-- When either no 3rd-party POV mod or TFP is installed, adds its own window.
-- -----------------------------------------------------------------------------
function IFP.DrawUI(modState, player, sys, heightLimits, saveOverridesCallback)
    local isTFP = (sys and sys.IsTFPPresent and sys:IsTFPPresent()) or false
    local ifpInstalled = IFP.IsInstalled()
    local ifpEnabled = IFP.IsEnabled()

    -- Attach ONLY to IFP when IFP is installed & enabled, and TFP is not active
    local attachToIFP = (not isTFP) and ifpInstalled and ifpEnabled

    if attachToIFP then
        if ImGui.Begin("Immersive First Person") then
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "[Immersive Footwear POV Extension]")
            DrawFootwearControls(modState, player, sys, heightLimits, saveOverridesCallback, true)
        end
        ImGui.End()
    else
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
            DrawFootwearControls(modState, player, sys, heightLimits, saveOverridesCallback, false)
        end
        ImGui.End()
    end
end

return IFP
