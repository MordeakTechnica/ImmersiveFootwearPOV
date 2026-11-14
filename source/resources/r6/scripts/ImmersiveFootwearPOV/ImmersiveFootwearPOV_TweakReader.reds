module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Shoe Height Parser
// Single Responsibility: Clean interface for reading shoe metadata from ItemID / TDBID / Item_Record
// =============================================================================

// -----------------------------------------------------------------------------
// Shoe Height Data Container
// -----------------------------------------------------------------------------
public class ShoeHeightData {
  public let heelHeight: Float;      // Primary height adjustment: elevates V up/down in FPP
  public let platformHeight: Float;  // Secondary sole thickness: reserved for Photo Mode (PM) height shifting

  /**
   * Initializes a ShoeHeightData container with heel and platform measurements.
   * @param heel Heel height offset in meters.
   * @param platform Platform height offset in meters.
   * @return A newly initialized ShoeHeightData instance.
   */
  public static func Create(heel: Float, platform: Float) -> ref<ShoeHeightData> {
    let data: ref<ShoeHeightData> = new ShoeHeightData();
    data.heelHeight = heel;
    data.platformHeight = platform;
    return data;
  }
}

// -----------------------------------------------------------------------------
// Shoe Height Parser
// -----------------------------------------------------------------------------
public class ShoeHeightParser {

  /**
   * Reads full footwear height data (heel + platform) from an ItemID.
   * @param itemID The ItemID of the footwear item.
   * @return ShoeHeightData containing parsed heel and platform heights in meters.
   */
  public static func ReadShoeHeightData(itemID: ItemID) -> ref<ShoeHeightData> {
    if !ItemID.IsValid(itemID) {
      return ShoeHeightData.Create(0.0, 0.0);
    };

    let itemTDBID: TweakDBID = ItemID.GetTDBID(itemID);
    return ShoeHeightParser.ReadShoeHeightDataFromTDBID(itemTDBID);
  }

  /**
   * Reads full footwear height data from a TweakDBID.
   * @param itemTDBID The TweakDB ID of the item record.
   * @return ShoeHeightData containing parsed heel and platform heights in meters.
   */
  public static func ReadShoeHeightDataFromTDBID(itemTDBID: TweakDBID) -> ref<ShoeHeightData> {
    if !TDBID.IsValid(itemTDBID) {
      return ShoeHeightData.Create(0.0, 0.0);
    };

    let itemRecord: ref<Item_Record> = TweakDBInterface.GetItemRecord(itemTDBID);
    if !IsDefined(itemRecord) {
      return ShoeHeightData.Create(0.0, 0.0);
    };

    return ShoeHeightParser.ReadShoeHeightDataFromRecord(itemRecord);
  }

  /**
   * Convenience alias reading primary active heel height in meters for first-person perspective.
   * @param itemID The ItemID of the footwear item.
   * @return Primary heel height in meters.
   */
  public static func ReadShoeHeight(itemID: ItemID) -> Float {
    return ShoeHeightParser.ReadHeelHeight(itemID);
  }

  /**
   * Reads primary heel height in meters from an ItemID.
   * @param itemID The ItemID of the footwear item.
   * @return Heel height in meters.
   */
  public static func ReadHeelHeight(itemID: ItemID) -> Float {
    let data: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(itemID);
    return data.heelHeight;
  }

  /**
   * Reads secondary platform sole thickness in meters from an ItemID.
   * @param itemID The ItemID of the footwear item.
   * @return Platform height in meters.
   */
  public static func ReadPlatformHeight(itemID: ItemID) -> Float {
    let data: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(itemID);
    return data.platformHeight;
  }

