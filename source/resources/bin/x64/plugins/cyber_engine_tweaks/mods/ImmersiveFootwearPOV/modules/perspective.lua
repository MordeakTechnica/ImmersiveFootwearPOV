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
---@param sys table|nil
---@return boolean
function Perspective.IsTPPActive(player, sys)
    if not player then return false end

    -- Strategy 1: Native REDscript system query (fastest, most authoritative)
    if sys and sys.IsTPPActive then
        local ok, active = pcall(function() return sys:IsTPPActive(player) end)
        if ok and type(active) == "boolean" then
            if active then isITPInstalledCache = true end
            return active
        end
    end

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

    -- Strategy 2: REDengine CameraSystem distance from active camera to player head
    -- In FPP, active camera is inside player head (distSq < 0.25)
    -- In TPP/ITP, active camera is behind/around player (distSq >= 0.64, i.e. >= 0.80m)
    local cameraSystem = Game.GetCameraSystem and Game.GetCameraSystem()
    if cameraSystem and cameraSystem.GetActiveCameraWorldTransform then
        if not reusableTransform then
            reusableTransform = (WorldTransform and WorldTransform.new and WorldTransform.new())
                or (Transform and Transform.new and Transform.new())
        end
        if reusableTransform then
            local okXf = pcall(function() return cameraSystem:GetActiveCameraWorldTransform(reusableTransform) end)
            if okXf then
                local activePos = nil
                if reusableTransform.GetPosition then activePos = reusableTransform:GetPosition() end
                if not activePos and reusableTransform.position then activePos = reusableTransform.position end
                if not activePos and reusableTransform.GetTranslation then activePos = reusableTransform:GetTranslation() end
                if not activePos and reusableTransform.GetWorldPosition and WorldPosition and WorldPosition.ToVector4 then
                    activePos = WorldPosition.ToVector4(reusableTransform:GetWorldPosition())
                end

                if activePos and activePos.x ~= nil then
                    local playerPos = player:GetWorldPosition()
                    if playerPos and playerPos.x ~= nil then
                        local dx = activePos.x - playerPos.x
                        local dy = activePos.y - playerPos.y
                        local dz = activePos.z - (playerPos.z + 1.55)
                        local distSq = dx * dx + dy * dy + dz * dz
                        if distSq >= 0.64 then
                            isITPInstalledCache = true
                            return true
                        elseif distSq < 0.25 then
                            return false
                        end
                    end
                end
            end
        end
    end

    -- Strategy 3: Fallback via tppCamera component local Y offset (behind player)
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
