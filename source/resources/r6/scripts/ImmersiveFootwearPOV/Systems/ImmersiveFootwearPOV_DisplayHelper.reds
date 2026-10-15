module ImmersiveFootwearPOV

// =============================================================================
// Immersive Footwear POV - Display & Localization Helper
// Single Responsibility: Resolves localized display names and debug record IDs
// =============================================================================
public class FootwearDisplayHelper {

  public static func GetResolvedShoeTDBIDString(itemID: ItemID) -> String {
    if ItemID.IsValid(itemID) {
      return TDBID.ToStringDEBUG(ItemID.GetTDBID(itemID));
    };
    return "";
  }

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
