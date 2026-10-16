module ImmersiveFootwearPOV

import RedFunctions.*
import RedFunctions.Json.*
import RedFunctions.Storage.*

// =============================================================================
// Immersive Footwear POV - Native Storage Manager (Repository Pattern)
// Single Responsibility: Low-level file persistence of config, presets, and overrides via RedFunctions
// =============================================================================
public class FootwearStorageManager {
  private let m_storage: ref<ModStorage>;

  private let CONFIG_FILE: String;
  private let OVERRIDES_FILE: String;
  private let PRESETS_FILE: String;

  /**
   * Factory method initializing and opening the ModStorage file interface for ImmersiveFootwearPOV.
   * @return A newly initialized FootwearStorageManager instance.
   */
  public static func Create() -> ref<FootwearStorageManager> {
    let instance: ref<FootwearStorageManager> = new FootwearStorageManager();
    instance.Init();
    return instance;
  }

  /**
   * Factory method initializing and opening the ModStorage file interface for ImmersiveFootwearPOV.
   * Prefer using ImmersiveFootwearPOVSystem.GetStorageManager() to reuse a single open handle.
   * @return A FootwearStorageManager instance.
   */
  public static func GetInstance() -> ref<FootwearStorageManager> {
    return FootwearStorageManager.Create();
  }

  /**
   * Internal initializer opening the ModStorage partition.
   */
  private func Init() -> Void {
    this.CONFIG_FILE = "config.json";
    this.OVERRIDES_FILE = "user_shoe_overrides.json";
    this.PRESETS_FILE = "presets.json";
    this.m_storage = ModStorage.Open("ImmersiveFootwearPOV");
    if !IsDefined(this.m_storage) {
      FootwearRedLogger.LogError("STORAGE", "Failed to open ModStorage for ImmersiveFootwearPOV");
    };
  }

  /**
   * Checks whether the underlying ModStorage filesystem handle is open and ready.
   * @return True if storage handle is defined, false otherwise.
   */
  public func IsReady() -> Bool {
    return IsDefined(this.m_storage);
  }

  /**
   * Retrieves the raw ModStorage reference.
   * @return The underlying ModStorage instance.
   */
  public func GetStorage() -> ref<ModStorage> {
    return this.m_storage;
  }

  // -----------------------------------------------------------------------------
  // Mod Configuration Loading & Saving
  // -----------------------------------------------------------------------------

  /**
   * Loads user configuration from config.json. Automatically writes default configuration if file is missing.
   * @param config The FootwearConfig instance to populate.
   * @return True if configuration was loaded or initialized successfully, false on error.
   */
  public func LoadConfig(config: ref<FootwearConfig>) -> Bool {
    if !this.IsReady() || !IsDefined(config) {
      return false;
    };
    if !this.m_storage.Has(this.CONFIG_FILE) {
      // First run: save defaults
      this.SaveConfig(config);
      return true;
    };

    let val: ref<JsonValue> = this.m_storage.ReadJson(this.CONFIG_FILE);
    if IsDefined(val) && val.IsMap() {
      config.ReadFromJson(val.AsMap());
      FootwearRedLogger.LogInfo("STORAGE", "Loaded mod configuration from config.json");
      return true;
    };

    FootwearRedLogger.LogWarn("STORAGE", "config.json was invalid or unreadable, using defaults");
    return false;
  }

  /**
   * Serializes and writes user configuration to config.json.
   * @param config The FootwearConfig instance to persist.
   * @return True if write succeeded, false otherwise.
   */
  public func SaveConfig(config: ref<FootwearConfig>) -> Bool {
    if !this.IsReady() || !IsDefined(config) {
      return false;
    };

    let map: ref<JsonMap> = JsonMap.Make();
    config.WriteToJson(map);
    let success: Bool = this.m_storage.WriteJson(this.CONFIG_FILE, map, false, true);
    if success {
      FootwearRedLogger.LogInfo("STORAGE", "Saved mod configuration to config.json");
    } else {
      FootwearRedLogger.LogError("STORAGE", "Failed to write config.json");
    };
    return success;
  }

  // -----------------------------------------------------------------------------
  // User Shoe Overrides Loading & Saving (Decoupled from System via Repository)
  // -----------------------------------------------------------------------------

