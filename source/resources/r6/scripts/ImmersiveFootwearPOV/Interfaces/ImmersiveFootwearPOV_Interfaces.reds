module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Observer Pattern & Granular State Listener Interfaces
// Interface Segregation Principle (ISP): Granular interfaces allow listeners
// to subscribe only to the events they are interested in.
// Open/Closed Principle (OCP): Extensible base classes for UI and integrations.
// =============================================================================

public abstract class IFootwearChangeListener {
  /**
   * Invoked when the player's equipped footwear changes or is recalibrated.
   * @param itemID The ItemID of the newly equipped footwear.
   * @param heelMeters Heel height offset in meters.
   * @param platformMeters Platform height offset in meters.
   * @param source Identification tag of the resolution source (e.g. "Override", "Tag", "Fallback").
   */
  public func OnFootwearChanged(itemID: ItemID, heelMeters: Float, platformMeters: Float, source: String) -> Void {}
}

public abstract class ISuppressionChangeListener {
  /**
   * Invoked when footwear elevation suppression activates or deactivates.
   * @param isSuppressed True if elevation is currently suppressed.
   * @param reason Human-readable description of the active suppression trigger.
   */
  public func OnSuppressionChanged(isSuppressed: Bool, reason: String) -> Void {}
}

public abstract class IConfigChangeListener {
  /**
   * Invoked when user configuration settings are reloaded or modified.
   * @param config The updated FootwearConfig instance.
   */
  public func OnConfigChanged(config: ref<FootwearConfig>) -> Void {}
}

// Composite listener providing default no-op implementations for backwards compatibility
public abstract class IFootwearStateListener extends IFootwearChangeListener {
  /**
   * Invoked when footwear elevation suppression activates or deactivates.
   * @param isSuppressed True if elevation is currently suppressed.
   * @param reason Human-readable description of the active suppression trigger.
   */
  public func OnSuppressionChanged(isSuppressed: Bool, reason: String) -> Void {}

  /**
   * Invoked when user configuration settings are reloaded or modified.
   * @param config The updated FootwearConfig instance.
   */
  public func OnConfigChanged(config: ref<FootwearConfig>) -> Void {}
}

// -----------------------------------------------------------------------------
// Centralized Event Dispatcher (Single Responsibility for Observer Subscriptions)
// -----------------------------------------------------------------------------
public class FootwearEventDispatcher {
  private let m_compositeListeners: array<ref<IFootwearStateListener>>;
  private let m_footwearListeners: array<ref<IFootwearChangeListener>>;
  private let m_suppressionListeners: array<ref<ISuppressionChangeListener>>;
  private let m_configListeners: array<ref<IConfigChangeListener>>;

  /**
   * Factory method creating a new FootwearEventDispatcher instance.
   * @return A newly initialized dispatcher.
   */
  public static func Create() -> ref<FootwearEventDispatcher> {
    return new FootwearEventDispatcher();
  }

  /**
   * Registers a composite state listener across all event channels.
   * @param listener The composite listener to register.
   */
  public func RegisterListener(listener: ref<IFootwearStateListener>) -> Void {
    if IsDefined(listener) {
      ArrayPush(this.m_compositeListeners, listener);
    };
  }

  /**
   * Unregisters a composite state listener across all event channels.
   * @param listener The composite listener to remove.
   */
  public func UnregisterListener(listener: ref<IFootwearStateListener>) -> Void {
    let count: Int32 = ArraySize(this.m_compositeListeners);
    let i: Int32 = 0;
    while i < count {
      if this.m_compositeListeners[i] == listener {
        ArrayErase(this.m_compositeListeners, i);
        return;
      };
      i += 1;
    };
  }

  /**
   * Registers a listener interested specifically in footwear change events.
   * @param l The footwear change listener to add.
   */
  public func RegisterFootwearListener(l: ref<IFootwearChangeListener>) -> Void {
    if IsDefined(l) {
      ArrayPush(this.m_footwearListeners, l);
    };
  }

  /**
   * Unregisters a footwear change listener.
   * @param l The footwear change listener to remove.
   */
  public func UnregisterFootwearListener(l: ref<IFootwearChangeListener>) -> Void {
    let count: Int32 = ArraySize(this.m_footwearListeners);
    let i: Int32 = 0;
    while i < count {
      if this.m_footwearListeners[i] == l {
        ArrayErase(this.m_footwearListeners, i);
        return;
      };
      i += 1;
    };
  }

