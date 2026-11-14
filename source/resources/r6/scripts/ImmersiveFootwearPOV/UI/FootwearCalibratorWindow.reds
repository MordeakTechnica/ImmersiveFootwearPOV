module ImmersiveFootwearPOV

@if(ModuleExists("RedWindows"))
import RedWindows.*
@if(ModuleExists("RedFunctions"))
import RedFunctions.*

// =============================================================================
// Immersive Footwear POV - Live Shoe Height Calibrator Window
// Single Responsibility: Real-time slider adjustments & manual numerical inputs
// with instant character preview, matching CET calibration capabilities.
// =============================================================================
@if(ModuleExists("RedWindows"))
public class CalibratorAxisController {
  private let m_sliderRow: CName;
  private let m_inputRow: CName;
  private let m_sliderLabel: String;
  private let m_inputLabel: String;
  private let m_maxCm: Float;
  private let m_lastSyncedCm: Float;
  private let m_wasInputFocused: Bool;

  public let sliderValueCm: Float;
  public let manualInputStr: String;
  public let targetCm: Float;
  public let didChange: Bool;
  public let isInteracting: Bool;
  public let isInputFocused: Bool;
  public let didFinishManualInput: Bool;
  private let m_changedBySlider: Bool;

  public static func Create(sliderRow: CName, inputRow: CName, sliderLabel: String, inputLabel: String, maxCm: Float) -> ref<CalibratorAxisController> {
    let axis: ref<CalibratorAxisController> = new CalibratorAxisController();
    axis.m_sliderRow = sliderRow;
    axis.m_inputRow = inputRow;
    axis.m_sliderLabel = sliderLabel;
    axis.m_inputLabel = inputLabel;
    axis.m_maxCm = maxCm;
    axis.m_lastSyncedCm = -1.0;
    return axis;
  }

  public func InvalidateSync() -> Void {
    this.m_lastSyncedCm = -1.0;
  }

  public func ForceSync(win: ref<RWWindow>, valueCm: Float) -> Void {
    this.m_lastSyncedCm = valueCm;
    win.SetValueF(this.m_sliderRow, valueCm);
    win.SetInputText(this.m_inputRow, FloatToStringPrec(valueCm, 1));
  }

  public func SyncAfterApply(win: ref<RWWindow>, valueCm: Float) -> Void {
    this.m_lastSyncedCm = valueCm;
    if this.m_changedBySlider || !this.isInputFocused {
      win.SetInputText(this.m_inputRow, FloatToStringPrec(valueCm, 1));
    };
  }

  public func DrawWidgets(win: ref<RWWindow>, currentCm: Float) -> Void {
    this.sliderValueCm = win.SliderF(this.m_sliderRow, this.m_sliderLabel, 0.0, this.m_maxCm, currentCm, 0.50);
    this.manualInputStr = win.Input(this.m_inputRow, this.m_inputLabel, FloatToStringPrec(currentCm, 1));
  }

  public func EvaluateInteraction(win: ref<RWWindow>, currentCm: Float, shoeChanged: Bool) -> Void {
    let sliderChanged: Bool = win.Changed(this.m_sliderRow);
    let sliderActive: Bool = win.Active(this.m_sliderRow);
    let inputChanged: Bool = win.Changed(this.m_inputRow);
    let inputSubmitted: Bool = win.InputSubmitted(this.m_inputRow);
    let inputFocused: Bool = win.InputFocused(this.m_inputRow);
    let inputFocusLost: Bool = this.m_wasInputFocused && !inputFocused;
    this.m_wasInputFocused = inputFocused;

    this.targetCm = currentCm;
    this.didChange = false;
    this.m_changedBySlider = false;
    this.isInputFocused = inputFocused;
    this.isInteracting = sliderActive || inputFocused;
    this.didFinishManualInput = inputSubmitted || inputFocusLost;

    if shoeChanged && !sliderChanged && !inputChanged && !inputSubmitted {
      this.m_lastSyncedCm = currentCm;
      win.SetValueF(this.m_sliderRow, currentCm);
      if !inputFocused {
        win.SetInputText(this.m_inputRow, FloatToStringPrec(currentCm, 1));
      };
      this.sliderValueCm = currentCm;
    };

    if sliderChanged {
      this.m_changedBySlider = true;
      this.targetCm = this.sliderValueCm;
      this.didChange = true;
      return;
    };

    if inputSubmitted || inputChanged || inputFocusLost {
      if StrLen(this.manualInputStr) > 0 {
        let typedCm: Float = ClampF(StringToFloat(this.manualInputStr), 0.0, this.m_maxCm);
        if inputChanged || inputSubmitted || AbsF(typedCm - currentCm) > 0.01 {
          win.SetValueF(this.m_sliderRow, typedCm);
          this.targetCm = typedCm;
          this.didChange = true;
        };
      };
      if !inputFocused && !this.didChange {
        win.SetInputText(this.m_inputRow, FloatToStringPrec(currentCm, 1));
      };
      return;
    };

    if !sliderActive && !inputFocused {
      if AbsF(this.m_lastSyncedCm - currentCm) > 0.05 || AbsF(this.sliderValueCm - currentCm) > 0.25 {
        this.ForceSync(win, currentCm);
      };
    };
  }
}

