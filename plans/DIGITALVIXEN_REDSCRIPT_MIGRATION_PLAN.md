# Comprehensive Technical Plan: Full Migration to Redscript & DigitalVixen Ecosystem (SOLID Architecture)

**Document Name:** `DIGITALVIXEN_REDSCRIPT_MIGRATION_PLAN.md`  
**Target Mod:** Immersive Footwear POV  
**Context:** Cyberpunk 2077 (Patch 2.0+ / Patch 2.31+) / REDengine 4 / Redscript 0.5.24+  
**Architecture:** Pure Redscript Architecture with DigitalVixen Suite (RedFunctions, RCF, RedWindows)  
**Status:** **Approved / In Execution**  

---

## 1. Executive Summary & Architectural Goals

This plan executes the complete architectural transition of *Immersive Footwear POV* from a hybrid Cyber Engine Tweaks (Lua) / Redscript stack to a **100% native Redscript** solution powered by DigitalVixen's modding ecosystem:

1. **Eliminate the CET Dependency:** Deprecate all Lua scripts, `init.lua` lifecycles, and ImGui overlays.
2. **Adopt Native Persistence ([RedFunctions](https://www.nexusmods.com/cyberpunk2077/mods/30726)):** Use native `ModStorage` and `JsonMap`/`JsonList` for JSON reading, writing, and preset storage directly in Redscript.
3. **Adopt Native Configuration ([Redscript Configuration Framework - RCF](https://www.nexusmods.com/cyberpunk2077/mods/30726)):** Integrate mod settings directly into Cyberpunk 2077's native in-game pause and main menus (fully compatible with mouse, controller, and Steam Deck).
4. **Adopt Native HUD & Live Calibrator ([RedWindows](https://www.nexusmods.com/cyberpunk2077/mods/30726)):** Implement native `inkWidget` floating windows for live real-time diagnostics and on-the-fly shoe height calibration.
5. **Strict Adherence to SOLID Principles:** Decouple domain models, storage persistence, and presentation layers using clean object-oriented patterns (Observer, Provider, Repository).

---

## 2. SOLID Design Architecture

To ensure modularity, maintainability, and clean separation of concerns, the migrated architecture adheres to the following design patterns:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            PRESENTATION LAYER                               │
│                                                                             │
│   ┌────────────────────────┐  ┌────────────────────────┐  ┌─────────────┐  │
│   │ FootwearRCFProvider    │  │ FootwearDiagnosticsWin │  │ Calibrator  │  │
│   │ (Extends DVRCF_Provider│  │ (RedWindows Live HUD)  │  │ (RedWindows)│  │
│   └───────────┬────────────┘  └───────────┬────────────┘  └──────┬──────┘  │
└───────────────┼───────────────────────────┼──────────────────────┼──────────┘
                │                           │                      │
                ▼                           ▼                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DOMAIN LAYER                                   │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                     ImmersiveFootwearPOVSystem                      │   │
│   │                    (Authoritative State Machine)                    │   │
│   │                                                                     │   │
│   │ • m_listeners: array<ref<IFootwearStateListener>> (Observer Pattern)│   │
│   │ • Dispatches: OnFootwearUpdated, OnSuppressionStateChanged          │   │
│   │ • Manages: FootwearResolver, StrideController, SuppressionEvaluator │   │
│   └──────────────────────────────────┬──────────────────────────────────┘   │
└──────────────────────────────────────┼──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            PERSISTENCE LAYER                                │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                     FootwearStorageManager                          │   │
│   │          (Repository Pattern via RedFunctions.ModStorage)           │   │
│   │                                                                     │   │
│   │ • LoadConfig() / SaveConfig()                                       │   │
│   │ • LoadUserOverrides() / SaveUserOverride(key, heel, plat)           │   │
│   │ • LoadMasterPresets() (presets.json)                                │   │
│   │ • MigrateLegacyCetSettings()                                        │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Applying SOLID Principles:

* **S - Single Responsibility Principle (SRP):**
  * `FootwearStorageManager`: Handles exclusively JSON serialization and file operations via `ModStorage`.
  * `FootwearConfig`: Pure data model holding active user settings with defaults and validation.
  * `FootwearRCFProvider`: Handles exclusively RCF menu schema registration and menu event dispatch.
  * `FootwearDiagnosticsWindow` & `FootwearCalibratorWindow`: Handles exclusively `inkWidget` UI rendering and user interaction via `RedWindows`.
  * `ImmersiveFootwearPOVSystem`: Retains authoritative gameplay state and elevation calculation.
* **O - Open/Closed Principle (OCP):**
  * State updates are broadcast via `IFootwearStateListener`. New diagnostic tools, external integrations (e.g. TFP, ITP), or UI windows can subscribe without modifying the core system.
* **L - Liskov Substitution Principle (LSP):**
  * `FootwearRCFProvider` extends `DVRCF_Provider` and fulfills all contract expectations (clean schema generation, typesafe getters/setters, default fallbacks).
* **I - Interface Segregation Principle (ISP):**
  * Separate listeners for footwear changes vs. suppression changes vs. calibration changes. UI components only implement the methods they need.
* **D - Dependency Inversion Principle (DIP):**
  * High-level gameplay systems do not depend on low-level UI libraries (`RedWindows` or `RCF`). The core continues to function if UI libraries are uninstalled or missing.

---

## 3. Implementation Phases

### Phase 1: Native Storage & JSON Persistence (`Storage/`)
* **Target File:** `source/resources/r6/scripts/ImmersiveFootwearPOV/Storage/ImmersiveFootwearPOV_Storage.reds`
* **Technology:** `RedFunctions` (`ModStorage`, `JsonMap`, `JsonList`, `JsonText`).
* **Components to Implement:**
  1. `FootwearStorageManager`:
     * Initialized via `ModStorage.Open("ImmersiveFootwearPOV")`.
     * `LoadConfig(out config: ref<FootwearConfig>) -> Bool`
     * `SaveConfig(config: ref<FootwearConfig>) -> Bool`
     * `LoadUserOverrides(system: ref<ImmersiveFootwearPOVSystem>) -> Int32`: Reads `user_shoe_overrides.json`, parsing key-value pairs (`heel`, `platform`) into system arrays.
     * `SaveUserOverride(key: String, heel: Float, platform: Float) -> Bool`: Updates and writes `user_shoe_overrides.json`.
     * `LoadMasterPresets(system: ref<ImmersiveFootwearPOVSystem>) -> Int32`: Parses community presets from `presets.json`.
     * `MigrateLegacyCetSettings()`: Scans for legacy CET `config.json` in `bin/x64/...` and migrates values.

### Phase 2: Configuration Hub via RCF (`UI/`)
* **Target File:** `source/resources/r6/scripts/ImmersiveFootwearPOV/UI/ImmersiveFootwearPOV_RCF.reds`
* **Technology:** `RedscriptConfigFramework` (`DVRCF`, `DVRCF_Provider`, `DVRCF_Schema`).
* **Components to Implement:**
  1. `FootwearRCFProvider extends DVRCF_Provider`:
     * `BuildSchema() -> ref<DVRCF_Schema>`:
       * **Tab 1: Stance & Elevation:**
         * `enableFPP` (Toggle): Enable FPP Camera Lift
         * `enableITP` (Toggle): Enable TPP Character Elevation (ITP)
         * `enablePM` (Toggle): Enable Photo Mode Auto-Elevation
         * `transitionSpeed` (Slider: 0.1 - 1.0, step 0.05): Smoothstep Easing Duration
       * **Tab 2: Catwalk Locomotion:**
         * `enableSway` (Toggle): Enable Pelvic Sway
         * `swayLow` (Slider: 0.0 - 2.0, step 0.1): Low Heels Sway Multiplier
         * `swayMid` (Slider: 0.0 - 2.0, step 0.1): Mid Heels Sway Multiplier
         * `swayHigh` (Slider: 0.0 - 2.0, step 0.1): Stilettos / High Heels Sway Multiplier
       * **Tab 3: Contextual Suppression:**
         * `suppressVehicles` (Toggle): Suppress in Vehicles
         * `suppressWorkspots` (Toggle): Suppress in Workspots (Sitting)
         * `suppressScenes` (Toggle): Suppress in High-Tier Dialogue / Scenes
       * **Tab 4: System & Overrides:**
         * `debugLogging` (Toggle): Verbose Logging
         * `btnReload` (Button): Reload Presets & Overrides from Disk
     * `GetBool`, `SetBool`, `GetFloat`, `SetFloat`, `OnButton`, `OnSave`.
  2. Register with `DVRCF.Register(gi, "ImmersiveFootwearPOV", "Immersive Footwear POV", ...)` during system startup.

### Phase 3: In-Game Diagnostics HUD & Live Calibrator (`UI/`)
* **Target File:** `source/resources/r6/scripts/ImmersiveFootwearPOV/UI/ImmersiveFootwearPOV_RedWindows.reds`
* **Technology:** `RedWindows` (`RedWindowsAPI`, `RWWindow`, `RWWidget`).
* **Components to Implement:**
  1. `FootwearDiagnosticsWindow extends IFootwearStateListener`:
     * Floating HUD window toggled via hotkey (default: `F7` or configurable).
     * Displays real-time telemetry:
       * Footwear ItemID & Display Name
       * Resolution Source (`[TweakDB Tag]`, `[User Override]`, `[Preset]`, `[Baseline]`)
       * Active Heel Height (cm) & Platform Height (cm)
       * Suppression State (`ACTIVE` / `CLEAR`) & Reason
       * Active Perspective (`FPP`, `TPP`, `Photo Mode`)
       * Sway Pelvic Roll Angle ($^\circ$) & Velocity
     * Automatically updates visuals on state changes.
  2. `FootwearCalibratorWindow`:
     * On-the-fly tuner window for currently equipped shoes.
     * Sliders: `Heel Height (0 - 15 cm)`, `Platform Height (0 - 10 cm)`.
     * Live preview: Adjusting sliders modifies V's height live on-screen in real-time.
     * Button: "Save as Override" calls `FootwearStorageManager.SaveUserOverride(...)`.

### Phase 4: Core System Wiring & Observer Hooks
* **Target File:** `source/resources/r6/scripts/ImmersiveFootwearPOV/Systems/ImmersiveFootwearPOV_System.reds`
* **Tasks:**
  1. Add `IFootwearStateListener` registration:
     * `public func RegisterListener(listener: ref<IFootwearStateListener>)`
     * `public func UnregisterListener(listener: ref<IFootwearStateListener>)`
  2. Broadcast state changes to listeners in `UpdateEquippedFootwear` and `SetSuppressionState`.
  3. Load overrides via `FootwearStorageManager` on `OnPlayerAttach` and `OnRestored`.

### Phase 5: CET Decoupling & Release Script Updates
* **Tasks:**
  1. Deprecate and remove `source/resources/bin/x64/plugins/cyber_engine_tweaks/mods/ImmersiveFootwearPOV/`.
  2. Update `tools/pack_and_deploy.ps1` to deploy Redscript and JSON configs while excluding CET.
  3. Validate compilation via `scc.exe` against game directory cache (`final.redscripts`).
  4. Update `tools/create_release_zips.ps1` to package a clean release ZIP without CET files.

---

## 4. Verification & Validation Steps

1. **Compilation Check:** Run `tools/pack_and_deploy.ps1` to execute `scc.exe` compilation against game scripts.
2. **Persistence Validation:**
   * Verify `r6/config/ImmersiveFootwearPOV/user_shoe_overrides.json` is created and read correctly by `ModStorage`.
   * Add a custom override in the Calibrator window; verify it persists after game restart.
3. **RCF Menu Validation:**
   * Open Cyberpunk in-game pause menu -> Mods -> Immersive Footwear POV.
   * Verify all 4 tabs, sliders, toggles, and buttons load and respond.
4. **RedWindows Validation:**
   * Press toggle hotkey in-game; verify Diagnostics HUD renders with native Cyberpunk styling.
   * Equip footwear; verify live telemetry reflects changes instantly.
