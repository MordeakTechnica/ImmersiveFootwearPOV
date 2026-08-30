-- =============================================================================
-- Immersive Footwear POV - Photo Mode (PM) Lifecycle & Native Elevation Integration
-- Observes Photo Mode lifecycle events and drives native Attribute 37 (V Up/Down)
-- Ensures 3rd-person Photo Mode character poses have accurate platform sole elevation
-- =============================================================================

local PM = {
    isPhotoModeActive = false,
    controller = nil,
    pendingElevation = nil,
    pendingPlatformCm = 0.0,
    elevationFrames = 0,
    pendingInspectFrames = nil,
    ATTR_V_UP_DOWN = 37, -- Native Cyberpunk 2077 Photo Mode V Elevation Attribute
    modState = nil,
}

local function LogPM(fmt, ...)
    if PM.modState and PM.modState.debugLogs then
        print(string.format("[ImmersiveFootwearPOV][PM] " .. fmt, ...))
    end
end

function PM.IsActive()
    return PM.isPhotoModeActive
end

function PM.ForceAttribute(attribute, value)
    if not PM.controller or not PM.isPhotoModeActive then
        LogPM("ForceAttribute called but controller is %s, isPhotoModeActive is %s",
            PM.controller and "valid" or "nil", tostring(PM.isPhotoModeActive))
        return false
    end

    local itemOk, item = pcall(function()
        return PM.controller:GetMenuItem(attribute)
    end)

    if itemOk and item ~= nil then
        local forceOk, err = pcall(function()
            item:ForceValue(value, true)
        end)
        if forceOk then
            LogPM("ForceAttribute via item:ForceValue(Attr=%d, Val=%.4f) SUCCEEDED", attribute, value)
            return true
        else
            LogPM("ForceAttribute via item:ForceValue FAILED: %s (falling back to controller:OnForceAttributeVaulue)", tostring(err))
        end
    else
        LogPM("GetMenuItem(%d) returned %s (pcall ok: %s)", attribute, item == nil and "nil" or "found", tostring(itemOk))
    end

    local callbackOk, callbackErr = pcall(function()
        PM.controller:OnForceAttributeVaulue(attribute, value, true)
    end)
    if callbackOk then
        LogPM("ForceAttribute via controller:OnForceAttributeVaulue(Attr=%d, Val=%.4f) SUCCEEDED", attribute, value)
    else
        LogPM("ForceAttribute via controller:OnForceAttributeVaulue FAILED: %s", tostring(callbackErr))
    end
    return callbackOk
end

local function ExtractCleanTDBIDString(tdbid)
    if not tdbid then return "" end
    local str = tostring(tdbid)
    local clean = string.match(str, "%-%-%[%[%s*(.-)%s*%-%-%]%]")
    if clean and #clean > 0 then
        return clean
    end
    return str
end

local function GetShoeDisplayName(tdbid, cleanKey)
    local displayName = nil
    pcall(function()
        local record = TweakDBInterface.GetItemRecord(tdbid)
        if not record and cleanKey and #cleanKey > 0 then
            record = TweakDBInterface.GetItemRecord(TweakDBID.new(cleanKey))
        end
        if record then
            local loc = record:DisplayName()
            if loc and #loc > 0 then
                displayName = GetLocalizedText(loc)
            end
        end
    end)
    if not displayName or displayName == "" then
        displayName = cleanKey or tostring(tdbid)
    end
    return displayName
end

local function ReadShoeHeightsFromSystem(itemID, tdbid)
    local heelCm = 0.0
    local platCm = 0.0
    pcall(function()
        local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
        if sys then
            if itemID and ItemID.IsValid(itemID) then
                platCm = sys:ReadPlatformHeightFromItemID(itemID) * 100.0
                heelCm = sys:ReadHeelHeightFromItemID(itemID) * 100.0
            elseif tdbid and TDBID.IsValid(tdbid) then
                platCm = sys:ReadPlatformHeightFromTDBID(tdbid) * 100.0
                heelCm = sys:ReadHeelHeightFromTDBID(tdbid) * 100.0
            end
        end
    end)
    return heelCm, platCm
end

