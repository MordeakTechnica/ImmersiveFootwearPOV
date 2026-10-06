-- =============================================================================
-- Immersive Footwear POV - Perspective & Camera Detection Service
-- Detects active camera perspective (FPP vs TPP) via REDengine CameraSystem transforms
-- Optimized: lazy-initializes CNames to avoid startup crashes, caches transforms and components
-- =============================================================================

local Perspective = {}

-- Cached static data (lazy-initialized to protect against boot-time VM unreadiness)
local isITPInstalledCache = nil
local fppCamName = nil
local tppCamName = nil
local reusableTransform = nil
local cachedPlayerID = nil
local cachedFPPCam = nil
local cachedTPPCam = nil

local function EnsureCamNames()
    if not fppCamName and CName and CName.new then
        fppCamName = CName.new("camera")
        tppCamName = CName.new("tppCamera")
    end
end

--- Query whether Immersive Third Person (ITP) mod is installed
---@return boolean
function Perspective.IsITPInstalled()
    if isITPInstalledCache == true then
        return true
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
        local container = Game.GetScriptableSystemsContainer and Game.GetScriptableSystemsContainer()
        if container then
            local bridge = container:Get("TPPCameraVisibleRenderBridge")
            if not bridge and CName and CName.new then
                bridge = container:Get(CName.new("TPPCameraVisibleRenderBridge"))
            end
            if bridge ~= nil then installed = true end
        end
    end)

    if not installed then
        EnsureCamNames()
        local player = Game.GetPlayer and Game.GetPlayer()
        if player and tppCamName and player:FindComponentByName(tppCamName) then
            installed = true
        end
    end

    if installed then
        isITPInstalledCache = true
    end

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
---@param player table
---@return boolean
function Perspective.IsTPPActive(player)
    if not player then return false end

    EnsureCamNames()

    -- Invalidate or update cached camera components if player changed
    local playerID = player:GetEntityID()
    if cachedPlayerID == nil or playerID.hash ~= cachedPlayerID.hash then
        cachedPlayerID = playerID
        cachedFPPCam = fppCamName and player:FindComponentByName(fppCamName) or nil
        cachedTPPCam = tppCamName and player:FindComponentByName(tppCamName) or nil
    else
        if not cachedFPPCam and fppCamName then cachedFPPCam = player:FindComponentByName(fppCamName) end
        if not cachedTPPCam and tppCamName then cachedTPPCam = player:FindComponentByName(tppCamName) end
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
                        if distTPP2 < distFPP2 then
                            isITPInstalledCache = true
                            return true
                        end
                        return false
                    end
                end

                local playerPos = player:GetWorldPosition()
                if playerPos and playerPos.x ~= nil then
                    local dx = activePos.x - playerPos.x
                    local dy = activePos.y - playerPos.y
                    local dz = activePos.z - (playerPos.z + 1.55)
                    local distSq = dx * dx + dy * dy + dz * dz
                    if distSq >= 0.64 then
                        isITPInstalledCache = true
                        return true
                    end
                end
            end
        end
    end

    -- Fallback: tppCamera component Y offset (behind player)
    if cachedTPPCam and cachedTPPCam.GetLocalPosition then
        local ok, pos = pcall(function() return cachedTPPCam:GetLocalPosition() end)
        if ok and pos and pos.y ~= nil then
            if (pos.y <= -0.75 or (pos.x ~= nil and math.abs(pos.x) >= 0.40)) then
                isITPInstalledCache = true
                return true
            end
        end
    end

    return false
end

return Perspective
