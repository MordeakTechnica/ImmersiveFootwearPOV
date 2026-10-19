module ImmersiveFootwearPOV

import RedWindows.*
import RedFunctions.*

// =============================================================================
// Immersive Footwear POV - RedWindows UI Integration (Facade & Controller)
// Single Responsibility Principle (SRP):
// Coordinates opening, closing, ticking, and layout geometry of native RedWindows.
// =============================================================================

public class FootwearWindowsTick extends DelayCallback {
  public let m_gi: GameInstance;
  public let m_generation: Int32;

  /**
   * Periodic callback invoked by DelaySystem to tick and render active RedWindows windows.
   */
  public func Call() -> Void {
    let winCtrl: ref<FootwearWindowsController> = FootwearWindowsController.GetInstance(this.m_gi);
    if IsDefined(winCtrl) && this.m_generation != winCtrl.GetTickGeneration() {
      return;
    };
    let nextDelay: Float = FootwearWindowsController.Update(this.m_gi);
    let cb: ref<FootwearWindowsTick> = new FootwearWindowsTick();
    cb.m_gi = this.m_gi;
    cb.m_generation = this.m_generation;
    GameInstance.GetDelaySystem(this.m_gi).DelayCallback(cb, nextDelay, false);
  }
}

public class FootwearWindowsController {
  private let m_calibratorWindow: ref<FootwearCalibratorWindow>;
  private let m_windowsLoopStarted: Bool;
  private let m_diagGeoApplied: Bool;
  private let m_calibGeoApplied: Bool;
  private let m_wasOverlayActive: Bool;
  private let m_tickGeneration: Int32;
  private let m_rwTickCounter: Int32;

  /**
   * Factory method creating a new FootwearWindowsController instance.
   * @return Initialized FootwearWindowsController instance.
   */
  public static func Create() -> ref<FootwearWindowsController> {
    let controller: ref<FootwearWindowsController> = new FootwearWindowsController();
    return controller;
  }

  /**
   * Retrieves the singleton FootwearWindowsController from the game system container.
   * @param gi Game instance context.
   * @return FootwearWindowsController instance or null.
   */
  public static func GetInstance(gi: GameInstance) -> ref<FootwearWindowsController> {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(system) {
      return null;
    };
    return system.GetWindowsController();
  }

  /**
   * Lazily initializes and retrieves the FootwearCalibratorWindow UI.
   * @return The FootwearCalibratorWindow instance.
   */
  public func GetCalibratorWindow() -> ref<FootwearCalibratorWindow> {
    if !IsDefined(this.m_calibratorWindow) {
      this.m_calibratorWindow = FootwearCalibratorWindow.Create();
    };
    return this.m_calibratorWindow;
  }

  /**
   * Checks whether the RedWindows tick loop has already been started.
   * @return True if started.
   */
  public func IsWindowsLoopStarted() -> Bool {
    return this.m_windowsLoopStarted;
  }

  /**
   * Sets the flag indicating whether the RedWindows tick loop is running.
   * @param started True if started.
   */
  public func SetWindowsLoopStarted(started: Bool) -> Void {
    this.m_windowsLoopStarted = started;
  }

  /**
   * Returns the current tick generation token used to invalidate stale DelaySystem loops across session loads.
   */
  public func GetTickGeneration() -> Int32 {
    return this.m_tickGeneration;
  }

  /**
   * Increments and returns the tick generation token.
   */
  public func NextTickGeneration() -> Int32 {
    this.m_tickGeneration += 1;
    return this.m_tickGeneration;
  }

  /**
   * Increments and returns the RedWindows overlay tick throttle counter.
   */
  public func StepRWTickCounter() -> Int32 {
    this.m_rwTickCounter += 1;
    return this.m_rwTickCounter;
  }

  /**
   * Checks whether initial geometry has been applied to the diagnostics window.
   * @return True if applied.
   */
  public func IsDiagGeoApplied() -> Bool {
    return this.m_diagGeoApplied;
  }

  /**
   * Sets the flag indicating whether initial geometry has been applied to the diagnostics window.
   * @param applied True if applied.
   */
  public func SetDiagGeoApplied(applied: Bool) -> Void {
    this.m_diagGeoApplied = applied;
  }

  /**
   * Checks whether initial geometry has been applied to the calibrator window.
   * @return True if applied.
   */
  public func IsCalibGeoApplied() -> Bool {
    return this.m_calibGeoApplied;
  }

  /**
   * Sets the flag indicating whether initial geometry has been applied to the calibrator window.
   * @param applied True if applied.
   */
  public func SetCalibGeoApplied(applied: Bool) -> Void {
    this.m_calibGeoApplied = applied;
  }

  /**
   * Checks whether the RedWindows overlay was active during the preceding tick.
   * @return True if overlay was previously active.
   */
  public func WasOverlayActive() -> Bool {
    return this.m_wasOverlayActive;
  }

  /**
   * Records whether the RedWindows overlay was active during the current tick.
   * @param active True if overlay is active.
   */
  public func SetWasOverlayActive(active: Bool) -> Void {
    this.m_wasOverlayActive = active;
  }

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

