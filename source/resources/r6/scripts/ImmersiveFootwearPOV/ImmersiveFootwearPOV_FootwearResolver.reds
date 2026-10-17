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

  /**
   * Factory method constructing a footwear resolution result.
   * @param itemID The resolved footwear ItemID.
   * @param sourceName Description of the resolving layer (e.g. "Equipment-EX", "Vanilla Wardrobe").
   * @return A newly initialized FootwearResolutionResult.
   */
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

  /**
   * Links the subsequent resolution handler in the chain.
   * @param handler The next handler in priority sequence.
   * @return The linked handler to allow method chaining.
   */
  public func SetNext(handler: ref<FootwearResolutionHandler>) -> ref<FootwearResolutionHandler> {
    this.m_nextHandler = handler;
    return handler;
  }

  /**
   * Evaluates the current handler. If unresolved, forwards the request down the chain.
   * @param player The local player puppet reference.
   * @return The resolved FootwearResolutionResult.
   */
  public func Handle(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    if !IsDefined(player) {
      return FootwearResolutionResult.Create(ItemID.None(), "None (Invalid Player)");
    };
    let result: ref<FootwearResolutionResult> = this.Resolve(player);
    if IsDefined(result) {
      return result;
    };
    if !IsDefined(this.m_nextHandler) {
      return FootwearResolutionResult.Create(ItemID.None(), "None (End of Chain)");
    };
    return this.m_nextHandler.Handle(player);
  }

  /**
   * Performs layer-specific footwear resolution logic.
   * @param player The local player puppet reference.
   * @return Resolution result if handled by this layer, or null to delegate.
   */
  protected func Resolve(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    return null;
  }
}

// -----------------------------------------------------------------------------
// Priority 1 Handler: Equipment-EX Mod OutfitSystem
// -----------------------------------------------------------------------------
public class EquipmentExResolutionHandler extends FootwearResolutionHandler {
  /**
   * Resolves footwear from Equipment-EX active outfits. Prevents fall-through if active outfit is bare feet.
   * @param player The local player puppet reference.
   * @return Equipment-EX resolution result, or null if Equipment-EX is not active.
   */
  protected func Resolve(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    if !IsDefined(player) || !EquipmentExHelper.IsEquipmentExActive(player) {
      return null;
    };
    let exItem: ItemID = EquipmentExHelper.GetActiveFootwear(player);
    if ItemID.IsValid(exItem) {
      return FootwearResolutionResult.Create(exItem, "Equipment-EX");
    };
    // If Equipment-EX is active but has no footwear slotted, V is wearing bare feet / flat in the outfit.
    // Under the strict hierarchy (Equipment-EX -> Wardrobe -> Gameplay Slots), do NOT fall through.
    return FootwearResolutionResult.Create(ItemID.None(), "Equipment-EX");
  }
}

// -----------------------------------------------------------------------------
// Priority 2 Handler: Vanilla Transmog / Wardrobe Appearance Slot
// -----------------------------------------------------------------------------
public class WardrobeResolutionHandler extends FootwearResolutionHandler {
  /**
   * Resolves footwear from vanilla wardrobe visual transmog slots.
   * @param player The local player puppet reference.
   * @return Wardrobe visual item result, or null if no wardrobe footwear equipped.
   */
  protected func Resolve(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    if !IsDefined(player) {
      return null;
    };
    let equipSystem: ref<EquipmentSystem> = EquipmentSystem.GetInstance(player);
    if !IsDefined(equipSystem) {
      return null;
    };
    let visualItem: ItemID = equipSystem.GetActiveVisualItem(player, gamedataEquipmentArea.Feet);
    if ItemID.IsValid(visualItem) {
      return FootwearResolutionResult.Create(visualItem, "Vanilla Wardrobe");
    };

    let equipData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if !IsDefined(equipData) || !equipData.IsVisualSetActive() || !equipData.IsSlotOverriden(gamedataEquipmentArea.Feet) {
      return null;
    };
    return FootwearResolutionResult.Create(ItemID.None(), "Vanilla Wardrobe");
  }
}

