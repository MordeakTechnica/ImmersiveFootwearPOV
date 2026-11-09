module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Photo Mode (PM) Native Integration
// Hooks Photo Mode menu lifecycle to manage elevation and suppression state
// =============================================================================

/**
 * Injects footwear platform elevation directly into Photo Mode's character Z position attribute (attribute 37u).
 */
@addMethod(gameuiPhotoModeMenuController)
public func ApplyFootwearElevation() -> Void {
  let obj: ref<GameObject> = this.GetPlayerControlledObject();
  if !IsDefined(obj) {
    return;
  };
  let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(obj.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
  if !IsDefined(player) {
    return;
  };
  let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
  if !IsDefined(sys) {
    return;
  };
  let cfg: ref<FootwearConfig> = sys.GetConfig();
  if IsDefined(cfg) && !cfg.autoElevatePM {
    return;
  };
  let platMeters: Float = sys.GetCurrentPlatformHeight();
  if platMeters <= 0.0 {
    return;
  };
  let clampedElevation: Float = ShoeHeightParser.ClampPlatformHeight(platMeters);
  this.OnForceAttributeVaulue(37u, clampedElevation, true);
}

/**
 * Handles Photo Mode activation lifecycle: sets photo mode state in ImmersiveFootwearPOVSystem and applies elevation.
 * @param reversedUI Indicates whether the photo mode menu layout is mirrored.
 * @return Original wrapped execution result.
 */
@wrapMethod(gameuiPhotoModeMenuController)
protected cb func OnShow(reversedUI: Bool) -> Bool {
  let result: Bool = wrappedMethod(reversedUI);
  let obj: ref<GameObject> = this.GetPlayerControlledObject();
  if !IsDefined(obj) {
    return result;
  };
  let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(obj.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
  if !IsDefined(player) {
    return result;
  };
  let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
  if !IsDefined(sys) {
    return result;
  };
  sys.SetPhotoModeActive(true);
  sys.UpdateEquippedFootwear(player);
  this.ApplyFootwearElevation();
  return result;
}

/**
 * Handles Photo Mode deactivation lifecycle: restores normal gameplay state and recalculates camera offsets.
 * @return Original wrapped execution result.
 */
@wrapMethod(gameuiPhotoModeMenuController)
protected cb func OnHide() -> Bool {
  let result: Bool = wrappedMethod();
  let obj: ref<GameObject> = this.GetPlayerControlledObject();
  if !IsDefined(obj) {
    return result;
  };
  let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(obj.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
  if !IsDefined(player) {
    return result;
  };
  let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
  if !IsDefined(sys) {
    return result;
  };
  sys.SetPhotoModeActive(false);
  sys.RecalculateEffectiveOffset(player);
  return result;
}

