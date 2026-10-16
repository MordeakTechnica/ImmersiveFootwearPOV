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

  /**
   * Periodic callback invoked by DelaySystem to tick and render active RedWindows windows.
   */
  public func Call() -> Void {
    let nextDelay: Float = FootwearWindowsController.Update(this.m_gi);
    let cb: ref<FootwearWindowsTick> = new FootwearWindowsTick();
    cb.m_gi = this.m_gi;
    GameInstance.GetDelaySystem(this.m_gi).DelayCallback(cb, nextDelay, false);
  }
}

public class FootwearWindowsController {

  /**
   * Applies persistently saved window coordinates and dimensions to an active RedWindows window.
   * Clamps positions to visible screen boundaries to prevent off-screen window loss.
   *
   * @param win Target RedWindows window.
   * @param x Saved horizontal coordinate.
   * @param y Saved vertical coordinate.
   * @param w Saved window width.
   * @param h Saved window height (userH).
   * @param minW Minimum allowed window width.
   * @param gi Game instance context.
   */
  public static func ApplySavedGeometry(win: ref<RWWindow>, x: Float, y: Float, w: Float, h: Float, minW: Float, gi: GameInstance) -> Void {
    if !IsDefined(win) {
      return;
    };
    win.minW = minW;
    let mgr: ref<RWManager> = RWManager.Get(gi);
    let inkW: Float = IsDefined(mgr) && mgr.InkW() > 100.0 ? mgr.InkW() : 1920.0;
    let inkH: Float = IsDefined(mgr) && mgr.InkH() > 100.0 ? mgr.InkH() : 1080.0;

    let modified: Bool = false;
    if x >= 0.0 {
      let clampedX: Float = ClampF(x, 0.0, inkW - 60.0);
      if AbsF(win.x - clampedX) > 0.50 {
        win.x = clampedX;
        modified = true;
      };
    };
    if y >= 0.0 {
      let clampedY: Float = ClampF(y, 0.0, inkH - 40.0);
      if AbsF(win.y - clampedY) > 0.50 {
        win.y = clampedY;
        modified = true;
      };
    };
    if w >= minW && AbsF(win.w - w) > 0.50 {
      win.w = w;
      modified = true;
    };
    if h >= 0.0 && AbsF(win.userH - h) > 0.50 {
      win.userH = h;
      modified = true;
    };
    if modified {
      win.ApplyGeometry();
    };
  }

  /**
   * Immediately saves current window coordinates, sizes, and layout to FootwearConfig and RedWindows store.
   *
   * @param gi Game instance context.
   */
  public static func SaveGeometryImmediate(gi: GameInstance) -> Void {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(system) {
      return;
    };
    let cfg: ref<FootwearConfig> = system.GetConfig();
    if !IsDefined(cfg) {
      return;
    };

    let diagWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    if IsDefined(diagWin) && diagWin.x > 0.0 {
      cfg.diagWinX = diagWin.x;
      cfg.diagWinY = diagWin.y;
      cfg.diagWinW = diagWin.w;
      cfg.diagWinH = diagWin.userH;
    };

    let calibWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    if IsDefined(calibWin) && calibWin.x > 0.0 {
      cfg.calibWinX = calibWin.x;
      cfg.calibWinY = calibWin.y;
      cfg.calibWinW = calibWin.w;
      cfg.calibWinH = calibWin.userH;
    };

    FootwearStorageManager.GetInstance().SaveConfig(cfg);
    let mgr: ref<RWManager> = RWManager.Get(gi);
    if IsDefined(mgr) {
      mgr.SaveStore();
    };
  }

  /**
   * Pre-registers mod windows with the RedWindows Window Manager on game startup and restores geometry.
   *
   * @param gi Game instance context.
   */
  public static func Init(gi: GameInstance) -> Void {
    let mgr: ref<RWManager> = RWManager.Get(gi);
    if !IsDefined(mgr) {
      return;
    };

    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    let cfg: ref<FootwearConfig> = IsDefined(system) ? system.GetConfig() : null;

    // Pre-register windows so RedWindows Window Manager is aware of them
    let diagWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    if IsDefined(diagWin) {
      diagWin.minW = 440.0;
      diagWin.SetClosable(true);
      if IsDefined(cfg) {
        diagWin.SetOverlayOnly(!cfg.hudPinned);
        if cfg.hudPinned {
          diagWin.Show();
        };
        FootwearWindowsController.ApplySavedGeometry(diagWin, cfg.diagWinX, cfg.diagWinY, cfg.diagWinW, cfg.diagWinH, 440.0, gi);
        if IsDefined(system) {
          system.SetDiagGeoApplied(true);
        };
      };
    };

    let calibWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    if IsDefined(calibWin) {
      calibWin.minW = 500.0;
      calibWin.SetClosable(true);
      calibWin.SetOverlayOnly(true); // Always hide when closing RedWindows overlay
      if IsDefined(cfg) {
        FootwearWindowsController.ApplySavedGeometry(calibWin, cfg.calibWinX, cfg.calibWinY, cfg.calibWinW, cfg.calibWinH, 500.0, gi);
        if IsDefined(system) {
          system.SetCalibGeoApplied(true);
        };
      };
    };
  }

  /**
   * Initiates the persistent periodic UI update loop via DelaySystem.
   *
   * @param gi Game instance context.
   */
  public static func StartTick(gi: GameInstance) -> Void {
    let cb: ref<FootwearWindowsTick> = new FootwearWindowsTick();
    cb.m_gi = gi;
    GameInstance.GetDelaySystem(gi).DelayCallback(cb, 1.0, false);
  }

