module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Observer Pattern & Granular State Listener Interfaces
// Interface Segregation Principle (ISP): Granular interfaces allow listeners
// to subscribe only to the events they are interested in.
// Open/Closed Principle (OCP): Extensible base classes for UI and integrations.
// =============================================================================

public abstract class IFootwearChangeListener {
  public func OnFootwearChanged(itemID: ItemID, heelMeters: Float, platformMeters: Float, source: String) -> Void {}
}

public abstract class ISuppressionChangeListener {
  public func OnSuppressionChanged(isSuppressed: Bool, reason: String) -> Void {}
}

public abstract class IConfigChangeListener {
  public func OnConfigChanged(config: ref<FootwearConfig>) -> Void {}
}

// Composite listener providing default no-op implementations for backwards compatibility
public abstract class IFootwearStateListener extends IFootwearChangeListener {
  public func OnSuppressionChanged(isSuppressed: Bool, reason: String) -> Void {}
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

  public static func Create() -> ref<FootwearEventDispatcher> {
    return new FootwearEventDispatcher();
  }

  // Registers a composite state listener across all event channels
  public func RegisterListener(listener: ref<IFootwearStateListener>) -> Void {
    if IsDefined(listener) {
      ArrayPush(this.m_compositeListeners, listener);
    };
  }

  // Unregisters a composite state listener across all event channels
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

  public func RegisterFootwearListener(l: ref<IFootwearChangeListener>) -> Void {
    if IsDefined(l) {
      ArrayPush(this.m_footwearListeners, l);
    };
  }

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

  public func RegisterSuppressionListener(l: ref<ISuppressionChangeListener>) -> Void {
    if IsDefined(l) {
      ArrayPush(this.m_suppressionListeners, l);
    };
  }

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

  public func RegisterConfigListener(l: ref<IConfigChangeListener>) -> Void {
    if IsDefined(l) {
      ArrayPush(this.m_configListeners, l);
    };
  }

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
