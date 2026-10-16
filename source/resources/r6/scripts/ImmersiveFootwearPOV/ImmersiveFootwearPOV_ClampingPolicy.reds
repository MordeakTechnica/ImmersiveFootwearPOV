module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Global Height Limits & Safety Clamping Policy
// Single Responsibility: Enforces vertical limits and safety clamping across perspectives
// =============================================================================

public enum FootwearHeightLimit {
  MaxHeightCm = 40,
  MaxPlatformCm = 30,
  MaxIFPCm = 25
}

public class FootwearHeightLimits {
  /**
   * Retrieves the maximum allowed footwear heel height limit in centimeters.
   * @return Maximum height limit in cm.
   */
  public static func GetMaxHeightCm() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxHeightCm));
  }

  /**
   * Retrieves the maximum allowed footwear heel height limit converted to meters.
   * @return Maximum height limit in meters (0.40m).
   */
  public static func GetMaxHeightMeters() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxHeightCm)) / 100.0;
  }

  /**
   * Retrieves the maximum allowed platform height limit in centimeters.
   * @return Maximum platform height in cm.
   */
  public static func GetMaxPlatformCm() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxPlatformCm));
  }

  /**
   * Retrieves the maximum allowed platform height limit converted to meters.
   * @return Maximum platform height in meters (0.30m).
   */
  public static func GetMaxPlatformMeters() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxPlatformCm)) / 100.0;
  }

  /**
   * Retrieves the maximum first-person camera elevation limit in centimeters.
   * @return Maximum IFP camera elevation limit in cm.
   */
  public static func GetMaxIFPCm() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxIFPCm));
  }

  /**
   * Retrieves the maximum first-person camera elevation limit converted to meters.
   * @return Maximum IFP camera elevation limit in meters (0.25m).
   */
  public static func GetMaxIFPMeters() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxIFPCm)) / 100.0;
  }
}

public class FootwearClampingPolicy {

  /**
   * Enforces safety bounds on footwear heel height in meters.
   * @param val Raw height value in meters.
   * @return Clamped height value between 0.0 and maximum heel height (0.40m).
   */
  public static func ClampHeight(val: Float) -> Float {
    if val < 0.0 {
      return 0.0;
    };
    let maxMeters: Float = FootwearHeightLimits.GetMaxHeightMeters();
    if val > maxMeters {
      return maxMeters;
    };
    return val;
  }

  /**
   * Enforces safety bounds on first-person camera elevation in meters.
   * @param val Raw camera elevation value in meters.
   * @return Clamped elevation value between 0.0 and maximum IFP elevation (0.25m).
   */
  public static func ClampIFPHeight(val: Float) -> Float {
    if val < 0.0 {
      return 0.0;
    };
    let maxMeters: Float = FootwearHeightLimits.GetMaxIFPMeters();
    if val > maxMeters {
      return maxMeters;
    };
    return val;
  }

  /**
   * Enforces safety bounds on platform and third-person body offsets in meters.
   * @param val Raw platform/PM offset value in meters.
   * @return Clamped offset value between 0.0 and maximum platform height (0.30m).
   */
  public static func ClampPlatformHeight(val: Float) -> Float {
    if val < 0.0 {
      return 0.0;
    };
    let maxMeters: Float = FootwearHeightLimits.GetMaxPlatformMeters();
    if val > maxMeters {
      return maxMeters;
    };
    return val;
  }
}
