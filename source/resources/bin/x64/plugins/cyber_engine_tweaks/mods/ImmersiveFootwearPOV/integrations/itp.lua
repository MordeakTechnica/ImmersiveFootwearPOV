-- =============================================================================
-- Immersive Footwear POV - Immersive Third Person (ITP) Integration Adapter
-- Interfaces with ITP's official Developer API (api.lua / groundLevel)
-- Manages dynamic 3rd-person ground-level elevation leases for platform footwear
-- =============================================================================

local ITP = {
    OWNER_NAME = "ImmersiveFootwearPOV",
    PRIORITY = 10,
    LEASE_TTL = 2.0,            -- Seconds lease remains valid before requiring heartbeat renewal
    HEARTBEAT_INTERVAL = 1.0,   -- Interval between renewal calls while stationary
    lastMm = 0,
    lastRenewTime = 0.0,
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
        local mmChanged = (wantMm ~= ITP.lastMm)
        local needsHeartbeat = (now - ITP.lastRenewTime) >= ITP.HEARTBEAT_INTERVAL

        if mmChanged or needsHeartbeat or not ITP.isLeaseHeld then
            local ok, status = pcall(mod.groundLevel.offset, ITP.OWNER_NAME, ITP.PRIORITY, wantMm, ITP.LEASE_TTL)
            if ok and (status == 2 or status == 1 or status == 0) then
                ITP.lastMm = wantMm
                ITP.lastRenewTime = now
                ITP.isLeaseHeld = true
                return true, wantMm
            end
        end
        return ITP.isLeaseHeld, ITP.lastMm
    else
        -- Zero elevation or suppressed: release lease if held
        if ITP.isLeaseHeld or ITP.lastMm > 0 then
            ITP.ReleaseGroundOffset()
        end
        return false, 0
    end
end

-- -----------------------------------------------------------------------------
-- Release Ground Offset Lease Gracefully
-- -----------------------------------------------------------------------------
function ITP.ReleaseGroundOffset()
    local mod = ITP.GetModInstance()
    if mod and ITP.HasGroundLevelApi() and (ITP.isLeaseHeld or ITP.lastMm > 0) then
        pcall(mod.groundLevel.release, ITP.OWNER_NAME)
    end
    ITP.isLeaseHeld = false
    ITP.lastMm = 0
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
    if ok and type(info) == "table" then
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
