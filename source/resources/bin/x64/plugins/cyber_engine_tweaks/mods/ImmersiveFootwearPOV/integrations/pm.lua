-- =============================================================================
-- Immersive Footwear POV - Photo Mode (PM) Lifecycle & Native Elevation Integration
-- Observes Photo Mode lifecycle events and drives native Attribute 37 (V Up/Down)
-- Ensures 3rd-person Photo Mode character poses have accurate platform sole elevation
-- =============================================================================

local PM_CONSTANTS = {
    ATTR_V_UP_DOWN = 37,           -- Native Cyberpunk 2077 Photo Mode V Elevation Attribute
    ATTR_WARDROBE_SET = 3300,      -- Vanilla Wardrobe set switcher attribute
    ATTR_EQUIPMENT_EX_OUTFIT = 3301, -- Equipment-EX outfit switcher attribute
    DELAY_FRAMES_INITIAL_ELEVATION = 2, -- Frames to wait after OnShow for PM menu readiness
    DELAY_FRAMES_OUTFIT_INSPECT = 8,    -- Frames to wait after wardrobe switch for mesh attachment
}

local FOOTWEAR_SLOTS = {
    "OutfitSlots.Feet",
    "AttachmentSlots.Feet",
    "OutfitSlots.FeetOuter",
    "OutfitSlots.Legs",
}

local PM = {
    isPhotoModeActive = false,
    controller = nil,
    pendingElevation = nil,
    pendingPlatformCm = 0.0,
    elevationFrames = 0,
    pendingInspectFrames = nil,
    ATTR_V_UP_DOWN = PM_CONSTANTS.ATTR_V_UP_DOWN,
    modState = nil,
}

-- -----------------------------------------------------------------------------
-- Logging & Diagnostics
-- -----------------------------------------------------------------------------
local function LogPM(fmt, ...)
    local msg = string.format(fmt, ...)
    if PM.modState and PM.modState.debugLogs then
        print(string.format("[ImmersiveFootwearPOV][PM] %s", msg))
        pcall(function()
            local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
            if sys and sys.LogLevelFromCET then
                sys:LogLevelFromCET("DEBUG", "PM", msg)
            end
        end)
    end
end

function PM.IsActive()
    return PM.isPhotoModeActive
end

-- -----------------------------------------------------------------------------
-- Native UI Attribute Dispatcher
-- -----------------------------------------------------------------------------
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
        local forceOk = pcall(function()
            item:ForceValue(value, true)
        end)
        if forceOk then
            LogPM("ForceAttribute via item:ForceValue(Attr=%d, Val=%.4f) SUCCEEDED", attribute, value)
            return true
        end
    end

    local callbackOk, callbackErr = pcall(function()
        PM.controller:OnForceAttributeVaulue(attribute, value, true)
    end)
    if callbackOk then
        LogPM("ForceAttribute via controller:OnForceAttributeVaulue(Attr=%d, Val=%.4f) SUCCEEDED", attribute, value)
    else
        LogPM("ForceAttribute FAILED: %s", tostring(callbackErr))
    end
    return callbackOk
end

