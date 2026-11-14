module ImmersiveFootwearPOV

@if(ModuleExists("RedWindows"))
import RedWindows.*
@if(ModuleExists("RedFunctions"))
import RedFunctions.*

// =============================================================================
// Immersive Footwear POV - RedWindows UI Integration
// Single Responsibility Principle (SRP):
// Coordinates opening, closing, ticking, and layout geometry of native RedWindows
// via uniform FootwearWindowBinding descriptors.
// =============================================================================

public enum FootwearWindowKind {
  Diagnostics = 0,
  Calibrator = 1
}

@if(ModuleExists("RedWindows"))
public class FootwearWindowsTick extends DelayCallback {
  public let m_gi: GameInstance;
  public let m_generation: Int32;

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

@if(ModuleExists("RedWindows"))
public class FootwearWindowBinding {
  public let kind: FootwearWindowKind;
  public let winId: CName;
  public let title: String;
  public let minW: Float;
  public let alwaysOverlayOnly: Bool;
  public let geoApplied: Bool;

  public static func Create(kind: FootwearWindowKind, winId: CName, title: String, minW: Float, alwaysOverlayOnly: Bool) -> ref<FootwearWindowBinding> {
    let b: ref<FootwearWindowBinding> = new FootwearWindowBinding();
    b.kind = kind;
    b.winId = winId;
    b.title = title;
    b.minW = minW;
    b.alwaysOverlayOnly = alwaysOverlayOnly;
    return b;
  }

  public func ResolveWindow(gi: GameInstance) -> ref<RWWindow> {
    return RedWindowsAPI.Window(gi, this.winId, this.title);
  }

  public func RenderContent(gi: GameInstance, win: ref<RWWindow>) -> Void {
    if Equals(this.kind, FootwearWindowKind.Diagnostics) {
      FootwearDiagnosticsHUD.Render(gi, win);
    } else {
      FootwearCalibratorWindow.Render(gi, win);
    };
  }

  public func ApplyOverlayRule(win: ref<RWWindow>, cfg: ref<FootwearConfig>) -> Void {
    if !IsDefined(win) {
      return;
    };
    if this.alwaysOverlayOnly {
      win.SetOverlayOnly(true);
    } else if IsDefined(cfg) {
      win.SetOverlayOnly(!cfg.hudPinned);
    };
  }

  public func EnsureGeometry(gi: GameInstance, win: ref<RWWindow>, cfg: ref<FootwearConfig>) -> Void {
    if !IsDefined(win) || !IsDefined(cfg) || this.geoApplied {
      return;
    };
    let x: Float = Equals(this.kind, FootwearWindowKind.Diagnostics) ? cfg.diagWinX : cfg.calibWinX;
    let y: Float = Equals(this.kind, FootwearWindowKind.Diagnostics) ? cfg.diagWinY : cfg.calibWinY;
    let w: Float = Equals(this.kind, FootwearWindowKind.Diagnostics) ? cfg.diagWinW : cfg.calibWinW;
    let h: Float = Equals(this.kind, FootwearWindowKind.Diagnostics) ? cfg.diagWinH : cfg.calibWinH;
    FootwearWindowsController.ApplySavedGeometry(win, x, y, w, h, this.minW, gi);
    this.geoApplied = true;
  }

  public func SyncToConfig(win: ref<RWWindow>, cfg: ref<FootwearConfig>, checkDelta: Bool) -> Bool {
    if !IsDefined(win) || !IsDefined(cfg) || win.x <= 0.0 {
      return false;
    };
    if Equals(this.kind, FootwearWindowKind.Diagnostics) {
      if checkDelta && AbsF(cfg.diagWinX - win.x) <= 1.0 && AbsF(cfg.diagWinY - win.y) <= 1.0 && AbsF(cfg.diagWinW - win.w) <= 1.0 {
        return false;
      };
      cfg.diagWinX = win.x;
      cfg.diagWinY = win.y;
      cfg.diagWinW = win.w;
      if win.userH > 0.0 { cfg.diagWinH = win.userH; };
      return true;
    };
    if checkDelta && AbsF(cfg.calibWinX - win.x) <= 1.0 && AbsF(cfg.calibWinY - win.y) <= 1.0 && AbsF(cfg.calibWinW - win.w) <= 1.0 {
      return false;
    };
    cfg.calibWinX = win.x;
    cfg.calibWinY = win.y;
    cfg.calibWinW = win.w;
    if win.userH > 0.0 { cfg.calibWinH = win.userH; };
    return true;
  }
}

@if(ModuleExists("RedWindows"))
public class FootwearWindowsController {
  private let m_calibratorWindow: ref<FootwearCalibratorWindow>;
  private let m_bindings: array<ref<FootwearWindowBinding>>;
  private let m_wasOverlayActive: Bool;
  private let m_tickGeneration: Int32;

