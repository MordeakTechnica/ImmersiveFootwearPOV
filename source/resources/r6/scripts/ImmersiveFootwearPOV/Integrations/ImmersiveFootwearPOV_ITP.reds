module ImmersiveFootwearPOV

@if(ModuleExists("ImmersiveThirdPerson"))
import ImmersiveThirdPerson.*

// =============================================================================
// Immersive Footwear POV - Immersive Third Person (ITP) Integration
// Real-time Third-Person Character Elevation Driver
// Primary: Custom animgraph variable 'foot_elevation_offset' (skeletal Root/Hips lift)
//          Keeps visible meshes, deformations, and shadow_rig synchronized in skeletal space.
// =============================================================================

public class ITPController {

  /**
   * Sets dynamic vertical elevation on the player puppet for third-person perspective
   * via the skeletal animgraph variable 'foot_elevation_offset'.
   * Driving elevation in skeletal space keeps n"root", attached skinned meshes (RT/PT self-cast shadows),
   * and shadow_rig synchronized without component SetLocalPosition desync.
   * @param player The local player puppet reference.
   * @param offsetMeters Elevation offset in meters (e.g. +0.085 for 8.5cm high platforms).
   * @return True if offset was successfully applied, false if player undefined.
   */
  public static func ApplyHeightOffset(player: ref<PlayerPuppet>, offsetMeters: Float) -> Bool {
    if !IsDefined(player) || !player.IsAttached() || player.IsDead() {
      return false;
    };
    let reqHandler: ref<inkISystemRequestsHandler> = GameInstance.GetSystemRequestsHandler();
    if IsDefined(reqHandler) && reqHandler.IsPreGame() {
      return false;
    };

    let gi: GameInstance = player.GetGame();
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    let clampedOffset: Float = ShoeHeightParser.ClampPlatformHeight(offsetMeters);
    if (clampedOffset - clampedOffset) != 0.0 {
      clampedOffset = 0.0;
    };

    // Note: We deliberately do NOT set 'ifp_height_blend' here.
    // FPP heel height is managed by HeightController. Setting it here would clobber FPP stance upon ITP reset.
    AnimationControllerComponent.SetInputFloat(player, n"foot_elevation_offset", clampedOffset);
    AnimationControllerComponent.SetInputFloat(player, n"shadow_platform_offset", 0.0);
    ITPController.SyncShadowProxyForTPP(player, clampedOffset > 0.00005);

    if IsDefined(sys) {
      sys.LogITPElevationIfChanged(clampedOffset, false, 0);
    };
    return true;
  }

  /**
   * Suppresses redundant player shadow proxy meshes during elevated TPP so they cannot
   * overlap V's lifted visible meshes and cast self-shadow patches onto V's body or clothes.
   * Restores default shadow casting and visibility when returning to FPP or 0.0m elevation.
   */
  public static func SyncShadowProxyForTPP(player: ref<PlayerPuppet>, suppressShadowProxy: Bool) -> Void {
    if !IsDefined(player) || !player.IsAttached() {
      return;
    };
    let targetEnabled: Bool = !suppressShadowProxy;
    let targetMode: shadowsShadowCastingMode = suppressShadowProxy ? shadowsShadowCastingMode.Never : shadowsShadowCastingMode.Default;
    let components: array<ref<IComponent>> = player.GetComponents();
    let i: Int32 = 0;
    let count: Int32 = ArraySize(components);
    while i < count {
      let comp: ref<IComponent> = components[i];
      if IsDefined(comp) {
        let compName: String = StrLower(NameToString(comp.GetName()));
        if StrContains(compName, "shadow") {
          let morph: ref<entMorphTargetSkinnedMeshComponent> = comp as entMorphTargetSkinnedMeshComponent;
          if IsDefined(morph) {
            let changed: Bool = false;
            if !Equals(morph.castShadows, targetMode) {
              morph.castShadows = targetMode;
              changed = true;
            };
            if !Equals(morph.castLocalShadows, targetMode) {
              morph.castLocalShadows = targetMode;
              changed = true;
            };
            if !Equals(morph.isEnabled, targetEnabled) {
              morph.Toggle(targetEnabled);
              changed = true;
            };
            if changed {
              morph.RefreshAppearance();
            };
          } else {
            let skinned: ref<entSkinnedMeshComponent> = comp as entSkinnedMeshComponent;
            if IsDefined(skinned) {
              let changed: Bool = false;
              if !Equals(skinned.castShadows, targetMode) {
                skinned.castShadows = targetMode;
                changed = true;
              };
              if !Equals(skinned.castLocalShadows, targetMode) {
                skinned.castLocalShadows = targetMode;
                changed = true;
              };
              if !Equals(skinned.isEnabled, targetEnabled) {
                skinned.Toggle(targetEnabled);
                changed = true;
              };
              if changed {
                skinned.RefreshAppearance();
              };
            };
          };
        };
      };
      i += 1;
    };
  }

  /**
   * Resets character model third-person elevation back to baseline (0.0m).
   * @param player The local player puppet reference.
   */
  public static func ResetHeightOffset(player: ref<PlayerPuppet>) -> Void {
    ITPController.ApplyHeightOffset(player, 0.0);
  }

