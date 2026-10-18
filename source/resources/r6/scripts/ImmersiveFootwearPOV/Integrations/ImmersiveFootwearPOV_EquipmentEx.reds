module ImmersiveFootwearPOV

@if(ModuleExists("EquipmentEx"))
import EquipmentEx.OutfitSystem

// -----------------------------------------------------------------------------
// 3rd-Party Integration: Equipment-EX (Active Module Implementation)
// -----------------------------------------------------------------------------
@if(ModuleExists("EquipmentEx"))
public class EquipmentExHelper {

  /**
   * Resolves the currently equipped footwear ItemID from Equipment-EX's active OutfitSystem.
   * Checks the default Feet slot first, then inspects occupied slots for items with heel data.
   * @param player The local player puppet reference.
   * @return The equipped footwear ItemID, or ItemID.None() if no footwear found.
   */
  public static func GetActiveFootwear(player: ref<PlayerPuppet>) -> ItemID {
    if !IsDefined(player) {
      return ItemID.None();
    };

    let outfitSys: ref<OutfitSystem> = OutfitSystem.GetInstance(player.GetGame());
    if !IsDefined(outfitSys) || !outfitSys.IsActive() {
      return ItemID.None();
    };

    let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    if !IsDefined(transactionSystem) {
      return ItemID.None();
    };

    // 1. Check primary extra OutfitSlots.Feet slot
    let feetObject: ref<ItemObject> = transactionSystem.GetItemInSlot(player, t"OutfitSlots.Feet");
    if IsDefined(feetObject) {
      let feetID: ItemID = feetObject.GetItemID();
      if ItemID.IsValid(feetID) {
        return feetID;
      };
    };

    // 2. Check base AttachmentSlots.Feet slot (where Equipment-EX equips standard shoes)
    let baseFeetObject: ref<ItemObject> = transactionSystem.GetItemInSlot(player, t"AttachmentSlots.Feet");
    if IsDefined(baseFeetObject) {
      let baseFeetID: ItemID = baseFeetObject.GetItemID();
      if ItemID.IsValid(baseFeetID) {
        return baseFeetID;
      };
    };

    // 3. Scan all occupied outfit slots in case footwear was assigned to a custom/alternate slot
    let usedSlots: array<TweakDBID> = outfitSys.GetUsedSlots();
    let count: Int32 = ArraySize(usedSlots);
    if count == 0 {
      return ItemID.None();
    };

    let i: Int32 = 0;
    let slotObj: ref<ItemObject>;
    let slotItem: ItemID;

    while i < count {
      let slotID: TweakDBID = usedSlots[i];
      if NotEquals(slotID, t"OutfitSlots.Feet") && NotEquals(slotID, t"AttachmentSlots.Feet") {
        slotObj = transactionSystem.GetItemInSlot(player, slotID);
        if IsDefined(slotObj) {
          slotItem = slotObj.GetItemID();
          if ItemID.IsValid(slotItem) {
            if EquipmentExHelper.IsFootwearItem(slotItem)
              || ShoeHeightParser.ReadHeelHeight(slotItem) > 0.0
              || ShoeHeightParser.ReadPlatformHeight(slotItem) > 0.0 {
              return slotItem;
            };
          };
        };
      };
      i += 1;
    };

    return ItemID.None();
  }

  /**
   * Helper to verify if an item belongs to the Feet equipment area in TweakDB.
   * @param itemID The ItemID to inspect.
   * @return True if the item is classified as footwear, false otherwise.
   */
  public static func IsFootwearItem(itemID: ItemID) -> Bool {
    if !ItemID.IsValid(itemID) {
      return false;
    };
    let rec: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemID));
    if !IsDefined(rec) || !IsDefined(rec.EquipArea()) {
      return false;
    };
    return Equals(rec.EquipArea().Type(), gamedataEquipmentArea.Feet);
  }

  /**
   * Resolves footwear ItemID directly from a specific Equipment-EX outfit if currently equipped.
   * @param game The active GameInstance.
   * @param outfitName Name of the outfit record.
   * @return The active footwear ItemID from the outfit, or ItemID.None() if unequipped.
   */
  public static func GetFootwearFromOutfit(game: GameInstance, outfitName: CName) -> ItemID {
    if !IsNameValid(outfitName) {
      return ItemID.None();
    };
    let outfitSys: ref<OutfitSystem> = OutfitSystem.GetInstance(game);
    if !IsDefined(outfitSys) || !outfitSys.IsEquipped(outfitName) {
      return ItemID.None();
    };

    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(game).GetLocalPlayerMainGameObject() as PlayerPuppet;
    if !IsDefined(player) {
      return ItemID.None();
    };
    return EquipmentExHelper.GetActiveFootwear(player);
  }

  /**
   * Checks whether Equipment-EX is installed and actively controlling outfits for the player.
   * @param player The local player puppet reference.
   * @return True if Equipment-EX OutfitSystem is active, false otherwise.
   */
  public static func IsEquipmentExActive(player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) {
      return false;
    };
    let outfitSys: ref<OutfitSystem> = OutfitSystem.GetInstance(player.GetGame());
    return IsDefined(outfitSys) && outfitSys.IsActive();
  }
}

// -----------------------------------------------------------------------------
// 3rd-Party Integration: Equipment-EX (Fallback when Mod is Not Installed)
// -----------------------------------------------------------------------------
@if(!ModuleExists("EquipmentEx"))
public class EquipmentExHelper {

  /**
   * Fallback resolution when Equipment-EX is not installed.
   * @param player The local player puppet reference.
   * @return Always returns ItemID.None().
   */
  public static func GetActiveFootwear(player: ref<PlayerPuppet>) -> ItemID {
    return ItemID.None();
  }

  /**
   * Fallback outfit query when Equipment-EX is not installed.
   * @param game The active GameInstance.
   * @param outfitName Name of the outfit record.
   * @return Always returns ItemID.None().
   */
  public static func GetFootwearFromOutfit(game: GameInstance, outfitName: CName) -> ItemID {
    return ItemID.None();
  }

  /**
   * Fallback active check when Equipment-EX is not installed.
   * @param player The local player puppet reference.
   * @return Always returns false.
   */
  public static func IsEquipmentExActive(player: ref<PlayerPuppet>) -> Bool {
    return false;
  }

  /**
   * Fallback footwear item check when Equipment-EX is not installed.
   * @param itemID The ItemID to inspect.
   * @return Always returns false.
   */
  public static func IsFootwearItem(itemID: ItemID) -> Bool {
    return false;
  }
}
