-- =============================================================================
-- Immersive Footwear POV - Cyber Engine Tweaks (CET) Dynamic Bridge
-- Dynamically combines IFP base height slider + footwear heel height
-- Features smooth 0.20s transitions, context suppression & Photo Mode support
-- Renders both as a standalone CET window and appended inside IFP's window
-- =============================================================================

local mod = {
    inputName = nil,
    pollTimer = 0.0,
    ifpPollTimer = 0.0,
    ifpBaseHeightCm = 0.0,
    overridesFile = "user_shoe_overrides.json",
    overrides = {},
    lastEquippedKey = "",
    
    -- Smooth Transition State
    TRANSITION_DURATION = 0.20,
    currentBlend = 0.50,
    startBlend = 0.50,
    targetBlend = 0.50,
    transitionElapsed = 0.20,

    -- Photo Mode Integration
    isPhotoModeOpen = false,
    pmController = nil,
    autoApplyPMHeight = true,
    currentPMPlatformOffsetCm = 0.0,

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
        suppressionReason = ""
    }
}

-- -----------------------------------------------------------------------------
-- Mathematical Easing Function (Smoothstep)
-- -----------------------------------------------------------------------------
local function smoothstep(t)
    t = math.max(0.0, math.min(1.0, t))
    return t * t * (3.0 - 2.0 * t)
end

-- -----------------------------------------------------------------------------
-- JSON Persistence for Custom Per-Shoe Height Overrides
-- -----------------------------------------------------------------------------
local function LoadOverrides()
    local file = io.open(mod.overridesFile, "r")
    if file then
        local content = file:read("*a")
        file:close()
        if content and #content > 0 then
            local success, data = pcall(function() return json.decode(content) end)
            if success and type(data) == "table" then
                mod.overrides = data
                return
            end
        end
    end
    mod.overrides = {}
end

local function SaveOverrides()
    local file = io.open(mod.overridesFile, "w")
    if file then
        local success, encoded = pcall(function() return json.encode(mod.overrides) end)
        if success and encoded then
            file:write(encoded)
        end
        file:close()
    end
end

-- -----------------------------------------------------------------------------
-- Read IFP Native Base Height & Suppression via In-Memory API
-- -----------------------------------------------------------------------------
local function GetIFPState()
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
-- Animgraph Height Blend Calculation (Additive: Base Height + Footwear Heel)
-- -----------------------------------------------------------------------------
local function GetInputName()
    if not mod.inputName then
        mod.inputName = CName.new("ifp_height_blend")
    end
    return mod.inputName
end

local function CalculateTargetBlend(shoeOffsetMeters, ifpBaseHeightCm, isSuppressed)
    local totalOffsetMeters = 0.0

    if isSuppressed then
        -- In suppressed contexts (vehicles, workspots, scenes, photo mode), return to neutral (0.0m)
        totalOffsetMeters = 0.0
    else
        local baseMeters = (ifpBaseHeightCm or 0.0) / 100.0
        totalOffsetMeters = baseMeters + (shoeOffsetMeters or 0.0)
    end

    -- Linear blend mapping: -50cm (-0.50m) to +50cm (+0.50m) -> [0.0, 1.0]
    -- Neutral (0.0m) -> 0.50
    local blend = (totalOffsetMeters + 0.50) / 1.00
    if blend < 0.0 then blend = 0.0 end
    if blend > 1.0 then blend = 1.0 end
    return blend, totalOffsetMeters
end

local function SetTargetBlend(newTarget)
    newTarget = math.max(0.0, math.min(1.0, newTarget))
    if math.abs(newTarget - mod.targetBlend) < 0.0001 then
        return
    end
    mod.startBlend = mod.currentBlend
    mod.targetBlend = newTarget
    mod.transitionElapsed = 0.0
end

local function UpdateTransition(deltaTime)
    if mod.transitionElapsed >= mod.TRANSITION_DURATION then
        mod.currentBlend = mod.targetBlend
    else
        mod.transitionElapsed = math.min(
            mod.TRANSITION_DURATION,
            mod.transitionElapsed + math.max(tonumber(deltaTime) or 0.0, 0.0)
        )
        local progress = mod.TRANSITION_DURATION <= 0.0
            and 1.0
            or mod.transitionElapsed / mod.TRANSITION_DURATION
        local eased = smoothstep(progress)
        mod.currentBlend = mod.startBlend + (mod.targetBlend - mod.startBlend) * eased
    end
    return mod.currentBlend
