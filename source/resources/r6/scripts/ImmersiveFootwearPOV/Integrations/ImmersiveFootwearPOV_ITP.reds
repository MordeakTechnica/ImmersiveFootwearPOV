module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Immersive Third Person (ITP) Integration
// Real-time Third-Person Character Elevation Driver
// Interfaces with the custom animgraph variable 'foot_elevation_offset'
// =============================================================================

public class ITPController {

  /// Sets the dynamic vertical elevation (in meters) on the player puppet for third-person view.
  /// Example: +0.08 for 8cm high heels / platform boots, 0.0 for flat footwear.
  public static func ApplyHeightOffset(player: ref<PlayerPuppet>, offsetMeters: Float) -> Bool {
    if !IsDefined(player) {
      FootwearRedLogger.LogError("ITP", "ApplyHeightOffset failed: player is undefined");
      return false;
    };

    let clampedOffset: Float = ShoeHeightParser.ClampPlatformHeight(offsetMeters);

    // Native REDengine API queues AnimInputSetterFloat directly into active animgraph
    // Note: We deliberately do NOT set 'ifp_height_blend' here. 
    // FPP heel height is managed by HeightController. Setting it here would clobber FPP stance upon ITP reset.
    AnimationControllerComponent.SetInputFloat(player, n"foot_elevation_offset", clampedOffset);
    return true;
  }

  /// Resets character model elevation back to baseline (0.0m)
  public static func ResetHeightOffset(player: ref<PlayerPuppet>) -> Void {
    ITPController.ApplyHeightOffset(player, 0.0);
  }

  /// Checks if Immersive Third Person (ITP) is active in the running game instance
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
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gameInstance).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) && IsDefined(player.FindComponentByName(n"tppCamera")) {
      return true;
    };
    return false;
  }

  /// Checks if third-person camera is currently active and rendering
  public static func IsTPPActive(player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) {
      return false;
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
    let minTppDistSq: Float = 0.64; // Distance threshold squared: (0.8m)^2
    return distSq > minTppDistSq;
  }
}