-- -----------------------------------------------------------------------------
-- Entity & Shoe Lookup Helpers
-- -----------------------------------------------------------------------------
local function ExtractCleanTDBIDString(tdbid)
    if not tdbid then return "" end
    local str = tostring(tdbid)
    local clean = string.match(str, "%-%-%[%[%s*(.-)%s*%-%-%]%]")
    return (clean and #clean > 0) and clean or str
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
    return (displayName and displayName ~= "") and displayName or (cleanKey or tostring(tdbid))
end

local function GetPMPuppet(controller)
    local puppet = nil
    if controller and controller.fakePuppet then
        puppet = controller.fakePuppet
    end
    if not puppet then
        pcall(function()
            local helper = Game.GetScriptableSystemsContainer():Get("EquipmentEx.PaperdollHelper")
            if helper then
                puppet = helper:GetPuppet()
            end
        end)
    end
    if not puppet then
        puppet = Game.GetPlayer()
    end
    return puppet
end

local function GetEquippedFootwear(puppet)
    local ts = Game.GetTransactionSystem()
    if not ts or not puppet then return nil, nil end

    for _, slotName in ipairs(FOOTWEAR_SLOTS) do
        local itemObj = ts:GetItemInSlot(puppet, TweakDBID.new(slotName))
        if itemObj then
            local itemID = itemObj:GetItemID()
            if ItemID.IsValid(itemID) then
                return itemID, slotName
            end
        end
    end
    return nil, nil
end

local function ResolveShoeHeights(itemID, tdbid, cleanKey)
    local heelCm, platCm = 0.0, 0.0

    -- 1. Official TweakDB metadata tags via REDscript ShoeHeightParser
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

    if heelCm > 0.0 or platCm > 0.0 then
        return heelCm, platCm, "TweakDB Tags"
    end

    -- 2. Custom user overrides in JSON
    local saved = PM.modState and PM.modState.overrides and PM.modState.overrides[cleanKey]
    if saved then
        return tonumber(saved.heel) or 0.0, tonumber(saved.platform) or 0.0, "Custom Override"
    end

    return 0.0, 0.0, "None"
end

local function CalculatePMElevation(platformCm)
    local autoElevate = PM.modState and (PM.modState.autoElevatePMPlatform ~= false) or true
    local elevationMeters = (autoElevate and platformCm > 0.0) and (platformCm / 100.0) or 0.0
    return elevationMeters, autoElevate
end

local function ExtractOptionText(option)
    if not option then return nil end
    if type(option) == "string" then return option end
    if option.optionText then return tostring(option.optionText) end
    if option.GetOptionText then return tostring(option:GetOptionText()) end
    return nil
end

-- -----------------------------------------------------------------------------
-- Photo Mode Elevation Controller
-- -----------------------------------------------------------------------------
local function UpdatePMElevationFromOutfitName(controller, outfitName)
    local ok, success = pcall(function()
        local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
        if not sys then return false end

        local itemID = sys:ReadFootwearFromEquipmentExOutfit(CName.new(outfitName))
        if not itemID or not ItemID.IsValid(itemID) then
            return false
        end

        local tdbid = ItemID.GetTDBID(itemID)
        local shoeKey = ExtractCleanTDBIDString(tdbid)
        local displayName = GetShoeDisplayName(tdbid, shoeKey)
        local heelCm, platformCm, source = ResolveShoeHeights(itemID, tdbid, shoeKey)
        local elevationMeters, autoElevate = CalculatePMElevation(platformCm)

        PM.pendingInspectFrames = nil
        LogPM("Outfit Switched -> '%s' (Footwear: '%s', Key: '%s', Source: %s) | Heel: +%.1f cm | Platform: +%.1f cm | AutoElevate: %s | Elevation: +%.4f m",
            tostring(outfitName),
            tostring(displayName),
            tostring(shoeKey),
            source,
            heelCm,
            platformCm,
            tostring(autoElevate),
            elevationMeters)

        PM.ForceAttribute(PM_CONSTANTS.ATTR_V_UP_DOWN, elevationMeters)
        return true
    end)
    return ok and (success == true)
end

local function UpdatePMFootwearElevation(controller)
    local ok, err = pcall(function()
        local puppet = GetPMPuppet(controller)
        if not puppet then return end

        local itemID, slotName = GetEquippedFootwear(puppet)
        local displayName, shoeKey, source = "Barefoot / Flat", "", "None"
        local heelCm, platformCm = 0.0, 0.0

        if itemID then
            local tdbid = ItemID.GetTDBID(itemID)
            shoeKey = ExtractCleanTDBIDString(tdbid)
            displayName = GetShoeDisplayName(tdbid, shoeKey)
            heelCm, platformCm, source = ResolveShoeHeights(itemID, tdbid, shoeKey)
        end

        local elevationMeters, autoElevate = CalculatePMElevation(platformCm)

        LogPM("Outfit Switched -> Footwear: '%s' (Key: '%s', Slot: %s, Source: %s) | Heel: +%.1f cm | Platform: +%.1f cm | AutoElevate: %s | Elevation: +%.4f m",
            tostring(displayName),
            tostring(shoeKey),
            tostring(slotName or "None"),
            source,
            heelCm,
            platformCm,
            tostring(autoElevate),
            elevationMeters)

        PM.ForceAttribute(PM_CONSTANTS.ATTR_V_UP_DOWN, elevationMeters)
    end)
    if not ok then
        print(string.format("[ImmersiveFootwearPOV][PM] UpdatePMFootwearElevation error: %s", tostring(err)))
    end
end

-- -----------------------------------------------------------------------------
-- Lifecycle & Event Registration
-- -----------------------------------------------------------------------------
function PM.Init(modState)
    PM.modState = modState

    Observe("gameuiPhotoModeMenuController", "OnShow", function(controller)
        PM.isPhotoModeActive = true
        PM.controller = controller
        if modState then
            modState.isPhotoModeOpen = true
        end

        pcall(function()
            local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
            if sys and sys.SetPhotoModeActive then
                sys:SetPhotoModeActive(true)
            end
        end)

        local shoeState = modState and modState.currentShoeState or {}
        local platformCm = shoeState.platformCm or 0.0
        local heelCm = shoeState.heelCm or 0.0
        local elevationMeters, autoElevate = CalculatePMElevation(platformCm)

        LogPM("OnShow triggered. Controller: %s | Shoe: '%s' (ID: %s) | Heel: +%.1fcm | Platform: +%.1fcm | AutoElevate: %s",
            controller and "Valid" or "nil",
            tostring(shoeState.displayName or "None"),
            tostring(shoeState.key or "None"),
            heelCm,
            platformCm,
            tostring(autoElevate))

        if autoElevate and platformCm > 0.0 then
            PM.pendingElevation = elevationMeters
            PM.pendingPlatformCm = platformCm
            PM.elevationFrames = 0
        else
            PM.pendingElevation = nil
            PM.pendingPlatformCm = 0.0
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnHide", function()
        if PM.isPhotoModeActive then
            LogPM("OnHide triggered. Exiting Photo Mode. Cleaning up controller and restoring stance.")
            PM.isPhotoModeActive = false
            PM.controller = nil
            PM.pendingElevation = nil
            PM.pendingPlatformCm = 0.0
            PM.elevationFrames = 0
            PM.pendingInspectFrames = nil
            if modState then
                modState.isPhotoModeOpen = false
            end
            pcall(function()
                local sys = Game.GetScriptableSystemsContainer():Get("ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem")
                if sys and sys.SetPhotoModeActive then
                    sys:SetPhotoModeActive(false)
                end
            end)
        end
    end)

    local function TriggerDelayedInspection()
        if PM.isPhotoModeActive then
            PM.pendingInspectFrames = PM_CONSTANTS.DELAY_FRAMES_OUTFIT_INSPECT
        end
    end

    Observe("gameuiPhotoModeMenuController", "OnAttributeOptionSelected", function(controller, attribute, option)
        local attrId = tonumber(attribute) or 0
        if attrId == PM_CONSTANTS.ATTR_EQUIPMENT_EX_OUTFIT or attrId == PM_CONSTANTS.ATTR_WARDROBE_SET then
            local optText = ExtractOptionText(option)
            if optText and #optText > 0 then
                local success = UpdatePMElevationFromOutfitName(controller, optText)
                if not success then
                    TriggerDelayedInspection()
                end
            else
                TriggerDelayedInspection()
            end
        end
    end)

    Observe("gameuiPhotoModeMenuController", "OnEquipWardrobeSet", function(controller, setIndex)
        TriggerDelayedInspection()
    end)
end

function PM.OnUpdate(deltaTime)
    -- Asynchronous in-PM outfit inspection queue (waits for mesh attachment)
    if PM.pendingInspectFrames ~= nil and PM.isPhotoModeActive then
        PM.pendingInspectFrames = PM.pendingInspectFrames - 1
        if PM.pendingInspectFrames <= 0 then
            PM.pendingInspectFrames = nil
            UpdatePMFootwearElevation(PM.controller)
        end
    end

    -- Initial PM entry elevation dispatcher
    if PM.pendingElevation ~= nil and PM.isPhotoModeActive and PM.controller ~= nil then
        PM.elevationFrames = PM.elevationFrames + 1
        if PM.elevationFrames >= PM_CONSTANTS.DELAY_FRAMES_INITIAL_ELEVATION then
            local success = PM.ForceAttribute(PM_CONSTANTS.ATTR_V_UP_DOWN, PM.pendingElevation)
            if success and PM.pendingPlatformCm > 0.0 then
                LogPM("Photo Mode character elevated: +%.1f cm (+%.4f m)", PM.pendingPlatformCm, PM.pendingElevation)
            end
            PM.pendingElevation = nil
        end
    end
end

return PM
