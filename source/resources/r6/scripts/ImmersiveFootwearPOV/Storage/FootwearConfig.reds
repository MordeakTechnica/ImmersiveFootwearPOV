module ImmersiveFootwearPOV

import RedFunctions.*
import RedFunctions.Json.*

// =============================================================================
// Immersive Footwear POV - Configuration Data Model
// Single Responsibility: Holds typed user configuration state with safe defaults
// =============================================================================
public class FootwearConfig {
  public let autoElevatePM: Bool;
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

  /**
   * Deserializes configuration attributes from a JSON map object, preserving existing defaults on missing keys.
   * Handles backwards compatibility migration from legacy 'hipSwayIntensity' if present.
   * @param map The source JsonMap to read from.
   */
  public func ReadFromJson(map: ref<JsonMap>) -> Void {
    if !IsDefined(map) {
      return;
    };
    this.autoElevatePM = map.Bool("autoElevatePM", this.autoElevatePM);
    this.debugLogs = map.Bool("debugLogs", this.debugLogs);
    this.enableFPP = map.Bool("enableFPP", this.enableFPP);
    this.enableITP = map.Bool("enableITP", this.enableITP);
    this.enableHipSway = map.Bool("enableHipSway", this.enableHipSway);
    if map.Contains("hipSwayIntensity") && !map.Contains("swayLow") {
      let legacyIntensity: Float = map.Float("hipSwayIntensity", 1.0);
      this.swayLow = legacyIntensity;
      this.swayMid = legacyIntensity;
      this.swayHigh = legacyIntensity;
    } else {
      this.swayLow = map.Float("swayLow", this.swayLow);
      this.swayMid = map.Float("swayMid", this.swayMid);
      this.swayHigh = map.Float("swayHigh", this.swayHigh);
    };
    this.suppressVehicles = map.Bool("suppressVehicles", this.suppressVehicles);
    this.suppressWorkspots = map.Bool("suppressWorkspots", this.suppressWorkspots);
    this.suppressScenes = map.Bool("suppressScenes", this.suppressScenes);
    this.transitionSpeed = map.Float("transitionSpeed", this.transitionSpeed);
    this.hudPinned = map.Bool("hudPinned", this.hudPinned);
    this.diagWinX = map.Float("diagWinX", this.diagWinX);
    this.diagWinY = map.Float("diagWinY", this.diagWinY);
    this.diagWinW = map.Float("diagWinW", this.diagWinW);
    this.diagWinH = map.Float("diagWinH", this.diagWinH);
    this.calibWinX = map.Float("calibWinX", this.calibWinX);
    this.calibWinY = map.Float("calibWinY", this.calibWinY);
    this.calibWinW = map.Float("calibWinW", this.calibWinW);
    this.calibWinH = map.Float("calibWinH", this.calibWinH);
  }

  /**
   * Serializes current configuration attributes into a JSON map object for persistent disk storage.
   * @param map The destination JsonMap to write to.
   */
  public func WriteToJson(map: ref<JsonMap>) -> Void {
    if !IsDefined(map) {
      return;
    };
    map.PutBool("autoElevatePM", this.autoElevatePM);
    map.PutBool("debugLogs", this.debugLogs);
    map.PutBool("enableFPP", this.enableFPP);
    map.PutBool("enableITP", this.enableITP);
    map.PutBool("enableHipSway", this.enableHipSway);
    map.PutFloat("swayLow", this.swayLow);
    map.PutFloat("swayMid", this.swayMid);
    map.PutFloat("swayHigh", this.swayHigh);
    map.PutBool("suppressVehicles", this.suppressVehicles);
    map.PutBool("suppressWorkspots", this.suppressWorkspots);
    map.PutBool("suppressScenes", this.suppressScenes);
    map.PutFloat("transitionSpeed", this.transitionSpeed);
    map.PutBool("hudPinned", this.hudPinned);
    map.PutFloat("diagWinX", this.diagWinX);
    map.PutFloat("diagWinY", this.diagWinY);
    map.PutFloat("diagWinW", this.diagWinW);
    map.PutFloat("diagWinH", this.diagWinH);
    map.PutFloat("calibWinX", this.calibWinX);
    map.PutFloat("calibWinY", this.calibWinY);
    map.PutFloat("calibWinW", this.calibWinW);
    map.PutFloat("calibWinH", this.calibWinH);
  }
}
