module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Catwalk Locomotion & Feminine Stride Controller
// Real-time pelvic roll, yaw swivel, thoracic counter-rotation, and leg tracking
// Native execution: zero FFI crossing per animation variable
// =============================================================================

public class StrideController {
  private let m_phase: Float;
  private let m_currentBlend: Float;
  private let m_currentRoll: Float;
  private let m_currentYaw: Float;
  private let m_currentSpineCounterYaw: Float;
  private let m_currentSpineCounterRoll: Float;
  private let m_currentLegCounterRoll: Float;
  private let m_currentHeelScale: Float;
  private let m_currentPitchCm: Float;
  private let m_statusText: String;
  private let m_hasZeroPublished: Bool;

  /**
   * Factory method initializing a new StrideController in idle state.
   * @return A newly initialized StrideController instance.
   */
  public static func Create() -> ref<StrideController> {
    let sc: ref<StrideController> = new StrideController();
    sc.m_statusText = "Idle";
    return sc;
  }

  /**
   * Primary frame update advancing gait phase, computing pelvic yaw/roll, counter-rotations, and publishing to animgraph.
   * @param sys Reference to ImmersiveFootwearPOVSystem.
   * @param player Local player puppet reference.
   * @param deltaTime Elapsed delta frame time in seconds.
   * @param enabled True if hip sway simulation is enabled in user settings.
   * @param intensityLow Multiplier for low heel heights (2.0cm to 5.08cm).
   * @param intensityMid Multiplier for mid heel heights (5.08cm to 7.5cm).
   * @param intensityHigh Multiplier for high heel heights (7.5cm and above).
   * @param isOverlayOpen True if diagnostics HUD or calibrator window is visible.
   */
  public func Update(sys: ref<ImmersiveFootwearPOVSystem>, player: ref<PlayerPuppet>, deltaTime: Float, enabled: Bool, intensityLow: Float, intensityMid: Float, intensityHigh: Float, isOverlayOpen: Bool) -> Void {
    if !enabled {
      if !this.m_hasZeroPublished {
        this.ResetValues();
        this.m_statusText = "Disabled by User Setting";
        this.Publish(player);
      };
      return;
    };

    if !IsDefined(player) || !IsDefined(sys) {
      if !this.m_hasZeroPublished {
        this.ResetValues();
        this.m_statusText = "System Unavailable";
        this.Publish(player);
      };
      return;
    };

    let ctx: ref<SwayContextData> = sys.GetSwayContext(player);
    if !IsDefined(ctx) {
      return;
    };

    let canSway: Bool = ctx.canSway;
    let heelScale: Float = ctx.heelScale;
    let speed: Float = ctx.speed;
    let reason: String = ctx.suppressionReason;
    let pitchCm: Float = ctx.heelPitchCm;

    this.m_currentHeelScale = heelScale;
    this.m_currentPitchCm = pitchCm;

    let targetBlend: Float = canSway ? 1.0 : 0.0;
    let blendSpeed: Float = targetBlend > this.m_currentBlend ? 5.0 : 6.0;

    if AbsF(targetBlend - this.m_currentBlend) > 0.001 {
      let delta: Float = (targetBlend - this.m_currentBlend) * blendSpeed * deltaTime;
      this.m_currentBlend = this.m_currentBlend + delta;
      if this.m_currentBlend < 0.0 { this.m_currentBlend = 0.0; };
      if this.m_currentBlend > 1.0 { this.m_currentBlend = 1.0; };
    } else {
      this.m_currentBlend = targetBlend;
    };

    let pi2: Float = 6.2831853; // 2 * pi
    if speed >= 0.15 {
      let freq: Float = MaxF(0.6, MinF(2.2, 0.55 + 0.32 * speed));
      this.m_phase = this.m_phase + (pi2 * freq * deltaTime);
      if this.m_phase > pi2 {
        this.m_phase = this.m_phase - pi2;
      };
    };

    let intensity: Float = 1.0;
    if pitchCm >= 7.50 {
      intensity = intensityHigh;
    } else if pitchCm >= 5.08 {
      intensity = intensityMid;
    } else if pitchCm >= 2.0 {
      intensity = intensityLow;
    } else {
      intensity = 0.0;
    };

    if this.m_currentBlend > 0.001 {
      let speedDamp: Float = 1.0;
      if speed > 3.0 {
        speedDamp = MaxF(0.40, 1.0 - (speed - 3.0) * 0.30);
      };

      let masterScale: Float = heelScale * intensity * this.m_currentBlend * speedDamp;
      let baseYaw: Float = 3.0;
      let baseRoll: Float = 4.8;

      this.m_currentYaw = -baseYaw * SinF(this.m_phase) * masterScale;
      this.m_currentRoll = baseRoll * CosF(this.m_phase) * masterScale;
      this.m_currentSpineCounterYaw = this.m_currentYaw * -0.55;
      this.m_currentSpineCounterRoll = this.m_currentRoll * -1.25;
      this.m_currentLegCounterRoll = this.m_currentRoll * -0.75;

      if isOverlayOpen {
        this.m_statusText = s"Active (Roll: \(this.m_currentRoll)°, Yaw: \(this.m_currentYaw)°, Pitch: \(pitchCm)cm, Speed: \(speed)m/s)";
      };
    } else {
      this.m_currentRoll = 0.0;
      this.m_currentYaw = 0.0;
      this.m_currentSpineCounterYaw = 0.0;
      this.m_currentSpineCounterRoll = 0.0;
      this.m_currentLegCounterRoll = 0.0;
      if isOverlayOpen {
        this.m_statusText = s"Inactive (\(reason))";
      };
    };

    this.Publish(player);
  }

