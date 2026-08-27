module ImmersiveFootwearPOV

// -----------------------------------------------------------------------------
// Footwear Resolution Pipeline
// Orchestrates priority between 3rd-party mods (Equipment-EX), Wardrobe, and Equipment
// -----------------------------------------------------------------------------
public class FootwearResolutionResult {
  public let itemID: ItemID;
  public let sourceName: String;

  public static func Create(itemID: ItemID, sourceName: String) -> ref<FootwearResolutionResult> {
    let res: ref<FootwearResolutionResult> = new FootwearResolutionResult();
    res.itemID = itemID;
    res.sourceName = sourceName;
    return res;
  }
}

public class FootwearResolver {

  // Resolves currently visible footwear using the prioritized hierarchy
  public static func ResolveFootwear(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    if !IsDefined(player) {
      return FootwearResolutionResult.Create(ItemID.None(), "None (Invalid Player)");
    };

    // Priority 1: 3rd-Party Equipment-EX OutfitSystem
    // When Equipment-EX is active, it strictly controls the visual outfit layers.
    if EquipmentExHelper.IsEquipmentExActive(player) {
      let exItem: ItemID = EquipmentExHelper.GetActiveFootwear(player);
      if ItemID.IsValid(exItem) {
        return FootwearResolutionResult.Create(exItem, "Equipment-EX");
      };
      // If Equipment-EX is active but has no footwear slotted, V is wearing bare feet / flat in the outfit.
      // Do NOT fall through to underlying gameplay equipment.
      return FootwearResolutionResult.Create(ItemID.None(), "Equipment-EX (Bare Feet / Flat)");
    };

    let equipSystem: ref<EquipmentSystem> = EquipmentSystem.GetInstance(player);
    if IsDefined(equipSystem) {
      // Priority 2: Vanilla Transmog / Wardrobe Appearance Slot
      let visualItem: ItemID = equipSystem.GetActiveVisualItem(player, gamedataEquipmentArea.Feet);
      if ItemID.IsValid(visualItem) {
        return FootwearResolutionResult.Create(visualItem, "Vanilla Wardrobe");
      };

      // Priority 3: Standard Gameplay Equipment Slot
      let gameplayItem: ItemID = equipSystem.GetActiveItem(player, gamedataEquipmentArea.Feet);
      if ItemID.IsValid(gameplayItem) {
        return FootwearResolutionResult.Create(gameplayItem, "Gameplay Equipment Slot");
      };
    };

    return FootwearResolutionResult.Create(ItemID.None(), "None (Unequipped)");
  }
}
