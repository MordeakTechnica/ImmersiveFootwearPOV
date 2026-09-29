module ImmersiveFootwearPOV

// -----------------------------------------------------------------------------
// Global Height Limits Configuration
// Easy access to alter maximum allowed heel and platform limits across the mod
// -----------------------------------------------------------------------------
public enum FootwearHeightLimit {
  MaxHeightCm = 25,
  MaxPlatformCm = 25
}

public class FootwearHeightLimits {
  public static func GetMaxHeightCm() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxHeightCm));
  }

  public static func GetMaxHeightMeters() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxHeightCm)) / 100.0;
  }

  public static func GetMaxPlatformCm() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxPlatformCm));
  }

  public static func GetMaxPlatformMeters() -> Float {
    return Cast<Float>(EnumInt(FootwearHeightLimit.MaxPlatformCm)) / 100.0;
  }
}

// -----------------------------------------------------------------------------
// Shoe Height Data Container
// Holds both Heel Height (for V's FPP elevation) and Platform Height (for PM shifting)
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
        let heelVal: Float = ShoeHeightParser.ParseHeelTag(tagStr);
        if heelVal > 0.0 {
          parsedHeel = heelVal;
        };
      };

      // Check Platform tag
      if parsedPlatform == 0.0 {
        let platVal: Float = ShoeHeightParser.ParsePlatformTag(tagStr);
        if platVal > 0.0 {
          parsedPlatform = platVal;
        };
      };

      i += 1;
    };

    // Compatibility Fallback:
    // If only a platform tag was specified without a heel tag, use platform value as heel height
    if parsedHeel == 0.0 && parsedPlatform > 0.0 {
      parsedHeel = parsedPlatform;
    };

    return ShoeHeightData.Create(parsedHeel, parsedPlatform);
  }

  // Parses heel height tags: HeelHeight_XXX, Heel_XXX, ShoeHeel_XXX, ShoeHeight_XXX, FootwearHeight_XXX
  public static func ParseHeelTag(tagStr: String) -> Float {
    let prefixLen: Int32 = 0;

    if StrBeginsWith(tagStr, "HeelHeight_") || StrBeginsWith(tagStr, "heelheight_") {
      prefixLen = 11;
    } else if StrBeginsWith(tagStr, "ShoeHeel_") || StrBeginsWith(tagStr, "shoeheel_") {
      prefixLen = 9;
    } else if StrBeginsWith(tagStr, "Heel_") || StrBeginsWith(tagStr, "heel_") {
      prefixLen = 5;
    } else if StrBeginsWith(tagStr, "ShoeHeight_") || StrBeginsWith(tagStr, "shoeheight_") {
      prefixLen = 11;
    } else if StrBeginsWith(tagStr, "FootwearHeight_") || StrBeginsWith(tagStr, "footwearheight_") {
      prefixLen = 15;
    };

    if prefixLen == 0 {
      return 0.0;
    };

    let totalLen: Int32 = StrLen(tagStr);
    if totalLen <= prefixLen {
      return 0.0;
    };

    let valueStr: String = StrMid(tagStr, prefixLen, totalLen - prefixLen);
    return ShoeHeightParser.ConvertValueToMeters(valueStr);
  }

  // Parses platform sole tags: PlatformHeight_XXX, Platform_XXX, ShoePlatform_XXX
  public static func ParsePlatformTag(tagStr: String) -> Float {
    let prefixLen: Int32 = 0;

    if StrBeginsWith(tagStr, "PlatformHeight_") || StrBeginsWith(tagStr, "platformheight_") {
      prefixLen = 15;
    } else if StrBeginsWith(tagStr, "ShoePlatform_") || StrBeginsWith(tagStr, "shoeplatform_") {
      prefixLen = 13;
    } else if StrBeginsWith(tagStr, "Platform_") || StrBeginsWith(tagStr, "platform_") {
      prefixLen = 9;
    };

    if prefixLen == 0 {
      return 0.0;
    };

    let totalLen: Int32 = StrLen(tagStr);
    if totalLen <= prefixLen {
      return 0.0;
    };

    let valueStr: String = StrMid(tagStr, prefixLen, totalLen - prefixLen);
    return ShoeHeightParser.ConvertValueToMeters(valueStr);
  }

  // Converts parsed tag value string to meters
  // Supports:
  // - Direct decimal meters: "0.06" -> 0.06m
  // - Centimeter tags: "006" -> 0.06m, "008" -> 0.08m, "010" -> 0.10m, "6" -> 0.06m, "25" -> 0.25m
  // - Millimeter tags: "60" -> 0.06m, "80" -> 0.08m, "250" -> 0.25m
  public static func ConvertValueToMeters(valueStr: String) -> Float {
    if StrLen(valueStr) == 0 {
      return 0.0;
    };

    // If decimal point exists (e.g. "0.06", "0.10", "0.25")
    if StrFindFirst(valueStr, ".") >= 0 {
      let rawVal: Float = StringToFloat(valueStr);
      return ShoeHeightParser.ClampHeight(rawVal);
    };

    let intVal: Int32 = StringToInt(valueStr);
    if intVal <= 0 {
      return 0.0;
    };

    let floatVal: Float = Cast<Float>(intVal);
    let maxCm: Float = FootwearHeightLimits.GetMaxHeightCm();

    // If value is in range 1..maxCm, treat as centimeters (e.g. 6cm = 0.06m, 25cm = 0.25m)
    if floatVal >= 1.0 && floatVal <= maxCm {
      return ShoeHeightParser.ClampHeight(floatVal / 100.0);
    };

    // If value is in range (maxCm + 1)..(maxCm * 10), treat as millimeters (e.g. 60mm = 0.06m, 250mm = 0.25m)
    if floatVal > maxCm && floatVal <= (maxCm * 10.0) {
      return ShoeHeightParser.ClampHeight(floatVal / 1000.0);
    };

    // If value is greater than max millimeters, return 0.0
    return 0.0;
  }

  // Safety clamp to prevent extreme offsets
  public static func ClampHeight(val: Float) -> Float {
    if val < 0.0 {
      return 0.0;
    };
    let maxMeters: Float = FootwearHeightLimits.GetMaxHeightMeters();
    if val > maxMeters {
      return maxMeters;
    };
    return val;
  }
}
