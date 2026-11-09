module ImmersiveFootwearPOV

@if(ModuleExists("RedscriptConfigFramework"))
import RedscriptConfigFramework.*
@if(ModuleExists("RedFunctions"))
import RedFunctions.*
@if(ModuleExists("RedWindows"))
import RedWindows.*

// =============================================================================
// Immersive Footwear POV - Redscript Configuration Framework (RCF) Integration
// Single Responsibility: Presents mod configuration cleanly in native Cyberpunk menus
// Open/Closed Principle: Extends DVRCF_Provider without modifying framework internals
// =============================================================================
@if(ModuleExists("RedscriptConfigFramework"))
public class FootwearRCFProvider extends DVRCF_Provider {
  private let m_config: ref<FootwearConfig>;
  private let m_system: wref<ImmersiveFootwearPOVSystem>;

  /**
   * Instantiates an RCF provider linking the active mod configuration and system.
   *
   * @param config Active footwear configuration reference.
   * @param system Active footwear system reference.
   * @return Initialized RCF provider instance.
   */
  public static func Create(config: ref<FootwearConfig>, system: ref<ImmersiveFootwearPOVSystem>) -> ref<FootwearRCFProvider> {
    let provider: ref<FootwearRCFProvider> = new FootwearRCFProvider();
    provider.m_config = config;
    provider.m_system = system;
    return provider;
  }

  // -----------------------------------------------------------------------------
  // Schema Declaration (Fluent Builder Pattern)
  // -----------------------------------------------------------------------------
  /**
   * Builds the declarative RCF menu schema containing tabs, sections,
   * toggles, sliders, and action buttons for native menu rendering.
   *
   * @return Constructed DVRCF schema definition.
   */
  public func BuildSchema() -> ref<DVRCF_Schema> {
    let builder: ref<DVRCF_SchemaBuilder> = DVRCF_SchemaBuilder.New("Immersive Footwear POV");

    builder.Tab("Stance & Elevation")
      .Section("First-Person Perspective (FPP)")
      .Toggle("enableFPP", "Enable FPP Camera Lift")
      .Tip("Lifts V's first-person eye height based on equipped footwear heel height.")
      .Divider()
      .Section("Third-Person (ITP) & Photo Mode")
      .Toggle("enableITP", "Enable Third-Person Character Elevation (ITP)")
      .Tip("Adjusts V's 3rd-person physical character elevation via animgraph blend nodes.")
      .Toggle("autoElevatePM", "Auto-Elevate in Photo Mode")
      .Tip("Automatically applies platform/sole elevation in Photo Mode.")
      .Toggle("autoElevateNTP", "Auto-Elevate in Negotiable Third Person (NTP)")
      .Tip("Lifts V's character model and workspot carrier during third-person idle and dance animations.")

      .Tab("Catwalk Locomotion")
      .Section("Feminine Stride & Pelvic Sway")
      .Toggle("enableHipSway", "Enable Pelvic Catwalk Sway")
      .Tip("Enables natural pelvic oscillation and hip sway when walking in heels.")
      .Slider("swayLow", "Low Heels Sway Multiplier", 0.0, 2.50, 0.10, false)
      .Tip("Multiplier for low heels (2cm - 5cm).")
      .Slider("swayMid", "Mid Heels Sway Multiplier", 0.0, 2.50, 0.10, false)
      .Tip("Multiplier for mid heels (6cm - 9cm).")
      .Slider("swayHigh", "High Heels Sway Multiplier", 0.0, 2.50, 0.10, false)
      .Tip("Multiplier for high heels & stilettos (10cm+).")

      .Tab("Suppression")
      .Section("Contextual Auto-Suppression")
      .Toggle("suppressVehicles", "Suppress in Vehicles")
      .Tip("Resets elevation to 0.0 when entering cars or motorcycles to prevent head clipping.")
      .Toggle("suppressWorkspots", "Suppress in Workspots (Sitting)")
      .Tip("Resets elevation to 0.0 when sitting on chairs, couches, or stools.")
      .Toggle("suppressScenes", "Suppress in Scripted Scenes / Dialogue")
      .Tip("Resets elevation during high-tier cinematic dialogues to maintain intended camera framing.")

      .Tab("Management & Storage")
      .Section("HUD & Live Calibrator")
      .Toggle("hudPinned", "Show Diagnostics on HUD")
      .Tip("Keeps the floating diagnostics HUD visible in first-person gameplay even when the RedWindows overlay is closed.")
      .Button("openDiagnostics", "Open Live Diagnostics HUD (RedWindows)")
      .Tip("Opens or focuses the floating native HUD showing active footwear, elevation, and suppression telemetry.")
      .Button("openCalibrator", "Open Live Shoe Height Calibrator (RedWindows)")
      .Tip("Opens or focuses the floating real-time shoe calibrator to adjust heel/platform sliders with live character preview.")
      .Divider()
      .Section("Configuration & Overrides")
      .Toggle("debugLogs", "Verbose Redscript Logging")
      .Tip("Enables detailed debug output in the Redscript log channels.")
      .Button("reloadStorage", "Reload Presets & Overrides from Disk")
      .Tip("Re-reads presets.json and user_shoe_overrides.json immediately.")
      .Button("resetDefaults", "Reset Mod Configuration to Default")
      .Tip("Restores all mod settings back to their factory defaults.");

    return builder.Build();
  }

