module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Shoe Height Parser (Facade Pattern)
// Single Responsibility: Clean facade for reading shoe metadata from ItemID / TDBID / Item_Record
// =============================================================================

// -----------------------------------------------------------------------------
// Shoe Height Data Container (Value Object)
// -----------------------------------------------------------------------------
public class ShoeHeightData {
  public let heelHeight: Float;      // Primary height adjustment: elevates V up/down in FPP
  public let platformHeight: Float;  // Secondary sole thickness: reserved for Photo Mode (PM) height shifting

  public static func Create(heel: Float, platform: Float) -> ref<ShoeHeightData> {
    let data: ref<ShoeHeightData> = new ShoeHeightData();
    data.heelHeight = heel;
    data.platformHeight = platform;
    return data;
  }
}

// -----------------------------------------------------------------------------
// Shoe Height Parser Facade
// -----------------------------------------------------------------------------
public class ShoeHeightParser {

  // Reads full shoe height data (heel + platform) from an ItemID
  public static func ReadShoeHeightData(itemID: ItemID) -> ref<ShoeHeightData> {
    if !ItemID.IsValid(itemID) {
      return ShoeHeightData.Create(0.0, 0.0);
    };

    let itemTDBID: TweakDBID = ItemID.GetTDBID(itemID);
    return ShoeHeightParser.ReadShoeHeightDataFromTDBID(itemTDBID);
  }

  // Reads full shoe height data from a TweakDBID
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

  // Reads primary active height (heel height) for FPP elevation
  public static func ReadShoeHeight(itemID: ItemID) -> Float {
    return ShoeHeightParser.ReadHeelHeight(itemID);
  }

  // Reads primary heel height in meters from an ItemID
  public static func ReadHeelHeight(itemID: ItemID) -> Float {
    let data: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(itemID);
    return data.heelHeight;
  }

  // Reads secondary platform height in meters from an ItemID
  public static func ReadPlatformHeight(itemID: ItemID) -> Float {
    let data: ref<ShoeHeightData> = ShoeHeightParser.ReadShoeHeightData(itemID);
    return data.platformHeight;
  }

  // Inspects item tags to extract Heel and Platform heights (in meters)
  public static func ReadShoeHeightDataFromRecord(itemRecord: ref<Item_Record>) -> ref<ShoeHeightData> {
    if !IsDefined(itemRecord) {
      return ShoeHeightData.Create(0.0, 0.0);
    };

    let tags: array<CName> = itemRecord.Tags();
    let count: Int32 = ArraySize(tags);
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

  // Forwarding shims for backward compatibility
  public static func ParseHeelTag(tagStr: String) -> Float {
    return ShoeTagRule.ParseHeelTag(tagStr);
  }

  public static func ParsePlatformTag(tagStr: String) -> Float {
    return ShoeTagRule.ParsePlatformTag(tagStr);
  }

  public static func ConvertValueToMeters(valueStr: String) -> Float {
    let raw: Float = FootwearUnitConverter.ConvertTagValueToMeters(valueStr, FootwearHeightLimits.GetMaxHeightCm());
    return FootwearClampingPolicy.ClampHeight(raw);
  }

  public static func ConvertPlatformValueToMeters(valueStr: String) -> Float {
    let raw: Float = FootwearUnitConverter.ConvertTagValueToMeters(valueStr, FootwearHeightLimits.GetMaxPlatformCm());
    return FootwearClampingPolicy.ClampPlatformHeight(raw);
  }

  public static func ClampHeight(val: Float) -> Float {
    return FootwearClampingPolicy.ClampHeight(val);
  }

  public static func ClampIFPHeight(val: Float) -> Float {
    return FootwearClampingPolicy.ClampIFPHeight(val);
  }

  public static func ClampPlatformHeight(val: Float) -> Float {
    return FootwearClampingPolicy.ClampPlatformHeight(val);
  }
}