end

-- -----------------------------------------------------------------------------
-- Synchronize Shoe State with REDscript System
-- -----------------------------------------------------------------------------
local function SyncShoeState(player, sys)
    if not player or not sys then return end

    local shoeID = sys:GetEquippedFootwearID()
    local hasShoe = shoeID and shoeID.hash ~= 0
    local shoeKey = sys:GetResolvedShoeTDBIDString()
    local isOfficial = sys:HasOfficialTweakTags()
    local sourceName = sys:GetActiveSource()
    local displayName = sys:GetResolvedShoeDisplayName()

    -- Check suppression from REDscript system, IFP bridge, and Photo Mode
    local isRedscriptSuppressed = sys:IsSuppressed()
    local redscriptReason = sys:GetSuppressionReason()
    local ifpHeight, ifpSuppressedReason = GetIFPState()

    mod.ifpBaseHeightCm = ifpHeight
    local isSuppressed = isRedscriptSuppressed or (ifpSuppressedReason ~= nil) or mod.isPhotoModeOpen
    local suppressionReason = isRedscriptSuppressed and redscriptReason or (ifpSuppressedReason or (mod.isPhotoModeOpen and "Photo Mode" or ""))

    mod.currentShoeState.hasShoe = hasShoe
    mod.currentShoeState.key = shoeKey
    mod.currentShoeState.source = sourceName
    mod.currentShoeState.displayName = displayName
    mod.currentShoeState.isOfficial = isOfficial
    mod.currentShoeState.isSuppressed = isSuppressed
    mod.currentShoeState.suppressionReason = suppressionReason

    if hasShoe and #shoeKey > 0 then
        if isOfficial then
            -- Official TweakDB tags found -> Discard obsolete custom override if one was saved
            if mod.overrides[shoeKey] then
                mod.overrides[shoeKey] = nil
                SaveOverrides()
            end
            mod.currentShoeState.heelCm = sys:GetCurrentHeelHeight() * 100.0
            mod.currentShoeState.platformCm = sys:GetCurrentPlatformHeight() * 100.0
        else
            -- Untagged shoe -> Check persistent JSON overrides
            local saved = mod.overrides[shoeKey]
            if saved then
                local heelCm = tonumber(saved.heel) or 0.0
                local platCm = tonumber(saved.platform) or 0.0
                local heelMeters = heelCm / 100.0
                local platMeters = platCm / 100.0

                -- Ensure custom override is active in REDscript
                if not sys:HasCustomOverride() or shoeKey ~= mod.lastEquippedKey or math.abs(sys:GetCurrentHeelHeight() - heelMeters) > 0.0005 then
                    sys:SetCustomHeightOverride(player, heelMeters, platMeters)
                end
                mod.currentShoeState.heelCm = heelCm
                mod.currentShoeState.platformCm = platCm
            else
                -- No saved override -> Ensure clean 0.0 baseline
                if sys:HasCustomOverride() or shoeKey ~= mod.lastEquippedKey then
                    sys:ClearCustomHeightOverride(player)
                end
                mod.currentShoeState.heelCm = 0.0
                mod.currentShoeState.platformCm = 0.0
            end
        end
        mod.lastEquippedKey = shoeKey
    else
        mod.currentShoeState.heelCm = 0.0
        mod.currentShoeState.platformCm = 0.0
        mod.lastEquippedKey = ""
    end

    mod.currentShoeState.effectiveCm = sys:GetEffectiveOffset() * 100.0
end

-- -----------------------------------------------------------------------------
-- Photo Mode Lifecycle & Automatic Platform Height Integration
-- -----------------------------------------------------------------------------
Observe("gameuiPhotoModeMenuController", "OnShow", function(controller)
    mod.pmController = controller
    mod.isPhotoModeOpen = true
    local platformCm = mod.currentShoeState.platformCm or 0.0
    if mod.autoApplyPMHeight and platformCm > 0.0 then
        mod.currentPMPlatformOffsetCm = platformCm
    else
        mod.currentPMPlatformOffsetCm = 0.0
    end
end)

