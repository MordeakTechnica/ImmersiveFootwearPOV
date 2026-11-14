module ImmersiveFootwearPOV

@if(ModuleExists("Codeware.UI"))
import Codeware.UI.*

// =============================================================================
// Immersive Footwear POV - Native Cyberpunk UI Primitives
// Shared visual styling, pill buttons, and live slider axes built directly on
// Cyberpunk 2077 ink widgets + main_colors.inkstyle + raj.inkfontfamily.
// =============================================================================

@if(ModuleExists("Codeware.UI"))
public class FootwearTheme {
  public static func InkWidth() -> Float { return 3840.0; }
  public static func InkHeight() -> Float { return 2160.0; }

  public static func Paint(widget: wref<inkWidget>, color: CName) -> Void {
    if !IsDefined(widget) {
      return;
    };
    widget.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
    widget.BindProperty(n"tintColor", color);
  }

  public static func Rect(name: CName, color: CName, opacity: Float) -> ref<inkRectangle> {
    let rect: ref<inkRectangle> = new inkRectangle();
    rect.SetName(name);
    rect.SetOpacity(opacity);
    FootwearTheme.Paint(rect, color);
    return rect;
  }

  public static func Slice(name: CName, part: CName, color: CName, opacity: Float) -> ref<inkImage> {
    let img: ref<inkImage> = new inkImage();
    img.SetName(name);
    img.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
    img.SetTexturePart(part);
    img.SetNineSliceScale(true);
    img.SetOpacity(opacity);
    FootwearTheme.Paint(img, color);
    return img;
  }

  public static func Label(name: CName, size: Int32, style: CName, color: CName) -> ref<inkText> {
    let text: ref<inkText> = new inkText();
    text.SetName(name);
    text.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    text.SetFontStyle(style);
    text.SetFontSize(size);
    text.SetFitToContent(true);
    FootwearTheme.Paint(text, color);
    return text;
  }

  public static func Caps(name: CName, size: Int32, style: CName, color: CName) -> ref<inkText> {
    let text: ref<inkText> = FootwearTheme.Label(name, size, style, color);
    text.SetLetterCase(textLetterCase.UpperCase);
    return text;
  }

  public static func Line(parent: ref<inkCompoundWidget>, name: CName, x: Float, y: Float, w: Float, h: Float, color: CName, opacity: Float) -> ref<inkRectangle> {
    let line: ref<inkRectangle> = FootwearTheme.Rect(name, color, opacity);
    line.SetAnchor(inkEAnchor.TopLeft);
    line.SetAnchorPoint(Vector2(0.0, 0.0));
    line.SetMargin(inkMargin(x, y, 0.0, 0.0));
    line.SetSize(Vector2(w, h));
    line.Reparent(parent);
    return line;
  }

  public static func KeyDisplayLabel(keyInt: Int32) -> String {
    if keyInt <= 0 {
      return "---";
    };
    let rawName: String = NameToString(EnumValueToName(n"EInputKey", Cast<Int64>(keyInt)));
    if StrLen(rawName) == 0 || Equals(rawName, "None") || Equals(rawName, "IK_None") {
      return "---";
    };
    let cleaned: String = StrReplace(rawName, "IK_", "");
    cleaned = StrReplace(cleaned, "NumPad", "NUM ");
    return cleaned;
  }
}

@if(ModuleExists("Codeware.UI"))
public class FootwearPillButton {
  private let m_root: ref<inkCanvas>;
  private let m_fill: ref<inkImage>;
  private let m_frame: ref<inkImage>;
  private let m_text: ref<inkText>;
  private let m_action: CName;
  private let m_owner: wref<FootwearCalibratorPopup>;
  private let m_selected: Bool;
  private let m_disabled: Bool;
  private let m_hovered: Bool;
  private let m_highlightAccent: Bool;

