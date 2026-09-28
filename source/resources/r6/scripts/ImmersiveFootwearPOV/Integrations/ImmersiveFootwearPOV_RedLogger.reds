module ImmersiveFootwearPOV

@if(ModuleExists("RedLogger"))
import RedLogger.*

// =============================================================================
// Immersive Footwear POV - RedLogger Integration
// Dedicated per-mod session logging with 5-session automatic pruning
// Supported log levels: "DEBUG", "INFO", "WARN", "ERROR"
// Writes to: r6\logs\mods\ImmersiveFootwearPOV__<YYYY-MM-DD_HH-MM-SS>.log
// =============================================================================

@if(ModuleExists("RedLogger"))
public class FootwearRedLogger {

  public static func Append(level: String, tag: String, message: String) -> Void {
    RedLog.AppendLevel("ImmersiveFootwearPOV", level, s"[\(tag)] \(message)");
  }

  public static func AppendRaw(line: String) -> Void {
    RedLog.Append("ImmersiveFootwearPOV", line);
  }

  public static func Log(tag: String, message: String) -> Void {
    FootwearRedLogger.Append("INFO", tag, message);
  }

  public static func LogDebug(tag: String, message: String) -> Void {
    FootwearRedLogger.Append("DEBUG", tag, message);
  }

  public static func LogInfo(tag: String, message: String) -> Void {
    FootwearRedLogger.Append("INFO", tag, message);
  }

  public static func LogWarn(tag: String, message: String) -> Void {
    FootwearRedLogger.Append("WARN", tag, message);
  }

  public static func LogError(tag: String, message: String) -> Void {
    FootwearRedLogger.Append("ERROR", tag, message);
  }
}

// -----------------------------------------------------------------------------
// Fallback Implementation (when RedLogger is NOT installed)
// Routes messages to native REDengine console / log via FTLog
// -----------------------------------------------------------------------------
@if(!ModuleExists("RedLogger"))
public class FootwearRedLogger {

  public static func Append(level: String, tag: String, message: String) -> Void {
    if Equals(level, "WARN") {
      FTLogWarning(s"[ImmersiveFootwearPOV][\(tag)][WARN] \(message)");
    } else if Equals(level, "ERROR") {
      FTLogError(s"[ImmersiveFootwearPOV][\(tag)][ERROR] \(message)");
    } else {
      FTLog(s"[ImmersiveFootwearPOV][\(tag)][\(level)] \(message)");
    };
  }

  public static func AppendRaw(line: String) -> Void {
    FTLog(s"[ImmersiveFootwearPOV] \(line)");
  }

  public static func Log(tag: String, message: String) -> Void {
    FTLog(s"[ImmersiveFootwearPOV][\(tag)] \(message)");
  }

  public static func LogDebug(tag: String, message: String) -> Void {
    FTLog(s"[ImmersiveFootwearPOV][\(tag)][DEBUG] \(message)");
  }

  public static func LogInfo(tag: String, message: String) -> Void {
    FTLog(s"[ImmersiveFootwearPOV][\(tag)][INFO] \(message)");
  }

  public static func LogWarn(tag: String, message: String) -> Void {
    FTLogWarning(s"[ImmersiveFootwearPOV][\(tag)][WARN] \(message)");
  }

  public static func LogError(tag: String, message: String) -> Void {
    FTLogError(s"[ImmersiveFootwearPOV][\(tag)][ERROR] \(message)");
  }
}
