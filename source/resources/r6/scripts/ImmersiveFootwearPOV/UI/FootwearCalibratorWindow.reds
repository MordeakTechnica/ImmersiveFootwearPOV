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
public class FootwearCalibratorWindow {
  private let m_lastShoeKey: String;
  private let m_lastHasFootwear: Int32;
  private let m_lastSyncedHeelCm: Float;
  private let m_lastSyncedPlatCm: Float;
  private let m_wasHeelInputFocused: Bool;
  private let m_wasPlatInputFocused: Bool;

  /**
   * Instantiates a new footwear calibrator window instance with uninitialized state.
   *
   * @return Initialized footwear calibrator window reference.
   */
  public static func Create() -> ref<FootwearCalibratorWindow> {
    let win: ref<FootwearCalibratorWindow> = new FootwearCalibratorWindow();
    win.m_lastHasFootwear = -1;
    win.m_lastSyncedHeelCm = -1.0;
    win.m_lastSyncedPlatCm = -1.0;
    return win;
  }

  /**
   * Invalidates cached slider synchronization state so controls resync on next render.
   */
  public func InvalidateSync() -> Void {
    this.m_lastShoeKey = "";
    this.m_lastSyncedHeelCm = -1.0;
    this.m_lastSyncedPlatCm = -1.0;
  }

  /**
   * Static entrypoint for rendering the footwear calibrator window.
   *
   * @param gi Game instance context.
   * @param targetWin Optional RedWindows window container to render within.
   */
  public static func Render(gi: GameInstance, opt targetWin: ref<RWWindow>) -> Void {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(system) {
      return;
    };
    system.GetCalibratorWindow().RenderInternal(gi, targetWin);
  }

