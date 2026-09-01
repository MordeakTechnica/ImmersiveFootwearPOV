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
        TFPHelper.LogState(player);
      };
    };
  }

  public static func NotifyWorkspotState(player: ref<PlayerPuppet>, inWorkspot: Bool) -> Void {
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        sys.SetWorkspotState(player, inWorkspot);
        TFPHelper.LogEvent(player.GetGame(), inWorkspot ? "WorkspotStarted (Sitting/Furniture)" : "WorkspotFinished (Standing/Exited)", 0.0, 0.0);
        TFPHelper.LogState(player);
      };
    };
  }

  public static func NotifyVehicleState(player: ref<PlayerPuppet>, inVehicle: Bool) -> Void {
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        sys.SetVehicleState(player, inVehicle);
        TFPHelper.LogEvent(player.GetGame(), inVehicle ? "VehicleEntered (Vehicle Occupancy)" : "VehicleExited (Restored)", 0.0, 0.0);
        TFPHelper.LogState(player);
      };
    };
  }

  public static func NotifyWeaponAction(player: ref<PlayerPuppet>, actionName: String) -> Void {
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        TFPHelper.SyncWeaponForCurrentFootwear(player.GetGame());
        TFPHelper.LogEvent(player.GetGame(), "WeaponAction (" + actionName + ")", 0.0, 0.0);
        TFPHelper.LogState(player);
      };
    };
  }
}

// -----------------------------------------------------------------------------
// Equipment & Appearance Change Hooks
// -----------------------------------------------------------------------------
@wrapMethod(EquipmentSystemPlayerData)
private final func ResetItemAppearance(area: gamedataEquipmentArea, opt force: Bool) -> Void {
  wrappedMethod(area, force);
  FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet);
}

@wrapMethod(EquipmentSystemPlayerData)
private final func ClearItemAppearanceEvent(area: gamedataEquipmentArea) -> Void {
  wrappedMethod(area);
  FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet);
}

@wrapMethod(EquipmentSystemPlayerData)
private final func ResetItemAppearanceEvent(area: gamedataEquipmentArea) -> Void {
  wrappedMethod(area);
  FootwearHooksHelper.NotifyFootwearChanged(this.m_owner as PlayerPuppet);
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
  FootwearHooksHelper.NotifyWorkspotState(this, true);
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnWorkspotFinishedEvent(evt: ref<WorkspotFinishedEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  FootwearHooksHelper.NotifyWorkspotState(this, false);
  return result;
}

// -----------------------------------------------------------------------------
// Vehicle Mounting Lifecycle Hooks
// -----------------------------------------------------------------------------
@wrapMethod(PlayerPuppet)
protected cb func OnMountingEvent(evt: ref<MountingEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  FootwearHooksHelper.NotifyVehicleState(this, true);
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnUnmountingEvent(evt: ref<UnmountingEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  FootwearHooksHelper.NotifyVehicleState(this, false);
  return result;
}

// -----------------------------------------------------------------------------
// Weapon Draw / Holster / Weapon Wheel Actions Hook
// -----------------------------------------------------------------------------
@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
  let result: Bool = wrappedMethod(action, consumer);
  let actionName: CName = ListenerAction.GetName(action);
  if Equals(actionName, n"DrawItem")
     || Equals(actionName, n"DrawWeapon")
     || Equals(actionName, n"HolsterWeapon")
     || Equals(actionName, n"SwitchWeapon")
     || Equals(actionName, n"WeaponWheel")
     || Equals(actionName, n"WeaponSlot1")
     || Equals(actionName, n"WeaponSlot2")
     || Equals(actionName, n"WeaponSlot3")
     || Equals(actionName, n"WeaponSlot4") {
    if ListenerAction.IsButtonJustPressed(action) {
      FootwearHooksHelper.NotifyWeaponAction(this, NameToString(actionName));
    };
  };
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToSlot(evt: ref<ItemAddedToSlot>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let slotID: TweakDBID = evt.GetSlotID();
  if Equals(slotID, t"AttachmentSlots.WeaponRight") || Equals(slotID, t"AttachmentSlots.WeaponLeft") {
    FootwearHooksHelper.NotifyWeaponAction(this, "WeaponEquippedToSlot");
  };
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnItemRemovedFromSlot(evt: ref<ItemRemovedFromSlot>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let slotID: TweakDBID = evt.GetSlotID();
  if Equals(slotID, t"AttachmentSlots.WeaponRight") || Equals(slotID, t"AttachmentSlots.WeaponLeft") {
    FootwearHooksHelper.NotifyWeaponAction(this, "WeaponRemovedFromSlot");
  };
  return result;
}