  /**
   * Safely reads a numeric JSON field as Float, supporting both JsonKind.Real and JsonKind.Int values.
   * Prevents default 0.0 fallbacks on integer JSON values in presets and overrides.
   * @param map Target JsonMap object.
   * @param key Property name string.
   * @param fallback Default value if missing or unreadable.
   * @return Extracted numeric value as Float.
   */
  public static func ReadNumberAsFloat(map: ref<JsonMap>, key: String, fallback: Float) -> Float {
    if !IsDefined(map) || !map.Contains(key) {
      return fallback;
    };
    let val: ref<JsonValue> = map.Value(key);
    if !IsDefined(val) {
      return fallback;
    };
    let kind: Int32 = val.Kind();
    // JsonKind: Null = 0, Bool = 1, Int = 2, Real = 3
    if kind == 3 {
      return map.Float(key, fallback);
    };
    if kind == 2 {
      return Cast<Float>(map.Int(key, Cast<Int32>(fallback)));
    };
    return map.Float(key, fallback);
  }

  /**
   * Loads user calibrated shoe overrides from user_shoe_overrides.json into the provided repository.
   * @param repo The target FootwearOverrideRepository to populate.
   * @return Number of override entries successfully parsed and registered.
   */
  public func LoadUserOverridesIntoRepo(repo: ref<FootwearOverrideRepository>) -> Int32 {
    if !this.IsReady() || !IsDefined(repo) {
      return 0;
    };
    if !this.m_storage.Has(this.OVERRIDES_FILE) {
      return 0;
    };

    let val: ref<JsonValue> = this.m_storage.ReadJson(this.OVERRIDES_FILE);
    if !IsDefined(val) || !val.IsMap() {
      return 0;
    };

    let rootMap: ref<JsonMap> = val.AsMap();
    let keys: array<String> = rootMap.KeyList();
    let count: Int32 = ArraySize(keys);
    let registered: Int32 = 0;

    let i: Int32 = 0;
    while i < count {
      let key: String = keys[i];
      if !Equals(key, "__settings") {
        let entryVal: ref<JsonValue> = rootMap.Value(key);
        if IsDefined(entryVal) && entryVal.IsMap() {
          let itemMap: ref<JsonMap> = entryVal.AsMap();
          let heelCm: Float = FootwearStorageManager.ReadNumberAsFloat(itemMap, "heel", 0.0);
          let platCm: Float = FootwearStorageManager.ReadNumberAsFloat(itemMap, "platform", 0.0);
          // Convert centimeters from JSON to meters for repository registration
          repo.Register(key, heelCm / 100.0, platCm / 100.0);
          registered += 1;
        };
      };
      i += 1;
    };

    FootwearRedLogger.LogInfo("STORAGE", s"Loaded \(registered) user shoe overrides from user_shoe_overrides.json");
    return registered;
  }

  /**
   * Persists a single calibrated shoe override entry to user_shoe_overrides.json.
   * @param key Unique shoe identifier string.
   * @param heelMeters Heel height offset in meters.
   * @param platMeters Platform height offset in meters.
   * @return True if save succeeded, false otherwise.
   */
  public func SaveUserOverride(key: String, heelMeters: Float, platMeters: Float) -> Bool {
    if !this.IsReady() || StrLen(key) == 0 {
      return false;
    };

    let rootMap: ref<JsonMap>;
    if this.m_storage.Has(this.OVERRIDES_FILE) {
      let existing: ref<JsonValue> = this.m_storage.ReadJson(this.OVERRIDES_FILE);
      if IsDefined(existing) && existing.IsMap() {
        rootMap = existing.AsMap();
      } else {
        rootMap = JsonMap.Make();
      };
    } else {
      rootMap = JsonMap.Make();
    };

    let itemMap: ref<JsonMap> = JsonMap.Make();
    itemMap.PutFloat("heel", heelMeters * 100.0);
    itemMap.PutFloat("platform", platMeters * 100.0);
    rootMap.Put(key, itemMap);

    let success: Bool = this.m_storage.WriteJson(this.OVERRIDES_FILE, rootMap, false, false);
    if success {
      FootwearRedLogger.LogInfo("STORAGE", s"Saved user shoe override for '\(key)' (Heel: \(heelMeters * 100.0)cm, Plat: \(platMeters * 100.0)cm)");
    } else {
      FootwearRedLogger.LogError("STORAGE", s"Failed to write user override for '\(key)'");
    };
    return success;
  }

