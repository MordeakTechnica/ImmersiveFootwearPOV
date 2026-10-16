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

  /**
   * Writes a categorized and tagged log message via RedLogger at the specified severity level.
   * @param level Severity level ("DEBUG", "INFO", "WARN", "ERROR").
   * @param tag Subsystem or component tag.
   * @param message Text content of the log message.
   */
  public static func Append(level: String, tag: String, message: String) -> Void {
    RedLog.AppendLevel("ImmersiveFootwearPOV", level, s"[\(tag)] \(message)");
  }

  /**
   * Writes an unformatted raw string directly to the mod's active log file.
   * @param line Raw text line to append.
   */
  public static func AppendRaw(line: String) -> Void {
    RedLog.Append("ImmersiveFootwearPOV", line);
  }

  /**
   * Convenience alias writing an INFO level log message.
   * @param tag Subsystem or component tag.
   * @param message Text content of the log message.
   */
  public static func Log(tag: String, message: String) -> Void {
    FootwearRedLogger.Append("INFO", tag, message);
  }

  /**
   * Writes a DEBUG level log message.
   * @param tag Subsystem or component tag.
   * @param message Text content of the log message.
   */
  public static func LogDebug(tag: String, message: String) -> Void {
    FootwearRedLogger.Append("DEBUG", tag, message);
  }

  /**
   * Writes an INFO level log message.
   * @param tag Subsystem or component tag.
   * @param message Text content of the log message.
   */
  public static func LogInfo(tag: String, message: String) -> Void {
    FootwearRedLogger.Append("INFO", tag, message);
  }

  /**
   * Writes a WARN level warning message.
   * @param tag Subsystem or component tag.
   * @param message Text content of the warning message.
   */
  public static func LogWarn(tag: String, message: String) -> Void {
    FootwearRedLogger.Append("WARN", tag, message);
  }

  /**
   * Writes an ERROR level error message.
   * @param tag Subsystem or component tag.
   * @param message Text content of the error message.
   */
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

  /**
   * Routes a categorized log message to REDengine native log based on severity.
   * @param level Severity level ("DEBUG", "INFO", "WARN", "ERROR").
   * @param tag Subsystem or component tag.
   * @param message Text content of the log message.
   */
  public static func Append(level: String, tag: String, message: String) -> Void {
    if Equals(level, "WARN") {
      FTLogWarning(s"[ImmersiveFootwearPOV][\(tag)][WARN] \(message)");
    } else if Equals(level, "ERROR") {
      FTLogError(s"[ImmersiveFootwearPOV][\(tag)][ERROR] \(message)");
    } else {
      FTLog(s"[ImmersiveFootwearPOV][\(tag)][\(level)] \(message)");
    };
  }

  /**
   * Writes an unformatted raw string to REDengine native log.
   * @param line Raw text line to log.
   */
  public static func AppendRaw(line: String) -> Void {
    FTLog(s"[ImmersiveFootwearPOV] \(line)");
  }

  /**
   * Convenience alias routing an INFO level log message to native log.
   * @param tag Subsystem or component tag.
   * @param message Text content of the log message.
   */
  public static func Log(tag: String, message: String) -> Void {
    FTLog(s"[ImmersiveFootwearPOV][\(tag)] \(message)");
  }

  /**
   * Writes a DEBUG level log message to native log.
   * @param tag Subsystem or component tag.
   * @param message Text content of the log message.
   */
  public static func LogDebug(tag: String, message: String) -> Void {
    FTLog(s"[ImmersiveFootwearPOV][\(tag)][DEBUG] \(message)");
  }

  /**
   * Writes an INFO level log message to native log.
   * @param tag Subsystem or component tag.
   * @param message Text content of the log message.
   */
  public static func LogInfo(tag: String, message: String) -> Void {
    FTLog(s"[ImmersiveFootwearPOV][\(tag)][INFO] \(message)");
  }

  /**
   * Writes a WARN level warning message to native warning stream.
   * @param tag Subsystem or component tag.
   * @param message Text content of the warning message.
   */
  public static func LogWarn(tag: String, message: String) -> Void {
    FTLogWarning(s"[ImmersiveFootwearPOV][\(tag)][WARN] \(message)");
  }

  /**
   * Writes an ERROR level error message to native error stream.
   * @param tag Subsystem or component tag.
   * @param message Text content of the error message.
   */
  public static func LogError(tag: String, message: String) -> Void {
    FTLogError(s"[ImmersiveFootwearPOV][\(tag)][ERROR] \(message)");
  }
}
