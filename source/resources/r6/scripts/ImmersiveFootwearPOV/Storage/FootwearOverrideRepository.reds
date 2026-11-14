module ImmersiveFootwearPOV

// =============================================================================
// Shoe Override Entity & Typed Repository
// Single Responsibility: Encapsulates custom shoe height overrides and presets
// in a single prioritized repository collection (User Override > Preset).
// =============================================================================
public class ShoeOverrideEntry {
  public let key: String;
  public let lowerKey: String;
  public let normKey: String;
  public let heelMeters: Float;
  public let platformMeters: Float;
  public let isUserOverride: Bool;

  /**
   * Initializes a new shoe override entity with precomputed lowercase and normalized keys.
   */
  public static func Create(key: String, heelMeters: Float, platformMeters: Float, opt isUserOverride: Bool) -> ref<ShoeOverrideEntry> {
    let entry: ref<ShoeOverrideEntry> = new ShoeOverrideEntry();
    entry.key = key;
    entry.lowerKey = StrLower(key);
    entry.normKey = FootwearOverrideRepository.NormalizeKey(key);
    entry.heelMeters = heelMeters;
    entry.platformMeters = platformMeters;
    entry.isUserOverride = isUserOverride;
    return entry;
  }
}

public class FootwearOverrideRepository {
  private let m_entries: array<ref<ShoeOverrideEntry>>;

  /**
   * Creates a new empty FootwearOverrideRepository.
   */
  public static func Create() -> ref<FootwearOverrideRepository> {
    return new FootwearOverrideRepository();
  }

  /**
   * Normalizes a shoe key by converting to lowercase and stripping the 'items.' prefix if present.
   */
  public static func NormalizeKey(k: String) -> String {
    if StrLen(k) == 0 {
      return "";
    };
    let lower: String = StrLower(k);
    if StrBeginsWith(lower, "items.") {
      return StrReplace(lower, "items.", "");
    };
    return lower;
  }

  /**
   * Searches m_entries for a matching key within the requested tier (exact -> lowercase -> normalized).
   */
  private func FindEntryIndex(key: String, isUser: Bool) -> Int32 {
    let count: Int32 = ArraySize(this.m_entries);
    if StrLen(key) == 0 || count == 0 {
      return -1;
    };

    let i: Int32 = 0;
    while i < count {
      if Equals(this.m_entries[i].isUserOverride, isUser) && Equals(this.m_entries[i].key, key) {
        return i;
      };
      i += 1;
    };

    let lowerKey: String = StrLower(key);
    i = 0;
    while i < count {
      if Equals(this.m_entries[i].isUserOverride, isUser) && Equals(this.m_entries[i].lowerKey, lowerKey) {
        return i;
      };
      i += 1;
    };

    let normKey: String = FootwearOverrideRepository.NormalizeKey(key);
    i = 0;
    while i < count {
      if Equals(this.m_entries[i].isUserOverride, isUser) && Equals(this.m_entries[i].normKey, normKey) {
        return i;
      };
      i += 1;
    };

    return -1;
  }

  public func HasUserOverride(key: String) -> Bool {
    return this.FindEntryIndex(key, true) >= 0;
  }

  public func HasPreset(key: String) -> Bool {
    return this.FindEntryIndex(key, false) >= 0;
  }

  public func Has(key: String) -> Bool {
    return this.HasUserOverride(key) || this.HasPreset(key);
  }

  /**
   * Retrieves the highest-precedence entry for key (User Override prioritized over Preset).
   */
  public func Get(key: String) -> ref<ShoeOverrideEntry> {
    let idx: Int32 = this.FindEntryIndex(key, true);
    if idx >= 0 {
      return this.m_entries[idx];
    };
    idx = this.FindEntryIndex(key, false);
    if idx >= 0 {
      return this.m_entries[idx];
    };
    return null;
  }

  public func GetHeel(key: String) -> Float {
    let entry: ref<ShoeOverrideEntry> = this.Get(key);
    return IsDefined(entry) ? entry.heelMeters : 0.0;
  }

  public func GetPlatform(key: String) -> Float {
    let entry: ref<ShoeOverrideEntry> = this.Get(key);
    return IsDefined(entry) ? entry.platformMeters : 0.0;
  }

  /**
   * Shared upsert helper inserting or updating an override or preset entry with policy clamping.
   */
  private func UpsertEntry(key: String, heelMeters: Float, platformMeters: Float, isUser: Bool) -> Void {
    if StrLen(key) == 0 {
      return;
    };
    let clampedHeel: Float = FootwearClampingPolicy.ClampHeight(heelMeters);
    let clampedPlat: Float = FootwearClampingPolicy.ClampPlatformHeight(platformMeters);

    let idx: Int32 = this.FindEntryIndex(key, isUser);
    if idx >= 0 {
      this.m_entries[idx].heelMeters = clampedHeel;
      this.m_entries[idx].platformMeters = clampedPlat;
      return;
    };
    ArrayPush(this.m_entries, ShoeOverrideEntry.Create(key, clampedHeel, clampedPlat, isUser));
  }

  public func RegisterUserOverride(key: String, heelMeters: Float, platformMeters: Float) -> Void {
    this.UpsertEntry(key, heelMeters, platformMeters, true);
  }

  public func RegisterPreset(key: String, heelMeters: Float, platformMeters: Float) -> Void {
    this.UpsertEntry(key, heelMeters, platformMeters, false);
  }

  public func RemoveUserOverride(key: String) -> Bool {
    let idx: Int32 = this.FindEntryIndex(key, true);
    if idx < 0 {
      return false;
    };
    ArrayErase(this.m_entries, idx);
    return true;
  }

  public func Clear() -> Void {
    ArrayClear(this.m_entries);
  }

  public func ClearUserOverrides() -> Void {
    let i: Int32 = ArraySize(this.m_entries) - 1;
    while i >= 0 {
      if this.m_entries[i].isUserOverride {
        ArrayErase(this.m_entries, i);
      };
      i -= 1;
    };
  }

  public func GetCount() -> Int32 {
    return ArraySize(this.m_entries);
  }
}
