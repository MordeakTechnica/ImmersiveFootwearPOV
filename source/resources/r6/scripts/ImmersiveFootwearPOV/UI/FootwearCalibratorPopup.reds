module ImmersiveFootwearPOV

@if(ModuleExists("Codeware.UI"))
import Codeware.UI.*

// =============================================================================
// Immersive Footwear POV - Native InGamePopup Calibrator (Codeware Primary)
// Left-docked, zero-blur, non-pausing Cyberpunk popup with immediate live
// slider & preset updates on V's character model.
// =============================================================================

@if(ModuleExists("Codeware.UI"))
public class FootwearCalibratorPopup extends InGamePopup {
  private let m_host: wref<FootwearCalibratorHost>;
  private let m_closingForUnlock: Bool;
  private let m_hiddenDone: Bool;
  private let m_uiContextPushed: Bool;
  private let m_closeOnInit: Bool;

  private let m_panel: ref<inkCanvas>;
  private let m_shoeTitle: ref<inkText>;
  private let m_shoeSub: ref<inkText>;
  private let m_controlsGroup: ref<inkCanvas>;
  private let m_emptyGroup: ref<inkCanvas>;

  private let m_btnUnlockCam: ref<FootwearPillButton>;
  private let m_btnFocusBoots: ref<FootwearPillButton>;
  private let m_btnSave: ref<FootwearPillButton>;
  private let m_btnRevert: ref<FootwearPillButton>;
  private let m_btnClose: ref<FootwearPillButton>;
  private let m_btnEmptyClose: ref<FootwearPillButton>;
  private let m_ownedButtons: array<ref<FootwearPillButton>>;

  private let m_heelAxis: ref<FootwearSliderAxis>;
  private let m_platAxis: ref<FootwearSliderAxis>;

  private let m_presetBtns: array<ref<FootwearPillButton>>;
  private let m_presetCm: array<Float>;

  private let m_teleLift: ref<inkText>;
  private let m_telePersp: ref<inkText>;
  private let m_teleStatus: ref<inkText>;
  private let m_hintText: ref<inkText>;

  private let m_lastShoeKey: String;
  private let m_isApplyingAxis: Bool;

  public static func Create(host: wref<FootwearCalibratorHost>) -> ref<FootwearCalibratorPopup> {
    let popup: ref<FootwearCalibratorPopup> = new FootwearCalibratorPopup();
    popup.m_host = host;
    return popup;
  }

  public func GetQueueName() -> CName {
    return n"footwear_calibrator";
  }

  public func UseCursor() -> Bool {
    return true;
  }

  public func IsFinishedHidden() -> Bool {
    return this.m_hiddenDone;
  }

  public func IsInputFocused() -> Bool {
    return (IsDefined(this.m_heelAxis) && this.m_heelAxis.IsInputFocused())
      || (IsDefined(this.m_platAxis) && this.m_platAxis.IsInputFocused());
  }

  public func CloseForUnlock() -> Void {
    this.m_closingForUnlock = true;
    this.ResetUIContext();
    if !this.IsInitialized() {
      this.m_closeOnInit = true;
      return;
    };
    this.Close();
  }

  protected func CreateVignette() -> Void {
    // Keep live world & character unobstructed (no fullscreen dim/vignette).
  }

  protected func SetTimeDilation() -> Void {
    // Keep animation & physics live while calibrating.
  }

  protected func ResetTimeDilation() -> Void {
  }

  protected func SetBackgroundBlur() -> Void {
    // Keep V's boots razor-sharp in the viewport.
  }

  protected func ResetBackgroundBlur() -> Void {
  }

  // Only push UIGameContext.ModalPopup (blocks gameplay actions & enables UI cursor).
  // Omit RequestNewVisualState(n"inkModalPopupState"), which triggers the fullscreen
  // modal overlay/blackout over the live 3D world.
  protected func SetUIContext() -> Void {
    if this.m_uiContextPushed {
      return;
    };
    let uiSystem: ref<UISystem> = GameInstance.GetUISystem(this.GetGame());
    if IsDefined(uiSystem) {
      uiSystem.PushGameContext(UIGameContext.ModalPopup);
      this.m_uiContextPushed = true;
    };
  }

  protected func ResetUIContext() -> Void {
    if !this.m_uiContextPushed {
      return;
    };
    let uiSystem: ref<UISystem> = GameInstance.GetUISystem(this.GetGame());
    if IsDefined(uiSystem) {
      uiSystem.PopGameContext(UIGameContext.ModalPopup, true);
    };
    this.m_uiContextPushed = false;
  }

  private func PlayAudioEvent(eventName: CName) -> Void {
    let audioSys: ref<AudioSystem> = GameInstance.GetAudioSystem(this.GetGame());
    if IsDefined(audioSys) {
      audioSys.Play(eventName);
    };
  }

  protected func PlayShowSound() -> Void {
    this.PlayAudioEvent(n"ui_menu_map_pin_on");
  }

