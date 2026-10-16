module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Lifecycle & State Event Hooks
// Listens to outfit changes, wardrobe resets, workspots, and vehicle events
// =============================================================================

public class FootwearHooksHelper {
  /**
   * Notifies the footwear system to re-evaluate equipped shoes and update heights.
   *
   * @param player Target player puppet entity.
   */
  public static func NotifyFootwearChanged(player: ref<PlayerPuppet>) -> Void {
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        sys.UpdateEquippedFootwear(player);
      };
    };
  }

  /**
   * Notifies the footwear system of entering or leaving a workspot (sitting/furniture).
   *
   * @param player Target player puppet entity.
   * @param inWorkspot True if entering workspot, false if exiting.
   */
  public static func NotifyWorkspotState(player: ref<PlayerPuppet>, inWorkspot: Bool) -> Void {
    if !IsDefined(player) {
      FootwearRedLogger.LogError("WORKSPOT", "NotifyWorkspotState failed: player entity is undefined");
      return;
    };
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
    if IsDefined(sys) {
      sys.SetWorkspotState(player, inWorkspot);
    } else {
      FootwearRedLogger.LogWarn("WORKSPOT", "NotifyWorkspotState: ImmersiveFootwearPOVSystem instance not found");
    };
  }

  /**
   * Notifies the footwear system of entering or leaving a vehicle.
   *
   * @param player Target player puppet entity.
   * @param inVehicle True if entering vehicle, false if unmounting.
   */
  public static func NotifyVehicleState(player: ref<PlayerPuppet>, inVehicle: Bool) -> Void {
    if !IsDefined(player) {
      FootwearRedLogger.LogError("VEHICLE", "NotifyVehicleState failed: player entity is undefined");
      return;
    };
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
    if IsDefined(sys) {
      sys.SetVehicleState(player, inVehicle);
    } else {
      FootwearRedLogger.LogWarn("VEHICLE", "NotifyVehicleState: ImmersiveFootwearPOVSystem instance not found");
    };
  }

  /**
   * Notifies the footwear system of a weapon manipulation action.
   *
   * @param player Target player puppet entity.
   * @param actionName Descriptive name of the weapon action.
   */
  public static func NotifyWeaponAction(player: ref<PlayerPuppet>, actionName: String) -> Void {
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        sys.OnWeaponAction(player, actionName);
      };
    };
  }


  /**
   * Determines whether an input action matches known weapon manipulation events.
   *
   * @param actionName Action identifier name.
   * @return True if the action is a weapon draw, holster, switch, or selection action.
   */
  public static func IsWeaponAction(actionName: CName) -> Bool {
    return Equals(actionName, n"DrawItem")
      || Equals(actionName, n"DrawWeapon")
      || Equals(actionName, n"HolsterWeapon")
      || Equals(actionName, n"SwitchWeapon")
      || Equals(actionName, n"WeaponWheel")
      || Equals(actionName, n"WeaponSlot1")
      || Equals(actionName, n"WeaponSlot2")
      || Equals(actionName, n"WeaponSlot3")
      || Equals(actionName, n"WeaponSlot4");
  }
}

// -----------------------------------------------------------------------------
// Equipment & Appearance Change Hooks
// -----------------------------------------------------------------------------
/**
 * Hooks item appearance resets on feet equipment area to trigger footwear updates.
 *
 * @param area Equipment slot area being reset.
 * @param force Optional flag forcing appearance recreation.
 */
@wrapMethod(EquipmentSystemPlayerData)
private final func ResetItemAppearance(area: gamedataEquipmentArea, opt force: Bool) -> Void {
  wrappedMethod(area, force);
  if Equals(area, gamedataEquipmentArea.Feet) {
    FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet);
  };
}

/**
 * Hooks appearance clearing events on feet equipment area to trigger footwear updates.
 *
 * @param area Equipment slot area being cleared.
 */
@wrapMethod(EquipmentSystemPlayerData)
private final func ClearItemAppearanceEvent(area: gamedataEquipmentArea) -> Void {
  wrappedMethod(area);
  if Equals(area, gamedataEquipmentArea.Feet) {
    FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet);
  };
}

/**
 * Hooks appearance reset events on feet equipment area to trigger footwear updates.
 *
 * @param area Equipment slot area being reset.
 */
