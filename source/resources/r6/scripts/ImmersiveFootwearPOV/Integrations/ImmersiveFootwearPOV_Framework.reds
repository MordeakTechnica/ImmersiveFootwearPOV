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

public class ITPDetector {
  public static func IsPresent(gameInstance: GameInstance) -> Bool {
    return ITPController.IsITPPresent(gameInstance);
  }
}
