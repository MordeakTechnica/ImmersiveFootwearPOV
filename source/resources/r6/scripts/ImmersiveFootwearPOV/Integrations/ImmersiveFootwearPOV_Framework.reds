module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Framework Detection & Diagnostics
// Compile-time & runtime presence detection for 1st-person and outfit frameworks
// =============================================================================

@if(ModuleExists("TrueFirstPerson"))
public class FrameworkDetector {
  public static func IsTFPPresent() -> Bool {
    return true;
  }
}

@if(!ModuleExists("TrueFirstPerson"))
public class FrameworkDetector {
  public static func IsTFPPresent() -> Bool {
    return false;
  }
}

@if(ModuleExists("EquipmentEx"))
public class EquipmentExDetector {
  public static func IsPresent() -> Bool {
    return true;
  }
}

@if(!ModuleExists("EquipmentEx"))
public class EquipmentExDetector {
  public static func IsPresent() -> Bool {
    return false;
  }
}

@if(ModuleExists("ImmersiveThirdPersonMove360"))
public class ITPDetector {
  public static func IsPresent(gameInstance: GameInstance) -> Bool {
    return true;
  }
}

@if(!ModuleExists("ImmersiveThirdPersonMove360"))
public class ITPDetector {
  public static func IsPresent(gameInstance: GameInstance) -> Bool {
    return ITPController.IsITPPresent(gameInstance);
  }
}

// -----------------------------------------------------------------------------
// Animgraph Elevation & Blend Math Helper
// -----------------------------------------------------------------------------
public class FootwearAnimgraphHelper {

  /// Calculates skeletal animgraph blend value for 'ifp_height_blend'.
  /// Blend range is 0.0 (-0.50m) to 1.0 (+0.50m). Baseline 0.0m offset = 0.50.
  public static func CalculateHeightBlend(offsetMeters: Float) -> Float {
    return ClampF((offsetMeters + 0.50) / 1.00, 0.0, 1.0);
  }
}
