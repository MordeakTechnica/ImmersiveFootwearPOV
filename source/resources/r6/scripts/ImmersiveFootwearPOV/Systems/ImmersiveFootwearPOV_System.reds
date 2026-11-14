module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Core ScriptableSystem Coordinator
// Single Responsibility Principle (SRP):
// Acts as the central REDengine ScriptableSystem coordinator, delegating domain
// operations to specialized repositories, rule engines, actuators, and dispatchers.
// =============================================================================

// -----------------------------------------------------------------------------
// Parameterized Delay Callback
// Consolidates post-restore and debounced update timers into a single callback class.
// -----------------------------------------------------------------------------
public enum FootwearScheduledTask {
  PostRestore = 0,
  DebouncedUpdate = 1
}

public class FootwearDelayCallback extends DelayCallback {
  public let m_system: wref<ImmersiveFootwearPOVSystem>;
  private let m_task: FootwearScheduledTask;

  public static func Create(sys: ref<ImmersiveFootwearPOVSystem>, task: FootwearScheduledTask) -> ref<FootwearDelayCallback> {
    let cb: ref<FootwearDelayCallback> = new FootwearDelayCallback();
    cb.m_system = sys;
    cb.m_task = task;
    return cb;
  }

  public func Call() -> Void {
    if IsDefined(this.m_system) {
      this.m_system.OnScheduledTask(this.m_task);
    };
  }
}

public class ImmersiveFootwearPOVSystem extends ScriptableSystem {

  // Authoritative State Model
  private let m_equipmentState: ref<FootwearEquipmentState>;
  private let m_servicesInitialized: Bool;
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
  private let m_activeNtpElevation: Float;

  // Debouncing Flags
  private let m_debouncePending: Bool;
  private let m_postRestorePending: Bool;

  // Domain Collaborators
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
  // System Accessor
  // -----------------------------------------------------------------------------

  /**
   * Retrieves the running ImmersiveFootwearPOVSystem instance from the game container.
   * @param gameInstance The active GameInstance.
   * @return The registered ImmersiveFootwearPOVSystem instance.
   */
  public static func GetInstance(gameInstance: GameInstance) -> ref<ImmersiveFootwearPOVSystem> {
    let system: ref<ImmersiveFootwearPOVSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem") as ImmersiveFootwearPOVSystem;
    return system;
  }

  // -----------------------------------------------------------------------------
  // Collaborator Initialization
  // -----------------------------------------------------------------------------

  /**
   * Initializes all domain collaborator services together once before use.
   */
  private func EnsureServices() -> Void {
    if this.m_servicesInitialized {
      return;
    };
    this.m_servicesInitialized = true;
    this.m_equipmentState = FootwearEquipmentState.Create();
    this.m_calibrationService = FootwearCalibrationService.Create();
    this.m_suppressionController = SuppressionStateController.Create();
    this.m_frameworkService = FrameworkIntegrationService.Create();
    this.m_windowsController = FootwearWindowsController.Create();
    this.m_storageManager = FootwearStorageManager.Create();
    this.m_overrideRepo = FootwearOverrideRepository.Create();
    this.m_eventDispatcher = FootwearEventDispatcher.Create();
    this.m_elevationCoordinator = ElevationActuatorCoordinator.Create();
    this.m_strideController = StrideController.Create();
    this.m_telemetry = FootwearTelemetryLogger.Create();
  }

  private func GetEquipmentState() -> ref<FootwearEquipmentState> { this.EnsureServices(); return this.m_equipmentState; }
  public func GetCalibrationService() -> ref<FootwearCalibrationService> { this.EnsureServices(); return this.m_calibrationService; }
  public func GetSuppressionController() -> ref<SuppressionStateController> { this.EnsureServices(); return this.m_suppressionController; }
  private func GetFrameworkService() -> ref<FrameworkIntegrationService> { this.EnsureServices(); return this.m_frameworkService; }
  public func GetWindowsController() -> ref<FootwearWindowsController> { this.EnsureServices(); return this.m_windowsController; }
  public func GetStorageManager() -> ref<FootwearStorageManager> { this.EnsureServices(); return this.m_storageManager; }
  public func GetOverrideRepository() -> ref<FootwearOverrideRepository> { this.EnsureServices(); return this.m_overrideRepo; }
  private func GetEventDispatcher() -> ref<FootwearEventDispatcher> { this.EnsureServices(); return this.m_eventDispatcher; }
  private func GetElevationCoordinator() -> ref<ElevationActuatorCoordinator> { this.EnsureServices(); return this.m_elevationCoordinator; }
  private func GetTelemetry() -> ref<FootwearTelemetryLogger> { this.EnsureServices(); return this.m_telemetry; }
  public func GetCalibratorWindow() -> ref<FootwearCalibratorWindow> { return this.GetWindowsController().GetCalibratorWindow(); }

