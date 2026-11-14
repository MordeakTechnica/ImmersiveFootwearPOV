module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - State Change Listeners & Event Dispatcher
// =============================================================================

public abstract class IFootwearObserver {
  /**
   * Invoked when the player's equipped footwear changes or is recalibrated.
   */
  public func OnFootwearChanged(itemID: ItemID, heelMeters: Float, platformMeters: Float, source: String) -> Void {}

  /**
   * Invoked when footwear elevation suppression activates or deactivates.
   */
  public func OnSuppressionChanged(isSuppressed: Bool, reason: String) -> Void {}

  /**
   * Invoked when user configuration settings are reloaded or modified.
   */
  public func OnConfigChanged(config: ref<FootwearConfig>) -> Void {}
}

// -----------------------------------------------------------------------------
// Centralized Event Dispatcher (Single Responsibility for Listener Subscriptions)
// -----------------------------------------------------------------------------
public class FootwearEventDispatcher {
  private let m_observers: array<ref<IFootwearObserver>>;

  /**
   * Creates a new FootwearEventDispatcher instance.
   * @return A newly initialized dispatcher.
   */
  public static func Create() -> ref<FootwearEventDispatcher> {
    return new FootwearEventDispatcher();
  }

  /**
   * Registers an observer across state change channels.
   */
  public func RegisterObserver(observer: ref<IFootwearObserver>) -> Void {
    if !IsDefined(observer) {
      return;
    };
    ArrayPush(this.m_observers, observer);
  }

  /**
   * Unregisters an observer from state change notifications.
   */
  public func UnregisterObserver(observer: ref<IFootwearObserver>) -> Void {
    if !IsDefined(observer) {
      return;
    };
    let i: Int32 = 0;
    let count: Int32 = ArraySize(this.m_observers);
    while i < count {
      if this.m_observers[i] == observer {
        ArrayErase(this.m_observers, i);
        return;
      };
      i += 1;
    };
  }

  /**
   * Dispatches footwear change notifications to all registered observers.
   */
  public func NotifyFootwearChanged(itemID: ItemID, heel: Float, platform: Float, source: String) -> Void {
    let i: Int32 = 0;
    let count: Int32 = ArraySize(this.m_observers);
    while i < count {
      if IsDefined(this.m_observers[i]) {
        this.m_observers[i].OnFootwearChanged(itemID, heel, platform, source);
      };
      i += 1;
    };
  }

  /**
   * Dispatches suppression state change notifications to all registered observers.
   */
  public func NotifySuppressionChanged(suppressed: Bool, reason: String) -> Void {
    let i: Int32 = 0;
    let count: Int32 = ArraySize(this.m_observers);
    while i < count {
      if IsDefined(this.m_observers[i]) {
        this.m_observers[i].OnSuppressionChanged(suppressed, reason);
      };
      i += 1;
    };
  }

  /**
   * Dispatches configuration update notifications to all registered observers.
   */
  public func NotifyConfigChanged(config: ref<FootwearConfig>) -> Void {
    if !IsDefined(config) {
      return;
    };
    let i: Int32 = 0;
    let count: Int32 = ArraySize(this.m_observers);
    while i < count {
      if IsDefined(this.m_observers[i]) {
        this.m_observers[i].OnConfigChanged(config);
      };
      i += 1;
    };
  }
}
