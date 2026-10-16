module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Context-Aware Suppression Domain
// Design Pattern: Specification / Rule Engine Pattern & State Controller
// Single Responsibility Principle (SRP):
// - FootwearSuppressionReasons: Constant definitions for typed suppression identifiers
// - PlayerSuppressionSnapshot: Immutable capture of player state machine blackboard
// - ISuppressionRule: Discrete rule specification for each context
// - SuppressionRuleEngine: Pure, side-effect-free evaluation of rules
// - SuppressionStateController: State machine tracking vehicle, workspot, and suppression
// - SuppressionEvaluator: Facade adapter connecting Rule Engine to System state
// =============================================================================

public abstract class FootwearSuppressionReasons {
  public static func Vehicle() -> String { return "Vehicle Occupancy"; }
  public static func Workspot() -> String { return "Authored Workspot"; }
  public static func Scene() -> String { return "Scripted Scene / Dialogue"; }
  public static func Traversal() -> String { return "Climb, Vault, or Ladder"; }
  public static func Knockdown() -> String { return "Knockdown or Forced Reaction"; }
  public static func Swimming() -> String { return "Swimming"; }
  public static func CombatLock() -> String { return "Takedown or Grapple"; }
  public static func BodyCarrying() -> String { return "Body Carrying"; }
}

public class SuppressionRuleResult {
  public let isSuppressed: Bool;
  public let reason: String;

  /**
   * Factory method for unsuppressed evaluation result (elevation permitted).
   * @return A passing SuppressionRuleResult.
   */
  public static func Pass() -> ref<SuppressionRuleResult> {
    let res: ref<SuppressionRuleResult> = new SuppressionRuleResult();
    res.isSuppressed = false;
    res.reason = "";
    return res;
  }

  /**
   * Factory method for suppressed evaluation result with descriptive context trigger.
   * @param reason Human-readable explanation of why elevation was suppressed.
   * @return A suppressed SuppressionRuleResult.
   */
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