  // -----------------------------------------------------------------------------
  // Typesafe Getters & Setters
  // -----------------------------------------------------------------------------
  /**
   * Retrieves boolean configuration values by identifier for RCF binding.
   *
   * @param key Setting identifier key.
   * @return Boolean value of the setting, or false if undefined.
   */
  public func GetBool(key: String) -> Bool {
    if !IsDefined(this.m_config) {
      return false;
    };
    if Equals(key, "enableFPP") { return this.m_config.enableFPP; };
    if Equals(key, "enableITP") { return this.m_config.enableITP; };
    if Equals(key, "autoElevatePM") { return this.m_config.autoElevatePM; };
    if Equals(key, "autoElevateNTP") { return this.m_config.autoElevateNTP; };
    if Equals(key, "enableHipSway") { return this.m_config.enableHipSway; };
    if Equals(key, "suppressVehicles") { return this.m_config.suppressVehicles; };
    if Equals(key, "suppressWorkspots") { return this.m_config.suppressWorkspots; };
    if Equals(key, "suppressScenes") { return this.m_config.suppressScenes; };
    if Equals(key, "debugLogs") { return this.m_config.debugLogs; };
    if Equals(key, "hudPinned") { return this.m_config.hudPinned; };
    return false;
  }

  /**
   * Updates boolean configuration values by identifier and persists modifications.
   *
   * @param key Setting identifier key.
   * @param value New boolean value.
   */
  public func SetBool(key: String, value: Bool) -> Void {
    if !IsDefined(this.m_config) {
      return;
    };
    let changed: Bool = false;
    if Equals(key, "enableFPP") && NotEquals(this.m_config.enableFPP, value) { this.m_config.enableFPP = value; changed = true; };
    if Equals(key, "enableITP") && NotEquals(this.m_config.enableITP, value) { this.m_config.enableITP = value; changed = true; };
    if Equals(key, "autoElevatePM") && NotEquals(this.m_config.autoElevatePM, value) { this.m_config.autoElevatePM = value; changed = true; };
    if Equals(key, "autoElevateNTP") && NotEquals(this.m_config.autoElevateNTP, value) { this.m_config.autoElevateNTP = value; changed = true; };
    if Equals(key, "enableHipSway") && NotEquals(this.m_config.enableHipSway, value) { this.m_config.enableHipSway = value; changed = true; };
    if Equals(key, "suppressVehicles") && NotEquals(this.m_config.suppressVehicles, value) { this.m_config.suppressVehicles = value; changed = true; };
    if Equals(key, "suppressWorkspots") && NotEquals(this.m_config.suppressWorkspots, value) { this.m_config.suppressWorkspots = value; changed = true; };
    if Equals(key, "suppressScenes") && NotEquals(this.m_config.suppressScenes, value) { this.m_config.suppressScenes = value; changed = true; };
    if Equals(key, "debugLogs") && NotEquals(this.m_config.debugLogs, value) { this.m_config.debugLogs = value; changed = true; };
    if Equals(key, "hudPinned") && NotEquals(this.m_config.hudPinned, value) {
      this.m_config.hudPinned = value;
      changed = true;
      if IsDefined(this.m_system) {
        let diagWin: ref<RWWindow> = RedWindowsAPI.Window(this.m_system.GetGameInstance(), n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
        if IsDefined(diagWin) {
          diagWin.SetOverlayOnly(!value);
          diagWin.SetBoolValue(n"ifp_diag_pin", value);
          if value {
            diagWin.Show();
          };
        };
      };
    };

    if !changed || !IsDefined(this.m_system) {
      return;
    };

    this.m_system.GetStorageManager().SaveConfig(this.m_config);
    this.m_system.OnConfigUpdated(this.m_config);
  }

  /**
   * Retrieves floating-point configuration values by identifier for RCF binding.
   *
   * @param key Setting identifier key.
   * @return Float value of the setting, or 0.0 if undefined.
   */
  public func GetFloat(key: String) -> Float {
    if !IsDefined(this.m_config) {
      return 0.0;
    };
    if Equals(key, "transitionSpeed") { return this.m_config.transitionSpeed; };
    if Equals(key, "swayLow") { return this.m_config.swayLow; };
    if Equals(key, "swayMid") { return this.m_config.swayMid; };
    if Equals(key, "swayHigh") { return this.m_config.swayHigh; };
    return 0.0;
  }

  /**
   * Updates floating-point configuration values by identifier and persists modifications.
   *
   * @param key Setting identifier key.
   * @param value New float value.
   */
  public func SetFloat(key: String, value: Float) -> Void {
    if !IsDefined(this.m_config) {
      return;
    };
    let changed: Bool = false;
    if Equals(key, "transitionSpeed") && AbsF(this.m_config.transitionSpeed - value) > 0.04 { this.m_config.transitionSpeed = value; changed = true; };
    if Equals(key, "swayLow") && AbsF(this.m_config.swayLow - value) > 0.08 { this.m_config.swayLow = value; changed = true; };
    if Equals(key, "swayMid") && AbsF(this.m_config.swayMid - value) > 0.08 { this.m_config.swayMid = value; changed = true; };
    if Equals(key, "swayHigh") && AbsF(this.m_config.swayHigh - value) > 0.08 { this.m_config.swayHigh = value; changed = true; };

    if !changed || !IsDefined(this.m_system) {
      return;
    };

    this.m_system.GetStorageManager().SaveConfig(this.m_config);
    this.m_system.OnConfigUpdated(this.m_config);
  }

  /**
   * Retrieves integer configuration values by identifier for RCF binding.
   *
   * @param key Setting identifier key.
   * @return Integer value (defaults to 0).
   */
  public func GetInt(key: String) -> Int32 {
    return 0;
  }

  /**
   * Updates integer configuration values by identifier for RCF binding.
   *
   * @param key Setting identifier key.
   * @param value New integer value.
   */
  public func SetInt(key: String, value: Int32) -> Void {}

  /**
   * Callback invoked by RCF when user settings are restored or reloaded.
   */
  public func OnSettingsRestored() -> Void {
    if !IsDefined(this.m_system) || !IsDefined(this.m_config) {
      return;
    };
    this.m_system.OnConfigUpdated(this.m_config);
  }

  /**
   * Handles action button clicks dispatched from the native RCF menu.
   *
   * @param key Action button identifier key.
   */
  public func OnButton(key: String) -> Void {
    if StrLen(key) == 0 || !IsDefined(this.m_system) {
      return;
    };
    if Equals(key, "openDiagnostics") {
      FootwearWindowsController.ToggleDiagnostics(this.m_system.GetGameInstance());
      return;
    };
    if Equals(key, "openCalibrator") {
      FootwearWindowsController.ToggleCalibrator(this.m_system.GetGameInstance());
      return;
    };
    if Equals(key, "reloadStorage") {
      let repo: ref<FootwearOverrideRepository> = this.m_system.GetOverrideRepository();
      repo.Clear();
      let storageMgr: ref<FootwearStorageManager> = this.m_system.GetStorageManager();
      storageMgr.LoadMasterPresetsIntoRepo(repo);
      storageMgr.LoadUserOverridesIntoRepo(repo);
      let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.m_system.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
      if IsDefined(player) {
        this.m_system.UpdateEquippedFootwear(player);
      };
      FootwearRedLogger.LogInfo("RCF", s"Reloaded presets and user overrides from disk via RCF button | Current source: [\(this.m_system.GetSettingsSource())]");
      return;
    };
    if Equals(key, "resetDefaults") {
      if !IsDefined(this.m_config) {
        return;
      };
      this.m_config.SetDefaults();
      this.m_system.GetStorageManager().SaveConfig(this.m_config);
      this.m_system.OnConfigUpdated(this.m_config);
      FootwearRedLogger.LogInfo("RCF", "Reset configuration to defaults via RCF button");
    };
  }

  // -----------------------------------------------------------------------------
  // Registration Helper
  // -----------------------------------------------------------------------------
  /**
   * Registers the mod's settings provider with the Redscript Configuration Framework.
   *
   * @param gi Game instance context.
   * @param config Active footwear configuration reference.
   * @param system Active footwear system reference.
   */
  public static func Register(gi: GameInstance, config: ref<FootwearConfig>, system: ref<ImmersiveFootwearPOVSystem>) -> Void {
    let provider: ref<FootwearRCFProvider> = FootwearRCFProvider.Create(config, system);
    DVRCF.Register(
      gi,
      "ImmersiveFootwearPOV",
      "Immersive Footwear POV",
      "Dynamic footwear height, perspective stance & feline stride framework",
      provider
    );
    FootwearRedLogger.LogInfo("RCF", "Registered Immersive Footwear POV with Redscript Configuration Framework (RCF)");
  }
}

// -----------------------------------------------------------------------------
// Fallback Stub (when RedscriptConfigFramework is NOT installed)
// -----------------------------------------------------------------------------
@if(!ModuleExists("RedscriptConfigFramework"))
public class FootwearRCFProvider {
  public static func Register(gi: GameInstance, config: ref<FootwearConfig>, system: ref<ImmersiveFootwearPOVSystem>) -> Void {
    // No-op: RCF is not installed; configuration will be handled via CET fallback
  }
}
