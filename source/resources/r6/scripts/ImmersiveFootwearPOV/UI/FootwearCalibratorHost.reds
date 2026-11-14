module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Unified Calibrator Host & Hotkey Coordinator
// Single source of truth for opening/closing the live shoe calibrator across
// Codeware.UI (primary) and RedWindows (fallback), managing TPP camera unlock,
// input blocking queries, and ITP Focus-Boots framing leases.
// =============================================================================

public class FootwearCalibratorLeaseTick extends DelayCallback {
  public let host: wref<FootwearCalibratorHost>;

  public func Call() -> Void {
    if IsDefined(this.host) {
      this.host.OnLeaseTick();
    };
  }
}

public class FootwearCalibratorReopenTick extends DelayCallback {
  public let host: wref<FootwearCalibratorHost>;

  public func Call() -> Void {
    if IsDefined(this.host) {
      this.host.OnReopenLockedTick();
    };
  }
}

public class FootwearCalibratorHost extends ScriptableSystem {
  private let m_popup: ref<FootwearCalibratorPopup>;
  private let m_hudMirror: ref<FootwearCalibratorHudMirror>;

  private let m_isOpen: Bool;
  private let m_cameraUnlocked: Bool;
  private let m_waitingReopen: Bool;
  private let m_pausedByMenu: Bool;
  private let m_reopenRetries: Int32;
  private let m_leaseTicking: Bool;
  private let m_hotkeyRegistered: Bool;
  private let m_gameplayLockApplied: Bool;

