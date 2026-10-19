module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Core ScriptableSystem Coordinator
// Design Pattern: Facade / Coordinator Pattern
// Single Responsibility Principle (SRP):
// Acts as the central REDengine ScriptableSystem coordinator, delegating domain
// operations to specialized repositories, rule engines, actuators, and dispatchers.
// =============================================================================

// -----------------------------------------------------------------------------
// Post-Restore / Post-Attach Delayed Initialization Callback
// Ensures late-streaming outfit components, Equipment-EX, and camera setup complete
// -----------------------------------------------------------------------------
public class FootwearPostRestoreTick extends DelayCallback {
  public let m_system: wref<ImmersiveFootwearPOVSystem>;

  public static func Create(sys: ref<ImmersiveFootwearPOVSystem>) -> ref<FootwearPostRestoreTick> {
    let cb: ref<FootwearPostRestoreTick> = new FootwearPostRestoreTick();
    cb.m_system = sys;
    return cb;
  }

  public func Call() -> Void {
    if !IsDefined(this.m_system) {
      return;
    };
    this.m_system.OnPostRestoreTick();
  }
}

// -----------------------------------------------------------------------------
// Debounced Footwear Update Callback
// Consolidates rapid-fire equip/unequip events and prevents transient barefoot logs
// -----------------------------------------------------------------------------
public class FootwearDebounceCallback extends DelayCallback {
  public let m_system: wref<ImmersiveFootwearPOVSystem>;

  public static func Create(sys: ref<ImmersiveFootwearPOVSystem>) -> ref<FootwearDebounceCallback> {
    let cb: ref<FootwearDebounceCallback> = new FootwearDebounceCallback();
    cb.m_system = sys;
    return cb;
  }

  public func Call() -> Void {
    if !IsDefined(this.m_system) {
      return;
    };
    this.m_system.OnDebouncedFootwearTick();
  }
}

public class ImmersiveFootwearPOVSystem extends ScriptableSystem {

  // Authoritative State Model
  private let m_equipmentState: ref<FootwearEquipmentState>;
  private let m_isInitialized: Bool;
  private let m_debugLogging: Bool;
  private let m_isStorageLoaded: Bool;
  private let m_lastTppActive: Bool;
  private let m_hasTppInitialized: Bool;
  private let m_driftCheckTimer: Float;
  private let m_swayContext: ref<SwayContextData>;
  private let m_lastStrideFrame: Uint64;
  private let m_lastLocoFrame: Uint64;
  private let m_isRcfRegistered: Bool;
  private let m_config: ref<FootwearConfig>;

  // Debouncing & Deduplication State
  private let m_debouncePending: Bool;
  private let m_postRestorePending: Bool;
  private let m_hasDirtyOverride: Bool;
  private let m_dirtyOverrideKey: String;
  private let m_dirtyOverrideHeel: Float;
  private let m_dirtyOverridePlat: Float;
  private let m_lastLoggedFootwearID: ItemID;
  private let m_lastLoggedSource: String;
  private let m_lastLoggedLayer: String;
  private let m_lastLoggedHeel: Float;
  private let m_lastLoggedPlatform: Float;
  private let m_hasLoggedFootwearOnce: Bool;

  // Domain Collaborators (Inversion of Control & Encapsulation)
  private let m_calibrationService: ref<FootwearCalibrationService>;
  private let m_suppressionController: ref<SuppressionStateController>;
  private let m_frameworkService: ref<FrameworkIntegrationService>;
  private let m_windowsController: ref<FootwearWindowsController>;
  private let m_overrideRepo: ref<FootwearOverrideRepository>;
  private let m_storageManager: ref<FootwearStorageManager>;
  private let m_eventDispatcher: ref<FootwearEventDispatcher>;
  private let m_elevationCoordinator: ref<ElevationActuatorCoordinator>;
  private let m_strideController: ref<StrideController>;
  private let m_telemetry: ref<FootwearTelemetryLogger>;

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
   * Lazily initializes and retrieves the FootwearEquipmentState value container.
   * @return The active FootwearEquipmentState instance.
   */
  public func GetEquipmentState() -> ref<FootwearEquipmentState> {
    if !IsDefined(this.m_equipmentState) {
      this.m_equipmentState = FootwearEquipmentState.Create();
    };
    return this.m_equipmentState;
  }

