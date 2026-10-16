module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Footwear Calibration Service
// Design Pattern: Domain Service Pattern
// Single Responsibility Principle (SRP):
// Encapsulates footwear resolution evaluation, official tag parsing, custom
// override synchronization with the repository, and real-time live calibration.
// =============================================================================

public class FootwearCalibrationService {
  private let m_resolver: ref<FootwearResolver>;

  /**
   * Factory method initializing a FootwearCalibrationService instance with its resolver collaborator.
   * @return A newly initialized FootwearCalibrationService instance.
   */
  public static func Create() -> ref<FootwearCalibrationService> {
    let service: ref<FootwearCalibrationService> = new FootwearCalibrationService();
    service.m_resolver = FootwearResolver.Create();
    return service;
  }

  /**
   * Lazily initializes and retrieves the cached FootwearResolver instance.
   * @return The cached FootwearResolver collaborator.
   */
  public func GetResolver() -> ref<FootwearResolver> {
    if !IsDefined(this.m_resolver) {
      this.m_resolver = FootwearResolver.Create();
    };
    return this.m_resolver;
  }

  /**
   * Evaluates the player's visible footwear via FootwearResolver, extracts tag or override heights,
   * and synchronizes the authoritative FootwearEquipmentState.
   * @param player The local player puppet reference.
   * @param state The target FootwearEquipmentState to populate.
   * @param repo The FootwearOverrideRepository containing user-calibrated overrides.
   * @return True if resolution succeeded.
   */
  public func EvaluateEquippedFootwear(player: ref<PlayerPuppet>, state: ref<FootwearEquipmentState>, repo: ref<FootwearOverrideRepository>) -> Bool {
    if !IsDefined(player) || !IsDefined(state) {
      FootwearRedLogger.LogError("CALIBRATION", "EvaluateEquippedFootwear: Player or State entity is undefined");
      return false;
    };

    let result: ref<FootwearResolutionResult> = this.GetResolver().Resolve(player);
    let itemChanged: Bool = NotEquals(result.itemID, state.equippedFootwearID);

    if itemChanged {
      state.equippedFootwearID = result.itemID;
      state.activeSource = result.sourceName;
      state.hasCustomOverride = false;
      state.customHeelHeight = 0.0;
      state.customPlatformHeight = 0.0;
    };

    if ItemID.IsValid(state.equippedFootwearID) {
      let heightData: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(state.equippedFootwearID);

      if heightData.heelHeight > 0.0 || heightData.platformHeight > 0.0 {
        state.hasOfficialTags = true;
        state.hasCustomOverride = false;
        state.currentHeelHeight = heightData.heelHeight;
        state.currentPlatformHeight = heightData.platformHeight;
      } else {
        state.hasOfficialTags = false;
        let shoeKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(state.equippedFootwearID));
        if IsDefined(repo) && repo.Has(shoeKey) {
          state.hasCustomOverride = true;
          state.customHeelHeight = repo.GetHeel(shoeKey);
          state.customPlatformHeight = repo.GetPlatform(shoeKey);
          state.currentHeelHeight = state.customHeelHeight;
          state.currentPlatformHeight = state.customPlatformHeight;
        } else {
          state.hasCustomOverride = false;
          state.customHeelHeight = 0.0;
          state.customPlatformHeight = 0.0;
          state.currentHeelHeight = 0.0;
          state.currentPlatformHeight = 0.0;
        };
      };
    } else {
      state.hasOfficialTags = false;
      state.hasCustomOverride = false;
      state.currentHeelHeight = 0.0;
      state.currentPlatformHeight = 0.0;
    };

    return true;
  }

  /**
   * Applies live preview elevation adjustments during calibration window slider manipulation.
   * @param state The target FootwearEquipmentState to update.
   * @param heel Temporary preview heel height in meters.
   * @param platform Temporary preview platform height in meters.
   */
  public func ApplyLiveCalibration(state: ref<FootwearEquipmentState>, heel: Float, platform: Float) -> Void {
    if !IsDefined(state) {
      return;
    };
    state.hasCustomOverride = true;
    state.customHeelHeight = FootwearClampingPolicy.ClampHeight(heel);
    state.customPlatformHeight = FootwearClampingPolicy.ClampPlatformHeight(platform);
    state.currentHeelHeight = state.customHeelHeight;
    state.currentPlatformHeight = state.customPlatformHeight;
  }

  /**
   * Calibrates and persists height overrides for currently equipped footwear.
   * @param state The target FootwearEquipmentState to update.
   * @param repo The FootwearOverrideRepository to persist into.
   * @param heel Heel height offset in meters.
   * @param platform Platform height offset in meters.
   * @param force True to override even if official tags exist.
   */
  public func SetCustomHeightOverride(state: ref<FootwearEquipmentState>, repo: ref<FootwearOverrideRepository>, heel: Float, platform: Float, opt force: Bool) -> Void {
    if !IsDefined(state) {
      return;
    };
    if state.hasOfficialTags && !force {
      return;
    };

    state.hasCustomOverride = true;
    state.customHeelHeight = FootwearClampingPolicy.ClampHeight(heel);
    state.customPlatformHeight = FootwearClampingPolicy.ClampPlatformHeight(platform);
    state.currentHeelHeight = state.customHeelHeight;
    state.currentPlatformHeight = state.customPlatformHeight;

    if ItemID.IsValid(state.equippedFootwearID) && IsDefined(repo) {
      let shoeKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(state.equippedFootwearID));
      repo.Register(shoeKey, state.customHeelHeight, state.customPlatformHeight);
    };
  }

  /**
   * Clears custom height override for current footwear and restores tag or zero baseline.
   * @param state The target FootwearEquipmentState to update.
   * @param repo The FootwearOverrideRepository to remove from.
   * @param force True to force clear regardless of official tags.
   */
  public func ClearCustomHeightOverride(state: ref<FootwearEquipmentState>, repo: ref<FootwearOverrideRepository>, opt force: Bool) -> Void {
    if !IsDefined(state) {
      return;
    };
    if !state.hasOfficialTags || force {
      state.hasCustomOverride = false;
      state.customHeelHeight = 0.0;
      state.customPlatformHeight = 0.0;
      if ItemID.IsValid(state.equippedFootwearID) && IsDefined(repo) {
        let shoeKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(state.equippedFootwearID));
        repo.Remove(shoeKey);
      };
      if !state.hasOfficialTags {
        state.currentHeelHeight = 0.0;
        state.currentPlatformHeight = 0.0;
      } else {
        let data: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(state.equippedFootwearID);
        state.currentHeelHeight = data.heelHeight;
        state.currentPlatformHeight = data.platformHeight;
      };
    };
  }
}
