module ImmersiveFootwearPOV

// =============================================================================
// Shoe Override Entity & Typed Repository
// Single Responsibility: Encapsulates custom shoe height overrides in memory
// =============================================================================
public class ShoeOverrideEntry {
  public let key: String;
  public let lowerKey: String;
  public let heelMeters: Float;
  public let platformMeters: Float;

  public static func Create(key: String, heelMeters: Float, platformMeters: Float) -> ref<ShoeOverrideEntry> {
    let entry: ref<ShoeOverrideEntry> = new ShoeOverrideEntry();
    entry.key = key;
    entry.lowerKey = StrLower(key);
    entry.heelMeters = heelMeters;
    entry.platformMeters = platformMeters;
    return entry;
  }
}

public class FootwearOverrideRepository {
  private let m_entries: array<ref<ShoeOverrideEntry>>;

  public static func Create() -> ref<FootwearOverrideRepository> {
    return new FootwearOverrideRepository();
  }

  public func Clear() -> Void {
    ArrayClear(this.m_entries);
  }

  public func GetCount() -> Int32 {
    return ArraySize(this.m_entries);
  }

  public func FindIndex(key: String) -> Int32 {
    let count: Int32 = ArraySize(this.m_entries);
    let i: Int32 = 0;
    while i < count {
      if Equals(this.m_entries[i].key, key) {
        return i;
      };
      i += 1;
    };
    let lowerKey: String = StrLower(key);
    i = 0;
    while i < count {
      if Equals(this.m_entries[i].lowerKey, lowerKey) {
        return i;
      };
      i += 1;
    };
    return -1;
  }

  public func Has(key: String) -> Bool {
    return this.FindIndex(key) >= 0;
  }

  public func Get(key: String) -> ref<ShoeOverrideEntry> {
    let idx: Int32 = this.FindIndex(key);
    if idx >= 0 {
      return this.m_entries[idx];
    };
    return null;
  }

  public func GetHeel(key: String) -> Float {
    let entry: ref<ShoeOverrideEntry> = this.Get(key);
    if IsDefined(entry) {
      return entry.heelMeters;
    };
    return 0.0;
  }

  public func GetPlatform(key: String) -> Float {
    let entry: ref<ShoeOverrideEntry> = this.Get(key);
    if IsDefined(entry) {
      return entry.platformMeters;
    };
    return 0.0;
  }

  public func Register(key: String, heelMeters: Float, platformMeters: Float) -> Void {
    if StrLen(key) == 0 {
      return;
    };
    let clampedHeel: Float = FootwearClampingPolicy.ClampHeight(heelMeters);
    let clampedPlat: Float = FootwearClampingPolicy.ClampPlatformHeight(platformMeters);

    let idx: Int32 = this.FindIndex(key);
    if idx >= 0 {
      this.m_entries[idx].heelMeters = clampedHeel;
      this.m_entries[idx].platformMeters = clampedPlat;
    } else {
      ArrayPush(this.m_entries, ShoeOverrideEntry.Create(key, clampedHeel, clampedPlat));
    };
  }

  public func Remove(key: String) -> Bool {
    let idx: Int32 = this.FindIndex(key);
    if idx >= 0 {
      ArrayErase(this.m_entries, idx);
      return true;
    };
    return false;
  }
}
