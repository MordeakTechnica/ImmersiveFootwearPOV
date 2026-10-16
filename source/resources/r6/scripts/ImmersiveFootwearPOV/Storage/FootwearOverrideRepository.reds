module ImmersiveFootwearPOV

// =============================================================================
// Shoe Override Entity & Typed Repository
// Single Responsibility: Encapsulates custom shoe height overrides in memory
// =============================================================================
public class ShoeOverrideEntry {
  public let key: String;
  public let lowerKey: String;
  public let normKey: String;
  public let heelMeters: Float;
  public let platformMeters: Float;

  /**
   * Factory method initializing a new shoe override entity with precomputed lowercase and normalized keys.
   * @param key Unique shoe identifier string.
   * @param heelMeters Heel height offset in meters.
   * @param platformMeters Platform height offset in meters.
   * @return A newly initialized ShoeOverrideEntry instance.
   */
  public static func Create(key: String, heelMeters: Float, platformMeters: Float) -> ref<ShoeOverrideEntry> {
    let entry: ref<ShoeOverrideEntry> = new ShoeOverrideEntry();
    entry.key = key;
    entry.lowerKey = StrLower(key);
    entry.normKey = FootwearOverrideRepository.NormalizeKey(key);
    entry.heelMeters = heelMeters;
    entry.platformMeters = platformMeters;
    return entry;
  }
}

public class FootwearOverrideRepository {
  private let m_entries: array<ref<ShoeOverrideEntry>>;

  /**
   * Factory method creating a new empty FootwearOverrideRepository.
   * @return A newly initialized repository instance.
   */
  public static func Create() -> ref<FootwearOverrideRepository> {
    return new FootwearOverrideRepository();
  }

  /**
   * Normalizes a shoe key by converting to lowercase and stripping the 'items.' prefix if present.
   * @param k Raw shoe key string.
   * @return Normalized identifier string.
   */
  public static func NormalizeKey(k: String) -> String {
    let lower: String = StrLower(k);
    if StrBeginsWith(lower, "items.") {
      return StrReplace(lower, "items.", "");
    };
    return lower;
  }

  /**
   * Removes all entries from the repository.
   */
  public func Clear() -> Void {
    ArrayClear(this.m_entries);
  }

  /**
   * Retrieves the current count of registered overrides.
   * @return Number of override entries stored.
   */
  public func GetCount() -> Int32 {
    return ArraySize(this.m_entries);
  }

  /**
   * Finds the array index for an entry matching the provided key, using case-exact match,
   * case-insensitive fallback, and normalized ('items.' prefix agnostic) fallback.
   * @param key Shoe identifier string to search for.
   * @return Zero-based index if found, -1 if not found.
   */
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
    let normKey: String = FootwearOverrideRepository.NormalizeKey(key);
    i = 0;
    while i < count {
      if Equals(this.m_entries[i].normKey, normKey) {
        return i;
      };
      i += 1;
    };
    return -1;
  }

  /**
   * Checks whether an override exists for the specified shoe identifier key.
   * @param key Shoe identifier string.
   * @return True if an override exists, false otherwise.
   */
  public func Has(key: String) -> Bool {
    return this.FindIndex(key) >= 0;
  }

  /**
   * Retrieves the override entry for a given shoe identifier key.
   * @param key Shoe identifier string.
   * @return The matching ShoeOverrideEntry, or null if not found.
   */
  public func Get(key: String) -> ref<ShoeOverrideEntry> {
    let idx: Int32 = this.FindIndex(key);
    if idx >= 0 {
      return this.m_entries[idx];
    };
    return null;
  }

  /**
   * Queries the heel height offset in meters for a given shoe key.
   * @param key Shoe identifier string.
   * @return Heel height in meters, or 0.0 if not overridden.
   */
  public func GetHeel(key: String) -> Float {
    let entry: ref<ShoeOverrideEntry> = this.Get(key);
    if IsDefined(entry) {
      return entry.heelMeters;
    };
    return 0.0;
  }

  /**
   * Queries the platform height offset in meters for a given shoe key.
   * @param key Shoe identifier string.
   * @return Platform height in meters, or 0.0 if not overridden.
   */
  public func GetPlatform(key: String) -> Float {
    let entry: ref<ShoeOverrideEntry> = this.Get(key);
    if IsDefined(entry) {
      return entry.platformMeters;
    };
    return 0.0;
  }

  /**
   * Adds or updates a shoe override entry with safety-clamped height bounds.
   * @param key Shoe identifier string.
   * @param heelMeters Raw heel height offset in meters.
   * @param platformMeters Raw platform height offset in meters.
   */
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

  /**
   * Deletes a shoe override entry from the repository.
   * @param key Shoe identifier string.
   * @return True if the entry was found and removed, false otherwise.
   */
  public func Remove(key: String) -> Bool {
    let idx: Int32 = this.FindIndex(key);
    if idx >= 0 {
      ArrayErase(this.m_entries, idx);
      return true;
    };
    return false;
  }
}
