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
  public let isUserOverride: Bool;

  /**
   * Factory method initializing a new shoe override entity with precomputed lowercase and normalized keys.
   * @param key Unique shoe identifier string.
   * @param heelMeters Heel height offset in meters.
   * @param platformMeters Platform height offset in meters.
   * @param isUserOverride True if this entry was calibrated and saved by the user, false if from presets.
   * @return A newly initialized ShoeOverrideEntry instance.
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
  private let m_userOverrides: array<ref<ShoeOverrideEntry>>;
  private let m_presets: array<ref<ShoeOverrideEntry>>;

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
   * Helper searching for a shoe key index within a specific entry array.
   */
  private func FindIndexIn(entries: array<ref<ShoeOverrideEntry>>, key: String) -> Int32 {
    let count: Int32 = ArraySize(entries);
    if StrLen(key) == 0 || count == 0 {
      return -1;
    };
    let i: Int32 = 0;
    while i < count {
      if Equals(entries[i].key, key) {
        return i;
      };
      i += 1;
    };
    let lowerKey: String = StrLower(key);
    i = 0;
    while i < count {
      if Equals(entries[i].lowerKey, lowerKey) {
        return i;
      };
      i += 1;
    };
    let normKey: String = FootwearOverrideRepository.NormalizeKey(key);
    i = 0;
    while i < count {
      if Equals(entries[i].normKey, normKey) {
        return i;
      };
      i += 1;
    };
    return -1;
  }

  /**
   * Finds index in user overrides array.
   */
  public func FindUserOverrideIndex(key: String) -> Int32 {
    if StrLen(key) == 0 {
      return -1;
    };
    return this.FindIndexIn(this.m_userOverrides, key);
  }

  /**
   * Finds index in presets array.
   */
  public func FindPresetIndex(key: String) -> Int32 {
    if StrLen(key) == 0 {
      return -1;
    };
    return this.FindIndexIn(this.m_presets, key);
  }

  /**
   * Checks whether a user-calibrated override exists for the key.
   */
  public func HasUserOverride(key: String) -> Bool {
    if StrLen(key) == 0 {
      return false;
    };
    return this.FindUserOverrideIndex(key) >= 0;
  }

  /**
   * Checks whether a master preset exists for the key.
   */
  public func HasPreset(key: String) -> Bool {
    if StrLen(key) == 0 {
      return false;
    };
    return this.FindPresetIndex(key) >= 0;
  }

  /**
   * Checks whether any override or preset exists for the specified shoe identifier key.
   * @param key Shoe identifier string.
   * @return True if user override or preset exists, false otherwise.
   */
  public func Has(key: String) -> Bool {
    if StrLen(key) == 0 {
      return false;
    };
    return this.HasUserOverride(key) || this.HasPreset(key);
  }

  /**
   * Retrieves the override entry for a given shoe identifier key (User override prioritized over preset).
   * @param key Shoe identifier string.
   * @return The matching ShoeOverrideEntry, or null if not found.
   */
  public func Get(key: String) -> ref<ShoeOverrideEntry> {
    if StrLen(key) == 0 {
      return null;
    };
    let userIdx: Int32 = this.FindUserOverrideIndex(key);
    if userIdx >= 0 {
      return this.m_userOverrides[userIdx];
    };
    let presetIdx: Int32 = this.FindPresetIndex(key);
    if presetIdx >= 0 {
      return this.m_presets[presetIdx];
    };
    return null;
  }

  /**
   * Queries the source name ("User Override" or "Preset") for a given shoe key.
   */
  public func GetSettingsSource(key: String) -> String {
    if StrLen(key) == 0 {
      return "";
    };
    if this.HasUserOverride(key) {
      return "User Override";
    };
    if this.HasPreset(key) {
      return "Preset";
    };
    return "";
  }

  /**
   * Queries the heel height offset in meters for a given shoe key.
   * @param key Shoe identifier string.
   * @return Heel height in meters, or 0.0 if not overridden.
   */
  public func GetHeel(key: String) -> Float {
    let entry: ref<ShoeOverrideEntry> = this.Get(key);
    if !IsDefined(entry) {
      return 0.0;
    };
    return entry.heelMeters;
  }

  /**
   * Queries the platform height offset in meters for a given shoe key.
   * @param key Shoe identifier string.
   * @return Platform height in meters, or 0.0 if not overridden.
   */
  public func GetPlatform(key: String) -> Float {
    let entry: ref<ShoeOverrideEntry> = this.Get(key);
    if !IsDefined(entry) {
      return 0.0;
    };
    return entry.platformMeters;
  }

  /**
   * Adds or updates a user-calibrated override entry.
   */
  public func RegisterUserOverride(key: String, heelMeters: Float, platformMeters: Float) -> Void {
    if StrLen(key) == 0 {
      return;
    };
    let clampedHeel: Float = FootwearClampingPolicy.ClampHeight(heelMeters);
    let clampedPlat: Float = FootwearClampingPolicy.ClampPlatformHeight(platformMeters);

    let idx: Int32 = this.FindUserOverrideIndex(key);
    if idx >= 0 {
      this.m_userOverrides[idx].heelMeters = clampedHeel;
      this.m_userOverrides[idx].platformMeters = clampedPlat;
      this.m_userOverrides[idx].isUserOverride = true;
      return;
    };
    ArrayPush(this.m_userOverrides, ShoeOverrideEntry.Create(key, clampedHeel, clampedPlat, true));
  }

  /**
   * Adds or updates a master preset entry from presets.json.
   */
  public func RegisterPreset(key: String, heelMeters: Float, platformMeters: Float) -> Void {
    if StrLen(key) == 0 {
      return;
    };
    let clampedHeel: Float = FootwearClampingPolicy.ClampHeight(heelMeters);
    let clampedPlat: Float = FootwearClampingPolicy.ClampPlatformHeight(platformMeters);

    let idx: Int32 = this.FindPresetIndex(key);
    if idx >= 0 {
      this.m_presets[idx].heelMeters = clampedHeel;
      this.m_presets[idx].platformMeters = clampedPlat;
      this.m_presets[idx].isUserOverride = false;
      return;
    };
    ArrayPush(this.m_presets, ShoeOverrideEntry.Create(key, clampedHeel, clampedPlat, false));
  }

  /**
   * Backward-compatible default registration: forwards to RegisterUserOverride.
   * @param key Shoe identifier string.
   * @param heelMeters Raw heel height offset in meters.
   * @param platformMeters Raw platform height offset in meters.
   */
  public func Register(key: String, heelMeters: Float, platformMeters: Float) -> Void {
    this.RegisterUserOverride(key, heelMeters, platformMeters);
  }

  /**
   * Removes a user override entry from memory.
   */
  public func RemoveUserOverride(key: String) -> Bool {
    if StrLen(key) == 0 {
      return false;
    };
    let idx: Int32 = this.FindUserOverrideIndex(key);
    if idx < 0 {
      return false;
    };
    ArrayErase(this.m_userOverrides, idx);
    return true;
  }

  /**
   * Backward-compatible delete: removes entry from user overrides.
   * @param key Shoe identifier string.
   * @return True if the entry was found and removed, false otherwise.
   */
  public func Remove(key: String) -> Bool {
    return this.RemoveUserOverride(key);
  }

  /**
   * Clears both user overrides and presets from the repository.
   */
  public func Clear() -> Void {
    ArrayClear(this.m_userOverrides);
    ArrayClear(this.m_presets);
  }

  /**
   * Clears only user overrides from memory, preserving presets.
   */
  public func ClearUserOverrides() -> Void {
    ArrayClear(this.m_userOverrides);
  }

  /**
   * Retrieves the total count of registered entries (user overrides + presets).
   * @return Total number of entries stored.
   */
  public func GetCount() -> Int32 {
    return ArraySize(this.m_userOverrides) + ArraySize(this.m_presets);
  }

  /**
   * Retrieves the count of user overrides.
   */
  public func GetUserOverrideCount() -> Int32 {
    return ArraySize(this.m_userOverrides);
  }

  /**
   * Retrieves the count of presets.
   */
  public func GetPresetCount() -> Int32 {
    return ArraySize(this.m_presets);
  }
}
