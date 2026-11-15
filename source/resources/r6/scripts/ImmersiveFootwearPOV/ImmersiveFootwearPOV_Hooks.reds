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
   * @param immediate If true, evaluates immediately; if false, debounces across rapid-fire bursts.
   */
  public static func NotifyFootwearChanged(player: ref<PlayerPuppet>, opt immediate: Bool) -> Void {
    if !IsDefined(player) {
      return;
    };
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
    if !IsDefined(sys) {
      return;
    };
    if immediate {
      sys.UpdateEquippedFootwear(player);
    } else {
      sys.QueueDebouncedUpdate();
    };
  }

  /**
   * Notifies the footwear system when an in-game inventory, wardrobe, or character menu closes.
   * Performs an immediate update and schedules a delayed post-restore tick so third-person
   * animgraph elevation and perspective drift are re-asserted after menu teardown and mesh swaps.
   *
   * @param player Target player puppet entity.
   */
  public static func NotifyMenuClosed(player: ref<PlayerPuppet>) -> Void {
    let reqHandler: ref<inkISystemRequestsHandler> = GameInstance.GetSystemRequestsHandler();
    if IsDefined(reqHandler) && reqHandler.IsPreGame() {
      return;
    };
    if !IsDefined(player) || !player.IsAttached() || player.IsDead() {
      return;
    };
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
    if !IsDefined(sys) {
      return;
    };
    sys.CheckPerspectiveDrift(player);
    sys.UpdateEquippedFootwear(player);
    sys.QueuePostRestoreTick();
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
    if !IsDefined(sys) {
      FootwearRedLogger.LogWarn("WORKSPOT", "NotifyWorkspotState: ImmersiveFootwearPOVSystem instance not found");
      return;
    };
    sys.SetWorkspotState(player, inWorkspot);
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
    if !IsDefined(sys) {
      FootwearRedLogger.LogWarn("VEHICLE", "NotifyVehicleState: ImmersiveFootwearPOVSystem instance not found");
      return;
    };
    sys.SetVehicleState(player, inVehicle);
  }

  /**
   * Notifies the footwear system of a weapon manipulation action.
   *
   * @param player Target player puppet entity.
   * @param actionName Descriptive name of the weapon action.
   */
  public static func NotifyWeaponAction(player: ref<PlayerPuppet>, actionName: String) -> Void {
    if !IsDefined(player) {
      return;
    };
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
    if !IsDefined(sys) {
      return;
    };
    sys.OnWeaponAction(player, actionName);
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

  public static func IsCameraPerspectiveAction(actionName: CName) -> Bool {
    return Equals(actionName, n"ToggleCamera")
      || Equals(actionName, n"ToggleVehFPPCamera")
      || Equals(actionName, n"CameraPerspective")
      || Equals(actionName, n"VehicleTogglePerspective");
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
  if !Equals(area, gamedataEquipmentArea.Feet) {
    return;
  };
  FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet, false);
}

/**
 * Hooks appearance clearing events on feet equipment area to trigger footwear updates.
 *
 * @param area Equipment slot area being cleared.
 */
@wrapMethod(EquipmentSystemPlayerData)
private final func ClearItemAppearanceEvent(area: gamedataEquipmentArea) -> Void {
  wrappedMethod(area);
  if !Equals(area, gamedataEquipmentArea.Feet) {
    return;
  };
  FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet, false);
}

/**
 * Hooks appearance reset events on feet equipment area to trigger footwear updates.
 *
 * @param area Equipment slot area being reset.
 */
@wrapMethod(EquipmentSystemPlayerData)
private final func ResetItemAppearanceEvent(area: gamedataEquipmentArea) -> Void {
  wrappedMethod(area);
  if !Equals(area, gamedataEquipmentArea.Feet) {
    return;
  };
  FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet, false);
}

/**
 * Hooks restoration of player equipment data on save load to initialize footwear.
 */
@wrapMethod(EquipmentSystemPlayerData)
public final func OnRestored() -> Void {
  wrappedMethod();
  FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet, false);
}

/**
 * Hooks player entity attachment to the game world to initialize footwear height.
 *
 * @return Wrapped callback return value.
 */
@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  FootwearHooksHelper.NotifyFootwearChanged(this, true);
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
  FootwearHooksHelper.NotifyMenuClosed(this.GetPlayerControlledObject() as PlayerPuppet);
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
  FootwearHooksHelper.NotifyMenuClosed(this.GetPlayerControlledObject() as PlayerPuppet);
  return result;
}

