module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Telemetry & Diagnostic Logger
// Single Responsibility: Observational state logging and TFP telemetry output
// =============================================================================

public class FootwearTelemetryLogger {
  private let m_lastLoggedFootwear: ItemID;
  private let m_lastLoggedOffset: Float;
  private let m_lastLoggedSuppressed: Bool;

  public static func Create() -> ref<FootwearTelemetryLogger> {
    return new FootwearTelemetryLogger();
  }

  public func LogTFPEvent(sys: ref<ImmersiveFootwearPOVSystem>, eventName: String, baseZ: Float, curZ: Float) -> Void {
    if !IsDefined(sys) || !sys.IsDebugLogging() { return; };
    let tag: String = sys.GetActiveModTag(null);
    let offset: Float = sys.GetEffectiveOffset();
    let liftCm: Float = Cast<Float>(RoundF(offset * 1000.0)) / 10.0;
    let shoeName: String = sys.GetResolvedShoeDisplayName();
    let suppressed: Bool = sys.IsSuppressed();
    let reason: String = sys.GetSuppressionReason();
    FootwearRedLogger.LogDebug(tag, s"Event: \(eventName) | Footwear: '\(shoeName)' (+\(liftCm) cm) | TFP BaseZ: \(baseZ) | CamZ: \(curZ) | Suppressed: \(suppressed) (\(reason))");
  }

  public func LogTFPPolling(sys: ref<ImmersiveFootwearPOVSystem>, baseZ: Float, curZ: Float) -> Void {
    if !IsDefined(sys) || !sys.IsDebugLogging() { return; };

    let item: ItemID = sys.GetEquippedFootwearID();
    let offset: Float = sys.GetEffectiveOffset();
    let suppressed: Bool = sys.IsSuppressed();

    let liftCm: Float = Cast<Float>(RoundF(offset * 1000.0)) / 10.0;
    let isModuloZero: Bool = (RoundF(liftCm * 10.0) % 5) == 0;

    let itemChanged: Bool = NotEquals(item, this.m_lastLoggedFootwear);
    let suppChanged: Bool = NotEquals(suppressed, this.m_lastLoggedSuppressed);
    let offsetChanged: Bool = AbsF(offset - this.m_lastLoggedOffset) > 0.0001;

    if itemChanged || suppChanged || (offsetChanged && isModuloZero) {
      this.m_lastLoggedFootwear = item;
      this.m_lastLoggedOffset = offset;
      this.m_lastLoggedSuppressed = suppressed;

      let tag: String = sys.GetActiveModTag(null);
      let shoeName: String = sys.GetResolvedShoeDisplayName();
      let reason: String = sys.GetSuppressionReason();
      FootwearRedLogger.LogDebug(tag, s"Camera State Transition -> Footwear: '\(shoeName)' | Lift: +\(liftCm) cm | TFP BaseZ: \(baseZ) | CamZ: \(curZ) | Suppressed: \(suppressed) (\(reason))");
    };
  }

  public static func LogVehicleState(sys: ref<ImmersiveFootwearPOVSystem>, inVehicle: Bool) -> Void {
    if !IsDefined(sys) { return; };
    let shoeName: String = sys.GetResolvedShoeDisplayName();
    let heelCm: Float = sys.GetCurrentHeelHeight() * 100.0;
    let platCm: Float = sys.GetCurrentPlatformHeight() * 100.0;
    let actionDesc: String = inVehicle
      ? "Suppression ENFORCED (Vehicle Occupancy: resetting effective offset to 0.0m, neutralizing stance)"
      : "Suppression CLEARED (Restoring footwear elevation)";
    FootwearRedLogger.LogInfo("VEHICLE", s"Vehicle state updated: inVehicle=\(inVehicle) | Action: \(actionDesc) | Shoe: '\(shoeName)' | Heel: \(heelCm) cm | Platform: \(platCm) cm");
  }

  public static func LogVehicleAutoRecovered(sys: ref<ImmersiveFootwearPOVSystem>) -> Void {
    if !IsDefined(sys) { return; };
    FootwearRedLogger.LogWarn("VEHICLE", s"Vehicle state auto-recovered (Exited) | Action: Clearing Vehicle Occupancy suppression and restoring footwear elevation | Shoe: '\(sys.GetResolvedShoeDisplayName())'");
  }

  public static func LogWorkspotState(sys: ref<ImmersiveFootwearPOVSystem>, inWorkspot: Bool) -> Void {
    if !IsDefined(sys) { return; };
    let shoeName: String = sys.GetResolvedShoeDisplayName();
    let heelCm: Float = sys.GetCurrentHeelHeight() * 100.0;
    let platCm: Float = sys.GetCurrentPlatformHeight() * 100.0;
    let actionDesc: String = inWorkspot
      ? "Suppression ENFORCED (Authored Workspot: chair/vending machine/furniture: resetting effective offset to 0.0m, neutralizing stance)"
      : "Suppression CLEARED (Restoring footwear elevation)";
    FootwearRedLogger.LogInfo("WORKSPOT", s"Workspot state updated: inWorkspot=\(inWorkspot) | Action: \(actionDesc) | Shoe: '\(shoeName)' | Heel: \(heelCm) cm | Platform: \(platCm) cm");
  }

  public static func LogWorkspotAutoRecovered(sys: ref<ImmersiveFootwearPOVSystem>) -> Void {
    if !IsDefined(sys) { return; };
    FootwearRedLogger.LogWarn("WORKSPOT", s"Workspot state auto-recovered (Standing/Exited) | Action: Clearing Authored Workspot suppression and restoring footwear elevation | Shoe: '\(sys.GetResolvedShoeDisplayName())'");
  }
}
