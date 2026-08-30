module ImmersiveFootwearPOV

@if(ModuleExists("TrueFirstPerson"))
import TrueFirstPerson.{IFPSystem, IFPCamera, IFPConfig}

// =============================================================================
// Immersive Footwear POV - True First Person (TFP) Integration Helper
// Direct native REDscript camera elevation and observational telemetry
// =============================================================================

@if(ModuleExists("TrueFirstPerson"))
public class TFPHelper {

  // Queries the active effective footwear height offset (in meters) from ImmersiveFootwearPOVSystem
  public static func GetFootwearHeightOffset(game: GameInstance) -> Float {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(game);
    if IsDefined(sys) {
      return sys.GetEffectiveOffset();
    };
    return 0.0;
  }

  // Queries raw current footwear heel height without suppression
  public static func GetCurrentHeelHeight(game: GameInstance) -> Float {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(game);
    if IsDefined(sys) {
      return sys.GetCurrentHeelHeight();
    };
    return 0.0;
  }

  // Checks whether footwear height is currently suppressed
  public static func IsSuppressed(game: GameInstance) -> Bool {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(game);
    if IsDefined(sys) {
      return sys.IsSuppressed();
    };
    return false;
  }

  // Observational telemetry helper for discrete TFP camera lifecycle events
  public static func LogEvent(game: GameInstance, eventName: String, baseZ: Float, curZ: Float) -> Void {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(game);
    if IsDefined(sys) {
      sys.LogTFPEvent(eventName, baseZ, curZ);
    };
  }

  // Observational telemetry helper for continuous camera polling (logged on state transitions)
  public static func LogPolling(game: GameInstance, baseZ: Float, curZ: Float) -> Void {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(game);
    if IsDefined(sys) {
      sys.LogTFPPolling(baseZ, curZ);
    };
  }

  // Polling helper: queries active TFP camera state directly from IFPSystem
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

  public static func GetFootwearHeightOffset(game: GameInstance) -> Float {
    return 0.0;
  }

  public static func GetCurrentHeelHeight(game: GameInstance) -> Float {
    return 0.0;
  }

  public static func IsSuppressed(game: GameInstance) -> Bool {
    return false;
  }

  public static func LogEvent(game: GameInstance, eventName: String, baseZ: Float, curZ: Float) -> Void {
    // No-op
  }

  public static func LogPolling(game: GameInstance, baseZ: Float, curZ: Float) -> Void {
    // No-op
  }

  public static func LogState(player: ref<PlayerPuppet>) -> Void {
    // No-op
  }
}
