module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Telemetry & Diagnostic Logger
// Single Responsibility: Observational state logging and TFP telemetry output
// =============================================================================

public class FootwearTelemetryLogger {
  private let m_lastLoggedFootwear: ItemID;
  private let m_lastLoggedOffset: Float;
  private let m_lastLoggedSuppressed: Bool;

  /**
   * Factory method initializing a new FootwearTelemetryLogger instance.
   * @return A newly initialized FootwearTelemetryLogger.
   */
  public static func Create() -> ref<FootwearTelemetryLogger> {
    return new FootwearTelemetryLogger();
  }

  /**
   * Logs discrete True First Person camera lifecycle events (e.g. resets, attachments).
   * @param sys Reference to ImmersiveFootwearPOVSystem.
   * @param eventName Identifier of the lifecycle event.
   * @param baseZ Base camera Z in meters.
   * @param curZ Current camera Z in meters.
   */
  public func LogTFPEvent(sys: ref<ImmersiveFootwearPOVSystem>, eventName: String, baseZ: Float, curZ: Float) -> Void {
    if !IsDefined(sys) || !sys.IsDebugLogging() { return; };
    let tag: String = sys.GetActiveModTag(null);
    let offset: Float = sys.GetEffectiveOffset();
    let liftCm: Float = Cast<Float>(RoundF(offset * 1000.0)) / 10.0;
    let shoeName: String = sys.GetResolvedShoeDisplayName();
    let suppressed: Bool = sys.IsSuppressed();
    let reason: String = sys.GetSuppressionReason();
    let settingsSrc: String = sys.GetSettingsSource();
    FootwearRedLogger.LogDebug(tag, s"Event: \(eventName) | Footwear: '\(shoeName)' [\(settingsSrc)] (+\(liftCm) cm) | TFP BaseZ: \(baseZ) | CamZ: \(curZ) | Suppressed: \(suppressed) (\(reason))");
  }

  /**
   * Logs continuous camera state transitions during polling, throttled to item/suppression changes or significant deltas.
   * @param sys Reference to ImmersiveFootwearPOVSystem.
   * @param baseZ Base camera Z in meters.
   * @param curZ Current camera Z in meters.
   */
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

    if !itemChanged && !suppChanged && !(offsetChanged && isModuloZero) {
      return;
    };

    this.m_lastLoggedFootwear = item;
    this.m_lastLoggedOffset = offset;
    this.m_lastLoggedSuppressed = suppressed;

    let tag: String = sys.GetActiveModTag(null);
    let shoeName: String = sys.GetResolvedShoeDisplayName();
    let reason: String = sys.GetSuppressionReason();
    let settingsSrc: String = sys.GetSettingsSource();
    FootwearRedLogger.LogDebug(tag, s"Camera State Transition -> Footwear: '\(shoeName)' [\(settingsSrc)] | Lift: +\(liftCm) cm | TFP BaseZ: \(baseZ) | CamZ: \(curZ) | Suppressed: \(suppressed) (\(reason))");
  }

  /**
   * Logs entry or exit from a vehicle and the corresponding suppression action taken.
   * @param sys Reference to ImmersiveFootwearPOVSystem.
   * @param inVehicle True if vehicle mount detected, false if dismounted.
   */
  public static func LogVehicleState(sys: ref<ImmersiveFootwearPOVSystem>, inVehicle: Bool) -> Void {
    if !IsDefined(sys) { return; };
    let shoeName: String = sys.GetResolvedShoeDisplayName();
    let heelCm: Float = sys.GetCurrentHeelHeight() * 100.0;
    let platCm: Float = sys.GetCurrentPlatformHeight() * 100.0;
    let settingsSrc: String = sys.GetSettingsSource();
    let actionDesc: String = inVehicle
      ? "Suppression ENFORCED (Vehicle Occupancy: resetting effective offset to 0.0m, neutralizing stance)"
      : "Suppression CLEARED (Restoring footwear elevation)";
    FootwearRedLogger.LogInfo("VEHICLE", s"Vehicle state updated: inVehicle=\(inVehicle) | Action: \(actionDesc) | Shoe: '\(shoeName)' | Source: [\(settingsSrc)] | Heel: \(heelCm) cm | Platform: \(platCm) cm");
  }

  /**
   * Logs automatic recovery from vehicle occupancy suppression when player is detected on foot.
   * @param sys Reference to ImmersiveFootwearPOVSystem.
   */
  public static func LogVehicleAutoRecovered(sys: ref<ImmersiveFootwearPOVSystem>) -> Void {
    if !IsDefined(sys) { return; };
    let settingsSrc: String = sys.GetSettingsSource();
    FootwearRedLogger.LogWarn("VEHICLE", s"Vehicle state auto-recovered (Exited) | Action: Clearing Vehicle Occupancy suppression and restoring footwear elevation | Shoe: '\(sys.GetResolvedShoeDisplayName())' | Source: [\(settingsSrc)]");
  }

  /**
   * Logs entry or exit from an authored workspot animation and suppression state change.
   * @param sys Reference to ImmersiveFootwearPOVSystem.
   * @param inWorkspot True if player entered workspot, false if exited.
   */
  public static func LogWorkspotState(sys: ref<ImmersiveFootwearPOVSystem>, inWorkspot: Bool) -> Void {
    if !IsDefined(sys) { return; };
    let shoeName: String = sys.GetResolvedShoeDisplayName();
    let heelCm: Float = sys.GetCurrentHeelHeight() * 100.0;
    let platCm: Float = sys.GetCurrentPlatformHeight() * 100.0;
    let settingsSrc: String = sys.GetSettingsSource();
    let actionDesc: String = inWorkspot
      ? "Suppression ENFORCED (Authored Workspot: chair/vending machine/furniture: resetting effective offset to 0.0m, neutralizing stance)"
      : "Suppression CLEARED (Restoring footwear elevation)";
    FootwearRedLogger.LogInfo("WORKSPOT", s"Workspot state updated: inWorkspot=\(inWorkspot) | Action: \(actionDesc) | Shoe: '\(shoeName)' | Source: [\(settingsSrc)] | Heel: \(heelCm) cm | Platform: \(platCm) cm");
  }

  /**
   * Logs automatic recovery from authored workspot suppression when player stands up or departs.
   * @param sys Reference to ImmersiveFootwearPOVSystem.
   */
  public static func LogWorkspotAutoRecovered(sys: ref<ImmersiveFootwearPOVSystem>) -> Void {
    if !IsDefined(sys) { return; };
    let settingsSrc: String = sys.GetSettingsSource();
    FootwearRedLogger.LogWarn("WORKSPOT", s"Workspot state auto-recovered (Standing/Exited) | Action: Clearing Authored Workspot suppression and restoring footwear elevation | Shoe: '\(sys.GetResolvedShoeDisplayName())' | Source: [\(settingsSrc)]");
  }
}
