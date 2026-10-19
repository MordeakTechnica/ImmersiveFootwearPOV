-- =============================================================================
-- Immersive Footwear POV - CET Configuration & JSON Persistence Fallback
-- Single Responsibility: Safe filesystem read/write of config and custom shoe
-- overrides in CET's directory when native RedFunctions ModStorage is missing.
-- =============================================================================

local Config = {
    SETTINGS_FILE = "config.json",
    OVERRIDES_FILE = "user_shoe_overrides.json",
    PRESETS_FILE = "presets.json",
}

--- Read and parse JSON content from a file path safely
---@param filePath string
---@return table|nil
local function ReadJSON(filePath)
    local file = io.open(filePath, "r")
    if not file then
        file = io.open("./" .. filePath, "r")
    end
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
---@param data table
---@return boolean
local function WriteJSON(filePath, data)
    local success, encoded = pcall(function() return json.encode(data) end)
    if not success or not encoded then return false end
    local file = io.open(filePath, "w")
    if not file then
        file = io.open("./" .. filePath, "w")
    end
    if not file then return false end
    file:write(encoded)
    file:close()
    return true
end

--- Load mod configuration table from config.json
---@return table
function Config.LoadSettings()
    local data = ReadJSON(Config.SETTINGS_FILE)
    if type(data) == "table" then
        return data
    end
    return {}
end

--- Save mod configuration table to config.json
---@param settings table
---@return boolean
function Config.SaveSettings(settings)
    return WriteJSON(Config.SETTINGS_FILE, settings or {})
end

--- Load user shoe overrides map from user_shoe_overrides.json
---@return table<string, table>
function Config.LoadOverrides()
    local data = ReadJSON(Config.OVERRIDES_FILE)
    if type(data) == "table" then
        return data
    end
    return {}
end

--- Save user shoe overrides map to user_shoe_overrides.json
---@param overrides table<string, table>
---@return boolean
function Config.SaveOverrides(overrides)
    return WriteJSON(Config.OVERRIDES_FILE, overrides or {})
end

return Config