  /**
   * Deletes a shoe override from user_shoe_overrides.json on disk.
   * @param key Unique shoe identifier string to remove.
   * @return True if entry existed and was deleted, false otherwise.
   */
  public func RemoveUserOverride(key: String) -> Bool {
    if !this.IsReady() || StrLen(key) == 0 {
      return false;
    };
    if !this.m_storage.Has(this.OVERRIDES_FILE) {
      return false;
    };

    let existing: ref<JsonValue> = this.m_storage.ReadJson(this.OVERRIDES_FILE);
    if !IsDefined(existing) || !existing.IsMap() {
      return false;
    };

    let rootMap: ref<JsonMap> = existing.AsMap();
    if rootMap.Contains(key) {
      rootMap.Drop(key);
      return this.m_storage.WriteJson(this.OVERRIDES_FILE, rootMap, false, false);
    };
    return false;
  }

  // -----------------------------------------------------------------------------
  // Master Presets Loading (Decoupled from System via Repository)
  // -----------------------------------------------------------------------------

  /**
   * Loads built-in master shoe presets from presets.json into the provided repository.
   * @param repo The target FootwearOverrideRepository to populate.
   * @return Number of preset entries successfully loaded.
   */
  public func LoadMasterPresetsIntoRepo(repo: ref<FootwearOverrideRepository>) -> Int32 {
    if !this.IsReady() || !IsDefined(repo) {
      return 0;
    };
    if !this.m_storage.Has(this.PRESETS_FILE) {
      return 0;
    };

    let val: ref<JsonValue> = this.m_storage.ReadJson(this.PRESETS_FILE);
    if !IsDefined(val) || !val.IsMap() {
      return 0;
    };

    let rootMap: ref<JsonMap> = val.AsMap();
    let keys: array<String> = rootMap.KeyList();
    let count: Int32 = ArraySize(keys);
    let registered: Int32 = 0;

    let i: Int32 = 0;
    while i < count {
      let key: String = keys[i];
      if !Equals(key, "__settings") {
        let entryVal: ref<JsonValue> = rootMap.Value(key);
        if IsDefined(entryVal) && entryVal.IsMap() {
          let itemMap: ref<JsonMap> = entryVal.AsMap();
          let heelCm: Float = FootwearStorageManager.ReadNumberAsFloat(itemMap, "heel", 0.0);
          let platCm: Float = FootwearStorageManager.ReadNumberAsFloat(itemMap, "platform", 0.0);
          repo.Register(key, heelCm / 100.0, platCm / 100.0);
          registered += 1;
        };
      };
      i += 1;
    };

    FootwearRedLogger.LogInfo("STORAGE", s"Loaded \(registered) master shoe presets from presets.json");
    return registered;
  }

  /**
   * Legacy adapter loading user shoe overrides directly through the central system.
   * @param system Reference to ImmersiveFootwearPOVSystem.
   * @return Number of entries registered.
   */
  public func LoadUserOverrides(system: ref<ImmersiveFootwearPOVSystem>) -> Int32 {
    if IsDefined(system) {
      return this.LoadUserOverridesIntoRepo(system.GetOverrideRepository());
    };
    return 0;
  }

  /**
   * Legacy adapter loading master shoe presets directly through the central system.
   * @param system Reference to ImmersiveFootwearPOVSystem.
   * @return Number of entries registered.
   */
  public func LoadMasterPresets(system: ref<ImmersiveFootwearPOVSystem>) -> Int32 {
    if IsDefined(system) {
      return this.LoadMasterPresetsIntoRepo(system.GetOverrideRepository());
    };
    return 0;
  }

  /**
   * Initiates migration of legacy CET configuration and shoe overrides if detected.
   * @param system Reference to ImmersiveFootwearPOVSystem.
   * @param config The current configuration instance.
   */
  public func MigrateLegacyCet(system: ref<ImmersiveFootwearPOVSystem>, config: ref<FootwearConfig>) -> Void {
    LegacyCetMigrationService.MigrateIfNeeded(this, config);
  }
}