  protected func PlayHideSound() -> Void {
    this.PlayAudioEvent(n"ui_menu_map_pin_off");
  }

  public func PlayUiHover() -> Void {
    this.PlayAudioEvent(n"ui_menu_hover");
  }

  public func PlayUiPress() -> Void {
    let ctrl: wref<inkGameController> = this.GetGameController();
    if IsDefined(ctrl) {
      ctrl.PlaySound(n"Button", n"OnPress");
    };
  }

  protected cb func OnInitialize() {
    super.OnInitialize();
    // Prevent default n"cancel" action (which is bound to both ESC and C on PC)
    // from closing the popup when user presses C to unlock the camera.
    this.m_closeAction = n"None";
    if this.m_closeOnInit {
      this.m_closeOnInit = false;
      this.Close();
    };
  }

  protected func CreateContainer() -> Void {
    let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
    let panel: ref<inkCanvas> = new inkCanvas();
    panel.SetName(n"footwearCalibratorPanel");
    panel.SetAnchor(inkEAnchor.TopLeft);
    panel.SetAnchorPoint(Vector2(0.0, 0.0));
    panel.SetMargin(inkMargin(64.0, 170.0, 0.0, 0.0));
    panel.SetSize(Vector2(920.0, 916.0));
    panel.SetInteractive(true);
    panel.Reparent(root);

    this.m_panel = panel;
    this.m_container = panel;
    this.SetContainerWidget(panel);
  }

  protected cb func OnCreate() {
    super.OnCreate();
    if !IsDefined(this.m_panel) {
      return;
    };
    this.BuildUI(this.m_panel);
    this.RefreshFromSystem(true);
  }

  protected cb func OnAttach() {
    super.OnAttach();
    if IsDefined(this.m_host) {
      this.m_host.OnPopupAttached(this);
    };
  }

  protected cb func OnHide() {
    super.OnHide();
    if IsDefined(this.m_host) {
      this.m_host.OnPopupHiding(this, this.m_closingForUnlock);
    };
    // Complete popup teardown on the same frame when unlocking camera so
    // UINotifications (which captures right_stick_x at priority -1) clears immediately.
    if this.m_closingForUnlock && !this.m_hiddenDone {
      if IsDefined(this.m_transitionAnimProxy) && this.m_transitionAnimProxy.IsPlaying() {
        this.m_transitionAnimProxy.Stop(true);
      };
      let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
      if IsDefined(root) {
        root.SetVisible(false);
      };
      this.OnHideFinish(this.m_transitionAnimProxy);
    };
  }

  protected cb func OnHidden() {
    this.m_hiddenDone = true;
    super.OnHidden();
    if IsDefined(this.m_host) {
      this.m_host.OnPopupHidden(this);
    };
  }

