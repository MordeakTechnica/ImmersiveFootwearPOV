module ImmersiveFootwearPOV

import RedWindows.*
import RedFunctions.*

// =============================================================================
// Immersive Footwear POV - Live Shoe Height Calibrator Window
// Single Responsibility: Real-time slider adjustments & manual numerical inputs
// with instant character preview, matching CET calibration capabilities.
// =============================================================================
public class FootwearCalibratorWindow {
  private let m_lastShoeKey: String;
  private let m_lastHasFootwear: Int32;

  /**
   * Instantiates a new footwear calibrator window instance with uninitialized state.
   *
   * @return Initialized footwear calibrator window reference.
   */
  public static func Create() -> ref<FootwearCalibratorWindow> {
    let win: ref<FootwearCalibratorWindow> = new FootwearCalibratorWindow();
    win.m_lastHasFootwear = -1;
    return win;
  }

  /**
   * Static entrypoint for rendering the footwear calibrator window.
   *
   * @param gi Game instance context.
   * @param targetWin Optional RedWindows window container to render within.
   */
  public static func Render(gi: GameInstance, opt targetWin: ref<RWWindow>) -> Void {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if IsDefined(system) {
      system.GetCalibratorWindow().RenderInternal(gi, targetWin);
    };
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
    win.Text(n"calib_sub", hasFootwear ? "Adjust sliders or type exact values below for instant live preview on V." : "Equip a pair of shoes or boots in inventory to calibrate.");

    if !hasFootwear {
      win.Spacer(n"calib_spc_none");
      if win.Button(n"calib_btn_close", "Close Calibrator") {
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

    // Footwear change detection: synchronize both slider and manual input to new baseline
    if NotEquals(this.m_lastShoeKey, shoeKey) {
      this.m_lastShoeKey = shoeKey;
      win.SetValueF(n"calib_slider_heel", currentHeelCm);
      win.SetInputText(n"calib_input_heel", FloatToStringPrec(currentHeelCm, 1));
      win.SetValueF(n"calib_slider_plat", currentPlatCm);
      win.SetInputText(n"calib_input_plat", FloatToStringPrec(currentPlatCm, 1));
    };

    // -------------------------------------------------------------------------
    // Custom Heel Height Controls (Slider + Manual Numerical Input)
    // -------------------------------------------------------------------------
    let newHeelCm: Float = win.SliderF(n"calib_slider_heel", "Custom Heel Slider (cm)", 0.0, maxHeelCm, currentHeelCm, 0.50);
    let manualHeelStr: String = win.Input(n"calib_input_heel", "Manual Heel (cm)", FloatToStringPrec(currentHeelCm, 1));

    if win.Changed(n"calib_slider_heel") {
      win.SetInputText(n"calib_input_heel", FloatToStringPrec(newHeelCm, 1));
      system.ApplyLiveCalibration(newHeelCm / 100.0, currentPlatCm / 100.0);
    } else if win.InputSubmitted(n"calib_input_heel") || win.Changed(n"calib_input_heel") {
      if StrLen(manualHeelStr) > 0 {
        let typedHeel: Float = ClampF(StringToFloat(manualHeelStr), 0.0, maxHeelCm);
        win.SetValueF(n"calib_slider_heel", typedHeel);
        system.ApplyLiveCalibration(typedHeel / 100.0, currentPlatCm / 100.0);
      };
    };

    win.Text(n"calib_heel_tip1", "  -> Total heel: drives catwalk sway pitch; elevates FPP camera up to 25.0 cm max.");
    win.Text(n"calib_heel_tip2", "  -> Manual input: Type exact cm (Auto-clamps: 0.0 to 40.0 cm; negative disallowed).");

    win.Separator(n"calib_sep2");

    // -------------------------------------------------------------------------
    // Custom Platform Height Controls (Slider + Manual Numerical Input)
    // -------------------------------------------------------------------------
    let newPlatCm: Float = win.SliderF(n"calib_slider_plat", "Custom Platform Slider (cm)", 0.0, maxPlatCm, currentPlatCm, 0.50);
    let manualPlatStr: String = win.Input(n"calib_input_plat", "Manual Platform (cm)", FloatToStringPrec(currentPlatCm, 1));

    if win.Changed(n"calib_slider_plat") {
      win.SetInputText(n"calib_input_plat", FloatToStringPrec(newPlatCm, 1));
      system.ApplyLiveCalibration(currentHeelCm / 100.0, newPlatCm / 100.0);
    } else if win.InputSubmitted(n"calib_input_plat") || win.Changed(n"calib_input_plat") {
      if StrLen(manualPlatStr) > 0 {
        let typedPlat: Float = ClampF(StringToFloat(manualPlatStr), 0.0, maxPlatCm);
        win.SetValueF(n"calib_slider_plat", typedPlat);
        system.ApplyLiveCalibration(currentHeelCm / 100.0, typedPlat / 100.0);
      };
    };

    win.Text(n"calib_plat_tip1", "  -> Front sole thickness: lifts character puppet in Third Person & Photo Mode.");
    win.Text(n"calib_plat_tip2", "  -> Manual input: Type exact cm (Auto-clamps: 0.0 to 30.0 cm; negative disallowed).");

    win.Spacer(n"calib_spc");

    // -------------------------------------------------------------------------
    // Action Buttons
    // -------------------------------------------------------------------------
    if win.Button(n"calib_btn_save", "Save as Permanent Custom Override") {
      let activeHeel: Float = system.GetCurrentHeelHeight();
      let activePlat: Float = system.GetCurrentPlatformHeight();
      FootwearStorageManager.GetInstance().SaveUserOverride(shoeKey, activeHeel, activePlat);
      system.RegisterCustomOverride(shoeKey, activeHeel, activePlat);
      FootwearRedLogger.LogInfo("CALIBRATOR", s"Saved permanent override for \(shoeKey) via RedWindows");
    };

    if win.Button(n"calib_btn_revert", "Revert to Tag/Preset Default") {
      FootwearStorageManager.GetInstance().RemoveUserOverride(shoeKey);
      system.RevertFootwearToDefault();
      let defaultHeelCm: Float = system.GetCurrentHeelHeight() * 100.0;
      let defaultPlatCm: Float = system.GetCurrentPlatformHeight() * 100.0;
      win.SetValueF(n"calib_slider_heel", defaultHeelCm);
      win.SetInputText(n"calib_input_heel", FloatToStringPrec(defaultHeelCm, 1));
      win.SetValueF(n"calib_slider_plat", defaultPlatCm);
      win.SetInputText(n"calib_input_plat", FloatToStringPrec(defaultPlatCm, 1));
      FootwearRedLogger.LogInfo("CALIBRATOR", s"Reverted override for \(shoeKey) to baseline");
    };

    if win.Button(n"calib_btn_close", "Close Calibrator") {
      FootwearWindowsController.SaveGeometryImmediate(gi);
      win.Hide();
    };
  }
}
