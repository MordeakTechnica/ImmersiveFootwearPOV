-- =============================================================================
-- Immersive Footwear POV - Immersive First Person (IFP) CET Integration
-- Handles IFP native state polling, additive animgraph blend, and CET UI appending
-- =============================================================================

local IFP = {
    inputName = nil,
}

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
function IFP.ApplyBlend(player, activeBlend)
    if not IFP.inputName then
        IFP.inputName = CName.new("ifp_height_blend")
    end
    AnimationControllerComponent.SetInputFloat(player, IFP.inputName, activeBlend)
end

-- -----------------------------------------------------------------------------
-- Render Footwear UI directly inside the native IFP CET Window
-- -----------------------------------------------------------------------------
function IFP.DrawUI(modState, player, sys, heightLimits, saveOverridesCallback)
    if not ImGui.Begin("Immersive First Person") then
        return
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "[Immersive Footwear POV Extension]")

    local shoeState = modState.currentShoeState

    if not shoeState.hasShoe or #shoeState.key == 0 then
        ImGui.TextDisabled("Equipped Footwear: Barefoot / None (Flat 0.0 cm)")
        if not shoeState.isSuppressed and modState.ifpBaseHeightCm ~= 0.0 then
            ImGui.Text(string.format("Base Height (IFP): %+d cm", math.floor(modState.ifpBaseHeightCm + 0.5)))
        end
    else
        ImGui.Text(string.format("Equipped: %s", shoeState.displayName))
        ImGui.TextDisabled(string.format("Source: %s | ID: %s", shoeState.source, shoeState.key))

        if shoeState.isOfficial then
            -- Official TweakDB tags found -> Read-only display
            ImGui.TextColored(0.2, 0.9, 0.3, 1.0, "Tags: Official TweakDB Metadata (Locked)")
            ImGui.Text(string.format("Heel Height:     +%.1f cm (Active FPP Eye Lift)", shoeState.heelCm))
            if shoeState.platformCm > 0.0 then
                ImGui.Text(string.format("Platform Sole:   +%.1f cm (Photo Mode Puppet Lift)", shoeState.platformCm))
            end
        else
            -- Untagged shoe -> Interactive custom override sliders
            ImGui.TextColored(1.0, 0.85, 0.2, 1.0, "Tags: None Found (Custom Override)")

            local shoeKey = shoeState.key
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
            local platVal, platChanged = ImGui.SliderFloat("Custom Platform (PM)##ifp_custom_plat", shoeState.platformCm, 0.0, heightLimits.MAX_PLATFORM_CM, "%.1f cm")
            ImGui.TextDisabled("  -> Front sole thickness: lifts character puppet in Photo Mode")
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

        -- Collapsible In-Game Height & Measuring Guide
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

        -- Photo Mode Elevation Configuration
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

        -- Display effective stance breakdown (IFP Base + Footwear Heel)
        ImGui.Separator()
        if shoeState.isSuppressed then
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.75, 0.2, 1.0)
            ImGui.Text(string.format("First-Person Stance: Temporarily Suppressed (%s)", shoeState.suppressionReason))
            ImGui.PopStyleColor(1)
            ImGui.TextDisabled("Elevation will smoothly restore upon standing / exiting.")
        else
            ImGui.Text(string.format("Base Height (IFP): %+d cm", math.floor(modState.ifpBaseHeightCm + 0.5)))
            ImGui.Text(string.format("Footwear Lift:     +%.1f cm", shoeState.effectiveCm))
            ImGui.TextColored(0.2, 1.0, 0.4, 1.0, string.format("Total Stance Lift: %+d cm (Base + Shoes)", math.floor(shoeState.totalStanceCm + 0.5)))
        end
    end

    ImGui.End()
end

return IFP
