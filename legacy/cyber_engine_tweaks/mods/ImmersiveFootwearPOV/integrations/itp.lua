-- =============================================================================
-- Immersive Footwear POV - Immersive Third Person (ITP) Integration Adapter
-- Interfaces with ITP's official Developer API (api.lua / groundLevel)
-- Manages dynamic 3rd-person ground-level elevation leases for platform footwear
-- =============================================================================

local Logger = require("modules/logger")

local STATUS_DESCRIPTIONS = {
    [2] = "effective (active)",
    [1] = "shadowed (queued/lower priority)",
    [0] = "released",
    [-1] = "wall stands (blocked by vehicle, scene, or combat camera)",
    [-2] = "badArguments (invalid parameters)",
    [-3] = "switchedOff (API access is disabled in Immersive Third Person settings)",
    [-4] = "full (maximum add-on owners reached)",
    [-5] = "notReady / unknown (ITP session or state not initialized)",
    [-6] = "blocked (blocked by player permission settings in ITP)",
}

local ITP = {
    OWNER_NAME = "ImmersiveFootwearPOV",
    PRIORITY = 10,
    LEASE_TTL = 2.0,            -- Seconds lease remains valid before requiring heartbeat renewal
    HEARTBEAT_INTERVAL = 1.0,   -- Interval between renewal calls while stationary
    RETRY_INTERVAL = 3.0,       -- Backoff cooldown before retrying a rejected or failed lease request
    lastMm = 0,
    lastRequestedMm = 0,
    lastRenewTime = 0.0,
    lastRetryTime = 0.0,
    lastFailedStatus = nil,
    lastFailedMm = nil,
    isLeaseHeld = false,
    modState = nil,
}

local cachedMod = nil
local cachedHasApi = nil

-- -----------------------------------------------------------------------------
-- Query ITP Installation Status
-- -----------------------------------------------------------------------------
function ITP.GetModInstance()
    if cachedMod == nil then
        cachedMod = GetMod("immersive_third_person")
    end
    return cachedMod
end

function ITP.IsInstalled()
    return ITP.GetModInstance() ~= nil
end

-- -----------------------------------------------------------------------------
-- Query ITP Official API Capability
-- -----------------------------------------------------------------------------
function ITP.HasGroundLevelApi()
    if cachedHasApi ~= nil then
        return cachedHasApi
    end
    local mod = ITP.GetModInstance()
    if mod and type(mod.groundLevel) == "table" and type(mod.groundLevel.offset) == "function" then
        cachedHasApi = true
    else
        cachedHasApi = false
    end
    return cachedHasApi
end

-- -----------------------------------------------------------------------------
-- Query Whether Elevation Lease is Currently Active
-- -----------------------------------------------------------------------------
function ITP.IsLeaseHeld()
    return ITP.isLeaseHeld == true
end

-- -----------------------------------------------------------------------------
-- Translate Status Code to Human-Readable Description
-- -----------------------------------------------------------------------------
function ITP.GetStatusDescription(status)
    return STATUS_DESCRIPTIONS[status] or string.format("status code: %s", tostring(status))
end

