module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Elevation Output Strategies & Coordinator
// Design Pattern: Strategy Pattern & Actuator Facade
// Single Responsibility Principle (SRP):
// - FppAnimgraphActuator: Handles skeletal elevation in First-Person Perspective (IFP)
// - TppAnimgraphActuator: Handles character elevation in Third-Person Perspective (ITP)
// - TfpCameraActuator: Handles camera and weapon reticle elevation in True First Person (TFP)
// - ElevationActuatorCoordinator: Routes elevation requests to active perspective strategy
// =============================================================================

public abstract class IElevationActuator {
  public func ApplyElevation(player: ref<PlayerPuppet>, heelMeters: Float, platformMeters: Float, isSuppressed: Bool) -> Void {}
  public func ResetElevation(player: ref<PlayerPuppet>) -> Void {}
}

// -----------------------------------------------------------------------------
// Strategy 1: FPP Skeletal Elevation (IFP animgraph blend)
// -----------------------------------------------------------------------------
public class FppAnimgraphActuator extends IElevationActuator {
  public func ApplyElevation(player: ref<PlayerPuppet>, heelMeters: Float, platformMeters: Float, isSuppressed: Bool) -> Void {
    if !IsDefined(player) { return; };
    let effHeel: Float = isSuppressed ? 0.0 : FootwearClampingPolicy.ClampIFPHeight(heelMeters);
    HeightController.ApplyHeightOffset(player, effHeel);
  }

  public func ResetElevation(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) { return; };
    HeightController.ResetHeightOffset(player);
  }
}

// -----------------------------------------------------------------------------
// Strategy 2: TPP Puppet Elevation (ITP foot_elevation_offset)
// -----------------------------------------------------------------------------
public class TppAnimgraphActuator extends IElevationActuator {
  public func ApplyElevation(player: ref<PlayerPuppet>, heelMeters: Float, platformMeters: Float, isSuppressed: Bool) -> Void {
    if !IsDefined(player) { return; };
    let effPlat: Float = isSuppressed ? 0.0 : FootwearClampingPolicy.ClampPlatformHeight(platformMeters);
    ITPController.ApplyHeightOffset(player, effPlat);
  }

  public func ResetElevation(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) { return; };
    ITPController.ResetHeightOffset(player);
  }
}

// -----------------------------------------------------------------------------
// Strategy 3: TFP Camera & Weapon Reticle Alignment (True First Person)
// -----------------------------------------------------------------------------
public class TfpCameraActuator extends IElevationActuator {
  public func ApplyElevation(player: ref<PlayerPuppet>, heelMeters: Float, platformMeters: Float, isSuppressed: Bool) -> Void {
    if !IsDefined(player) { return; };
    TFPHelper.ApplyFootwearHeight(player.GetGame());
  }

  public func ResetElevation(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) { return; };
    TFPHelper.ApplyFootwearHeight(player.GetGame());
  }
}

// -----------------------------------------------------------------------------
// Actuator Facade & Perspective Coordinator
// -----------------------------------------------------------------------------
public class ElevationActuatorCoordinator {
  private let m_fppActuator: ref<FppAnimgraphActuator>;
  private let m_tppActuator: ref<TppAnimgraphActuator>;
  private let m_tfpActuator: ref<TfpCameraActuator>;

  public static func Create() -> ref<ElevationActuatorCoordinator> {
    let coord: ref<ElevationActuatorCoordinator> = new ElevationActuatorCoordinator();
    coord.m_fppActuator = new FppAnimgraphActuator();
    coord.m_tppActuator = new TppAnimgraphActuator();
    coord.m_tfpActuator = new TfpCameraActuator();
    return coord;
  }

  public func Apply(player: ref<PlayerPuppet>, heelMeters: Float, platformMeters: Float, isSuppressed: Bool, config: ref<FootwearConfig>, debugLogging: Bool, suppressionReason: String) -> Void {
    if !IsDefined(player) { return; };

    let isTPP: Bool = ITPController.IsTPPActive(player);

    if isTPP {
      this.m_fppActuator.ResetElevation(player);
      if IsDefined(config) && !config.enableITP {
        this.m_tppActuator.ResetElevation(player);
      } else {
        this.m_tppActuator.ApplyElevation(player, heelMeters, platformMeters, isSuppressed);
      };
      if debugLogging {
        let effPlatCm: Float = (isSuppressed ? 0.0 : platformMeters) * 100.0;
        FootwearRedLogger.LogDebug("VIEW", s"RecalculateEffectiveOffset: TPP Active | Action: Resetting FPP height offset to 0.0m, applying TPP platform offset \(effPlatCm) cm (Suppressed: \(isSuppressed) [\(suppressionReason)])");
      };
    } else {
      if IsDefined(config) && !config.enableFPP {
        this.m_fppActuator.ResetElevation(player);
      } else {
        this.m_fppActuator.ApplyElevation(player, heelMeters, platformMeters, isSuppressed);
      };
      this.m_tfpActuator.ApplyElevation(player, heelMeters, platformMeters, isSuppressed);
      this.m_tppActuator.ResetElevation(player);
      if debugLogging {
        let effHeelCm: Float = (isSuppressed ? 0.0 : FootwearClampingPolicy.ClampIFPHeight(heelMeters)) * 100.0;
        FootwearRedLogger.LogDebug("VIEW", s"RecalculateEffectiveOffset: FPP Active | Action: Applying FPP height offset \(effHeelCm) cm, resetting TPP platform offset to 0.0m (Suppressed: \(isSuppressed) [\(suppressionReason)])");
      };
    };
  }

  public func ResetAll(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) { return; };
    this.m_fppActuator.ResetElevation(player);
    this.m_tppActuator.ResetElevation(player);
    this.m_tfpActuator.ResetElevation(player);
  }
}
