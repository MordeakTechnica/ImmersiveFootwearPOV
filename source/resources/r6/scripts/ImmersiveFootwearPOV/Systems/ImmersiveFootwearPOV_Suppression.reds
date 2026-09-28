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
    if sys.IsInVehicle() || VehicleComponent.IsMountedToVehicle(player.GetGame(), player) {
      return sys.SetSuppressionState(true, "Vehicle Occupancy");
    };

    // 2. Workspots / Furniture (sitting on chairs, barstools, sofas, beds)
    if sys.IsInWorkspot() || GameInstance.GetWorkspotSystem(player.GetGame()).IsActorInWorkspot(player) {
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

  public static func Create(canSway: Bool, heelScale: Float, reason: String, speed: Float) -> ref<SwayContextData> {
    let data: ref<SwayContextData> = new SwayContextData();
    data.canSway = canSway;
    data.heelScale = heelScale;
    data.suppressionReason = reason;
    data.speed = speed;
    return data;
  }
}

public class SwayEvaluator {

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

    // 6. Heel height scaling (in cm)
    let heelCm: Float = sys.GetCurrentHeelHeight() * 100.0;
    if heelCm < 2.0 {
      return SwayContextData.Create(false, 0.0, "Neutral Stride (Flat Footwear / <2 cm)", speed);
    };

    let norm: Float = MinF(1.50, (heelCm - 2.0) / 6.50);
    let heelScale: Float = MaxF(0.40, MinF(1.20, 0.45 + 0.60 * SqrtF(norm)));

    return SwayContextData.Create(true, heelScale, "Walking / Jogging", speed);
  }
}
