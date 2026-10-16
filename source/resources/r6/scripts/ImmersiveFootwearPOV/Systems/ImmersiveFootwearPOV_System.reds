module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Core ScriptableSystem Coordinator
// Design Pattern: Facade / Coordinator Pattern
// Single Responsibility Principle (SRP):
// Acts as the central REDengine ScriptableSystem coordinator, delegating domain
// operations to specialized repositories, rule engines, actuators, and dispatchers.
// =============================================================================

public class ImmersiveFootwearPOVSystem extends ScriptableSystem {

  // Authoritative State
  private let m_currentHeelHeight: Float;      // Active FPP elevation height (meters)
  private let m_currentPlatformHeight: Float;  // Secondary platform height (reserved for PM / TPP)
  private let m_effectiveOffset: Float;        // Current effective height after suppression
  private let m_equippedFootwearID: ItemID;
  private let m_activeSource: String;
  private let m_hasOfficialTags: Bool;
  private let m_hasCustomOverride: Bool;
  private let m_customHeelHeight: Float;
  private let m_customPlatformHeight: Float;
  private let m_isInVehicle: Bool;
  private let m_isInWorkspot: Bool;
  private let m_isSuppressed: Bool;
  private let m_suppressionReason: String;
  private let m_isInitialized: Bool;
  private let m_debugLogging: Bool;
  private let m_isPhotoModeActive: Bool;
  private let m_isIFPPresent: Bool;
  private let m_isITPPresent: Bool;
  private let m_isITPChecked: Bool;
  private let m_isStorageLoaded: Bool;
  private let m_swayContext: ref<SwayContextData>;
  private let m_lastStrideFrame: Uint64;

  // Domain Collaborators (Inversion of Control & Encapsulation)
  private let m_overrideRepo: ref<FootwearOverrideRepository>;
  private let m_eventDispatcher: ref<FootwearEventDispatcher>;
  private let m_elevationCoordinator: ref<ElevationActuatorCoordinator>;
  private let m_strideController: ref<StrideController>;
  private let m_suppressionEngine: ref<SuppressionRuleEngine>;
  private let m_telemetry: ref<FootwearTelemetryLogger>;
  private let m_calibratorWindow: ref<FootwearCalibratorWindow>;
  private let m_config: ref<FootwearConfig>;
  private let m_isRcfRegistered: Bool;
  private let m_windowsLoopStarted: Bool;
  private let m_diagGeoApplied: Bool;
  private let m_calibGeoApplied: Bool;


  // -----------------------------------------------------------------------------
  // Singleton Accessor
  // -----------------------------------------------------------------------------
  /**
   * Singleton accessor retrieving the running ImmersiveFootwearPOVSystem instance from the game container.
   * @param gameInstance The active GameInstance.
   * @return The registered ImmersiveFootwearPOVSystem instance.
   */
  public static func GetInstance(gameInstance: GameInstance) -> ref<ImmersiveFootwearPOVSystem> {
    let system: ref<ImmersiveFootwearPOVSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem") as ImmersiveFootwearPOVSystem;
    return system;
  }

  // -----------------------------------------------------------------------------
  // Lazy Collaborator Initializers
  // -----------------------------------------------------------------------------

  /**
   * Lazily initializes and retrieves the FootwearOverrideRepository.
   * @return The shared FootwearOverrideRepository instance.
   */
  public func GetOverrideRepository() -> ref<FootwearOverrideRepository> {
    if !IsDefined(this.m_overrideRepo) {
      this.m_overrideRepo = FootwearOverrideRepository.Create();
    };
    return this.m_overrideRepo;
  }

  /**
   * Lazily initializes and retrieves the FootwearEventDispatcher.
   * @return The central FootwearEventDispatcher instance.
   */
  public func GetEventDispatcher() -> ref<FootwearEventDispatcher> {
    if !IsDefined(this.m_eventDispatcher) {
      this.m_eventDispatcher = FootwearEventDispatcher.Create();
    };
    return this.m_eventDispatcher;
  }

  /**
   * Lazily initializes and retrieves the ElevationActuatorCoordinator.
   * @return The ElevationActuatorCoordinator instance.
   */
  public func GetElevationCoordinator() -> ref<ElevationActuatorCoordinator> {
    if !IsDefined(this.m_elevationCoordinator) {
      this.m_elevationCoordinator = ElevationActuatorCoordinator.Create();
    };
    return this.m_elevationCoordinator;
  }

  /**
   * Lazily initializes and retrieves the SuppressionRuleEngine.
   * @return The SuppressionRuleEngine instance.
   */
  public func GetSuppressionEngine() -> ref<SuppressionRuleEngine> {
    if !IsDefined(this.m_suppressionEngine) {
      this.m_suppressionEngine = SuppressionRuleEngine.CreateDefault();
    };
    return this.m_suppressionEngine;
  }

  /**
   * Lazily initializes and retrieves the FootwearTelemetryLogger.
   * @return The FootwearTelemetryLogger instance.
   */
  public func GetTelemetry() -> ref<FootwearTelemetryLogger> {
    if !IsDefined(this.m_telemetry) {
      this.m_telemetry = FootwearTelemetryLogger.Create();
    };
    return this.m_telemetry;
  }

  /**
   * Lazily initializes and retrieves the FootwearCalibratorWindow UI.
   * @return The FootwearCalibratorWindow instance.
   */
  public func GetCalibratorWindow() -> ref<FootwearCalibratorWindow> {
    if !IsDefined(this.m_calibratorWindow) {
      this.m_calibratorWindow = FootwearCalibratorWindow.Create();
    };
    return this.m_calibratorWindow;
  }

