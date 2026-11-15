module ImmersiveFootwearPOV

@if(ModuleExists("ImmersiveThirdPerson"))
import ImmersiveThirdPerson.*

// =============================================================================
// Immersive Footwear POV - Immersive Third Person (ITP) Integration
// Real-time Third-Person Character Elevation Driver
// Primary: Direct `n"root"` component SetLocalPosition (+1*H across root <- deformations <- shadow)
// Fallback: Custom animgraph variable 'foot_elevation_offset'
// =============================================================================

public class TPPRootElevationTarget {
  private let comp: wref<IPlacedComponent>;
  private let hasBase: Bool;
  private let baseX: Float;
  private let baseY: Float;
  private let baseZ: Float;
  private let baseW: Float;
  private let pendingRestore: Bool;
  private let hasLastAnimState: Bool;
  private let lastAnimUsedRootLift: Bool;
  private let lastAnimOffset: Float;
  private let lastAnimEntityID: EntityID;

  private static func IsFinite(v: Float) -> Bool {
    return (v - v) == 0.0;
  }

  private func Resolve(player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) || !player.IsAttached() || player.IsDead() {
      return false;
    };
    if IsDefined(this.comp) && this.hasBase {
      let compEnt: wref<Entity> = this.comp.GetEntity();
      if IsDefined(compEnt) && Equals(compEnt.GetEntityID(), player.GetEntityID()) {
        return true;
      };
    };
    if this.pendingRestore {
      this.RestoreOffset();
    };
    this.hasBase = false;
    this.pendingRestore = false;
    this.hasLastAnimState = false;
    this.comp = null;
    let component: ref<IComponent> = player.FindComponentByName(n"root");
    if !IsDefined(component) {
      return false;
    };
    let animated: ref<AnimatedComponent> = component as AnimatedComponent;
    let placed: ref<IPlacedComponent> = component as IPlacedComponent;
    if !IsDefined(animated) || !IsDefined(placed) {
      return false;
    };
    let pos: Vector4 = placed.GetLocalPosition();
    if !TPPRootElevationTarget.IsFinite(pos.Z) || AbsF(pos.Z) > 2.0 {
      return false;
    };
    this.baseX = TPPRootElevationTarget.IsFinite(pos.X) ? pos.X : 0.0;
    this.baseY = TPPRootElevationTarget.IsFinite(pos.Y) ? pos.Y : 0.0;
    this.baseZ = pos.Z;
    this.baseW = TPPRootElevationTarget.IsFinite(pos.W) ? pos.W : 1.0;
    this.hasBase = true;
    this.comp = placed;
    return true;
  }

  private func WriteZ(z: Float) -> Bool {
    if !IsDefined(this.comp) || !TPPRootElevationTarget.IsFinite(z) {
      return false;
    };
    let pos: Vector4 = this.comp.GetLocalPosition();
    let x: Float = TPPRootElevationTarget.IsFinite(pos.X) ? pos.X : this.baseX;
    let y: Float = TPPRootElevationTarget.IsFinite(pos.Y) ? pos.Y : this.baseY;
    let w: Float = TPPRootElevationTarget.IsFinite(pos.W) ? pos.W : this.baseW;
    this.comp.SetLocalPosition(new Vector4(x, y, z, w));
    let back: Float = this.comp.GetLocalPosition().Z;
    return TPPRootElevationTarget.IsFinite(back) && AbsF(back - z) <= 0.0001;
  }

  public func ApplyOffset(player: ref<PlayerPuppet>, offsetMeters: Float) -> Bool {
    if !TPPRootElevationTarget.IsFinite(offsetMeters) {
      return false;
    };
    if offsetMeters <= 0.00005 {
      this.RestoreOffset();
      return IsDefined(this.comp) || (IsDefined(player) && IsDefined(player.FindComponentByName(n"root") as IPlacedComponent));
    };
    if !this.Resolve(player) {
      return false;
    };
    let want: Float = this.baseZ + offsetMeters;
    let cur: Float = this.comp.GetLocalPosition().Z;
    if !TPPRootElevationTarget.IsFinite(cur) || AbsF(cur - want) > 0.0001 {
      if !this.WriteZ(want) {
        return false;
      };
    };
    this.pendingRestore = true;
    return true;
  }

  public func SyncAnimInputsIfChanged(player: ref<PlayerPuppet>, usedRootLift: Bool, clampedOffset: Float) -> Void {
    if !IsDefined(player) || !player.IsAttached() {
      return;
    };
    let pid: EntityID = player.GetEntityID();
    if this.hasLastAnimState
      && Equals(this.lastAnimEntityID, pid)
      && Equals(this.lastAnimUsedRootLift, usedRootLift)
      && AbsF(this.lastAnimOffset - clampedOffset) <= 0.0001 {
      return;
    };
    this.hasLastAnimState = true;
    this.lastAnimEntityID = pid;
    this.lastAnimUsedRootLift = usedRootLift;
    this.lastAnimOffset = clampedOffset;
    if usedRootLift {
      // Clear skeletal fallback variable so direct root component elevation owns 100% of the lift.
      AnimationControllerComponent.SetInputFloat(player, n"foot_elevation_offset", 0.0);
      // Counter-shift shadow rig feet/toes back down in Root Z to stay planted on the ground under lifted platform soles.
      AnimationControllerComponent.SetInputFloat(player, n"shadow_platform_offset", clampedOffset);
    } else {
      AnimationControllerComponent.SetInputFloat(player, n"foot_elevation_offset", clampedOffset);
      AnimationControllerComponent.SetInputFloat(player, n"shadow_platform_offset", 0.0);
    };
  }

  public func RestoreOffset() -> Void {
    this.hasLastAnimState = false;
    if !this.pendingRestore {
      return;
    };
    let compEnt: wref<Entity> = IsDefined(this.comp) ? this.comp.GetEntity() : null;
    if IsDefined(this.comp) && this.hasBase && IsDefined(compEnt) && compEnt.IsAttached() {
      let cur: Float = this.comp.GetLocalPosition().Z;
      if !TPPRootElevationTarget.IsFinite(cur) || AbsF(cur - this.baseZ) > 0.0001 {
        if this.WriteZ(this.baseZ) {
          this.pendingRestore = false;
        };
      } else {
        this.pendingRestore = false;
      };
    } else {
      this.pendingRestore = false;
      this.hasBase = false;
      this.comp = null;
    };
  }
}