  /**
   * Lazily initializes and retrieves the FootwearCalibrationService.
   * @return The FootwearCalibrationService domain collaborator.
   */
  public func GetCalibrationService() -> ref<FootwearCalibrationService> {
    if !IsDefined(this.m_calibrationService) {
      this.m_calibrationService = FootwearCalibrationService.Create();
    };
    return this.m_calibrationService;
  }

  /**
   * Lazily initializes and retrieves the SuppressionStateController.
   * @return The SuppressionStateController state machine instance.
   */
  public func GetSuppressionController() -> ref<SuppressionStateController> {
    if !IsDefined(this.m_suppressionController) {
      this.m_suppressionController = SuppressionStateController.Create();
    };
    return this.m_suppressionController;
  }

  /**
   * Lazily initializes and retrieves the FrameworkIntegrationService.
   * @return The FrameworkIntegrationService adapter instance.
   */
  public func GetFrameworkService() -> ref<FrameworkIntegrationService> {
    if !IsDefined(this.m_frameworkService) {
      this.m_frameworkService = FrameworkIntegrationService.Create();
    };
    return this.m_frameworkService;
  }

  /**
   * Lazily initializes and retrieves the FootwearWindowsController UI facade.
   * @return The FootwearWindowsController instance.
   */
  public func GetWindowsController() -> ref<FootwearWindowsController> {
    if !IsDefined(this.m_windowsController) {
      this.m_windowsController = FootwearWindowsController.Create();
    };
    return this.m_windowsController;
  }

  /**
   * Lazily initializes and retrieves the shared FootwearStorageManager handle.
   * @return The FootwearStorageManager instance.
   */
  public func GetStorageManager() -> ref<FootwearStorageManager> {
    if !IsDefined(this.m_storageManager) {
      this.m_storageManager = FootwearStorageManager.Create();
    };
    return this.m_storageManager;
  }

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
   * Lazily initializes and retrieves the underlying SuppressionRuleEngine.
   * @return The active SuppressionRuleEngine instance.
   */
  public func GetSuppressionEngine() -> ref<SuppressionRuleEngine> {
    return this.GetSuppressionController().GetRuleEngine();
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
    return this.GetWindowsController().GetCalibratorWindow();
  }

  // -----------------------------------------------------------------------------
  // Lifecycle Handlers
  // -----------------------------------------------------------------------------

  /**
   * REDengine system attachment lifecycle callback. Initializes storage, config, and registers session callbacks.
   */
  private func OnAttach() -> Void {
    this.InitConfigAndRCF();
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
  }

