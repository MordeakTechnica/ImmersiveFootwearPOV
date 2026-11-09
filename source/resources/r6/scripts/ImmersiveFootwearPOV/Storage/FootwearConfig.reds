module ImmersiveFootwearPOV

@if(ModuleExists("RedFunctions"))
import RedFunctions.*
@if(ModuleExists("RedFunctions"))
import RedFunctions.Json.*

// =============================================================================
// Immersive Footwear POV - Configuration Data Model
// Single Responsibility: Holds typed user configuration state with safe defaults
// =============================================================================
public class FootwearConfig {
  public let autoElevatePM: Bool;
  public let autoElevateNTP: Bool;
  public let debugLogs: Bool;
  public let enableFPP: Bool;
  public let enableITP: Bool;
  public let enableHipSway: Bool;
  public let swayLow: Float;
  public let swayMid: Float;
  public let swayHigh: Float;
  public let suppressVehicles: Bool;
  public let suppressWorkspots: Bool;
  public let suppressScenes: Bool;
  public let transitionSpeed: Float;
  public let hudPinned: Bool;
  public let diagWinX: Float;
  public let diagWinY: Float;
  public let diagWinW: Float;
  public let diagWinH: Float;
  public let calibWinX: Float;
  public let calibWinY: Float;
  public let calibWinW: Float;
  public let calibWinH: Float;

  /**
   * Factory method creating a FootwearConfig populated with factory default settings.
   * @return A newly initialized FootwearConfig with default values.
   */
  public static func CreateDefault() -> ref<FootwearConfig> {
    let cfg: ref<FootwearConfig> = new FootwearConfig();
    cfg.SetDefaults();
    return cfg;
  }

  /**
   * Resets all configuration settings to their recommended default values.
   */
  public func SetDefaults() -> Void {
    this.autoElevatePM = true;
    this.autoElevateNTP = true;
    this.debugLogs = false;
    this.enableFPP = true;
    this.enableITP = true;
    this.enableHipSway = true;
    this.swayLow = 1.0;
    this.swayMid = 1.0;
    this.swayHigh = 1.0;
    this.suppressVehicles = true;
    this.suppressWorkspots = true;
    this.suppressScenes = true;
    this.transitionSpeed = 0.35;
    this.hudPinned = false;
    this.diagWinX = -1.0;
    this.diagWinY = -1.0;
    this.diagWinW = -1.0;
    this.diagWinH = -1.0;
    this.calibWinX = -1.0;
    this.calibWinY = -1.0;
    this.calibWinW = -1.0;
    this.calibWinH = -1.0;
  }
}

// =============================================================================
// Immersive Footwear POV - Configuration JSON Serializer Adapter
// Single Responsibility: Class-level conditional RedFunctions JSON serialization
// =============================================================================
@if(ModuleExists("RedFunctions"))
public class FootwearConfigJsonAdapter {
  /**
   * Deserializes configuration attributes from a JSON map object, preserving existing defaults on missing keys.
   * Handles backwards compatibility migration from legacy 'hipSwayIntensity' if present.
   * @param cfg The FootwearConfig instance to populate.
   * @param map The source JsonMap to read from.
   */
  public static func ReadFromJson(cfg: ref<FootwearConfig>, map: ref<JsonMap>) -> Void {
    if !IsDefined(cfg) || !IsDefined(map) {
      return;
    };
    cfg.autoElevatePM = map.Bool("autoElevatePM", cfg.autoElevatePM);
    cfg.autoElevateNTP = map.Bool("autoElevateNTP", cfg.autoElevateNTP);
    cfg.debugLogs = map.Bool("debugLogs", cfg.debugLogs);
    cfg.enableFPP = map.Bool("enableFPP", cfg.enableFPP);
    cfg.enableITP = map.Bool("enableITP", cfg.enableITP);
    cfg.enableHipSway = map.Bool("enableHipSway", cfg.enableHipSway);
    if map.Contains("hipSwayIntensity") && !map.Contains("swayLow") {
      let legacyIntensity: Float = map.Float("hipSwayIntensity", 1.0);
      cfg.swayLow = legacyIntensity;
      cfg.swayMid = legacyIntensity;
      cfg.swayHigh = legacyIntensity;
    } else {
      cfg.swayLow = map.Float("swayLow", cfg.swayLow);
      cfg.swayMid = map.Float("swayMid", cfg.swayMid);
      cfg.swayHigh = map.Float("swayHigh", cfg.swayHigh);
    };
    cfg.suppressVehicles = map.Bool("suppressVehicles", cfg.suppressVehicles);
    cfg.suppressWorkspots = map.Bool("suppressWorkspots", cfg.suppressWorkspots);
    cfg.suppressScenes = map.Bool("suppressScenes", cfg.suppressScenes);
    cfg.transitionSpeed = map.Float("transitionSpeed", cfg.transitionSpeed);
    cfg.hudPinned = map.Bool("hudPinned", cfg.hudPinned);
    cfg.diagWinX = map.Float("diagWinX", cfg.diagWinX);
    cfg.diagWinY = map.Float("diagWinY", cfg.diagWinY);
    cfg.diagWinW = map.Float("diagWinW", cfg.diagWinW);
    cfg.diagWinH = map.Float("diagWinH", cfg.diagWinH);
    cfg.calibWinX = map.Float("calibWinX", cfg.calibWinX);
    cfg.calibWinY = map.Float("calibWinY", cfg.calibWinY);
    cfg.calibWinW = map.Float("calibWinW", cfg.calibWinW);
    cfg.calibWinH = map.Float("calibWinH", cfg.calibWinH);
  }

  /**
   * Serializes current configuration attributes into a JSON map object for persistent disk storage.
   * @param cfg The FootwearConfig instance to serialize.
   * @param map The destination JsonMap to write to.
   */
  public static func WriteToJson(cfg: ref<FootwearConfig>, map: ref<JsonMap>) -> Void {
    if !IsDefined(cfg) || !IsDefined(map) {
      return;
    };
    map.PutBool("autoElevatePM", cfg.autoElevatePM);
    map.PutBool("autoElevateNTP", cfg.autoElevateNTP);
    map.PutBool("debugLogs", cfg.debugLogs);
    map.PutBool("enableFPP", cfg.enableFPP);
    map.PutBool("enableITP", cfg.enableITP);
    map.PutBool("enableHipSway", cfg.enableHipSway);
    map.PutFloat("swayLow", cfg.swayLow);
    map.PutFloat("swayMid", cfg.swayMid);
    map.PutFloat("swayHigh", cfg.swayHigh);
    map.PutBool("suppressVehicles", cfg.suppressVehicles);
    map.PutBool("suppressWorkspots", cfg.suppressWorkspots);
    map.PutBool("suppressScenes", cfg.suppressScenes);
    map.PutFloat("transitionSpeed", cfg.transitionSpeed);
    map.PutBool("hudPinned", cfg.hudPinned);
    map.PutFloat("diagWinX", cfg.diagWinX);
    map.PutFloat("diagWinY", cfg.diagWinY);
    map.PutFloat("diagWinW", cfg.diagWinW);
    map.PutFloat("diagWinH", cfg.diagWinH);
    map.PutFloat("calibWinX", cfg.calibWinX);
    map.PutFloat("calibWinY", cfg.calibWinY);
    map.PutFloat("calibWinW", cfg.calibWinW);
    map.PutFloat("calibWinH", cfg.calibWinH);
  }
}
