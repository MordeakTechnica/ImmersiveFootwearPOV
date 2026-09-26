module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Telemetry & Diagnostic Logger
// Observational state logging and TFP telemetry output
// =============================================================================

public class FootwearTelemetryLogger {

  public static func LogTFPEvent(sys: ref<ImmersiveFootwearPOVSystem>, eventName: String, baseZ: Float, curZ: Float) -> Void {
    if !IsDefined(sys) || !sys.IsDebugLogging() { return; };
    let tag: String = sys.GetActiveModTag(null);
    let offset: Float = sys.GetEffectiveOffset();
    let liftCm: Float = Cast<Float>(RoundF(offset * 1000.0)) / 10.0;
    let shoeName: String = sys.GetResolvedShoeDisplayName();
    let suppressed: Bool = sys.IsSuppressed();
    let reason: String = sys.GetSuppressionReason();
    FootwearRedLogger.LogDebug(tag, s"Event: \(eventName) | Footwear: '\(shoeName)' (+\(liftCm) cm) | TFP BaseZ: \(baseZ) | CamZ: \(curZ) | Suppressed: \(suppressed) (\(reason))");
  }

  public static func LogTFPPolling(sys: ref<ImmersiveFootwearPOVSystem>, baseZ: Float, curZ: Float) -> Void {
    if !IsDefined(sys) || !sys.IsDebugLogging() { return; };

    let item: ItemID = sys.GetEquippedFootwearID();
    let offset: Float = sys.GetEffectiveOffset();
    let suppressed: Bool = sys.IsSuppressed();

    if NotEquals(item, sys.GetTFPLastLoggedFootwear()) || AbsF(offset - sys.GetTFPLastLoggedOffset()) > 0.0005 || NotEquals(suppressed, sys.GetTFPLastLoggedSuppressed()) {
      sys.SetTFPLastLoggedState(item, offset, suppressed);

      let tag: String = sys.GetActiveModTag(null);
      let liftCm: Float = Cast<Float>(RoundF(offset * 1000.0)) / 10.0;
      let shoeName: String = sys.GetResolvedShoeDisplayName();
      let reason: String = sys.GetSuppressionReason();
      FootwearRedLogger.LogDebug(tag, s"Camera State Transition -> Footwear: '\(shoeName)' | Lift: +\(liftCm) cm | TFP BaseZ: \(baseZ) | CamZ: \(curZ) | Suppressed: \(suppressed) (\(reason))");
    };
  }
}