@if(ModuleExists("RedWindows"))
public class FootwearCalibratorWindow {
  private let m_lastShoeKey: String;
  private let m_lastHasFootwear: Int32;
  private let m_heelAxis: ref<CalibratorAxisController>;
  private let m_platAxis: ref<CalibratorAxisController>;

  public static func Create() -> ref<FootwearCalibratorWindow> {
    let win: ref<FootwearCalibratorWindow> = new FootwearCalibratorWindow();
    win.m_lastHasFootwear = -1;
    win.m_heelAxis = CalibratorAxisController.Create(n"calib_slider_heel", n"calib_input_heel", "Custom Heel Slider (cm)", "Manual Heel (cm)", FootwearHeightLimits.GetMaxHeightCm());
    win.m_platAxis = CalibratorAxisController.Create(n"calib_slider_plat", n"calib_input_plat", "Custom Platform Slider (cm)", "Manual Platform (cm)", FootwearHeightLimits.GetMaxPlatformCm());
    return win;
  }

  public func InvalidateSync() -> Void {
    this.m_lastShoeKey = "";
    if IsDefined(this.m_heelAxis) { this.m_heelAxis.InvalidateSync(); };
    if IsDefined(this.m_platAxis) { this.m_platAxis.InvalidateSync(); };
  }

  public static func Render(gi: GameInstance, opt targetWin: ref<RWWindow>) -> Void {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(system) {
      return;
    };
    system.GetCalibratorWindow().RenderInternal(gi, targetWin);
  }

  private func UpdateRowVisibility(win: ref<RWWindow>, hasFootwear: Bool) -> Void {
    win.SetRowVisible(n"calib_hdr_none", false);
    win.SetRowVisible(n"calib_txt_none", false);
    win.SetRowVisible(n"calib_close_btn", false);
    win.SetRowVisible(n"calib_sep1", hasFootwear);
    win.SetRowVisible(n"calib_slider_heel", hasFootwear);
    win.SetRowVisible(n"calib_input_heel", hasFootwear);
    win.SetRowVisible(n"calib_heel_tip1", hasFootwear);
    win.SetRowVisible(n"calib_heel_tip2", hasFootwear);
    win.SetRowVisible(n"calib_sep2", hasFootwear);
    win.SetRowVisible(n"calib_slider_plat", hasFootwear);
    win.SetRowVisible(n"calib_input_plat", hasFootwear);
    win.SetRowVisible(n"calib_plat_tip1", hasFootwear);
    win.SetRowVisible(n"calib_plat_tip2", hasFootwear);
    win.SetRowVisible(n"calib_presets_hdr", hasFootwear);
    win.SetRowVisible(n"calib_pre_0", hasFootwear);
    win.SetRowVisible(n"calib_pre_4", hasFootwear);
    win.SetRowVisible(n"calib_pre_8", hasFootwear);
    win.SetRowVisible(n"calib_pre_12", hasFootwear);
    win.SetRowVisible(n"calib_spc", hasFootwear);
    win.SetRowVisible(n"calib_btn_save", hasFootwear);
    win.SetRowVisible(n"calib_btn_revert", hasFootwear);
    win.SetRowVisible(n"calib_spc_none", !hasFootwear);
    win.SetRowVisible(n"calib_btn_close", !hasFootwear);
  }

