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
      return false;
    };

    // Clamp within declared animgraph variable bounds (-0.50m to +0.50m)
    let clampedOffset: Float = ClampF(offsetMeters, -0.50, 0.50);

    // Native REDengine API queues AnimInputSetterFloat directly into active animgraph
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
      return IsDefined(itpBridge);
    };
    return false;
  }
}