    let hasChanged: Bool = false;
    let diagWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    if IsDefined(diagWin) && diagWin.x > 0.0 {
      if AbsF(cfg.diagWinX - diagWin.x) > 1.0 || AbsF(cfg.diagWinY - diagWin.y) > 1.0 || AbsF(cfg.diagWinW - diagWin.w) > 1.0 {
        cfg.diagWinX = diagWin.x;
        cfg.diagWinY = diagWin.y;
        cfg.diagWinW = diagWin.w;
        cfg.diagWinH = diagWin.userH;
        hasChanged = true;
      };
    };

    let calibWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    if IsDefined(calibWin) && calibWin.x > 0.0 {
      if AbsF(cfg.calibWinX - calibWin.x) > 1.0 || AbsF(cfg.calibWinY - calibWin.y) > 1.0 || AbsF(cfg.calibWinW - calibWin.w) > 1.0 {
        cfg.calibWinX = calibWin.x;
        cfg.calibWinY = calibWin.y;
        cfg.calibWinW = calibWin.w;
        cfg.calibWinH = calibWin.userH;
        hasChanged = true;
      };
    };

    if !hasChanged {
      return;
    };

    system.GetStorageManager().SaveConfig(cfg);
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
    let winCtrl: ref<FootwearWindowsController> = IsDefined(system) ? system.GetWindowsController() : null;
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
        if IsDefined(winCtrl) {
          winCtrl.SetDiagGeoApplied(true);
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
        if IsDefined(winCtrl) {
          winCtrl.SetCalibGeoApplied(true);
        };
      };
    };
  }

  /**
   * Initiates or restarts the persistent periodic UI update loop via DelaySystem.
   * Uses a generation counter so stale callbacks from pre-game or previous sessions exit cleanly.
   *
   * @param gi Game instance context.
   */
  public static func StartTick(gi: GameInstance) -> Void {
    let winCtrl: ref<FootwearWindowsController> = FootwearWindowsController.GetInstance(gi);
    let gen: Int32 = 1;
    if IsDefined(winCtrl) {
      winCtrl.SetWindowsLoopStarted(true);
      gen = winCtrl.NextTickGeneration();
    };
    let cb: ref<FootwearWindowsTick> = new FootwearWindowsTick();
    cb.m_gi = gi;
    cb.m_generation = gen;
    GameInstance.GetDelaySystem(gi).DelayCallback(cb, 1.0, false);
  }

  /**
   * Synchronously commits any pending Calibrator inputs and flushes dirty overrides when the RedWindows overlay exits.
   *
   * @param gi Game instance context.
   */
  public static func OnOverlayExited(gi: GameInstance) -> Void {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(system) {
      return;
    };
    let winCtrl: ref<FootwearWindowsController> = system.GetWindowsController();
    if IsDefined(winCtrl) {
      winCtrl.SetWasOverlayActive(false);
    };
    let calibWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    if IsDefined(calibWin) && calibWin.IsVisible() {
      FootwearCalibratorWindow.Render(gi, calibWin);
    };
    system.FlushPendingOverrideSave();
    FootwearWindowsController.SaveGeometryImmediate(gi);
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
      return 3.0;
    };

    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    let winCtrl: ref<FootwearWindowsController> = IsDefined(system) ? system.GetWindowsController() : null;
    let cfg: ref<FootwearConfig> = IsDefined(system) ? system.GetConfig() : null;

    let isOverlay: Bool = RedWindowsAPI.IsOverlay(gi);
    let isHudPinned: Bool = IsDefined(cfg) && cfg.hudPinned;

    // Detect overlay closing: when transitioning from open to closed, persist pending overrides and window geometry ONCE to disk.
    if IsDefined(winCtrl) {
      if winCtrl.WasOverlayActive() && !isOverlay {
        winCtrl.SetWasOverlayActive(false);
        if IsDefined(system) {
          system.FlushPendingOverrideSave();
        };
        FootwearWindowsController.SaveGeometryImmediate(gi);
      } else if isOverlay && !winCtrl.WasOverlayActive() {
        winCtrl.SetWasOverlayActive(true);
      };
    };

    // Fast-path: When RedWindows overlay is closed and HUD is unpinned, skip all window rendering & sync
    if !isOverlay && !isHudPinned {
      return 5.0;
    };

    let diagWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    let isDiagActive: Bool = false;
    if IsDefined(diagWin) {
      if IsDefined(winCtrl) && IsDefined(cfg) && !winCtrl.IsDiagGeoApplied() {
        FootwearWindowsController.ApplySavedGeometry(diagWin, cfg.diagWinX, cfg.diagWinY, cfg.diagWinW, cfg.diagWinH, 440.0, gi);
        diagWin.SetOverlayOnly(!cfg.hudPinned);
        winCtrl.SetDiagGeoApplied(true);
      };

      if diagWin.IsVisible() {
        if isOverlay || !diagWin.overlayOnly {
          FootwearDiagnosticsHUD.Render(gi, diagWin);
          isDiagActive = true;
        };
      };
    };

    let calibWin: ref<RWWindow> = null;
    let isCalibActive: Bool = false;
    // Calibrator is strictly overlay-only; only query and render when overlay is open
    if isOverlay {
      calibWin = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
      if IsDefined(calibWin) {
        if IsDefined(winCtrl) && IsDefined(cfg) && !winCtrl.IsCalibGeoApplied() {
          FootwearWindowsController.ApplySavedGeometry(calibWin, cfg.calibWinX, cfg.calibWinY, cfg.calibWinW, cfg.calibWinH, 500.0, gi);
          calibWin.SetOverlayOnly(true);
          winCtrl.SetCalibGeoApplied(true);
        };

        if calibWin.IsVisible() {
          FootwearCalibratorWindow.Render(gi, calibWin);
          isCalibActive = true;
        };
      };
    };

    // In-memory geometry tracking (ZERO disk I/O): keeps in-RAM FootwearConfig positions in sync while dragging
    if IsDefined(cfg) {
      if IsDefined(diagWin) && diagWin.x > 0.0 {
        cfg.diagWinX = diagWin.x;
        cfg.diagWinY = diagWin.y;
        cfg.diagWinW = diagWin.w;
        if diagWin.userH > 0.0 {
          cfg.diagWinH = diagWin.userH;
        };
      };

      if IsDefined(calibWin) && calibWin.x > 0.0 {
        cfg.calibWinX = calibWin.x;
        cfg.calibWinY = calibWin.y;
        cfg.calibWinW = calibWin.w;
        if calibWin.userH > 0.0 {
          cfg.calibWinH = calibWin.userH;
        };
      };
    };

    // Adaptive tick delay:
    // When RedWindows overlay is actively open and calibrator is being adjusted: 0.15s for smooth slider response
    // When overlay is open without calibrator: 0.25s
    // When only HUD telemetry is pinned: 1.5s (ultra-lightweight, zero hitching)
    // When overlay is closed and nothing is pinned: 3.0s (idle check)
    if isOverlay && isCalibActive {
      return 0.15;
    };
    if isOverlay {
      return 0.25;
    };
    if isDiagActive {
      return 2.5;
    };
    return 5.0;
  }

  /**
   * Forces display and immediate rendering of the diagnostics HUD window.
   *
   * @param gi Game instance context.
   */
  public static func RenderDiagnostics(gi: GameInstance) -> Void {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    if !IsDefined(win) {
      return;
    };
    win.ShowForced();
    FootwearDiagnosticsHUD.Render(gi, win);
  }

  /**
   * Forces display and immediate rendering of the shoe calibrator window.
   *
   * @param gi Game instance context.
   */
  public static func RenderCalibrator(gi: GameInstance) -> Void {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    if !IsDefined(win) {
      return;
    };
    win.SetOverlayOnly(true);
    win.ShowForced();
    FootwearCalibratorWindow.Render(gi, win);
  }

  /**
   * Toggles the visibility of the diagnostics HUD window between shown and hidden.
   *
   * @param gi Game instance context.
   */
  public static func ToggleDiagnostics(gi: GameInstance) -> Void {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    if !IsDefined(win) {
      return;
    };
    if win.IsVisible() {
      FootwearWindowsController.SaveGeometryImmediate(gi);
      win.Hide();
      return;
    };
    win.ShowForced();
    FootwearDiagnosticsHUD.Render(gi, win);
  }

  /**
   * Toggles the visibility of the shoe calibrator window and opens the RedWindows overlay.
   *
   * @param gi Game instance context.
   */
  public static func ToggleCalibrator(gi: GameInstance) -> Void {
    let win: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator");
    if !IsDefined(win) {
      return;
    };
    win.SetOverlayOnly(true);
    if win.IsVisible() && RedWindowsAPI.IsOverlay(gi) {
      let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
      if IsDefined(system) {
        system.FlushPendingOverrideSave();
      };
      FootwearWindowsController.SaveGeometryImmediate(gi);
      win.Hide();
      return;
    };
    win.ShowForced();
    FootwearCalibratorWindow.Render(gi, win);
    let bb: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().UI_System);
    let inMenu: Bool = IsDefined(bb) && bb.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu);
    if !inMenu {
      RedWindowsAPI.OpenFor(gi, win);
    };
  }
}

// -----------------------------------------------------------------------------
// RedWindows Manager Hooks (Responsive Overlay Tick & Immediate Exit Flush)
// -----------------------------------------------------------------------------

@wrapMethod(RWManager)
public func OnTick() -> Void {
  wrappedMethod();
  if this.IsOverlay() {
    let gi: GameInstance = this.GetGameInstance();
    let winCtrl: ref<FootwearWindowsController> = FootwearWindowsController.GetInstance(gi);
    if IsDefined(winCtrl) && (winCtrl.StepRWTickCounter() % 3 == 0) {
      FootwearWindowsController.Update(gi);
    };
  };
}

@wrapMethod(RWManager)
private func ExitOverlay() -> Void {
  let wasOverlay: Bool = this.IsOverlay();
  wrappedMethod();
  if wasOverlay {
    FootwearWindowsController.OnOverlayExited(this.GetGameInstance());
  };
}