  public static func Create(
    parent: ref<inkCompoundWidget>,
    action: CName,
    labelText: String,
    x: Float,
    y: Float,
    w: Float,
    h: Float,
    fontSize: Int32,
    owner: wref<FootwearCalibratorPopup>
  ) -> ref<FootwearPillButton> {
    let btn: ref<FootwearPillButton> = new FootwearPillButton();
    btn.m_action = action;
    btn.m_owner = owner;

    let root: ref<inkCanvas> = new inkCanvas();
    root.SetName(action);
    root.SetAnchor(inkEAnchor.TopLeft);
    root.SetAnchorPoint(Vector2(0.0, 0.0));
    root.SetMargin(inkMargin(x, y, 0.0, 0.0));
    root.SetSize(Vector2(w, h));
    root.SetInteractive(true);
    root.Reparent(parent);
    btn.m_root = root;

    let fill: ref<inkImage> = FootwearTheme.Slice(n"fill", n"cell_bg", n"MainColors.DarkRed", 0.30);
    fill.SetAnchor(inkEAnchor.Fill);
    fill.Reparent(root);
    btn.m_fill = fill;

    let frame: ref<inkImage> = FootwearTheme.Slice(n"frame", n"cell_fg", n"MainColors.Red", 0.72);
    frame.SetAnchor(inkEAnchor.Fill);
    frame.Reparent(root);
    btn.m_frame = frame;

    let label: ref<inkText> = FootwearTheme.Caps(n"label", fontSize, n"Medium", n"MainColors.MildRed");
    label.SetAnchor(inkEAnchor.Centered);
    label.SetAnchorPoint(Vector2(0.5, 0.5));
    label.SetHAlign(inkEHorizontalAlign.Center);
    label.SetVAlign(inkEVerticalAlign.Center);
    label.SetHorizontalAlignment(textHorizontalAlignment.Center);
    label.SetText(labelText);
    label.Reparent(root);
    btn.m_text = label;

    root.RegisterToCallback(n"OnRelease", btn, n"OnButtonRelease");
    root.RegisterToCallback(n"OnHoverOver", btn, n"OnButtonHoverOver");
    root.RegisterToCallback(n"OnHoverOut", btn, n"OnButtonHoverOut");

    btn.RefreshVisuals();
    return btn;
  }

  public func SetText(labelText: String) -> Void {
    if IsDefined(this.m_text) {
      this.m_text.SetText(labelText);
    };
  }

  public func SetSelected(selected: Bool) -> Void {
    if Equals(this.m_selected, selected) {
      return;
    };
    this.m_selected = selected;
    this.RefreshVisuals();
  }

  public func SetHighlightAccent(accent: Bool) -> Void {
    if Equals(this.m_highlightAccent, accent) {
      return;
    };
    this.m_highlightAccent = accent;
    this.RefreshVisuals();
  }

  public func SetDisabled(disabled: Bool) -> Void {
    if Equals(this.m_disabled, disabled) {
      return;
    };
    this.m_disabled = disabled;
    if IsDefined(this.m_root) {
      this.m_root.SetInteractive(!disabled);
    };
    this.RefreshVisuals();
  }

  public func GetRoot() -> ref<inkCanvas> {
    return this.m_root;
  }

