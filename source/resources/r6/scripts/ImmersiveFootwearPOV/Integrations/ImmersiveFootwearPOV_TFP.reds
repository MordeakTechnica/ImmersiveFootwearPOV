module ImmersiveFootwearPOV

@if(ModuleExists("TrueFirstPerson"))
import TrueFirstPerson.{IFPSystem, IFPCamera, IFPConfig, IFPWeapon}

// =============================================================================
// Immersive Footwear POV - True First Person (TFP) Integration Helper
// Additive native REDscript camera elevation, weapon alignment, and telemetry
// =============================================================================

@if(ModuleExists("TrueFirstPerson"))
public class TFPHelper {

  /**
   * Applies additive footwear height offset to TFP camera and triggers weapon ADS alignment.
   * @param game The active GameInstance.
   * @param effectiveOffset Footwear elevation offset in meters.
   * @param hasExplicitOffset Flag indicating whether effectiveOffset was explicitly supplied.
   */
  public static func ApplyFootwearHeight(game: GameInstance, opt effectiveOffset: Float, opt hasExplicitOffset: Bool) -> Void {
    let sysHandler: ref<inkISystemRequestsHandler> = GameInstance.GetSystemRequestsHandler();
    if IsDefined(sysHandler) && sysHandler.IsPreGame() { return; };

    let player: ref<PlayerPuppet> = GetPlayer(game);
    if !IsDefined(player) || !player.IsAttached() { return; };

    let tfpSys: ref<IFPSystem> = IFPSystem.Get(game);
    if !IsDefined(tfpSys) || !tfpSys.IsSessionActive() { return; };

    let cam: ref<IFPCamera> = tfpSys.GetCamera();
    if !IsDefined(cam) || !cam.IsEnabled() || !IsDefined(cam.GetFPP()) { return; };

    let config: ref<IFPConfig> = tfpSys.GetConfig();
    let povSys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(game);
    if IsDefined(config) {
      let baseZ: Float = Cast<Float>(config.cameraZ_i) / 1000.0;
      let offsetToApply: Float = hasExplicitOffset ? effectiveOffset : (IsDefined(povSys) ? povSys.GetEffectiveOffset() : 0.0);
      let targetZ: Float = baseZ + offsetToApply;

      // Only update if target elevation has actually changed
      if AbsF(config.cameraZ - targetZ) > 0.0001 {
        let oldCamZ: Float = config.cameraZ;
        // Update TFP config cameraZ with additive footwear lift
        config.cameraZ = targetZ;

        cam.ResetToBase(true);

        // Sync weapon height with active footwear lift
        TFPHelper.SyncWeaponForCurrentFootwear(game);

        let shoeName: String = povSys.GetResolvedShoeDisplayName();
        let shoeSource: String = povSys.GetActiveSource();
        let liftCm: Float = Cast<Float>(RoundF(effectiveOffset * 1000.0)) / 10.0;
        let baseZCm: Float = Cast<Float>(RoundF(baseZ * 1000.0)) / 10.0;
        let targetZCm: Float = Cast<Float>(RoundF(targetZ * 1000.0)) / 10.0;
        let oldCamZCm: Float = Cast<Float>(RoundF(oldCamZ * 1000.0)) / 10.0;
        let isSuppressed: Bool = povSys.IsSuppressed();
        let suppReason: String = povSys.GetSuppressionReason();

        let tag: String = povSys.GetActiveModTag(player);
        let msg: String;
        if isSuppressed {
          msg = s"Footwear Height Suppressed (\(suppReason)) -> Shoe: '\(shoeName)' [\(shoeSource)] | Active Lift: +0.0cm | Base CameraZ: \(baseZCm)cm (was \(oldCamZCm)cm)";
        } else {
          msg = s"Footwear Height Applied -> Shoe: '\(shoeName)' [\(shoeSource)] | Lift: +\(liftCm)cm | TFP Base: \(baseZCm)cm -> Total CameraZ: \(targetZCm)cm (was \(oldCamZCm)cm)";
        };

        let isModuloZero: Bool = (RoundF(liftCm * 10.0) % 5) == 0;
        if povSys.IsDebugLogging() && (isModuloZero || isSuppressed) {
          FootwearRedLogger.LogDebug(tag, msg);
        };
      };
    };
  }

