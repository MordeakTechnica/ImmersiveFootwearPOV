module ImmersiveFootwearPOV

@if(ModuleExists("RedscriptConfigFramework"))
import RedscriptConfigFramework.*
@if(ModuleExists("Codeware"))
import Codeware.Localization.*

// =============================================================================
// Immersive Footwear POV - Native Settings Provider (RedscriptConfigFramework)
// In-game Mod Settings menu for custom footwear height overrides & testing
// =============================================================================

@if(ModuleExists("RedscriptConfigFramework"))
public class FootwearConfigProvider extends DVRCF_Provider {
  private let m_gi: GameInstance;
  private let m_manualHeelCm: Float;
  private let m_manualPlatformCm: Float;

  public func Init(gi: GameInstance) -> Void {
    this.m_gi = gi;
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if IsDefined(sys) {
      this.m_manualHeelCm = sys.GetCurrentHeelHeight() * 100.0;
      this.m_manualPlatformCm = sys.GetCurrentPlatformHeight() * 100.0;
    };
  }

  public func BuildSchema() -> ref<DVRCF_Schema> {
    let b: ref<DVRCF_SchemaBuilder> = DVRCF_SchemaBuilder.New("Immersive Footwear POV");
    return b
      .Tab("Footwear POV")
        .Section("Manual Height Overrides")
          .Group("Custom Shoes & Height Testing")
          .Slider("manualHeelHeightCm", "Heel Height (cm)", 0.0, 25.0, 0.5, false)
            .Tip("Adjust heel height elevation in centimeters (0.0 to 25.0 cm).")
          .Slider("manualPlatformHeightCm", "Platform Height (cm)", 0.0, 25.0, 0.5, false)
            .Tip("Adjust platform height in centimeters (0.0 to 25.0 cm).")
          .Button("applyOverride", "Apply Footwear Height")
            .Tip("Applies the chosen heel and platform height directly to your character's first-person POV.")
          .Button("clearOverride", "Reset to Default / Clear Override")
            .Tip("Clears custom height and restores official shoe tags or baseline.")
        .Section("Diagnostics & Telemetry")
          .Toggle("debugLogging", "Enable Transition Debug Logging")
            .Tip("Logs elevation changes, TFP state transitions, and suppression events to the REDscript/CET console.")
      .Build();
  }

  public func GetBool(key: String) -> Bool {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(this.m_gi);
    if !IsDefined(sys) { return false; };
    if Equals(key, "debugLogging") { return sys.IsDebugLogging(); };
    return false;
  }

  public func SetBool(key: String, value: Bool) -> Void {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(this.m_gi);
    if !IsDefined(sys) { return; };
    if Equals(key, "debugLogging") { sys.SetDebugLogging(value); };
  }

  public func GetFloat(key: String) -> Float {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(this.m_gi);
    if !IsDefined(sys) { return 0.0; };
    if Equals(key, "manualHeelHeightCm") {
      if this.m_manualHeelCm > 0.0001 { return this.m_manualHeelCm; };
      return sys.GetCurrentHeelHeight() * 100.0;
    };
    if Equals(key, "manualPlatformHeightCm") {
      if this.m_manualPlatformCm > 0.0001 { return this.m_manualPlatformCm; };
      return sys.GetCurrentPlatformHeight() * 100.0;
    };
    return 0.0;
  }

  public func SetFloat(key: String, value: Float) -> Void {
    if Equals(key, "manualHeelHeightCm") {
      this.m_manualHeelCm = value;
    };
    if Equals(key, "manualPlatformHeightCm") {
      this.m_manualPlatformCm = value;
    };
  }

  public func GetInt(key: String) -> Int32 { return 0; }
  public func SetInt(key: String, value: Int32) -> Void {}

  public func OnButton(key: String) -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.m_gi);
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(this.m_gi);
    if !IsDefined(player) || !IsDefined(sys) { return; };

    if Equals(key, "applyOverride") {
      sys.SetCustomHeightOverride(player, this.m_manualHeelCm / 100.0, this.m_manualPlatformCm / 100.0, true);
    };

    if Equals(key, "clearOverride") {
      this.m_manualHeelCm = 0.0;
      this.m_manualPlatformCm = 0.0;
      sys.ClearCustomHeightOverride(player, true);
    };
  }

  public func OnSave() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.m_gi);
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(this.m_gi);
    if IsDefined(player) && IsDefined(sys) {
      if this.m_manualHeelCm > 0.0001 || this.m_manualPlatformCm > 0.0001 {
        sys.SetCustomHeightOverride(player, this.m_manualHeelCm / 100.0, this.m_manualPlatformCm / 100.0, true);
      };
    };
  }
}

// -----------------------------------------------------------------------------
// RCF Lifecycle Registration System
// -----------------------------------------------------------------------------
@if(ModuleExists("RedscriptConfigFramework"))
public class FootwearConfigRegistrar extends ScriptableSystem {
  private let m_provider: ref<FootwearConfigProvider>;

  private final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.RegisterProvider();
  }

  private final func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
    this.RegisterProvider();
  }

  private final func RegisterProvider() -> Void {
    if !IsDefined(this.m_provider) {
      this.m_provider = new FootwearConfigProvider();
      this.m_provider.Init(this.GetGameInstance());
      DVRCF.Register(this.GetGameInstance(), "ImmersiveFootwearPOV", "Immersive Footwear POV", "Footwear height elevation, custom shoe overrides, and POV settings.", this.m_provider);
    };
  }
}