  private func RefreshVisuals() -> Void {
    if !IsDefined(this.m_fill) || !IsDefined(this.m_frame) || !IsDefined(this.m_text) {
      return;
    };

    if this.m_disabled {
      FootwearTheme.Paint(this.m_fill, n"MainColors.Black");
      this.m_fill.SetOpacity(0.35);
      FootwearTheme.Paint(this.m_frame, n"MainColors.MildRed");
      this.m_frame.SetOpacity(0.20);
      FootwearTheme.Paint(this.m_text, n"MainColors.MildRed");
      this.m_text.SetOpacity(0.35);
      return;
    };

    this.m_text.SetOpacity(1.0);

    if this.m_selected {
      FootwearTheme.Paint(this.m_fill, n"MainColors.ActiveBlue");
      this.m_fill.SetOpacity(this.m_hovered ? 0.34 : 0.24);
      FootwearTheme.Paint(this.m_frame, n"MainColors.ActiveBlue");
      this.m_frame.SetOpacity(0.95);
      FootwearTheme.Paint(this.m_text, n"MainColors.ActiveBlue");
      return;
    };

    if this.m_highlightAccent {
      FootwearTheme.Paint(this.m_fill, n"MainColors.Yellow");
      this.m_fill.SetOpacity(this.m_hovered ? 0.28 : 0.18);
      FootwearTheme.Paint(this.m_frame, n"MainColors.Yellow");
      this.m_frame.SetOpacity(0.90);
      FootwearTheme.Paint(this.m_text, n"MainColors.Yellow");
      return;
    };

    if this.m_hovered {
      FootwearTheme.Paint(this.m_fill, n"MainColors.ActiveBlue");
      this.m_fill.SetOpacity(0.18);
      FootwearTheme.Paint(this.m_frame, n"MainColors.ActiveBlue");
      this.m_frame.SetOpacity(0.95);
      FootwearTheme.Paint(this.m_text, n"MainColors.White");
      return;
    };

    FootwearTheme.Paint(this.m_fill, n"MainColors.DarkRed");
    this.m_fill.SetOpacity(0.28);
    FootwearTheme.Paint(this.m_frame, n"MainColors.Red");
    this.m_frame.SetOpacity(0.62);
    FootwearTheme.Paint(this.m_text, n"MainColors.MildRed");
  }

  protected cb func OnButtonHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    this.m_hovered = true;
    this.RefreshVisuals();
    if IsDefined(this.m_owner) && !this.m_disabled {
      this.m_owner.PlayUiHover();
    };
    return false;
  }

  protected cb func OnButtonHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    this.m_hovered = false;
    this.RefreshVisuals();
    return false;
  }

  protected cb func OnButtonRelease(evt: ref<inkPointerEvent>) -> Bool {
    if this.m_disabled || !evt.IsAction(n"click") {
      return false;
    };
    if IsDefined(this.m_owner) {
      this.m_owner.PlayUiPress();
      this.m_owner.OnPopupAction(this.m_action);
    };
    evt.Handle();
    return true;
  }
}

@if(ModuleExists("Codeware.UI"))
public class FootwearSliderAxis {
  private let m_axisId: CName;
  private let m_owner: wref<FootwearCalibratorPopup>;
  private let m_maxCm: Float;
  private let m_stepCm: Float;
  private let m_valueCm: Float;
  private let m_sliderW: Float;
  private let m_suppressCallback: Bool;
  private let m_isHovered: Bool;
  private let m_isPointerDragging: Bool;

  private let m_valueText: ref<inkText>;
  private let m_fillBar: ref<inkRectangle>;
  private let m_handle: ref<inkRectangle>;
  private let m_sliderArea: ref<inkCanvas>;
  private let m_sliderCtrl: wref<inkSliderController>;
  private let m_buttons: array<ref<FootwearPillButton>>;