  private func BuildUI(panel: ref<inkCanvas>) -> Void {
    let panelW: Float = 920.0;
    let panelH: Float = 916.0;
    let padX: Float = 36.0;
    let innerW: Float = panelW - (padX * 2.0);

    // Cyberpunk frosted dark panel backing + crisp hairline border + left neon rail
    let bg: ref<inkRectangle> = FootwearTheme.Rect(n"bg", n"MainColors.Black", 0.86);
    bg.SetAnchor(inkEAnchor.Fill);
    bg.SetInteractive(true);
    bg.Reparent(panel);

    let frame: ref<inkImage> = FootwearTheme.Slice(n"outerFrame", n"cell_fg", n"MainColors.DarkRed", 0.90);
    frame.SetAnchor(inkEAnchor.Fill);
    frame.Reparent(panel);

    FootwearTheme.Line(panel, n"leftAccentRail", 0.0, 0.0, 6.0, panelH, n"MainColors.Red", 1.0);
    FootwearTheme.Line(panel, n"topAccentBar", 6.0, 0.0, panelW - 6.0, 3.0, n"MainColors.Red", 0.85);

    // Header
    let eyebrow: ref<inkText> = FootwearTheme.Caps(n"eyebrow", 22, n"Semi-Bold", n"MainColors.Red");
    eyebrow.SetAnchor(inkEAnchor.TopLeft);
    eyebrow.SetMargin(inkMargin(padX, 18.0, 0.0, 0.0));
    eyebrow.SetText("IMMERSIVE FOOTWEAR POV  //  LIVE CALIBRATOR");
    eyebrow.Reparent(panel);

    let title: ref<inkText> = FootwearTheme.Caps(n"shoeTitle", 34, n"Bold", n"MainColors.White");
    title.SetAnchor(inkEAnchor.TopLeft);
    title.SetMargin(inkMargin(padX, 46.0, 0.0, 0.0));
    title.SetSize(Vector2(innerW - 76.0, 42.0));
    title.SetWrapping(false, innerW - 76.0);
    title.SetText("LOADING FOOTWEAR...");
    title.Reparent(panel);
    this.m_shoeTitle = title;

    let sub: ref<inkText> = FootwearTheme.Label(n"shoeSub", 22, n"Regular", n"MainColors.MildRed");
    sub.SetAnchor(inkEAnchor.TopLeft);
    sub.SetMargin(inkMargin(padX, 88.0, 0.0, 0.0));
    sub.SetSize(Vector2(innerW - 76.0, 30.0));
    sub.SetWrapping(false, innerW - 76.0);
    sub.SetText("");
    sub.Reparent(panel);
    this.m_shoeSub = sub;

    ArrayClear(this.m_ownedButtons);
    ArrayPush(this.m_ownedButtons, FootwearPillButton.Create(panel, n"close", "X", panelW - padX - 54.0, 22.0, 54.0, 54.0, 26, this));
    FootwearTheme.Line(panel, n"headerRule", padX, 132.0, innerW, 2.0, n"MainColors.DarkRed", 0.90);

    // Camera Lock & Focus Boots Row
    let modeY: Float = 150.0;
    let halfW: Float = (innerW - 16.0) / 2.0;
    this.m_btnUnlockCam = FootwearPillButton.Create(panel, n"toggleCamUnlock", "UNLOCK CAMERA", padX, modeY, halfW, 56.0, 26, this);
    this.m_btnFocusBoots = FootwearPillButton.Create(panel, n"toggleFocusBoots", "FOCUS BOOTS: ON", padX + halfW + 16.0, modeY, halfW, 56.0, 26, this);

    // Empty footwear notice (shown when V is barefoot / invalid ItemID)
    let emptyGroup: ref<inkCanvas> = new inkCanvas();
    emptyGroup.SetName(n"emptyGroup");
    emptyGroup.SetAnchor(inkEAnchor.TopLeft);
    emptyGroup.SetMargin(inkMargin(padX, 240.0, 0.0, 0.0));
    emptyGroup.SetSize(Vector2(innerW, 560.0));
    emptyGroup.SetVisible(false);
    emptyGroup.Reparent(panel);
    this.m_emptyGroup = emptyGroup;

    let emptyBg: ref<inkImage> = FootwearTheme.Slice(n"emptyBg", n"cell_bg", n"MainColors.Black", 0.45);
    emptyBg.SetAnchor(inkEAnchor.Fill);
    emptyBg.Reparent(emptyGroup);

    let emptyHdr: ref<inkText> = FootwearTheme.Caps(n"emptyHdr", 34, n"Bold", n"MainColors.Yellow");
    emptyHdr.SetAnchor(inkEAnchor.TopLeft);
    emptyHdr.SetMargin(inkMargin(28.0, 48.0, 0.0, 0.0));
    emptyHdr.SetText("NO FOOTWEAR EQUIPPED");
    emptyHdr.Reparent(emptyGroup);

    let emptyMsg: ref<inkText> = FootwearTheme.Label(n"emptyMsg", 26, n"Regular", n"MainColors.White");
    emptyMsg.SetAnchor(inkEAnchor.TopLeft);
    emptyMsg.SetMargin(inkMargin(28.0, 108.0, 0.0, 0.0));
    emptyMsg.SetSize(Vector2(innerW - 56.0, 140.0));
    emptyMsg.SetWrapping(true, innerW - 56.0);
    emptyMsg.SetText("Equip a pair of shoes or boots in your Inventory or Wardrobe while this calibrator is open to adjust heel & platform elevation live.");
    emptyMsg.Reparent(emptyGroup);

    this.m_btnEmptyClose = FootwearPillButton.Create(emptyGroup, n"close", "CLOSE [ESC]", 28.0, 280.0, 360.0, 60.0, 24, this);

    // Active controls container
    let ctrlGroup: ref<inkCanvas> = new inkCanvas();
    ctrlGroup.SetName(n"controlsGroup");
    ctrlGroup.SetAnchor(inkEAnchor.TopLeft);
    ctrlGroup.SetMargin(inkMargin(padX, 226.0, 0.0, 0.0));
    ctrlGroup.SetSize(Vector2(innerW, 616.0));
    ctrlGroup.Reparent(panel);
    this.m_controlsGroup = ctrlGroup;

    this.m_heelAxis = FootwearSliderAxis.Create(
      ctrlGroup,
      n"heel",
      "HEEL LIFT (FPP / SWAY / POSTURE)",
      0.0,
      0.0,
      innerW,
      FootwearHeightLimits.GetMaxHeightCm(),
      0.0,
      this
    );

    this.m_platAxis = FootwearSliderAxis.Create(
      ctrlGroup,
      n"platform",
      "PLATFORM SOLE (TPP / PHOTO LIFT)",
      0.0,
      148.0,
      innerW,
      FootwearHeightLimits.GetMaxPlatformCm(),
      0.0,
      this
    );

    // Quick Heel Presets Row
    let presetHdr: ref<inkText> = FootwearTheme.Caps(n"presetHdr", 22, n"Semi-Bold", n"MainColors.MildRed");
    presetHdr.SetAnchor(inkEAnchor.TopLeft);
    presetHdr.SetMargin(inkMargin(0.0, 298.0, 0.0, 0.0));
    presetHdr.SetText("QUICK HEEL PRESETS (IMMEDIATE)");
    presetHdr.Reparent(ctrlGroup);

    ArrayClear(this.m_presetBtns);
    ArrayClear(this.m_presetCm);
    ArrayPush(this.m_presetCm, 0.0);
    ArrayPush(this.m_presetCm, 4.0);
    ArrayPush(this.m_presetCm, 8.0);
    ArrayPush(this.m_presetCm, 12.0);
    ArrayPush(this.m_presetCm, 16.0);

    let presetLabels: array<String>;
    ArrayPush(presetLabels, "FLAT 0");
    ArrayPush(presetLabels, "LOW 4");
    ArrayPush(presetLabels, "MID 8");
    ArrayPush(presetLabels, "HIGH 12");
    ArrayPush(presetLabels, "MAX 16");

    let presetActions: array<CName>;
    ArrayPush(presetActions, n"preset0");
    ArrayPush(presetActions, n"preset1");
    ArrayPush(presetActions, n"preset2");
    ArrayPush(presetActions, n"preset3");
    ArrayPush(presetActions, n"preset4");

    let pGap: Float = 12.0;
    let pW: Float = (innerW - (pGap * 4.0)) / 5.0;
    let i: Int32 = 0;
    while i < 5 {
      let btn: ref<FootwearPillButton> = FootwearPillButton.Create(
        ctrlGroup,
        presetActions[i],
        presetLabels[i],
        Cast<Float>(i) * (pW + pGap),
        334.0,
        pW,
        54.0,
        24,
        this
      );
      ArrayPush(this.m_presetBtns, btn);
      i += 1;
    };

    // Telemetry card strip
    let teleY: Float = 408.0;
    let teleH: Float = 96.0;
    let teleBg: ref<inkRectangle> = FootwearTheme.Rect(n"teleBg", n"MainColors.DarkRed", 0.22);
    teleBg.SetAnchor(inkEAnchor.TopLeft);
    teleBg.SetMargin(inkMargin(0.0, teleY, 0.0, 0.0));
    teleBg.SetSize(Vector2(innerW, teleH));
    teleBg.Reparent(ctrlGroup);

    FootwearTheme.Line(ctrlGroup, n"teleTop", 0.0, teleY, innerW, 2.0, n"MainColors.DarkRed", 0.80);

    let colW: Float = innerW / 3.0;
    this.m_teleLift = this.BuildTelemetryCol(ctrlGroup, n"colLift", 18.0, teleY + 12.0, "EFFECTIVE LIFT", n"MainColors.ActiveBlue");
    this.m_telePersp = this.BuildTelemetryCol(ctrlGroup, n"colPersp", colW + 14.0, teleY + 12.0, "VIEW MODE", n"MainColors.White");
    this.m_teleStatus = this.BuildTelemetryCol(ctrlGroup, n"colStatus", (colW * 2.0) + 14.0, teleY + 12.0, "STATE", n"MainColors.Yellow");

    // Primary footer actions
    let footY: Float = 524.0;
    let footGap: Float = 16.0;
    let footW: Float = (innerW - (footGap * 2.0)) / 3.0;
    this.m_btnSave = FootwearPillButton.Create(ctrlGroup, n"saveOverride", "SAVE OVERRIDE", 0.0, footY, footW, 64.0, 26, this);
    this.m_btnRevert = FootwearPillButton.Create(ctrlGroup, n"revertDefault", "REVERT DEFAULT", footW + footGap, footY, footW, 64.0, 26, this);
    this.m_btnClose = FootwearPillButton.Create(ctrlGroup, n"close", "CLOSE [ESC]", (footW + footGap) * 2.0, footY, footW, 64.0, 24, this);

    // Footer keybind hint strip
    let hintText: ref<inkText> = FootwearTheme.Caps(n"hintText", 22, n"Regular", n"MainColors.MildRed");
    hintText.SetAnchor(inkEAnchor.TopLeft);
    hintText.SetMargin(inkMargin(padX, 858.0, 0.0, 0.0));
    hintText.SetText("");
    hintText.Reparent(panel);
    this.m_hintText = hintText;
  }

