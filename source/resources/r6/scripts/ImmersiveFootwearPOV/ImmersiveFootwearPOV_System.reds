module ImmersiveFootwearPOV

public class ImmersiveFootwearPOVSystem extends ScriptableSystem {

  private let m_currentHeelHeight: Float;      // Active FPP elevation height
  private let m_currentPlatformHeight: Float;  // Secondary platform height (reserved for PM)
  private let m_effectiveOffset: Float;
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
  private let m_tfpLastLoggedFootwear: ItemID;
  private let m_tfpLastLoggedOffset: Float;
  private let m_tfpLastLoggedSuppressed: Bool;
  private let m_tfpLastWeaponKey: String;
  private let m_tfpLastAppliedWeaponLift: Float;

  public static func GetInstance(gameInstance: GameInstance) -> ref<ImmersiveFootwearPOVSystem> {
    let system: ref<ImmersiveFootwearPOVSystem> = GameInstance.GetScriptableSystemsContainer(gameInstance).Get(n"ImmersiveFootwearPOV.ImmersiveFootwearPOVSystem") as ImmersiveFootwearPOVSystem;
    return system;
  }

  public func SetDebugLogging(enable: Bool) -> Void {
    this.m_debugLogging = enable;
  }

  public func IsDebugLogging() -> Bool {
    return this.m_debugLogging;
  }

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

  // Updates current shoe heights via the FootwearResolver pipeline
  // Prioritizes official TweakDB tags over custom overrides
  public func UpdateEquippedFootwear(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) {
      return;
    };

    let result: ref<FootwearResolutionResult> = FootwearResolver.ResolveFootwear(player);