Observe("gameuiPhotoModeMenuController", "OnHide", function()
    mod.isPhotoModeOpen = false
    mod.pmController = nil
    mod.currentPMPlatformOffsetCm = 0.0
end)

-- -----------------------------------------------------------------------------
-- CET Lifecycle Events
-- -----------------------------------------------------------------------------
registerForEvent("onInit", function()
    LoadOverrides()
    local height, _ = GetIFPState()
    mod.ifpBaseHeightCm = height
end)

registerForEvent("onUpdate", function(deltaTime)
    local player = Game.GetPlayer()
    if not player then return end

    local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
    if not sys then return end

    -- Check for footwear / state changes periodically (every 0.15s)
    mod.pollTimer = mod.pollTimer + deltaTime
    if mod.pollTimer >= 0.15 then
        mod.pollTimer = 0.0
        sys:UpdateEquippedFootwear(player)
        SyncShoeState(player, sys)
    end

    -- Poll IFP base height periodically
    mod.ifpPollTimer = mod.ifpPollTimer + deltaTime
    if mod.ifpPollTimer >= 0.10 then
        mod.ifpPollTimer = 0.0
        local height, _ = GetIFPState()
        mod.ifpBaseHeightCm = height
    end

    -- Calculate target blend based on current shoe offset, IFP base slider, and suppression state
    local currentOffset = sys:GetEffectiveOffset()
    local isSuppressed = mod.currentShoeState.isSuppressed or mod.isPhotoModeOpen
    local targetBlend, totalMeters = CalculateTargetBlend(currentOffset, mod.ifpBaseHeightCm, isSuppressed)
    
    SetTargetBlend(targetBlend)
    local activeBlend = UpdateTransition(deltaTime)
    
    mod.currentShoeState.totalStanceCm = (activeBlend * 1.00 - 0.50) * 100.0
    AnimationControllerComponent.SetInputFloat(player, GetInputName(), activeBlend)
end)