  private func ApplyPresetHeel(system: ref<ImmersiveFootwearPOVSystem>, win: ref<RWWindow>, heelCm: Float) -> Void {
    let platMeters: Float = system.GetCurrentPlatformHeight();
    system.ApplyLiveCalibration(heelCm / 100.0, platMeters);
    system.FlushPendingOverrideSave();
    this.m_heelAxis.ForceSync(win, system.GetCurrentHeelHeight() * 100.0);
    this.m_platAxis.ForceSync(win, system.GetCurrentPlatformHeight() * 100.0);
  }

  public func RenderInternal(gi: GameInstance, opt targetWin: ref<RWWindow>) -> Void {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(system) {
      return;
    };

    let win: ref<RWWindow> = IsDefined(targetWin) ? targetWin : RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    if !IsDefined(win) {
      return;
    };

    win.SetSkinStyle(RWSkinStyle.Popup);
    win.minW = 520.0;
    win.SetClosable(true);
    win.SetOverlayOnly(true);

    let cfg: ref<FootwearConfig> = system.GetConfig();
    if IsDefined(cfg) {
      let nextFocus: Bool = win.Checkbox(n"calib_focus_boots", "Focus Boots in TPP (Close Low-Angle View)", cfg.focusBootsInTPP);
      if NotEquals(nextFocus, cfg.focusBootsInTPP) {
        cfg.focusBootsInTPP = nextFocus;
        system.OnConfigUpdated(cfg);
        system.GetStorageManager().SaveConfig(cfg);
        ITPController.MaintainCalibratorTPPLease(gi, cfg.focusBootsInTPP);
        FootwearCalibratorCamera.SetFocusBoots(gi, cfg.focusBootsInTPP);
      };
    };

    let itemID: ItemID = system.GetEquippedFootwearID();
    let hasFootwear: Bool = ItemID.IsValid(itemID);
    let shoeKey: String = hasFootwear ? TDBID.ToStringDEBUG(ItemID.GetTDBID(itemID)) : "";

    let curState: Int32 = hasFootwear ? 1 : 0;
    if NotEquals(this.m_lastHasFootwear, curState) {
      this.m_lastHasFootwear = curState;
      this.UpdateRowVisibility(win, hasFootwear);
    };

    win.Header(n"calib_hdr", hasFootwear ? s"Calibrating: \(shoeKey)" : "No Footwear Equipped");
    win.Text(n"calib_sub", hasFootwear ? s"Source: [\(system.GetSettingsSource())] | Adjust sliders or type values for live preview on V." : "Equip a pair of shoes or boots in inventory to calibrate.");

    if !hasFootwear {
      this.InvalidateSync();
      win.Spacer(n"calib_spc_none");
      if win.Button(n"calib_btn_close", "Close Calibrator") {
        FootwearWindowsController.CloseCalibrator(gi);
      };
      return;
    };

    win.Separator(n"calib_sep1");
    let currentHeelCm: Float = system.GetCurrentHeelHeight() * 100.0;
    let currentPlatCm: Float = system.GetCurrentPlatformHeight() * 100.0;

    this.m_heelAxis.DrawWidgets(win, currentHeelCm);
    win.Text(n"calib_heel_tip1", "  -> Total heel: drives catwalk sway pitch; elevates FPP camera up to 25.0 cm max.");
    win.Text(n"calib_heel_tip2", "  -> Manual input: Type exact cm (Auto-clamps: 0.0 to 40.0 cm; negative disallowed).");

    win.Separator(n"calib_sep2");
    this.m_platAxis.DrawWidgets(win, currentPlatCm);
    win.Text(n"calib_plat_tip1", "  -> Front sole thickness: lifts character puppet in Third Person & Photo Mode.");
    win.Text(n"calib_plat_tip2", "  -> Manual input: Type exact cm (Auto-clamps: 0.0 to 30.0 cm; negative disallowed).");

    let shoeChanged: Bool = NotEquals(this.m_lastShoeKey, shoeKey);
    if shoeChanged {
      this.m_lastShoeKey = shoeKey;
    };

    this.m_heelAxis.EvaluateInteraction(win, currentHeelCm, shoeChanged);
    this.m_platAxis.EvaluateInteraction(win, currentPlatCm, shoeChanged);

    if this.m_heelAxis.didChange || this.m_platAxis.didChange {
      system.ApplyLiveCalibration(this.m_heelAxis.targetCm / 100.0, this.m_platAxis.targetCm / 100.0);
      currentHeelCm = system.GetCurrentHeelHeight() * 100.0;
      currentPlatCm = system.GetCurrentPlatformHeight() * 100.0;
      if this.m_heelAxis.didChange {
        this.m_heelAxis.SyncAfterApply(win, currentHeelCm);
      };
      if this.m_platAxis.didChange {
        this.m_platAxis.SyncAfterApply(win, currentPlatCm);
      };
    };

    if system.HasDirtyOverride() {
      let manualFinished: Bool = this.m_heelAxis.didFinishManualInput || this.m_platAxis.didFinishManualInput;
      let idleAfterEdit: Bool = !this.m_heelAxis.isInteracting && !this.m_platAxis.isInteracting;
      if manualFinished || idleAfterEdit {
        system.FlushPendingOverrideSave();
        win.Text(n"calib_sub", s"Source: [\(system.GetSettingsSource())] | Adjust sliders or type values for live preview on V.");
      };
    };

    win.Header(n"calib_presets_hdr", "Quick Heel Presets");
    if win.Button(n"calib_pre_0", "Flat (0.0 cm)") { this.ApplyPresetHeel(system, win, 0.0); };
    if win.Button(n"calib_pre_4", "Low Heel (4.0 cm)") { this.ApplyPresetHeel(system, win, 4.0); };
    if win.Button(n"calib_pre_8", "Mid Heel (8.0 cm)") { this.ApplyPresetHeel(system, win, 8.0); };
    if win.Button(n"calib_pre_12", "High Heel (12.0 cm)") { this.ApplyPresetHeel(system, win, 12.0); };

    win.Spacer(n"calib_spc");

    if win.Button(n"calib_btn_save", "Save as Permanent Custom Override") {
      let activeHeel: Float = system.GetCurrentHeelHeight();
      let activePlat: Float = system.GetCurrentPlatformHeight();
      system.ClearPendingOverrideSave();
      system.GetStorageManager().SaveUserOverride(shoeKey, activeHeel, activePlat);
      system.RegisterCustomOverride(shoeKey, activeHeel, activePlat);
      this.m_heelAxis.ForceSync(win, activeHeel * 100.0);
      this.m_platAxis.ForceSync(win, activePlat * 100.0);
      FootwearRedLogger.LogInfo("CALIBRATOR", s"Saved permanent override for \(shoeKey) via RedWindows");
    };

    if win.Button(n"calib_btn_revert", "Revert to Tag/Preset Default") {
      system.ClearPendingOverrideSave();
      system.GetStorageManager().RemoveUserOverride(shoeKey);
      system.RevertFootwearToDefault();
      this.m_heelAxis.ForceSync(win, system.GetCurrentHeelHeight() * 100.0);
      this.m_platAxis.ForceSync(win, system.GetCurrentPlatformHeight() * 100.0);
      FootwearRedLogger.LogInfo("CALIBRATOR", s"Reverted override for \(shoeKey) to baseline");
    };

    if win.Button(n"calib_btn_close", "Close Calibrator") {
      FootwearWindowsController.CloseCalibrator(gi);
    };
  }
}

// -----------------------------------------------------------------------------
// Fallback Stub (when RedWindows is NOT installed)
// -----------------------------------------------------------------------------
@if(!ModuleExists("RedWindows"))
public class FootwearCalibratorWindow {
  public static func Create() -> ref<FootwearCalibratorWindow> {
    return new FootwearCalibratorWindow();
  }
  public func InvalidateSync() -> Void {}
}
