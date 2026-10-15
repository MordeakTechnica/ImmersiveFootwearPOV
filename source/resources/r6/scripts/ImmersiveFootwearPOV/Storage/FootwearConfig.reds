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

  public static func CreateDefault() -> ref<FootwearConfig> {
    let cfg: ref<FootwearConfig> = new FootwearConfig();
    cfg.SetDefaults();
    return cfg;
  }

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
  }

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
  }

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
  }
}
