module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Context-Aware Suppression Domain
// Design Pattern: Specification / Rule Engine Pattern
// Single Responsibility Principle (SRP):
// - PlayerSuppressionSnapshot: Immutable capture of player state machine blackboard
// - ISuppressionRule: Discrete rule specification for each context
// - SuppressionRuleEngine: Pure, side-effect-free evaluation of rules
// - SuppressionEvaluator: Facade adapter connecting Rule Engine to System state
// =============================================================================

public class SuppressionRuleResult {
  public let isSuppressed: Bool;
  public let reason: String;

  public static func Pass() -> ref<SuppressionRuleResult> {
    let res: ref<SuppressionRuleResult> = new SuppressionRuleResult();
    res.isSuppressed = false;
    res.reason = "";
    return res;
  }

  public static func Suppress(reason: String) -> ref<SuppressionRuleResult> {
    let res: ref<SuppressionRuleResult> = new SuppressionRuleResult();
    res.isSuppressed = true;
    res.reason = reason;
    return res;
  }
}

// -----------------------------------------------------------------------------
// Snapshot of all relevant player state contexts for suppression evaluation
// -----------------------------------------------------------------------------
public class PlayerSuppressionSnapshot {
  public let isMountedToVehicle: Bool;
  public let isActorInWorkspot: Bool;
  public let sceneTier: Int32;
  public let locomotionState: Int32;
  public let detailedLocomotionState: Int32;
  public let highLevelState: Int32;
  public let swimmingState: Int32;
  public let takedownState: Int32;
  public let bodyCarryingState: Int32;

  public static func Capture(player: ref<PlayerPuppet>) -> ref<PlayerSuppressionSnapshot> {
    let snap: ref<PlayerSuppressionSnapshot> = new PlayerSuppressionSnapshot();
    if !IsDefined(player) {
      return snap;
    };

    snap.isMountedToVehicle = VehicleComponent.IsMountedToVehicle(player.GetGame(), player);
    snap.isActorInWorkspot = GameInstance.GetWorkspotSystem(player.GetGame()).IsActorInWorkspot(player);

    let psmBlackboard: ref<IBlackboard> = player.GetPlayerStateMachineBlackboard();
    if IsDefined(psmBlackboard) {
      let psmDefs: ref<PlayerStateMachineDef> = GetAllBlackboardDefs().PlayerStateMachine;
      if IsDefined(psmDefs) {
        snap.sceneTier = psmBlackboard.GetInt(psmDefs.SceneTier);
        snap.locomotionState = psmBlackboard.GetInt(psmDefs.Locomotion);
        snap.detailedLocomotionState = psmBlackboard.GetInt(psmDefs.LocomotionDetailed);
        snap.highLevelState = psmBlackboard.GetInt(psmDefs.HighLevel);
        snap.swimmingState = psmBlackboard.GetInt(psmDefs.Swimming);
        snap.takedownState = psmBlackboard.GetInt(psmDefs.Takedown);
        snap.bodyCarryingState = psmBlackboard.GetInt(psmDefs.BodyCarrying);
      };
    };

    return snap;
  }
}