    // If item changed or not yet initialized
    if !this.m_isInitialized || NotEquals(result.itemID, this.m_equippedFootwearID) {
      this.m_isInitialized = true;
      this.m_equippedFootwearID = result.itemID;
      this.m_activeSource = result.sourceName;
      this.m_hasCustomOverride = false;
      this.m_customHeelHeight = 0.0;
      this.m_customPlatformHeight = 0.0;

      if ItemID.IsValid(result.itemID) {
        let heightData: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(result.itemID);
        
        // Check if official TweakDB tags exist
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
  }

  // Applies a custom user override when no official TweakDB tags are present
  public func SetCustomHeightOverride(player: ref<PlayerPuppet>, heel: Float, platform: Float) -> Void {
    // If shoe has official TweakDB tags, ignore custom override
    if this.m_hasOfficialTags {
      return;
    };

    this.m_hasCustomOverride = true;
    this.m_customHeelHeight = ShoeHeightParser.ClampHeight(heel);
    this.m_customPlatformHeight = ShoeHeightParser.ClampHeight(platform);
    this.m_currentHeelHeight = this.m_customHeelHeight;
    this.m_currentPlatformHeight = this.m_customPlatformHeight;

    this.RecalculateEffectiveOffset(player);
  }

  // Clears active custom override
  public func ClearCustomHeightOverride(player: ref<PlayerPuppet>) -> Void {
    if !this.m_hasOfficialTags {
      this.m_hasCustomOverride = false;
      this.m_customHeelHeight = 0.0;
      this.m_customPlatformHeight = 0.0;
      this.m_currentHeelHeight = 0.0;
      this.m_currentPlatformHeight = 0.0;
      this.RecalculateEffectiveOffset(player);
    };
  }

  public func SetVehicleState(player: ref<PlayerPuppet>, inVehicle: Bool) -> Void {
    if Equals(this.m_isInVehicle, inVehicle) {
      return;
    };
    this.m_isInVehicle = inVehicle;
    this.RecalculateEffectiveOffset(player);
  }

  public func SetWorkspotState(player: ref<PlayerPuppet>, inWorkspot: Bool) -> Void {
    if Equals(this.m_isInWorkspot, inWorkspot) {
      return;
    };
    this.m_isInWorkspot = inWorkspot;
    this.RecalculateEffectiveOffset(player);
  }

  // Evaluates all suppression contexts (vehicles, workspots, high scene tiers, traversal states)
  public func EvaluateSuppressionState(player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) {
      return false;
    };

    // 1. Vehicles
    if this.m_isInVehicle || VehicleComponent.IsMountedToVehicle(player.GetGame(), player) {
      return this.SetSuppression(true, "Vehicle Occupancy");
    };

    // 2. Workspots / Furniture (sitting on chairs, barstools, sofas, beds)
    if this.m_isInWorkspot || GameInstance.GetWorkspotSystem(player.GetGame()).IsActorInWorkspot(player) {
      return this.SetSuppression(true, "Authored Workspot");
    };

    let psmBlackboard: ref<IBlackboard> = player.GetPlayerStateMachineBlackboard();
    if !IsDefined(psmBlackboard) {
      return this.SetSuppression(false, "");
    };

    let psmDefs: ref<PlayerStateMachineDef> = GetAllBlackboardDefs().PlayerStateMachine;

    // 3. Scripted Quest Scenes & High Dialogue Tiers (Tier >= 3 or <= 0)
    let sceneTier: Int32 = psmBlackboard.GetInt(psmDefs.SceneTier);
    if sceneTier >= 3 || sceneTier <= 0 {
      return this.SetSuppression(true, "Scripted Scene / Dialogue");
    };

    // 4. Locomotion Traversal & Special Actions (Climb, Vault, Ladder, Knockdown)
    let detailedLoco: Int32 = psmBlackboard.GetInt(psmDefs.LocomotionDetailed);
    if detailedLoco >= 8 && detailedLoco <= 13 {
      return this.SetSuppression(true, "Climb, Vault, or Ladder");
    };
    if detailedLoco == 29 || detailedLoco == 31 {
      return this.SetSuppression(true, "Knockdown or Forced Reaction");
    };

    // 5. Swimming
    let highLevel: Int32 = psmBlackboard.GetInt(psmDefs.HighLevel);
    let swimmingState: Int32 = psmBlackboard.GetInt(psmDefs.Swimming);
    if highLevel == 6 || swimmingState > 0 {
      return this.SetSuppression(true, "Swimming");
    };

    // 6. Combat / Action Locks (Takedown, Body Carrying)
    if psmBlackboard.GetInt(psmDefs.Takedown) > 0 {
      return this.SetSuppression(true, "Takedown or Grapple");
    };
    if psmBlackboard.GetInt(psmDefs.BodyCarrying) > 0 {
      return this.SetSuppression(true, "Body Carrying");
    };

    // No suppression active
    return this.SetSuppression(false, "");
  }

  private func SetSuppression(suppressed: Bool, reason: String) -> Bool {
    this.m_isSuppressed = suppressed;
    this.m_suppressionReason = reason;
    return this.m_isSuppressed;
  }

  public func RecalculateEffectiveOffset(player: ref<PlayerPuppet>) -> Void {
    let suppressed: Bool = this.EvaluateSuppressionState(player);

    if suppressed {
      this.m_effectiveOffset = 0.0;
    } else {
      this.m_effectiveOffset = this.m_currentHeelHeight;
    };

    if IsDefined(player) {
      HeightController.ApplyHeightOffset(player, this.m_effectiveOffset);
      TFPHelper.ApplyFootwearHeight(player.GetGame());
    };
  }

  public func IsSuppressed() -> Bool {
    return this.m_isSuppressed;
  }

  public func GetSuppressionReason() -> String {
    return this.m_suppressionReason;
  }

  public func GetCurrentHeelHeight() -> Float {
    return this.m_currentHeelHeight;
  }

  public func GetCurrentPlatformHeight() -> Float {
    return this.m_currentPlatformHeight;
  }

  public func GetCurrentShoeHeight() -> Float {
    return this.m_currentHeelHeight;
  }

