module ImmersiveFootwearPOV

// =============================================================================
// Feminine Locomotion & Catwalk Sway Context
// Authoritative evaluation of locomotion state, velocity, and heel-height scaling
// Enforces ITP (Immersive Third Person) dependency; suppresses sway in FPP
// =============================================================================

public class SwayContextData {
  public let canSway: Bool;
  public let heelScale: Float;
  public let suppressionReason: String;
  public let speed: Float;
  public let heelPitchCm: Float;

  /**
   * Creates a new SwayContextData container.
   * @param canSway True if biomechanical conditions permit hip sway.
   * @param heelScale Normalized intensity scalar (0.0 to 1.0).
   * @param reason Diagnostic explanation or gait description string.
   * @param speed Current planar movement speed in m/s.
   * @param pitchCm Effective heel inclination in cm (heel minus platform).
   * @return A newly initialized SwayContextData instance.
   */
  public static func Create(canSway: Bool, heelScale: Float, reason: String, speed: Float, opt pitchCm: Float) -> ref<SwayContextData> {
    let data: ref<SwayContextData> = new SwayContextData();
    data.Set(canSway, heelScale, reason, speed, pitchCm);
    return data;
  }

  /**
   * Populates fields in an existing SwayContextData instance without allocations.
   * @param canSway True if biomechanical conditions permit hip sway.
   * @param heelScale Normalized intensity scalar (0.0 to 1.0).
   * @param reason Diagnostic explanation or gait description string.
   * @param speed Current planar movement speed in m/s.
   * @param pitchCm Effective heel inclination in cm.
   */
  public func Set(canSway: Bool, heelScale: Float, reason: String, speed: Float, opt pitchCm: Float) -> Void {
    this.canSway = canSway;
    this.heelScale = heelScale;
    this.suppressionReason = reason;
    this.speed = speed;
    this.heelPitchCm = pitchCm;
  }
}

public class SwayEvaluator {

  /**
   * Calculates biomechanical catwalk sway scale factor (0.00x to 1.00x) based on heel pitch:
   * - < 2.0 cm (< 0.8"): Flat / Platform (0% sway - neutral gait)
   * - 1.0" (~2.54 cm): Low / Kitten Heel (~35% sway - subtle sway)
   * - 2.0" (~5.08 cm): Mid Heel (~70% sway - moderate sway)
   * - >= 3.0" (7.50 cm): High Heel / Stiletto (100% max sway)
   * @param pitchCm Effective heel inclination in centimeters.
   * @return Normalized sway multiplier scalar between 0.0 and 1.0.
   */
  public static func CalculateHeelScale(pitchCm: Float) -> Float {
    if pitchCm < 2.0 {
      return 0.0;
    };
    if pitchCm < 2.54 {
      return 0.35 * ((pitchCm - 2.0) / 0.54);
    };
    if pitchCm < 5.08 {
      return 0.35 + 0.35 * ((pitchCm - 2.54) / 2.54);
    };
    if pitchCm < 7.50 {
      return 0.70 + 0.30 * ((pitchCm - 5.08) / 2.42);
    };
    return 1.0;
  }

  /**
   * Convenience evaluator creating and returning a new SwayContextData instance.
   * @param sys Reference to ImmersiveFootwearPOVSystem.
   * @param player Local player puppet reference.
   * @return Populated SwayContextData instance.
   */
  public static func Evaluate(sys: ref<ImmersiveFootwearPOVSystem>, player: ref<PlayerPuppet>) -> ref<SwayContextData> {
    return SwayEvaluator.EvaluateInto(sys, player, new SwayContextData());
  }

