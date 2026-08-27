module ImmersiveFootwearPOV

public class HeightController {

  // Applies physical skeletal height offset directly to V's AnimationControllerComponent
  // Uses REDengine's two-branch animgraph blend ('ifp_height_blend')
  public static func ApplyHeightOffset(player: ref<PlayerPuppet>, offsetZ: Float) -> Void {
    if !IsDefined(player) {
      return;
    };

    let targetBlend: Float = HeightController.CalculateHeightBlend(offsetZ);

    AnimationControllerComponent.SetInputFloat(player, n"ifp_height_blend", targetBlend);
  }

  // Maps physical offset in meters [-0.50m, +0.50m] to normalized animgraph blend [0.0, 1.0]
  // Neutral baseline (0.0m elevation) -> 0.50
  public static func CalculateHeightBlend(offsetZ: Float) -> Float {
    let normalizedBlend: Float = (offsetZ + 0.50) / 1.00;

    if normalizedBlend < 0.0 {
      normalizedBlend = 0.0;
    };
    if normalizedBlend > 1.0 {
      normalizedBlend = 1.0;
    };

    return normalizedBlend;
  }

  public static func PrintBodyOffsetInfo(player: ref<PlayerPuppet>, offsetZ: Float) -> Void {
    // Routine logging silenced for clean console
  }
}
