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

local cachedConfigSetting = nil
local lastConfigFileCheck = 0.0

-- -----------------------------------------------------------------------------
-- Query IFP Height Adjustment Status
-- Checks if IFP itself is enabled AND if height adjustment is enabled
-- -----------------------------------------------------------------------------
function IFP.IsHeightAdjustmentEnabled()
    local ifp = GetMod("ImmersiveFirstPerson") or GetMod("immersive_first_person")
    if not ifp then
        return false
    end

    -- If IFP is globally disabled, height adjustment is effectively disabled
    if not IFP.IsEnabled() then
        return false
    end

    -- 1. Query dynamic in-memory API methods if provided by IFP
    if ifp.api then
        if type(ifp.api.IsHeightAdjustmentEnabled) == "function" then
            local ok, val = pcall(ifp.api.IsHeightAdjustmentEnabled)
            if ok and val ~= nil then return val == true end
        end
        if type(ifp.api.IsHeightEnabled) == "function" then
            local ok, val = pcall(ifp.api.IsHeightEnabled)
            if ok and val ~= nil then return val == true end
        end
        if type(ifp.api.GetHeightAdjustmentEnabled) == "function" then
            local ok, val = pcall(ifp.api.GetHeightAdjustmentEnabled)
            if ok and val ~= nil then return val == true end
        end
        if type(ifp.api.GetHeightState) == "function" then
            local ok, state = pcall(ifp.api.GetHeightState)
            if ok and type(state) == "table" then
                if state.heightAdjustmentEnabled ~= nil then return state.heightAdjustmentEnabled == true end
                if state.isHeightAdjustmentEnabled ~= nil then return state.isHeightAdjustmentEnabled == true end
                if state.enabled ~= nil then return state.enabled == true end
            end
        end
    end

    -- 2. Query in-memory configuration objects
    if type(ifp.config) == "table" and ifp.config.heightAdjustmentEnabled ~= nil then
        return ifp.config.heightAdjustmentEnabled == true
    end
    if type(ifp.settings) == "table" and ifp.settings.heightAdjustmentEnabled ~= nil then
        return ifp.settings.heightAdjustmentEnabled == true
    end
    if type(ifp.Config) == "table" and type(ifp.Config.inner) == "table" and ifp.Config.inner.heightAdjustmentEnabled ~= nil then
        return ifp.Config.inner.heightAdjustmentEnabled == true
    end

    -- 3. File fallback: read IFP's config.json (throttled check)
    local now = os.clock and os.clock() or 0.0
    if now - lastConfigFileCheck >= 0.5 or cachedConfigSetting == nil then
        lastConfigFileCheck = now
        local configPath = "bin/x64/plugins/cyber_engine_tweaks/mods/ImmersiveFirstPerson/config.json"
        local f = io.open(configPath, "r")
        if f then
            local content = f:read("*a")
            f:close()
            if content and json and json.decode then
                local ok, parsed = pcall(json.decode, content)
                if ok and type(parsed) == "table" and parsed.heightAdjustmentEnabled ~= nil then
                    cachedConfigSetting = (parsed.heightAdjustmentEnabled == true)
                end
            end
        end
    end

    if cachedConfigSetting ~= nil then
        return cachedConfigSetting
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

-- -----------------------------------------------------------------------------
-- Render Tab 1: Footwear Calibration & Stance Settings
-- -----------------------------------------------------------------------------
local function DrawFootwearTab(modState, player, sys, heightLimits, saveOverridesCallback, isAppended, heightAdjustmentEnabled)
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
    DrawPhotoModeOptions(modState, shoeState, saveOverridesCallback)
    DrawStanceReadout(modState, shoeState, isAppended, sys, heightAdjustmentEnabled)
end

-- -----------------------------------------------------------------------------
-- Render Tab 2: Catwalk Locomotion & Feminine Stride Settings
-- Enforces ITP (Immersive Third Person) dependency
-- -----------------------------------------------------------------------------
local function DrawCatwalkLocomotionTab(modState, sys, saveOverridesCallback)
    ImGui.Spacing()

    -- Check if ITP is installed
    local itpInstalled = (sys and sys.IsITPPresent and sys:IsITPPresent()) or false
    if not itpInstalled then
        ImGui.TextColored(1.0, 0.75, 0.2, 1.0, "[!] Immersive Third Person (ITP) Required")
        ImGui.Spacing()
        ImGui.TextWrapped("Catwalk locomotion and dynamic feminine hip sway require the Immersive Third Person (ITP) mod.")
        ImGui.Spacing()
        ImGui.TextDisabled("Please install Immersive Third Person from Nexus Mods to enable 3rd-person catwalk stride, pelvic teeter-totter, and femoral counter-rotation.")
        return
    end

    local changed = false

    -- 1. Master enable toggle (3rd-person catwalk sway)
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

    if changed and saveOverridesCallback then
        saveOverridesCallback()
    end
end

-- -----------------------------------------------------------------------------
-- Render Footwear Configuration Controls with Tabbed Organization
-- -----------------------------------------------------------------------------
local function DrawFootwearControls(modState, player, sys, heightLimits, saveOverridesCallback, isAppended, heightAdjustmentEnabled)
    if ImGui.BeginTabBar("##IFP_MainTabBar") then
        if ImGui.BeginTabItem("Footwear & Stance##TabFootwear") then
            DrawFootwearTab(modState, player, sys, heightLimits, saveOverridesCallback, isAppended, heightAdjustmentEnabled)
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem("Hip Sway##TabHipSway") then
            DrawCatwalkLocomotionTab(modState, sys, saveOverridesCallback)
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
end

-- -----------------------------------------------------------------------------
-- Render Footwear UI (Standalone Window or Appended to IFP Window)
-- When IFP is installed and TFP is not active: strictly attaches to IFP window.
-- Never show the self-contained config window when IFP is installed and height adjustment is disabled.
-- -----------------------------------------------------------------------------
function IFP.DrawUI(modState, player, sys, heightLimits, saveOverridesCallback)
    local isTFP = (sys and sys.IsTFPPresent and sys:IsTFPPresent()) or false
    local ifpInstalled = IFP.IsInstalled()
    local ifpEnabled = IFP.IsEnabled()
    local heightAdjustmentEnabled = IFP.IsHeightAdjustmentEnabled()

    -- Strict Rule: When IFP is installed (and TFP is not active), NEVER show
    -- the standalone "Immersive Footwear POV" window!
    if ifpInstalled and not isTFP then
        if ifpEnabled then
            if ImGui.Begin("Immersive First Person") then
                ImGui.Spacing()
                ImGui.Separator()
                ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "[Immersive Footwear POV Extension]")
                DrawFootwearControls(modState, player, sys, heightLimits, saveOverridesCallback, true, heightAdjustmentEnabled)
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
        DrawFootwearControls(modState, player, sys, heightLimits, saveOverridesCallback, false, true)
    end
    ImGui.End()
end

return IFP