  /**
   * Internal render implementation handling dynamic UI state, slider adjustments,
   * manual text input clamping, live elevation preview, and override persistence.
   *
   * @param gi Game instance context.
   * @param targetWin Optional RedWindows window container to render within.
   */
  public func RenderInternal(gi: GameInstance, opt targetWin: ref<RWWindow>) -> Void {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(system) {
      return;
    };

    let win: ref<RWWindow> = targetWin;
    if !IsDefined(win) {
      win = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    };
    if !IsDefined(win) {
      return;
    };

    win.minW = 500.0;
    win.SetClosable(true);
    win.SetOverlayOnly(true); // Always hide when closing RedWindows overlay

    let itemID: ItemID = system.GetEquippedFootwearID();
    let hasFootwear: Bool = ItemID.IsValid(itemID);
    let shoeKey: String = hasFootwear ? TDBID.ToStringDEBUG(ItemID.GetTDBID(itemID)) : "";

    // Toggle row visibility ONLY when equipped state changes (avoids costly ApplyGeometry layout passes)
    let curState: Int32 = hasFootwear ? 1 : 0;
    if NotEquals(this.m_lastHasFootwear, curState) {
      this.m_lastHasFootwear = curState;
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
      win.SetRowVisible(n"calib_spc", hasFootwear);
      win.SetRowVisible(n"calib_btn_save", hasFootwear);
      win.SetRowVisible(n"calib_btn_revert", hasFootwear);
      win.SetRowVisible(n"calib_spc_none", !hasFootwear);
      win.SetRowVisible(n"calib_btn_close", !hasFootwear);
    };

    // Unified Header & Subtitle (avoids duplicate retained rows in RedWindows)
    win.Header(n"calib_hdr", hasFootwear ? s"Calibrating: \(shoeKey)" : "No Footwear Equipped");
    win.Text(n"calib_sub", hasFootwear ? s"Source: [\(system.GetSettingsSource())] | Adjust sliders or type values for live preview on V." : "Equip a pair of shoes or boots in inventory to calibrate.");

    if !hasFootwear {
      this.InvalidateSync();
      win.Spacer(n"calib_spc_none");
      if win.Button(n"calib_btn_close", "Close Calibrator") {
        system.FlushPendingOverrideSave();
        FootwearWindowsController.SaveGeometryImmediate(gi);
        win.Hide();
      };
      return;
    };

    win.Separator(n"calib_sep1");

    let currentHeelCm: Float = system.GetCurrentHeelHeight() * 100.0;
    let currentPlatCm: Float = system.GetCurrentPlatformHeight() * 100.0;

    let maxHeelCm: Float = FootwearHeightLimits.GetMaxHeightCm();     // 40.0 cm
    let maxPlatCm: Float = FootwearHeightLimits.GetMaxPlatformCm();   // 30.0 cm

    // -------------------------------------------------------------------------
    // Custom Heel Height Controls (Slider + Manual Numerical Input)
    // -------------------------------------------------------------------------
    let newHeelCm: Float = win.SliderF(n"calib_slider_heel", "Custom Heel Slider (cm)", 0.0, maxHeelCm, currentHeelCm, 0.50);
    let manualHeelStr: String = win.Input(n"calib_input_heel", "Manual Heel (cm)", FloatToStringPrec(currentHeelCm, 1));

    win.Text(n"calib_heel_tip1", "  -> Total heel: drives catwalk sway pitch; elevates FPP camera up to 25.0 cm max.");
    win.Text(n"calib_heel_tip2", "  -> Manual input: Type exact cm (Auto-clamps: 0.0 to 40.0 cm; negative disallowed).");

    win.Separator(n"calib_sep2");

    // -------------------------------------------------------------------------
    // Custom Platform Height Controls (Slider + Manual Numerical Input)
    // -------------------------------------------------------------------------
    let newPlatCm: Float = win.SliderF(n"calib_slider_plat", "Custom Platform Slider (cm)", 0.0, maxPlatCm, currentPlatCm, 0.50);
    let manualPlatStr: String = win.Input(n"calib_input_plat", "Manual Platform (cm)", FloatToStringPrec(currentPlatCm, 1));

    win.Text(n"calib_plat_tip1", "  -> Front sole thickness: lifts character puppet in Third Person & Photo Mode.");
    win.Text(n"calib_plat_tip2", "  -> Manual input: Type exact cm (Auto-clamps: 0.0 to 30.0 cm; negative disallowed).");

    // -------------------------------------------------------------------------
    // Inspect Widget Interaction & Focus State Before Synchronizing
    // -------------------------------------------------------------------------
    let heelSliderChanged: Bool = win.Changed(n"calib_slider_heel");
    let heelSliderActive: Bool = win.Active(n"calib_slider_heel");
    let heelInputChanged: Bool = win.Changed(n"calib_input_heel");
    let heelInputSubmitted: Bool = win.InputSubmitted(n"calib_input_heel");
    let heelInputFocused: Bool = win.InputFocused(n"calib_input_heel");
    let heelInputFocusLost: Bool = this.m_wasHeelInputFocused && !heelInputFocused;
    this.m_wasHeelInputFocused = heelInputFocused;

    let platSliderChanged: Bool = win.Changed(n"calib_slider_plat");
    let platSliderActive: Bool = win.Active(n"calib_slider_plat");
    let platInputChanged: Bool = win.Changed(n"calib_input_plat");
    let platInputSubmitted: Bool = win.InputSubmitted(n"calib_input_plat");
    let platInputFocused: Bool = win.InputFocused(n"calib_input_plat");
    let platInputFocusLost: Bool = this.m_wasPlatInputFocused && !platInputFocused;
    this.m_wasPlatInputFocused = platInputFocused;

    let shoeChanged: Bool = NotEquals(this.m_lastShoeKey, shoeKey);
    if shoeChanged {
      this.m_lastShoeKey = shoeKey;
      if !heelSliderChanged && !heelInputChanged && !heelInputSubmitted {
        this.m_lastSyncedHeelCm = currentHeelCm;
        win.SetValueF(n"calib_slider_heel", currentHeelCm);
        if !heelInputFocused {
          win.SetInputText(n"calib_input_heel", FloatToStringPrec(currentHeelCm, 1));
        };
        newHeelCm = currentHeelCm;
      };
      if !platSliderChanged && !platInputChanged && !platInputSubmitted {
        this.m_lastSyncedPlatCm = currentPlatCm;
        win.SetValueF(n"calib_slider_plat", currentPlatCm);
        if !platInputFocused {
          win.SetInputText(n"calib_input_plat", FloatToStringPrec(currentPlatCm, 1));
        };
        newPlatCm = currentPlatCm;
      };
    };

    // Process Heel Slider / Manual Input / External Sync
    if heelSliderChanged {
      win.SetInputText(n"calib_input_heel", FloatToStringPrec(newHeelCm, 1));
      system.ApplyLiveCalibration(newHeelCm / 100.0, currentPlatCm / 100.0);
      currentHeelCm = system.GetCurrentHeelHeight() * 100.0;
      this.m_lastSyncedHeelCm = currentHeelCm;
    } else if heelInputSubmitted || heelInputChanged || heelInputFocusLost {
      if StrLen(manualHeelStr) > 0 {
        let typedHeel: Float = ClampF(StringToFloat(manualHeelStr), 0.0, maxHeelCm);
        if heelInputChanged || heelInputSubmitted || AbsF(typedHeel - currentHeelCm) > 0.01 {
          win.SetValueF(n"calib_slider_heel", typedHeel);
          system.ApplyLiveCalibration(typedHeel / 100.0, currentPlatCm / 100.0);
          currentHeelCm = system.GetCurrentHeelHeight() * 100.0;
          this.m_lastSyncedHeelCm = currentHeelCm;
        };
      };
      if !heelInputFocused {
        win.SetInputText(n"calib_input_heel", FloatToStringPrec(currentHeelCm, 1));
      };
    } else if !heelSliderActive && !heelInputFocused {
      if AbsF(this.m_lastSyncedHeelCm - currentHeelCm) > 0.05 || AbsF(newHeelCm - currentHeelCm) > 0.25 {
        this.m_lastSyncedHeelCm = currentHeelCm;
        win.SetValueF(n"calib_slider_heel", currentHeelCm);
        win.SetInputText(n"calib_input_heel", FloatToStringPrec(currentHeelCm, 1));
      };
    };

    // Process Platform Slider / Manual Input / External Sync
    if platSliderChanged {
      win.SetInputText(n"calib_input_plat", FloatToStringPrec(newPlatCm, 1));
      system.ApplyLiveCalibration(currentHeelCm / 100.0, newPlatCm / 100.0);
      currentPlatCm = system.GetCurrentPlatformHeight() * 100.0;
      this.m_lastSyncedPlatCm = currentPlatCm;
    } else if platInputSubmitted || platInputChanged || platInputFocusLost {
      if StrLen(manualPlatStr) > 0 {
        let typedPlat: Float = ClampF(StringToFloat(manualPlatStr), 0.0, maxPlatCm);
        if platInputChanged || platInputSubmitted || AbsF(typedPlat - currentPlatCm) > 0.01 {
          win.SetValueF(n"calib_slider_plat", typedPlat);
          system.ApplyLiveCalibration(currentHeelCm / 100.0, typedPlat / 100.0);
          currentPlatCm = system.GetCurrentPlatformHeight() * 100.0;
          this.m_lastSyncedPlatCm = currentPlatCm;
        };
      };
      if !platInputFocused {
        win.SetInputText(n"calib_input_plat", FloatToStringPrec(currentPlatCm, 1));
      };
    } else if !platSliderActive && !platInputFocused {
      if AbsF(this.m_lastSyncedPlatCm - currentPlatCm) > 0.05 || AbsF(newPlatCm - currentPlatCm) > 0.25 {
        this.m_lastSyncedPlatCm = currentPlatCm;
        win.SetValueF(n"calib_slider_plat", currentPlatCm);
        win.SetInputText(n"calib_input_plat", FloatToStringPrec(currentPlatCm, 1));
      };
    };

    // Auto-save dirty overrides as soon as slider drag finishes or manual input is submitted/unfocused
    if system.HasDirtyOverride() {
      let manualFinished: Bool = heelInputSubmitted || platInputSubmitted || heelInputFocusLost || platInputFocusLost;
      let idleAfterEdit: Bool = !heelSliderActive && !platSliderActive && !heelInputFocused && !platInputFocused;
      if manualFinished || idleAfterEdit {
        system.FlushPendingOverrideSave();
        // Refresh subtitle immediately so Source: [Custom User Override] is shown
        win.Text(n"calib_sub", s"Source: [\(system.GetSettingsSource())] | Adjust sliders or type values for live preview on V.");
      };
    };

    win.Spacer(n"calib_spc");

    // -------------------------------------------------------------------------
    // Action Buttons
    // -------------------------------------------------------------------------
    if win.Button(n"calib_btn_save", "Save as Permanent Custom Override") {
      let activeHeel: Float = system.GetCurrentHeelHeight();
      let activePlat: Float = system.GetCurrentPlatformHeight();
      system.ClearPendingOverrideSave();
      system.GetStorageManager().SaveUserOverride(shoeKey, activeHeel, activePlat);
      system.RegisterCustomOverride(shoeKey, activeHeel, activePlat);
      this.m_lastSyncedHeelCm = activeHeel * 100.0;
      this.m_lastSyncedPlatCm = activePlat * 100.0;
      FootwearRedLogger.LogInfo("CALIBRATOR", s"Saved permanent override for \(shoeKey) via RedWindows");
    };

    if win.Button(n"calib_btn_revert", "Revert to Tag/Preset Default") {
      system.ClearPendingOverrideSave();
      system.GetStorageManager().RemoveUserOverride(shoeKey);
      system.RevertFootwearToDefault();
      let defaultHeelCm: Float = system.GetCurrentHeelHeight() * 100.0;
      let defaultPlatCm: Float = system.GetCurrentPlatformHeight() * 100.0;
      this.m_lastSyncedHeelCm = defaultHeelCm;
      this.m_lastSyncedPlatCm = defaultPlatCm;
      win.SetValueF(n"calib_slider_heel", defaultHeelCm);
      win.SetInputText(n"calib_input_heel", FloatToStringPrec(defaultHeelCm, 1));
      win.SetValueF(n"calib_slider_plat", defaultPlatCm);
      win.SetInputText(n"calib_input_plat", FloatToStringPrec(defaultPlatCm, 1));
      FootwearRedLogger.LogInfo("CALIBRATOR", s"Reverted override for \(shoeKey) to baseline");
    };

    if win.Button(n"calib_btn_close", "Close Calibrator") {
      system.FlushPendingOverrideSave();
      FootwearWindowsController.SaveGeometryImmediate(gi);
      win.Hide();
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
