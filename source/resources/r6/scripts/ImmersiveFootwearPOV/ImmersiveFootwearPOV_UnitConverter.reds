module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Footwear Unit Converter
// Single Responsibility: DRY conversions between decimal meters, centimeters, and millimeters
// =============================================================================

public class FootwearUnitConverter {

  /**
   * Converts a parsed tag value string to meters based on a maximum allowed centimeter threshold.
   * Supports decimal meters ("0.06"), centimeters ("006", "6", "10"), and millimeters ("60", "80", "250").
   * @param valueStr Numeric substring extracted from the tag.
   * @param maxAllowedCm Upper boundary in centimeters defining the cm vs mm interpretation threshold.
   * @return Converted measurement in meters, or 0.0 if invalid.
   */
  public static func ConvertTagValueToMeters(valueStr: String, maxAllowedCm: Float) -> Float {
    if StrLen(valueStr) == 0 {
      return 0.0;
    };

    // If decimal point exists (e.g. "0.06", "0.10", "0.25")
    if StrFindFirst(valueStr, ".") >= 0 {
      return StringToFloat(valueStr);
    };

    let intVal: Int32 = StringToInt(valueStr);
    if intVal <= 0 {
      return 0.0;
    };

    let floatVal: Float = Cast<Float>(intVal);

    // If value is in range 1..maxAllowedCm, treat as centimeters (e.g. 6cm = 0.06m)
    if floatVal >= 1.0 && floatVal <= maxAllowedCm {
      return floatVal / 100.0;
    };

    // If value is in range (maxAllowedCm + 1)..(maxAllowedCm * 10), treat as millimeters (e.g. 60mm = 0.06m)
    if floatVal > maxAllowedCm && floatVal <= (maxAllowedCm * 10.0) {
      return floatVal / 1000.0;
    };

    return 0.0;
  }
}
