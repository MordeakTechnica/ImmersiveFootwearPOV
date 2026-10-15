module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Footwear Resolution Pipeline
// Design Pattern: Chain of Responsibility
// Single Responsibility Principle (SRP): Each handler evaluates exactly one footwear layer
// Open/Closed Principle (OCP): New outfit or equipment mods can be registered without altering core logic
// =============================================================================

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

// -----------------------------------------------------------------------------
// Base Handler for Chain of Responsibility
// -----------------------------------------------------------------------------
public abstract class FootwearResolutionHandler {
  protected let m_nextHandler: ref<FootwearResolutionHandler>;

  public func SetNext(handler: ref<FootwearResolutionHandler>) -> ref<FootwearResolutionHandler> {
    this.m_nextHandler = handler;
    return handler;
  }

  public func Handle(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    let result: ref<FootwearResolutionResult> = this.Resolve(player);
    if IsDefined(result) {
      return result;
    };
    if IsDefined(this.m_nextHandler) {
      return this.m_nextHandler.Handle(player);
    };
    return FootwearResolutionResult.Create(ItemID.None(), "None (End of Chain)");
  }

  protected func Resolve(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    return null;
  }
}

// -----------------------------------------------------------------------------
// Priority 1 Handler: Equipment-EX Mod OutfitSystem
// -----------------------------------------------------------------------------
public class EquipmentExResolutionHandler extends FootwearResolutionHandler {
  protected func Resolve(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    if EquipmentExHelper.IsEquipmentExActive(player) {
      let exItem: ItemID = EquipmentExHelper.GetActiveFootwear(player);
      if ItemID.IsValid(exItem) {
        return FootwearResolutionResult.Create(exItem, "Equipment-EX");
      };
      // If Equipment-EX is active but has no footwear slotted, V is wearing bare feet / flat in the outfit.
      // Do NOT fall through to underlying gameplay equipment.
      return FootwearResolutionResult.Create(ItemID.None(), "Equipment-EX (Bare Feet / Flat)");
    };
    return null;
  }
}

// -----------------------------------------------------------------------------
// Priority 2 Handler: Vanilla Transmog / Wardrobe Appearance Slot
// -----------------------------------------------------------------------------
public class WardrobeResolutionHandler extends FootwearResolutionHandler {
  protected func Resolve(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    let equipSystem: ref<EquipmentSystem> = EquipmentSystem.GetInstance(player);
    if IsDefined(equipSystem) {
      let visualItem: ItemID = equipSystem.GetActiveVisualItem(player, gamedataEquipmentArea.Feet);
      if ItemID.IsValid(visualItem) {
        return FootwearResolutionResult.Create(visualItem, "Vanilla Wardrobe");
      };
    };
    return null;
  }
}

// -----------------------------------------------------------------------------
// Priority 3 Handler: Standard Gameplay Equipment Slot
// -----------------------------------------------------------------------------
public class GameplaySlotResolutionHandler extends FootwearResolutionHandler {
  protected func Resolve(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    let equipSystem: ref<EquipmentSystem> = EquipmentSystem.GetInstance(player);
    if IsDefined(equipSystem) {
      let gameplayItem: ItemID = equipSystem.GetActiveItem(player, gamedataEquipmentArea.Feet);
      if ItemID.IsValid(gameplayItem) {
        return FootwearResolutionResult.Create(gameplayItem, "Gameplay Equipment Slot");
      };
    };
    return null;
  }
}

// -----------------------------------------------------------------------------
// Fallback Handler: Barefoot / Unequipped
// -----------------------------------------------------------------------------
public class BarefootFallbackHandler extends FootwearResolutionHandler {
  protected func Resolve(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    return FootwearResolutionResult.Create(ItemID.None(), "None (Unequipped)");
  }
}

// -----------------------------------------------------------------------------
// Footwear Resolver Pipeline Orchestrator (Facade)
// -----------------------------------------------------------------------------
public class FootwearResolver {

  public static func CreateChain() -> ref<FootwearResolutionHandler> {
    let eqEx: ref<EquipmentExResolutionHandler> = new EquipmentExResolutionHandler();
    let wardrobe: ref<WardrobeResolutionHandler> = new WardrobeResolutionHandler();
    let slot: ref<GameplaySlotResolutionHandler> = new GameplaySlotResolutionHandler();
    let barefoot: ref<BarefootFallbackHandler> = new BarefootFallbackHandler();

    eqEx.SetNext(wardrobe);
    wardrobe.SetNext(slot);
    slot.SetNext(barefoot);

    return eqEx;
  }

  // Resolves currently visible footwear using the Chain of Responsibility
  public static func ResolveFootwear(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    if !IsDefined(player) {
      return FootwearResolutionResult.Create(ItemID.None(), "None (Invalid Player)");
    };
    return FootwearResolver.CreateChain().Handle(player);
  }
}