  /**
   * Captures an immutable snapshot of player state machine blackboard parameters and world attachment.
   * @param player The local player puppet reference.
   * @return Populated PlayerSuppressionSnapshot instance.
   */
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
  /**
   * Evaluates a single suppression condition against the player snapshot.
   * @param snap Captured player state machine snapshot.
   * @param cfg Active user configuration settings.
   * @return Result containing suppression status and reason.
   */
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule 1: Vehicle Occupancy
// -----------------------------------------------------------------------------
public class VehicleSuppressionRule extends ISuppressionRule {
  /**
   * Suppresses elevation when player is seated or mounted in any vehicle.
   * @param snap Captured player state machine snapshot.
   * @param cfg Active user configuration settings.
   * @return Result containing suppression status and reason.
   */
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    if IsDefined(cfg) && !cfg.suppressVehicles {
      return SuppressionRuleResult.Pass();
    };
    if snap.isMountedToVehicle {
      return SuppressionRuleResult.Suppress(FootwearSuppressionReasons.Vehicle());
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule 2: Authored Workspot (Sitting on chairs, couches, beds, furniture)
// -----------------------------------------------------------------------------
public class WorkspotSuppressionRule extends ISuppressionRule {
  /**
   * Suppresses elevation when player is bound to an authored workspot animation.
   * @param snap Captured player state machine snapshot.
   * @param cfg Active user configuration settings.
   * @return Result containing suppression status and reason.
   */
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    if IsDefined(cfg) && !cfg.suppressWorkspots {
      return SuppressionRuleResult.Pass();
    };
    if snap.isActorInWorkspot {
      return SuppressionRuleResult.Suppress(FootwearSuppressionReasons.Workspot());
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule 3: Scripted Quest Scenes & High Dialogue Tiers (Tier 3 to 5)
// -----------------------------------------------------------------------------
public class SceneTierSuppressionRule extends ISuppressionRule {
  /**
   * Suppresses elevation during scripted quest cutscenes and high-tier dialogues (Tiers 3..5).
   * Note: Tier <= 0 represents uninitialized or standard gameplay baseline and must NOT suppress.
   * @param snap Captured player state machine snapshot.
   * @param cfg Active user configuration settings.
   * @return Result containing suppression status and reason.
   */
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    if IsDefined(cfg) && !cfg.suppressScenes {
      return SuppressionRuleResult.Pass();
    };
    // SceneTier: 1 = Tier1_FullGameplay, 2 = Tier2_StagedGameplay, 3 = Tier3_LimitedGameplay, 4 = Tier4_FPPCutscene, 5 = Tier5_Cinematic
    if snap.sceneTier >= 3 && snap.sceneTier <= 5 {
      return SuppressionRuleResult.Suppress(FootwearSuppressionReasons.Scene());
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule 4: Locomotion Traversal & Special Physical Actions
// -----------------------------------------------------------------------------
public class LocomotionTraversalRule extends ISuppressionRule {
  /**
   * Suppresses elevation during ladder climbing, vaulting, mantling, or knockdown reactions.
   * @param snap Captured player state machine snapshot.
   * @param cfg Active user configuration settings.
   * @return Result containing suppression status and reason.
   */
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    // Locomotion detailed: 8..13 correspond to climbing, vaulting, and ladder climbing
    if snap.detailedLocomotionState >= 8 && snap.detailedLocomotionState <= 13 {
      return SuppressionRuleResult.Suppress(FootwearSuppressionReasons.Traversal());
    };
    // Detailed states 29 and 31 represent knockdown and forced body reactions
    if snap.detailedLocomotionState == 29 || snap.detailedLocomotionState == 31 {
      return SuppressionRuleResult.Suppress(FootwearSuppressionReasons.Knockdown());
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule 5: Swimming & Water Traversal
// -----------------------------------------------------------------------------
public class SwimmingSuppressionRule extends ISuppressionRule {
  /**
   * Suppresses elevation when player is swimming or treading water.
   * @param snap Captured player state machine snapshot.
   * @param cfg Active user configuration settings.
   * @return Result containing suppression status and reason.
   */
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    if snap.highLevelState == 6 || snap.swimmingState > 0 {
      return SuppressionRuleResult.Suppress(FootwearSuppressionReasons.Swimming());
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule 6: Combat / Action Locks (Takedown, Body Carrying)
// -----------------------------------------------------------------------------
public class CombatActionLockRule extends ISuppressionRule {
  /**
   * Suppresses elevation during enemy takedowns, grappling, or body carrying.
   * @param snap Captured player state machine snapshot.
   * @param cfg Active user configuration settings.
   * @return Result containing suppression status and reason.
   */
  public func Evaluate(snap: ref<PlayerSuppressionSnapshot>, cfg: ref<FootwearConfig>) -> ref<SuppressionRuleResult> {
    if snap.takedownState > 0 {
      return SuppressionRuleResult.Suppress(FootwearSuppressionReasons.CombatLock());
    };
    if snap.bodyCarryingState > 0 {
      return SuppressionRuleResult.Suppress(FootwearSuppressionReasons.BodyCarrying());
    };
    return SuppressionRuleResult.Pass();
  }
}

// -----------------------------------------------------------------------------
// Rule Engine Composite Evaluator (Pure Query - Zero Side Effects)
// -----------------------------------------------------------------------------
public class SuppressionRuleEngine {
  private let m_rules: array<ref<ISuppressionRule>>;

  /**
   * Factory method initializing the rule engine with standard gameplay suppression rules.
   * @return A newly initialized SuppressionRuleEngine instance.
   */
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

  /**
   * Evaluates all registered suppression rules sequentially. Returns early on first suppression trigger.
   * @param snap Captured player state snapshot.
   * @param cfg Active configuration settings.
   * @return First active suppression result, or Pass() if all rules permit elevation.
   */
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
// Suppression State Controller (State Machine & Facade)
// -----------------------------------------------------------------------------
public class SuppressionStateController {
  private let m_isInVehicle: Bool;
  private let m_isInWorkspot: Bool;
  private let m_isSuppressed: Bool;
  private let m_suppressionReason: String;
  private let m_ruleEngine: ref<SuppressionRuleEngine>;

  /**
   * Factory method initializing a SuppressionStateController with its default rule engine.
   * @return A newly initialized SuppressionStateController instance.
   */
  public static func Create() -> ref<SuppressionStateController> {
    let ctrl: ref<SuppressionStateController> = new SuppressionStateController();
    ctrl.m_ruleEngine = SuppressionRuleEngine.CreateDefault();
    ctrl.Reset();
    return ctrl;
  }

  /**
   * Resets all suppression and context flags to unsuppressed baseline.
   */
  public func Reset() -> Void {
    this.m_isInVehicle = false;
    this.m_isInWorkspot = false;
    this.m_isSuppressed = false;
    this.m_suppressionReason = "";
  }

  /**
   * Checks whether footwear elevation is currently suppressed.
   * @return True if suppressed.
   */
  public func IsSuppressed() -> Bool {
    return this.m_isSuppressed;
  }

  /**
   * Retrieves the active suppression trigger explanation string.
   * @return Suppression explanation string.
   */
  public func GetSuppressionReason() -> String {
    return this.m_suppressionReason;
  }

  /**
   * Checks whether player is currently flagged inside a vehicle.
   * @return True if seated in vehicle.
   */
  public func IsInVehicle() -> Bool {
    return this.m_isInVehicle;
  }

  /**
   * Checks whether player is currently flagged in an authored workspot animation.
   * @return True if in workspot.
   */
  public func IsInWorkspot() -> Bool {
    return this.m_isInWorkspot;
  }

  /**
   * Lazily initializes and retrieves the SuppressionRuleEngine.
   * @return The active SuppressionRuleEngine instance.
   */
  public func GetRuleEngine() -> ref<SuppressionRuleEngine> {
    if !IsDefined(this.m_ruleEngine) {
      this.m_ruleEngine = SuppressionRuleEngine.CreateDefault();
    };
    return this.m_ruleEngine;
  }

  /**
   * Updates internal suppression state and notifies event dispatcher if state changed.
   * @param suppressed True if elevation is suppressed.
   * @param reason Description of suppression trigger.
   * @param dispatcher Central FootwearEventDispatcher instance.
   * @return Current suppression boolean value.
   */
  public func SetSuppressionState(suppressed: Bool, reason: String, dispatcher: ref<FootwearEventDispatcher>) -> Bool {
    let changed: Bool = NotEquals(this.m_isSuppressed, suppressed) || NotEquals(this.m_suppressionReason, reason);
    this.m_isSuppressed = suppressed;
    this.m_suppressionReason = reason;
    if changed && IsDefined(dispatcher) {
      dispatcher.NotifySuppressionChanged(suppressed, reason);
    };
    return this.m_isSuppressed;
  }

  /**
   * Sets vehicle occupancy state. Updates internal suppression state if exiting.
   * @param inVehicle True if entered vehicle, false if exited.
   * @param dispatcher Event dispatcher to notify on change.
   * @param telemetry Telemetry logger instance.
   * @param sys System reference for telemetry logging.
   * @return True if vehicle state actually changed.
   */
  public func SetVehicleState(inVehicle: Bool, dispatcher: ref<FootwearEventDispatcher>, telemetry: ref<FootwearTelemetryLogger>, sys: ref<ImmersiveFootwearPOVSystem>) -> Bool {
    if Equals(this.m_isInVehicle, inVehicle) {
      return false;
    };
    this.m_isInVehicle = inVehicle;
    if !inVehicle && Equals(this.m_suppressionReason, FootwearSuppressionReasons.Vehicle()) {
      this.m_isSuppressed = false;
      this.m_suppressionReason = "";
      if IsDefined(dispatcher) {
        dispatcher.NotifySuppressionChanged(false, "");
      };
    };
    if IsDefined(telemetry) && IsDefined(sys) {
      FootwearTelemetryLogger.LogVehicleState(sys, inVehicle);
    };
    return true;
  }

  /**
   * Clears vehicle occupancy suppression when auto-recovery detects player on foot.
   * @param dispatcher Event dispatcher to notify on change.
   * @param telemetry Telemetry logger instance.
   * @param sys System reference for telemetry logging.
   * @return True if vehicle state was cleared.
   */
  public func ClearVehicleState(dispatcher: ref<FootwearEventDispatcher>, telemetry: ref<FootwearTelemetryLogger>, sys: ref<ImmersiveFootwearPOVSystem>) -> Bool {
    if !this.m_isInVehicle {
      return false;
    };
    this.m_isInVehicle = false;
    if Equals(this.m_suppressionReason, FootwearSuppressionReasons.Vehicle()) {
      this.m_isSuppressed = false;
      this.m_suppressionReason = "";
      if IsDefined(dispatcher) {
        dispatcher.NotifySuppressionChanged(false, "");
      };
    };
    if IsDefined(telemetry) && IsDefined(sys) {
      FootwearTelemetryLogger.LogVehicleAutoRecovered(sys);
    };
    return true;
  }

  /**
   * Sets authored workspot animation state (sitting, furniture).
   * @param inWorkspot True if entered workspot, false if exited.
   * @param dispatcher Event dispatcher to notify on change.
   * @param telemetry Telemetry logger instance.
   * @param sys System reference for telemetry logging.
   * @return True if workspot state actually changed.
   */
  public func SetWorkspotState(inWorkspot: Bool, dispatcher: ref<FootwearEventDispatcher>, telemetry: ref<FootwearTelemetryLogger>, sys: ref<ImmersiveFootwearPOVSystem>) -> Bool {
    if Equals(this.m_isInWorkspot, inWorkspot) {
      return false;
    };
    this.m_isInWorkspot = inWorkspot;
    if !inWorkspot && Equals(this.m_suppressionReason, FootwearSuppressionReasons.Workspot()) {
      this.m_isSuppressed = false;
      this.m_suppressionReason = "";
      if IsDefined(dispatcher) {
        dispatcher.NotifySuppressionChanged(false, "");
      };
    };
    if IsDefined(telemetry) && IsDefined(sys) {
      FootwearTelemetryLogger.LogWorkspotState(sys, inWorkspot);
    };
    return true;
  }

  /**
   * Clears workspot suppression when auto-recovery detects player standing up.
   * @param dispatcher Event dispatcher to notify on change.
   * @param telemetry Telemetry logger instance.
   * @param sys System reference for telemetry logging.
   * @return True if workspot state was cleared.
   */
  public func ClearWorkspotState(dispatcher: ref<FootwearEventDispatcher>, telemetry: ref<FootwearTelemetryLogger>, sys: ref<ImmersiveFootwearPOVSystem>) -> Bool {
    if !this.m_isInWorkspot {
      return false;
    };
    this.m_isInWorkspot = false;
    if Equals(this.m_suppressionReason, FootwearSuppressionReasons.Workspot()) {
      this.m_isSuppressed = false;
      this.m_suppressionReason = "";
      if IsDefined(dispatcher) {
        dispatcher.NotifySuppressionChanged(false, "");
      };
    };
    if IsDefined(telemetry) && IsDefined(sys) {
      FootwearTelemetryLogger.LogWorkspotAutoRecovered(sys);
    };
    return true;
  }

  /**
   * Evaluates all suppression contexts against the player state snapshot.
   * Synchronizes vehicle/workspot drift locally without circular re-entrancy into elevation recalculation.
   * @param player The local player puppet reference.
   * @param cfg Active user configuration settings.
   * @param dispatcher Central FootwearEventDispatcher instance.
   * @return True if elevation is currently suppressed.
   */
  public func Evaluate(player: ref<PlayerPuppet>, cfg: ref<FootwearConfig>, dispatcher: ref<FootwearEventDispatcher>) -> Bool {
    if !IsDefined(player) {
      return false;
    };

    let snap: ref<PlayerSuppressionSnapshot> = PlayerSuppressionSnapshot.Capture(player);

    // Sync vehicle state drift locally on controller (NO circular call into RecalculateEffectiveOffset)
    if (!IsDefined(cfg) || cfg.suppressVehicles) {
      if snap.isMountedToVehicle && !this.m_isInVehicle {
        this.m_isInVehicle = true;
      } else if !snap.isMountedToVehicle && this.m_isInVehicle {
        this.m_isInVehicle = false;
      };
    };

    // Sync workspot state drift locally on controller (NO circular call into RecalculateEffectiveOffset)
    if (!IsDefined(cfg) || cfg.suppressWorkspots) {
      if snap.isActorInWorkspot && !this.m_isInWorkspot {
        this.m_isInWorkspot = true;
      } else if !snap.isActorInWorkspot && this.m_isInWorkspot {
        this.m_isInWorkspot = false;
      };
    };

    let result: ref<SuppressionRuleResult> = this.GetRuleEngine().EvaluateAll(snap, cfg);
    this.SetSuppressionState(result.isSuppressed, result.reason, dispatcher);
    return this.m_isSuppressed;
  }
}

// -----------------------------------------------------------------------------
// Suppression Evaluator (Facade Adapter for Backwards Compatibility)
// -----------------------------------------------------------------------------
public class SuppressionEvaluator {

  /**
   * Evaluates all suppression contexts against the player and synchronizes state on ImmersiveFootwearPOVSystem.
   * @param sys Reference to ImmersiveFootwearPOVSystem.
   * @param player The local player puppet reference.
   * @return True if elevation is currently suppressed.
   */
  public static func Evaluate(sys: ref<ImmersiveFootwearPOVSystem>, player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) {
      FootwearRedLogger.LogError("SUPPRESSION", "SuppressionEvaluator.Evaluate: Player entity is undefined");
      return false;
    };
    if !IsDefined(sys) {
      FootwearRedLogger.LogError("SUPPRESSION", "SuppressionEvaluator.Evaluate: System instance is undefined");
      return false;
    };

    return sys.GetSuppressionController().Evaluate(player, sys.GetConfig(), sys.GetEventDispatcher());
  }
}