// -----------------------------------------------------------------------------
// Priority 3 Handler: Standard Gameplay Equipment Slot
// -----------------------------------------------------------------------------
public class GameplaySlotResolutionHandler extends FootwearResolutionHandler {
  /**
   * Resolves footwear from standard gameplay equipment slots (inventory armor slot).
   * @param player The local player puppet reference.
   * @return Gameplay equipment slot item result, or null if empty.
   */
  protected func Resolve(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    if !IsDefined(player) {
      return null;
    };
    let equipSystem: ref<EquipmentSystem> = EquipmentSystem.GetInstance(player);
    if !IsDefined(equipSystem) {
      return null;
    };
    let gameplayItem: ItemID = equipSystem.GetActiveItem(player, gamedataEquipmentArea.Feet);
    if !ItemID.IsValid(gameplayItem) {
      return null;
    };
    return FootwearResolutionResult.Create(gameplayItem, "Gameplay Equipment Slot");
  }
}

// -----------------------------------------------------------------------------
// Fallback Handler: Barefoot / Unequipped
// -----------------------------------------------------------------------------
public class BarefootFallbackHandler extends FootwearResolutionHandler {
  /**
   * Fallback resolution indicating the player is unequipped or barefoot.
   * @param player The local player puppet reference.
   * @return Barefoot resolution result.
   */
  protected func Resolve(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    return FootwearResolutionResult.Create(ItemID.None(), "None");
  }
}

// -----------------------------------------------------------------------------
// Footwear Resolver Pipeline Orchestrator (Facade)
// -----------------------------------------------------------------------------
public class FootwearResolver {
  private let m_chain: ref<FootwearResolutionHandler>;

  /**
   * Factory method initializing a resolver instance with a pre-assembled handler chain.
   * @return A newly initialized FootwearResolver instance.
   */
  public static func Create() -> ref<FootwearResolver> {
    let resolver: ref<FootwearResolver> = new FootwearResolver();
    resolver.m_chain = FootwearResolver.CreateChain();
    return resolver;
  }

  /**
   * Lazily initializes and returns the cached resolution handler chain.
   * @return The head handler of the chain.
   */
  public func GetChain() -> ref<FootwearResolutionHandler> {
    if !IsDefined(this.m_chain) {
      this.m_chain = FootwearResolver.CreateChain();
    };
    return this.m_chain;
  }

  /**
   * Resolves currently visible footwear using this instance's cached handler chain.
   * @param player The local player puppet reference.
   * @return The resolved FootwearResolutionResult.
   */
  public func Resolve(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    if !IsDefined(player) {
      return FootwearResolutionResult.Create(ItemID.None(), "None (Invalid Player)");
    };
    return this.GetChain().Handle(player);
  }

  /**
   * Assembles and links the full resolution chain: Equipment-EX -> Wardrobe -> Gameplay Slot -> Barefoot Fallback.
   * @return The head handler of the configured pipeline.
   */
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

  /**
   * Resolves currently visible footwear for the player puppet using the Chain of Responsibility pipeline.
   * Reuses the system's cached calibration resolver when available to prevent per-call object allocations.
   * @param player The local player puppet reference.
   * @return The resolved FootwearResolutionResult containing ItemID and layer name.
   */
  public static func ResolveFootwear(player: ref<PlayerPuppet>) -> ref<FootwearResolutionResult> {
    if !IsDefined(player) {
      return FootwearResolutionResult.Create(ItemID.None(), "None (Invalid Player)");
    };
    let sys: ref<ImmersiveFootwearPOVSystem> = ImmersiveFootwearPOVSystem.GetInstance(player.GetGame());
    if IsDefined(sys) && IsDefined(sys.GetCalibrationService()) {
      return sys.GetCalibrationService().GetResolver().Resolve(player);
    };
    return FootwearResolver.CreateChain().Handle(player);
  }
}