  /**
   * Synchronizes active weapon viewmodel and ADS reticle alignment with elevated cameraZ.
   * @param game The active GameInstance.
   */
  public static func SyncWeaponForCurrentFootwear(game: GameInstance) -> Void {
    let sysHandler: ref<inkISystemRequestsHandler> = GameInstance.GetSystemRequestsHandler();
    if IsDefined(sysHandler) && sysHandler.IsPreGame() { return; };

    let player: ref<PlayerPuppet> = GetPlayer(game);
    if !IsDefined(player) || !player.IsAttached() { return; };

    let tfpSys: ref<IFPSystem> = IFPSystem.Get(game);
    if !IsDefined(tfpSys) || !tfpSys.IsSessionActive() { return; };

    let povSys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(game);
    let weapon: ref<IFPWeapon> = tfpSys.GetWeapon();
    let config: ref<IFPConfig> = tfpSys.GetConfig();

    if IsDefined(weapon) && IsDefined(povSys) && IsDefined(config) {
      let curWeapon: wref<WeaponObject> = weapon.GetCurrentWeapon();
      if IsDefined(curWeapon) && curWeapon.IsAttached() {
        let effectiveOffset: Float = povSys.GetEffectiveOffset();
        let key: String = weapon.GetTuningKeyForCurrent();

        // Refresh TFP weapon ADS stat modifiers and TweakDB alignment with elevated cameraZ
        weapon.RefreshCurrentWeapon(config.cameraZ, config);

        let liftCm: Float = Cast<Float>(RoundF(effectiveOffset * 1000.0)) / 10.0;
        let isModuloZero: Bool = (RoundF(liftCm * 10.0) % 5) == 0;
        let tag: String = povSys.GetActiveModTag(player);
        let msg: String = s"Weapon ADS Reticle Aligned -> Shoe Lift: +\(liftCm)cm | CameraZ: \(config.cameraZ)m";
        if povSys.IsDebugLogging() && isModuloZero {
          FootwearRedLogger.LogDebug(tag, msg);
        };
      };
    };
  }

  /**
   * Queries the active effective footwear height offset (in meters) from ImmersiveFootwearPOVSystem.
   * @param game The active GameInstance.
   * @return Effective offset in meters.
   */
  public static func GetFootwearHeightOffset(game: GameInstance) -> Float {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(game);
    if IsDefined(sys) {
      return sys.GetEffectiveOffset();
    };
    return 0.0;
  }

  /**
   * Queries the raw current footwear heel height in meters without suppression.
   * @param game The active GameInstance.
   * @return Heel height in meters.
   */
  public static func GetCurrentHeelHeight(game: GameInstance) -> Float {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(game);
    if IsDefined(sys) {
      return sys.GetCurrentHeelHeight();
    };
    return 0.0;
  }

  /**
   * Checks whether footwear height is currently suppressed by gameplay states.
   * @param game The active GameInstance.
   * @return True if suppressed, false otherwise.
   */
  public static func IsSuppressed(game: GameInstance) -> Bool {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(game);
    if IsDefined(sys) {
      return sys.IsSuppressed();
    };
    return false;
  }

  /**
   * Observational telemetry helper for discrete TFP camera lifecycle events.
   * @param game The active GameInstance.
   * @param eventName Identifier of the lifecycle event.
   * @param baseZ Base camera Z in meters.
   * @param curZ Current camera Z in meters.
   */
  public static func LogEvent(game: GameInstance, eventName: String, baseZ: Float, curZ: Float) -> Void {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(game);
    if IsDefined(sys) {
      sys.LogTFPEvent(eventName, baseZ, curZ);
    };
  }