  public static func Create(
    parent: ref<inkCompoundWidget>,
    axisId: CName,
    title: String,
    x: Float,
    y: Float,
    width: Float,
    maxCm: Float,
    initialCm: Float,
    owner: wref<FootwearCalibratorPopup>
  ) -> ref<FootwearSliderAxis> {
    let axis: ref<FootwearSliderAxis> = new FootwearSliderAxis();
    axis.m_axisId = axisId;
    axis.m_owner = owner;
    axis.m_maxCm = maxCm > 0.0 ? maxCm : 40.0;
    axis.m_stepCm = 0.1;
    axis.m_valueCm = ClampF(initialCm, 0.0, axis.m_maxCm);

    let block: ref<inkCanvas> = new inkCanvas();
    block.SetName(axisId);
    block.SetAnchor(inkEAnchor.TopLeft);
    block.SetAnchorPoint(Vector2(0.0, 0.0));
    block.SetMargin(inkMargin(x, y, 0.0, 0.0));
    block.SetSize(Vector2(width, 132.0));
    block.Reparent(parent);

    // Subtle dark recessed axis backdrop
    let card: ref<inkImage> = FootwearTheme.Slice(n"cardBg", n"cell_bg", n"MainColors.Black", 0.42);
    card.SetAnchor(inkEAnchor.Fill);
    card.Reparent(block);

    let cardLine: ref<inkImage> = FootwearTheme.Slice(n"cardBorder", n"cell_fg", n"MainColors.DarkRed", 0.65);
    cardLine.SetAnchor(inkEAnchor.Fill);
    cardLine.Reparent(block);

    // Header row: axis title on left, crisp readout + quick reset on right
    let titleLabel: ref<inkText> = FootwearTheme.Caps(n"axisTitle", 28, n"Semi-Bold", n"MainColors.Red");
    titleLabel.SetAnchor(inkEAnchor.TopLeft);
    titleLabel.SetAnchorPoint(Vector2(0.0, 0.0));
    titleLabel.SetMargin(inkMargin(22.0, 14.0, 0.0, 0.0));
    titleLabel.SetText(title);
    titleLabel.Reparent(block);

    let valLabel: ref<inkText> = FootwearTheme.Label(n"axisValue", 36, n"Bold", n"MainColors.Yellow");
    valLabel.SetAnchor(inkEAnchor.TopRight);
    valLabel.SetAnchorPoint(Vector2(1.0, 0.0));
    valLabel.SetMargin(inkMargin(0.0, 10.0, 132.0, 0.0));
    valLabel.SetHAlign(inkEHorizontalAlign.Right);
    valLabel.SetText(FloatToStringPrec(axis.m_valueCm, 1) + " cm");
    valLabel.Reparent(block);
    axis.m_valueText = valLabel;

    let resetAction: CName = Equals(axisId, n"heel") ? n"resetHeel" : n"resetPlatform";
    ArrayPush(axis.m_buttons, FootwearPillButton.Create(block, resetAction, "0.0", width - 114.0, 12.0, 94.0, 38.0, 24, owner));

    // Controls row: [-1] [-.1] [=== Slider ===] [+.1] [+1]
    let rowY: Float = 66.0;
    let stepW: Float = 72.0;
    let stepH: Float = 46.0;
    let gap: Float = 8.0;
    let padX: Float = 20.0;
    let sliderX: Float = padX + (stepW + gap) * 2.0;
    let sliderW: Float = width - (padX * 2.0) - (stepW * 4.0) - (gap * 4.0);
    axis.m_sliderW = sliderW;

    let decCoarse: CName = Equals(axisId, n"heel") ? n"heelDecCoarse" : n"platDecCoarse";
    let decFine: CName = Equals(axisId, n"heel") ? n"heelDecFine" : n"platDecFine";
    let incFine: CName = Equals(axisId, n"heel") ? n"heelIncFine" : n"platIncFine";
    let incCoarse: CName = Equals(axisId, n"heel") ? n"heelIncCoarse" : n"platIncCoarse";

    ArrayPush(axis.m_buttons, FootwearPillButton.Create(block, decCoarse, "-1", padX, rowY, stepW, stepH, 24, owner));
    ArrayPush(axis.m_buttons, FootwearPillButton.Create(block, decFine, "-.1", padX + stepW + gap, rowY, stepW, stepH, 24, owner));
    ArrayPush(axis.m_buttons, FootwearPillButton.Create(block, incFine, "+.1", sliderX + sliderW + gap, rowY, stepW, stepH, 24, owner));
    ArrayPush(axis.m_buttons, FootwearPillButton.Create(block, incCoarse, "+1", sliderX + sliderW + (gap * 2.0) + stepW, rowY, stepW, stepH, 24, owner));

    let sliderArea: ref<inkCanvas> = new inkCanvas();
    sliderArea.SetName(n"slidingArea");
    sliderArea.SetAnchor(inkEAnchor.TopLeft);
    sliderArea.SetAnchorPoint(Vector2(0.0, 0.0));
    sliderArea.SetMargin(inkMargin(sliderX, rowY, 0.0, 0.0));
    sliderArea.SetSize(Vector2(sliderW, stepH));
    sliderArea.SetInteractive(true);
    sliderArea.Reparent(block);
    axis.m_sliderArea = sliderArea;

    // Track rail
    let rail: ref<inkRectangle> = FootwearTheme.Rect(n"rail", n"MainColors.DarkRed", 0.45);
    rail.SetAnchor(inkEAnchor.CenterLeft);
    rail.SetAnchorPoint(Vector2(0.0, 0.5));
    rail.SetSize(Vector2(sliderW, 14.0));
    rail.Reparent(sliderArea);

    // Live fill bar
    let initNorm: Float = ClampF(axis.m_valueCm / axis.m_maxCm, 0.0, 1.0);
    let fillBar: ref<inkRectangle> = FootwearTheme.Rect(n"fillBar", n"MainColors.Red", 0.88);
    fillBar.SetAnchor(inkEAnchor.CenterLeft);
    fillBar.SetAnchorPoint(Vector2(0.0, 0.5));
    fillBar.SetSize(Vector2(sliderW * initNorm, 14.0));
    fillBar.Reparent(sliderArea);
    axis.m_fillBar = fillBar;

    // Handle thumb
    let handle: ref<inkRectangle> = FootwearTheme.Rect(n"handle", n"MainColors.Yellow", 1.0);
    handle.SetAnchor(inkEAnchor.LeftFillVerticaly);
    handle.SetSize(Vector2(24.0, stepH));
    handle.SetInteractive(true);
    handle.Reparent(sliderArea);
    axis.m_handle = handle;

    let ctrl: ref<inkSliderController> = new inkSliderController();
    ctrl.slidingAreaRef = inkWidgetRef.Create(sliderArea);
    ctrl.handleRef = inkWidgetRef.Create(handle);
    ctrl.direction = inkESliderDirection.Horizontal;
    ctrl.autoSizeHandle = false;
    ctrl.Setup(0.0, 1.0, initNorm);
    sliderArea.AttachController(ctrl);
    axis.m_sliderCtrl = ctrl;

    ctrl.RegisterToCallback(n"OnSliderValueChanged", axis, n"OnSliderValueChanged");
    ctrl.RegisterToCallback(n"OnSliderHandleReleased", axis, n"OnSliderReleased");
    sliderArea.RegisterToCallback(n"OnPress", axis, n"OnAreaPress");
    handle.RegisterToCallback(n"OnPress", axis, n"OnAreaPress");
    sliderArea.RegisterToCallback(n"OnRelease", axis, n"OnAreaRelease");
    sliderArea.RegisterToCallback(n"OnHoverOver", axis, n"OnSliderHoverOver");
    sliderArea.RegisterToCallback(n"OnHoverOut", axis, n"OnSliderHoverOut");

    return axis;
  }