/**
 * Hooks closing of wardrobe screen to re-sync footwear state immediately upon exit.
 *
 * @return Wrapped callback return value.
 */
@wrapMethod(WardrobeSetPreviewGameController)
protected cb func OnUninitialize() -> Bool {
  let result: Bool = wrappedMethod();
  FootwearHooksHelper.NotifyMenuClosed(this.GetPlayerControlledObject() as PlayerPuppet);
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
    return result;
  };
  FootwearRedLogger.LogInfo("WORKSPOT", "OnWorkspotStartedEvent: Workspot activated (chair/vending machine/furniture) | Action: Setting workspot state to TRUE and evaluating elevation suppression");
  FootwearHooksHelper.NotifyWorkspotState(this, true);
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
    return result;
  };
  FootwearRedLogger.LogInfo("WORKSPOT", "OnWorkspotFinishedEvent: Workspot finished (standing/exited) | Action: Setting workspot state to FALSE and restoring footwear elevation");
  FootwearHooksHelper.NotifyWorkspotState(this, false);
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
    return result;
  };
  FootwearRedLogger.LogInfo("VEHICLE", "OnMountingEvent: Vehicle mounted | Action: Setting vehicle state to TRUE and evaluating elevation suppression");
  FootwearHooksHelper.NotifyVehicleState(this, true);
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
    return result;
  };
  FootwearRedLogger.LogInfo("VEHICLE", "OnUnmountingEvent: Vehicle unmounted | Action: Setting vehicle state to FALSE and restoring footwear elevation");
  FootwearHooksHelper.NotifyVehicleState(this, false);
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
  let actionName: CName = ListenerAction.GetName(action);
  let gi: GameInstance = this.GetGame();

  if FootwearCalibratorHost.IsCameraInputBlocked(gi) && (FootwearHooksHelper.IsCameraPerspectiveAction(actionName) || FootwearHooksHelper.IsWeaponAction(actionName)) {
    ListenerActionConsumer.Consume(consumer);
    ListenerActionConsumer.DontSendReleaseEvent(consumer);
    return false;
  };

  if (Equals(actionName, n"ToggleCrouch") || Equals(actionName, n"Crouch")) && FootwearCalibratorHost.ShouldConsumeUnlockCrouch(gi) {
    ListenerActionConsumer.Consume(consumer);
    ListenerActionConsumer.DontSendReleaseEvent(consumer);
    return false;
  };

  if Equals(actionName, n"QuickMelee") && FootwearCalibratorHost.ShouldConsumeUnlockQuickMelee(gi) {
    ListenerActionConsumer.Consume(consumer);
    ListenerActionConsumer.DontSendReleaseEvent(consumer);
    return false;
  };

  let result: Bool = wrappedMethod(action, consumer);
  if !ListenerAction.IsButtonJustPressed(action) {
    return result;
  };
  if FootwearHooksHelper.IsWeaponAction(actionName) {
    FootwearHooksHelper.NotifyWeaponAction(this, NameToString(actionName));
    return result;
  };
  if FootwearHooksHelper.IsCameraPerspectiveAction(actionName) {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(sys) {
      return result;
    };
    sys.CheckPerspectiveDrift(this);
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
  if !IsDefined(evt) {
    return result;
  };
  let slotID: TweakDBID = evt.GetSlotID();
  if Equals(slotID, t"AttachmentSlots.WeaponRight") || Equals(slotID, t"AttachmentSlots.WeaponLeft") {
    FootwearHooksHelper.NotifyWeaponAction(this, "WeaponEquippedToSlot");
  } else if Equals(slotID, t"AttachmentSlots.Feet") || Equals(slotID, t"OutfitSlots.Feet") {
    FootwearHooksHelper.NotifyFootwearChanged(this, false);
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
  if !IsDefined(evt) {
    return result;
  };
  let slotID: TweakDBID = evt.GetSlotID();
  if Equals(slotID, t"AttachmentSlots.WeaponRight") || Equals(slotID, t"AttachmentSlots.WeaponLeft") {
    FootwearHooksHelper.NotifyWeaponAction(this, "WeaponRemovedFromSlot");
  } else if Equals(slotID, t"AttachmentSlots.Feet") || Equals(slotID, t"OutfitSlots.Feet") {
    FootwearHooksHelper.NotifyFootwearChanged(this, false);
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
  if !IsDefined(scriptInterface) {
    return;
  };
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if !IsDefined(player) || !player.IsAttached() || player.IsDead() {
    return;
  };
  let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
  if !IsDefined(sys) {
    return;
  };
  sys.OnLocomotionUpdate(player, timeDelta);
}
