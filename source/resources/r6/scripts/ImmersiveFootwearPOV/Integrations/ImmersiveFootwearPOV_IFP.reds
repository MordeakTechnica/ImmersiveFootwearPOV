module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Immersive First Person (IFP) Integration
// Directly drives the player animgraph two-branch height blend (ifp_height_blend)
// Strictly does NOT modify FPPCameraComponent or camera parameters
// =============================================================================

public class HeightController {

  /**
   * Applies physical platform elevation to V's character model via the IFP animgraph variable 'ifp_height_blend'.
   * Skipped if True First Person is active to prevent double-height elevation conflicts.
   * @param player The local player puppet reference.
   * @param offsetZ Vertical height offset in meters.
   * @return True if blend was successfully applied, false if player undefined or TFP is handling elevation.
   */
  public static func ApplyHeightOffset(player: ref<PlayerPuppet>, offsetZ: Float) -> Bool {
    if !IsDefined(player) {
      FootwearRedLogger.LogError("IFP", "ApplyHeightOffset failed: player is undefined");
      return false;
    };

    // When True First Person is present, camera elevation is handled mathematically by TFP.
    // We skip touching the skeletal animgraph blend to prevent double-height conflicts.
    if FrameworkDetector.IsTFPPresent() {
      return false;
    };

    let clampedOffset: Float = ShoeHeightParser.ClampIFPHeight(offsetZ);
    let blend: Float = FootwearAnimgraphHelper.CalculateHeightBlend(clampedOffset);
    AnimationControllerComponent.SetInputFloat(player, n"ifp_height_blend", blend);
    return true;
  }

  /**
   * Resets V's physical platform elevation back to baseline (0.0m).
   * @param player The local player puppet reference.
   */
  public static func ResetHeightOffset(player: ref<PlayerPuppet>) -> Void {
    HeightController.ApplyHeightOffset(player, 0.0);
  }
}