  /**
   * Registers a listener interested specifically in suppression state changes.
   * @param l The suppression change listener to add.
   */
  public func RegisterSuppressionListener(l: ref<ISuppressionChangeListener>) -> Void {
    if IsDefined(l) {
      ArrayPush(this.m_suppressionListeners, l);
    };
  }

  /**
   * Unregisters a suppression change listener.
   * @param l The suppression change listener to remove.
   */
  public func UnregisterSuppressionListener(l: ref<ISuppressionChangeListener>) -> Void {
    let count: Int32 = ArraySize(this.m_suppressionListeners);
    let i: Int32 = 0;
    while i < count {
      if this.m_suppressionListeners[i] == l {
        ArrayErase(this.m_suppressionListeners, i);
        return;
      };
      i += 1;
    };
  }

  /**
   * Registers a listener interested specifically in configuration updates.
   * @param l The configuration change listener to add.
   */
  public func RegisterConfigListener(l: ref<IConfigChangeListener>) -> Void {
    if IsDefined(l) {
      ArrayPush(this.m_configListeners, l);
    };
  }

  /**
   * Unregisters a configuration change listener.
   * @param l The configuration change listener to remove.
   */
  public func UnregisterConfigListener(l: ref<IConfigChangeListener>) -> Void {
    let count: Int32 = ArraySize(this.m_configListeners);
    let i: Int32 = 0;
    while i < count {
      if this.m_configListeners[i] == l {
        ArrayErase(this.m_configListeners, i);
        return;
      };
      i += 1;
    };
  }

  /**
   * Dispatches footwear change notifications to all registered footwear and composite listeners.
   * @param itemID The ItemID of the newly equipped footwear.
   * @param heel Heel height offset in meters.
   * @param platform Platform height offset in meters.
   * @param source Identification tag of the resolution source.
   */
  public func NotifyFootwearChanged(itemID: ItemID, heel: Float, platform: Float, source: String) -> Void {
    let count: Int32 = ArraySize(this.m_footwearListeners);
    let i: Int32 = 0;
    while i < count {
      if IsDefined(this.m_footwearListeners[i]) {
        this.m_footwearListeners[i].OnFootwearChanged(itemID, heel, platform, source);
      };
      i += 1;
    };

    let compCount: Int32 = ArraySize(this.m_compositeListeners);
    let j: Int32 = 0;
    while j < compCount {
      if IsDefined(this.m_compositeListeners[j]) {
        this.m_compositeListeners[j].OnFootwearChanged(itemID, heel, platform, source);
      };
      j += 1;
    };
  }

  /**
   * Dispatches suppression state change notifications to all registered suppression and composite listeners.
   * @param suppressed True if elevation is currently suppressed.
   * @param reason Human-readable description of the active suppression trigger.
   */
  public func NotifySuppressionChanged(suppressed: Bool, reason: String) -> Void {
    let count: Int32 = ArraySize(this.m_suppressionListeners);
    let i: Int32 = 0;
    while i < count {
      if IsDefined(this.m_suppressionListeners[i]) {
        this.m_suppressionListeners[i].OnSuppressionChanged(suppressed, reason);
      };
      i += 1;
    };

    let compCount: Int32 = ArraySize(this.m_compositeListeners);
    let j: Int32 = 0;
    while j < compCount {
      if IsDefined(this.m_compositeListeners[j]) {
        this.m_compositeListeners[j].OnSuppressionChanged(suppressed, reason);
      };
      j += 1;
    };
  }

  /**
   * Dispatches configuration update notifications to all registered config and composite listeners.
   * @param config The updated FootwearConfig instance.
   */
  public func NotifyConfigChanged(config: ref<FootwearConfig>) -> Void {
    let count: Int32 = ArraySize(this.m_configListeners);
    let i: Int32 = 0;
    while i < count {
      if IsDefined(this.m_configListeners[i]) {
        this.m_configListeners[i].OnConfigChanged(config);
      };
      i += 1;
    };

    let compCount: Int32 = ArraySize(this.m_compositeListeners);
    let j: Int32 = 0;
    while j < compCount {
      if IsDefined(this.m_compositeListeners[j]) {
        this.m_compositeListeners[j].OnConfigChanged(config);
      };
      j += 1;
    };
  }
}
