module ImmersiveFootwearPOV

@if(ModuleExists("RedFunctions"))
import RedFunctions.*
@if(ModuleExists("RedFunctions"))
import RedFunctions.Json.*
@if(ModuleExists("RedFunctions"))
import RedFunctions.Storage.*

// =============================================================================
// One-Time Legacy CET Migration Service (Isolated Single Responsibility)
// =============================================================================
@if(ModuleExists("RedFunctions"))
public class LegacyCetMigrationService {

  /**
   * Detects legacy Cyber Engine Tweaks configuration and user shoe overrides on disk,
   * migrating their contents into RedFunctions ModStorage partition on first launch.
   * @param storageMgr The initialized FootwearStorageManager instance.
   * @param config The active FootwearConfig instance to update if legacy settings are imported.
   */
  public static func MigrateIfNeeded(storageMgr: ref<FootwearStorageManager>, config: ref<FootwearConfig>) -> Void {
    if !IsDefined(storageMgr) || !storageMgr.IsReady() {
      return;
    };

    let storage: ref<ModStorage> = storageMgr.GetStorage();
    if !IsDefined(storage) {
      return;
    };

    let legacyDir: String = "bin\\x64\\plugins\\cyber_engine_tweaks\\mods\\ImmersiveFootwearPOV";
    let legacyOverridesPath: String = s"\(legacyDir)\\user_shoe_overrides.json";
    let legacyConfigPath: String = s"\(legacyDir)\\config.json";

    LegacyCetMigrationService.MigrateConfigIfNeeded(storage, legacyConfigPath, config);
    LegacyCetMigrationService.MigrateOverridesIfNeeded(storage, legacyOverridesPath, config);
  }

  /**
   * Migrates legacy CET config.json into RedFunctions ModStorage if not already migrated.
   */
  private static func MigrateConfigIfNeeded(storage: ref<ModStorage>, legacyConfigPath: String, config: ref<FootwearConfig>) -> Void {
    if !IsDefined(storage) || storage.Has("config.json") || !RedFunc.FileExists(legacyConfigPath) {
      return;
    };

    FootwearRedLogger.LogInfo("STORAGE", "Found legacy CET config.json. Migrating to RedFunctions ModStorage...");
    let cfgLines: array<String> = RedFunc.ReadTextFile(legacyConfigPath, 10000);
    let cfgCount: Int32 = ArraySize(cfgLines);
    if cfgCount == 0 {
      return;
    };

    let cfgText: String = "";
    let j: Int32 = 0;
    while j < cfgCount {
      cfgText = s"\(cfgText)\(cfgLines[j])\n";
      j += 1;
    };

    let parsedCfg: ref<JsonValue> = JsonText.Parse(cfgText);
    if !IsDefined(parsedCfg) || !parsedCfg.IsMap() {
      return;
    };

    if IsDefined(config) {
      FootwearConfigJsonAdapter.ReadFromJson(config, parsedCfg.AsMap());
    };
    storage.WriteJson("config.json", parsedCfg, false, true);
    FootwearRedLogger.LogInfo("STORAGE", "Successfully migrated legacy CET config.json into ModStorage!");
  }

  /**
   * Migrates legacy CET user_shoe_overrides.json into RedFunctions ModStorage if not already migrated.
   */
  private static func MigrateOverridesIfNeeded(storage: ref<ModStorage>, legacyOverridesPath: String, config: ref<FootwearConfig>) -> Void {
    if !IsDefined(storage) || storage.Has("user_shoe_overrides.json") || !RedFunc.FileExists(legacyOverridesPath) {
      return;
    };

    FootwearRedLogger.LogInfo("STORAGE", "Found legacy CET user_shoe_overrides.json. Migrating to RedFunctions ModStorage...");
    let lines: array<String> = RedFunc.ReadTextFile(legacyOverridesPath, 10000);
    let lineCount: Int32 = ArraySize(lines);
    if lineCount == 0 {
      return;
    };

    let fullText: String = "";
    let i: Int32 = 0;
    while i < lineCount {
      fullText = s"\(fullText)\(lines[i])\n";
      i += 1;
    };

    let parsedVal: ref<JsonValue> = JsonText.Parse(fullText);
    if !IsDefined(parsedVal) || !parsedVal.IsMap() {
      return;
    };

    let rootMap: ref<JsonMap> = parsedVal.AsMap();
    // Fallback: If legacy overrides has __settings and config.json wasn't created yet, extract __settings
    if rootMap.Contains("__settings") && !storage.Has("config.json") {
      let settingsVal: ref<JsonValue> = rootMap.Value("__settings");
      if IsDefined(settingsVal) && settingsVal.IsMap() {
        if IsDefined(config) {
          FootwearConfigJsonAdapter.ReadFromJson(config, settingsVal.AsMap());
        };
        storage.WriteJson("config.json", settingsVal, false, true);
        FootwearRedLogger.LogInfo("STORAGE", "Extracted legacy __settings into config.json in ModStorage!");
      };
    };

    storage.WriteJson("user_shoe_overrides.json", parsedVal, false, false);
    FootwearRedLogger.LogInfo("STORAGE", "Successfully migrated legacy CET user overrides into ModStorage!");
  }
}

// -----------------------------------------------------------------------------
// Fallback Stub (when RedFunctions is NOT installed)
// -----------------------------------------------------------------------------
@if(!ModuleExists("RedFunctions"))
public class LegacyCetMigrationService {
  public static func MigrateIfNeeded(storageMgr: ref<FootwearStorageManager>, config: ref<FootwearConfig>) -> Void {}
}