  public static func Create() -> ref<FootwearWindowsController> {
    let controller: ref<FootwearWindowsController> = new FootwearWindowsController();
    ArrayPush(controller.m_bindings, FootwearWindowBinding.Create(FootwearWindowKind.Diagnostics, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics", 440.0, false));
    ArrayPush(controller.m_bindings, FootwearWindowBinding.Create(FootwearWindowKind.Calibrator, n"IFP_Calibrator", "Immersive Footwear POV — Shoe Calibrator", 500.0, true));
    return controller;
  }

  public static func GetInstance(gi: GameInstance) -> ref<FootwearWindowsController> {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    return IsDefined(system) ? system.GetWindowsController() : null;
  }

  public func GetCalibratorWindow() -> ref<FootwearCalibratorWindow> {
    if !IsDefined(this.m_calibratorWindow) {
      this.m_calibratorWindow = FootwearCalibratorWindow.Create();
    };
    return this.m_calibratorWindow;
  }

  public func GetTickGeneration() -> Int32 {
    return this.m_tickGeneration;
  }

  public func NextTickGeneration() -> Int32 {
    this.m_tickGeneration += 1;
    return this.m_tickGeneration;
  }

  public func WasOverlayActive() -> Bool {
    return this.m_wasOverlayActive;
  }

  public func SetWasOverlayActive(active: Bool) -> Void {
    this.m_wasOverlayActive = active;
  }

  private func GetBinding(kind: FootwearWindowKind) -> ref<FootwearWindowBinding> {
    let i: Int32 = 0;
    while i < ArraySize(this.m_bindings) {
      if Equals(this.m_bindings[i].kind, kind) {
        return this.m_bindings[i];
      };
      i += 1;
    };
    return null;
  }

  /**
   * Applies persistently saved window coordinates and dimensions to an active RedWindows window,
   * clamping positions to visible screen boundaries.
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

  public static func SaveGeometryImmediate(gi: GameInstance) -> Void {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(system) {
      return;
    };
    let winCtrl: ref<FootwearWindowsController> = system.GetWindowsController();
    let cfg: ref<FootwearConfig> = system.GetConfig();
    if !IsDefined(winCtrl) || !IsDefined(cfg) {
      return;
    };

    let hasChanged: Bool = false;
    let i: Int32 = 0;
    while i < ArraySize(winCtrl.m_bindings) {
      let binding: ref<FootwearWindowBinding> = winCtrl.m_bindings[i];
      let win: ref<RWWindow> = binding.ResolveWindow(gi);
      if binding.SyncToConfig(win, cfg, true) {
        hasChanged = true;
      };
      i += 1;
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

  public static func Init(gi: GameInstance) -> Void {
    let mgr: ref<RWManager> = RWManager.Get(gi);
    if !IsDefined(mgr) {
      return;
    };

    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    let winCtrl: ref<FootwearWindowsController> = IsDefined(system) ? system.GetWindowsController() : null;
    if !IsDefined(winCtrl) {
      return;
    };
    let cfg: ref<FootwearConfig> = system.GetConfig();

    let i: Int32 = 0;
    while i < ArraySize(winCtrl.m_bindings) {
      let binding: ref<FootwearWindowBinding> = winCtrl.m_bindings[i];
      let win: ref<RWWindow> = binding.ResolveWindow(gi);
      if IsDefined(win) {
        win.minW = binding.minW;
        win.SetClosable(true);
        binding.ApplyOverlayRule(win, cfg);
        if !binding.alwaysOverlayOnly && IsDefined(cfg) && cfg.hudPinned {
          win.Show();
        };
        binding.EnsureGeometry(gi, win, cfg);
      };
      i += 1;
    };
  }

  public static func StartTick(gi: GameInstance) -> Void {
    let winCtrl: ref<FootwearWindowsController> = FootwearWindowsController.GetInstance(gi);
    let gen: Int32 = IsDefined(winCtrl) ? winCtrl.NextTickGeneration() : 1;
    let cb: ref<FootwearWindowsTick> = new FootwearWindowsTick();
    cb.m_gi = gi;
    cb.m_generation = gen;
    GameInstance.GetDelaySystem(gi).DelayCallback(cb, 1.0, false);
  }

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

    if IsDefined(winCtrl) {
      if winCtrl.WasOverlayActive() && !isOverlay {
        FootwearWindowsController.OnOverlayExited(gi);
      } else if isOverlay && !winCtrl.WasOverlayActive() {
        winCtrl.SetWasOverlayActive(true);
      };
    };

    if !isOverlay && !isHudPinned {
      return 5.0;
    };

    let isDiagActive: Bool = false;
    let isCalibActive: Bool = false;
    if IsDefined(winCtrl) {
      let i: Int32 = 0;
      while i < ArraySize(winCtrl.m_bindings) {
        let binding: ref<FootwearWindowBinding> = winCtrl.m_bindings[i];
        if !binding.alwaysOverlayOnly || isOverlay {
          let win: ref<RWWindow> = binding.ResolveWindow(gi);
          if IsDefined(win) {
            if !binding.geoApplied && IsDefined(cfg) {
              binding.EnsureGeometry(gi, win, cfg);
              binding.ApplyOverlayRule(win, cfg);
            };
            if win.IsVisible() && (isOverlay || !win.overlayOnly) {
              binding.RenderContent(gi, win);
              if Equals(binding.kind, FootwearWindowKind.Diagnostics) {
                isDiagActive = true;
              } else {
                isCalibActive = true;
              };
            };
            binding.SyncToConfig(win, cfg, false);
          };
        };
        i += 1;
      };
    };

    if isOverlay && isCalibActive { return 0.15; };
    if isOverlay { return 0.25; };
    if isDiagActive { return 2.5; };
    return 5.0;
  }

  private static func ToggleWindow(gi: GameInstance, kind: FootwearWindowKind) -> Void {
    let winCtrl: ref<FootwearWindowsController> = FootwearWindowsController.GetInstance(gi);
    let binding: ref<FootwearWindowBinding> = IsDefined(winCtrl) ? winCtrl.GetBinding(kind) : null;
    if !IsDefined(binding) {
      return;
    };
    let win: ref<RWWindow> = binding.ResolveWindow(gi);
    if !IsDefined(win) {
      return;
    };

    if binding.alwaysOverlayOnly {
      win.SetOverlayOnly(true);
    };

    let shouldHide: Bool = binding.alwaysOverlayOnly ? (win.IsVisible() && RedWindowsAPI.IsOverlay(gi)) : win.IsVisible();
    if shouldHide {
      if Equals(kind, FootwearWindowKind.Calibrator) {
        let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
        if IsDefined(system) {
          system.FlushPendingOverrideSave();
        };
      };
      FootwearWindowsController.SaveGeometryImmediate(gi);
      win.Hide();
      return;
    };

    win.ShowForced();
    binding.RenderContent(gi, win);

    if Equals(kind, FootwearWindowKind.Calibrator) {
      let bb: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().UI_System);
      let inMenu: Bool = IsDefined(bb) && bb.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu);
      if !inMenu {
        RedWindowsAPI.OpenFor(gi, win);
      };
    };
  }

  public static func ToggleDiagnostics(gi: GameInstance) -> Void {
    FootwearWindowsController.ToggleWindow(gi, FootwearWindowKind.Diagnostics);
  }

  public static func ToggleCalibrator(gi: GameInstance) -> Void {
    FootwearWindowsController.ToggleWindow(gi, FootwearWindowKind.Calibrator);
  }

  /**
   * Synchronizes the pinned HUD state for the Diagnostics window without exposing RedWindowsAPI to callers.
   */
  public static func SetDiagnosticsPinned(gi: GameInstance, pinned: Bool) -> Void {
    let diagWin: ref<RWWindow> = RedWindowsAPI.Window(gi, n"IFP_Diagnostics", "Immersive Footwear POV — Diagnostics");
    if !IsDefined(diagWin) {
      return;
    };
    diagWin.SetOverlayOnly(!pinned);
    diagWin.SetBoolValue(n"ifp_diag_pin", pinned);
    if pinned {
      diagWin.Show();
    };
  }
}

// -----------------------------------------------------------------------------
// Fallback Stub (when RedWindows is NOT installed)
// -----------------------------------------------------------------------------
@if(!ModuleExists("RedWindows"))
public class FootwearWindowsController {
  private let m_calibratorWindow: ref<FootwearCalibratorWindow>;

  public static func Create() -> ref<FootwearWindowsController> {
    let controller: ref<FootwearWindowsController> = new FootwearWindowsController();
    controller.m_calibratorWindow = FootwearCalibratorWindow.Create();
    return controller;
  }

  public static func GetInstance(gi: GameInstance) -> ref<FootwearWindowsController> {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    return IsDefined(system) ? system.GetWindowsController() : null;
  }

  public static func Init(gi: GameInstance) -> Void {}
  public static func StartTick(gi: GameInstance) -> Void {}
  public static func Update(gi: GameInstance) -> Float { return 5.0; }
  public static func OnOverlayExited(gi: GameInstance) -> Void {}
  public static func ToggleDiagnostics(gi: GameInstance) -> Void {}
  public static func ToggleCalibrator(gi: GameInstance) -> Void {}
  public static func SaveGeometryImmediate(gi: GameInstance) -> Void {}
  public static func SetDiagnosticsPinned(gi: GameInstance, pinned: Bool) -> Void {}

  public func GetCalibratorWindow() -> ref<FootwearCalibratorWindow> { return this.m_calibratorWindow; }
  public func WasOverlayActive() -> Bool { return false; }
}
