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

    // 1. Check primary OutfitSlots.Feet slot
    let feetItem: ItemID = outfitSys.GetEquippedItemInSlot(t"OutfitSlots.Feet");
    if ItemID.IsValid(feetItem) {
      return feetItem;
    };

    // 2. Scan all occupied outfit slots in case footwear was assigned to a custom/alternate slot
    let usedSlots: array<TweakDBID> = outfitSys.GetUsedSlots();
    let count: Int32 = ArraySize(usedSlots);
    let i: Int32 = 0;
    let slotItem: ItemID;

    while i < count {
      slotItem = outfitSys.GetEquippedItemInSlot(usedSlots[i]);
      if ItemID.IsValid(slotItem) && ShoeHeightParser.ReadShoeHeight(slotItem) > 0.0 {
        return slotItem;
      };
      i += 1;
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

  public static func IsEquipmentExActive(player: ref<PlayerPuppet>) -> Bool {
    return false;
  }
}