-- -----------------------------------------------------------------------------
-- Set Dynamic Ground Offset (Platform Thickness in Millimeters)
-- -----------------------------------------------------------------------------
function ITP.SetGroundOffset(platformMeters, isSuppressed, currentTime)
    local mod = ITP.GetModInstance()
    if not mod or not ITP.HasGroundLevelApi() then
        return false, 0
    end

    local now = currentTime or os.clock()
    local wantMm = 0

    if not isSuppressed and platformMeters and platformMeters > 0.0005 then
        wantMm = math.floor((platformMeters * 1000.0) + 0.5)
        if wantMm < 0 then wantMm = 0 end
        if wantMm > 300 then wantMm = 300 end
    end

    if wantMm > 0 then
        -- Active elevation requested
        local mmChanged = (wantMm ~= ITP.lastRequestedMm)
        local needsHeartbeat = ITP.isLeaseHeld and ((now - ITP.lastRenewTime) >= ITP.HEARTBEAT_INTERVAL)
        local canRetry = (not ITP.isLeaseHeld) and ((now - ITP.lastRetryTime) >= ITP.RETRY_INTERVAL)

        -- Only attempt API lease offset call if:
        -- 1. Target millimeter height changed, OR
        -- 2. Lease is currently held and heartbeat renewal interval elapsed, OR
        -- 3. Lease is not held and retry backoff cooldown elapsed
        if mmChanged or needsHeartbeat or canRetry then
            ITP.lastRequestedMm = wantMm
            local ok, status = pcall(mod.groundLevel.offset, ITP.OWNER_NAME, ITP.PRIORITY, wantMm, ITP.LEASE_TTL)
            if ok and (status == 2 or status == 1 or status == 0) then
                if not ITP.isLeaseHeld or mmChanged then
                    Logger.Log("ITP", "Acquired ground elevation lease: +%d mm (priority %d, status=%s: %s)",
                        wantMm, ITP.PRIORITY, tostring(status), STATUS_DESCRIPTIONS[status] or "ok")
                end
                ITP.lastMm = wantMm
                ITP.lastRenewTime = now
                ITP.isLeaseHeld = true
                ITP.lastFailedStatus = nil
                ITP.lastFailedMm = nil
                return true, wantMm
            else
                ITP.isLeaseHeld = false
                ITP.lastRetryTime = now

                -- Deduplicate warning logs: only log once per status/height change
                if not ok then
                    Logger.Error("ITP", "Failed to invoke mod.groundLevel.offset(+%d mm): %s", wantMm, tostring(status))
                elseif status ~= ITP.lastFailedStatus or wantMm ~= ITP.lastFailedMm then
                    local desc = ITP.GetStatusDescription(status)
                    local refusal = nil
                    if mod.meta and type(mod.meta.lastRefusal) == "function" then
                        local rOk, rText = pcall(mod.meta.lastRefusal, ITP.OWNER_NAME)
                        if rOk and type(rText) == "string" and #rText > 0 then
                            refusal = rText
                        end
                    end

                    if refusal and #refusal > 0 then
                        Logger.Warn("ITP", "mod.groundLevel.offset rejected lease for +%d mm: %s ('%s'). Falling back to animgraph footwear elevation.", wantMm, desc, refusal)
                    else
                        Logger.Warn("ITP", "mod.groundLevel.offset rejected lease for +%d mm: %s. Falling back to animgraph footwear elevation.", wantMm, desc)
                    end

                    ITP.lastFailedStatus = status
                    ITP.lastFailedMm = wantMm
                end
            end
        end
        return ITP.isLeaseHeld, (ITP.isLeaseHeld and ITP.lastMm or 0)
    else
        -- Zero elevation or suppressed: release lease if held
        if ITP.isLeaseHeld or ITP.lastMm > 0 then
            ITP.ReleaseGroundOffset()
        end
        ITP.lastRequestedMm = 0
        ITP.lastFailedStatus = nil
        ITP.lastFailedMm = nil
        return false, 0
    end
end

-- -----------------------------------------------------------------------------
-- Release Ground Offset Lease Gracefully
-- -----------------------------------------------------------------------------
function ITP.ReleaseGroundOffset()
    local mod = ITP.GetModInstance()
    if mod and ITP.HasGroundLevelApi() and (ITP.isLeaseHeld or ITP.lastMm > 0) then
        local ok, err = pcall(mod.groundLevel.release, ITP.OWNER_NAME)
        if not ok then
            Logger.Error("ITP", "Failed to release ground offset lease: %s", tostring(err))
        else
            Logger.Log("ITP", "Released ground elevation lease (was +%d mm)", ITP.lastMm)
        end
    end
    ITP.isLeaseHeld = false
    ITP.lastMm = 0
    ITP.lastRequestedMm = 0
    ITP.lastRenewTime = 0.0
end

-- -----------------------------------------------------------------------------
-- Query Live Telemetry from ITP
-- -----------------------------------------------------------------------------
function ITP.GetGroundTelemetry()
    local mod = ITP.GetModInstance()
    if not mod or not ITP.HasGroundLevelApi() then
        return nil
    end

    local ok, info = pcall(mod.groundLevel.get)
    if not ok then
        Logger.Warn("ITP", "Failed to query mod.groundLevel.get: %s", tostring(info))
        return nil
    end
    if type(info) == "table" then
        return {
            enabled = info.enabled == true,
            playerMm = tonumber(info.playerMm) or 0,
            mmInForce = tonumber(info.mmInForce) or 0,
            inForce = info.inForce == true,
            owner = tostring(info.owner or ""),
            isOurLeaseActive = (info.owner == ITP.OWNER_NAME) or ITP.isLeaseHeld,
        }
    end
    return nil
end

return ITP
