module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Telemetry & Diagnostic Logger
// Single Responsibility: Observational state logging and TFP telemetry output
// =============================================================================

public class FootwearTelemetryLogger {
  private let m_lastLoggedFootwear: ItemID;
  private let m_lastLoggedOffset: Float;
  private let m_lastLoggedSuppressed: Bool;

  private let m_hasLoggedFootwearOnce: Bool;
  private let m_lastLoggedFootwearID: ItemID;
  private let m_lastLoggedSource: String;
  private let m_lastLoggedLayer: String;
  private let m_lastLoggedHeel: Float;
  private let m_lastLoggedPlatform: Float;

  /**
   * Initializes a new FootwearTelemetryLogger instance.
   * @return A newly initialized FootwearTelemetryLogger.
   */
  public static func Create() -> ref<FootwearTelemetryLogger> {
    return new FootwearTelemetryLogger();
  }

  /**
   * Logs equipped footwear resolution only when identity, source, layer, or height values actually changed.
   * @param state Authoritative FootwearEquipmentState snapshot.
   */
  public func LogFootwearUpdateIfChanged(state: ref<FootwearEquipmentState>) -> Void {
    if !IsDefined(state) { return; };

    let shoeChanged: Bool = !this.m_hasLoggedFootwearOnce
      || NotEquals(state.equippedFootwearID, this.m_lastLoggedFootwearID)
      || NotEquals(state.settingsSource, this.m_lastLoggedSource)
      || NotEquals(state.activeSource, this.m_lastLoggedLayer)
      || AbsF(state.currentHeelHeight - this.m_lastLoggedHeel) > 0.0005
      || AbsF(state.currentPlatformHeight - this.m_lastLoggedPlatform) > 0.0005;

    if !shoeChanged {
      return;
    };

    this.m_hasLoggedFootwearOnce = true;
    this.m_lastLoggedFootwearID = state.equippedFootwearID;
    this.m_lastLoggedSource = state.settingsSource;
    this.m_lastLoggedLayer = state.activeSource;
    this.m_lastLoggedHeel = state.currentHeelHeight;
    this.m_lastLoggedPlatform = state.currentPlatformHeight;

    let shoeName: String = FootwearDisplayHelper.GetResolvedShoeDisplayName(state.equippedFootwearID);
    let heelCm: Float = state.currentHeelHeight * 100.0;
    let platCm: Float = state.currentPlatformHeight * 100.0;
    FootwearRedLogger.LogInfo("FOOTWEAR", s"Equipped footwear updated: '\(shoeName)' | Source: [\(state.settingsSource)] | Layer: [\(state.activeSource)] | Heel: \(heelCm) cm | Platform: \(platCm) cm");
  }

  /**
   * Synchronizes deduplication state after live slider calibration without emitting duplicate equip logs.
   * @param state Authoritative FootwearEquipmentState snapshot.
   */
  public func SyncLiveCalibrationSnapshot(state: ref<FootwearEquipmentState>) -> Void {
    if !IsDefined(state) { return; };
    this.m_lastLoggedSource = state.settingsSource;
    this.m_lastLoggedHeel = state.currentHeelHeight;
    this.m_lastLoggedPlatform = state.currentPlatformHeight;
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
   * Logs entry or exit for a gameplay suppression context (Vehicle or Workspot) from the state snapshot.
   */
  public static func LogContextTransition(channel: FootwearContextChannel, active: Bool, state: ref<FootwearEquipmentState>) -> Void {
    let shoeName: String = IsDefined(state) ? FootwearDisplayHelper.GetResolvedShoeDisplayName(state.equippedFootwearID) : "None";
    let heelCm: Float = IsDefined(state) ? state.currentHeelHeight * 100.0 : 0.0;
    let platCm: Float = IsDefined(state) ? state.currentPlatformHeight * 100.0 : 0.0;
    let settingsSrc: String = IsDefined(state) ? state.settingsSource : "None";

    if Equals(channel, FootwearContextChannel.Vehicle) {
      let actionDesc: String = active
        ? "Suppression ENFORCED (Vehicle Occupancy: resetting effective offset to 0.0m, neutralizing stance)"
        : "Suppression CLEARED (Restoring footwear elevation)";
      FootwearRedLogger.LogInfo("VEHICLE", s"Vehicle state updated: inVehicle=\(active) | Action: \(actionDesc) | Shoe: '\(shoeName)' | Source: [\(settingsSrc)] | Heel: \(heelCm) cm | Platform: \(platCm) cm");
    } else {
      let actionDesc: String = active
        ? "Suppression ENFORCED (Authored Workspot: chair/vending machine/furniture: resetting effective offset to 0.0m, neutralizing stance)"
        : "Suppression CLEARED (Restoring footwear elevation)";
      FootwearRedLogger.LogInfo("WORKSPOT", s"Workspot state updated: inWorkspot=\(active) | Action: \(actionDesc) | Shoe: '\(shoeName)' | Source: [\(settingsSrc)] | Heel: \(heelCm) cm | Platform: \(platCm) cm");
    };
  }
}
