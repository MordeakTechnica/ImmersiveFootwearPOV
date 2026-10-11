-- =============================================================================
-- Immersive Footwear POV - Console Command & CLI Manager (Command Pattern)
-- Handles CET developer console inputs, shortcuts, diagnostics, and height overrides
-- =============================================================================

local Logger = require("modules/logger")
local Diagnostics = require("modules/diagnostics")

local ConsoleManager = {}

--- Set debug logging mode
---@param mod table Mod context
---@param enabled boolean
---@param saveCallback function
---@return boolean
function ConsoleManager.SetDebug(mod, enabled, saveCallback)
    mod.debugLogs = Logger.SetDebug(enabled, function(newVal)
        mod.debugLogs = newVal
        if saveCallback then saveCallback() end
    end)
    return mod.debugLogs
end

--- Toggle debug logging mode
---@param mod table Mod context
---@param saveCallback function
---@return boolean
function ConsoleManager.ToggleDebug(mod, saveCallback)
    return ConsoleManager.SetDebug(mod, not mod.debugLogs, saveCallback)
end

--- Output system and state diagnostics to console
---@param sys table Scriptable system reference
---@param mod table Mod context
---@param ifpIntegration table IFP integration service
---@param transitionMgr table Transition manager
function ConsoleManager.DumpState(sys, mod, ifpIntegration, transitionMgr)
    Diagnostics.Dump(sys, mod, ifpIntegration, transitionMgr, mod.currentShoeState)
end

--- Force a static stance elevation (meters or cm) for debugging / photoshoot poses
---@param mod table Mod context
---@param ifpIntegration table IFP integration service
---@param cm number|string Stance in cm, or "clear" / "reset"
---@param extra any Optional extra argument when invoked as mod:ForceStance(cm)
---@return string
function ConsoleManager.ForceStance(mod, ifpIntegration, cm, extra)
    -- Support both mod.ForceStance(val) and mod:ForceStance(val)
    if type(cm) == "table" and cm == mod then
        cm = extra
    end

    if cm == nil or tostring(cm):lower() == "clear" or tostring(cm):lower() == "reset" then
        mod.forcedBlend = nil
        local player = Game.GetPlayer()
        if player and ifpIntegration and ifpIntegration.ApplyBlend then
            ifpIntegration.ApplyBlend(player, 0.50, 0.0)
        end
        print("[ImmersiveFootwearPOV] Stance override CLEARED. Dynamic footwear logic resumed.")
        return "Cleared"
    else
        local cmNum = tonumber(cm) or 0.0
        local meters = cmNum / 100.0
        local blend = math.max(0.0, math.min(1.0, (meters + 0.50) / 1.00))
        mod.forcedBlend = blend
        local player = Game.GetPlayer()
        if player and ifpIntegration and ifpIntegration.ApplyBlend then
            ifpIntegration.ApplyBlend(player, blend, meters)
        end
        local msg = string.format("FORCED stance to %+.1f cm (Offset: %.3f m | Blend: %.3f)", cmNum, meters, blend)
        print(string.format("[ImmersiveFootwearPOV] %s", msg))
        Logger.LogFile("%s", msg)
        return msg
    end
end

--- Set custom footwear heights via console command
---@param mod table Mod context
---@param sys table Scriptable system reference
---@param player table Player entity
---@param heightLimits table Height configuration boundaries
---@param heelCm number|string
---@param platformCm number|string
---@param saveCallback function
---@return string
function ConsoleManager.SetCustomHeight(mod, sys, player, heightLimits, heelCm, platformCm, saveCallback)
    if not player then
        print("[ImmersiveFootwearPOV] Error: Player not found.")
        return "Error: Player not found"
    end
    if not sys then
        print("[ImmersiveFootwearPOV] Error: System not found.")
        return "Error: System not found"
    end

    local shoeState = mod.currentShoeState
    if not shoeState or not shoeState.key or #shoeState.key == 0 then
        print("[ImmersiveFootwearPOV] Error: No shoe equipped to override.")
        return "Error: No shoe equipped"
    end

    local maxHeel = (heightLimits and heightLimits.MAX_HEEL_CM) or 40.0
    local maxPlat = (heightLimits and heightLimits.MAX_PLATFORM_CM) or 30.0

    local h = tonumber(heelCm) or 0.0
    local p = tonumber(platformCm) or 0.0

    if h < 0.0 then h = 0.0 elseif h > maxHeel then h = maxHeel end
    if p < 0.0 then p = 0.0 elseif p > maxPlat then p = maxPlat end

    shoeState.heelCm = h
    shoeState.platformCm = p

    if not mod.overrides[shoeState.key] then
        mod.overrides[shoeState.key] = {}
    end
    mod.overrides[shoeState.key].heel = h
    mod.overrides[shoeState.key].platform = p

    if mod.userOverrides then
        if not mod.userOverrides[shoeState.key] then
            mod.userOverrides[shoeState.key] = {}
        end
        mod.userOverrides[shoeState.key].heel = h
        mod.userOverrides[shoeState.key].platform = p
    end

    if saveCallback then saveCallback() end
    if sys and sys.RegisterCustomOverride then
        sys:RegisterCustomOverride(shoeState.key, h / 100.0, p / 100.0)
    end
    sys:SetCustomHeightOverride(player, h / 100.0, p / 100.0, true)

    local msg = string.format("Set custom height for '%s': Heel = %.1f cm (max %.1f cm), Platform = %.1f cm (max %.1f cm)",
        shoeState.displayName or shoeState.key, h, maxHeel, p, maxPlat)
    print(string.format("[ImmersiveFootwearPOV] %s", msg))
    return msg
end

--- Register shortcut aliases in CET console global environment (_G)
---@param mod table Mod object providing methods
function ConsoleManager.RegisterShortcuts(mod)
    local shortcuts = {
        ToggleIFPDebug = function() return mod.ToggleDebug() end,
        IFPDebug = function(enabled) return mod.SetDebug(enabled) end,
        IFPStatus = function() return mod.DumpState() end,
        ForceStance = function(cm, extra) return mod.ForceStance(cm, extra) end,
        IFPForceStance = function(cm, extra) return mod.ForceStance(cm, extra) end,
        SetCustomHeight = function(h, p) return mod.SetCustomHeight(h, p) end,
        SetFootwearHeight = function(h, p) return mod.SetCustomHeight(h, p) end,
    }
    for name, fn in pairs(shortcuts) do
        if _G then
            rawset(_G, name, fn)
        end
    end
end

return ConsoleManager
