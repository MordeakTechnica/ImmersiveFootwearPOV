-- =============================================================================
-- Immersive Footwear POV - Perspective & Camera Detection Service
-- Detects active camera perspective (FPP vs TPP) via REDengine CameraSystem transforms
-- and detects Immersive Third Person (ITP) installation status
-- =============================================================================

local Perspective = {}

--- Query whether Immersive Third Person (ITP) mod is installed
---@return boolean
function Perspective.IsITPInstalled()
    if GetMod then
        local itpMod = GetMod("immersive_third_person") or GetMod("ImmersiveThirdPerson") or GetMod("ITP")
        if itpMod ~= nil then
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
        if player and player:FindComponentByName(CName.new("tppCamera")) then
            installed = true
        end
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

    -- Primary: REDengine CameraSystem distance to active camera
    local cameraSystem = Game.GetCameraSystem and Game.GetCameraSystem()
    if cameraSystem and cameraSystem.GetActiveCameraWorldTransform then
        local transform = (Transform and Transform.new and Transform.new())
            or (WorldTransform and WorldTransform.new and WorldTransform.new())
        if transform and cameraSystem:GetActiveCameraWorldTransform(transform) then
            local activePos = transform.position
            if activePos == nil and transform.GetPosition then activePos = transform:GetPosition() end
            if activePos == nil and transform.GetTranslation then activePos = transform:GetTranslation() end
            if activePos == nil and transform.GetWorldPosition and WorldPosition and WorldPosition.ToVector4 then
                activePos = WorldPosition.ToVector4(transform:GetWorldPosition())
            end
            if activePos and activePos.x ~= nil then
                -- Check against both camera components (matches ITP mod.activeCameraOwner)
                local fppCam = player:FindComponentByName(CName.new("camera"))
                local tppCam = player:FindComponentByName(CName.new("tppCamera"))
                if fppCam and tppCam then
                    local fppWorld = Perspective.GetCameraWorldPosition(fppCam)
                    local tppWorld = Perspective.GetCameraWorldPosition(tppCam)
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
    local tppCam = player:FindComponentByName(CName.new("tppCamera"))
    if tppCam and tppCam.GetLocalPosition then
        local ok, pos = pcall(function() return tppCam:GetLocalPosition() end)
        if ok and pos and pos.y ~= nil then
            return (pos.y <= -0.75 or (pos.x ~= nil and math.abs(pos.x) >= 0.40))
        end
    end

    return false
end

return Perspective
