module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - DigitalVixen Environment Probe
// Single Responsibility: Evaluates the presence of required DigitalVixen mods
// (RedWindows, RedscriptConfigFramework, RedFunctions) to decide whether the
// CET fallback interface should be activated.
// (RedLogger is exempted as it has its own built-in REDscript fallback).
// =============================================================================

public class FootwearDVEnvironment {

  /**
   * Checks whether RedWindows is installed and available.
   * @return True if RedWindows module is present.
   */
  public static func HasRedWindows() -> Bool {
    @if(ModuleExists("RedWindows"))
    return true;
    @if(!ModuleExists("RedWindows"))
    return false;
  }

  /**
   * Checks whether RedscriptConfigFramework (RCF) is installed and available.
   * @return True if RedscriptConfigFramework module is present.
   */
  public static func HasRCF() -> Bool {
    @if(ModuleExists("RedscriptConfigFramework"))
    return true;
    @if(!ModuleExists("RedscriptConfigFramework"))
    return false;
  }

  /**
   * Checks whether RedFunctions (ModStorage & helpers) is installed and available.
   * @return True if RedFunctions module is present.
   */
  public static func HasRedFunctions() -> Bool {
    @if(ModuleExists("RedFunctions"))
    return true;
    @if(!ModuleExists("RedFunctions"))
    return false;
  }

  /**
   * Checks whether RedLogger is installed and available (for telemetry/status).
   * @return True if RedLogger module is present.
   */
  public static func HasRedLogger() -> Bool {
    @if(ModuleExists("RedLogger"))
    return true;
    @if(!ModuleExists("RedLogger"))
    return false;
  }

  /**
   * Determines if all required DigitalVixen mods are available.
   * RedWindows, RCF, and RedFunctions must all be present.
   * @return True if the native DigitalVixen suite is complete.
   */
  public static func IsDigitalVixenComplete() -> Bool {
    return FootwearDVEnvironment.HasRedWindows() && 
           FootwearDVEnvironment.HasRCF() && 
           FootwearDVEnvironment.HasRedFunctions();
  }

  /**
   * Determines whether the CET fallback interface should be activated.
   * Active only when at least one required DigitalVixen mod is missing.
   * @return True if CET fallback is active.
   */
  public static func IsCetFallbackActive() -> Bool {
    return !FootwearDVEnvironment.IsDigitalVixenComplete();
  }

  /**
   * Returns a comma-separated list of missing required DigitalVixen mods, or "None" if all present.
   * @return Formatted summary string.
   */
  public static func GetMissingSummary() -> String {
    let missing: String = "";
    if !FootwearDVEnvironment.HasRedWindows() {
      missing = StrLen(missing) > 0 ? s"\(missing), RedWindows" : "RedWindows";
    };
    if !FootwearDVEnvironment.HasRCF() {
      missing = StrLen(missing) > 0 ? s"\(missing), RedscriptConfigFramework" : "RedscriptConfigFramework";
    };
    if !FootwearDVEnvironment.HasRedFunctions() {
      missing = StrLen(missing) > 0 ? s"\(missing), RedFunctions" : "RedFunctions";
    };
    return StrLen(missing) > 0 ? missing : "None (All Required Mods Present)";
  }
}