  /**
   * Checks if Immersive Third Person (ITP) or compatible TPP bridges are active in the running game instance.
   * @param gameInstance The active GameInstance.
   * @return True if ITP scriptable systems or tppCamera component are present.
   */
  public static func IsITPPresent(gameInstance: GameInstance) -> Bool {
    let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(gameInstance);
    if IsDefined(container) {
      let itpBridge: ref<ScriptableSystem> = container.Get(n"TPPCameraVisibleRenderBridge");
      if IsDefined(itpBridge) {
        return true;
      };
      let itpApi: ref<ScriptableSystem> = container.Get(n"ImmersiveThirdPerson.ITPApi");
      if IsDefined(itpApi) {
        return true;
      };
      let itpGround: ref<ScriptableSystem> = container.Get(n"TPPCameraGroundLevel");
      if IsDefined(itpGround) {
        return true;
      };
    };
    let reqHandler: ref<inkISystemRequestsHandler> = GameInstance.GetSystemRequestsHandler();
    if IsDefined(reqHandler) && reqHandler.IsPreGame() {
      return false;
    };
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gameInstance).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) && player.IsAttached() && IsDefined(player.FindComponentByName(n"tppCamera")) {
      return true;
    };
    return false;
  }

  /**
   * Checks if third-person camera is currently active and rendering based on camera distance from player.
   * Employs dual-threshold hysteresis to eliminate perspective flapping during locomotion head bob, crouch, or stairs.
   *
   * @param player The local player puppet reference.
   * @param currentTppState Optional current perspective state to apply hysteresis against.
   * @return True if active camera transform indicates third-person perspective.
   */
  public static func IsTPPActive(player: ref<PlayerPuppet>, opt currentTppState: Bool) -> Bool {
    if !IsDefined(player) {
      return false;
    };
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
    let isITPPresent: Bool = IsDefined(sys) ? sys.IsITPPresent() : ITPDetector.IsPresent(player.GetGame());
    if !isITPPresent {
      return false;
    };
    if FootwearCalibratorCamera.IsCalibratorCamActive(player.GetGame()) {
      return true;
    };
    let camSys: ref<CameraSystem> = GameInstance.GetCameraSystem(player.GetGame());
    if !IsDefined(camSys) {
      return false;
    };
    let camXf: Transform;
    if !camSys.GetActiveCameraWorldTransform(camXf) {
      return false;
    };
    let camPos: Vector4 = Transform.GetPosition(camXf);
    let basePos: Vector4 = player.GetWorldPosition();
    let eyeZBaseline: Float = 1.55; // Standard player eye level above root Z (meters)
    let eyeZ: Float = basePos.Z + eyeZBaseline;
    let dx: Float = camPos.X - basePos.X;
    let dy: Float = camPos.Y - basePos.Y;
    let dz: Float = camPos.Z - eyeZ;
    let distSq: Float = dx * dx + dy * dy + dz * dz;

    // Hysteresis thresholds to eliminate perspective flapping:
    // When currently in TPP, camera must move close (< 0.80m, distSq < 0.64) to transition back to FPP.
    // When currently in FPP, camera must separate significantly (> 1.41m, distSq > 2.00) to transition to TPP.
    if currentTppState {
      return distSq >= 0.64;
    };
    return distSq > 2.0;
  }

  /**
   * Maintains an active third-person lease, optional boot-focus framing, and ground-level
   * elevation lease in Immersive Third Person while the calibrator UI is open.
   */
  public static func MaintainCalibratorTPPLease(gi: GameInstance, focusBoots: Bool) -> Void {
    ITPApiCalibratorAdapter.MaintainLease(gi, focusBoots);
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(sys) && IsDefined(player) {
      sys.CheckPerspectiveDrift(player);
      sys.RenewTPPElevationLease(player);
    };
  }

  /**
   * Releases calibrator camera and perspective leases in Immersive Third Person.
   */
  public static func ReleaseCalibratorTPPLease(gi: GameInstance) -> Void {
    ITPApiCalibratorAdapter.ReleaseLease(gi);
  }
}

@if(ModuleExists("ImmersiveThirdPerson"))
public class ITPApiCalibratorAdapter {
  public static func MaintainLease(gi: GameInstance, focusBoots: Bool) -> Void {
    let api: ref<ITPApi> = ITPApi.Get(gi);
    if !IsDefined(api) {
      return;
    };
    let owner: CName = n"ImmersiveFootwearPOV";
    api.KeepThirdPerson(owner, 100, 1.0);
    if focusBoots {
      // Frame boots at ankle/calf height (0.50m minimum valid ITPApi height) centered in the open right viewport
      api.RequestFraming(owner, 100, 1.0, 15, 1.00, 0.50, -0.22, 50.0, 0.25);
    } else {
      api.Release(owner, n"camera");
    };
  }

  public static func ReleaseGroundLease(gi: GameInstance) -> Void {
    let api: ref<ITPApi> = ITPApi.Get(gi);
    if !IsDefined(api) {
      return;
    };
    api.Release(n"ImmersiveFootwearPOV", n"groundLevel");
  }

  public static func ReleaseLease(gi: GameInstance) -> Void {
    let api: ref<ITPApi> = ITPApi.Get(gi);
    if !IsDefined(api) {
      return;
    };
    let owner: CName = n"ImmersiveFootwearPOV";
    api.Release(owner, n"camera");
    api.Release(owner, n"perspective");
    api.Release(owner, n"groundLevel");
  }
}

@if(!ModuleExists("ImmersiveThirdPerson"))
public class ITPApiCalibratorAdapter {
  public static func MaintainLease(gi: GameInstance, focusBoots: Bool) -> Void {}
  public static func ReleaseGroundLease(gi: GameInstance) -> Void {}
  public static func ReleaseLease(gi: GameInstance) -> Void {}
}
