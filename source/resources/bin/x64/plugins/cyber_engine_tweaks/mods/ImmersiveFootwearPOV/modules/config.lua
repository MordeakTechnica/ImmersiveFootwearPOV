-- =============================================================================
-- Immersive Footwear POV - Configuration & Persistence Module
-- Manages persistent JSON storage for per-shoe height overrides & user settings
-- =============================================================================

local Config = {
    FILE_NAME = "user_shoe_overrides.json",
}

function Config.Load(filePath)
    local targetPath = filePath or Config.FILE_NAME
    local overrides = {}
    local settings = {
        autoElevatePM = true,
        debugLogs = false,
        enableHipSway = true,
        hipSwayIntensity = 1.0,
    }

    local file = io.open(targetPath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        if content and #content > 0 then
            local success, data = pcall(function() return json.decode(content) end)
            if success and type(data) == "table" then
                if data["__settings"] then
                    settings.autoElevatePM = (data["__settings"].autoElevatePM ~= false)
                    settings.debugLogs = (data["__settings"].debugLogs == true)
                    settings.enableHipSway = (data["__settings"].enableHipSway ~= false)
                    settings.hipSwayIntensity = tonumber(data["__settings"].hipSwayIntensity) or 1.0
                end
                for k, v in pairs(data) do
                    if k ~= "__settings" then
                        overrides[k] = v
                    end
                end
                local count = 0
                for _ in pairs(overrides) do count = count + 1 end
                print(string.format("[ImmersiveFootwearPOV] Loaded %d custom shoe override(s) from %s (Debug Logs: %s, Hip Sway: %s).",
                    count, targetPath, settings.debugLogs and "ON" or "OFF", settings.enableHipSway and "ON" or "OFF"))
                return overrides, settings
            end
        end
    end

    return overrides, settings
end

function Config.Save(filePath, overrides, settings)
    local targetPath = filePath or Config.FILE_NAME
    local file = io.open(targetPath, "w")
    if not file then return false end

    local payload = {}
    if overrides and type(overrides) == "table" then
        for k, v in pairs(overrides) do
            if k ~= "__settings" then
                payload[k] = v
            end
        end
    end

    payload["__settings"] = {
        autoElevatePM = settings and (settings.autoElevatePM ~= false) or true,
        debugLogs = settings and (settings.debugLogs == true) or false,
        enableHipSway = settings and (settings.enableHipSway ~= false) or true,
        hipSwayIntensity = settings and (tonumber(settings.hipSwayIntensity) or 1.0) or 1.0,
    }

    local success, encoded = pcall(function() return json.encode(payload) end)
    if success and encoded then
        file:write(encoded)
    end
    file:close()
    return success == true
end

return Config