  public func GetValueCm() -> Float {
    return this.m_valueCm;
  }

  public func SetValueCm(cm: Float, notifyOwner: Bool, commitSave: Bool) -> Void {
    let snapped: Float = FootwearSliderAxis.SnapTenths(ClampF(cm, 0.0, this.m_maxCm));
    let changed: Bool = AbsF(snapped - this.m_valueCm) > 0.01;
    this.m_valueCm = snapped;

    let norm: Float = ClampF(snapped / this.m_maxCm, 0.0, 1.0);
    this.UpdateReadoutAndFill(norm);

    if IsDefined(this.m_sliderCtrl) && AbsF(this.m_sliderCtrl.GetProgress() - norm) > 0.001 {
      this.m_suppressCallback = true;
      this.m_sliderCtrl.ChangeProgress(norm);
      this.m_suppressCallback = false;
    };

    if notifyOwner && IsDefined(this.m_owner) && (changed || commitSave) {
      this.m_owner.OnAxisValue(this.m_axisId, this.m_valueCm, commitSave);
    };
  }

  public func NudgeTenths(deltaTenths: Int32) -> Void {
    let maxTenths: Int32 = FootwearSliderAxis.ToTenths(this.m_maxCm);
    let curTenths: Int32 = FootwearSliderAxis.ToTenths(this.m_valueCm);
    let nextTenths: Int32 = curTenths + deltaTenths;
    if nextTenths < 0 {
      nextTenths = 0;
    } else if nextTenths > maxTenths {
      nextTenths = maxTenths;
    };
    this.SetValueCm(Cast<Float>(nextTenths) / 10.0, true, true);
  }