public class ITPController {

  /**
   * Sets dynamic vertical elevation on the player puppet for third-person perspective.
   * Lifts only `n"root"` so linked `deformations` and `shadow` components inherit the same +1*H lift
   * in lockstep without compounding or self-shadowing, while `shadow_platform_offset` plants the
   * shadow-rig feet back to the floor. Falls back to `foot_elevation_offset` if `root` is missing.
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
    let rootTarget: ref<TPPRootElevationTarget> = IsDefined(sys) ? sys.GetRootElevationTarget() : null;
    let usedRootLift: Bool = IsDefined(rootTarget) && rootTarget.ApplyOffset(player, clampedOffset);

    // Note: We deliberately do NOT set 'ifp_height_blend' here.
    // FPP heel height is managed by HeightController. Setting it here would clobber FPP stance upon ITP reset.
    if IsDefined(rootTarget) {
      rootTarget.SyncAnimInputsIfChanged(player, usedRootLift, clampedOffset);
    } else if usedRootLift {
      // Clear skeletal fallback variable so direct root component elevation owns 100% of the lift.
      AnimationControllerComponent.SetInputFloat(player, n"foot_elevation_offset", 0.0);
      // Counter-shift shadow rig feet/toes back down in Root Z to stay planted on the ground under lifted platform soles.
      AnimationControllerComponent.SetInputFloat(player, n"shadow_platform_offset", clampedOffset);
    } else {
      AnimationControllerComponent.SetInputFloat(player, n"foot_elevation_offset", clampedOffset);
      AnimationControllerComponent.SetInputFloat(player, n"shadow_platform_offset", 0.0);
    };

    if IsDefined(sys) {
      sys.LogITPElevationIfChanged(clampedOffset, usedRootLift, usedRootLift ? 0 : -1);
    };
    return true;
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
