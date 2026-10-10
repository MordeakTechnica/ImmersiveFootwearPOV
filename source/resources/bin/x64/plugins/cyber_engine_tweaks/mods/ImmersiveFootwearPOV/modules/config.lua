-- =============================================================================
-- Immersive Footwear POV - Configuration & Persistence Module
-- Manages persistent JSON storage for:
--   1. General mod settings (config.json)
--   2. User shoe height overrides (user_shoe_overrides.json)
--   3. Optional community/modder preset packs (shoe_presets.json / presets.json)
-- =============================================================================

local Config = {
    SETTINGS_FILE = "config.json",
    OVERRIDES_FILE = "user_shoe_overrides.json",
    PRESET_FILES = { "shoe_presets.json", "presets.json" },
    -- Maintained for backward compatibility
    FILE_NAME = "user_shoe_overrides.json",
}

local DEFAULT_SETTINGS = {
    autoElevatePM = true,
    debugLogs = false,
    enableHipSway = true,
    swayLow = 1.0,
    swayMid = 1.0,
    swayHigh = 1.0,
}

--- Read and parse JSON content from a file path safely
---@param filePath string
---@return table|nil
local function ReadJSONFile(filePath)
    local file = io.open(filePath, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    if not content or #content == 0 then return nil end
    local success, data = pcall(function() return json.decode(content) end)
    if success and type(data) == "table" then
        return data
    end
    return nil
end

--- Encode and write a table to a JSON file path safely
---@param filePath string
---@return boolean
local function WriteJSONFile(filePath, data)
    local success, encoded = pcall(function() return json.encode(data) end)
    if not success or not encoded then return false end
    local file = io.open(filePath, "w")
    if not file then return false end
    file:write(encoded)
    file:close()
    return true
end

--- Return a clone of the default mod settings
---@return table
function Config.GetDefaultSettings()
    local copy = {}
    for k, v in pairs(DEFAULT_SETTINGS) do
        copy[k] = v
    end
    return copy
end

--- Check whether a file exists at the given path
---@param filePath string
---@return boolean
function Config.FileExists(filePath)
    local file = io.open(filePath, "r")
    if file then
        file:close()
        return true
    end
    return false
end

--- Migrate legacy settings from user_shoe_overrides.json to config.json
--- Extracts __settings into config.json and removes __settings from user_shoe_overrides.json.
--- If no legacy file exists, initializes default config.json.
---@param legacyOverridesPath string|nil
---@param targetSettingsPath string|nil
---@return boolean success
function Config.MigrateLegacySettings(legacyOverridesPath, targetSettingsPath)
    local settingsPath = targetSettingsPath or Config.SETTINGS_FILE
    local overridesPath = legacyOverridesPath or Config.OVERRIDES_FILE

    local legacyData = ReadJSONFile(overridesPath)
    if legacyData and legacyData["__settings"] then
        local leg = legacyData["__settings"]
        local settings = Config.GetDefaultSettings()
        settings.autoElevatePM = (leg.autoElevatePM ~= false)
        settings.debugLogs = (leg.debugLogs == true)
        settings.enableHipSway = (leg.enableHipSway ~= false)
        local legacyIntensity = tonumber(leg.hipSwayIntensity)
        settings.swayLow = tonumber(leg.swayLow) or legacyIntensity or 1.0
        settings.swayMid = tonumber(leg.swayMid) or legacyIntensity or 1.0
        settings.swayHigh = tonumber(leg.swayHigh) or legacyIntensity or 1.0

        -- 1. Save extracted settings exclusively to config.json
        Config.SaveSettings(settings, settingsPath)

        -- 2. Clean user_shoe_overrides.json by removing __settings
        legacyData["__settings"] = nil
        WriteJSONFile(overridesPath, legacyData)

        print(string.format("[ImmersiveFootwearPOV] Migration: Successfully migrated settings from %s to %s and removed __settings from overrides.",
            overridesPath, settingsPath))
        return true
    else
        -- If config.json does not exist, initialize it with default settings
        if not Config.FileExists(settingsPath) then
            local defaults = Config.GetDefaultSettings()
            Config.SaveSettings(defaults, settingsPath)
            print(string.format("[ImmersiveFootwearPOV] Migration: Initialized %s with default settings.", settingsPath))
            return true
        end
    end
    return false
end

--- Load general mod settings from config.json (with migration fallback from legacy __settings)
---@param settingsPath string|nil Path to config.json
---@param legacyOverridesPath string|nil Path to legacy user_shoe_overrides.json
---@return table
function Config.LoadSettings(settingsPath, legacyOverridesPath)
    local targetPath = settingsPath or Config.SETTINGS_FILE
    local settings = Config.GetDefaultSettings()

    -- 1. Primary source: dedicated config.json
    local data = ReadJSONFile(targetPath)
    if data then
        settings.autoElevatePM = (data.autoElevatePM ~= false)
        settings.debugLogs = (data.debugLogs == true)
        settings.enableHipSway = (data.enableHipSway ~= false)
        local legacyIntensity = tonumber(data.hipSwayIntensity)
        settings.swayLow = tonumber(data.swayLow) or legacyIntensity or 1.0
        settings.swayMid = tonumber(data.swayMid) or legacyIntensity or 1.0
        settings.swayHigh = tonumber(data.swayHigh) or legacyIntensity or 1.0
        return settings
    end

    -- 2. Migration fallback: check if legacy overrides file has __settings
    local legacyData = ReadJSONFile(legacyOverridesPath or Config.OVERRIDES_FILE)
    if legacyData and legacyData["__settings"] then
        local leg = legacyData["__settings"]
        settings.autoElevatePM = (leg.autoElevatePM ~= false)
        settings.debugLogs = (leg.debugLogs == true)
        settings.enableHipSway = (leg.enableHipSway ~= false)
        local legacyIntensity = tonumber(leg.hipSwayIntensity)
        settings.swayLow = tonumber(leg.swayLow) or legacyIntensity or 1.0
        settings.swayMid = tonumber(leg.swayMid) or legacyIntensity or 1.0
        settings.swayHigh = tonumber(leg.swayHigh) or legacyIntensity or 1.0

        -- Automatically migrate and save into dedicated config.json
        Config.SaveSettings(settings, targetPath)
        print(string.format("[ImmersiveFootwearPOV] Migrated legacy mod settings from %s to %s.",
            legacyOverridesPath or Config.OVERRIDES_FILE, targetPath))
    end

    return settings
end

--- Save general mod settings exclusively to config.json
---@param settings table
---@param settingsPath string|nil
---@return boolean
function Config.SaveSettings(settings, settingsPath)
    local targetPath = settingsPath or Config.SETTINGS_FILE
    local payload = {
        autoElevatePM = settings and (settings.autoElevatePM ~= false) or true,
        debugLogs = settings and (settings.debugLogs == true) or false,
        enableHipSway = settings and (settings.enableHipSway ~= false) or true,
        swayLow = settings and (tonumber(settings.swayLow) or 1.0) or 1.0,
        swayMid = settings and (tonumber(settings.swayMid) or 1.0) or 1.0,
        swayHigh = settings and (tonumber(settings.swayHigh) or 1.0) or 1.0,
    }
    return WriteJSONFile(targetPath, payload)
end

--- Load optional shoe presets from a preset pack (shoe_presets.json or presets.json)
--- Presets are read-only distributions and never modified by the game.
---@param presetPath string|nil
---@return table presets, string|nil sourceFileName
function Config.LoadPresets(presetPath)
    local candidates = presetPath and { presetPath } or Config.PRESET_FILES
    for _, path in ipairs(candidates) do
        local data = ReadJSONFile(path)
        if data then
            local presets = {}
            for k, v in pairs(data) do
                if k ~= "__settings" and type(v) == "table" then
                    presets[k] = {
                        heel = tonumber(v.heel) or 0.0,
                        platform = tonumber(v.platform) or 0.0,
                    }
                end
            end
            return presets, path
        end
    end
    return {}, nil
end

--- Load user-specific shoe height overrides from user_shoe_overrides.json
--- General mod settings (__settings) are intentionally excluded.
---@param filePath string|nil
---@return table userOverrides
function Config.LoadOverrides(filePath)
    local targetPath = filePath or Config.OVERRIDES_FILE
    local overrides = {}
    local data = ReadJSONFile(targetPath)
    if data then
        for k, v in pairs(data) do
            if k ~= "__settings" and type(v) == "table" then
                overrides[k] = {
                    heel = tonumber(v.heel) or 0.0,
                    platform = tonumber(v.platform) or 0.0,
                }
            end
        end
    end
    return overrides
end

--- Save user-specific shoe height overrides to user_shoe_overrides.json
--- Excludes general mod settings entirely.
---@param overrides table
---@param filePath string|nil
---@return boolean
function Config.SaveOverrides(overrides, filePath)
    local targetPath = filePath or Config.OVERRIDES_FILE
    local payload = {}
    if overrides and type(overrides) == "table" then
        for k, v in pairs(overrides) do
            if k ~= "__settings" and type(v) == "table" then
                payload[k] = {
                    heel = tonumber(v.heel) or 0.0,
                    platform = tonumber(v.platform) or 0.0,
                }
            end
        end
    end
    return WriteJSONFile(targetPath, payload)
end

--- Combined loader: loads settings, optional presets, and user overrides
--- Merges presets with user overrides (user overrides take precedence).
---@param overridesPath string|nil
---@param settingsPath string|nil
---@param presetPath string|nil
---@return table effectiveOverrides, table settings, table presets, table userOverrides
function Config.Load(overridesPath, settingsPath, presetPath)
    local settings = Config.LoadSettings(settingsPath, overridesPath)
    local presets, presetSource = Config.LoadPresets(presetPath)
    local userOverrides = Config.LoadOverrides(overridesPath)

    local effectiveOverrides = {}
    local presetCount = 0
    for k, v in pairs(presets) do
        effectiveOverrides[k] = { heel = v.heel, platform = v.platform }
        presetCount = presetCount + 1
    end

    local userCount = 0
    for k, v in pairs(userOverrides) do
        effectiveOverrides[k] = { heel = v.heel, platform = v.platform }
        userCount = userCount + 1
    end

    if presetCount > 0 then
        print(string.format("[ImmersiveFootwearPOV] Loaded %d shoe preset(s) from %s.",
            presetCount, presetSource or "presets file"))
    end
    print(string.format("[ImmersiveFootwearPOV] Loaded %d custom shoe override(s) from %s (Debug Logs: %s, Hip Sway: %s).",
        userCount, overridesPath or Config.OVERRIDES_FILE,
        settings.debugLogs and "ON" or "OFF", settings.enableHipSway and "ON" or "OFF"))

    return effectiveOverrides, settings, presets, userOverrides
end

--- Backward-compatible save method
--- Saves overrides to overrides file (without __settings) and settings to config.json
---@param filePath string|nil
---@param overrides table|nil
---@param settings table|nil
---@return boolean
function Config.Save(filePath, overrides, settings)
    local overridesOk = true
    if overrides then
        overridesOk = Config.SaveOverrides(overrides, filePath or Config.OVERRIDES_FILE)
    end
    local settingsOk = true
    if settings then
        settingsOk = Config.SaveSettings(settings)
    end
    return overridesOk and settingsOk
end

return Config
