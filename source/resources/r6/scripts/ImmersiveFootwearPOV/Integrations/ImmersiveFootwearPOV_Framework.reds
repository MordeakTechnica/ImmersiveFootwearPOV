module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Framework Detection & Diagnostics
// Compile-time & runtime presence detection for 1st-person and outfit frameworks
// =============================================================================

@if(ModuleExists("TrueFirstPerson"))
public class FrameworkDetector {
  /**
   * Checks whether True First Person (TFP) module is compiled and present.
   * @return True if TrueFirstPerson module exists.
   */
  public static func IsTFPPresent() -> Bool {
    return true;
  }
}

@if(!ModuleExists("TrueFirstPerson"))
public class FrameworkDetector {
  /**
   * Checks whether True First Person (TFP) module is compiled and present.
   * @return False when TrueFirstPerson module is absent.
   */
  public static func IsTFPPresent() -> Bool {
    return false;
  }
}

@if(ModuleExists("EquipmentEx"))
public class EquipmentExDetector {
  /**
   * Checks whether Equipment-EX module is compiled and present.
   * @return True if EquipmentEx module exists.
   */
  public static func IsPresent() -> Bool {
    return true;
  }
}

@if(!ModuleExists("EquipmentEx"))
public class EquipmentExDetector {
  /**
   * Checks whether Equipment-EX module is compiled and present.
   * @return False when EquipmentEx module is absent.
   */
  public static func IsPresent() -> Bool {
    return false;
  }
}

@if(ModuleExists("ImmersiveThirdPersonMove360"))
public class ITPDetector {
  /**
   * Checks whether Immersive Third Person (ITP) module is compiled and present.
   * @param gameInstance The active GameInstance.
   * @return True if ImmersiveThirdPersonMove360 module exists.
   */
  public static func IsPresent(gameInstance: GameInstance) -> Bool {
    return true;
  }
}

@if(!ModuleExists("ImmersiveThirdPersonMove360"))
public class ITPDetector {
  /**
   * Checks whether Immersive Third Person (ITP) is available at runtime.
   * @param gameInstance The active GameInstance.
   * @return True if ITP runtime controller detects presence, false otherwise.
   */
  public static func IsPresent(gameInstance: GameInstance) -> Bool {
    return ITPController.IsITPPresent(gameInstance);
  }
}

// -----------------------------------------------------------------------------
// Animgraph Elevation & Blend Math Helper
// -----------------------------------------------------------------------------
public class FootwearAnimgraphHelper {

  /**
   * Calculates skeletal animgraph blend value for 'ifp_height_blend'.
   * Blend range is 0.0 (-0.50m) to 1.0 (+0.50m). Baseline 0.0m offset = 0.50.
   * @param offsetMeters Elevation offset in meters.
   * @return Clamped normalized blend scalar between 0.0 and 1.0.
   */
  public static func CalculateHeightBlend(offsetMeters: Float) -> Float {
    return ClampF((offsetMeters + 0.50) / 1.00, 0.0, 1.0);
  }
}