  private func BuildTelemetryCol(
    parent: ref<inkCompoundWidget>,
    name: CName,
    x: Float,
    y: Float,
    caption: String,
    valColor: CName
  ) -> ref<inkText> {
    let cap: ref<inkText> = FootwearTheme.Caps(StringToName(NameToString(name) + "Cap"), 20, n"Semi-Bold", n"MainColors.MildRed");
    cap.SetAnchor(inkEAnchor.TopLeft);
    cap.SetMargin(inkMargin(x, y, 0.0, 0.0));
    cap.SetText(caption);
    cap.Reparent(parent);

    let val: ref<inkText> = FootwearTheme.Caps(StringToName(NameToString(name) + "Val"), 30, n"Bold", valColor);
    val.SetAnchor(inkEAnchor.TopLeft);
    val.SetMargin(inkMargin(x, y + 32.0, 0.0, 0.0));
    val.SetText("--");
    val.Reparent(parent);
    return val;
  }

  public func RefreshFromSystem(forceAxes: Bool) -> Void {
    if this.m_isApplyingAxis {
      return;
    };
    let gi: GameInstance = this.GetGame();
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(system) {
      return;
    };

    let cfg: ref<FootwearConfig> = system.GetConfig();
    let focusBoots: Bool = IsDefined(cfg) ? cfg.focusBootsInTPP : true;
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject() as PlayerPuppet;
    let usingPad: Bool = IsDefined(player) && player.PlayerLastUsedPad();
    let isPS5: Bool = usingPad && player.PlayerLastUsedPS5Pad();
    let toggleKeyLbl: String = IsDefined(cfg) ? FootwearTheme.KeyDisplayLabel(cfg.calibratorHotkey) : "NUM 1";
    let unlockKeyLbl: String = usingPad ? (isPS5 ? "R3" : "RS") : (IsDefined(cfg) ? FootwearTheme.KeyDisplayLabel(cfg.cameraUnlockKey) : "C");
    let closeLbl: String = usingPad ? (isPS5 ? "CIRCLE" : "B") : "ESC";
    let closeHintLbl: String = (!usingPad && NotEquals(toggleKeyLbl, "---")) ? (closeLbl + " / " + toggleKeyLbl) : closeLbl;

    if IsDefined(this.m_btnUnlockCam) {
      this.m_btnUnlockCam.SetText("UNLOCK CAMERA [" + unlockKeyLbl + "]");
    };
    if IsDefined(this.m_btnFocusBoots) {
      this.m_btnFocusBoots.SetText(focusBoots ? "FOCUS BOOTS: ON" : "FOCUS BOOTS: OFF");
      this.m_btnFocusBoots.SetSelected(focusBoots);
    };
    if IsDefined(this.m_btnClose) {
      this.m_btnClose.SetText("CLOSE [" + closeHintLbl + "]");
    };
    if IsDefined(this.m_btnEmptyClose) {
      this.m_btnEmptyClose.SetText("CLOSE [" + closeHintLbl + "]");
    };
    if IsDefined(this.m_hintText) {
      this.m_hintText.SetText("UNLOCK CAMERA: [" + unlockKeyLbl + "]  •  CLOSE: [" + closeHintLbl + "]");
    };

    let itemID: ItemID = system.GetEquippedFootwearID();
    let hasFootwear: Bool = ItemID.IsValid(itemID);

    if IsDefined(this.m_controlsGroup) {
      this.m_controlsGroup.SetVisible(hasFootwear);
    };
    if IsDefined(this.m_emptyGroup) {
      this.m_emptyGroup.SetVisible(!hasFootwear);
    };

    if !hasFootwear {
      this.m_lastShoeKey = "";
      if IsDefined(this.m_shoeTitle) {
        this.m_shoeTitle.SetText("NO FOOTWEAR EQUIPPED");
      };
      if IsDefined(this.m_shoeSub) {
        this.m_shoeSub.SetText("Equip shoes or boots in inventory for live adjustments.");
      };
      return;
    };

    let shoeKey: String = TDBID.ToStringDEBUG(ItemID.GetTDBID(itemID));
    let displayName: String = system.GetResolvedShoeDisplayName();
    let shoeChanged: Bool = NotEquals(this.m_lastShoeKey, shoeKey);
    if shoeChanged {
      this.m_lastShoeKey = shoeKey;
    };

    if IsDefined(this.m_shoeTitle) {
      this.m_shoeTitle.SetText(StrLen(displayName) > 0 ? displayName : shoeKey);
    };
    if IsDefined(this.m_shoeSub) {
      this.m_shoeSub.SetText("SOURCE: [" + system.GetSettingsSource() + "]  •  " + shoeKey);
    };

    let heelCm: Float = system.GetCurrentHeelHeight() * 100.0;
    let platCm: Float = system.GetCurrentPlatformHeight() * 100.0;

    if forceAxes || shoeChanged {
      if IsDefined(this.m_heelAxis) {
        this.m_heelAxis.SetValueCm(heelCm, false, false);
      };
      if IsDefined(this.m_platAxis) {
        this.m_platAxis.SetValueCm(platCm, false, false);
      };
    };

    this.UpdatePresetHighlights(heelCm);
    this.UpdateTelemetry(system);
  }

