module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - DigitalVixen Environment Probes & Detectors
// Single Responsibility: Evaluates the presence of required DigitalVixen mods
// (RedWindows, RedscriptConfigFramework, RedFunctions) using compile-time
// class-level conditional compilation (@if / @if(!ModuleExists(...))).
// =============================================================================

@if(ModuleExists("RedWindows"))
public class RedWindowsDetector {
  public static func IsPresent() -> Bool {
    return true;
  }
}

@if(!ModuleExists("RedWindows"))
public class RedWindowsDetector {
  public static func IsPresent() -> Bool {
    return false;
  }
}

@if(ModuleExists("RedscriptConfigFramework"))
public class RCFDetector {
  public static func IsPresent() -> Bool {
    return true;
  }
}

@if(!ModuleExists("RedscriptConfigFramework"))
public class RCFDetector {
  public static func IsPresent() -> Bool {
    return false;
  }
}

@if(ModuleExists("RedFunctions"))
public class RedFunctionsDetector {
  public static func IsPresent() -> Bool {
    return true;
  }
}

@if(!ModuleExists("RedFunctions"))
public class RedFunctionsDetector {
  public static func IsPresent() -> Bool {
    return false;
  }
}

@if(ModuleExists("RedLogger"))
public class RedLoggerDetector {
  public static func IsPresent() -> Bool {
    return true;
  }
}

@if(!ModuleExists("RedLogger"))
public class RedLoggerDetector {
  public static func IsPresent() -> Bool {
    return false;
  }
}

public class FootwearDVEnvironment {

  /**
   * Checks whether RedWindows is installed and available.
   * @return True if RedWindows module is present.
   */
  public static func HasRedWindows() -> Bool {
    return RedWindowsDetector.IsPresent();
  }

  /**
   * Checks whether RedscriptConfigFramework (RCF) is installed and available.
   * @return True if RedscriptConfigFramework module is present.
   */
  public static func HasRCF() -> Bool {
    return RCFDetector.IsPresent();
  }

  /**
   * Checks whether RedFunctions (ModStorage & helpers) is installed and available.
   * @return True if RedFunctions module is present.
   */
  public static func HasRedFunctions() -> Bool {
    return RedFunctionsDetector.IsPresent();
  }

  /**
   * Checks whether RedLogger is installed and available (for telemetry/status).
   * @return True if RedLogger module is present.
   */
  public static func HasRedLogger() -> Bool {
    return RedLoggerDetector.IsPresent();
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
