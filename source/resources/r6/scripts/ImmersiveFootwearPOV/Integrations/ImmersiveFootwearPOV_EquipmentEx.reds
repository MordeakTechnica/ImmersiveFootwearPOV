module ImmersiveFootwearPOV

@if(ModuleExists("EquipmentEx"))
import EquipmentEx.OutfitSystem

// -----------------------------------------------------------------------------
// 3rd-Party Integration: Equipment-EX (Active Module Implementation)
// -----------------------------------------------------------------------------
@if(ModuleExists("EquipmentEx"))
public class EquipmentExHelper {

  // Resolves the currently equipped footwear from Equipment-EX's OutfitSystem
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

    // 1. Check primary OutfitSlots.Feet slot
    let feetObject: ref<ItemObject> = transactionSystem.GetItemInSlot(player, t"OutfitSlots.Feet");
    if IsDefined(feetObject) {
      let feetID: ItemID = feetObject.GetItemID();
      if ItemID.IsValid(feetID) {
        return feetID;
      };
    };

    // 2. Scan all occupied outfit slots in case footwear was assigned to a custom/alternate slot
    let usedSlots: array<TweakDBID> = outfitSys.GetUsedSlots();
    let count: Int32 = ArraySize(usedSlots);
    let i: Int32 = 0;
    let slotObj: ref<ItemObject>;
    let slotItem: ItemID;

    while i < count {
      slotObj = transactionSystem.GetItemInSlot(player, usedSlots[i]);
      if IsDefined(slotObj) {
        slotItem = slotObj.GetItemID();
        if ItemID.IsValid(slotItem) && ShoeHeightParser.ReadShoeHeight(slotItem) > 0.0 {
          return slotItem;
        };
      };
      i += 1;
    };

    return ItemID.None();
  }

  // Resolves footwear ItemID directly from an Equipment-EX outfit if currently equipped
  public static func GetFootwearFromOutfit(game: GameInstance, outfitName: CName) -> ItemID {
    let outfitSys: ref<OutfitSystem> = OutfitSystem.GetInstance(game);
    if !IsDefined(outfitSys) {
      return ItemID.None();
    };

    if outfitSys.IsEquipped(outfitName) {
      let feetID: ItemID = outfitSys.GetEquippedItemInSlot(t"OutfitSlots.Feet");
      if ItemID.IsValid(feetID) {
        return feetID;
      };
    };

    return ItemID.None();
  }

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

  public static func GetActiveFootwear(player: ref<PlayerPuppet>) -> ItemID {
    return ItemID.None();
  }

  public static func GetFootwearFromOutfit(game: GameInstance, outfitName: CName) -> ItemID {
    return ItemID.None();
  }

  public static func IsEquipmentExActive(player: ref<PlayerPuppet>) -> Bool {
    return false;
  }
}