  /**
   * Evaluates all sway prerequisites and populates an existing target SwayContextData container.
   * Checks configuration, speed threshold, global suppression, ITP presence, third-person perspective, PSM states, and pitch.
   * @param sys Reference to ImmersiveFootwearPOVSystem.
   * @param player Local player puppet reference.
   * @param target Output container to update.
   * @return The updated target SwayContextData instance.
   */
  public static func EvaluateInto(sys: ref<ImmersiveFootwearPOVSystem>, player: ref<PlayerPuppet>, target: ref<SwayContextData>) -> ref<SwayContextData> {
    if !IsDefined(target) {
      return SwayEvaluator.Evaluate(sys, player);
    };

    if !IsDefined(player) || !IsDefined(sys) {
      target.Set(false, 0.0, "No Player", 0.0);
      return target;
    };

    // Check user config toggle
    if IsDefined(sys.GetConfig()) && !sys.GetConfig().enableHipSway {
      target.Set(false, 0.0, "Disabled in Settings", 0.0);
      return target;
    };

    // 1. Movement velocity threshold (standing still skips all heavier checks)
    let vel: Vector4 = player.GetVelocity();
    let speed: Float = SqrtF(vel.X * vel.X + vel.Y * vel.Y);
    if speed < 0.15 {
      target.Set(false, 0.0, "Standing Still", speed);
      return target;
    };

    // 2. Global context-aware suppression (vehicles, workspots, scenes, ladders, photo mode)
    if sys.IsSuppressed() || sys.IsPhotoModeActive() {
      let reason: String = sys.GetSuppressionReason();
      if StrLen(reason) == 0 {
        reason = "Suppressed";
      };
      target.Set(false, 0.0, reason, speed);
      return target;
    };

    // 3. Catwalk locomotion strictly requires Immersive Third Person (ITP) installed (O(1) cached check)
    let isITPInstalled: Bool = sys.IsITPPresent();
    if !isITPInstalled {
      target.Set(false, 0.0, "Requires Immersive Third Person (ITP)", speed);
      return target;
    };

    // 4. Catwalk locomotion is 3rd-person only; suppressed while in First-Person Perspective (FPP)
    let isTPPActive: Bool = sys.IsTPPActive(player);
    if !isTPPActive {
      target.Set(false, 0.0, "First Person Active (ITP 3rd-Person Only)", speed);
      return target;
    };

    // 5. Player State Machine blackboard checks (crouch, sprint, jump, slide, dodge, climb, ADS)
    let psmBlackboard: ref<IBlackboard> = player.GetPlayerStateMachineBlackboard();
    if IsDefined(psmBlackboard) {
      let psmDefs: ref<PlayerStateMachineDef> = GetAllBlackboardDefs().PlayerStateMachine;
      if IsDefined(psmDefs) {
        let loco: Int32 = psmBlackboard.GetInt(psmDefs.Locomotion);
        if loco == 1 {
          target.Set(false, 0.0, "Crouching", speed);
          return target;
        };
        if loco == 2 || speed > 5.50 {
          target.Set(false, 0.0, "Sprinting", speed);
          return target;
        };
        if loco == 3 {
          target.Set(false, 0.0, "Airborne / Jumping", speed);
          return target;
        };

        let detailedLoco: Int32 = psmBlackboard.GetInt(psmDefs.LocomotionDetailed);
        if detailedLoco == 5 || detailedLoco == 6 {
          target.Set(false, 0.0, "Dodging / Sliding", speed);
          return target;
        };
        if detailedLoco >= 8 && detailedLoco <= 13 {
          target.Set(false, 0.0, "Climbing / Vaulting", speed);
          return target;
        };

        let crosshairState: Int32 = psmBlackboard.GetInt(psmDefs.Crosshair);
        let upperBodyState: Int32 = psmBlackboard.GetInt(psmDefs.UpperBody);
        if crosshairState == EnumInt(gamePSMCrosshairStates.Aim) || upperBodyState == EnumInt(gamePSMUpperBodyStates.Aim) {
          target.Set(false, 0.0, "Aiming Weapon", speed);
          return target;
        };
      };
    };

    // 6. Effective heel pitch / inclination scaling (heel lift relative to platform sole)
    let heelCm: Float = sys.GetCurrentHeelHeight() * 100.0;
    let platCm: Float = sys.GetCurrentPlatformHeight() * 100.0;
    let pitchCm: Float = MaxF(0.0, heelCm - platCm);

    // Barefoot, flat shoes, or pure platforms (no heel incline) produce 0 sway
    if pitchCm < 2.0 {
      if platCm >= 2.0 && pitchCm < 0.5 {
        target.Set(false, 0.0, "Neutral Stride (Flat Platform / No Incline)", speed, pitchCm);
        return target;
      };
      target.Set(false, 0.0, "Neutral Stride (Flat Footwear / <2 cm)", speed, pitchCm);
      return target;
    };

    let heelScale: Float = SwayEvaluator.CalculateHeelScale(pitchCm);
    let gaitDesc: String;
    if pitchCm >= 7.50 {
      gaitDesc = "Catwalk Stride (High Heel 3.0\"+ / Max Sway)";
    } else if pitchCm >= 5.08 {
      gaitDesc = "Catwalk Stride (Mid Heel 2.0\" - 3.0\")";
    } else {
      gaitDesc = "Catwalk Stride (Low Heel 1.0\" - 2.0\")";
    };

    target.Set(true, heelScale, gaitDesc, speed, pitchCm);
    return target;
  }
}
