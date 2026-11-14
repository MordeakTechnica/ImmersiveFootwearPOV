module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Footwear Calibration Service
// Single Responsibility Principle (SRP):
// Encapsulates footwear resolution evaluation, official tag parsing, custom
// override synchronization with the repository, and real-time live calibration.
// =============================================================================

public class FootwearCalibrationService {
  private let m_resolver: ref<FootwearResolver>;
  private let m_hasDirtyOverride: Bool;
  private let m_dirtyOverrideKey: String;
  private let m_dirtyOverrideHeel: Float;
  private let m_dirtyOverridePlat: Float;

  /**
   * Initializes a FootwearCalibrationService instance with its resolver collaborator.
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

    state.activeSource = result.sourceName;

    if itemChanged {
      state.equippedFootwearID = result.itemID;
      state.hasCustomOverride = false;
      state.customHeelHeight = 0.0;
      state.customPlatformHeight = 0.0;
    };

    if !ItemID.IsValid(state.equippedFootwearID) {
      state.hasOfficialTags = false;
      state.hasCustomOverride = false;
      state.settingsSource = "None (Barefoot)";
      state.currentHeelHeight = 0.0;
      state.currentPlatformHeight = 0.0;
      return true;
    };

    let shoeKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(state.equippedFootwearID));
    let heightData: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(state.equippedFootwearID);
    let hasTags: Bool = heightData.heelHeight > 0.0 || heightData.platformHeight > 0.0;

    // 1. User Override (highest precedence - user customized calibration)
    if IsDefined(repo) && repo.HasUserOverride(shoeKey) {
      state.hasOfficialTags = hasTags;
      state.hasCustomOverride = true;
      state.settingsSource = "User Override";
      state.customHeelHeight = repo.GetHeel(shoeKey);
      state.customPlatformHeight = repo.GetPlatform(shoeKey);
      state.currentHeelHeight = state.customHeelHeight;
      state.currentPlatformHeight = state.customPlatformHeight;
      return true;
    };

    // 2. Tweak File (official TweakDB tags from mod/DLC item record)
    if hasTags {
      state.hasOfficialTags = true;
      state.hasCustomOverride = false;
      state.settingsSource = "Tweak File";
      state.currentHeelHeight = heightData.heelHeight;
      state.currentPlatformHeight = heightData.platformHeight;
      return true;
    };

    // 3. Preset (presets.json master catalog)
    if IsDefined(repo) && repo.HasPreset(shoeKey) {
      state.hasOfficialTags = false;
      state.hasCustomOverride = false;
      state.settingsSource = "Preset";
      state.currentHeelHeight = repo.GetHeel(shoeKey);
      state.currentPlatformHeight = repo.GetPlatform(shoeKey);
      return true;
    };

    // 4. Default / uncalibrated vanilla shoe
    state.hasOfficialTags = false;
    state.hasCustomOverride = false;
    state.settingsSource = "Default / None";
    state.customHeelHeight = 0.0;
    state.customPlatformHeight = 0.0;
    state.currentHeelHeight = 0.0;
    state.currentPlatformHeight = 0.0;
    return true;
  }

  /**
   * Applies live preview elevation adjustments during calibration window slider manipulation,
   * updates the in-memory repository, and records pending dirty state for deferred disk persistence.
   */
  public func ApplyLiveCalibration(state: ref<FootwearEquipmentState>, repo: ref<FootwearOverrideRepository>, storageMgr: ref<FootwearStorageManager>, heel: Float, platform: Float) -> Void {
    if !IsDefined(state) {
      return;
    };
    state.hasCustomOverride = true;
    state.settingsSource = "Live Calibration";
    state.customHeelHeight = FootwearClampingPolicy.ClampHeight(heel);
    state.customPlatformHeight = FootwearClampingPolicy.ClampPlatformHeight(platform);
    state.currentHeelHeight = state.customHeelHeight;
    state.currentPlatformHeight = state.customPlatformHeight;

    if ItemID.IsValid(state.equippedFootwearID) {
      let shoeKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(state.equippedFootwearID));
      if StrLen(shoeKey) > 0 {
        if this.m_hasDirtyOverride && NotEquals(this.m_dirtyOverrideKey, shoeKey) {
          this.FlushPendingOverrideSave(state, repo, storageMgr);
        };
        if IsDefined(repo) {
          repo.RegisterUserOverride(shoeKey, state.currentHeelHeight, state.currentPlatformHeight);
        };
        this.m_hasDirtyOverride = true;
        this.m_dirtyOverrideKey = shoeKey;
        this.m_dirtyOverrideHeel = state.currentHeelHeight;
        this.m_dirtyOverridePlat = state.currentPlatformHeight;
      };
    };
  }

  /**
   * Registers or updates a custom shoe override in the repository and synchronizes active state if equipped.
   */
  public func RegisterCustomOverride(state: ref<FootwearEquipmentState>, repo: ref<FootwearOverrideRepository>, key: String, heel: Float, platform: Float) -> Void {
    if StrLen(key) == 0 {
      return;
    };
    let clampedHeel: Float = FootwearClampingPolicy.ClampHeight(heel);
    let clampedPlat: Float = FootwearClampingPolicy.ClampPlatformHeight(platform);
    if IsDefined(repo) {
      repo.RegisterUserOverride(key, clampedHeel, clampedPlat);
    };
    if !IsDefined(state) || !ItemID.IsValid(state.equippedFootwearID) {
      return;
    };
    let currentKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(state.equippedFootwearID));
    if !Equals(currentKey, key) && !Equals(StrLower(currentKey), StrLower(key)) {
      return;
    };

    state.hasCustomOverride = true;
    state.settingsSource = "User Override";
    state.customHeelHeight = clampedHeel;
    state.customPlatformHeight = clampedPlat;
    state.currentHeelHeight = clampedHeel;
    state.currentPlatformHeight = clampedPlat;
  }

  /**
   * Persists any uncommitted live calibration override to user_shoe_overrides.json once.
   */
  public func FlushPendingOverrideSave(state: ref<FootwearEquipmentState>, repo: ref<FootwearOverrideRepository>, storageMgr: ref<FootwearStorageManager>) -> Void {
    if !this.m_hasDirtyOverride || StrLen(this.m_dirtyOverrideKey) == 0 {
      return;
    };
    let key: String = this.m_dirtyOverrideKey;
    let heel: Float = this.m_dirtyOverrideHeel;
    let plat: Float = this.m_dirtyOverridePlat;
    this.m_hasDirtyOverride = false;
    this.m_dirtyOverrideKey = "";

    if IsDefined(storageMgr) {
      storageMgr.SaveUserOverride(key, heel, plat);
    };
    this.RegisterCustomOverride(state, repo, key, heel, plat);
    FootwearRedLogger.LogInfo("CALIBRATOR", s"Auto-saved permanent override for \(key)");
  }

  public func HasDirtyOverride() -> Bool {
    return this.m_hasDirtyOverride;
  }

  public func ClearPendingOverrideSave() -> Void {
    this.m_hasDirtyOverride = false;
    this.m_dirtyOverrideKey = "";
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
    state.settingsSource = "User Override";
    state.customHeelHeight = FootwearClampingPolicy.ClampHeight(heel);
    state.customPlatformHeight = FootwearClampingPolicy.ClampPlatformHeight(platform);
    state.currentHeelHeight = state.customHeelHeight;
    state.currentPlatformHeight = state.customPlatformHeight;

    if !ItemID.IsValid(state.equippedFootwearID) || !IsDefined(repo) {
      return;
    };
    let shoeKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(state.equippedFootwearID));
    repo.RegisterUserOverride(shoeKey, state.customHeelHeight, state.customPlatformHeight);
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
    if state.hasOfficialTags && !force {
      return;
    };

    state.hasCustomOverride = false;
    state.customHeelHeight = 0.0;
    state.customPlatformHeight = 0.0;

    if !ItemID.IsValid(state.equippedFootwearID) {
      state.hasOfficialTags = false;
      state.settingsSource = "None (Barefoot)";
      state.currentHeelHeight = 0.0;
      state.currentPlatformHeight = 0.0;
      return;
    };

    let shoeKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(state.equippedFootwearID));
    if IsDefined(repo) {
      repo.RemoveUserOverride(shoeKey);
    };

    let data: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(state.equippedFootwearID);
    if data.heelHeight > 0.0 || data.platformHeight > 0.0 {
      state.hasOfficialTags = true;
      state.settingsSource = "Tweak File";
      state.currentHeelHeight = data.heelHeight;
      state.currentPlatformHeight = data.platformHeight;
      return;
    };

    if IsDefined(repo) && repo.HasPreset(shoeKey) {
      state.hasOfficialTags = false;
      state.settingsSource = "Preset";
      state.currentHeelHeight = repo.GetHeel(shoeKey);
      state.currentPlatformHeight = repo.GetPlatform(shoeKey);
      return;
    };

    state.hasOfficialTags = false;
    state.settingsSource = "Default / None";
    state.currentHeelHeight = 0.0;
    state.currentPlatformHeight = 0.0;
  }
}
