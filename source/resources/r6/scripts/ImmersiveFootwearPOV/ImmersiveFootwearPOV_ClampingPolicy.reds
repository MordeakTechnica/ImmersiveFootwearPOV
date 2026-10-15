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
  public static func GetMaxHeightCm() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxHeightCm));
  }

  public static func GetMaxHeightMeters() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxHeightCm)) / 100.0;
  }

  public static func GetMaxPlatformCm() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxPlatformCm));
  }

  public static func GetMaxPlatformMeters() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxPlatformCm)) / 100.0;
  }

  public static func GetMaxIFPCm() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxIFPCm));
  }

  public static func GetMaxIFPMeters() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxIFPCm)) / 100.0;
  }
}

public class FootwearClampingPolicy {

  // Safety clamp to prevent extreme offsets (Heel / Sway pitch: max 40cm / 0.40m)
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

  // Safety clamp for First-Person / IFP camera elevation (strictly capped at 25cm / 0.25m)
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

  // Safety clamp to prevent extreme offsets (Platform / Third-Person / PM: max 30cm / 0.30m)
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