local function UpdatePMFootwearElevation(controller)
    local ok, err = pcall(function()
        local puppet = nil
        if controller and controller.fakePuppet then
            puppet = controller.fakePuppet
        end
        if not puppet then
            local helper = Game.GetScriptableSystemsContainer():Get("EquipmentEx.PaperdollHelper")
            if helper then
                puppet = helper:GetPuppet()
            end
        end
        if not puppet then
            puppet = Game.GetPlayer()
        end

        if not puppet then
            print("[ImmersiveFootwearPOV][PM] Could not resolve PM puppet entity")
            return
        end

        local ts = Game.GetTransactionSystem()
        if not ts then return end

        local slots = {
            "OutfitSlots.Feet",
            "AttachmentSlots.Feet",
            "OutfitSlots.FeetOuter",
            "OutfitSlots.Legs"
        }

        local foundItemID = nil
        local foundSlot = nil
        for _, slotName in ipairs(slots) do
            local itemObj = ts:GetItemInSlot(puppet, TweakDBID.new(slotName))
            if itemObj then
                local itemID = itemObj:GetItemID()
                if ItemID.IsValid(itemID) then
                    foundItemID = itemID
                    foundSlot = slotName
                    break
                end
            end
        end

        local platformCm = 0.0
        local heelCm = 0.0
        local displayName = "Barefoot / Flat"
        local shoeKey = ""
        local source = "None"

        if foundItemID then
            local tdbid = ItemID.GetTDBID(foundItemID)
            shoeKey = ExtractCleanTDBIDString(tdbid)
            displayName = GetShoeDisplayName(tdbid, shoeKey)

            -- 1. Check official TweakDB metadata tags via REDscript ShoeHeightParser
            local officialHeelCm, officialPlatCm = ReadShoeHeightsFromSystem(foundItemID, tdbid)
            if officialHeelCm > 0.0 or officialPlatCm > 0.0 then
                heelCm = officialHeelCm
                platformCm = officialPlatCm
                source = "TweakDB Tags"
            else
                -- 2. If untagged, check user custom overrides
                local saved = PM.modState and PM.modState.overrides and PM.modState.overrides[shoeKey]
                if saved then
                    platformCm = tonumber(saved.platform) or 0.0
                    heelCm = tonumber(saved.heel) or 0.0
                    source = "Custom Override"
                end
            end
        end

        local autoElevate = PM.modState and (PM.modState.autoElevatePMPlatform ~= false) or true
        local elevationMeters = (autoElevate and platformCm > 0.0) and (platformCm / 100.0) or 0.0

        print(string.format("[ImmersiveFootwearPOV][PM] Outfit Switched -> Footwear: '%s' (Key: '%s', Slot: %s, Source: %s) | Heel: +%.1f cm | Platform: +%.1f cm | AutoElevate: %s | Elevation: +%.4f m",
            tostring(displayName),
            tostring(shoeKey),
            tostring(foundSlot or "None"),
            source,
            heelCm,
            platformCm,
            tostring(autoElevate),
            elevationMeters))

        PM.ForceAttribute(PM.ATTR_V_UP_DOWN, elevationMeters)
    end)
    if not ok then
        print(string.format("[ImmersiveFootwearPOV][PM] UpdatePMFootwearElevation error: %s", tostring(err)))
    end
end