  public func NudgeCm(deltaCm: Float) -> Void {
    this.NudgeTenths(FootwearSliderAxis.ToTenths(deltaCm));
  }

  private func UpdateReadoutAndFill(norm: Float) -> Void {
    if IsDefined(this.m_valueText) {
      this.m_valueText.SetText(FloatToStringPrec(this.m_valueCm, 1) + " cm");
    };
    if IsDefined(this.m_fillBar) {
      this.m_fillBar.SetSize(Vector2(MaxF(0.0, this.m_sliderW * ClampF(norm, 0.0, 1.0)), 14.0));
    };
  }

  // Round to nearest tenth using FloorF(+0.5) because REDengine RoundF truncates float32 values like 5.2999997 -> 52.
  private static func ToTenths(val: Float) -> Int32 {
    if val < 0.0 {
      return -FloorF((-val * 10.0) + 0.5);
    };
    return FloorF((val * 10.0) + 0.5);
  }

  private static func SnapTenths(val: Float) -> Float {
    return Cast<Float>(FootwearSliderAxis.ToTenths(val)) / 10.0;
  }

  protected cb func OnAreaPress(evt: ref<inkPointerEvent>) -> Bool {
    if evt.IsAction(n"click") {
      this.m_isPointerDragging = true;
    };
    return false;
  }

  protected cb func OnSliderValueChanged(slider: wref<inkSliderController>, progress: Float, value: Float) -> Bool {
    if this.m_suppressCallback || !this.m_isPointerDragging {
      return false;
    };
    let cm: Float = FootwearSliderAxis.SnapTenths(ClampF(progress * this.m_maxCm, 0.0, this.m_maxCm));
    this.m_valueCm = cm;
    this.UpdateReadoutAndFill(progress);
    if IsDefined(this.m_owner) {
      this.m_owner.OnAxisValue(this.m_axisId, this.m_valueCm, false);
    };
    return false;
  }

  protected cb func OnSliderReleased() -> Bool {
    this.m_isPointerDragging = false;
    if IsDefined(this.m_owner) {
      this.m_owner.OnAxisValue(this.m_axisId, this.m_valueCm, true);
    };
    return false;
  }

  protected cb func OnAreaRelease(evt: ref<inkPointerEvent>) -> Bool {
    if evt.IsAction(n"click") {
      this.m_isPointerDragging = false;
      if IsDefined(this.m_owner) {
        this.m_owner.OnAxisValue(this.m_axisId, this.m_valueCm, true);
      };
    };
    return false;
  }

  protected cb func OnSliderHoverOver(evt: ref<inkPointerEvent>) -> Bool {
    this.m_isHovered = true;
    if IsDefined(this.m_fillBar) {
      FootwearTheme.Paint(this.m_fillBar, n"MainColors.ActiveBlue");
    };
    return false;
  }

  protected cb func OnSliderHoverOut(evt: ref<inkPointerEvent>) -> Bool {
    this.m_isHovered = false;
    if IsDefined(this.m_fillBar) {
      FootwearTheme.Paint(this.m_fillBar, n"MainColors.Red");
    };
    return false;
  }
}
