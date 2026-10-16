module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Shoe Tag Rule Engine
// Single Responsibility: Data-driven prefix matching and numeric extraction for shoe tags
// =============================================================================

public class ShoeTagRule {

  /**
   * Extracts the suffix value from a tag string matching any provided prefix.
   * @param tagStr The full tag name string to inspect.
   * @param prefixes List of prefixes to match against.
   * @return The extracted value string following the matched prefix, or empty string if no match.
   */
  public static func ExtractTagValue(tagStr: String, prefixes: array<String>) -> String {
    let count: Int32 = ArraySize(prefixes);
    let i: Int32 = 0;
    let tagLen: Int32 = StrLen(tagStr);

    while i < count {
      let prefix: String = prefixes[i];
      let prefixLen: Int32 = StrLen(prefix);
      if tagLen > prefixLen {
        if StrBeginsWith(tagStr, prefix) {
          return StrMid(tagStr, prefixLen, tagLen - prefixLen);
        };
      };
      i += 1;
    };

    return "";
  }

  /**
   * Parses and validates heel height tags (e.g., HeelHeight_XXX, Heel_XXX, ShoeHeel_XXX).
   * @param tagStr The tag name string to evaluate.
   * @return Clamped heel height in meters, or 0.0 if not a matching heel tag.
   */
  public static func ParseHeelTag(tagStr: String) -> Float {
    let prefixes: array<String>;
    ArrayPush(prefixes, "HeelHeight_");
    ArrayPush(prefixes, "heelheight_");
    ArrayPush(prefixes, "ShoeHeel_");
    ArrayPush(prefixes, "shoeheel_");
    ArrayPush(prefixes, "ShoeHeight_");
    ArrayPush(prefixes, "shoeheight_");
    ArrayPush(prefixes, "FootwearHeight_");
    ArrayPush(prefixes, "footwearheight_");
    ArrayPush(prefixes, "Heel_");
    ArrayPush(prefixes, "heel_");

    let valStr: String = ShoeTagRule.ExtractTagValue(tagStr, prefixes);
    if StrLen(valStr) == 0 {
      return 0.0;
    };

    let rawMeters: Float = FootwearUnitConverter.ConvertTagValueToMeters(valStr, FootwearHeightLimits.GetMaxHeightCm());
    return FootwearClampingPolicy.ClampHeight(rawMeters);
  }

  /**
   * Parses and validates platform sole tags (e.g., PlatformHeight_XXX, Platform_XXX, ShoePlatform_XXX).
   * @param tagStr The tag name string to evaluate.
   * @return Clamped platform height in meters, or 0.0 if not a matching platform tag.
   */
  public static func ParsePlatformTag(tagStr: String) -> Float {
    let prefixes: array<String>;
    ArrayPush(prefixes, "PlatformHeight_");
    ArrayPush(prefixes, "platformheight_");
    ArrayPush(prefixes, "ShoePlatform_");
    ArrayPush(prefixes, "shoeplatform_");
    ArrayPush(prefixes, "Platform_");
    ArrayPush(prefixes, "platform_");

    let valStr: String = ShoeTagRule.ExtractTagValue(tagStr, prefixes);
    if StrLen(valStr) == 0 {
      return 0.0;
    };

    let rawMeters: Float = FootwearUnitConverter.ConvertTagValueToMeters(valStr, FootwearHeightLimits.GetMaxPlatformCm());
    return FootwearClampingPolicy.ClampPlatformHeight(rawMeters);
  }
}