  /**
   * Inspects item tags on an Item_Record to extract and clamp heel and platform heights in meters.
   * If only platform tags are defined, falls back to using platform height for heel elevation.
   * @param itemRecord The item record to inspect.
   * @return ShoeHeightData populated with parsed values.
   */
  public static func ReadShoeHeightDataFromRecord(itemRecord: ref<Item_Record>) -> ref<ShoeHeightData> {
    if !IsDefined(itemRecord) {
      return ShoeHeightData.Create(0.0, 0.0);
    };

    let tags: array<CName> = itemRecord.Tags();
    let count: Int32 = ArraySize(tags);
    if count == 0 {
      return ShoeHeightData.Create(0.0, 0.0);
    };
    let i: Int32 = 0;
    let tagStr: String;

    let parsedHeel: Float = 0.0;
    let parsedPlatform: Float = 0.0;

    while i < count {
      tagStr = NameToString(tags[i]);

      // Check Heel tag
      if parsedHeel == 0.0 {
        let heelVal: Float = ShoeTagRule.ParseHeelTag(tagStr);
        if heelVal > 0.0 {
          parsedHeel = heelVal;
        };
      };

      // Check Platform tag
      if parsedPlatform == 0.0 {
        let platVal: Float = ShoeTagRule.ParsePlatformTag(tagStr);
        if platVal > 0.0 {
          parsedPlatform = platVal;
        };
      };

      i += 1;
    };

    // Compatibility Fallback:
    // If only a platform tag was specified without a heel tag, use platform value as heel height.
    if parsedHeel == 0.0 && parsedPlatform > 0.0 {
      parsedHeel = parsedPlatform;
    };

    return ShoeHeightData.Create(parsedHeel, parsedPlatform);
  }

  /**
   * Forwarding shim to ShoeTagRule.ParseHeelTag for backward compatibility.
   * @param tagStr The tag string to parse.
   * @return Parsed and clamped heel height in meters.
   */
  public static func ParseHeelTag(tagStr: String) -> Float {
    return ShoeTagRule.ParseHeelTag(tagStr);
  }

  /**
   * Forwarding shim to ShoeTagRule.ParsePlatformTag for backward compatibility.
   * @param tagStr The tag string to parse.
   * @return Parsed and clamped platform height in meters.
   */
  public static func ParsePlatformTag(tagStr: String) -> Float {
    return ShoeTagRule.ParsePlatformTag(tagStr);
  }

  /**
   * Forwarding shim converting raw string values to meters against heel height limits.
   * @param valueStr Numeric substring from tag.
   * @return Converted and clamped height in meters.
   */
  public static func ConvertValueToMeters(valueStr: String) -> Float {
    let raw: Float = FootwearUnitConverter.ConvertTagValueToMeters(valueStr, FootwearHeightLimits.GetMaxHeightCm());
    return FootwearClampingPolicy.ClampHeight(raw);
  }

  /**
   * Forwarding shim converting raw string values to meters against platform height limits.
   * @param valueStr Numeric substring from tag.
   * @return Converted and clamped platform height in meters.
   */
  public static func ConvertPlatformValueToMeters(valueStr: String) -> Float {
    let raw: Float = FootwearUnitConverter.ConvertTagValueToMeters(valueStr, FootwearHeightLimits.GetMaxPlatformCm());
    return FootwearClampingPolicy.ClampPlatformHeight(raw);
  }

  /**
   * Forwarding shim enforcing heel height safety bounds.
   * @param val Raw height in meters.
   * @return Clamped heel height in meters.
   */
  public static func ClampHeight(val: Float) -> Float {
    return FootwearClampingPolicy.ClampHeight(val);
  }

  /**
   * Forwarding shim enforcing first-person camera elevation bounds.
   * @param val Raw camera offset in meters.
   * @return Clamped elevation in meters.
   */
  public static func ClampIFPHeight(val: Float) -> Float {
    return FootwearClampingPolicy.ClampIFPHeight(val);
  }

  /**
   * Forwarding shim enforcing platform height bounds.
   * @param val Raw platform offset in meters.
   * @return Clamped platform height in meters.
   */
  public static func ClampPlatformHeight(val: Float) -> Float {
    return FootwearClampingPolicy.ClampPlatformHeight(val);
  }
}
