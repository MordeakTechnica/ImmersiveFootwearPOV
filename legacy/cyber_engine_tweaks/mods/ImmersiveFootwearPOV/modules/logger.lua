-- =============================================================================
-- Immersive Footwear POV - Logging Module
-- Centralized logging manager: routes CET telemetry and logs to RedLogger
-- Writes to: r6\logs\mods\ImmersiveFootwearPOV__<timestamp>.log
-- =============================================================================

local Logger = {
    debugLogs = false,
}

local function ForwardToRedLogger(level, tag, msg)
    pcall(function()
        local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
        if sys then
            if not tag or tag == "" then
                if sys.GetActiveModTag then
                    tag = sys:GetActiveModTag(Game.GetPlayer())
                end
            end
            if sys.LogLevelFromCET then
                sys:LogLevelFromCET(level or "INFO", tag or "PM", msg)
            elseif sys.LogFromCET then
                sys:LogFromCET(tag or "PM", msg)
            end
        end
    end)
end

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
    local msg = string.format(fmt, ...)
    if Logger.debugLogs then
        print(string.format("[ImmersiveFootwearPOV][%s] %s", tag or "CORE", msg))
        ForwardToRedLogger("DEBUG", tag, msg)
    end
end

function Logger.LogFPP(isTFP, fmt, ...)
    local tag = isTFP and "TFP" or "IFP"
    local msg = string.format(fmt, ...)
    if Logger.debugLogs then
        print(string.format("[ImmersiveFootwearPOV][%s] %s", tag, msg))
        ForwardToRedLogger("DEBUG", tag, msg)
    end
end

function Logger.Info(tag, fmt, ...)
    local msg
    if fmt == nil then
        msg = tostring(tag)
        tag = "INFO"
    else
        msg = string.format(fmt, ...)
    end
    print(string.format("[ImmersiveFootwearPOV][%s] %s", tag or "INFO", msg))
    ForwardToRedLogger("INFO", tag or "INFO", msg)
end

function Logger.Warn(tag, fmt, ...)
    local msg
    if fmt == nil then
        msg = tostring(tag)
        tag = "WARN"
    else
        msg = string.format(fmt, ...)
    end
    print(string.format("[ImmersiveFootwearPOV][%s][WARN] %s", tag or "WARN", msg))
    ForwardToRedLogger("WARN", tag or "WARN", msg)
end

function Logger.Error(tag, fmt, ...)
    local msg
    if fmt == nil then
        msg = tostring(tag)
        tag = "ERROR"
    else
        msg = string.format(fmt, ...)
    end
    print(string.format("[ImmersiveFootwearPOV][%s][ERROR] %s", tag or "ERROR", msg))
    ForwardToRedLogger("ERROR", tag or "ERROR", msg)
end

function Logger.LogFile(fmt, ...)
    local msg = string.format(fmt, ...)
    print(string.format("[ImmersiveFootwearPOV] %s", msg))
    ForwardToRedLogger("INFO", "", msg)
end

return Logger
