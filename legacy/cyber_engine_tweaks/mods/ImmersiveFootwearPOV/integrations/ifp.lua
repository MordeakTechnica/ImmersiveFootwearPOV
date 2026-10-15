-- =============================================================================
-- Immersive Footwear POV - Immersive First Person (IFP) Integration Adapter
-- Adapts IFP native state polling, animgraph blend calculation, and animation inputs
-- Optimized: caches installation state, throttles height adjustment queries, deduplicates anim inputs
-- =============================================================================

local UIManager = require("modules/ui")
local Logger = require("modules/logger")

local IFP = {
    inputName = nil,
    footElevationName = nil,
}

local isIFPInstalledCache = nil
local cachedHeightAdjEnabled = nil
local lastHeightAdjCheck = 0.0
local cachedConfigSetting = nil
local lastConfigFileCheck = 0.0

local lastAppliedBlend = -999.0
local lastAppliedOffset = -999.0

-- -----------------------------------------------------------------------------
-- Query IFP Installation Status (Cached after first evaluation)
-- -----------------------------------------------------------------------------
function IFP.IsInstalled()
    if isIFPInstalledCache ~= nil then
        return isIFPInstalledCache
    end
    local ifp = GetMod("ImmersiveFirstPerson") or GetMod("immersive_first_person")
    isIFPInstalledCache = (ifp ~= nil)
    return isIFPInstalledCache
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
-- Query IFP Height Adjustment Status
-- Checks if IFP itself is enabled AND if height adjustment is enabled
-- Throttled to 0.25s internally to avoid per-frame reflection/filesystem overhead
-- -----------------------------------------------------------------------------
function IFP.IsHeightAdjustmentEnabled(force)
    local ifp = GetMod("ImmersiveFirstPerson") or GetMod("immersive_first_person")
    if not ifp then
        return false
    end

    local now = os.clock and os.clock() or 0.0
    if force ~= true and cachedHeightAdjEnabled ~= nil and (now - lastHeightAdjCheck < 0.25) then
        return cachedHeightAdjEnabled
    end
    lastHeightAdjCheck = now

    -- If IFP is globally disabled, height adjustment is effectively disabled
    if not IFP.IsEnabled() then
        cachedHeightAdjEnabled = false
        return false
    end

    -- 1. Query dynamic in-memory API methods if provided by IFP
    if ifp.api then
        if type(ifp.api.IsHeightAdjustmentEnabled) == "function" then
            local ok, val = pcall(ifp.api.IsHeightAdjustmentEnabled)
            if ok and val ~= nil then
                cachedHeightAdjEnabled = (val == true)
                return cachedHeightAdjEnabled
            end
        end
        if type(ifp.api.IsHeightEnabled) == "function" then
            local ok, val = pcall(ifp.api.IsHeightEnabled)
            if ok and val ~= nil then
                cachedHeightAdjEnabled = (val == true)
                return cachedHeightAdjEnabled
            end
        end
        if type(ifp.api.GetHeightAdjustmentEnabled) == "function" then
            local ok, val = pcall(ifp.api.GetHeightAdjustmentEnabled)
            if ok and val ~= nil then
                cachedHeightAdjEnabled = (val == true)
                return cachedHeightAdjEnabled
            end
        end
        if type(ifp.api.GetHeightState) == "function" then
            local ok, state = pcall(ifp.api.GetHeightState)
            if ok and type(state) == "table" then
                if state.heightAdjustmentEnabled ~= nil then
                    cachedHeightAdjEnabled = (state.heightAdjustmentEnabled == true)
                    return cachedHeightAdjEnabled
                end
                if state.isHeightAdjustmentEnabled ~= nil then
                    cachedHeightAdjEnabled = (state.isHeightAdjustmentEnabled == true)
                    return cachedHeightAdjEnabled
                end
                if state.enabled ~= nil then
                    cachedHeightAdjEnabled = (state.enabled == true)
                    return cachedHeightAdjEnabled
                end
            end
        end
    end

    -- 2. Query in-memory configuration objects
    if type(ifp.config) == "table" and ifp.config.heightAdjustmentEnabled ~= nil then
        cachedHeightAdjEnabled = (ifp.config.heightAdjustmentEnabled == true)
        return cachedHeightAdjEnabled
    end
    if type(ifp.settings) == "table" and ifp.settings.heightAdjustmentEnabled ~= nil then
        cachedHeightAdjEnabled = (ifp.settings.heightAdjustmentEnabled == true)
        return cachedHeightAdjEnabled
    end
    if type(ifp.Config) == "table" and type(ifp.Config.inner) == "table" and ifp.Config.inner.heightAdjustmentEnabled ~= nil then
        cachedHeightAdjEnabled = (ifp.Config.inner.heightAdjustmentEnabled == true)
        return cachedHeightAdjEnabled
    end

    -- 3. File fallback: read IFP's config.json (throttled check)
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
        cachedHeightAdjEnabled = cachedConfigSetting
        return cachedHeightAdjEnabled
    end

    cachedHeightAdjEnabled = true
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
-- Reset Blend Cache (e.g., upon perspective switch or teleport)
-- -----------------------------------------------------------------------------
function IFP.ResetBlendCache()
    lastAppliedBlend = -999.0
    lastAppliedOffset = -999.0
end

-- -----------------------------------------------------------------------------
-- Apply Active Blend Value to Character Animation Component
-- Feeds anim input values continuously each frame to prevent engine animgraph resets
-- -----------------------------------------------------------------------------
function IFP.ApplyBlend(player, activeBlend, offsetMeters)
    if not player then
        return
    end
    if not AnimationControllerComponent or not AnimationControllerComponent.SetInputFloat then
        Logger.Error("IFP", "AnimationControllerComponent.SetInputFloat is not available")
        return
    end

    if not IFP.inputName and CName and CName.new then
        IFP.inputName = CName.new("ifp_height_blend")
    end
    if not IFP.footElevationName and CName and CName.new then
        IFP.footElevationName = CName.new("foot_elevation_offset")
    end

    if IFP.inputName and activeBlend ~= nil then
        local ok, err = pcall(AnimationControllerComponent.SetInputFloat, player, IFP.inputName, activeBlend)
        if not ok then
            Logger.Error("IFP", "Failed to set animgraph float '%s' to %.3f: %s", tostring(IFP.inputName), activeBlend, tostring(err))
        end
    end

    if IFP.footElevationName and offsetMeters ~= nil then
        local ok, err = pcall(AnimationControllerComponent.SetInputFloat, player, IFP.footElevationName, offsetMeters)
        if not ok then
            Logger.Error("IFP", "Failed to set animgraph float '%s' to %.3f: %s", tostring(IFP.footElevationName), offsetMeters, tostring(err))
        end
    end
end

-- -----------------------------------------------------------------------------
-- Render Footwear UI (Backward-compatible delegation to UIManager)
-- -----------------------------------------------------------------------------
function IFP.DrawUI(modState, player, sys, heightLimits, saveOverridesCallback)
    UIManager.DrawUI(modState, player, sys, heightLimits, saveOverridesCallback, IFP)
end

return IFP