  private func UpdatePresetHighlights(heelCm: Float) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.m_presetBtns) {
      let match: Bool = AbsF(heelCm - this.m_presetCm[i]) <= 0.15;
      this.m_presetBtns[i].SetSelected(match);
      i += 1;
    };
  }

  private func UpdateTelemetry(system: ref<ImmersiveFootwearPOVSystem>) -> Void {
    let player: ref<PlayerPuppet> = this.GetPlayer();
    let isTpp: Bool = IsDefined(player) && system.IsTPPActive(player);
    let effCm: Float = (isTpp ? system.GetEffectivePlatformOffset() : system.GetEffectiveOffset()) * 100.0;
    if IsDefined(this.m_teleLift) {
      this.m_teleLift.SetText("+" + FloatToStringPrec(effCm, 1) + " cm");
    };

    if IsDefined(this.m_telePersp) {
      this.m_telePersp.SetText(isTpp ? "TPP (ITP)" : "FPP");
    };

    if IsDefined(this.m_teleStatus) {
      if system.IsSuppressed() {
        FootwearTheme.Paint(this.m_teleStatus, n"MainColors.Yellow");
        this.m_teleStatus.SetText("SUPPRESSED");
      } else if system.HasDirtyOverride() {
        FootwearTheme.Paint(this.m_teleStatus, n"MainColors.Yellow");
        this.m_teleStatus.SetText("UNSAVED LIVE");
      } else {
        FootwearTheme.Paint(this.m_teleStatus, n"MainColors.ActiveBlue");
        this.m_teleStatus.SetText("LIVE SYNCED");
      };
    };

    if IsDefined(this.m_btnSave) {
      this.m_btnSave.SetHighlightAccent(system.HasDirtyOverride());
    };
  }

  public func OnAxisValue(axisId: CName, valueCm: Float, commit: Bool) -> Void {
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(this.GetGame());
    if !IsDefined(system) {
      return;
    };

    let heelCm: Float = IsDefined(this.m_heelAxis) ? this.m_heelAxis.GetValueCm() : (system.GetCurrentHeelHeight() * 100.0);
    let platCm: Float = IsDefined(this.m_platAxis) ? this.m_platAxis.GetValueCm() : (system.GetCurrentPlatformHeight() * 100.0);

    this.m_isApplyingAxis = true;
    system.ApplyLiveCalibration(heelCm / 100.0, platCm / 100.0);
    if commit && system.HasDirtyOverride() {
      system.FlushPendingOverrideSave();
    };
    this.m_isApplyingAxis = false;

    let appliedHeelCm: Float = system.GetCurrentHeelHeight() * 100.0;
    let appliedPlatCm: Float = system.GetCurrentPlatformHeight() * 100.0;
    if IsDefined(this.m_heelAxis) && AbsF(appliedHeelCm - heelCm) > 0.05 {
      this.m_heelAxis.SetValueCm(appliedHeelCm, false, false);
    };
    if IsDefined(this.m_platAxis) && AbsF(appliedPlatCm - platCm) > 0.05 {
      this.m_platAxis.SetValueCm(appliedPlatCm, false, false);
    };

    if IsDefined(this.m_shoeSub) {
      let itemID: ItemID = system.GetEquippedFootwearID();
      let shoeKey: String = ItemID.IsValid(itemID) ? TDBID.ToStringDEBUG(ItemID.GetTDBID(itemID)) : "";
      this.m_shoeSub.SetText("SOURCE: [" + system.GetSettingsSource() + "]  •  " + shoeKey);
    };
    this.UpdatePresetHighlights(appliedHeelCm);
    this.UpdateTelemetry(system);
  }

  public func OnPopupAction(action: CName) -> Void {
    if IsDefined(this.m_heelAxis) { this.m_heelAxis.ClearInputFocus(); };
    if IsDefined(this.m_platAxis) { this.m_platAxis.ClearInputFocus(); };

    let gi: GameInstance = this.GetGame();
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(system) {
      return;
    };

    if Equals(action, n"close") {
      if IsDefined(this.m_host) {
        this.m_host.CloseCalibrator();
      } else {
        system.FlushPendingOverrideSave();
        this.Close();
      };
      return;
    };

    if Equals(action, n"toggleCamUnlock") {
      if IsDefined(this.m_host) {
        this.m_host.ToggleCameraLock();
      };
      return;
    };

    if Equals(action, n"toggleFocusBoots") {
      let cfg: ref<FootwearConfig> = system.GetConfig();
      if IsDefined(cfg) {
        cfg.focusBootsInTPP = !cfg.focusBootsInTPP;
        system.OnConfigUpdated(cfg);
        system.GetStorageManager().SaveConfig(cfg);
        ITPController.MaintainCalibratorTPPLease(gi, cfg.focusBootsInTPP);
        FootwearCalibratorCamera.SetFocusBoots(gi, cfg.focusBootsInTPP);
      };
      this.RefreshFromSystem(false);
      return;
    };

    if Equals(action, n"saveOverride") {
      system.FlushPendingOverrideSave();
      this.RefreshFromSystem(false);
      return;
    };

    if Equals(action, n"revertDefault") {
      system.ClearPendingOverrideSave();
      let itemID: ItemID = system.GetEquippedFootwearID();
      if ItemID.IsValid(itemID) {
        system.GetStorageManager().RemoveUserOverride(TDBID.ToStringDEBUG(ItemID.GetTDBID(itemID)));
      };
      system.RevertFootwearToDefault();
      this.RefreshFromSystem(true);
      return;
    };

    // Axis step & reset actions
    if Equals(action, n"heelDecCoarse") && IsDefined(this.m_heelAxis) { this.m_heelAxis.NudgeCm(-1.0); return; };
    if Equals(action, n"heelDecFine") && IsDefined(this.m_heelAxis) { this.m_heelAxis.NudgeCm(-0.1); return; };
    if Equals(action, n"heelIncFine") && IsDefined(this.m_heelAxis) { this.m_heelAxis.NudgeCm(0.1); return; };
    if Equals(action, n"heelIncCoarse") && IsDefined(this.m_heelAxis) { this.m_heelAxis.NudgeCm(1.0); return; };
    if Equals(action, n"resetHeel") && IsDefined(this.m_heelAxis) { this.m_heelAxis.SetValueCm(0.0, true, true); return; };

    if Equals(action, n"platDecCoarse") && IsDefined(this.m_platAxis) { this.m_platAxis.NudgeCm(-1.0); return; };
    if Equals(action, n"platDecFine") && IsDefined(this.m_platAxis) { this.m_platAxis.NudgeCm(-0.1); return; };
    if Equals(action, n"platIncFine") && IsDefined(this.m_platAxis) { this.m_platAxis.NudgeCm(0.1); return; };
    if Equals(action, n"platIncCoarse") && IsDefined(this.m_platAxis) { this.m_platAxis.NudgeCm(1.0); return; };
    if Equals(action, n"resetPlatform") && IsDefined(this.m_platAxis) { this.m_platAxis.SetValueCm(0.0, true, true); return; };

    // Quick Heel Presets
    if Equals(action, n"preset0") && IsDefined(this.m_heelAxis) { this.m_heelAxis.SetValueCm(0.0, true, true); return; };
    if Equals(action, n"preset1") && IsDefined(this.m_heelAxis) { this.m_heelAxis.SetValueCm(4.0, true, true); return; };
    if Equals(action, n"preset2") && IsDefined(this.m_heelAxis) { this.m_heelAxis.SetValueCm(8.0, true, true); return; };
    if Equals(action, n"preset3") && IsDefined(this.m_heelAxis) { this.m_heelAxis.SetValueCm(12.0, true, true); return; };
    if Equals(action, n"preset4") && IsDefined(this.m_heelAxis) { this.m_heelAxis.SetValueCm(16.0, true, true); return; };
  }
}

