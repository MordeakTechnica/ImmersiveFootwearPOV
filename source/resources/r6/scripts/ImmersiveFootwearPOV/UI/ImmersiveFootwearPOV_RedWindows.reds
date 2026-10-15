module ImmersiveFootwearPOV

import RedWindows.*
import RedFunctions.*

// =============================================================================
// Immersive Footwear POV - RedWindows UI Integration (Facade)
// Single Responsibility: Coordinates opening, closing, and ticking of native windows
// Windows are retained in the RedWindows Window Manager without crowding the top taskbar.
// =============================================================================

public class FootwearWindowsTick extends DelayCallback {
  public let m_gi: GameInstance;

  public func Call() -> Void {
    let nextDelay: Float = FootwearWindowsController.Update(this.m_gi);
    let cb: ref<FootwearWindowsTick> = new FootwearWindowsTick();
    cb.m_gi = this.m_gi;
    GameInstance.GetDelaySystem(this.m_gi).DelayCallback(cb, nextDelay, false);
  }
}

public class FootwearWindowsController {

  public static func Init(gi: GameInstance) -> Void {
    let mgr: ref<RWManager> = RWManager.Get(gi);
    if !IsDefined(mgr) {
      return;
    };

    // Pre-register windows so RedWindows Window Manager is aware of them
    let diagWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    if IsDefined(diagWin) {
      diagWin.minW = 440.0;
      diagWin.SetClosable(true);
    };

    let calibWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    if IsDefined(calibWin) {
      calibWin.minW = 460.0;
      calibWin.SetClosable(true);
      calibWin.SetOverlayOnly(true); // Always hide when closing RedWindows overlay
    };
  }

  public static func StartTick(gi: GameInstance) -> Void {
    let cb: ref<FootwearWindowsTick> = new FootwearWindowsTick();
    cb.m_gi = gi;
    GameInstance.GetDelaySystem(gi).DelayCallback(cb, 1.0, false);
  }

  public static func Update(gi: GameInstance) -> Float {
    let mgr: ref<RWManager> = RWManager.Get(gi);
    if !IsDefined(mgr) {
      return 1.5;
    };

    let isOverlay: Bool = RedWindowsAPI.IsOverlay(gi);

    let diagWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    let isDiagActive: Bool = false;
    if IsDefined(diagWin) && diagWin.IsVisible() {
      // Diagnostics is active if overlay is open OR if pinned to the HUD
      if isOverlay || !diagWin.overlayOnly {
        FootwearDiagnosticsHUD.Render(gi, diagWin);
        isDiagActive = true;
      };
    };

    let calibWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    let isCalibActive: Bool = false;
    if IsDefined(calibWin) && calibWin.IsVisible() {
      // Shoe Calibrator is strictly overlay-only
      if isOverlay {
        FootwearCalibratorWindow.Render(gi, calibWin);
        isCalibActive = true;
      };
    };

    // Adaptive tick delay:
    // When RedWindows overlay is actively open and calibrator is being adjusted: 0.15s for smooth slider response
    // When only HUD telemetry is pinned: 1.0s (lightweight, zero hitching)
    // When overlay is closed and nothing is pinned: 1.5s (idle check)
    if isOverlay && isCalibActive {
      return 0.15;
    };
    if isOverlay || isDiagActive {
      return isOverlay ? 0.25 : 1.0;
    };
    return 1.5;
  }

  public static func RenderDiagnostics(gi: GameInstance) -> Void {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    if IsDefined(win) {
      win.ShowForced();
      FootwearDiagnosticsHUD.Render(gi, win);
    };
  }

  public static func RenderCalibrator(gi: GameInstance) -> Void {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    if IsDefined(win) {
      win.SetOverlayOnly(true);
      win.ShowForced();
      FootwearCalibratorWindow.Render(gi, win);
    };
  }

  public static func ToggleDiagnostics(gi: GameInstance) -> Void {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    if IsDefined(win) {
      if win.IsVisible() {
        win.Hide();
      } else {
        win.ShowForced();
        FootwearDiagnosticsHUD.Render(gi, win);
      };
    };
  }

  public static func ToggleCalibrator(gi: GameInstance) -> Void {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    if IsDefined(win) {
      win.SetOverlayOnly(true);
      if win.IsVisible() && RedWindowsAPI.IsOverlay(gi) {
        win.Hide();
      } else {
        win.ShowForced();
        FootwearCalibratorWindow.Render(gi, win);
        let bb: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().UI_System);
        let inMenu: Bool = IsDefined(bb) && bb.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu);
        if !inMenu {
          RedWindowsAPI.OpenFor(gi, win);
        };
      };
    };
  }
}