  // -----------------------------------------------------------------------------
  // Lifecycle Handlers
  // -----------------------------------------------------------------------------

  /**
   * REDengine system attachment lifecycle callback. Initializes storage, config, and registers session callbacks.
   */
  private func OnAttach() -> Void {
    this.EnsureServices();
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
   * Resets per-session runtime state and evaluates initial equipped footwear for the player puppet.
   */
  private func ResetAndBindPlayerSession(player: ref<PlayerPuppet>) -> Void {
    this.EnsureServices();
    this.m_isInitialized = false;
    this.m_hasTppInitialized = false;
    this.m_activeNtpElevation = 0.0;
    this.GetSuppressionController().Reset();
    this.EnsurePresetsAndOverridesLoaded();
    this.UpdateEquippedFootwear(player);
    this.QueuePostRestoreTick();
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
    if IsDefined(player) {
      this.ResetAndBindPlayerSession(player);
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
      this.ResetAndBindPlayerSession(player);
    };
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
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(
      FootwearDelayCallback.Create(this, FootwearScheduledTask.PostRestore),
      0.40,
      false
    );
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
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(
      FootwearDelayCallback.Create(this, FootwearScheduledTask.DebouncedUpdate),
      0.10,
      false
    );
  }

  /**
   * Executes a scheduled delay task triggered by FootwearDelayCallback.
   */
  public func OnScheduledTask(task: FootwearScheduledTask) -> Void {
    if Equals(task, FootwearScheduledTask.DebouncedUpdate) {
      this.m_debouncePending = false;
    } else {
      this.m_postRestorePending = false;
    };

    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return;
    };

    if Equals(task, FootwearScheduledTask.DebouncedUpdate) {
      this.CheckPerspectiveDrift(player);
      this.UpdateEquippedFootwear(player);
    } else {
      this.EnsurePresetsAndOverridesLoaded();
      this.UpdateEquippedFootwear(player);
      this.CheckPerspectiveDrift(player);
      this.RecalculateEffectiveOffset(player);
    };
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

    if !this.m_lastTppActive {
      let cfg: ref<FootwearConfig> = this.GetConfig();
      if !IsDefined(cfg) || cfg.enableFPP {
        HeightController.ApplyHeightOffset(player, this.GetActiveFppOffset());
      };
      return;
    };

    let cfg: ref<FootwearConfig> = this.GetConfig();
    if !IsDefined(cfg) || !cfg.enableHipSway {
      return;
    };
    let winCtrl: ref<FootwearWindowsController> = this.GetWindowsController();
    let isOverlayOpen: Bool = FootwearCalibratorHost.IsCalibratorOpen(player.GetGame()) || (IsDefined(winCtrl) && winCtrl.WasOverlayActive());
    let currentFrame: Uint64 = GameInstance.GetFrameNumber(player.GetGame());
    if currentFrame != this.m_lastStrideFrame {
      this.m_lastStrideFrame = currentFrame;
      this.EnsureServices();
      this.m_strideController.Update(this, player, timeDelta, cfg.enableHipSway, cfg.swayLow, cfg.swayMid, cfg.swayHigh, isOverlayOpen);
    };
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
    this.GetTelemetry().LogFootwearUpdateIfChanged(state);

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

    let suppressed: Bool = this.GetSuppressionController().Evaluate(player, this.m_config, this.GetEventDispatcher());
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
   * Registers or updates a shoe override in the repository and updates active state if matching equipped shoe.
   * @param key Unique shoe identifier string.
   * @param heel Raw heel height in meters.
   * @param platform Raw platform height in meters.
   */
  public func RegisterCustomOverride(key: String, heel: Float, platform: Float) -> Void {
    this.GetCalibrationService().RegisterCustomOverride(this.GetEquipmentState(), this.GetOverrideRepository(), key, heel, platform);
  }

  // -----------------------------------------------------------------------------
  // Suppression State Management & Delegation
  // -----------------------------------------------------------------------------

  /**
   * Updates internal suppression state and notifies observers if changed.
   * @param suppressed True if elevation is suppressed.
   * @param reason Description of suppression trigger.
   * @return Current suppression boolean value.
   */
  public func SetSuppressionState(suppressed: Bool, reason: String) -> Bool {
    return this.GetSuppressionController().SetSuppressionState(suppressed, reason, this.GetEventDispatcher());
  }

  private func SetSuppressionContext(player: ref<PlayerPuppet>, channel: FootwearContextChannel, active: Bool, eventName: String) -> Void {
    if !this.GetSuppressionController().SetContextState(channel, active, this.GetEquipmentState(), this.GetEventDispatcher()) {
      return;
    };
    this.RecalculateEffectiveOffset(player);
    if !IsDefined(player) {
      return;
    };
    this.LogTFPEvent(eventName, 0.0, 0.0);
    this.LogTFPState(player);
  }

  public func SetVehicleState(player: ref<PlayerPuppet>, inVehicle: Bool) -> Void {
    let eventName: String = inVehicle ? "VehicleEntered (Vehicle Occupancy)" : "VehicleExited (Restored)";
    this.SetSuppressionContext(player, FootwearContextChannel.Vehicle, inVehicle, eventName);
  }

  public func SetWorkspotState(player: ref<PlayerPuppet>, inWorkspot: Bool) -> Void {
    let eventName: String = inWorkspot ? "WorkspotStarted (Sitting/Furniture)" : "WorkspotFinished (Standing/Exited)";
    this.SetSuppressionContext(player, FootwearContextChannel.Workspot, inWorkspot, eventName);
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
  public func GetEquippedFootwearID() -> ItemID { return this.GetEquipmentState().equippedFootwearID; }
  public func GetActiveSource() -> String { return this.GetEquipmentState().activeSource; }
  public func GetSettingsSource() -> String { return this.GetEquipmentState().settingsSource; }
  public func GetEffectiveHeelPitch() -> Float { return this.GetEquipmentState().GetEffectiveHeelPitch(); }
  public func GetActiveFppBlend() -> Float {
    return FootwearAnimgraphHelper.CalculateHeightBlend(this.GetActiveFppOffset());
  }
  public func GetActiveFppOffset() -> Float {
    let cfg: ref<FootwearConfig> = this.GetConfig();
    if IsDefined(cfg) && !cfg.enableFPP {
      return 0.0;
    };
    if this.m_lastTppActive {
      return 0.0;
    };
    let suppressed: Bool = this.IsSuppressed();
    let state: ref<FootwearEquipmentState> = this.GetEquipmentState();
    return suppressed ? 0.0 : FootwearClampingPolicy.ClampIFPHeight(state.currentHeelHeight);
  }

  // -----------------------------------------------------------------------------
  // Framework & Camera Integration Queries
  // -----------------------------------------------------------------------------

  public func IsPhotoModeActive() -> Bool { return this.GetFrameworkService().IsPhotoModeActive(this.GetGameInstance()); }
  public func SetPhotoModeActive(active: Bool) -> Void { this.GetFrameworkService().SetPhotoModeActive(active); }
  public func IsIFPPresent() -> Bool { return this.GetFrameworkService().IsIFPPresent(); }
  public func SetIFPPresent(present: Bool) -> Void { this.GetFrameworkService().SetIFPPresent(present); }
  public func IsITPPresent() -> Bool { return this.GetFrameworkService().IsITPPresent(this.GetGameInstance()); }
  public func SetITPPresent(present: Bool) -> Void { this.GetFrameworkService().SetITPPresent(present); }
  public func IsNTPPresent() -> Bool { return this.GetFrameworkService().IsNTPPresent(); }
  public func SetActiveNtpElevation(elevation: Float) -> Void { this.m_activeNtpElevation = elevation; }
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
  public func LogTFPEvent(eventName: String, baseZ: Float, curZ: Float) -> Void { this.GetTelemetry().LogTFPEvent(this, eventName, baseZ, curZ); }
  public func LogTFPPolling(baseZ: Float, curZ: Float) -> Void { this.GetTelemetry().LogTFPPolling(this, baseZ, curZ); }

  private func LogTFPState(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) || !this.m_debugLogging { return; };
    TFPHelper.LogState(player);
  }

  // -----------------------------------------------------------------------------
  // Event Dispatcher Delegation (FootwearEventDispatcher)
  // -----------------------------------------------------------------------------

  public func RegisterObserver(observer: ref<IFootwearObserver>) -> Void { this.GetEventDispatcher().RegisterObserver(observer); }
  public func UnregisterObserver(observer: ref<IFootwearObserver>) -> Void { this.GetEventDispatcher().UnregisterObserver(observer); }

  private func NotifyFootwearChanged(itemID: ItemID, heel: Float, platform: Float, source: String) -> Void {
    this.GetEventDispatcher().NotifyFootwearChanged(itemID, heel, platform, source);
    FootwearCalibratorHost.OnFootwearUpdated(this.GetGameInstance());
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
    FootwearCalibratorHost.Init(gi);
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

  public func ApplyLiveCalibration(heel: Float, platform: Float) -> Void {
    let state: ref<FootwearEquipmentState> = this.GetEquipmentState();
    this.GetCalibrationService().ApplyLiveCalibration(state, this.GetOverrideRepository(), this.GetStorageManager(), heel, platform);
    this.GetTelemetry().SyncLiveCalibrationSnapshot(state);

    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      this.CheckPerspectiveDrift(player);
      this.RecalculateEffectiveOffset(player);
    };
    this.NotifyFootwearChanged(state.equippedFootwearID, state.currentHeelHeight, state.currentPlatformHeight, "Live Calibration");
  }

  public func FlushPendingOverrideSave() -> Void {
    this.GetCalibrationService().FlushPendingOverrideSave(this.GetEquipmentState(), this.GetOverrideRepository(), this.GetStorageManager());
  }

  public func HasDirtyOverride() -> Bool {
    return this.GetCalibrationService().HasDirtyOverride();
  }

  public func ClearPendingOverrideSave() -> Void {
    this.GetCalibrationService().ClearPendingOverrideSave();
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
    this.GetCalibrationService().ClearCustomHeightOverride(this.GetEquipmentState(), this.GetOverrideRepository(), true);
    this.UpdateEquippedFootwear(player);
  }

  // -----------------------------------------------------------------------------
  // DigitalVixen Environment & CET Fallback Status API
  // -----------------------------------------------------------------------------

  /**
   * Checks whether the native DigitalVixen suite (RedWindows, RCF, RedFunctions) is complete.
   * When true, native in-game menus and floating windows are fully functional.
   * @return True if all required DigitalVixen mods are installed.
   */
  public func IsDigitalVixenComplete() -> Bool {
    return FootwearDVEnvironment.IsDigitalVixenComplete();
  }

  /**
   * Checks whether the CET fallback interface should be active.
   * Active only when at least 1 required DigitalVixen mod is missing.
   * @return True if CET fallback is active.
   */
  public func IsCetFallbackActive() -> Bool {
    return FootwearDVEnvironment.IsCetFallbackActive();
  }

  /**
   * Checks whether RedWindows is available.
   * @return True if RedWindows is installed.
   */
  public func HasRedWindows() -> Bool {
    return FootwearDVEnvironment.HasRedWindows();
  }

  /**
   * Checks whether RedscriptConfigFramework (RCF) is available.
   * @return True if RCF is installed.
   */
  public func HasRCF() -> Bool {
    return FootwearDVEnvironment.HasRCF();
  }

  /**
   * Checks whether RedFunctions is available.
   * @return True if RedFunctions is installed.
   */
  public func HasRedFunctions() -> Bool {
    return FootwearDVEnvironment.HasRedFunctions();
  }

  /**
   * Returns a human-readable list of missing DigitalVixen mods.
   * @return Formatted summary string.
   */
  public func GetMissingDigitalVixenSummary() -> String {
    return FootwearDVEnvironment.GetMissingSummary();
  }
}

