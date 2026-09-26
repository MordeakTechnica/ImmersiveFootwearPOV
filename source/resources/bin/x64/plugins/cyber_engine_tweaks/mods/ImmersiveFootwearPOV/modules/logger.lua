-- =============================================================================
-- Immersive Footwear POV - Logging Module
-- Manages debug logging, runtime filtering, and CET console API toggles
-- =============================================================================

local Logger = {
    debugLogs = false,
}

function Logger.Init(enabled)
    Logger.debugLogs = (enabled == true)
end

function Logger.IsDebug()
    return Logger.debugLogs
end

function Logger.SetDebug(enabled, onSaveCallback)
    if enabled == nil then
        Logger.debugLogs = not Logger.debugLogs
    else
        Logger.debugLogs = (enabled == true)
    end

    if onSaveCallback and type(onSaveCallback) == "function" then
        onSaveCallback(Logger.debugLogs)
    end

    local player = Game.GetPlayer()
    if player then
        local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
        if sys and sys.SetDebugLogging then
            pcall(function() sys:SetDebugLogging(Logger.debugLogs) end)
        end
    end

    print(string.format("[ImmersiveFootwearPOV] Debug logging is now: %s", Logger.debugLogs and "ENABLED" or "DISABLED"))
    return Logger.debugLogs
end

function Logger.ToggleDebug(onSaveCallback)
    return Logger.SetDebug(not Logger.debugLogs, onSaveCallback)
end

function Logger.Log(tag, fmt, ...)
    if Logger.debugLogs then
        print(string.format("[ImmersiveFootwearPOV][%s] " .. fmt, tag or "CORE", ...))
    end
end

function Logger.LogFPP(isTFP, fmt, ...)
    if Logger.debugLogs then
        local tag = isTFP and "TFP" or "FPP"
        print(string.format("[ImmersiveFootwearPOV][%s] " .. fmt, tag, ...))
    end
end

function Logger.LogFile(fmt, ...)
    local msg = string.format(fmt, ...)
    if Logger.debugLogs then
        print(string.format("[ImmersiveFootwearPOV] %s", msg))
    end
    pcall(function()
        local f = io.open("ImmersiveFootwearPOV.log", "a")
        if f then
            f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg .. "\n")
            f:close()
        end
    end)
end

return Logger