@wrapMethod(EquipmentSystemPlayerData)
private final func ResetItemAppearanceEvent(area: gamedataEquipmentArea) -> Void {
  wrappedMethod(area);
  if Equals(area, gamedataEquipmentArea.Feet) {
    FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet);
  };
}

/**
 * Hooks restoration of player equipment data on save load to initialize footwear.
 */
@wrapMethod(EquipmentSystemPlayerData)
public final func OnRestored() -> Void {
  wrappedMethod();
  FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet);
}

/**
 * Hooks player entity attachment to the game world to initialize footwear height.
 *
 * @return Wrapped callback return value.
 */
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  FootwearHooksHelper.NotifyFootwearChanged(this);
  return result;
}

// -----------------------------------------------------------------------------
// In-Game Menu & Wardrobe UI Closing Hooks
// -----------------------------------------------------------------------------
/**
 * Hooks closing of in-game menus to re-sync footwear state on menu exit.
 *
 * @return Wrapped callback return value.
 */
@wrapMethod(gameuiInGameMenuGameController)
protected cb func OnUninitialize() -> Bool {
  let result: Bool = wrappedMethod();
  FootwearHooksHelper.NotifyFootwearChanged(this.GetPlayerControlledObject() as PlayerPuppet);
  return result;
}

/**
 * Hooks closing of inventory menus to re-sync footwear state after gear changes.
 *
 * @return Wrapped callback return value.
 */
@wrapMethod(gameuiInventoryGameController)
protected cb func OnUninitialize() -> Bool {
  let result: Bool = wrappedMethod();
  FootwearHooksHelper.NotifyFootwearChanged(this.GetPlayerControlledObject() as PlayerPuppet);
  return result;
}



// -----------------------------------------------------------------------------
// Workspot (Furniture, Sitting, Sleeping, Workstations) Lifecycle Hooks
// -----------------------------------------------------------------------------
/**
 * Hooks initiation of furniture and workspot interactions to trigger elevation suppression.
 *
 * @param evt Workspot start event payload.
 * @return Wrapped callback return value.
 */
@wrapMethod(PlayerPuppet)
protected cb func OnWorkspotStartedEvent(evt: ref<WorkspotStartedEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if !IsDefined(this) {
    FootwearRedLogger.LogError("WORKSPOT", "OnWorkspotStartedEvent called with undefined player entity");
  } else {
    FootwearRedLogger.LogInfo("WORKSPOT", "OnWorkspotStartedEvent: Workspot activated (chair/vending machine/furniture) | Action: Setting workspot state to TRUE and evaluating elevation suppression");
    FootwearHooksHelper.NotifyWorkspotState(this, true);
  };
  return result;
}

/**
 * Hooks completion or cancellation of workspot interactions to restore elevation.
 *
 * @param evt Workspot completion event payload.
 * @return Wrapped callback return value.
 */
@wrapMethod(PlayerPuppet)
protected cb func OnWorkspotFinishedEvent(evt: ref<WorkspotFinishedEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if !IsDefined(this) {
    FootwearRedLogger.LogError("WORKSPOT", "OnWorkspotFinishedEvent called with undefined player entity");
  } else {
    FootwearRedLogger.LogInfo("WORKSPOT", "OnWorkspotFinishedEvent: Workspot finished (standing/exited) | Action: Setting workspot state to FALSE and restoring footwear elevation");
    FootwearHooksHelper.NotifyWorkspotState(this, false);
  };
  return result;
}

// -----------------------------------------------------------------------------
// Vehicle Mounting Lifecycle Hooks
// -----------------------------------------------------------------------------
/**
 * Hooks vehicle mounting events to suppress footwear camera elevation while driving.
 *
 * @param evt Vehicle mounting event payload.
 * @return Wrapped callback return value.
 */
@wrapMethod(PlayerPuppet)
protected cb func OnMountingEvent(evt: ref<MountingEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if !IsDefined(this) {
    FootwearRedLogger.LogError("VEHICLE", "OnMountingEvent called with undefined player entity");
  } else {
    FootwearRedLogger.LogInfo("VEHICLE", "OnMountingEvent: Vehicle mounted | Action: Setting vehicle state to TRUE and evaluating elevation suppression");
    FootwearHooksHelper.NotifyVehicleState(this, true);
  };
  return result;
}

