module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Negotiable Third Person (NTP) Native Integration
// Public integration helper for Negotiable Third Person (NTP) workspots.
// Automatically calculates elevation offset based on V's active footwear.
// =============================================================================

@if(ModuleExists("NegotiableThirdPerson"))
import NegotiableThirdPerson.*

@if(ModuleExists("NegotiableThirdPerson"))
public class NTPFootwearHelper {

  /**
   * Checks whether the workspot is a standing or dancing animation that requires foot elevation.
   * Excludes sitting on ground, couches, chairs, beds, and kneeling animations.
   * @param path The workspot resource reference.
   * @return True if the animation is a standing or dancing idle.
   */
  public static func IsStandingWorkspot(path: ResRef) -> Bool {
    let pathStr: String = ResRef.ToString(path);
    if StrContains(pathStr, "sit") 
        || StrContains(pathStr, "couch") 
        || StrContains(pathStr, "chair") 
        || StrContains(pathStr, "bed") 
        || StrContains(pathStr, "bench") 
        || StrContains(pathStr, "kneel") 
        || StrContains(pathStr, "ground_lean") {
      return false;
    };
    return true;
  }

  /**
   * Returns the clamped vertical elevation in meters for active footwear.
   * Uses platform sole thickness (not heel height) so V's feet rest flush on the floor.
   * @param gi The active GameInstance.
   * @return Elevation offset in meters (0.0 if flat or disabled).
   */
  public static func GetFootwearElevation(gi: GameInstance) -> Float {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(sys) {
      return 0.0;
    };

    let cfg: ref<FootwearConfig> = sys.GetConfig();
    let canElevate: Bool = IsDefined(cfg) ? cfg.autoElevateNTP : true;
    if !canElevate {
      return 0.0;
    };

    let plat: Float = sys.GetCurrentPlatformHeight();
    if plat > 0.005 {
      return FootwearClampingPolicy.ClampPlatformHeight(plat);
    };

    return 0.0;
  }

  /**
   * Inspects footwear platform height and applies vertical Z elevation to an NTP request payload.
   * @param request The active NTP animation request payload.
   * @param gi The active GameInstance.
   */
  public static func ApplyElevationToRequest(request: ref<NTP_AnimationRequest>, gi: GameInstance) -> Void {
    if !IsDefined(request) {
      return;
    };

    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(sys) {
      return;
    };

    if NTPFootwearHelper.IsStandingWorkspot(request.workspotPath) {
      let elevation: Float = NTPFootwearHelper.GetFootwearElevation(gi);
      if elevation > 0.005 {
        sys.SetActiveNtpElevation(elevation);

        if request.useNodeRef {
          request.positionOffset.Z += elevation;
        } else if request.useCustomTransform {
          request.customPosition.Z += elevation;
        } else {
          let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject() as PlayerPuppet;
          if IsDefined(player) {
            let basePos: Vector4 = player.GetWorldPosition();
            let baseRot: EulerAngles = player.GetWorldOrientation().ToEulerAngles();
            request.WithStagedLocation(basePos, baseRot);
            let elevatedPos: Vector4 = new Vector4(basePos.X, basePos.Y, basePos.Z + elevation, 1.0);
            request.WithLocation(elevatedPos, baseRot);
          };
        };

        FootwearRedLogger.LogInfo("NTP", s"Elevating NTP workspot staging by \(elevation * 100.0) cm (platform sole)");
        return;
      };
    };

    sys.SetActiveNtpElevation(0.0);
  }
}