  // -----------------------------------------------------------------------------
  // Lifecycle Handlers
  // -----------------------------------------------------------------------------

  /**
   * REDengine system attachment lifecycle callback. Initializes storage, config, and registers session callbacks.
   */
  private func OnAttach() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    this.InitStorageAndConfig();
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
  }

  /**
   * Session ready callback. Ensures storage configuration is loaded and starts RedWindows tick loop.
   * @param event Game session ready event payload.
   */
  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    this.InitStorageAndConfig();
    if !this.m_windowsLoopStarted {
      this.m_windowsLoopStarted = true;
      FootwearWindowsController.StartTick(this.GetGameInstance());
    };
  }

  /**
   * Player attachment callback triggered upon spawning into world. Re-evaluates equipped footwear.
   * @param request Player attach request object containing owner game.
   */
  private final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(request.owner.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      this.m_isInitialized = false;
      this.m_isInWorkspot = false;
      this.m_isInVehicle = false;
      this.m_isSuppressed = false;
      this.m_suppressionReason = "";
      this.InitStorageAndConfig();
      this.UpdateEquippedFootwear(player);
    };
  }

  /**
   * Savegame restoration lifecycle callback. Restores system baseline and updates equipped shoe state.
   * @param saveVersion Savefile version integer.
   * @param gameVersion Running game version integer.
   */
  public final func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      this.m_isInitialized = false;
      this.m_isInWorkspot = false;
      this.m_isInVehicle = false;
      this.m_isSuppressed = false;
      this.m_suppressionReason = "";
      this.InitStorageAndConfig();
      this.UpdateEquippedFootwear(player);
    };
  }

  // -----------------------------------------------------------------------------
  // Footwear Resolution & Height Update
  // -----------------------------------------------------------------------------

  /**
   * Evaluates the player's visible footwear via FootwearResolver, extracts tag or override heights, and recalculates elevation.
   * @param player The local player puppet reference.
   */
  public func UpdateEquippedFootwear(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) {
      FootwearRedLogger.LogError("SYSTEM", "UpdateEquippedFootwear: Player entity is undefined");
      return;
    };

    let result: ref<FootwearResolutionResult> = FootwearResolver.ResolveFootwear(player);
    let itemChanged: Bool = !this.m_isInitialized || NotEquals(result.itemID, this.m_equippedFootwearID);

    if itemChanged {
      this.m_isInitialized = true;
      this.m_equippedFootwearID = result.itemID;
      this.m_activeSource = result.sourceName;
      this.m_hasCustomOverride = false;
      this.m_customHeelHeight = 0.0;
      this.m_customPlatformHeight = 0.0;
    };

    if ItemID.IsValid(this.m_equippedFootwearID) {
      if itemChanged || (!this.m_hasOfficialTags && !this.m_hasCustomOverride) {
        let heightData: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(this.m_equippedFootwearID);
        
        if heightData.heelHeight > 0.0 || heightData.platformHeight > 0.0 {
          this.m_hasOfficialTags = true;
          this.m_hasCustomOverride = false;
          this.m_currentHeelHeight = heightData.heelHeight;
          this.m_currentPlatformHeight = heightData.platformHeight;
        } else {
          this.m_hasOfficialTags = false;
          let shoeKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(this.m_equippedFootwearID));
          let repo: ref<FootwearOverrideRepository> = this.GetOverrideRepository();
          if repo.Has(shoeKey) {
            this.m_hasCustomOverride = true;
            this.m_customHeelHeight = repo.GetHeel(shoeKey);
            this.m_customPlatformHeight = repo.GetPlatform(shoeKey);
            this.m_currentHeelHeight = this.m_customHeelHeight;
            this.m_currentPlatformHeight = this.m_customPlatformHeight;
          } else {
            this.m_hasCustomOverride = false;
            this.m_customHeelHeight = 0.0;
            this.m_customPlatformHeight = 0.0;
            this.m_currentHeelHeight = 0.0;
            this.m_currentPlatformHeight = 0.0;
          };
        };
      };
    } else {
      this.m_hasOfficialTags = false;
      this.m_hasCustomOverride = false;
      this.m_currentHeelHeight = 0.0;
      this.m_currentPlatformHeight = 0.0;
    };

    this.RecalculateEffectiveOffset(player);
    this.LogTFPState(player);
    this.NotifyFootwearChanged(this.m_equippedFootwearID, this.m_currentHeelHeight, this.m_currentPlatformHeight, this.m_activeSource);
  }

  /**
   * Recalculates effective elevation based on current suppression state and routes to the elevation coordinator.
   * @param player The local player puppet reference.
   */
  public func RecalculateEffectiveOffset(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) {
      FootwearRedLogger.LogError("SYSTEM", "RecalculateEffectiveOffset: Player entity is undefined");
      return;
    };

    let suppressed: Bool = this.EvaluateSuppressionState(player);
    this.m_effectiveOffset = suppressed ? 0.0 : FootwearClampingPolicy.ClampIFPHeight(this.m_currentHeelHeight);

    this.GetElevationCoordinator().Apply(
      player,
      this.m_currentHeelHeight,
      this.m_currentPlatformHeight,
      suppressed,
      this.m_config,
      this.m_debugLogging,
      this.m_suppressionReason
    );
  }

  // -----------------------------------------------------------------------------
  // Custom Overrides Map & Management (Delegated to FootwearOverrideRepository)
  // -----------------------------------------------------------------------------
  /**
   * Clears all custom shoe overrides from repository and resets active override variables if footwear lacks official tags.
   */
  public func ClearCustomOverrides() -> Void {
    this.GetOverrideRepository().Clear();
    if !this.m_hasOfficialTags {
      this.m_hasCustomOverride = false;
      this.m_customHeelHeight = 0.0;
      this.m_customPlatformHeight = 0.0;
      this.m_currentHeelHeight = 0.0;
      this.m_currentPlatformHeight = 0.0;
    };
  }

  /**
   * Finds the repository index for a shoe override key.
   * @param key Unique shoe identifier string.
   * @return Array index or -1 if not found.
   */
  public func FindCustomOverrideIndex(key: String) -> Int32 {
    return this.GetOverrideRepository().FindIndex(key);
  }

  /**
   * Registers or updates a shoe override in the repository and updates active state if matching equipped shoe.
   * @param key Unique shoe identifier string.
   * @param heel Raw heel height in meters.
   * @param platform Raw platform height in meters.
   */
  public func RegisterCustomOverride(key: String, heel: Float, platform: Float) -> Void {
    if StrLen(key) == 0 {
      return;
    };
    let clampedHeel: Float = FootwearClampingPolicy.ClampHeight(heel);
    let clampedPlat: Float = FootwearClampingPolicy.ClampPlatformHeight(platform);
    this.GetOverrideRepository().Register(key, clampedHeel, clampedPlat);

    if ItemID.IsValid(this.m_equippedFootwearID) {
      let currentKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(this.m_equippedFootwearID));
      if Equals(currentKey, key) || Equals(StrLower(currentKey), StrLower(key)) {
        if !this.m_hasOfficialTags {
          this.m_hasCustomOverride = true;
          this.m_customHeelHeight = clampedHeel;
          this.m_customPlatformHeight = clampedPlat;
          this.m_currentHeelHeight = clampedHeel;
          this.m_currentPlatformHeight = clampedPlat;
        };
      };
    };
  }

  /**
   * Removes a shoe override entry from the repository.
   * @param key Unique shoe identifier string to delete.
   */
  public func RemoveCustomOverride(key: String) -> Void {
    this.GetOverrideRepository().Remove(key);
  }

  /**
   * Bulk registers parallel arrays of keys, heels, and platforms into the override repository.
   * @param keys List of shoe identifier strings.
   * @param heels List of heel heights in meters.
   * @param platforms List of platform heights in meters.
   */
  public func SetCustomOverridesMap(keys: array<String>, heels: array<Float>, platforms: array<Float>) -> Void {
    this.ClearCustomOverrides();
    let count: Int32 = ArraySize(keys);
    let i: Int32 = 0;
    while i < count {
      this.RegisterCustomOverride(keys[i], heels[i], platforms[i]);
      i += 1;
    };
  }

  /**
   * Queries custom heel height for a shoe key.
   * @param key Unique shoe identifier string.
   * @return Heel height in meters, or 0.0 if not overridden.
   */
  public func GetCustomOverrideHeel(key: String) -> Float {
    return this.GetOverrideRepository().GetHeel(key);
  }

  /**
   * Queries custom platform height for a shoe key.
   * @param key Unique shoe identifier string.
   * @return Platform height in meters, or 0.0 if not overridden.
   */
  public func GetCustomOverridePlatform(key: String) -> Float {
    return this.GetOverrideRepository().GetPlatform(key);
  }

  /**
   * Checks whether a custom height override is registered for the specified shoe key.
   * @param key Unique shoe identifier string.
   * @return True if key is overridden, false otherwise.
   */
  public func HasCustomOverrideForKey(key: String) -> Bool {
    return this.GetOverrideRepository().Has(key);
  }

  /**
   * Calibrates and persists height overrides for currently equipped footwear.
   * @param player The local player puppet reference.
   * @param heel Heel height offset in meters.
   * @param platform Platform height offset in meters.
   * @param force True to override even if official tags exist.
   */
  public func SetCustomHeightOverride(player: ref<PlayerPuppet>, heel: Float, platform: Float, opt force: Bool) -> Void {
    if this.m_hasOfficialTags && !force {
      return;
    };

    this.m_hasCustomOverride = true;
    this.m_customHeelHeight = FootwearClampingPolicy.ClampHeight(heel);
    this.m_customPlatformHeight = FootwearClampingPolicy.ClampPlatformHeight(platform);
    this.m_currentHeelHeight = this.m_customHeelHeight;
    this.m_currentPlatformHeight = this.m_customPlatformHeight;

    if ItemID.IsValid(this.m_equippedFootwearID) {
      let shoeKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(this.m_equippedFootwearID));
      this.RegisterCustomOverride(shoeKey, this.m_customHeelHeight, this.m_customPlatformHeight);
    };

    this.RecalculateEffectiveOffset(player);
  }

  /**
   * Clears custom height override for the current footwear and restores tag or zero baseline.
   * @param player The local player puppet reference.
   * @param force True to force clear regardless of official tags.
   */
  public func ClearCustomHeightOverride(player: ref<PlayerPuppet>, opt force: Bool) -> Void {
    if !this.m_hasOfficialTags || force {
      this.m_hasCustomOverride = false;
      this.m_customHeelHeight = 0.0;
      this.m_customPlatformHeight = 0.0;
      if ItemID.IsValid(this.m_equippedFootwearID) {
        let shoeKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(this.m_equippedFootwearID));
        this.RemoveCustomOverride(shoeKey);
      };
      if !this.m_hasOfficialTags {
        this.m_currentHeelHeight = 0.0;
        this.m_currentPlatformHeight = 0.0;
      } else {
        let data: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(this.m_equippedFootwearID);
        this.m_currentHeelHeight = data.heelHeight;
        this.m_currentPlatformHeight = data.platformHeight;
      };
      this.RecalculateEffectiveOffset(player);
    };
  }

  // -----------------------------------------------------------------------------
  // Suppression State Management & Delegation
  // -----------------------------------------------------------------------------

  /**
   * Runs the SuppressionEvaluator to check vehicle, workspot, scene, and movement state.
   * @param player The local player puppet reference.
   * @return True if elevation is currently suppressed.
   */
  public func EvaluateSuppressionState(player: ref<PlayerPuppet>) -> Bool {
    return SuppressionEvaluator.Evaluate(this, player);
  }

  /**
   * Updates internal suppression state and notifies observers if changed.
   * @param suppressed True if elevation is suppressed.
   * @param reason Description of suppression trigger.
   * @return Current suppression boolean value.
   */
  public func SetSuppressionState(suppressed: Bool, reason: String) -> Bool {
    let changed: Bool = NotEquals(this.m_isSuppressed, suppressed) || NotEquals(this.m_suppressionReason, reason);
    this.m_isSuppressed = suppressed;
    this.m_suppressionReason = reason;
    if changed {
      this.NotifySuppressionChanged(suppressed, reason);
    };
    return this.m_isSuppressed;
  }

  /**
   * Sets vehicle occupancy state and updates camera elevation accordingly.
   * @param player The local player puppet reference.
   * @param inVehicle True if player entered vehicle, false if exited.
   */
  public func SetVehicleState(player: ref<PlayerPuppet>, inVehicle: Bool) -> Void {
    if Equals(this.m_isInVehicle, inVehicle) { return; };
    this.m_isInVehicle = inVehicle;
    if !inVehicle && Equals(this.m_suppressionReason, "Vehicle Occupancy") {
      this.m_isSuppressed = false;
      this.m_suppressionReason = "";
    };
    FootwearTelemetryLogger.LogVehicleState(this, inVehicle);
    this.RecalculateEffectiveOffset(player);
    if IsDefined(player) {
      let eventName: String = inVehicle ? "VehicleEntered (Vehicle Occupancy)" : "VehicleExited (Restored)";
      this.LogTFPEvent(eventName, 0.0, 0.0);
      this.LogTFPState(player);
    };
  }

  /**
   * Clears vehicle occupancy suppression when auto-recovery detects player on foot.
   * @param player The local player puppet reference.
   */
  public func ClearVehicleState(player: ref<PlayerPuppet>) -> Void {
    if !this.m_isInVehicle { return; };
    this.m_isInVehicle = false;
    if Equals(this.m_suppressionReason, "Vehicle Occupancy") {
      this.m_isSuppressed = false;
      this.m_suppressionReason = "";
    };
    FootwearTelemetryLogger.LogVehicleAutoRecovered(this);
    this.RecalculateEffectiveOffset(player);
    if IsDefined(player) {
      this.LogTFPEvent("VehicleAutoRecovered (Exited)", 0.0, 0.0);
      this.LogTFPState(player);
    };
  }

  /**
   * Sets authored workspot animation state (sitting, furniture) and updates camera offset.
   * @param player The local player puppet reference.
   * @param inWorkspot True if player entered workspot, false if exited.
   */
  public func SetWorkspotState(player: ref<PlayerPuppet>, inWorkspot: Bool) -> Void {
    if Equals(this.m_isInWorkspot, inWorkspot) { return; };
    this.m_isInWorkspot = inWorkspot;
    if !inWorkspot && Equals(this.m_suppressionReason, "Authored Workspot") {
      this.m_isSuppressed = false;
      this.m_suppressionReason = "";
    };
    FootwearTelemetryLogger.LogWorkspotState(this, inWorkspot);
    this.RecalculateEffectiveOffset(player);
    if IsDefined(player) {
      let eventName: String = inWorkspot ? "WorkspotStarted (Sitting/Furniture)" : "WorkspotFinished (Standing/Exited)";
      this.LogTFPEvent(eventName, 0.0, 0.0);
      this.LogTFPState(player);
    };
  }

  /**
   * Clears workspot suppression when auto-recovery detects player standing up.
   * @param player The local player puppet reference.
   */
  public func ClearWorkspotState(player: ref<PlayerPuppet>) -> Void {
    if !this.m_isInWorkspot { return; };
    this.m_isInWorkspot = false;
    if Equals(this.m_suppressionReason, "Authored Workspot") {
      this.m_isSuppressed = false;
      this.m_suppressionReason = "";
    };
    FootwearTelemetryLogger.LogWorkspotAutoRecovered(this);
    this.RecalculateEffectiveOffset(player);
    if IsDefined(player) {
      this.LogTFPEvent("WorkspotAutoRecovered (Standing/Exited)", 0.0, 0.0);
      this.LogTFPState(player);
    };
  }

  /**
   * Handles weapon aiming/holstering actions by synchronizing weapon ADS with footwear lift.
   * @param player The local player puppet reference.
   * @param actionName Name of the weapon action.
   */
  public func OnWeaponAction(player: ref<PlayerPuppet>, actionName: String) -> Void {
    if !IsDefined(player) { return; };
    TFPHelper.SyncWeaponForCurrentFootwear(player.GetGame());
    this.LogTFPEvent(s"WeaponAction (\(actionName))", 0.0, 0.0);
    this.LogTFPState(player);
  }

  // -----------------------------------------------------------------------------
  // State Queries & Getters
  // -----------------------------------------------------------------------------

  /**
   * Checks whether footwear elevation is currently suppressed.
   * @return True if suppressed, false if elevation is active.
   */
  public func IsSuppressed() -> Bool { return this.m_isSuppressed; }

  /**
   * Retrieves the human-readable explanation of why elevation was suppressed.
   * @return Suppression trigger string.
   */
  public func GetSuppressionReason() -> String { return this.m_suppressionReason; }

  /**
   * Retrieves the raw unsuppressed heel height in meters.
   * @return Heel height in meters.
   */
  public func GetCurrentHeelHeight() -> Float { return this.m_currentHeelHeight; }

  /**
   * Retrieves the raw unsuppressed platform height in meters.
   * @return Platform height in meters.
   */
  public func GetCurrentPlatformHeight() -> Float { return this.m_currentPlatformHeight; }

  /**
   * Retrieves the active effective elevation offset in meters (0.0m if suppressed).
   * @return Effective offset in meters.
   */
  public func GetEffectiveOffset() -> Float { return this.m_effectiveOffset; }

  /**
   * Retrieves the effective platform offset in meters (0.0m if suppressed).
   * @return Effective platform offset in meters.
   */
  public func GetEffectivePlatformOffset() -> Float {
    if this.m_isSuppressed {
      return 0.0;
    };
    return this.m_currentPlatformHeight;
  }

  /**
   * Checks whether the current footwear has official TweakDB tags defining height.
   * @return True if official tags exist on the item record.
   */
  public func HasOfficialTweakTags() -> Bool { return this.m_hasOfficialTags; }

  /**
   * Checks whether the current footwear is actively using a user-calibrated custom override.
   * @return True if using custom override.
   */
  public func HasCustomOverride() -> Bool { return this.m_hasCustomOverride; }

  /**
   * Retrieves the ItemID of the currently resolved equipped footwear.
   * @return Equipped footwear ItemID.
   */
  public func GetEquippedFootwearID() -> ItemID { return this.m_equippedFootwearID; }

  /**
   * Retrieves the descriptor of the source layer resolving the footwear (e.g. "Equipment-EX", "Vanilla Wardrobe").
   * @return Source name string.
   */
  public func GetActiveSource() -> String { return this.m_activeSource; }

  /**
   * Checks whether player is currently flagged as seated in a vehicle.
   * @return True if in vehicle.
   */
  public func IsInVehicle() -> Bool { return this.m_isInVehicle; }

  /**
   * Checks whether player is currently flagged in an authored workspot animation.
   * @return True if in workspot.
   */
  public func IsInWorkspot() -> Bool { return this.m_isInWorkspot; }

  /**
   * Checks whether verbose debug logging is enabled.
   * @return True if debug logging is enabled.
   */
  public func IsDebugLogging() -> Bool { return this.m_debugLogging; }

  /**
   * Enables or disables verbose debug logging.
   * @param enable True to enable debug logging.
   */
  public func SetDebugLogging(enable: Bool) -> Void { this.m_debugLogging = enable; }

  /**
   * Checks whether Photo Mode is currently active in the game session.
   * @return True if Photo Mode is active.
   */
  public func IsPhotoModeActive() -> Bool {
    let pmSys: ref<PhotoModeSystem> = GameInstance.GetPhotoModeSystem(this.GetGameInstance());
    if IsDefined(pmSys) {
      return pmSys.IsPhotoModeActive();
    };
    return this.m_isPhotoModeActive;
  }

  /**
   * Explicitly sets the internal Photo Mode state flag.
   * @param active True if Photo Mode activated.
   */
  public func SetPhotoModeActive(active: Bool) -> Void { this.m_isPhotoModeActive = active; }

  /**
   * Checks whether Immersive First Person (IFP) is present.
   * @return True if IFP is available.
   */
  public func IsIFPPresent() -> Bool { return this.m_isIFPPresent; }

  /**
   * Sets the IFP presence flag.
   * @param present True if IFP detected.
   */
  public func SetIFPPresent(present: Bool) -> Void { this.m_isIFPPresent = present; }

  /**
   * Checks whether Immersive Third Person (ITP) is present in the game instance (cached).
   * @return True if ITP is available.
   */
  public func IsITPPresent() -> Bool {
    if !this.m_isITPChecked {
      this.m_isITPChecked = true;
      this.m_isITPPresent = ITPDetector.IsPresent(this.GetGameInstance());
    };
    return this.m_isITPPresent;
  }

  /**
   * Sets the ITP presence flag and marks presence as checked.
   * @param present True if ITP detected.
   */
  public func SetITPPresent(present: Bool) -> Void {
    this.m_isITPPresent = present;
    this.m_isITPChecked = true;
  }
  /**
   * Checks whether third-person camera is actively rendering for the player.
   * @param player The local player puppet reference.
   * @return True if in third-person view.
   */
  public func IsTPPActive(player: ref<PlayerPuppet>) -> Bool {
    return ITPController.IsTPPActive(player);
  }

  // -----------------------------------------------------------------------------
  // Feminine Locomotion & Catwalk Sway Context
  // -----------------------------------------------------------------------------

  /**
   * Evaluates and updates the shared SwayContextData container for the player.
   * @param player The local player puppet reference.
   * @return Current SwayContextData instance.
   */
  public func GetSwayContext(player: ref<PlayerPuppet>) -> ref<SwayContextData> {
    if !IsDefined(this.m_swayContext) {
      this.m_swayContext = new SwayContextData();
    };
    return SwayEvaluator.EvaluateInto(this, player, this.m_swayContext);
  }

  /**
   * Computes effective heel pitch inclination in meters (heel minus platform).
   * @return Heel pitch in meters.
   */
  public func GetEffectiveHeelPitch() -> Float {
    return MaxF(0.0, this.m_currentHeelHeight - this.m_currentPlatformHeight);
  }

  /**
   * Lazily initializes and retrieves the StrideController.
   * @return The StrideController instance.
   */
  public func GetStrideController() -> ref<StrideController> {
    if !IsDefined(this.m_strideController) {
      this.m_strideController = StrideController.Create();
    };
    return this.m_strideController;
  }

  /**
   * Dispatches frame update to StrideController once per unique engine render frame.
   * @param player Local player puppet reference.
   * @param deltaTime Elapsed delta frame time in seconds.
   * @param enabled True if sway simulation is active.
   * @param intensityLow Low heel tier intensity multiplier.
   * @param intensityMid Mid heel tier intensity multiplier.
   * @param intensityHigh High heel tier intensity multiplier.
   * @param isOverlayOpen True if diagnostics HUD or calibrator window is visible.
   */
  public func UpdateStride(player: ref<PlayerPuppet>, deltaTime: Float, enabled: Bool, intensityLow: Float, intensityMid: Float, intensityHigh: Float, isOverlayOpen: Bool) -> Void {
    if !enabled || !IsDefined(player) || deltaTime <= 0.0 {
      return;
    };
    let currentFrame: Uint64 = GameInstance.GetFrameNumber(player.GetGame());
    if currentFrame == this.m_lastStrideFrame {
      return;
    };
    this.m_lastStrideFrame = currentFrame;
    this.GetStrideController().Update(this, player, deltaTime, enabled, intensityLow, intensityMid, intensityHigh, isOverlayOpen);
  }

  /**
   * Resets stride locomotion simulation phase and publishes zero state to player animgraph.
   * @param player The local player puppet reference.
   */
  public func ResetStride(player: ref<PlayerPuppet>) -> Void {
    if IsDefined(this.m_strideController) {
      this.m_strideController.Reset(player);
    };
  }

  /**
   * Retrieves the current diagnostic text from StrideController.
   * @return Diagnostic status string.
   */
  public func GetStrideStatus() -> String { return IsDefined(this.m_strideController) ? this.m_strideController.GetStatusText() : "Idle"; }

  /**
   * Retrieves current pelvic roll rotation in degrees from StrideController.
   * @return Pelvic roll in degrees.
   */
  public func GetStrideRoll() -> Float { return IsDefined(this.m_strideController) ? this.m_strideController.GetCurrentRoll() : 0.0; }

  /**
   * Retrieves current pelvic yaw swivel rotation in degrees from StrideController.
   * @return Pelvic yaw in degrees.
   */
  public func GetStrideYaw() -> Float { return IsDefined(this.m_strideController) ? this.m_strideController.GetCurrentYaw() : 0.0; }

  /**
   * Retrieves current sway blend weight from StrideController.
   * @return Normalized blend weight between 0.0 and 1.0.
   */
  public func GetStrideBlend() -> Float { return IsDefined(this.m_strideController) ? this.m_strideController.GetCurrentBlend() : 0.0; }

  /**
   * Retrieves current leg counter-roll angle in degrees from StrideController.
   * @return Counter-roll angle in degrees.
   */
  public func GetStrideLegCounterRoll() -> Float { return IsDefined(this.m_strideController) ? this.m_strideController.GetCurrentLegCounterRoll() : 0.0; }

  /**
   * Retrieves current heel scale factor from StrideController.
   * @return Normalized scale factor.
   */
  public func GetStrideHeelScale() -> Float { return IsDefined(this.m_strideController) ? this.m_strideController.GetCurrentHeelScale() : 0.0; }

  /**
   * Retrieves current effective heel pitch in cm from StrideController.
   * @return Heel pitch in cm.
   */
  public func GetStridePitchCm() -> Float { return IsDefined(this.m_strideController) ? this.m_strideController.GetCurrentPitchCm() : 0.0; }

  // -----------------------------------------------------------------------------
  // Display & Localization Helpers (Delegated to FootwearDisplayHelper)
  // -----------------------------------------------------------------------------

  /**
   * Formats debug TweakDB ID string for equipped footwear.
   * @return Debug TDBID string.
   */
  public func GetResolvedShoeTDBIDString() -> String {
    return FootwearDisplayHelper.GetResolvedShoeTDBIDString(this.m_equippedFootwearID);
  }

  /**
   * Resolves localized display name for equipped footwear.
   * @return Human-readable shoe name.
   */
  public func GetResolvedShoeDisplayName() -> String {
    return FootwearDisplayHelper.GetResolvedShoeDisplayName(this.m_equippedFootwearID);
  }

  // -----------------------------------------------------------------------------
  // Public ShoeHeightParser Helpers
  // -----------------------------------------------------------------------------

  /**
   * Reads platform height in meters from an ItemID.
   * @param itemID Footwear item identifier.
   * @return Platform height in meters.
   */
  public func ReadPlatformHeightFromItemID(itemID: ItemID) -> Float {
    return ShoeHeightParser.ReadPlatformHeight(itemID);
  }

  /**
   * Reads heel height in meters from an ItemID.
   * @param itemID Footwear item identifier.
   * @return Heel height in meters.
   */
  public func ReadHeelHeightFromItemID(itemID: ItemID) -> Float {
    return ShoeHeightParser.ReadHeelHeight(itemID);
  }

  /**
   * Reads platform height in meters from a TweakDBID.
   * @param tdbid Item record TweakDB ID.
   * @return Platform height in meters.
   */
  public func ReadPlatformHeightFromTDBID(tdbid: TweakDBID) -> Float {
    return ShoeHeightParser.ReadShoeHeightDataFromTDBID(tdbid).platformHeight;
  }

  /**
   * Reads heel height in meters from a TweakDBID.
   * @param tdbid Item record TweakDB ID.
   * @return Heel height in meters.
   */
  public func ReadHeelHeightFromTDBID(tdbid: TweakDBID) -> Float {
    return ShoeHeightParser.ReadShoeHeightDataFromTDBID(tdbid).heelHeight;
  }

  /**
   * Queries footwear ItemID from a specific Equipment-EX outfit.
   * @param outfitName Name of the outfit record.
   * @return Footwear ItemID or ItemID.None().
   */
  public func ReadFootwearFromEquipmentExOutfit(outfitName: CName) -> ItemID {
    return EquipmentExHelper.GetFootwearFromOutfit(this.GetGameInstance(), outfitName);
  }

  // -----------------------------------------------------------------------------
  // Framework Detection & Active Mod Tagging
  // -----------------------------------------------------------------------------

  /**
   * Checks whether True First Person (TFP) is installed.
   * @return True if TFP is present.
   */
  public func IsTFPPresent() -> Bool {
    return FrameworkDetector.IsTFPPresent();
  }

  /**
   * Checks whether Equipment-EX is installed.
   * @return True if EquipmentEx is present.
   */
  public func IsEquipmentExPresent() -> Bool {
    return EquipmentExDetector.IsPresent();
  }

  /**
   * Resolves the active camera or framework integration acronym tag (PM, ITP, TFP, IFP).
   * @param player Local player puppet reference.
   * @return 2-3 letter framework acronym string.
   */
  public func GetActiveModTag(opt player: ref<PlayerPuppet>) -> String {
    if this.IsPhotoModeActive() {
      return "PM";
    };
    if this.IsITPPresent() {
      return "ITP";
    };
    if this.IsTFPPresent() {
      return "TFP";
    };
    if this.m_isIFPPresent {
      return "IFP";
    };
    return "PM";
  }

  // -----------------------------------------------------------------------------
  // Telemetry Logger Delegation
  // -----------------------------------------------------------------------------

  /**
   * Forwards discrete TFP camera lifecycle events to the telemetry logger.
   * @param eventName Name of the lifecycle event.
   * @param baseZ Base camera Z in meters.
   * @param curZ Current camera Z in meters.
   */
  public func LogTFPEvent(eventName: String, baseZ: Float, curZ: Float) -> Void {
    this.GetTelemetry().LogTFPEvent(this, eventName, baseZ, curZ);
  }

  /**
   * Forwards continuous TFP camera polling state to the telemetry logger.
   * @param baseZ Base camera Z in meters.
   * @param curZ Current camera Z in meters.
   */
  public func LogTFPPolling(baseZ: Float, curZ: Float) -> Void {
    this.GetTelemetry().LogTFPPolling(this, baseZ, curZ);
  }

  /**
   * Forwards instantaneous TFP camera state log request.
   * @param player The local player puppet reference.
   */
  public func LogTFPState(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) || !this.m_debugLogging { return; };
    TFPHelper.LogState(player);
  }

  // -----------------------------------------------------------------------------
  // Observer Pattern Delegation (FootwearEventDispatcher)
  // -----------------------------------------------------------------------------

  /**
   * Registers a composite listener for footwear, suppression, and config events.
   * @param listener The composite state listener to add.
   */
  public func RegisterListener(listener: ref<IFootwearStateListener>) -> Void {
    this.GetEventDispatcher().RegisterListener(listener);
  }

  /**
   * Unregisters a composite state listener.
   * @param listener The composite state listener to remove.
   */
  public func UnregisterListener(listener: ref<IFootwearStateListener>) -> Void {
    this.GetEventDispatcher().UnregisterListener(listener);
  }

  /**
   * Registers a footwear change listener.
   * @param l Footwear change listener instance.
   */
  public func RegisterFootwearListener(l: ref<IFootwearChangeListener>) -> Void {
    this.GetEventDispatcher().RegisterFootwearListener(l);
  }

  /**
   * Unregisters a footwear change listener.
   * @param l Footwear change listener instance.
   */
  public func UnregisterFootwearListener(l: ref<IFootwearChangeListener>) -> Void {
    this.GetEventDispatcher().UnregisterFootwearListener(l);
  }

  /**
   * Registers a suppression state listener.
   * @param l Suppression change listener instance.
   */
  public func RegisterSuppressionListener(l: ref<ISuppressionChangeListener>) -> Void {
    this.GetEventDispatcher().RegisterSuppressionListener(l);
  }

  /**
   * Unregisters a suppression state listener.
   * @param l Suppression change listener instance.
   */
  public func UnregisterSuppressionListener(l: ref<ISuppressionChangeListener>) -> Void {
    this.GetEventDispatcher().UnregisterSuppressionListener(l);
  }

  /**
   * Registers a configuration update listener.
   * @param l Configuration change listener instance.
   */
  public func RegisterConfigListener(l: ref<IConfigChangeListener>) -> Void {
    this.GetEventDispatcher().RegisterConfigListener(l);
  }

  /**
   * Unregisters a configuration update listener.
   * @param l Configuration change listener instance.
   */
  public func UnregisterConfigListener(l: ref<IConfigChangeListener>) -> Void {
    this.GetEventDispatcher().UnregisterConfigListener(l);
  }

  /**
   * Dispatches footwear change event to registered listeners.
   * @param itemID Footwear ItemID.
   * @param heel Heel height offset in meters.
   * @param platform Platform height offset in meters.
   * @param source Identification tag of resolution source.
   */
  private func NotifyFootwearChanged(itemID: ItemID, heel: Float, platform: Float, source: String) -> Void {
    this.GetEventDispatcher().NotifyFootwearChanged(itemID, heel, platform, source);
  }

  /**
   * Dispatches suppression change event to registered listeners.
   * @param suppressed True if elevation is suppressed.
   * @param reason Human-readable suppression reason string.
   */
  private func NotifySuppressionChanged(suppressed: Bool, reason: String) -> Void {
    this.GetEventDispatcher().NotifySuppressionChanged(suppressed, reason);
  }

  /**
   * Dispatches configuration update event to registered listeners.
   * @param config The updated FootwearConfig instance.
   */
  private func NotifyConfigChanged(config: ref<FootwearConfig>) -> Void {
    this.GetEventDispatcher().NotifyConfigChanged(config);
  }

  // -----------------------------------------------------------------------------
  // Storage & Mod Configuration Lifecycle
  // -----------------------------------------------------------------------------

  /**
   * Initializes persistent storage, loads config and presets, and binds RCF/RedWindows providers.
   */
  public func InitStorageAndConfig() -> Void {
    if !IsDefined(this.m_config) {
      this.m_config = FootwearConfig.CreateDefault();
    };

    if !this.m_isStorageLoaded {
      this.m_isStorageLoaded = true;
      let storageMgr: ref<FootwearStorageManager> = FootwearStorageManager.GetInstance();
      storageMgr.LoadConfig(this.m_config);
      LegacyCetMigrationService.MigrateIfNeeded(storageMgr, this.m_config);
      storageMgr.LoadMasterPresetsIntoRepo(this.GetOverrideRepository());
      storageMgr.LoadUserOverridesIntoRepo(this.GetOverrideRepository());
    };

    this.m_debugLogging = this.m_config.debugLogs;

    let gi: GameInstance = this.GetGameInstance();
    if !this.m_isRcfRegistered {
      this.m_isRcfRegistered = true;
      FootwearRCFProvider.Register(gi, this.m_config, this);
    };

    FootwearWindowsController.Init(gi);
  }

  /**
   * Retrieves active user configuration reference.
   * @return FootwearConfig instance.
   */
  public func GetConfig() -> ref<FootwearConfig> {
    if !IsDefined(this.m_config) {
      this.m_config = FootwearConfig.CreateDefault();
    };
    return this.m_config;
  }

  /**
   * Handles configuration update from Redmodded Configuration Framework (RCF) or UI.
   * @param config Updated FootwearConfig instance.
   */
  public func OnConfigUpdated(config: ref<FootwearConfig>) -> Void {
    if IsDefined(config) {
      this.m_config = config;
      this.m_debugLogging = config.debugLogs;
      this.NotifyConfigChanged(config);
      let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
      if IsDefined(player) {
        this.RecalculateEffectiveOffset(player);
      };
    };
  }

  // -----------------------------------------------------------------------------
  // Real-Time Calibration & Live Preview (RedWindows)
  // -----------------------------------------------------------------------------

  /**
   * Applies live preview elevation adjustments during calibration window slider manipulation.
   * @param heel Temporary preview heel height in meters.
   * @param platform Temporary preview platform height in meters.
   */
  public func ApplyLiveCalibration(heel: Float, platform: Float) -> Void {
    this.m_hasCustomOverride = true;
    this.m_customHeelHeight = FootwearClampingPolicy.ClampHeight(heel);
    this.m_customPlatformHeight = FootwearClampingPolicy.ClampPlatformHeight(platform);
    this.m_currentHeelHeight = this.m_customHeelHeight;
    this.m_currentPlatformHeight = this.m_customPlatformHeight;

    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      this.RecalculateEffectiveOffset(player);
    };
    this.NotifyFootwearChanged(this.m_equippedFootwearID, this.m_currentHeelHeight, this.m_currentPlatformHeight, "Live Calibration");
  }

  /**
   * Clears custom height override and reverts currently equipped footwear to tag or zero baseline.
   */
  public func RevertFootwearToDefault() -> Void {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      this.ClearCustomHeightOverride(player, true);
      this.UpdateEquippedFootwear(player);
    };
  }

  /**
   * Checks whether initial geometry has been applied to the diagnostics window.
   *
   * @return True if geometry was applied, false otherwise.
   */
  public func IsDiagGeoApplied() -> Bool {
    return this.m_diagGeoApplied;
  }

  /**
   * Sets the flag indicating whether initial geometry has been applied to the diagnostics window.
   *
   * @param applied True if applied, false otherwise.
   */
  public func SetDiagGeoApplied(applied: Bool) -> Void {
    this.m_diagGeoApplied = applied;
  }

  /**
   * Checks whether initial geometry has been applied to the calibrator window.
   *
   * @return True if geometry was applied, false otherwise.
   */
  public func IsCalibGeoApplied() -> Bool {
    return this.m_calibGeoApplied;
  }

  /**
   * Sets the flag indicating whether initial geometry has been applied to the calibrator window.
   *
   * @param applied True if applied, false otherwise.
   */
  public func SetCalibGeoApplied(applied: Bool) -> Void {
    this.m_calibGeoApplied = applied;
  }
}
