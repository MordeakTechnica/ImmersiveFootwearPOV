module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Core ScriptableSystem
// Authoritative state manager for footwear elevation, suppression, and offsets
// =============================================================================

public class ImmersiveFootwearPOVSystem extends ScriptableSystem {

  private let m_currentHeelHeight: Float;      // Active FPP elevation height (meters)
  private let m_currentPlatformHeight: Float;  // Secondary platform height (reserved for PM)
  private let m_effectiveOffset: Float;        // Current effective height after suppression
  private let m_equippedFootwearID: ItemID;
  private let m_activeSource: String;
  private let m_hasOfficialTags: Bool;
  private let m_hasCustomOverride: Bool;
  private let m_customHeelHeight: Float;
  private let m_customPlatformHeight: Float;
  private let m_isInVehicle: Bool;
  private let m_isInWorkspot: Bool;
  private let m_isSuppressed: Bool;
  private let m_suppressionReason: String;
  private let m_isInitialized: Bool;
  private let m_debugLogging: Bool;
  private let m_isPhotoModeActive: Bool;
  private let m_isIFPPresent: Bool;
  private let m_isITPPresent: Bool;

  // TFP Telemetry & Weapon Synchronization Tracking
  private let m_tfpLastLoggedFootwear: ItemID;
  private let m_tfpLastLoggedOffset: Float;
  private let m_tfpLastLoggedSuppressed: Bool;
  private let m_tfpLastWeaponKey: String;
  private let m_tfpLastWeaponBaseZ: Float;
  private let m_tfpLastAppliedWeaponLift: Float;

  // -----------------------------------------------------------------------------
  // Singleton Accessor
  // -----------------------------------------------------------------------------
  public static func GetInstance(gameInstance: GameInstance) -> ref<ImmersiveFootwearPOVSystem> {
    let system: ref<ImmersiveFootwearPOVSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem") as ImmersiveFootwearPOVSystem;
    return system;
  }

