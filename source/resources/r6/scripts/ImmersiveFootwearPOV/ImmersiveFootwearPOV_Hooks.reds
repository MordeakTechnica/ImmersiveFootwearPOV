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
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        sys.SetWorkspotState(player, inWorkspot);
      };
    };
  }

  public static func NotifyVehicleState(player: ref<PlayerPuppet>, inVehicle: Bool) -> Void {
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        sys.SetVehicleState(player, inVehicle);
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
