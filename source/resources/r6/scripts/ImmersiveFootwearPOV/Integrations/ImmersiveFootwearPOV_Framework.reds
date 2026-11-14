module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Framework Detection & Diagnostics
// Compile-time & runtime presence detection for 1st-person and outfit frameworks
// Design Pattern: Adapter / Registry Pattern (FrameworkIntegrationService)
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

@if(ModuleExists("NegotiableThirdPerson"))
public class NTPDetector {
  /**
   * Checks whether Negotiable Third Person (NTP) module is compiled and present.
   * @return True if NegotiableThirdPerson module exists.
   */
  public static func IsPresent() -> Bool {
    return true;
  }
}

@if(!ModuleExists("NegotiableThirdPerson"))
public class NTPDetector {
  /**
   * Checks whether Negotiable Third Person (NTP) module is compiled and present.
   * @return False when NegotiableThirdPerson module is absent.
   */
  public static func IsPresent() -> Bool {
    return false;
  }
}

// -----------------------------------------------------------------------------
// Animgraph Elevation & Blend Math Helper
// -----------------------------------------------------------------------------
public class FootwearAnimgraphHelper {

  /**
   * Calculates skeletal animgraph blend value for 'ifp_height_blend'.
   * IFP v3 contract range is -1.00m (0.0 blend) to +2.00m (1.0 blend), total span 3.00m.
   * Baseline 0.0m offset = (0.0 - (-1.00)) / 3.00 = 1.00 / 3.00 ~= 0.333333.
   * @param offsetMeters Elevation offset in meters.
   * @return Clamped normalized blend scalar between 0.0 and 1.0.
   */
  public static func CalculateHeightBlend(offsetMeters: Float) -> Float {
    return ClampF((offsetMeters + 1.00) / 3.00, 0.0, 1.0);
  }
}

// -----------------------------------------------------------------------------
// Framework Integration Service (Adapter / Registry Pattern)
// Single Responsibility Principle (SRP) & Open/Closed Principle (OCP)
// -----------------------------------------------------------------------------
public class FrameworkIntegrationService {
  private let m_isIFPPresent: Bool;
  private let m_isITPPresent: Bool;
  private let m_isITPChecked: Bool;
  private let m_isPhotoModeActive: Bool;

  /**
   * Factory method initializing a new FrameworkIntegrationService instance.
   * @return Initialized FrameworkIntegrationService instance.
   */
  public static func Create() -> ref<FrameworkIntegrationService> {
    let service: ref<FrameworkIntegrationService> = new FrameworkIntegrationService();
    return service;
  }

  /**
   * Checks whether Immersive First Person (IFP) is present.
   * @return True if IFP is available.
   */
  public func IsIFPPresent() -> Bool {
    return this.m_isIFPPresent;
  }

  /**
   * Sets the IFP presence flag.
   * @param present True if IFP detected.
   */
  public func SetIFPPresent(present: Bool) -> Void {
    this.m_isIFPPresent = present;
  }

  /**
   * Checks whether Immersive Third Person (ITP) is present in the game instance (cached).
   * @param gameInstance The active GameInstance.
   * @return True if ITP is available.
   */
  public func IsITPPresent(gameInstance: GameInstance) -> Bool {
    if !this.m_isITPChecked {
      this.m_isITPChecked = true;
      this.m_isITPPresent = ITPDetector.IsPresent(gameInstance);
    };
    return this.m_isITPPresent;
  }

  /**
   * Sets the ITP presence flag and marks presence as checked.
   * @param present True if ITP detected.
   */
  public func SetITPPresent(present: Bool) -> Void {
    this.m_isITPPresent = present;
    this.m_isITPChecked = true;
  }

  /**
   * Checks whether Photo Mode is currently active in the game session.
   * @param gameInstance The active GameInstance.
   * @return True if Photo Mode is active.
   */
  public func IsPhotoModeActive(gameInstance: GameInstance) -> Bool {
    let pmSys: ref<PhotoModeSystem> = GameInstance.GetPhotoModeSystem(gameInstance);
    if IsDefined(pmSys) {
      return pmSys.IsPhotoModeActive();
    };
    return this.m_isPhotoModeActive;
  }

  /**
   * Explicitly sets the internal Photo Mode state flag.
   * @param active True if Photo Mode activated.
   */
  public func SetPhotoModeActive(active: Bool) -> Void {
    this.m_isPhotoModeActive = active;
  }

  /**
   * Checks whether True First Person (TFP) is installed.
   * @return True if TFP is present.
   */
  public func IsTFPPresent() -> Bool {
    return FrameworkDetector.IsTFPPresent();
  }

  /**
   * Checks whether Equipment-EX is installed.
   * @return True if EquipmentEx is present.
   */
  public func IsEquipmentExPresent() -> Bool {
    return EquipmentExDetector.IsPresent();
  }

  /**
   * Checks whether third-person camera is actively rendering for the player.
   * @param player The local player puppet reference.
   * @param currentTppState Optional current perspective state for hysteresis evaluation.
   * @return True if in third-person view.
   */
  public func IsTPPActive(player: ref<PlayerPuppet>, opt currentTppState: Bool) -> Bool {
    return ITPController.IsTPPActive(player, currentTppState);
  }

  /**
   * Checks whether Negotiable Third Person (NTP) is present.
   * @return True if NTP is available.
   */
  public func IsNTPPresent() -> Bool {
    return NTPDetector.IsPresent();
  }

  /**
   * Resolves the active camera or framework integration acronym tag (PM, ITP, TFP, IFP).
   * @param gameInstance The active GameInstance.
   * @param player Optional local player puppet reference.
   * @return 2-3 letter framework acronym string.
   */
  public func GetActiveModTag(gameInstance: GameInstance, opt player: ref<PlayerPuppet>) -> String {
    if this.IsPhotoModeActive(gameInstance) {
      return "PM";
    };
    if this.IsITPPresent(gameInstance) {
      return "ITP";
    };
    if this.IsTFPPresent() {
      return "TFP";
    };
    if this.m_isIFPPresent {
      return "IFP";
    };
    return "PM";
  }
}