-- -----------------------------------------------------------------------------
-- Core UI Drawer (Used in both standalone window and IFP extension)
-- -----------------------------------------------------------------------------
local function DrawFootwearUI(isAppended)
    local player = Game.GetPlayer()
    local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")

    if isAppended then
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "[Immersive Footwear POV Extension]")
    end

    if not mod.currentShoeState.hasShoe or #mod.currentShoeState.key == 0 then
        ImGui.TextDisabled("Equipped Footwear: Barefoot / None (Flat 0.0 cm)")
        if not mod.currentShoeState.isSuppressed and mod.ifpBaseHeightCm ~= 0.0 then
            ImGui.Text(string.format("Base Height (IFP): %+d cm", math.floor(mod.ifpBaseHeightCm + 0.5)))
        end
    else
        ImGui.Text(string.format("Equipped: %s", mod.currentShoeState.displayName))
        ImGui.TextDisabled(string.format("Source: %s | ID: %s", mod.currentShoeState.source, mod.currentShoeState.key))

        if mod.currentShoeState.isOfficial then
            -- Official TweakDB tags found -> Read-only display
            ImGui.TextColored(0.2, 0.9, 0.3, 1.0, "Tags: Official TweakDB Metadata (Locked)")
            ImGui.Text(string.format("Heel Height:     +%.1f cm (Active FPP)", mod.currentShoeState.heelCm))
            if mod.currentShoeState.platformCm > 0.0 then
                ImGui.Text(string.format("Platform Sole:   +%.1f cm (Auto PM Elevation)", mod.currentShoeState.platformCm))
            else
                ImGui.TextDisabled("Platform Sole:    0.0 cm (Naturally Grounded)")
            end
        else
            -- Untagged shoe -> Interactive custom override sliders
            ImGui.TextColored(1.0, 0.85, 0.2, 1.0, "Tags: None Found (Custom Override)")

            local shoeKey = mod.currentShoeState.key
            local heelVal, heelChanged = ImGui.SliderFloat("Custom Heel (cm)##ifp_custom_heel", mod.currentShoeState.heelCm, 0.0, 15.0, "%.1f cm")
            if heelChanged and player and sys and #shoeKey > 0 then
                mod.currentShoeState.heelCm = heelVal
                if not mod.overrides[shoeKey] then
                    mod.overrides[shoeKey] = {}
                end
                mod.overrides[shoeKey].heel = heelVal
                mod.overrides[shoeKey].platform = mod.currentShoeState.platformCm
                SaveOverrides()

                local heelMeters = heelVal / 100.0
                local platMeters = mod.currentShoeState.platformCm / 100.0
                sys:SetCustomHeightOverride(player, heelMeters, platMeters)
            end

            local platVal, platChanged = ImGui.SliderFloat("Custom Platform (cm)##ifp_custom_plat", mod.currentShoeState.platformCm, 0.0, 10.0, "%.1f cm")
            if platChanged and player and sys and #shoeKey > 0 then
                mod.currentShoeState.platformCm = platVal
                if not mod.overrides[shoeKey] then
                    mod.overrides[shoeKey] = {}
                end
                mod.overrides[shoeKey].heel = mod.currentShoeState.heelCm
                mod.overrides[shoeKey].platform = platVal
                SaveOverrides()

                local heelMeters = mod.currentShoeState.heelCm / 100.0
                local platMeters = platVal / 100.0
                sys:SetCustomHeightOverride(player, heelMeters, platMeters)
            end

            if ImGui.Button("Reset Height to 0.0 cm##ifp_reset_shoe") and player and sys and #shoeKey > 0 then
                mod.currentShoeState.heelCm = 0.0
                mod.currentShoeState.platformCm = 0.0
                if mod.overrides[shoeKey] then
                    mod.overrides[shoeKey] = nil
                    SaveOverrides()
                end
                sys:ClearCustomHeightOverride(player)
            end
            ImGui.SameLine()
            ImGui.TextDisabled("(Auto-saved per shoe)")
        end

        -- Photo Mode Elevation Configuration
        ImGui.Spacing()
        local pmAutoChanged
        mod.autoApplyPMHeight, pmAutoChanged = ImGui.Checkbox("Auto-Apply Platform Elevation in Photo Mode##ifp_pm_auto", mod.autoApplyPMHeight)
        if mod.isPhotoModeOpen then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.9, 1.0, 1.0)
            if mod.currentShoeState.platformCm > 0.0 then
                ImGui.Text(string.format("Photo Mode: Active (+%.1f cm Platform Sole Elevated)", mod.currentShoeState.platformCm))
            else
                ImGui.Text("Photo Mode: Active (Flat/Stiletto Sole Grounded)")
            end
            ImGui.PopStyleColor(1)
        end

        -- Display effective stance breakdown (IFP Base + Footwear Heel)
        ImGui.Separator()
        if mod.currentShoeState.isSuppressed then
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.75, 0.2, 1.0)
            ImGui.Text(string.format("First-Person Stance: Temporarily Suppressed (%s)", mod.currentShoeState.suppressionReason))
            ImGui.PopStyleColor(1)
            ImGui.TextDisabled("Elevation will smoothly restore upon standing / exiting.")
        else
            ImGui.Text(string.format("Base Height (IFP): %+d cm", math.floor(mod.ifpBaseHeightCm + 0.5)))
            ImGui.Text(string.format("Footwear Lift:     +%.1f cm", mod.currentShoeState.effectiveCm))
            ImGui.TextColored(0.2, 1.0, 0.4, 1.0, string.format("Total Stance Lift: %+d cm (Base + Shoes)", math.floor(mod.currentShoeState.totalStanceCm + 0.5)))
        end
    end
end

-- -----------------------------------------------------------------------------
-- Dear ImGui Overlay Event
-- -----------------------------------------------------------------------------
registerForEvent("onDraw", function()
    -- Always update live IFP base height during draw
    local liveHeight, _ = GetIFPState()
    mod.ifpBaseHeightCm = liveHeight

    -- 1. Dedicated Standalone Window (listed directly in CET Bindings/Mods)
    ImGui.SetNextWindowSize(380, 360, ImGuiCond.FirstUseEver)
    if ImGui.Begin("Immersive Footwear POV") then
        DrawFootwearUI(false)
        ImGui.End()
    end

    -- 2. Direct Window Appending to IFP
    if ImGui.Begin("Immersive First Person") then
        DrawFootwearUI(true)
        ImGui.End()
    end
end)

return mod
