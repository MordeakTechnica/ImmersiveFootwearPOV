module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Immersive First Person (IFP) Integration
// Directly drives the player animgraph two-branch height blend (ifp_height_blend)
// Strictly does NOT modify FPPCameraComponent or camera parameters
// =============================================================================

public class HeightController {

  // Applies physical platform elevation to V's character model via IFP animgraph variable
  public static func ApplyHeightOffset(player: ref<PlayerPuppet>, offsetZ: Float) -> Bool {
    if !IsDefined(player) {
      return false;
    };

    // When True First Person is present, camera elevation is handled mathematically by TFP.
    // We skip touching the skeletal animgraph blend to prevent double-height conflicts.
    if FrameworkDetector.IsTFPPresent() {
      return false;
    };

    // Calculate animgraph blend:
    // Range is -50cm (-0.50m) to +50cm (+0.50m)
    // 0.0m offset (flat shoes) -> blend 0.50
    // +0.09m offset (9cm boots) -> blend 0.59
    let blend: Float = (offsetZ + 0.50) / 1.00;
    if blend < 0.0 {
      blend = 0.0;
    };
    if blend > 1.0 {
      blend = 1.0;
    };

    AnimationControllerComponent.SetInputFloat(player, n"ifp_height_blend", blend);
    return true;
  }

  // Resets V's physical platform elevation back to base (0.0m)
  public static func ResetHeightOffset(player: ref<PlayerPuppet>) -> Void {
    HeightController.ApplyHeightOffset(player, 0.0);
  }
}

