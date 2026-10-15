module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Lifecycle & State Event Hooks
// Listens to outfit changes, wardrobe resets, workspots, and vehicle events
// =============================================================================

public class FootwearHooksHelper {
  public static func NotifyFootwearChanged(player: ref<PlayerPuppet>) -> Void {
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        sys.UpdateEquippedFootwear(player);
      };
    };
  }

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

  public static func NotifyWeaponAction(player: ref<PlayerPuppet>, actionName: String) -> Void {
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        sys.OnWeaponAction(player, actionName);
      };
    };
  }


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
@wrapMethod(EquipmentSystemPlayerData)
private final func ResetItemAppearance(area: gamedataEquipmentArea, opt force: Bool) -> Void {
  wrappedMethod(area, force);
  if Equals(area, gamedataEquipmentArea.Feet) {
    FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet);
  };
}

@wrapMethod(EquipmentSystemPlayerData)
private final func ClearItemAppearanceEvent(area: gamedataEquipmentArea) -> Void {
  wrappedMethod(area);
  if Equals(area, gamedataEquipmentArea.Feet) {
    FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet);
  };
}

@wrapMethod(EquipmentSystemPlayerData)
private final func ResetItemAppearanceEvent(area: gamedataEquipmentArea) -> Void {
  wrappedMethod(area);
  if Equals(area, gamedataEquipmentArea.Feet) {
    FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet);
  };
}

@wrapMethod(EquipmentSystemPlayerData)
public final func OnRestored() -> Void {
  wrappedMethod();
  FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet);
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  FootwearHooksHelper.NotifyFootwearChanged(this);
  return result;
}

// -----------------------------------------------------------------------------
// In-Game Menu & Wardrobe UI Closing Hooks
// -----------------------------------------------------------------------------
@wrapMethod(gameuiInGameMenuGameController)
protected cb func OnUninitialize() -> Bool {
  let result: Bool = wrappedMethod();
  FootwearHooksHelper.NotifyFootwearChanged(this.GetPlayerControlledObject() as PlayerPuppet);
  return result;
}

@wrapMethod(gameuiInventoryGameController)
protected cb func OnUninitialize() -> Bool {
  let result: Bool = wrappedMethod();
  FootwearHooksHelper.NotifyFootwearChanged(this.GetPlayerControlledObject() as PlayerPuppet);
  return result;
}



// -----------------------------------------------------------------------------
// Workspot (Furniture, Sitting, Sleeping, Workstations) Lifecycle Hooks
// -----------------------------------------------------------------------------
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
@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
  let result: Bool = wrappedMethod(action, consumer);
  let actionName: CName = ListenerAction.GetName(action);
  if FootwearHooksHelper.IsWeaponAction(actionName) && ListenerAction.IsButtonJustPressed(action) {
    FootwearHooksHelper.NotifyWeaponAction(this, NameToString(actionName));
  };
  return result;
}

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
@wrapMethod(LocomotionEventsTransition)
protected func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(timeDelta, stateContext, scriptInterface);
  let player: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
  if IsDefined(player) {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
    if IsDefined(sys) {
      let cfg: ref<FootwearConfig> = sys.GetConfig();
      if IsDefined(cfg) && cfg.enableHipSway {
        sys.UpdateStride(player, timeDelta, cfg.enableHipSway, cfg.swayLow, cfg.swayMid, cfg.swayHigh, false);
      };
    };
  };
}