  /**
   * Publishes calculated rotation angles to player animgraph input variables. Suppresses redundant zeroes.
   * @param player The local player puppet reference.
   */
  private func Publish(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) {
      return;
    };

    let isZero: Bool = this.m_currentBlend <= 0.0001 && this.m_currentRoll == 0.0 && this.m_currentYaw == 0.0;
    if isZero {
      if this.m_hasZeroPublished {
        return;
      };
      this.m_hasZeroPublished = true;
    } else {
      this.m_hasZeroPublished = false;
    };

    AnimationControllerComponent.SetInputFloat(player, n"ifp_hip_sway_roll", this.m_currentRoll);
    AnimationControllerComponent.SetInputFloat(player, n"ifp_hip_sway_yaw", this.m_currentYaw);
    AnimationControllerComponent.SetInputFloat(player, n"ifp_spine_counter_yaw", this.m_currentSpineCounterYaw);
    AnimationControllerComponent.SetInputFloat(player, n"ifp_spine_counter_roll", this.m_currentSpineCounterRoll);
    AnimationControllerComponent.SetInputFloat(player, n"ifp_leg_counter_roll", this.m_currentLegCounterRoll);
    AnimationControllerComponent.SetInputFloat(player, n"ifp_hip_sway_blend", this.m_currentBlend);
  }

  /**
   * Resets phase and sway angles to zero and immediately publishes zero state to player animgraph.
   * @param player The local player puppet reference.
   */
  public func Reset(player: ref<PlayerPuppet>) -> Void {
    this.m_phase = 0.0;
    this.ResetValues();
    this.m_statusText = "Reset";
    this.m_hasZeroPublished = false;
    if !IsDefined(player) {
      return;
    };
    this.Publish(player);
  }

  /**
   * Internal helper clearing all cached oscillation and angle states to zero.
   */
  private func ResetValues() -> Void {
    this.m_currentBlend = 0.0;
    this.m_currentRoll = 0.0;
    this.m_currentYaw = 0.0;
    this.m_currentSpineCounterYaw = 0.0;
    this.m_currentSpineCounterRoll = 0.0;
    this.m_currentLegCounterRoll = 0.0;
    this.m_currentHeelScale = 0.0;
    this.m_currentPitchCm = 0.0;
  }

  /**
   * Retrieves the current diagnostic status string describing stride state.
   * @return Human-readable status string.
   */
  public func GetStatusText() -> String { return this.m_statusText; }

  /**
   * Retrieves the instantaneous pelvic roll rotation in degrees.
   * @return Pelvic roll in degrees.
   */
  public func GetCurrentRoll() -> Float { return this.m_currentRoll; }

  /**
   * Retrieves the instantaneous pelvic yaw swivel rotation in degrees.
   * @return Pelvic yaw in degrees.
   */
  public func GetCurrentYaw() -> Float { return this.m_currentYaw; }

  /**
   * Retrieves the current sway blend weight scalar.
   * @return Normalized blend weight between 0.0 and 1.0.
   */
  public func GetCurrentBlend() -> Float { return this.m_currentBlend; }

  /**
   * Retrieves the current leg counter-roll angle in degrees.
   * @return Counter-roll angle in degrees.
   */
  public func GetCurrentLegCounterRoll() -> Float { return this.m_currentLegCounterRoll; }

  /**
   * Retrieves the normalized heel scale factor (0.0 to 1.0) applied to sway intensity.
   * @return Heel scale factor.
   */
  public func GetCurrentHeelScale() -> Float { return this.m_currentHeelScale; }

  /**
   * Retrieves the effective heel pitch in centimeters used for intensity tier evaluation.
   * @return Heel pitch in cm.
   */
  public func GetCurrentPitchCm() -> Float { return this.m_currentPitchCm; }
}
