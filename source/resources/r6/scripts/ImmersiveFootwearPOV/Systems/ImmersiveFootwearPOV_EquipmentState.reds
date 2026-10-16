module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Footwear Equipment State
// Design Pattern: State / Value Object Pattern
// Single Responsibility Principle (SRP):
// Encapsulates authoritative state for equipped footwear, height offsets,
// tags, and custom overrides.
// =============================================================================

public class FootwearEquipmentState {
  public let equippedFootwearID: ItemID;
  public let activeSource: String;
  public let currentHeelHeight: Float;
  public let currentPlatformHeight: Float;
  public let effectiveOffset: Float;
  public let hasOfficialTags: Bool;
  public let hasCustomOverride: Bool;
  public let customHeelHeight: Float;
  public let customPlatformHeight: Float;

  /**
   * Factory method creating a freshly initialized FootwearEquipmentState.
   * @return Initialized FootwearEquipmentState instance with zeroed baseline.
   */
  public static func Create() -> ref<FootwearEquipmentState> {
    let state: ref<FootwearEquipmentState> = new FootwearEquipmentState();
    state.ResetToZero();
    return state;
  }

  /**
   * Resets all footwear state variables to their unequipped, zero-elevation baseline.
   */
  public func ResetToZero() -> Void {
    this.equippedFootwearID = ItemID.None();
    this.activeSource = "None";
    this.currentHeelHeight = 0.0;
    this.currentPlatformHeight = 0.0;
    this.effectiveOffset = 0.0;
    this.hasOfficialTags = false;
    this.hasCustomOverride = false;
    this.customHeelHeight = 0.0;
    this.customPlatformHeight = 0.0;
  }

  /**
   * Computes effective heel pitch inclination in meters (heel minus platform).
   * @return Heel pitch in meters.
   */
  public func GetEffectiveHeelPitch() -> Float {
    return MaxF(0.0, this.currentHeelHeight - this.currentPlatformHeight);
  }

  /**
   * Retrieves effective platform offset in meters (0.0m if suppressed).
   * @param isSuppressed True if elevation is currently suppressed.
   * @return Effective platform offset in meters.
   */
  public func GetEffectivePlatformOffset(isSuppressed: Bool) -> Float {
    if isSuppressed {
      return 0.0;
    };
    return this.currentPlatformHeight;
  }
}
