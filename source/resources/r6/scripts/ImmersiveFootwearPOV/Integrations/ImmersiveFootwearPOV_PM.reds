module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Photo Mode (PM) Native Integration
// Hooks Photo Mode menu lifecycle to manage elevation and suppression state
// =============================================================================

@addMethod(gameuiPhotoModeMenuController)
public func ApplyFootwearElevation() -> Void {
  let obj: ref<GameObject> = this.GetPlayerControlledObject();
  if IsDefined(obj) {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(obj.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        let platMeters: Float = sys.GetCurrentPlatformHeight();
        if platMeters > 0.0 {
          let clampedElevation: Float = ShoeHeightParser.ClampPlatformHeight(platMeters);
          this.OnForceAttributeVaulue(37u, clampedElevation, true);
        };
      };
    };
  };
}

@wrapMethod(gameuiPhotoModeMenuController)
protected cb func OnShow() -> Bool {
  let result: Bool = wrappedMethod();
  let obj: ref<GameObject> = this.GetPlayerControlledObject();
  if IsDefined(obj) {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(obj.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        sys.SetPhotoModeActive(true);
        sys.UpdateEquippedFootwear(player);
        this.ApplyFootwearElevation();
      };
    };
  };
  return result;
}

@wrapMethod(gameuiPhotoModeMenuController)
protected cb func OnHide() -> Bool {
  let result: Bool = wrappedMethod();
  let obj: ref<GameObject> = this.GetPlayerControlledObject();
  if IsDefined(obj) {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(obj.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        sys.SetPhotoModeActive(false);
        sys.RecalculateEffectiveOffset(player);
      };
    };
  };
  return result;
}

@wrapMethod(gameuiPhotoModeMenuController)
protected cb func OnEquipWardrobeSet(setIndex: Int32) -> Bool {
  let result: Bool = wrappedMethod(setIndex);
  let obj: ref<GameObject> = this.GetPlayerControlledObject();
  if IsDefined(obj) {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(obj.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
      if IsDefined(sys) {
        sys.UpdateEquippedFootwear(player);
        this.ApplyFootwearElevation();
      };
    };
  };
  return result;
}