// =============================================================================
// Lightweight Left-Docked HUD Mirror (Shown when Camera is Unlocked in TPP)
// Renders cleanly on inkHUDLayer with zero cursor capture so player can orbit
// and zoom freely around V's legs & boots while viewing live telemetry.
// =============================================================================

@if(ModuleExists("Codeware.UI"))
public class FootwearCalibratorHudMirror {
  private let m_root: ref<inkCanvas>;
  private let m_titleText: ref<inkText>;
  private let m_valuesText: ref<inkText>;
  private let m_hintText: ref<inkText>;
  private let m_hostParent: wref<inkCompoundWidget>;

  public func Mount(gi: GameInstance) -> Bool {
    if IsDefined(this.m_root) {
      this.Refresh(gi);
      return true;
    };

    let inkSys: ref<inkSystem> = GameInstance.GetInkSystem();
    if !IsDefined(inkSys) {
      return false;
    };
    let hudLayer: ref<inkLayerWrapper> = inkSys.GetLayer(n"inkHUDLayer");
    if !IsDefined(hudLayer) {
      return false;
    };
    let hudCtrl: wref<inkGameController> = hudLayer.GetGameController() as inkGameController;
    if !IsDefined(hudCtrl) {
      return false;
    };
    let hudRoot: ref<inkCompoundWidget> = hudCtrl.GetRootCompoundWidget();
    if !IsDefined(hudRoot) {
      return false;
    };

    let card: ref<inkCanvas> = new inkCanvas();
    card.SetName(n"IFP_CalibratorHudMirror");
    card.SetAnchor(inkEAnchor.TopLeft);
    card.SetAnchorPoint(Vector2(0.0, 0.0));
    card.SetMargin(inkMargin(64.0, 170.0, 0.0, 0.0));
    card.SetSize(Vector2(920.0, 260.0));
    card.Reparent(hudRoot);

    let bg: ref<inkRectangle> = FootwearTheme.Rect(n"bg", n"MainColors.Black", 0.78);
    bg.SetAnchor(inkEAnchor.Fill);
    bg.Reparent(card);

    let frame: ref<inkImage> = FootwearTheme.Slice(n"frame", n"cell_fg", n"MainColors.Yellow", 0.90);
    frame.SetAnchor(inkEAnchor.Fill);
    frame.Reparent(card);

    FootwearTheme.Line(card, n"leftRail", 0.0, 0.0, 6.0, 260.0, n"MainColors.Yellow", 1.0);

    let badge: ref<inkText> = FootwearTheme.Caps(n"badge", 24, n"Bold", n"MainColors.Yellow");
    badge.SetAnchor(inkEAnchor.TopLeft);
    badge.SetMargin(inkMargin(36.0, 22.0, 0.0, 0.0));
    badge.SetText("CAMERA UNLOCKED  //  FREE ORBIT INSPECTION");
    badge.Reparent(card);

    let title: ref<inkText> = FootwearTheme.Caps(n"shoeTitle", 32, n"Bold", n"MainColors.White");
    title.SetAnchor(inkEAnchor.TopLeft);
    title.SetMargin(inkMargin(36.0, 60.0, 0.0, 0.0));
    title.SetSize(Vector2(848.0, 40.0));
    title.SetWrapping(false, 848.0);
    title.Reparent(card);
    this.m_titleText = title;

    let vals: ref<inkText> = FootwearTheme.Caps(n"values", 28, n"Semi-Bold", n"MainColors.ActiveBlue");
    vals.SetAnchor(inkEAnchor.TopLeft);
    vals.SetMargin(inkMargin(36.0, 114.0, 0.0, 0.0));
    vals.Reparent(card);
    this.m_valuesText = vals;

    FootwearTheme.Line(card, n"rule", 36.0, 172.0, 848.0, 2.0, n"MainColors.DarkRed", 0.90);

    let hint: ref<inkText> = FootwearTheme.Caps(n"hint", 24, n"Medium", n"MainColors.Yellow");
    hint.SetAnchor(inkEAnchor.TopLeft);
    hint.SetMargin(inkMargin(36.0, 194.0, 0.0, 0.0));
    hint.Reparent(card);
    this.m_hintText = hint;

    this.m_root = card;
    this.m_hostParent = hudRoot;
    this.Refresh(gi);
    return true;
  }