  public static func GetInstance(gi: GameInstance) -> ref<FootwearCalibratorHost> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"ImmersiveFootwearPOV.FootwearCalibratorHost") as FootwearCalibratorHost;
  }

  private func OnDetach() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    this.SetCalibratorGameplayLock(false);
    this.m_isOpen = false;
    this.m_cameraUnlocked = false;
    this.m_waitingReopen = false;
    this.m_pausedByMenu = false;
    this.m_leaseTicking = false;
    this.UnmountHudMirror();
    FootwearCalibratorCamera.Disengage(gi, true);
    ITPController.ReleaseCalibratorTPPLease(gi);
  }

  public static func Init(gi: GameInstance) -> Void {
    let host: ref<FootwearCalibratorHost> = FootwearCalibratorHost.GetInstance(gi);
    if !IsDefined(host) {
      return;
    };
    host.EnsureHotkeyRegistered();
  }

  public static func ToggleCalibrator(gi: GameInstance) -> Void {
    if !FootwearDVEnvironment.HasCodewareUI() {
      FootwearWindowsController.ToggleCalibrator(gi);
      return;
    };
    let host: ref<FootwearCalibratorHost> = FootwearCalibratorHost.GetInstance(gi);
    if !IsDefined(host) {
      return;
    };
    host.ToggleInstance();
  }

  public static func OpenCalibrator(gi: GameInstance) -> Void {
    if !FootwearDVEnvironment.HasCodewareUI() {
      if !FootwearWindowsController.IsCalibratorOpen(gi) {
        FootwearWindowsController.ToggleCalibrator(gi);
      };
      return;
    };
    let host: ref<FootwearCalibratorHost> = FootwearCalibratorHost.GetInstance(gi);
    if IsDefined(host) && !host.IsOpen() {
      host.OpenInstance();
    };
  }

  public static func CloseCalibrator(gi: GameInstance) -> Void {
    let host: ref<FootwearCalibratorHost> = FootwearCalibratorHost.GetInstance(gi);
    if IsDefined(host) && host.IsOpen() {
      host.CloseCalibrator();
    };
    if FootwearWindowsController.IsCalibratorOpen(gi) {
      FootwearWindowsController.CloseCalibrator(gi);
    };
  }

  public static func IsCalibratorOpen(gi: GameInstance) -> Bool {
    if FootwearWindowsController.IsCalibratorOpen(gi) {
      return true;
    };
    let host: ref<FootwearCalibratorHost> = FootwearCalibratorHost.GetInstance(gi);
    return IsDefined(host) && host.IsOpen();
  }

  public static func IsCameraInputBlocked(gi: GameInstance) -> Bool {
    if FootwearWindowsController.IsCalibratorOpen(gi) {
      return true;
    };
    let host: ref<FootwearCalibratorHost> = FootwearCalibratorHost.GetInstance(gi);
    return IsDefined(host) && host.IsOpen() && !host.IsCameraUnlocked();
  }

  public static func ShouldConsumeUnlockCrouch(gi: GameInstance) -> Bool {
    let host: ref<FootwearCalibratorHost> = FootwearCalibratorHost.GetInstance(gi);
    if !IsDefined(host) || !host.IsOpen() {
      return false;
    };
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) && player.PlayerLastUsedPad() && host.IsCameraUnlocked() {
      return false;
    };
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(sys) {
      return false;
    };
    let cfg: ref<FootwearConfig> = sys.GetConfig();
    return IsDefined(cfg) && cfg.cameraUnlockKey == EnumInt(EInputKey.IK_C);
  }

  public static func ShouldConsumeUnlockQuickMelee(gi: GameInstance) -> Bool {
    let host: ref<FootwearCalibratorHost> = FootwearCalibratorHost.GetInstance(gi);
    if !IsDefined(host) || !host.IsOpen() || host.IsInPauseOrGameMenu(gi) {
      return false;
    };
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject() as PlayerPuppet;
    return IsDefined(player) && player.PlayerLastUsedPad();
  }

  public static func OnFootwearUpdated(gi: GameInstance) -> Void {
    let host: ref<FootwearCalibratorHost> = FootwearCalibratorHost.GetInstance(gi);
    if IsDefined(host) && host.IsOpen() {
      host.RefreshCodewareUI(true);
    };
  }

  public func IsOpen() -> Bool {
    return this.m_isOpen;
  }

  public func IsCameraUnlocked() -> Bool {
    return this.m_cameraUnlocked;
  }

  public func ToggleInstance() -> Void {
    if this.m_isOpen {
      this.CloseCalibrator();
    } else {
      this.OpenInstance();
    };
  }

  public func OpenInstance() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    if GameInstance.GetSystemRequestsHandler().IsPreGame() {
      return;
    };
    this.m_isOpen = true;
    this.m_cameraUnlocked = false;
    this.m_waitingReopen = false;
    this.m_pausedByMenu = false;

    if !this.OpenCodewarePopup() {
      this.m_isOpen = false;
      this.SetCalibratorGameplayLock(false);
      return;
    };

    this.SetCalibratorGameplayLock(true);
    this.ApplyTPPLeaseNow();
    FootwearCalibratorCamera.Engage(gi, this.ShouldFocusBoots(gi), false);
    this.ScheduleLeaseTick();
  }

  public func CloseCalibrator() -> Void {
    if !this.m_isOpen {
      this.SetCalibratorGameplayLock(false);
      return;
    };
    let gi: GameInstance = this.GetGameInstance();
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if IsDefined(sys) && sys.HasDirtyOverride() {
      sys.FlushPendingOverrideSave();
    };

    this.m_isOpen = false;
    this.m_cameraUnlocked = false;
    this.m_waitingReopen = false;
    this.m_pausedByMenu = false;

    this.SetCalibratorGameplayLock(false);
    this.UnmountHudMirror();
    this.CloseCodewarePopup();
    FootwearCalibratorCamera.Disengage(gi, true);
    ITPController.ReleaseCalibratorTPPLease(gi);
  }

  public func ToggleCameraLock() -> Void {
    if !this.m_isOpen {
      return;
    };
    let gi: GameInstance = this.GetGameInstance();
    if this.m_cameraUnlocked {
      // Lock cursor back to UI and preserve the player's newly orbited angle
      this.m_cameraUnlocked = false;
      this.m_waitingReopen = true;
      this.m_reopenRetries = 0;
      this.SetCalibratorGameplayLock(true);
      FootwearCalibratorCamera.Engage(gi, this.ShouldFocusBoots(gi), true);
      this.OnReopenLockedTick();
    } else {
      // Unlock camera while keeping lightweight left HUD card visible
      this.m_cameraUnlocked = true;
      this.m_waitingReopen = false;
      this.SetCalibratorGameplayLock(false);
      FootwearCalibratorCamera.Disengage(gi, false);
      this.MountHudMirror();
      this.CloseCodewarePopupForUnlock();
    };
  }

  public func OnPopupAttached(popup: ref<FootwearCalibratorPopup>) -> Void {
    if !this.m_isOpen || this.m_cameraUnlocked {
      return;
    };
    this.SetCalibratorGameplayLock(true);
    this.UnmountHudMirror();
    this.RefreshCodewareUI(true);
  }

  public func OnPopupHiding(popup: ref<FootwearCalibratorPopup>, forUnlock: Bool) -> Void {
    if !Equals(this.m_popup, popup) {
      return;
    };
    if forUnlock {
      return;
    };
    if this.m_isOpen && !this.m_cameraUnlocked {
      // Popup closed externally (e.g., by menu or pause) -> perform full clean shutdown.
      let gi: GameInstance = this.GetGameInstance();
      let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
      if IsDefined(sys) && sys.HasDirtyOverride() {
        sys.FlushPendingOverrideSave();
      };
      this.m_isOpen = false;
      this.m_waitingReopen = false;
      this.m_pausedByMenu = false;
      this.SetCalibratorGameplayLock(false);
      FootwearCalibratorCamera.Disengage(gi, true);
      ITPController.ReleaseCalibratorTPPLease(gi);
    };
  }

  public func OnPopupHidden(popup: ref<FootwearCalibratorPopup>) -> Void {
    if Equals(this.m_popup, popup) {
      this.m_popup = null;
    };
    if this.m_isOpen && !this.m_cameraUnlocked && this.m_waitingReopen {
      this.OnReopenLockedTick();
    };
  }

  public func OnLeaseTick() -> Void {
    this.m_leaseTicking = false;
    if !this.m_isOpen {
      return;
    };

    let gi: GameInstance = this.GetGameInstance();
    if GameInstance.GetSystemRequestsHandler().IsPreGame() {
      this.CloseCalibrator();
      return;
    };

    if this.IsInPauseOrGameMenu(gi) {
      if !this.m_pausedByMenu {
        this.m_pausedByMenu = true;
        FootwearCalibratorCamera.Disengage(gi, false);
      };
      this.SetCalibratorGameplayLock(false);
      if this.m_cameraUnlocked {
        this.UnmountHudMirror();
      };
      this.ScheduleLeaseTick();
      return;
    };

    if this.m_pausedByMenu {
      this.m_pausedByMenu = false;
      if !this.m_cameraUnlocked {
        FootwearCalibratorCamera.Engage(gi, this.ShouldFocusBoots(gi), true);
      };
    };

    if this.m_cameraUnlocked {
      this.SetCalibratorGameplayLock(false);
      this.MountHudMirror();
    } else {
      this.SetCalibratorGameplayLock(true);
    };

    this.ApplyTPPLeaseNow();
    this.ScheduleLeaseTick();
  }

  public func OnReopenLockedTick() -> Void {
    if !this.m_isOpen || this.m_cameraUnlocked || !this.m_waitingReopen {
      return;
    };

    if IsDefined(this.m_popup) && !this.IsPopupFinishedHidden(this.m_popup) {
      if this.m_reopenRetries < 12 {
        this.m_reopenRetries += 1;
        let cb: ref<FootwearCalibratorReopenTick> = new FootwearCalibratorReopenTick();
        cb.host = this;
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, 0.05);
      };
      return;
    };

    this.m_waitingReopen = false;
    this.m_popup = null;
    this.OpenCodewarePopup();
  }

  private func ShouldFocusBoots(gi: GameInstance) -> Bool {
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(sys) {
      return true;
    };
    let cfg: ref<FootwearConfig> = sys.GetConfig();
    return IsDefined(cfg) ? cfg.focusBootsInTPP : true;
  }

  private func ApplyTPPLeaseNow() -> Void {
    let gi: GameInstance = this.GetGameInstance();
    ITPController.MaintainCalibratorTPPLease(gi, this.ShouldFocusBoots(gi));
  }

  private func ScheduleLeaseTick() -> Void {
    if this.m_leaseTicking || !this.m_isOpen {
      return;
    };
    this.m_leaseTicking = true;
    let cb: ref<FootwearCalibratorLeaseTick> = new FootwearCalibratorLeaseTick();
    cb.host = this;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, 0.40);
  }

  private func IsInPauseOrGameMenu(gi: GameInstance) -> Bool {
    let bb: ref<IBlackboard> = GameInstance.GetBlackboardSystem(gi).Get(GetAllBlackboardDefs().UI_System);
    return IsDefined(bb) && bb.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu);
  }

  private func SetCalibratorGameplayLock(locked: Bool) -> Void {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if locked {
      if IsDefined(player) {
        if !StatusEffectSystem.ObjectHasStatusEffect(player, t"GameplayRestriction.NoCameraControl") {
          StatusEffectHelper.ApplyStatusEffect(player, t"GameplayRestriction.NoCameraControl");
        };
        if !StatusEffectSystem.ObjectHasStatusEffect(player, t"GameplayRestriction.NoMovement") {
          StatusEffectHelper.ApplyStatusEffect(player, t"GameplayRestriction.NoMovement");
        };
        this.m_gameplayLockApplied = true;
      };
    } else if this.m_gameplayLockApplied {
      if IsDefined(player) {
        StatusEffectHelper.RemoveStatusEffect(player, t"GameplayRestriction.NoCameraControl");
        StatusEffectHelper.RemoveStatusEffect(player, t"GameplayRestriction.NoMovement");
      };
      this.m_gameplayLockApplied = false;
    };
  }

  // ---------------------------------------------------------------------------
  // Global Input/Key Listener (Guarded by Codeware)
  // ---------------------------------------------------------------------------

  @if(ModuleExists("Codeware"))
  private func EnsureHotkeyRegistered() -> Void {
    if this.m_hotkeyRegistered {
      return;
    };
    this.m_hotkeyRegistered = true;
    GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnGlobalKey", true);
  }

  @if(!ModuleExists("Codeware"))
  private func EnsureHotkeyRegistered() -> Void {
  }

  @if(ModuleExists("Codeware"))
  protected cb func OnGlobalKey(event: ref<KeyInputEvent>) -> Void {
    if !Equals(event.GetAction(), EInputAction.IACT_Press) {
      return;
    };
    let gi: GameInstance = this.GetGameInstance();
    if GameInstance.GetSystemRequestsHandler().IsPreGame() {
      return;
    };

    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(sys) {
      return;
    };
    let cfg: ref<FootwearConfig> = sys.GetConfig();
    if !IsDefined(cfg) {
      return;
    };

    let key: Int32 = EnumInt(event.GetKey());

    // While Codeware calibrator is open, handle Escape / Toggle / Camera Unlock
    if this.m_isOpen {
      if this.m_cameraUnlocked {
        if this.IsInPauseOrGameMenu(gi) {
          return;
        };
        if key == EnumInt(EInputKey.IK_Pad_RightThumb) {
          this.ToggleCameraLock();
          return;
        };
        if cfg.calibratorHotkey > 0 && key == cfg.calibratorHotkey {
          this.CloseCalibrator();
          return;
        };
        if cfg.cameraUnlockKey > 0 && key == cfg.cameraUnlockKey {
          this.ToggleCameraLock();
          return;
        };
        return;
      };

      // UI Locked mode: ensure our popup is actually top-most before intercepting keys
      if !this.IsPopupOnTop(this.m_popup) {
        return;
      };
      if key == EnumInt(EInputKey.IK_Escape) || key == EnumInt(EInputKey.IK_Pad_B_CIRCLE) || (cfg.calibratorHotkey > 0 && key == cfg.calibratorHotkey) {
        this.CloseCalibrator();
        return;
      };
      if key == EnumInt(EInputKey.IK_Pad_RightThumb) && !this.IsInPauseOrGameMenu(gi) {
        this.ToggleCameraLock();
        return;
      };
      if cfg.cameraUnlockKey > 0 && key == cfg.cameraUnlockKey {
        this.ToggleCameraLock();
        return;
      };
      return;
    };

    // Calibrator closed -> open on calibratorHotkey outside menus (and outside RedWindows overlay)
    if cfg.calibratorHotkey <= 0 || key != cfg.calibratorHotkey {
      return;
    };
    if this.IsInPauseOrGameMenu(gi) || FootwearRCFProvider.IsHubOpen(gi) {
      return;
    };
    if !FootwearDVEnvironment.HasCodewareUI() && FootwearWindowsController.IsCalibratorOpen(gi) {
      FootwearWindowsController.CloseCalibrator(gi);
      return;
    };
    FootwearCalibratorHost.ToggleCalibrator(gi);
  }

  // ---------------------------------------------------------------------------
  // Codeware.UI Popup & HUD Mirror Operations (Soft-Guarded)
  // ---------------------------------------------------------------------------

  @if(ModuleExists("Codeware.UI"))
  private func OpenCodewarePopup() -> Bool {
    let inkSys: ref<inkSystem> = GameInstance.GetInkSystem();
    if !IsDefined(inkSys) {
      return false;
    };
    let hudLayer: ref<inkLayerWrapper> = inkSys.GetLayer(n"inkHUDLayer");
    if !IsDefined(hudLayer) {
      return false;
    };
    let ctrl: wref<inkGameController> = hudLayer.GetGameController() as inkGameController;
    if !IsDefined(ctrl) {
      return false;
    };
    let popup: ref<FootwearCalibratorPopup> = FootwearCalibratorPopup.Create(this);
    this.m_popup = popup;
    popup.Open(ctrl);
    return true;
  }

  @if(!ModuleExists("Codeware.UI"))
  private func OpenCodewarePopup() -> Bool {
    return false;
  }

  @if(ModuleExists("Codeware.UI"))
  private func CloseCodewarePopup() -> Void {
    if IsDefined(this.m_popup) {
      this.m_popup.Close();
    };
  }

  @if(!ModuleExists("Codeware.UI"))
  private func CloseCodewarePopup() -> Void {
  }

  @if(ModuleExists("Codeware.UI"))
  private func CloseCodewarePopupForUnlock() -> Void {
    if IsDefined(this.m_popup) {
      this.m_popup.CloseForUnlock();
    };
  }

  @if(!ModuleExists("Codeware.UI"))
  private func CloseCodewarePopupForUnlock() -> Void {
  }

  @if(ModuleExists("Codeware.UI"))
  private func IsPopupFinishedHidden(popup: ref<FootwearCalibratorPopup>) -> Bool {
    return !IsDefined(popup) || popup.IsFinishedHidden();
  }

  @if(!ModuleExists("Codeware.UI"))
  private func IsPopupFinishedHidden(popup: ref<FootwearCalibratorPopup>) -> Bool {
    return true;
  }

  @if(ModuleExists("Codeware.UI"))
  private func IsPopupOnTop(popup: ref<FootwearCalibratorPopup>) -> Bool {
    return IsDefined(popup) && popup.IsTopPopup();
  }

  @if(!ModuleExists("Codeware.UI"))
  private func IsPopupOnTop(popup: ref<FootwearCalibratorPopup>) -> Bool {
    return false;
  }

  @if(ModuleExists("Codeware.UI"))
  private func MountHudMirror() -> Void {
    if !IsDefined(this.m_hudMirror) {
      this.m_hudMirror = new FootwearCalibratorHudMirror();
    };
    this.m_hudMirror.Mount(this.GetGameInstance());
  }

  @if(!ModuleExists("Codeware.UI"))
  private func MountHudMirror() -> Void {
  }

  @if(ModuleExists("Codeware.UI"))
  private func UnmountHudMirror() -> Void {
    if IsDefined(this.m_hudMirror) {
      this.m_hudMirror.Unmount();
      this.m_hudMirror = null;
    };
  }

  @if(!ModuleExists("Codeware.UI"))
  private func UnmountHudMirror() -> Void {
  }

  @if(ModuleExists("Codeware.UI"))
  private func RefreshCodewareUI(forceAxes: Bool) -> Void {
    if this.m_cameraUnlocked {
      if IsDefined(this.m_hudMirror) {
        this.m_hudMirror.Refresh(this.GetGameInstance());
      };
      return;
    };
    if IsDefined(this.m_popup) {
      this.m_popup.RefreshFromSystem(forceAxes);
    };
  }

  @if(!ModuleExists("Codeware.UI"))
  private func RefreshCodewareUI(forceAxes: Bool) -> Void {
  }
}
