module ImmersiveFootwearPOV

import RedFunctions.*
import RedFunctions.Json.*
import RedFunctions.Storage.*

// =============================================================================
// One-Time Legacy CET Migration Service (Isolated Single Responsibility)
// =============================================================================
public class LegacyCetMigrationService {

  public static func MigrateIfNeeded(storageMgr: ref<FootwearStorageManager>, config: ref<FootwearConfig>) -> Void {
    if !IsDefined(storageMgr) || !storageMgr.IsReady() {
      return;
    };

    let storage: ref<ModStorage> = storageMgr.GetStorage();
    let legacyDir: String = "bin\\x64\\plugins\\cyber_engine_tweaks\\mods\\ImmersiveFootwearPOV";
    let legacyOverridesPath: String = s"\(legacyDir)\\user_shoe_overrides.json";
    let legacyConfigPath: String = s"\(legacyDir)\\config.json";

    // 1. Migrate general settings to config.json if not already in ModStorage
    if !storage.Has("config.json") {
      if RedFunc.FileExists(legacyConfigPath) {
        FootwearRedLogger.LogInfo("STORAGE", "Found legacy CET config.json. Migrating to RedFunctions ModStorage...");
        let cfgLines: array<String> = RedFunc.ReadTextFile(legacyConfigPath, 10000);
        let cfgText: String = "";
        let j: Int32 = 0;
        let cfgCount: Int32 = ArraySize(cfgLines);
        while j < cfgCount {
          cfgText = s"\(cfgText)\(cfgLines[j])\n";
          j += 1;
        };
        let parsedCfg: ref<JsonValue> = JsonText.Parse(cfgText);
        if IsDefined(parsedCfg) && parsedCfg.IsMap() {
          if IsDefined(config) {
            config.ReadFromJson(parsedCfg.AsMap());
          };
          storage.WriteJson("config.json", parsedCfg, false, true);
          FootwearRedLogger.LogInfo("STORAGE", "Successfully migrated legacy CET config.json into ModStorage!");
        };
      };
    };

    // 2. Migrate shoe overrides to user_shoe_overrides.json if not already in ModStorage
    if !storage.Has("user_shoe_overrides.json") {
      if RedFunc.FileExists(legacyOverridesPath) {
        FootwearRedLogger.LogInfo("STORAGE", "Found legacy CET user_shoe_overrides.json. Migrating to RedFunctions ModStorage...");
        let lines: array<String> = RedFunc.ReadTextFile(legacyOverridesPath, 10000);
        let fullText: String = "";
        let i: Int32 = 0;
        let lineCount: Int32 = ArraySize(lines);
        while i < lineCount {
          fullText = s"\(fullText)\(lines[i])\n";
          i += 1;
        };

        let parsedVal: ref<JsonValue> = JsonText.Parse(fullText);
        if IsDefined(parsedVal) && parsedVal.IsMap() {
          let rootMap: ref<JsonMap> = parsedVal.AsMap();
          // Fallback: If legacy overrides has __settings and config.json wasn't created yet, extract __settings
          if rootMap.Contains("__settings") && !storage.Has("config.json") {
            let settingsVal: ref<JsonValue> = rootMap.Value("__settings");
            if IsDefined(settingsVal) && settingsVal.IsMap() {
              if IsDefined(config) {
                config.ReadFromJson(settingsVal.AsMap());
              };
              storage.WriteJson("config.json", settingsVal, false, true);
              FootwearRedLogger.LogInfo("STORAGE", "Extracted legacy __settings into config.json in ModStorage!");
            };
          };
          storage.WriteJson("user_shoe_overrides.json", parsedVal, false, false);
          FootwearRedLogger.LogInfo("STORAGE", "Successfully migrated legacy CET user overrides into ModStorage!");
        };
      };
    };
  }
}
