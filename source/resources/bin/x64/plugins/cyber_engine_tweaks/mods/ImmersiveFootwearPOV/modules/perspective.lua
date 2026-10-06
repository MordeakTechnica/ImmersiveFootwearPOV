-- =============================================================================
-- Immersive Footwear POV - Perspective & Camera Detection Service
-- Detects active camera perspective (FPP vs TPP) via REDengine CameraSystem transforms
-- Optimized for high-frequency execution: caches transforms, CNames, and components
-- =============================================================================

local Perspective = {}

-- Cached static data
local isITPInstalledCache = nil
local fppCamName = CName.new("camera")
local tppCamName = CName.new("tppCamera")
local reusableTransform = nil
local cachedPlayerID = nil
local cachedFPPCam = nil
local cachedTPPCam = nil

--- Query whether Immersive Third Person (ITP) mod is installed (cached after first evaluation)
---@return boolean
function Perspective.IsITPInstalled()
    if isITPInstalledCache ~= nil then
        return isITPInstalledCache
    end

    if GetMod then
        local itpMod = GetMod("immersive_third_person") or GetMod("ImmersiveThirdPerson") or GetMod("ITP")
        if itpMod ~= nil then
            isITPInstalledCache = true
            return true
        end
    end

    local installed = false
    pcall(function()
        local bridge = Game.GetScriptableSystemsContainer():Get("TPPCameraVisibleRenderBridge")
        if bridge ~= nil then installed = true end
    end)
    if not installed then
        local player = Game.GetPlayer()
        if player and player:FindComponentByName(tppCamName) then
            installed = true
        end
    end

    isITPInstalledCache = installed
    return installed
end

--- Get world position of a camera component
---@param camera table
---@return table|nil
function Perspective.GetCameraWorldPosition(camera)
    if not camera or not camera.GetLocalToWorld then return nil end
    local okTransform, transform = pcall(function() return camera:GetLocalToWorld() end)
    if not okTransform or not transform or not transform.GetTranslation then return nil end
    local okTranslation, translation = pcall(function() return transform:GetTranslation() end)
    if okTranslation and translation and translation.x ~= nil then
        return translation
    end
    return nil
end

--- Determine whether Third Person Perspective (TPP) camera is actively rendering
--- Optimized: early exits when ITP is absent, reuses single Transform instance, caches camera components
---@param player table
---@return boolean
function Perspective.IsTPPActive(player)
    if not player then return false end

    -- Early exit: if ITP is absent, third person camera cannot be active in normal gameplay
    if not Perspective.IsITPInstalled() then
        return false
    end

    -- Invalidate or update cached camera components if player changed
    local playerID = player:GetEntityID()
    if cachedPlayerID == nil or playerID.hash ~= cachedPlayerID.hash then
        cachedPlayerID = playerID
        cachedFPPCam = player:FindComponentByName(fppCamName)
        cachedTPPCam = player:FindComponentByName(tppCamName)
    else
        if not cachedFPPCam then cachedFPPCam = player:FindComponentByName(fppCamName) end
        if not cachedTPPCam then cachedTPPCam = player:FindComponentByName(tppCamName) end
    end

    -- Primary: REDengine CameraSystem distance to active camera
    local cameraSystem = Game.GetCameraSystem and Game.GetCameraSystem()
    if cameraSystem and cameraSystem.GetActiveCameraWorldTransform then
        if not reusableTransform then
            reusableTransform = (Transform and Transform.new and Transform.new())
                or (WorldTransform and WorldTransform.new and WorldTransform.new())
        end
        if reusableTransform and cameraSystem:GetActiveCameraWorldTransform(reusableTransform) then
            local activePos = reusableTransform.position
            if activePos == nil and reusableTransform.GetPosition then activePos = reusableTransform:GetPosition() end
            if activePos == nil and reusableTransform.GetTranslation then activePos = reusableTransform:GetTranslation() end
            if activePos == nil and reusableTransform.GetWorldPosition and WorldPosition and WorldPosition.ToVector4 then
                activePos = WorldPosition.ToVector4(reusableTransform:GetWorldPosition())
            end
            if activePos and activePos.x ~= nil then
                -- Check against both camera components (matches ITP mod.activeCameraOwner)
                if cachedFPPCam and cachedTPPCam then
                    local fppWorld = Perspective.GetCameraWorldPosition(cachedFPPCam)
                    local tppWorld = Perspective.GetCameraWorldPosition(cachedTPPCam)
                    if fppWorld and tppWorld then
                        local dfx, dfy, dfz = activePos.x - fppWorld.x, activePos.y - fppWorld.y, activePos.z - fppWorld.z
                        local dtx, dty, dtz = activePos.x - tppWorld.x, activePos.y - tppWorld.y, activePos.z - tppWorld.z
                        local distFPP2 = dfx * dfx + dfy * dfy + dfz * dfz
                        local distTPP2 = dtx * dtx + dty * dty + dtz * dtz
                        return distTPP2 < distFPP2
                    end
                end

                local playerPos = player:GetWorldPosition()
                if playerPos and playerPos.x ~= nil then
                    local dx = activePos.x - playerPos.x
                    local dy = activePos.y - playerPos.y
                    local dz = activePos.z - (playerPos.z + 1.55)
                    local distSq = dx * dx + dy * dy + dz * dz
                    return distSq >= 0.64
                end
            end
        end
    end

    -- Fallback: tppCamera component Y offset (behind player)
    if cachedTPPCam and cachedTPPCam.GetLocalPosition then
        local ok, pos = pcall(function() return cachedTPPCam:GetLocalPosition() end)
        if ok and pos and pos.y ~= nil then
            return (pos.y <= -0.75 or (pos.x ~= nil and math.abs(pos.x) >= 0.40))
        end
    end

    return false
end

return Perspective
