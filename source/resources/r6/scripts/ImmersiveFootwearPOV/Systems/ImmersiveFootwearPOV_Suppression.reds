module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Suppression Evaluator
// Context-aware suppression for vehicles, workspots, scenes, ladders, swimming
// =============================================================================

public class SuppressionEvaluator {

  // Evaluates all suppression contexts (vehicles, workspots, high scene tiers, traversal states)
  public static func Evaluate(sys: ref<ImmersiveFootwearPOVSystem>, player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) || !IsDefined(sys) {
      return false;
    };

    // 1. Vehicles
    let isMounted: Bool = VehicleComponent.IsMountedToVehicle(player.GetGame(), player);
    if !isMounted && sys.IsInVehicle() {
      sys.ClearVehicleState(player);
    };
    if sys.IsInVehicle() {
      return sys.SetSuppressionState(true, "Vehicle Occupancy");
    };

    // 2. Workspots / Furniture (sitting on chairs, barstools, sofas, beds)
    let inWorkspotSys: Bool = GameInstance.GetWorkspotSystem(player.GetGame()).IsActorInWorkspot(player);
    if !inWorkspotSys && sys.IsInWorkspot() {
      sys.ClearWorkspotState(player);
    };
    if sys.IsInWorkspot() {
      return sys.SetSuppressionState(true, "Authored Workspot");
    };

    let psmBlackboard: ref<IBlackboard> = player.GetPlayerStateMachineBlackboard();
    if !IsDefined(psmBlackboard) {
      return sys.SetSuppressionState(false, "");
    };

    let psmDefs: ref<PlayerStateMachineDef> = GetAllBlackboardDefs().PlayerStateMachine;

    // 3. Scripted Quest Scenes & High Dialogue Tiers (Tier >= 3 or <= 0)
    let sceneTier: Int32 = psmBlackboard.GetInt(psmDefs.SceneTier);
    if sceneTier >= 3 || sceneTier <= 0 {
      return sys.SetSuppressionState(true, "Scripted Scene / Dialogue");
    };

    // 4. Locomotion Traversal & Special Actions (Climb, Vault, Ladder, Knockdown)
    let detailedLoco: Int32 = psmBlackboard.GetInt(psmDefs.LocomotionDetailed);
    if detailedLoco >= 8 && detailedLoco <= 13 {
      return sys.SetSuppressionState(true, "Climb, Vault, or Ladder");
    };
    if detailedLoco == 29 || detailedLoco == 31 {
      return sys.SetSuppressionState(true, "Knockdown or Forced Reaction");
    };

    // 5. Swimming
    let highLevel: Int32 = psmBlackboard.GetInt(psmDefs.HighLevel);
    let swimmingState: Int32 = psmBlackboard.GetInt(psmDefs.Swimming);
    if highLevel == 6 || swimmingState > 0 {
      return sys.SetSuppressionState(true, "Swimming");
    };

    // 6. Combat / Action Locks (Takedown, Body Carrying)
    if psmBlackboard.GetInt(psmDefs.Takedown) > 0 {
      return sys.SetSuppressionState(true, "Takedown or Grapple");
    };
    if psmBlackboard.GetInt(psmDefs.BodyCarrying) > 0 {
      return sys.SetSuppressionState(true, "Body Carrying");
    };

    // No suppression active
    return sys.SetSuppressionState(false, "");
  }
}

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

  public static func Create(canSway: Bool, heelScale: Float, reason: String, speed: Float, opt pitchCm: Float) -> ref<SwayContextData> {
    let data: ref<SwayContextData> = new SwayContextData();
    data.canSway = canSway;
    data.heelScale = heelScale;
    data.suppressionReason = reason;
    data.speed = speed;
    data.heelPitchCm = pitchCm;
    return data;
  }
}

public class SwayEvaluator {