  /**
   * Ticks active RedWindows windows and dynamically computes the next polling interval
   * based on user interaction, overlay visibility, and pinned status.
   * Synchronizes window moves and resizing directly to persistent storage.
   *
   * @param gi Game instance context.
   * @return Number of seconds to delay before the subsequent tick.
   */
  public static func Update(gi: GameInstance) -> Float {
    let mgr: ref<RWManager> = RWManager.Get(gi);
    if !IsDefined(mgr) {
      return 1.5;
    };

    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    let cfg: ref<FootwearConfig> = IsDefined(system) ? system.GetConfig() : null;

    let isOverlay: Bool = RedWindowsAPI.IsOverlay(gi);

    let diagWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    let isDiagActive: Bool = false;
    if IsDefined(diagWin) {
      if IsDefined(system) && IsDefined(cfg) && !system.IsDiagGeoApplied() {
        FootwearWindowsController.ApplySavedGeometry(diagWin, cfg.diagWinX, cfg.diagWinY, cfg.diagWinW, cfg.diagWinH, 440.0, gi);
        diagWin.SetOverlayOnly(!cfg.hudPinned);
        system.SetDiagGeoApplied(true);
      };

      if diagWin.IsVisible() {
        if isOverlay || !diagWin.overlayOnly {
          FootwearDiagnosticsHUD.Render(gi, diagWin);
          isDiagActive = true;
        };
      };
    };

    let calibWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    let isCalibActive: Bool = false;
    if IsDefined(calibWin) {
      if IsDefined(system) && IsDefined(cfg) && !system.IsCalibGeoApplied() {
        FootwearWindowsController.ApplySavedGeometry(calibWin, cfg.calibWinX, cfg.calibWinY, cfg.calibWinW, cfg.calibWinH, 500.0, gi);
        calibWin.SetOverlayOnly(true);
        system.SetCalibGeoApplied(true);
      };

      if calibWin.IsVisible() {
        if isOverlay {
          FootwearCalibratorWindow.Render(gi, calibWin);
          isCalibActive = true;
        };
      };
    };

    // Live geometry change detection: sync move & resize to FootwearConfig and RedWindows store
    if IsDefined(cfg) {
      let geoChanged: Bool = false;
      if IsDefined(diagWin) && diagWin.IsVisible() {
        if cfg.diagWinX < 0.0 && diagWin.x > 0.0 {
          cfg.diagWinX = diagWin.x;
          cfg.diagWinY = diagWin.y;
          cfg.diagWinW = diagWin.w;
          cfg.diagWinH = diagWin.userH;
          geoChanged = true;
        } else if AbsF(diagWin.x - cfg.diagWinX) > 1.0 || AbsF(diagWin.y - cfg.diagWinY) > 1.0 || AbsF(diagWin.w - cfg.diagWinW) > 1.0 || AbsF(diagWin.userH - cfg.diagH) > 1.0 {
          cfg.diagWinX = diagWin.x;
          cfg.diagWinY = diagWin.y;
          cfg.diagWinW = diagWin.w;
          cfg.diagWinH = diagWin.userH;
          geoChanged = true;
        };
      };

      if IsDefined(calibWin) && calibWin.IsVisible() {
        if cfg.calibWinX < 0.0 && calibWin.x > 0.0 {
          cfg.calibWinX = calibWin.x;
          cfg.calibWinY = calibWin.y;
          cfg.calibWinW = calibWin.w;
          cfg.calibWinH = calibWin.userH;
          geoChanged = true;
        } else if AbsF(calibWin.x - cfg.calibWinX) > 1.0 || AbsF(calibWin.y - cfg.calibWinY) > 1.0 || AbsF(calibWin.w - cfg.calibWinW) > 1.0 || AbsF(calibWin.userH - cfg.calibH) > 1.0 {
          cfg.calibWinX = calibWin.x;
          cfg.calibWinY = calibWin.y;
          cfg.calibWinW = calibWin.w;
          cfg.calibWinH = calibWin.userH;
          geoChanged = true;
        };
      };

      if geoChanged {
        FootwearStorageManager.GetInstance().SaveConfig(cfg);
        mgr.SaveStore();
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

  /**
   * Forces display and immediate rendering of the diagnostics HUD window.
   *
   * @param gi Game instance context.
   */
  public static func RenderDiagnostics(gi: GameInstance) -> Void {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    if IsDefined(win) {
      win.ShowForced();
      FootwearDiagnosticsHUD.Render(gi, win);
    };
  }

  /**
   * Forces display and immediate rendering of the shoe calibrator window.
   *
   * @param gi Game instance context.
   */
  public static func RenderCalibrator(gi: GameInstance) -> Void {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    if IsDefined(win) {
      win.SetOverlayOnly(true);
      win.ShowForced();
      FootwearCalibratorWindow.Render(gi, win);
    };
  }

  /**
   * Toggles the visibility of the diagnostics HUD window between shown and hidden.
   *
   * @param gi Game instance context.
   */
  public static func ToggleDiagnostics(gi: GameInstance) -> Void {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    if IsDefined(win) {
      if win.IsVisible() {
        FootwearWindowsController.SaveGeometryImmediate(gi);
        win.Hide();
      } else {
        win.ShowForced();
        FootwearDiagnosticsHUD.Render(gi, win);
      };
    };
  }

  /**
   * Toggles the visibility of the shoe calibrator window and opens the RedWindows overlay.
   *
   * @param gi Game instance context.
   */
  public static func ToggleCalibrator(gi: GameInstance) -> Void {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    if IsDefined(win) {
      win.SetOverlayOnly(true);
      if win.IsVisible() && RedWindowsAPI.IsOverlay(gi) {
        FootwearWindowsController.SaveGeometryImmediate(gi);
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