/**
 * Hooks vehicle unmounting events to restore footwear elevation upon exiting.
 *
 * @param evt Vehicle unmounting event payload.
 * @return Wrapped callback return value.
 */
@wrapMethod(PlayerPuppet)
protected cb func OnUnmountingEvent(evt: ref<UnmountingEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if !IsDefined(this) {
    FootwearRedLogger.LogError("VEHICLE", "OnUnmountingEvent called with undefined player entity");
  } else {
    FootwearRedLogger.LogInfo("VEHICLE", "OnUnmountingEvent: Vehicle unmounted | Action: Setting vehicle state to FALSE and restoring footwear elevation");
    FootwearHooksHelper.NotifyVehicleState(this, false);
  };
  return result;
}

// -----------------------------------------------------------------------------
// Weapon Draw / Holster / Weapon Wheel Actions Hook
// -----------------------------------------------------------------------------
/**
 * Hooks player input actions to catch weapon draw/holster gestures.
 *
 * @param action Listener action instance.
 * @param consumer Action consumer reference.
 * @return Wrapped callback return value.
 */
@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
  let result: Bool = wrappedMethod(action, consumer);
  let actionName: CName = ListenerAction.GetName(action);
  if ListenerAction.IsButtonJustPressed(action) {
    if FootwearHooksHelper.IsWeaponAction(actionName) {
      FootwearHooksHelper.NotifyWeaponAction(this, NameToString(actionName));
    } else if Equals(actionName, n"ToggleCamera") || Equals(actionName, n"ToggleVehFPPCamera") || Equals(actionName, n"CameraPerspective") || Equals(actionName, n"VehicleTogglePerspective") {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(this.GetGame());
      if IsDefined(sys) {
        sys.CheckPerspectiveDrift(this);
      };
    };
  };
  return result;
}

/**
 * Hooks item equipping into weapon or footwear slots to refresh mod state.
 *
 * @param evt Item added to slot event payload.
 * @return Wrapped callback return value.
 */
@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToSlot(evt: ref<ItemAddedToSlot>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let slotID: TweakDBID = evt.GetSlotID();
  if Equals(slotID, t"AttachmentSlots.WeaponRight") || Equals(slotID, t"AttachmentSlots.WeaponLeft") {
    FootwearHooksHelper.NotifyWeaponAction(this, "WeaponEquippedToSlot");
  } else if Equals(slotID, t"AttachmentSlots.Feet") || Equals(slotID, t"OutfitSlots.Feet") {
    FootwearHooksHelper.NotifyFootwearChanged(this);
  };
  return result;
}

/**
 * Hooks item un-equipping from weapon or footwear slots to refresh mod state.
 *
 * @param evt Item removed from slot event payload.
 * @return Wrapped callback return value.
 */
@wrapMethod(PlayerPuppet)
protected cb func OnItemRemovedFromSlot(evt: ref<ItemRemovedFromSlot>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let slotID: TweakDBID = evt.GetSlotID();
  if Equals(slotID, t"AttachmentSlots.WeaponRight") || Equals(slotID, t"AttachmentSlots.WeaponLeft") {
    FootwearHooksHelper.NotifyWeaponAction(this, "WeaponRemovedFromSlot");
  } else if Equals(slotID, t"AttachmentSlots.Feet") || Equals(slotID, t"OutfitSlots.Feet") {
    FootwearHooksHelper.NotifyFootwearChanged(this);
  };
  return result;
}

// -----------------------------------------------------------------------------
// Native Locomotion Frame Tick (Catwalk Stride & Hip Sway)
// Eliminates per-frame Lua-to-C++ FFI overhead entirely
// -----------------------------------------------------------------------------
/**
 * Native locomotion state machine tick for evaluating pelvic sway and catwalk stride.
 *
 * @param timeDelta Frame delta time in seconds.
 * @param stateContext Locomotion state context reference.
 * @param scriptInterface Locomotion script interface reference.
 */
@wrapMethod(LocomotionEventsTransition)
protected func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(timeDelta, stateContext, scriptInterface);
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
    if IsDefined(sys) {
      sys.OnLocomotionUpdate(player, timeDelta);
    };
  };
}