  // -----------------------------------------------------------------------------
  // Calculates Biomechanical Catwalk Sway Scale (0.00x - 1.00x)
  // Based on real-world gait kinematics & ankle plantarflexion benchmarks:
  // - < 2.0 cm (< 0.8"): Flat / Platform (0% sway - neutral gait)
  // - 1.0" (~2.54 cm): Low / Kitten Heel (~35% sway - subtle sway)
  // - 2.0" (~5.08 cm): Mid Heel (~70% sway - moderate sway)
  // - >= 3.0" (7.50 cm): High Heel / Stiletto (100% max sway)
  // -----------------------------------------------------------------------------
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

  public static func Evaluate(sys: ref<ImmersiveFootwearPOVSystem>, player: ref<PlayerPuppet>) -> ref<SwayContextData> {
    if !IsDefined(player) || !IsDefined(sys) {
      return SwayContextData.Create(false, 0.0, "No Player", 0.0);
    };

    // 1. Catwalk locomotion strictly requires Immersive Third Person (ITP) installed
    let isITPInstalled: Bool = sys.IsITPPresent() || ITPController.IsITPPresent(player.GetGame());
    if !isITPInstalled {
      return SwayContextData.Create(false, 0.0, "Requires Immersive Third Person (ITP)", 0.0);
    };

    // 2. Catwalk locomotion is 3rd-person only; suppressed while in First-Person Perspective (FPP)
    let isTPPActive: Bool = ITPController.IsTPPActive(player);
    if !isTPPActive {
      return SwayContextData.Create(false, 0.0, "First Person Active (ITP 3rd-Person Only)", 0.0);
    };

    // 3. Global context-aware suppression (vehicles, workspots, scenes, ladders, photo mode)
    if sys.IsSuppressed() || sys.IsPhotoModeActive() {
      let reason: String = sys.GetSuppressionReason();
      if StrLen(reason) == 0 {
        reason = "Suppressed";
      };
      return SwayContextData.Create(false, 0.0, reason, 0.0);
    };

    // 4. Movement velocity threshold
    let vel: Vector4 = player.GetVelocity();
    let speed: Float = SqrtF(vel.X * vel.X + vel.Y * vel.Y);
    if speed < 0.15 {
      return SwayContextData.Create(false, 0.0, "Standing Still", speed);
    };

    // 5. Player State Machine blackboard checks (crouch, sprint, jump, slide, dodge, climb, ADS)
    let psmBlackboard: ref<IBlackboard> = player.GetPlayerStateMachineBlackboard();
    if IsDefined(psmBlackboard) {
      let psmDefs: ref<PlayerStateMachineDef> = GetAllBlackboardDefs().PlayerStateMachine;
      if IsDefined(psmDefs) {
        let loco: Int32 = psmBlackboard.GetInt(psmDefs.Locomotion);
        if loco == 1 {
          return SwayContextData.Create(false, 0.0, "Crouching", speed);
        };
        if loco == 2 || speed > 5.50 {
          return SwayContextData.Create(false, 0.0, "Sprinting", speed);
        };
        if loco == 3 {
          return SwayContextData.Create(false, 0.0, "Airborne / Jumping", speed);
        };

        let detailedLoco: Int32 = psmBlackboard.GetInt(psmDefs.LocomotionDetailed);
        if detailedLoco == 5 || detailedLoco == 6 {
          return SwayContextData.Create(false, 0.0, "Dodging / Sliding", speed);
        };
        if detailedLoco >= 8 && detailedLoco <= 13 {
          return SwayContextData.Create(false, 0.0, "Climbing / Vaulting", speed);
        };

        let weapon: Int32 = psmBlackboard.GetInt(psmDefs.Weapon);
        if weapon == 2 {
          return SwayContextData.Create(false, 0.0, "Aiming Weapon", speed);
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
        return SwayContextData.Create(false, 0.0, "Neutral Stride (Flat Platform / No Incline)", speed, pitchCm);
      };
      return SwayContextData.Create(false, 0.0, "Neutral Stride (Flat Footwear / <2 cm)", speed, pitchCm);
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

    return SwayContextData.Create(true, heelScale, gaitDesc, speed, pitchCm);
  }
}
