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


  // -----------------------------------------------------------------------------
  // Singleton Accessor
  // -----------------------------------------------------------------------------
  public static func GetInstance(gameInstance: GameInstance) -> ref<ImmersiveFootwearPOVSystem> {
    let system: ref<ImmersiveFootwearPOVSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem") as ImmersiveFootwearPOVSystem;
    return system;
  }

  // -----------------------------------------------------------------------------
  // Lazy Collaborator Initializers
  // -----------------------------------------------------------------------------
  public func GetOverrideRepository() -> ref<FootwearOverrideRepository> {
    if !IsDefined(this.m_overrideRepo) {
      this.m_overrideRepo = FootwearOverrideRepository.Create();
    };
    return this.m_overrideRepo;
  }

  public func GetEventDispatcher() -> ref<FootwearEventDispatcher> {
    if !IsDefined(this.m_eventDispatcher) {
      this.m_eventDispatcher = FootwearEventDispatcher.Create();
    };
    return this.m_eventDispatcher;
  }

  public func GetElevationCoordinator() -> ref<ElevationActuatorCoordinator> {
    if !IsDefined(this.m_elevationCoordinator) {
      this.m_elevationCoordinator = ElevationActuatorCoordinator.Create();
    };
    return this.m_elevationCoordinator;
  }

  public func GetSuppressionEngine() -> ref<SuppressionRuleEngine> {
    if !IsDefined(this.m_suppressionEngine) {
      this.m_suppressionEngine = SuppressionRuleEngine.CreateDefault();
    };
    return this.m_suppressionEngine;
  }

  public func GetTelemetry() -> ref<FootwearTelemetryLogger> {
    if !IsDefined(this.m_telemetry) {
      this.m_telemetry = FootwearTelemetryLogger.Create();
    };
    return this.m_telemetry;
  }

  public func GetCalibratorWindow() -> ref<FootwearCalibratorWindow> {
    if !IsDefined(this.m_calibratorWindow) {
      this.m_calibratorWindow = FootwearCalibratorWindow.Create();
    };
    return this.m_calibratorWindow;
  }

  // -----------------------------------------------------------------------------
  // Lifecycle Handlers
  // -----------------------------------------------------------------------------
  private func OnAttach() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    this.InitStorageAndConfig();
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
  }

  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    this.InitStorageAndConfig();
    if !this.m_windowsLoopStarted {
      this.m_windowsLoopStarted = true;
      FootwearWindowsController.StartTick(this.GetGameInstance());
    };
  }

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

  public func FindCustomOverrideIndex(key: String) -> Int32 {
    return this.GetOverrideRepository().FindIndex(key);
  }

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

  public func RemoveCustomOverride(key: String) -> Void {
    this.GetOverrideRepository().Remove(key);
  }

  public func SetCustomOverridesMap(keys: array<String>, heels: array<Float>, platforms: array<Float>) -> Void {
    this.ClearCustomOverrides();
    let count: Int32 = ArraySize(keys);
    let i: Int32 = 0;
    while i < count {
      this.RegisterCustomOverride(keys[i], heels[i], platforms[i]);
      i += 1;
    };
  }

  public func GetCustomOverrideHeel(key: String) -> Float {
    return this.GetOverrideRepository().GetHeel(key);
  }

  public func GetCustomOverridePlatform(key: String) -> Float {
    return this.GetOverrideRepository().GetPlatform(key);
  }

  public func HasCustomOverrideForKey(key: String) -> Bool {
    return this.GetOverrideRepository().Has(key);
  }

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
  public func EvaluateSuppressionState(player: ref<PlayerPuppet>) -> Bool {
    return SuppressionEvaluator.Evaluate(this, player);
  }

  public func SetSuppressionState(suppressed: Bool, reason: String) -> Bool {
    let changed: Bool = NotEquals(this.m_isSuppressed, suppressed) || NotEquals(this.m_suppressionReason, reason);
    this.m_isSuppressed = suppressed;
    this.m_suppressionReason = reason;
    if changed {
      this.NotifySuppressionChanged(suppressed, reason);
    };
    return this.m_isSuppressed;
  }

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

  public func OnWeaponAction(player: ref<PlayerPuppet>, actionName: String) -> Void {
    if !IsDefined(player) { return; };
    TFPHelper.SyncWeaponForCurrentFootwear(player.GetGame());
    this.LogTFPEvent(s"WeaponAction (\(actionName))", 0.0, 0.0);
    this.LogTFPState(player);
  }

  // -----------------------------------------------------------------------------
  // State Queries & Getters
  // -----------------------------------------------------------------------------
  public func IsSuppressed() -> Bool { return this.m_isSuppressed; }
  public func GetSuppressionReason() -> String { return this.m_suppressionReason; }
  public func GetCurrentHeelHeight() -> Float { return this.m_currentHeelHeight; }
  public func GetCurrentPlatformHeight() -> Float { return this.m_currentPlatformHeight; }
  public func GetEffectiveOffset() -> Float { return this.m_effectiveOffset; }
  public func GetEffectivePlatformOffset() -> Float {
    if this.m_isSuppressed {
      return 0.0;
    };
    return this.m_currentPlatformHeight;
  }
  public func HasOfficialTweakTags() -> Bool { return this.m_hasOfficialTags; }
  public func HasCustomOverride() -> Bool { return this.m_hasCustomOverride; }
  public func GetEquippedFootwearID() -> ItemID { return this.m_equippedFootwearID; }
  public func GetActiveSource() -> String { return this.m_activeSource; }
  public func IsInVehicle() -> Bool { return this.m_isInVehicle; }
  public func IsInWorkspot() -> Bool { return this.m_isInWorkspot; }
  public func IsDebugLogging() -> Bool { return this.m_debugLogging; }
  public func SetDebugLogging(enable: Bool) -> Void { this.m_debugLogging = enable; }
  public func IsPhotoModeActive() -> Bool {
    let pmSys: ref<PhotoModeSystem> = GameInstance.GetPhotoModeSystem(this.GetGameInstance());
    if IsDefined(pmSys) {
      return pmSys.IsPhotoModeActive();
    };
    return this.m_isPhotoModeActive;
  }
  public func SetPhotoModeActive(active: Bool) -> Void { this.m_isPhotoModeActive = active; }
  public func IsIFPPresent() -> Bool { return this.m_isIFPPresent; }
  public func SetIFPPresent(present: Bool) -> Void { this.m_isIFPPresent = present; }
  public func IsITPPresent() -> Bool {
    if !this.m_isITPChecked {
      this.m_isITPChecked = true;
      this.m_isITPPresent = ITPDetector.IsPresent(this.GetGameInstance());
    };
    return this.m_isITPPresent;
  }
  public func SetITPPresent(present: Bool) -> Void {
    this.m_isITPPresent = present;
    this.m_isITPChecked = true;
  }
  public func IsTPPActive(player: ref<PlayerPuppet>) -> Bool {
    return ITPController.IsTPPActive(player);
  }

  // -----------------------------------------------------------------------------
  // Feminine Locomotion & Catwalk Sway Context
  // -----------------------------------------------------------------------------
  public func GetSwayContext(player: ref<PlayerPuppet>) -> ref<SwayContextData> {
    if !IsDefined(this.m_swayContext) {
      this.m_swayContext = new SwayContextData();
    };
    return SwayEvaluator.EvaluateInto(this, player, this.m_swayContext);
  }

  public func GetEffectiveHeelPitch() -> Float {
    return MaxF(0.0, this.m_currentHeelHeight - this.m_currentPlatformHeight);
  }

  public func GetStrideController() -> ref<StrideController> {
    if !IsDefined(this.m_strideController) {
      this.m_strideController = StrideController.Create();
    };
    return this.m_strideController;
  }

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

  public func ResetStride(player: ref<PlayerPuppet>) -> Void {
    if IsDefined(this.m_strideController) {
      this.m_strideController.Reset(player);
    };
  }

  public func GetStrideStatus() -> String { return IsDefined(this.m_strideController) ? this.m_strideController.GetStatusText() : "Idle"; }
  public func GetStrideRoll() -> Float { return IsDefined(this.m_strideController) ? this.m_strideController.GetCurrentRoll() : 0.0; }
  public func GetStrideYaw() -> Float { return IsDefined(this.m_strideController) ? this.m_strideController.GetCurrentYaw() : 0.0; }
  public func GetStrideBlend() -> Float { return IsDefined(this.m_strideController) ? this.m_strideController.GetCurrentBlend() : 0.0; }
  public func GetStrideLegCounterRoll() -> Float { return IsDefined(this.m_strideController) ? this.m_strideController.GetCurrentLegCounterRoll() : 0.0; }
  public func GetStrideHeelScale() -> Float { return IsDefined(this.m_strideController) ? this.m_strideController.GetCurrentHeelScale() : 0.0; }
  public func GetStridePitchCm() -> Float { return IsDefined(this.m_strideController) ? this.m_strideController.GetCurrentPitchCm() : 0.0; }

  // -----------------------------------------------------------------------------
  // Display & Localization Helpers (Delegated to FootwearDisplayHelper)
  // -----------------------------------------------------------------------------
  public func GetResolvedShoeTDBIDString() -> String {
    return FootwearDisplayHelper.GetResolvedShoeTDBIDString(this.m_equippedFootwearID);
  }

  public func GetResolvedShoeDisplayName() -> String {
    return FootwearDisplayHelper.GetResolvedShoeDisplayName(this.m_equippedFootwearID);
  }

  // -----------------------------------------------------------------------------
  // Public ShoeHeightParser Helpers
  // -----------------------------------------------------------------------------
  public func ReadPlatformHeightFromItemID(itemID: ItemID) -> Float {
    return ShoeHeightParser.ReadPlatformHeight(itemID);
  }

  public func ReadHeelHeightFromItemID(itemID: ItemID) -> Float {
    return ShoeHeightParser.ReadHeelHeight(itemID);
  }

  public func ReadPlatformHeightFromTDBID(tdbid: TweakDBID) -> Float {
    return ShoeHeightParser.ReadShoeHeightDataFromTDBID(tdbid).platformHeight;
  }

  public func ReadHeelHeightFromTDBID(tdbid: TweakDBID) -> Float {
    return ShoeHeightParser.ReadShoeHeightDataFromTDBID(tdbid).heelHeight;
  }

  public func ReadFootwearFromEquipmentExOutfit(outfitName: CName) -> ItemID {
    return EquipmentExHelper.GetFootwearFromOutfit(this.GetGameInstance(), outfitName);
  }

  // -----------------------------------------------------------------------------
  // Framework Detection & Active Mod Tagging
  // -----------------------------------------------------------------------------
  public func IsTFPPresent() -> Bool {
    return FrameworkDetector.IsTFPPresent();
  }

  public func IsEquipmentExPresent() -> Bool {
    return EquipmentExDetector.IsPresent();
  }

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
  public func LogTFPEvent(eventName: String, baseZ: Float, curZ: Float) -> Void {
    this.GetTelemetry().LogTFPEvent(this, eventName, baseZ, curZ);
  }

  public func LogTFPPolling(baseZ: Float, curZ: Float) -> Void {
    this.GetTelemetry().LogTFPPolling(this, baseZ, curZ);
  }

  public func LogTFPState(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) || !this.m_debugLogging { return; };
    TFPHelper.LogState(player);
  }

  // -----------------------------------------------------------------------------
  // Observer Pattern Delegation (FootwearEventDispatcher)
  // -----------------------------------------------------------------------------
  public func RegisterListener(listener: ref<IFootwearStateListener>) -> Void {
    this.GetEventDispatcher().RegisterListener(listener);
  }

  public func UnregisterListener(listener: ref<IFootwearStateListener>) -> Void {
    this.GetEventDispatcher().UnregisterListener(listener);
  }

  public func RegisterFootwearListener(l: ref<IFootwearChangeListener>) -> Void {
    this.GetEventDispatcher().RegisterFootwearListener(l);
  }

  public func UnregisterFootwearListener(l: ref<IFootwearChangeListener>) -> Void {
    this.GetEventDispatcher().UnregisterFootwearListener(l);
  }

  public func RegisterSuppressionListener(l: ref<ISuppressionChangeListener>) -> Void {
    this.GetEventDispatcher().RegisterSuppressionListener(l);
  }

  public func UnregisterSuppressionListener(l: ref<ISuppressionChangeListener>) -> Void {
    this.GetEventDispatcher().UnregisterSuppressionListener(l);
  }

  public func RegisterConfigListener(l: ref<IConfigChangeListener>) -> Void {
    this.GetEventDispatcher().RegisterConfigListener(l);
  }

  public func UnregisterConfigListener(l: ref<IConfigChangeListener>) -> Void {
    this.GetEventDispatcher().UnregisterConfigListener(l);
  }

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

  public func GetConfig() -> ref<FootwearConfig> {
    if !IsDefined(this.m_config) {
      this.m_config = FootwearConfig.CreateDefault();
    };
    return this.m_config;
  }

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

  public func RevertFootwearToDefault() -> Void {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      this.ClearCustomHeightOverride(player, true);
      this.UpdateEquippedFootwear(player);
    };
  }
}