  /**
   * Session ready callback. Ensures storage configuration and shoe presets are loaded and starts RedWindows tick loop.
   * @param event Game session ready event payload.
   */
  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    this.InitConfigAndRCF();
    this.EnsurePresetsAndOverridesLoaded();
    FootwearWindowsController.StartTick(this.GetGameInstance());
  }

  /**
   * Player attachment callback triggered upon spawning into world. Re-evaluates equipped footwear.
   * @param request Player attach request object containing owner game.
   */
  private final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    if !IsDefined(request) || !IsDefined(request.owner) {
      return;
    };
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(request.owner.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return;
    };
    this.m_isInitialized = false;
    this.m_hasTppInitialized = false;
    this.GetSuppressionController().Reset();
    this.EnsurePresetsAndOverridesLoaded();
    this.UpdateEquippedFootwear(player);
    this.QueuePostRestoreTick();
    FootwearWindowsController.StartTick(this.GetGameInstance());
  }

  /**
   * Savegame restoration lifecycle callback. Restores system baseline and updates equipped shoe state.
   * @param saveVersion Savefile version integer.
   * @param gameVersion Running game version integer.
   */
  public final func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return;
    };
    this.m_isInitialized = false;
    this.m_hasTppInitialized = false;
    this.GetSuppressionController().Reset();
    this.EnsurePresetsAndOverridesLoaded();
    this.UpdateEquippedFootwear(player);
    this.QueuePostRestoreTick();
    FootwearWindowsController.StartTick(this.GetGameInstance());
  }

  /**
   * Schedules a delayed callback after player attachment or save load to evaluate footwear
   * after streaming systems, Equipment-EX, and wardrobe appearances have finished instantiating.
   */
  public func QueuePostRestoreTick() -> Void {
    if this.m_postRestorePending {
      return;
    };
    this.m_postRestorePending = true;
    let cb: ref<FootwearPostRestoreTick> = FootwearPostRestoreTick.Create(this);
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, 0.40, false);
  }

  /**
   * Schedules a debounced footwear evaluation tick (0.10s delay).
   * Consolidates multi-hook bursts and transient empty slots during clothing swap transitions.
   */
  public func QueueDebouncedUpdate() -> Void {
    if this.m_debouncePending {
      return;
    };
    this.m_debouncePending = true;
    let cb: ref<FootwearDebounceCallback> = FootwearDebounceCallback.Create(this);
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, 0.10, false);
  }

  /**
   * Callback executed after debounce delay expires. Performs authoritative footwear re-evaluation.
   */
  public func OnDebouncedFootwearTick() -> Void {
    this.m_debouncePending = false;
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return;
    };
    this.CheckPerspectiveDrift(player);
    this.UpdateEquippedFootwear(player);
  }

  /**
   * Delayed callback executing 0.4s after load/attach/menu exit to re-evaluate footwear and elevation with full assets loaded.
   */
  public func OnPostRestoreTick() -> Void {
    this.m_postRestorePending = false;
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return;
    };
    this.EnsurePresetsAndOverridesLoaded();
    this.UpdateEquippedFootwear(player);
    this.CheckPerspectiveDrift(player);
    this.RecalculateEffectiveOffset(player);
  }

  /**
   * Detects whether the active camera perspective transitioned between FPP and TPP, triggering elevation recalculation.
   * @param player The local player puppet reference.
   */
  public func CheckPerspectiveDrift(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) { return; };
    let isTPP: Bool = ITPController.IsTPPActive(player, this.m_lastTppActive);
    if this.m_hasTppInitialized && Equals(isTPP, this.m_lastTppActive) {
      return;
    };
    this.m_hasTppInitialized = true;
    this.m_lastTppActive = isTPP;
    this.RecalculateEffectiveOffset(player);
  }

  /**
   * Frame tick called by locomotion state machine transition to evaluate dynamic perspective drift and hip sway.
   * Deduplicates execution per render frame to prevent synthetic timer acceleration across state machine sub-transitions.
   * @param player The local player puppet reference.
   * @param timeDelta Frame delta time in seconds.
   */
  public func OnLocomotionUpdate(player: ref<PlayerPuppet>, timeDelta: Float) -> Void {
    if !IsDefined(player) { return; };

    let currentFrame: Uint64 = GameInstance.GetFrameNumber(player.GetGame());
    if currentFrame == this.m_lastLocoFrame {
      return;
    };
    this.m_lastLocoFrame = currentFrame;

    this.m_driftCheckTimer += timeDelta;
    if this.m_driftCheckTimer >= 1.50 {
      this.m_driftCheckTimer = 0.0;
      this.CheckPerspectiveDrift(player);
    };

    let cfg: ref<FootwearConfig> = this.GetConfig();
    if !IsDefined(cfg) || !cfg.enableHipSway || !this.m_lastTppActive {
      return;
    };
    this.UpdateStride(player, timeDelta, cfg.enableHipSway, cfg.swayLow, cfg.swayMid, cfg.swayHigh, false);
  }

  // -----------------------------------------------------------------------------
  // High-Level Footwear Coordination
  // -----------------------------------------------------------------------------

  /**
   * Evaluates the player's visible footwear via FootwearCalibrationService and recalculates elevation.
   * @param player The local player puppet reference.
   */
  public func UpdateEquippedFootwear(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) {
      FootwearRedLogger.LogError("SYSTEM", "UpdateEquippedFootwear: Player entity is undefined");
      return;
    };

    this.FlushPendingOverrideSave();
    this.EnsurePresetsAndOverridesLoaded();
    let state: ref<FootwearEquipmentState> = this.GetEquipmentState();
    let repo: ref<FootwearOverrideRepository> = this.GetOverrideRepository();
    this.GetCalibrationService().EvaluateEquippedFootwear(player, state, repo);
    this.m_isInitialized = true;

    // Deduplicate logging: Only log when footwear identity, settings source, layer, or heights actually change!
    let shoeChanged: Bool = !this.m_hasLoggedFootwearOnce
      || NotEquals(state.equippedFootwearID, this.m_lastLoggedFootwearID)
      || NotEquals(state.settingsSource, this.m_lastLoggedSource)
      || NotEquals(state.activeSource, this.m_lastLoggedLayer)
      || AbsF(state.currentHeelHeight - this.m_lastLoggedHeel) > 0.0005
      || AbsF(state.currentPlatformHeight - this.m_lastLoggedPlatform) > 0.0005;

    if shoeChanged {
      this.m_hasLoggedFootwearOnce = true;
      this.m_lastLoggedFootwearID = state.equippedFootwearID;
      this.m_lastLoggedSource = state.settingsSource;
      this.m_lastLoggedLayer = state.activeSource;
      this.m_lastLoggedHeel = state.currentHeelHeight;
      this.m_lastLoggedPlatform = state.currentPlatformHeight;

      let shoeName: String = this.GetResolvedShoeDisplayName();
      let heelCm: Float = state.currentHeelHeight * 100.0;
      let platCm: Float = state.currentPlatformHeight * 100.0;
      FootwearRedLogger.LogInfo("FOOTWEAR", s"Equipped footwear updated: '\(shoeName)' | Source: [\(state.settingsSource)] | Layer: [\(state.activeSource)] | Heel: \(heelCm) cm | Platform: \(platCm) cm");
    };

    this.RecalculateEffectiveOffset(player);
    this.LogTFPState(player);
    this.NotifyFootwearChanged(state.equippedFootwearID, state.currentHeelHeight, state.currentPlatformHeight, state.activeSource);
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
    let state: ref<FootwearEquipmentState> = this.GetEquipmentState();
    state.effectiveOffset = suppressed ? 0.0 : FootwearClampingPolicy.ClampIFPHeight(state.currentHeelHeight);

    this.GetElevationCoordinator().Apply(
      player,
      state.currentHeelHeight,
      state.currentPlatformHeight,
      suppressed,
      this.m_config,
      this.m_debugLogging,
      this.GetSuppressionReason(),
      this.m_lastTppActive,
      true
    );
  }

  /**
   * Calibrates and persists height overrides for currently equipped footwear.
   * @param player The local player puppet reference.
   * @param heel Heel height offset in meters.
   * @param platform Platform height offset in meters.
   * @param force True to override even if official tags exist.
   */
  public func SetCustomHeightOverride(player: ref<PlayerPuppet>, heel: Float, platform: Float, opt force: Bool) -> Void {
    this.GetCalibrationService().SetCustomHeightOverride(this.GetEquipmentState(), this.GetOverrideRepository(), heel, platform, force);
    this.RecalculateEffectiveOffset(player);
  }

  /**
   * Clears custom height override for the current footwear and restores tag or zero baseline.
   * @param player The local player puppet reference.
   * @param force True to force clear regardless of official tags.
   */
  public func ClearCustomHeightOverride(player: ref<PlayerPuppet>, opt force: Bool) -> Void {
    this.GetCalibrationService().ClearCustomHeightOverride(this.GetEquipmentState(), this.GetOverrideRepository(), force);
    this.RecalculateEffectiveOffset(player);
  }

  /**
   * Registers or updates a shoe override in the repository and updates active state if matching equipped shoe.
   * @param key Unique shoe identifier string.
   * @param heel Raw heel height in meters.
   * @param platform Raw platform height in meters.
   */
  public func RegisterCustomOverride(key: String, heel: Float, platform: Float) -> Void {
    if StrLen(key) == 0 { return; };
    let clampedHeel: Float = FootwearClampingPolicy.ClampHeight(heel);
    let clampedPlat: Float = FootwearClampingPolicy.ClampPlatformHeight(platform);
    this.GetOverrideRepository().RegisterUserOverride(key, clampedHeel, clampedPlat);

    let state: ref<FootwearEquipmentState> = this.GetEquipmentState();
    if !ItemID.IsValid(state.equippedFootwearID) {
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
   * Clears all custom shoe overrides from repository and resets active override variables if footwear lacks official tags.
   */
  public func ClearCustomOverrides() -> Void {
    this.GetOverrideRepository().ClearUserOverrides();
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      let state: ref<FootwearEquipmentState> = this.GetEquipmentState();
      state.hasCustomOverride = false;
      state.settingsSource = "Default / None";
      state.customHeelHeight = 0.0;
      state.customPlatformHeight = 0.0;
      state.currentHeelHeight = 0.0;
      state.currentPlatformHeight = 0.0;
      return;
    };
    this.UpdateEquippedFootwear(player);
  }

  /**
   * Checks whether a custom height override is registered for the specified shoe key.
   * @param key Unique shoe identifier string.
   * @return True if key is overridden, false otherwise.
   */
  public func HasCustomOverrideForKey(key: String) -> Bool {
    return this.GetOverrideRepository().Has(key);
  }

  // -----------------------------------------------------------------------------
  // Suppression State Management & Delegation
  // -----------------------------------------------------------------------------

  /**
   * Runs the SuppressionStateController to evaluate player state snapshot.
   * @param player The local player puppet reference.
   * @return True if elevation is currently suppressed.
   */
  public func EvaluateSuppressionState(player: ref<PlayerPuppet>) -> Bool {
    return this.GetSuppressionController().Evaluate(player, this.m_config, this.GetEventDispatcher());
  }

  /**
   * Updates internal suppression state and notifies observers if changed.
   * @param suppressed True if elevation is suppressed.
   * @param reason Description of suppression trigger.
   * @return Current suppression boolean value.
   */
  public func SetSuppressionState(suppressed: Bool, reason: String) -> Bool {
    return this.GetSuppressionController().SetSuppressionState(suppressed, reason, this.GetEventDispatcher());
  }

  /**
   * Sets vehicle occupancy state and updates camera elevation accordingly.
   * @param player The local player puppet reference.
   * @param inVehicle True if player entered vehicle, false if exited.
   */
  public func SetVehicleState(player: ref<PlayerPuppet>, inVehicle: Bool) -> Void {
    if !this.GetSuppressionController().SetVehicleState(inVehicle, this.GetEventDispatcher(), this.GetTelemetry(), this) {
      return;
    };
    this.RecalculateEffectiveOffset(player);
    if !IsDefined(player) {
      return;
    };
    let eventName: String = inVehicle ? "VehicleEntered (Vehicle Occupancy)" : "VehicleExited (Restored)";
    this.LogTFPEvent(eventName, 0.0, 0.0);
    this.LogTFPState(player);
  }

  /**
   * Clears vehicle occupancy suppression when auto-recovery detects player on foot.
   * @param player The local player puppet reference.
   */
  public func ClearVehicleState(player: ref<PlayerPuppet>) -> Void {
    if !this.GetSuppressionController().ClearVehicleState(this.GetEventDispatcher(), this.GetTelemetry(), this) {
      return;
    };
    this.RecalculateEffectiveOffset(player);
    if !IsDefined(player) {
      return;
    };
    this.LogTFPEvent("VehicleAutoRecovered (Exited)", 0.0, 0.0);
    this.LogTFPState(player);
  }

  /**
   * Sets authored workspot animation state (sitting, furniture) and updates camera offset.
   * @param player The local player puppet reference.
   * @param inWorkspot True if player entered workspot, false if exited.
   */
  public func SetWorkspotState(player: ref<PlayerPuppet>, inWorkspot: Bool) -> Void {
    if !this.GetSuppressionController().SetWorkspotState(inWorkspot, this.GetEventDispatcher(), this.GetTelemetry(), this) {
      return;
    };
    this.RecalculateEffectiveOffset(player);
    if !IsDefined(player) {
      return;
    };
    let eventName: String = inWorkspot ? "WorkspotStarted (Sitting/Furniture)" : "WorkspotFinished (Standing/Exited)";
    this.LogTFPEvent(eventName, 0.0, 0.0);
    this.LogTFPState(player);
  }

  /**
   * Clears workspot suppression when auto-recovery detects player standing up.
   * @param player The local player puppet reference.
   */
  public func ClearWorkspotState(player: ref<PlayerPuppet>) -> Void {
    if !this.GetSuppressionController().ClearWorkspotState(this.GetEventDispatcher(), this.GetTelemetry(), this) {
      return;
    };
    this.RecalculateEffectiveOffset(player);
    if !IsDefined(player) {
      return;
    };
    this.LogTFPEvent("WorkspotAutoRecovered (Standing/Exited)", 0.0, 0.0);
    this.LogTFPState(player);
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
  // Authoritative State Queries & Getters
  // -----------------------------------------------------------------------------

  public func IsSuppressed() -> Bool { return this.GetSuppressionController().IsSuppressed(); }
  public func GetSuppressionReason() -> String { return this.GetSuppressionController().GetSuppressionReason(); }
  public func IsInVehicle() -> Bool { return this.GetSuppressionController().IsInVehicle(); }
  public func IsInWorkspot() -> Bool { return this.GetSuppressionController().IsInWorkspot(); }
  public func GetCurrentHeelHeight() -> Float { return this.GetEquipmentState().currentHeelHeight; }
  public func GetCurrentPlatformHeight() -> Float { return this.GetEquipmentState().currentPlatformHeight; }
  public func GetEffectiveOffset() -> Float { return this.GetEquipmentState().effectiveOffset; }
  public func GetEffectivePlatformOffset() -> Float { return this.GetEquipmentState().GetEffectivePlatformOffset(this.IsSuppressed()); }
  public func HasOfficialTweakTags() -> Bool { return this.GetEquipmentState().hasOfficialTags; }
  public func HasCustomOverride() -> Bool { return this.GetEquipmentState().hasCustomOverride; }
  public func GetEquippedFootwearID() -> ItemID { return this.GetEquipmentState().equippedFootwearID; }
  public func GetActiveSource() -> String { return this.GetEquipmentState().activeSource; }
  public func GetSettingsSource() -> String { return this.GetEquipmentState().settingsSource; }
  public func GetEffectiveHeelPitch() -> Float { return this.GetEquipmentState().GetEffectiveHeelPitch(); }

  // -----------------------------------------------------------------------------
  // Framework & Camera Integration Queries
  // -----------------------------------------------------------------------------

  public func IsPhotoModeActive() -> Bool { return this.GetFrameworkService().IsPhotoModeActive(this.GetGameInstance()); }
  public func SetPhotoModeActive(active: Bool) -> Void { this.GetFrameworkService().SetPhotoModeActive(active); }
  public func IsIFPPresent() -> Bool { return this.GetFrameworkService().IsIFPPresent(); }
  public func SetIFPPresent(present: Bool) -> Void { this.GetFrameworkService().SetIFPPresent(present); }
  public func IsITPPresent() -> Bool { return this.GetFrameworkService().IsITPPresent(this.GetGameInstance()); }
  public func SetITPPresent(present: Bool) -> Void { this.GetFrameworkService().SetITPPresent(present); }
  public func IsTPPActive(player: ref<PlayerPuppet>) -> Bool {
    if !this.m_hasTppInitialized {
      this.CheckPerspectiveDrift(player);
    };
    return this.m_lastTppActive;
  }
  public func IsTFPPresent() -> Bool { return this.GetFrameworkService().IsTFPPresent(); }
  public func IsEquipmentExPresent() -> Bool { return this.GetFrameworkService().IsEquipmentExPresent(); }
  public func GetActiveModTag(opt player: ref<PlayerPuppet>) -> String { return this.GetFrameworkService().GetActiveModTag(this.GetGameInstance(), player); }

  // -----------------------------------------------------------------------------
  // Locomotion & Sway Stride Simulation
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
    if !enabled || !IsDefined(player) || deltaTime <= 0.0 || !this.m_lastTppActive {
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
    if !IsDefined(this.m_strideController) || !IsDefined(player) {
      return;
    };
    this.m_strideController.Reset(player);
  }

  /**
   * Retrieves the current diagnostic text from StrideController.
   * @return Diagnostic status string.
   */
  public func GetStrideStatus() -> String {
    return IsDefined(this.m_strideController) ? this.m_strideController.GetStatusText() : "Idle";
  }

  // -----------------------------------------------------------------------------
  // Display, Logging & Telemetry
  // -----------------------------------------------------------------------------

  public func GetResolvedShoeTDBIDString() -> String { return FootwearDisplayHelper.GetResolvedShoeTDBIDString(this.GetEquipmentState().equippedFootwearID); }
  public func GetResolvedShoeDisplayName() -> String { return FootwearDisplayHelper.GetResolvedShoeDisplayName(this.GetEquipmentState().equippedFootwearID); }
  public func IsDebugLogging() -> Bool { return this.m_debugLogging; }
  public func SetDebugLogging(enable: Bool) -> Void { this.m_debugLogging = enable; }
  public func LogTFPEvent(eventName: String, baseZ: Float, curZ: Float) -> Void { this.GetTelemetry().LogTFPEvent(this, eventName, baseZ, curZ); }
  public func LogTFPPolling(baseZ: Float, curZ: Float) -> Void { this.GetTelemetry().LogTFPPolling(this, baseZ, curZ); }

  public func LogTFPState(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) || !this.m_debugLogging { return; };
    TFPHelper.LogState(player);
  }

  // -----------------------------------------------------------------------------
  // Observer Pattern Delegation (FootwearEventDispatcher)
  // -----------------------------------------------------------------------------

  public func RegisterListener(listener: ref<IFootwearStateListener>) -> Void { this.GetEventDispatcher().RegisterListener(listener); }
  public func UnregisterListener(listener: ref<IFootwearStateListener>) -> Void { this.GetEventDispatcher().UnregisterListener(listener); }
  public func RegisterFootwearListener(l: ref<IFootwearChangeListener>) -> Void { this.GetEventDispatcher().RegisterFootwearListener(l); }
  public func UnregisterFootwearListener(l: ref<IFootwearChangeListener>) -> Void { this.GetEventDispatcher().UnregisterFootwearListener(l); }
  public func RegisterSuppressionListener(l: ref<ISuppressionChangeListener>) -> Void { this.GetEventDispatcher().RegisterSuppressionListener(l); }
  public func UnregisterSuppressionListener(l: ref<ISuppressionChangeListener>) -> Void { this.GetEventDispatcher().UnregisterSuppressionListener(l); }
  public func RegisterConfigListener(l: ref<IConfigChangeListener>) -> Void { this.GetEventDispatcher().RegisterConfigListener(l); }
  public func UnregisterConfigListener(l: ref<IConfigChangeListener>) -> Void { this.GetEventDispatcher().UnregisterConfigListener(l); }

  private func NotifyFootwearChanged(itemID: ItemID, heel: Float, platform: Float, source: String) -> Void {
    this.GetEventDispatcher().NotifyFootwearChanged(itemID, heel, platform, source);
  }

  private func NotifySuppressionChanged(suppressed: Bool, reason: String) -> Void {
    this.GetEventDispatcher().NotifySuppressionChanged(suppressed, reason);
  }

  private func NotifyConfigChanged(config: ref<FootwearConfig>) -> Void {
    this.GetEventDispatcher().NotifyConfigChanged(config);
  }

  // -----------------------------------------------------------------------------
  // Storage & Mod Configuration Lifecycle
  // -----------------------------------------------------------------------------

  /**
   * Initializes persistent configuration and binds RCF/RedWindows providers.
   * Can be safely invoked during engine boot or in main menu without loading the shoe preset database.
   */
  public func InitConfigAndRCF() -> Void {
    if !IsDefined(this.m_config) {
      this.m_config = FootwearConfig.CreateDefault();
    };

    if !this.m_isStorageLoaded {
      this.m_isStorageLoaded = true;
      let storageMgr: ref<FootwearStorageManager> = this.GetStorageManager();
      storageMgr.LoadConfig(this.m_config);
      LegacyCetMigrationService.MigrateIfNeeded(storageMgr, this.m_config);
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
   * Ensures master shoe presets and user calibrated overrides are loaded into memory exactly once.
   * Skips all file I/O if the repository already contains populated entries.
   */
  public func EnsurePresetsAndOverridesLoaded() -> Void {
    let repo: ref<FootwearOverrideRepository> = this.GetOverrideRepository();
    if repo.GetCount() > 0 {
      return;
    };

    let storageMgr: ref<FootwearStorageManager> = this.GetStorageManager();
    storageMgr.LoadMasterPresetsIntoRepo(repo);
    storageMgr.LoadUserOverridesIntoRepo(repo);
  }

  /**
   * Initializes persistent storage, loads config and presets, and binds RCF/RedWindows providers.
   */
  public func InitStorageAndConfig() -> Void {
    this.InitConfigAndRCF();
    this.EnsurePresetsAndOverridesLoaded();
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
    if !IsDefined(config) {
      return;
    };
    this.m_config = config;
    this.m_debugLogging = config.debugLogs;
    this.NotifyConfigChanged(config);
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return;
    };
    this.RecalculateEffectiveOffset(player);
  }

  // -----------------------------------------------------------------------------
  // Real-Time Calibration & Live Preview (RedWindows)
  // -----------------------------------------------------------------------------

  /**
   * Applies live preview elevation adjustments during calibration window slider manipulation.
   * Immediately registers updated heights in the in-memory repository and marks override dirty for deferred disk persistence.
   * @param heel Temporary preview heel height in meters.
   * @param platform Temporary preview platform height in meters.
   */
  public func ApplyLiveCalibration(heel: Float, platform: Float) -> Void {
    let state: ref<FootwearEquipmentState> = this.GetEquipmentState();
    this.GetCalibrationService().ApplyLiveCalibration(state, heel, platform);

    if ItemID.IsValid(state.equippedFootwearID) {
      let shoeKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(state.equippedFootwearID));
      if StrLen(shoeKey) > 0 {
        if this.m_hasDirtyOverride && NotEquals(this.m_dirtyOverrideKey, shoeKey) {
          this.FlushPendingOverrideSave();
        };
        this.GetOverrideRepository().RegisterUserOverride(shoeKey, state.currentHeelHeight, state.currentPlatformHeight);
        this.m_hasDirtyOverride = true;
        this.m_dirtyOverrideKey = shoeKey;
        this.m_dirtyOverrideHeel = state.currentHeelHeight;
        this.m_dirtyOverridePlat = state.currentPlatformHeight;
      };
    };

    this.m_lastLoggedSource = state.settingsSource;
    this.m_lastLoggedHeel = state.currentHeelHeight;
    this.m_lastLoggedPlatform = state.currentPlatformHeight;

    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      this.RecalculateEffectiveOffset(player);
    };
    this.NotifyFootwearChanged(state.equippedFootwearID, state.currentHeelHeight, state.currentPlatformHeight, "Live Calibration");
  }

  /**
   * Persists any uncommitted live calibration override to user_shoe_overrides.json once.
   * Invoked automatically when closing the RedWindows overlay, switching shoes, or exiting menus.
   */
  public func FlushPendingOverrideSave() -> Void {
    if !this.m_hasDirtyOverride || StrLen(this.m_dirtyOverrideKey) == 0 {
      return;
    };
    let key: String = this.m_dirtyOverrideKey;
    let heel: Float = this.m_dirtyOverrideHeel;
    let plat: Float = this.m_dirtyOverridePlat;
    this.m_hasDirtyOverride = false;
    this.m_dirtyOverrideKey = "";

    this.GetStorageManager().SaveUserOverride(key, heel, plat);
    this.RegisterCustomOverride(key, heel, plat);
    FootwearRedLogger.LogInfo("CALIBRATOR", s"Auto-saved permanent override for \(key)");
  }

  /**
   * Checks whether there is an uncommitted live calibration override awaiting persistence.
   * @return True if a dirty override is pending save.
   */
  public func HasDirtyOverride() -> Bool {
    return this.m_hasDirtyOverride;
  }

  /**
   * Clears the dirty override tracking flag after an explicit save or revert action.
   */
  public func ClearPendingOverrideSave() -> Void {
    this.m_hasDirtyOverride = false;
    this.m_dirtyOverrideKey = "";
  }

  /**
   * Clears custom height override and reverts currently equipped footwear to tag or zero baseline.
   */
  public func RevertFootwearToDefault() -> Void {
    this.ClearPendingOverrideSave();
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return;
    };
    this.ClearCustomHeightOverride(player, true);
    this.UpdateEquippedFootwear(player);
  }

  public func IsDiagGeoApplied() -> Bool { return this.GetWindowsController().IsDiagGeoApplied(); }
  public func SetDiagGeoApplied(applied: Bool) -> Void { this.GetWindowsController().SetDiagGeoApplied(applied); }
  public func IsCalibGeoApplied() -> Bool { return this.GetWindowsController().IsCalibGeoApplied(); }
  public func SetCalibGeoApplied(applied: Bool) -> Void { this.GetWindowsController().SetCalibGeoApplied(applied); }
}
