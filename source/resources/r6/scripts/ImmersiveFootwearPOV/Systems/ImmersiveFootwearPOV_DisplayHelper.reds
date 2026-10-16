module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Display & Localization Helper
// Single Responsibility: Resolves localized display names and debug record IDs
// =============================================================================
public class FootwearDisplayHelper {

  /**
   * Retrieves the debug string representation of an item's TweakDB ID.
   * @param itemID The ItemID to inspect.
   * @return Formatted TweakDB ID string, or empty string if invalid.
   */
  public static func GetResolvedShoeTDBIDString(itemID: ItemID) -> String {
    if ItemID.IsValid(itemID) {
      return TDBID.ToStringDEBUG(ItemID.GetTDBID(itemID));
    };
    return "";
  }

  /**
   * Resolves the human-readable localized display name for a footwear item.
   * Falls back to debug TDBID string if localization is missing, or "None" if unequipped/invalid.
   * @param itemID The ItemID of the footwear item.
   * @return Localized shoe name or fallback identifier.
   */
  public static func GetResolvedShoeDisplayName(itemID: ItemID) -> String {
    if ItemID.IsValid(itemID) {
      let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemID));
      if IsDefined(record) {
        let locKey: CName = record.DisplayName();
        if IsNameValid(locKey) {
          let locName: String = GetLocalizedTextByKey(locKey);
          if StrLen(locName) > 0 {
            return locName;
          };
        };
        return TDBID.ToStringDEBUG(ItemID.GetTDBID(itemID));
      };
    };
    return "None";
  }
}