  public func Refresh(gi: GameInstance) -> Void {
    if !IsDefined(this.m_root) {
      return;
    };
    let system: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(gi);
    if !IsDefined(system) {
      return;
    };
    let cfg: ref<FootwearConfig> = system.GetConfig();
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(gi).GetLocalPlayerMainGameObject() as PlayerPuppet;
    let usingPad: Bool = IsDefined(player) && player.PlayerLastUsedPad();
    let isPS5: Bool = usingPad && player.PlayerLastUsedPS5Pad();
    let toggleKeyLbl: String = IsDefined(cfg) ? FootwearTheme.KeyDisplayLabel(cfg.calibratorHotkey) : "NUM 1";
    let unlockKeyLbl: String = usingPad ? (isPS5 ? "R3" : "RS") : (IsDefined(cfg) ? FootwearTheme.KeyDisplayLabel(cfg.cameraUnlockKey) : "C");

    let itemID: ItemID = system.GetEquippedFootwearID();
    let hasFootwear: Bool = ItemID.IsValid(itemID);
    if IsDefined(this.m_titleText) {
      this.m_titleText.SetText(hasFootwear ? system.GetResolvedShoeDisplayName() : "NO FOOTWEAR EQUIPPED");
    };
    if IsDefined(this.m_valuesText) {
      if hasFootwear {
        let isTpp: Bool = IsDefined(player) && system.IsTPPActive(player);
        let hCm: String = FloatToStringPrec(system.GetCurrentHeelHeight() * 100.0, 1);
        let pCm: String = FloatToStringPrec(system.GetCurrentPlatformHeight() * 100.0, 1);
        let eCm: String = FloatToStringPrec((isTpp ? system.GetEffectivePlatformOffset() : system.GetEffectiveOffset()) * 100.0, 1);
        let liftLbl: String = isTpp ? "TPP LIFT: +" : "FPP LIFT: +";
        this.m_valuesText.SetText("HEEL: " + hCm + " CM   •   PLATFORM: " + pCm + " CM   •   " + liftLbl + eCm + " CM");
      } else {
        this.m_valuesText.SetText("EQUIP SHOES TO VIEW LIVE TELEMETRY");
      };
    };
    if IsDefined(this.m_hintText) {
      if usingPad {
        this.m_hintText.SetText("PRESS [" + unlockKeyLbl + "] TO RE-LOCK UI, EDIT OR CLOSE");
      } else {
        this.m_hintText.SetText("PRESS [" + unlockKeyLbl + "] TO RE-LOCK UI & EDIT   •   PRESS [" + toggleKeyLbl + "] TO CLOSE");
      };
    };
  }

  public func Unmount() -> Void {
    if IsDefined(this.m_root) && IsDefined(this.m_hostParent) {
      this.m_hostParent.RemoveChild(this.m_root);
    };
    this.m_root = null;
    this.m_hostParent = null;
  }
}

@if(!ModuleExists("Codeware.UI"))
public class FootwearCalibratorPopup {
}

@if(!ModuleExists("Codeware.UI"))
public class FootwearCalibratorHudMirror {
}