function PM.Init(modState)
    PM.modState = modState
    Observe("gameuiPhotoModeMenuController", "OnShow", function(controller)
        PM.isPhotoModeActive = true
        PM.controller = controller
        if modState then
            modState.isPhotoModeOpen = true
        end

        local shoeState = modState and modState.currentShoeState or {}
        local platformCm = shoeState.platformCm or 0.0
        local heelCm = shoeState.heelCm or 0.0
        local autoElevate = modState and (modState.autoElevatePMPlatform ~= false) or true

        print(string.format("[ImmersiveFootwearPOV][PM] OnShow triggered. Controller: %s | Shoe: '%s' (ID: %s) | Heel: +%.1fcm | Platform: +%.1fcm | AutoElevate: %s",
            controller and "Valid" or "nil",
            tostring(shoeState.displayName or "None"),
            tostring(shoeState.key or "None"),
            heelCm,
            platformCm,
            tostring(autoElevate)))

        if autoElevate and platformCm > 0.0 then
            PM.pendingElevation = platformCm / 100.0
            PM.pendingPlatformCm = platformCm
            PM.elevationFrames = 0
            LogPM("Queued Native Attribute %d (+%.1f cm / +%.4f m) platform sole elevation for PM character puppet",
                PM.ATTR_V_UP_DOWN, platformCm, PM.pendingElevation)
        else
            PM.pendingElevation = nil
            PM.pendingPlatformCm = 0.0
            LogPM("No Photo Mode platform elevation queued (Platform: +%.1fcm, AutoElevate: %s)", platformCm, tostring(autoElevate))
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnHide", function()
        if PM.isPhotoModeActive then
            print("[ImmersiveFootwearPOV][PM] OnHide triggered. Exiting Photo Mode. Cleaning up controller and restoring stance.")
            PM.isPhotoModeActive = false
            PM.controller = nil
            PM.pendingElevation = nil
            PM.pendingPlatformCm = 0.0
            PM.elevationFrames = 0
            PM.pendingInspectFrames = nil
            if modState then
                modState.isPhotoModeOpen = false
            end
        end
    end)

    Observe("PhotoModeMenuListItem", "StartArrowClickedEffect", function(listItem, widget)
        if PM.isPhotoModeActive then
            local data = listItem and listItem:GetData()
            local attrKey = data and data.attributeKey or "unknown"
            if tostring(attrKey) == "3301" or tostring(attrKey) == "3300" then
                PM.pendingInspectFrames = 5
            end
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnAttributeUpdated", function(controller, attributeKey, attributeValue, doApply)
        if PM.isPhotoModeActive then
            if tostring(attributeKey) == "3301" or tostring(attributeKey) == "3300" then
                PM.pendingInspectFrames = 5
            end
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnAttributeOptionSelected", function(controller, attribute, option)
        if PM.isPhotoModeActive then
            local optText = option and option.optionText or ""
            local optData = option and option.optionData or ""
            print(string.format("[ImmersiveFootwearPOV][PM] OnAttributeOptionSelected -> Attr: %s, Option: '%s' (Data: %s)",
                tostring(attribute), tostring(optText), tostring(optData)))
            PM.pendingInspectFrames = 5
        end
    end)

    Observe("PhotoModePlayerEntityComponent", "OnItemAddedToSlot", function(component, evt)
        if PM.isPhotoModeActive and evt then
            PM.pendingInspectFrames = 3
        end
    end)

    Observe("EquipmentSystemPlayerData", "SwitchWardrobeSet", function(playerData, setIndex)
        print(string.format("[ImmersiveFootwearPOV][PM] Wardrobe SwitchWardrobeSet -> Set Index: %s", tostring(setIndex)))
        if PM.isPhotoModeActive then
            PM.pendingInspectFrames = 5
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnEquipWardrobeSet", function(controller, setIndex)
        print(string.format("[ImmersiveFootwearPOV][PM] OnEquipWardrobeSet -> Set Index: %s", tostring(setIndex)))
        if PM.isPhotoModeActive then
            PM.pendingInspectFrames = 5
        end
    end)
end

function PM.OnUpdate(deltaTime)
    if PM.pendingInspectFrames ~= nil and PM.isPhotoModeActive then
        PM.pendingInspectFrames = PM.pendingInspectFrames - 1
        if PM.pendingInspectFrames <= 0 then
            PM.pendingInspectFrames = nil
            UpdatePMFootwearElevation(PM.controller)
        end
    end

    if PM.pendingElevation ~= nil and PM.isPhotoModeActive and PM.controller ~= nil then
        PM.elevationFrames = PM.elevationFrames + 1
        LogPM("OnUpdate frame %d: Waiting to apply Attribute %d (+%.4f m)...", PM.elevationFrames, PM.ATTR_V_UP_DOWN, PM.pendingElevation)
        if PM.elevationFrames >= 2 then
            LogPM("OnUpdate frame %d reached: Dispatching ForceAttribute(%d, +%.4f m)...", PM.elevationFrames, PM.ATTR_V_UP_DOWN, PM.pendingElevation)
            local success = PM.ForceAttribute(PM.ATTR_V_UP_DOWN, PM.pendingElevation)
            if success and PM.pendingPlatformCm > 0.0 then
                print(string.format("[ImmersiveFootwearPOV] Photo Mode character elevated: +%.1f cm (+%.2f m)", PM.pendingPlatformCm, PM.pendingElevation))
            elseif not success then
                print(string.format("[ImmersiveFootwearPOV][ERROR] Failed to apply Photo Mode elevation (+%.1f cm) to Attribute %d", PM.pendingPlatformCm, PM.ATTR_V_UP_DOWN))
            end
            PM.pendingElevation = nil
        end
    end
end

return PM