  // -----------------------------------------------------------------------------
  // Lifecycle Handlers
  // -----------------------------------------------------------------------------
  private final func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(request.owner.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      this.m_isInitialized = false;
      this.UpdateEquippedFootwear(player);
    };
  }

  public final func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if IsDefined(player) {
      this.m_isInitialized = false;
      this.UpdateEquippedFootwear(player);
    };
  }

  // -----------------------------------------------------------------------------
  // Footwear Resolution & Height Update
  // -----------------------------------------------------------------------------
  public func UpdateEquippedFootwear(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) {
      return;
    };

    let result: ref<FootwearResolutionResult> = FootwearResolver.ResolveFootwear(player);

    if !this.m_isInitialized || NotEquals(result.itemID, this.m_equippedFootwearID) {
      this.m_isInitialized = true;
      this.m_equippedFootwearID = result.itemID;
      this.m_activeSource = result.sourceName;
      this.m_hasCustomOverride = false;
      this.m_customHeelHeight = 0.0;
      this.m_customPlatformHeight = 0.0;

      if ItemID.IsValid(result.itemID) {
        let heightData: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(result.itemID);
        
        if heightData.heelHeight > 0.0 || heightData.platformHeight > 0.0 {
          this.m_hasOfficialTags = true;
          this.m_currentHeelHeight = heightData.heelHeight;
          this.m_currentPlatformHeight = heightData.platformHeight;
        } else {
          this.m_hasOfficialTags = false;
          this.m_currentHeelHeight = 0.0;
          this.m_currentPlatformHeight = 0.0;
        };
      } else {
        this.m_hasOfficialTags = false;
        this.m_currentHeelHeight = 0.0;
        this.m_currentPlatformHeight = 0.0;
      };

      this.RecalculateEffectiveOffset(player);
    } else {
      this.RecalculateEffectiveOffset(player);
    };
    this.LogTFPState(player);
  }

  public func RecalculateEffectiveOffset(player: ref<PlayerPuppet>) -> Void {
    let suppressed: Bool = this.EvaluateSuppressionState(player);

    if suppressed {
      this.m_effectiveOffset = 0.0;
    } else {
      this.m_effectiveOffset = this.m_currentHeelHeight;
    };

    let effectivePlatform: Float = suppressed ? 0.0 : this.m_currentPlatformHeight;

    if IsDefined(player) {
      HeightController.ApplyHeightOffset(player, this.m_effectiveOffset);
      TFPHelper.ApplyFootwearHeight(player.GetGame());
      if ITPController.IsTPPActive(player) {
        ITPController.ApplyHeightOffset(player, effectivePlatform);
      } else {
        ITPController.ResetHeightOffset(player);
      };
    };
  }

  // -----------------------------------------------------------------------------
  // Custom Overrides (Untagged Mod Footwear & Testing)
  // -----------------------------------------------------------------------------
  public func SetCustomHeightOverride(player: ref<PlayerPuppet>, heel: Float, platform: Float, opt force: Bool) -> Void {
    if this.m_hasOfficialTags && !force {
      return;
    };

    this.m_hasCustomOverride = true;
    this.m_customHeelHeight = ShoeHeightParser.ClampHeight(heel);
    this.m_customPlatformHeight = ShoeHeightParser.ClampHeight(platform);
    this.m_currentHeelHeight = this.m_customHeelHeight;
    this.m_currentPlatformHeight = this.m_customPlatformHeight;

    this.RecalculateEffectiveOffset(player);
  }

  public func ClearCustomHeightOverride(player: ref<PlayerPuppet>, opt force: Bool) -> Void {
    if !this.m_hasOfficialTags || force {
      this.m_hasCustomOverride = false;
      this.m_customHeelHeight = 0.0;
      this.m_customPlatformHeight = 0.0;
      if !this.m_hasOfficialTags {
        this.m_currentHeelHeight = 0.0;
        this.m_currentPlatformHeight = 0.0;
      } else {
        let data: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(this.m_equippedFootwearID);
        this.m_currentHeelHeight = data.heelHeight;
        this.m_currentPlatformHeight = data.platformHeight;
      };
      this.RecalculateEffectiveOffset(player);
    };
  }

  // -----------------------------------------------------------------------------
  // Suppression State Management & Delegation
  // -----------------------------------------------------------------------------
  public func EvaluateSuppressionState(player: ref<PlayerPuppet>) -> Bool {
    return SuppressionEvaluator.Evaluate(this, player);
  }

  public func SetSuppressionState(suppressed: Bool, reason: String) -> Bool {
    this.m_isSuppressed = suppressed;
    this.m_suppressionReason = reason;
    return this.m_isSuppressed;
  }

  public func SetVehicleState(player: ref<PlayerPuppet>, inVehicle: Bool) -> Void {
    if Equals(this.m_isInVehicle, inVehicle) { return; };
    this.m_isInVehicle = inVehicle;
    this.RecalculateEffectiveOffset(player);
    if IsDefined(player) {
      let eventName: String = inVehicle ? "VehicleEntered (Vehicle Occupancy)" : "VehicleExited (Restored)";
      this.LogTFPEvent(eventName, 0.0, 0.0);
      this.LogTFPState(player);
    };
  }

  public func SetWorkspotState(player: ref<PlayerPuppet>, inWorkspot: Bool) -> Void {
    if Equals(this.m_isInWorkspot, inWorkspot) { return; };
    this.m_isInWorkspot = inWorkspot;
    this.RecalculateEffectiveOffset(player);
    if IsDefined(player) {
      let eventName: String = inWorkspot ? "WorkspotStarted (Sitting/Furniture)" : "WorkspotFinished (Standing/Exited)";
      this.LogTFPEvent(eventName, 0.0, 0.0);
      this.LogTFPState(player);
    };
  }

  public func OnWeaponAction(player: ref<PlayerPuppet>, actionName: String) -> Void {
    if !IsDefined(player) { return; };
    TFPHelper.SyncWeaponForCurrentFootwear(player.GetGame());
    this.LogTFPEvent(s"WeaponAction (\(actionName))", 0.0, 0.0);
    this.LogTFPState(player);
  }

  // -----------------------------------------------------------------------------
  // State Queries & Getters
  // -----------------------------------------------------------------------------
  public func IsSuppressed() -> Bool { return this.m_isSuppressed; }
  public func GetSuppressionReason() -> String { return this.m_suppressionReason; }
  public func GetCurrentHeelHeight() -> Float { return this.m_currentHeelHeight; }
  public func GetCurrentPlatformHeight() -> Float { return this.m_currentPlatformHeight; }
  public func GetCurrentShoeHeight() -> Float { return this.m_currentHeelHeight; }
  public func GetEffectiveOffset() -> Float { return this.m_effectiveOffset; }
  public func GetEffectivePlatformOffset() -> Float {
    if this.m_isSuppressed {
      return 0.0;
    };
    return this.m_currentPlatformHeight;
  }
  public func HasOfficialTweakTags() -> Bool { return this.m_hasOfficialTags; }
  public func HasCustomOverride() -> Bool { return this.m_hasCustomOverride; }
  public func GetBodyOffset(player: ref<PlayerPuppet>) -> Float { return this.m_effectiveOffset; }
  public func GetEquippedFootwearID() -> ItemID { return this.m_equippedFootwearID; }
  public func GetActiveSource() -> String { return this.m_activeSource; }
  public func IsInVehicle() -> Bool { return this.m_isInVehicle; }
  public func IsInWorkspot() -> Bool { return this.m_isInWorkspot; }
  public func IsDebugLogging() -> Bool { return this.m_debugLogging; }
  public func SetDebugLogging(enable: Bool) -> Void { this.m_debugLogging = enable; }
  public func IsPhotoModeActive() -> Bool {
    let pmSys: ref<PhotoModeSystem> = GameInstance.GetPhotoModeSystem(this.GetGameInstance());
    if IsDefined(pmSys) {
      return pmSys.IsPhotoModeActive();
    };
    return this.m_isPhotoModeActive;
  }
  public func SetPhotoModeActive(active: Bool) -> Void { this.m_isPhotoModeActive = active; }
  public func IsIFPPresent() -> Bool { return this.m_isIFPPresent; }
  public func SetIFPPresent(present: Bool) -> Void { this.m_isIFPPresent = present; }
  public func SetITPPresent(present: Bool) -> Void { this.m_isITPPresent = present; }

  // -----------------------------------------------------------------------------
  // TFP Weapon Synchronization Tracking
  // -----------------------------------------------------------------------------
  public func GetTFPLastWeaponKey() -> String { return this.m_tfpLastWeaponKey; }
  public func SetTFPLastWeaponKey(key: String) -> Void { this.m_tfpLastWeaponKey = key; }
  public func GetTFPLastWeaponBaseZ() -> Float { return this.m_tfpLastWeaponBaseZ; }
  public func SetTFPLastWeaponBaseZ(baseZ: Float) -> Void { this.m_tfpLastWeaponBaseZ = baseZ; }
  public func GetTFPLastAppliedWeaponLift() -> Float { return this.m_tfpLastAppliedWeaponLift; }
  public func SetTFPLastAppliedWeaponLift(lift: Float) -> Void { this.m_tfpLastAppliedWeaponLift = lift; }

  // -----------------------------------------------------------------------------
  // TFP Telemetry Tracking State
  // -----------------------------------------------------------------------------
  public func GetTFPLastLoggedFootwear() -> ItemID { return this.m_tfpLastLoggedFootwear; }
  public func GetTFPLastLoggedOffset() -> Float { return this.m_tfpLastLoggedOffset; }
  public func GetTFPLastLoggedSuppressed() -> Bool { return this.m_tfpLastLoggedSuppressed; }
  public func SetTFPLastLoggedState(item: ItemID, offset: Float, suppressed: Bool) -> Void {
    this.m_tfpLastLoggedFootwear = item;
    this.m_tfpLastLoggedOffset = offset;
    this.m_tfpLastLoggedSuppressed = suppressed;
  }

  // -----------------------------------------------------------------------------
  // Display & Localization Helpers
  // -----------------------------------------------------------------------------
  public func GetResolvedShoeTDBIDString() -> String {
    if ItemID.IsValid(this.m_equippedFootwearID) {
      return TDBID.ToStringDEBUG(ItemID.GetTDBID(this.m_equippedFootwearID));
    };
    return "";
  }

  public func GetResolvedShoeDisplayName() -> String {
    if ItemID.IsValid(this.m_equippedFootwearID) {
      let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(this.m_equippedFootwearID));
      if IsDefined(record) {
        let locKey: CName = record.DisplayName();
        if IsNameValid(locKey) {
          let locName: String = GetLocalizedTextByKey(locKey);
          if StrLen(locName) > 0 {
            return locName;
          };
        };
        return TDBID.ToStringDEBUG(ItemID.GetTDBID(this.m_equippedFootwearID));
      };
    };
    return "None";
  }

  // -----------------------------------------------------------------------------
  // Public ShoeHeightParser Helpers (Exposed to CET Lua)
  // -----------------------------------------------------------------------------
  public func ReadPlatformHeightFromItemID(itemID: ItemID) -> Float {
    return ShoeHeightParser.ReadPlatformHeight(itemID);
  }

  public func ReadHeelHeightFromItemID(itemID: ItemID) -> Float {
    return ShoeHeightParser.ReadHeelHeight(itemID);
  }

  public func ReadPlatformHeightFromTDBID(tdbid: TweakDBID) -> Float {
    return ShoeHeightParser.ReadShoeHeightDataFromTDBID(tdbid).platformHeight;
  }

  public func ReadHeelHeightFromTDBID(tdbid: TweakDBID) -> Float {
    return ShoeHeightParser.ReadShoeHeightDataFromTDBID(tdbid).heelHeight;
  }

  public func ReadFootwearFromEquipmentExOutfit(outfitName: CName) -> ItemID {
    return EquipmentExHelper.GetFootwearFromOutfit(this.GetGameInstance(), outfitName);
  }

  // -----------------------------------------------------------------------------
  // Framework Detection & Active Mod Tagging
  // -----------------------------------------------------------------------------
  public func IsTFPPresent() -> Bool {
    return FrameworkDetector.IsTFPPresent();
  }

  public func IsEquipmentExPresent() -> Bool {
    return EquipmentExDetector.IsPresent();
  }

  public func IsITPPresent() -> Bool {
    if this.m_isITPPresent {
      return true;
    };
    return ITPDetector.IsPresent(this.GetGameInstance());
  }

  public func GetActiveModTag(opt player: ref<PlayerPuppet>) -> String {
    if this.IsPhotoModeActive() {
      return "PM";
    };

    if this.IsITPPresent() {
      return "ITP";
    };

    if this.IsTFPPresent() {
      return "TFP";
    };

    if this.m_isIFPPresent {
      return "IFP";
    };

    return "PM";
  }

  // -----------------------------------------------------------------------------
  // Centralized Logging Delegation (Used by CET and internal callers)
  // -----------------------------------------------------------------------------
  public func LogFromCET(tag: String, message: String) -> Void {
    let activeTag: String = StrLen(tag) > 0 ? tag : this.GetActiveModTag(null);
    FootwearRedLogger.LogInfo(activeTag, message);
  }

  public func LogLevelFromCET(level: String, tag: String, message: String) -> Void {
    let activeTag: String = StrLen(tag) > 0 ? tag : this.GetActiveModTag(null);
    FootwearRedLogger.Append(level, activeTag, message);
  }

  // -----------------------------------------------------------------------------
  // Telemetry Logger Delegation
  // -----------------------------------------------------------------------------
  public func LogTFPEvent(eventName: String, baseZ: Float, curZ: Float) -> Void {
    FootwearTelemetryLogger.LogTFPEvent(this, eventName, baseZ, curZ);
  }

  public func LogTFPPolling(baseZ: Float, curZ: Float) -> Void {
    FootwearTelemetryLogger.LogTFPPolling(this, baseZ, curZ);
  }

  public func LogTFPState(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) || !this.m_debugLogging { return; };
    TFPHelper.LogState(player);
  }
}
