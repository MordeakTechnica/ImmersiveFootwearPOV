module ImmersiveFootwearPOV

import RedWindows.*
import RedFunctions.*

// =============================================================================
// Immersive Footwear POV - Live Diagnostics HUD Window
// Single Responsibility: Floating inkWidget HUD displaying live telemetry
public class FootwearDiagnosticsHUD {

  /**
   * Renders the real-time diagnostics HUD window displaying telemetry,
   * active footwear info, contextual suppression states, and perspective modes.
   *
   * @param gi Game instance context.
   * @param targetWin Optional RedWindows window container to render within.
   */
  public static func Render(gi: GameInstance, opt targetWin: ref<RWWindow>) -> Void {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(system) {
      return;
    };

    let win: ref<RWWindow> = targetWin;
    if !IsDefined(win) {
      win = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    };
    if !IsDefined(win) {
      return;
    };

    win.minW = 440.0;
    win.SetClosable(true);

    let player: ref<PlayerPuppet> = GetPlayer(gi);
    let itemID: ItemID = system.GetEquippedFootwearID();
    let source: String = system.GetActiveSource();
    let heelCm: Float = system.GetCurrentHeelHeight() * 100.0;
    let platCm: Float = system.GetCurrentPlatformHeight() * 100.0;
    let effOffsetCm: Float = system.GetEffectiveOffset() * 100.0;
    let isSuppressed: Bool = system.IsSuppressed();
    let suppReason: String = system.GetSuppressionReason();

    // Section 1: Active Footwear
    win.Header(n"hdr_shoe", "Equipped Footwear");
    if ItemID.IsValid(itemID) {
      let tdbidStr: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(itemID));
      win.Text(n"txt_item", s"Item: \(tdbidStr)");
    } else {
      win.Text(n"txt_item", "Item: None (Barefoot / Unequipped)");
    };
    win.BulletText(n"txt_src", s"Source: \(source)");
    win.BulletText(n"txt_heel", s"Heel Elevation: \(FloatToStringPrec(heelCm, 2)) cm");
    win.BulletText(n"txt_plat", s"Platform Sole: \(FloatToStringPrec(platCm, 2)) cm");
    win.BulletText(n"txt_eff", s"Effective Lift: \(FloatToStringPrec(effOffsetCm, 2)) cm");

    win.Separator(n"sep_supp");

    // Section 2: Contextual Suppression
    win.Header(n"hdr_supp", "Suppression & Context");
    if isSuppressed {
      win.Text(n"txt_supp_state", s"State: [SUPPRESSED] - \(suppReason)");
    } else {
      win.Text(n"txt_supp_state", "State: [ACTIVE] - Normal Elevation Applied");
    };
    win.BulletText(n"txt_veh", s"In Vehicle: \(system.IsInVehicle())");
    win.BulletText(n"txt_ws", s"In Workspot (Sitting): \(system.IsInWorkspot())");

    win.Separator(n"sep_cam");

    // Section 3: Perspective & Camera
    win.Header(n"hdr_cam", "Camera & Perspective");
    let isTPP: Bool = IsDefined(player) && ITPController.IsTPPActive(player);
    let isPM: Bool = system.IsPhotoModeActive();
    if isPM {
      win.Text(n"txt_cam", "Perspective: Photo Mode");
    } else if isTPP {
      win.Text(n"txt_cam", "Perspective: Third-Person (ITP Active)");
    } else {
      win.Text(n"txt_cam", "Perspective: First-Person (FPP)");
    };

    win.Spacer(n"spc_bot");

    // HUD mode pinning control
    let pinned: Bool = win.Checkbox(n"ifp_diag_pin", "Show on HUD (when overlay is closed)", true);
    win.SetOverlayOnly(!pinned);

    if win.Button(n"btn_open_calib", "Open Live Shoe Calibrator") {
      FootwearWindowsController.ToggleCalibrator(gi);
    };
    if win.Button(n"btn_close", "Close HUD") {
      win.Hide();
    };
  }
}