  public func GetEffectiveOffset() -> Float {
    return this.m_effectiveOffset;
  }

  public func HasOfficialTweakTags() -> Bool {
    return this.m_hasOfficialTags;
  }

  public func HasCustomOverride() -> Bool {
    return this.m_hasCustomOverride;
  }

  public func GetBodyOffset(player: ref<PlayerPuppet>) -> Float {
    return this.m_effectiveOffset;
  }

  public func IsTFPPresent() -> Bool {
    return FrameworkDetector.IsTFPPresent();
  }

  public func GetTFPLastWeaponKey() -> String {
    return this.m_tfpLastWeaponKey;
  }

  public func SetTFPLastWeaponKey(key: String) -> Void {
    this.m_tfpLastWeaponKey = key;
  }

  public func GetTFPLastAppliedWeaponLift() -> Float {
    return this.m_tfpLastAppliedWeaponLift;
  }

  public func SetTFPLastAppliedWeaponLift(lift: Float) -> Void {
    this.m_tfpLastAppliedWeaponLift = lift;
  }


  public func GetEquippedFootwearID() -> ItemID {
    return this.m_equippedFootwearID;
  }

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

  public func GetActiveSource() -> String {
    return this.m_activeSource;
  }

  public func IsInVehicle() -> Bool {
    return this.m_isInVehicle;
  }

  public func IsInWorkspot() -> Bool {
    return this.m_isInWorkspot;
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
  // Framework Detection Helpers
  // -----------------------------------------------------------------------------
  public func IsTFPPresent() -> Bool {
    return FrameworkDetector.IsTFPPresent();
  }

  public func IsEquipmentExPresent() -> Bool {
    return EquipmentExDetector.IsPresent();
  }

  // -----------------------------------------------------------------------------
  // TFP Telemetry Logging Helpers
  // -----------------------------------------------------------------------------
  public func LogTFPEvent(eventName: String, baseZ: Float, curZ: Float) -> Void {
    if !this.m_debugLogging { return; };
    let offset: Float = this.m_effectiveOffset;
    let liftCm: Float = Cast<Float>(RoundF(offset * 1000.0)) / 10.0;
    let shoeName: String = this.GetResolvedShoeDisplayName();
    let suppressed: Bool = this.m_isSuppressed;
    let reason: String = this.m_suppressionReason;
    Log(s"[ImmersiveFootwearPOV][TFP] Event: \(eventName) | Footwear: '\(shoeName)' (+\(liftCm) cm) | TFP BaseZ: \(baseZ) | CamZ: \(curZ) | Suppressed: \(suppressed) (\(reason))");
  }

  public func LogTFPPolling(baseZ: Float, curZ: Float) -> Void {
    if !this.m_debugLogging { return; };

    let item: ItemID = this.m_equippedFootwearID;
    let offset: Float = this.m_effectiveOffset;
    let suppressed: Bool = this.m_isSuppressed;

    if NotEquals(item, this.m_tfpLastLoggedFootwear) || AbsF(offset - this.m_tfpLastLoggedOffset) > 0.0005 || NotEquals(suppressed, this.m_tfpLastLoggedSuppressed) {
      this.m_tfpLastLoggedFootwear = item;
      this.m_tfpLastLoggedOffset = offset;
      this.m_tfpLastLoggedSuppressed = suppressed;

      let liftCm: Float = Cast<Float>(RoundF(offset * 1000.0)) / 10.0;
      let shoeName: String = this.GetResolvedShoeDisplayName();
      let reason: String = this.m_suppressionReason;
      Log(s"[ImmersiveFootwearPOV][TFP] Camera State Transition -> Footwear: '\(shoeName)' | Lift: +\(liftCm) cm | TFP BaseZ: \(baseZ) | CamZ: \(curZ) | Suppressed: \(suppressed) (\(reason))");
    };
  }
}