// -----------------------------------------------------------------------------
// Abstract Rule Specification
// -----------------------------------------------------------------------------
public abstract class ISuppressionRule {
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule 1: Vehicle Occupancy
// -----------------------------------------------------------------------------
public class VehicleSuppressionRule extends ISuppressionRule {
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    if IsDefined(cfg) && !cfg.suppressVehicles {
      return SuppressionRuleResult.Pass();
    };
    if snap.isMountedToVehicle {
      return SuppressionRuleResult.Suppress("Vehicle Occupancy");
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule 2: Authored Workspot (Sitting on chairs, couches, beds, furniture)
// -----------------------------------------------------------------------------
public class WorkspotSuppressionRule extends ISuppressionRule {
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    if IsDefined(cfg) && !cfg.suppressWorkspots {
      return SuppressionRuleResult.Pass();
    };
    if snap.isActorInWorkspot {
      return SuppressionRuleResult.Suppress("Authored Workspot");
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule 3: Scripted Quest Scenes & High Dialogue Tiers (Tier >= 3 or <= 0)
// -----------------------------------------------------------------------------
public class SceneTierSuppressionRule extends ISuppressionRule {
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    if IsDefined(cfg) && !cfg.suppressScenes {
      return SuppressionRuleResult.Pass();
    };
    if snap.sceneTier >= 3 || snap.sceneTier <= 0 {
      return SuppressionRuleResult.Suppress("Scripted Scene / Dialogue");
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule 4: Locomotion Traversal & Special Physical Actions
// -----------------------------------------------------------------------------
public class LocomotionTraversalRule extends ISuppressionRule {
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    // Locomotion detailed: 8..13 correspond to climbing, vaulting, and ladder climbing
    if snap.detailedLocomotionState >= 8 && snap.detailedLocomotionState <= 13 {
      return SuppressionRuleResult.Suppress("Climb, Vault, or Ladder");
    };
    // Detailed states 29 and 31 represent knockdown and forced body reactions
    if snap.detailedLocomotionState == 29 || snap.detailedLocomotionState == 31 {
      return SuppressionRuleResult.Suppress("Knockdown or Forced Reaction");
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule 5: Swimming & Water Traversal
// -----------------------------------------------------------------------------
public class SwimmingSuppressionRule extends ISuppressionRule {
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    if snap.highLevelState == 6 || snap.swimmingState > 0 {
      return SuppressionRuleResult.Suppress("Swimming");
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule 6: Combat / Action Locks (Takedown, Body Carrying)
// -----------------------------------------------------------------------------
public class CombatActionLockRule extends ISuppressionRule {
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    if snap.takedownState > 0 {
      return SuppressionRuleResult.Suppress("Takedown or Grapple");
    };
    if snap.bodyCarryingState > 0 {
      return SuppressionRuleResult.Suppress("Body Carrying");
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule Engine Composite Evaluator (Pure Query - Zero Side Effects)
// -----------------------------------------------------------------------------
public class SuppressionRuleEngine {
  private let m_rules: array<ref<ISuppressionRule>>;

  public static func CreateDefault() -> ref<SuppressionRuleEngine> {
    let engine: ref<SuppressionRuleEngine> = new SuppressionRuleEngine();
    ArrayPush(engine.m_rules, new VehicleSuppressionRule());
    ArrayPush(engine.m_rules, new WorkspotSuppressionRule());
    ArrayPush(engine.m_rules, new SceneTierSuppressionRule());
    ArrayPush(engine.m_rules, new LocomotionTraversalRule());
    ArrayPush(engine.m_rules, new SwimmingSuppressionRule());
    ArrayPush(engine.m_rules, new CombatActionLockRule());
    return engine;
  }

  public func EvaluateAll(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    let count: Int32 = ArraySize(this.m_rules);
    let i: Int32 = 0;
    while i < count {
      let res: ref<SuppressionRuleResult> = this.m_rules[i].Evaluate(snap, cfg);
      if res.isSuppressed {
        return res;
      };
      i += 1;
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Suppression Evaluator (Facade Adapter)
// -----------------------------------------------------------------------------
public class SuppressionEvaluator {

  // Evaluates all suppression contexts and synchronizes state on the system coordinator
  public static func Evaluate(sys: ref<ImmersiveFootwearPOVSystem>, player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) {
      FootwearRedLogger.LogError("SUPPRESSION", "SuppressionEvaluator.Evaluate: Player entity is undefined");
      return false;
    };
    if !IsDefined(sys) {
      FootwearRedLogger.LogError("SUPPRESSION", "SuppressionEvaluator.Evaluate: System instance is undefined");
      return false;
    };

    let cfg: ref<FootwearConfig> = sys.GetConfig();
    let snap: ref<PlayerSuppressionSnapshot> = PlayerSuppressionSnapshot.Capture(player);

    // Sync vehicle state drift if needed
    if (!IsDefined(cfg) || cfg.suppressVehicles) {
      if snap.isMountedToVehicle && !sys.IsInVehicle() {
        sys.SetVehicleState(player, true);
      } else if !snap.isMountedToVehicle && sys.IsInVehicle() {
        sys.ClearVehicleState(player);
      };
    };

    // Sync workspot state drift if needed
    if (!IsDefined(cfg) || cfg.suppressWorkspots) {
      if snap.isActorInWorkspot && !sys.IsInWorkspot() {
        sys.SetWorkspotState(player, true);
      } else if !snap.isActorInWorkspot && sys.IsInWorkspot() {
        sys.ClearWorkspotState(player);
      };
    };

    let result: ref<SuppressionRuleResult> = sys.GetSuppressionEngine().EvaluateAll(snap, cfg);
    return sys.SetSuppressionState(result.isSuppressed, result.reason);
  }
}

