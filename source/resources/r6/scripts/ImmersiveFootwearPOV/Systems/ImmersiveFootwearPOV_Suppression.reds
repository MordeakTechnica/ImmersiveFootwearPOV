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
