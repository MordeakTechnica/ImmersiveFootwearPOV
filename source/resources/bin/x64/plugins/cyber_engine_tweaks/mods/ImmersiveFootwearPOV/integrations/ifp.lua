-- =============================================================================
-- Immersive Footwear POV - Immersive First Person (IFP) Integration Adapter
-- Adapts IFP native state polling, animgraph blend calculation, and animation inputs
-- =============================================================================

local UIManager = require("modules/ui")

local IFP = {
    inputName = nil,
    footElevationName = nil,
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
-- In IFP, footwear height offset strictly capped to max 25cm (0.25m) by default
-- -----------------------------------------------------------------------------
function IFP.CalculateTargetBlend(shoeOffsetMeters, ifpBaseHeightCm, isSuppressed, maxShoeMeters)
    local totalOffsetMeters = 0.0

    if isSuppressed then
        -- In suppressed contexts (vehicles, workspots, scenes), return to neutral (0.0m)
        totalOffsetMeters = 0.0
    else
        local maxMeters = maxShoeMeters or 0.25
        local clampedShoe = math.min(math.max(0.0, shoeOffsetMeters or 0.0), maxMeters)
        local baseMeters = (ifpBaseHeightCm or 0.0) / 100.0
        totalOffsetMeters = baseMeters + clampedShoe
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
-- Render Footwear UI (Backward-compatible delegation to UIManager)
-- -----------------------------------------------------------------------------
function IFP.DrawUI(modState, player, sys, heightLimits, saveOverridesCallback)
    UIManager.DrawUI(modState, player, sys, heightLimits, saveOverridesCallback, IFP)
end

return IFP