  /**
   * Observational telemetry helper for continuous camera polling (logged on state transitions).
   * @param game The active GameInstance.
   * @param baseZ Base camera Z in meters.
   * @param curZ Current camera Z in meters.
   */
  public static func LogPolling(game: GameInstance, baseZ: Float, curZ: Float) -> Void {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(game);
    if IsDefined(sys) {
      sys.LogTFPPolling(baseZ, curZ);
    };
  }

  /**
   * Polling helper: queries active TFP camera state directly from IFPSystem.
   * @param player The local player puppet reference.
   */
  public static func LogState(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) { return; };
    let gi: GameInstance = player.GetGame();
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(sys) || !sys.IsDebugLogging() { return; };

    let tfpSys: ref<IFPSystem> = IFPSystem.Get(gi);
    if IsDefined(tfpSys) && tfpSys.IsSessionActive() {
      let cam: ref<IFPCamera> = tfpSys.GetCamera();
      let cfg: ref<IFPConfig> = tfpSys.GetConfig();
      if IsDefined(cam) && IsDefined(cfg) {
        let baseZ: Float = cam.GetBaseZ(cfg);
        let curZ: Float = cam.GetCurrentZ();
        sys.LogTFPPolling(baseZ, curZ);
      };
    };
  }
}

// -----------------------------------------------------------------------------
// TFP Fallback Implementation (when True First Person is NOT installed)
// -----------------------------------------------------------------------------
@if(!ModuleExists("TrueFirstPerson"))
public class TFPHelper {

  /**
   * Fallback elevation application when TFP is not installed.
   * @param game The active GameInstance.
   * @param effectiveOffset Footwear elevation offset in meters.
   * @param hasExplicitOffset Flag indicating whether effectiveOffset was explicitly supplied.
   */
  public static func ApplyFootwearHeight(game: GameInstance, opt effectiveOffset: Float, opt hasExplicitOffset: Bool) -> Void {
    // No-op
  }

  /**
   * Fallback weapon alignment when TFP is not installed.
   * @param game The active GameInstance.
   */
  public static func SyncWeaponForCurrentFootwear(game: GameInstance) -> Void {
    // No-op
  }

  /**
   * Fallback offset query when TFP is not installed.
   * @param game The active GameInstance.
   * @return Always returns 0.0.
   */
  public static func GetFootwearHeightOffset(game: GameInstance) -> Float {
    return 0.0;
  }

  /**
   * Fallback heel height query when TFP is not installed.
   * @param game The active GameInstance.
   * @return Always returns 0.0.
   */
  public static func GetCurrentHeelHeight(game: GameInstance) -> Float {
    return 0.0;
  }

  /**
   * Fallback suppression query when TFP is not installed.
   * @param game The active GameInstance.
   * @return Always returns false.
   */
  public static func IsSuppressed(game: GameInstance) -> Bool {
    return false;
  }

  /**
   * Fallback event logger when TFP is not installed.
   * @param game The active GameInstance.
   * @param eventName Identifier of the lifecycle event.
   * @param baseZ Base camera Z in meters.
   * @param curZ Current camera Z in meters.
   */
  public static func LogEvent(game: GameInstance, eventName: String, baseZ: Float, curZ: Float) -> Void {
    // No-op
  }

  /**
   * Fallback polling logger when TFP is not installed.
   * @param game The active GameInstance.
   * @param baseZ Base camera Z in meters.
   * @param curZ Current camera Z in meters.
   */
  public static func LogPolling(game: GameInstance, baseZ: Float, curZ: Float) -> Void {
    // No-op
  }

  /**
   * Fallback state logger when TFP is not installed.
   * @param player The local player puppet reference.
   */
  public static func LogState(player: ref<PlayerPuppet>) -> Void {
    // No-op
  }
}
