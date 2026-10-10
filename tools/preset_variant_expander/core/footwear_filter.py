"""
Footwear Domain Classifier and Stem Extractor.
Ensures preset generation and variant expansion strictly isolate footwear items
from other clothing (e.g. dresses, suits, jewelry, outerwear, and accessories).
"""

from __future__ import annotations
import re
from typing import Any, Dict, List, Optional, Set, Tuple


class FootwearClassifier:
    """
    Classifies whether an item ID or REDengine item definition is footwear,
    and extracts normalized garment stems to isolate sibling colorways.
    """

    POSITIVE_FOOTWEAR_TOKENS: Set[str] = {
        "boot", "boots", "shoe", "shoes", "heel", "heels", "sneaker", "sneakers",
        "pump", "pumps", "sandal", "sandals", "wedge", "wedges", "stiletto", "stilettos",
        "mule", "mules", "flat", "flats", "loafer", "loafers", "derby", "oxford", "oxfords",
        "clog", "clogs", "slipper", "slippers", "cleat", "cleats", "espadrille", "espadrilles",
        "footwear", "feet", "foot", "highheel", "highheels", "ankleboot", "ankleboots",
        "sock", "socks", "platform", "platforms", "combatboots", "cowboyboots",
        "curv_a", "curv_b", "curv_c", "curv_d", "curv_e", "curv_f"
    }

    NEGATIVE_CLOTHING_TOKENS: Set[str] = {
        "dress", "bra", "underwear", "panty", "panties", "thong", "lingerie", "top", "bottom",
        "skirt", "pants", "jeans", "shorts", "breeches", "leggings", "tights", "stocking",
        "stockings", "coat", "jacket", "vest", "hood", "hoodie", "cloak", "collar", "choker",
        "necklace", "handcuff", "handcuffs", "glove", "gloves", "mask", "glasses", "piercing",
        "navel", "belt", "harness", "suit", "earring", "ring", "bracelet", "hat", "helmet",
        "cap", "corset", "swimsuit", "bikini", "eyewear", "scarf", "bodysuit", "strapon",
        "tshirt", "shirt", "blouse", "crop", "sweater", "cardigan"
    }

    POSITIVE_BASE_KEYWORDS: Tuple[str, ...] = (
        "footclothing", "genericfoot", "shoes", "boots", "feet"
    )

    NEGATIVE_BASE_KEYWORDS: Tuple[str, ...] = (
        "faceclothing", "headclothing", "innerchestclothing", "outerchestclothing",
        "legclothing", "eyesclothing"
    )

    POSITIVE_SLOT_KEYWORDS: Tuple[str, ...] = (
        "attachmentlots.feet", "outfitslots.feet", "outfitslots.feetinner",
        "outfitslots.ankles", "outfitslots.shoes", "equipmentarea.feet", "area.feet"
    )

    NEGATIVE_SLOT_KEYWORDS: Tuple[str, ...] = (
        "neckwear", "head", "eyes", "mask", "chest", "torso", "legs",
        "hands", "wrists", "arms", "glasses", "ear", "ring", "fingers", "waist"
    )

    COMMON_COLOR_MATERIALS: Set[str] = {
        "black", "white", "red", "blue", "green", "yellow", "gold", "silver", "pink",
        "purple", "orange", "brown", "grey", "gray", "beige", "tan", "burgundy", "navy",
        "lime", "teal", "cyan", "magenta", "chocolate", "darkgreen", "sky_blue", "babyblue",
        "whitered", "blackred", "steel", "sand", "peach", "sea", "dark", "air", "redblack",
        "plain", "flower", "latex", "leather", "satin", "velvet", "denim", "nylon", "mesh",
        "chrome", "carbon", "neon", "camo", "glossy", "matte", "holo", "holo_pink", "holo_blue"
    }

    @classmethod
    def is_footwear(cls, item_id: str, item_data: Optional[Dict[str, Any]] = None) -> bool:
        """
        Determines whether the given item ID and optional REDengine TweakXL dictionary
        represent footwear.
        """
        norm_id = item_id.strip().lower()

        # 1. Structural / Metadata Analysis (if TweakXL YAML dictionary is supplied)
        if isinstance(item_data, dict):
            # Inspect $base
            base_val = str(item_data.get("$base", "")).lower()
            if base_val:
                if any(kw in base_val for kw in cls.POSITIVE_BASE_KEYWORDS):
                    return True
                if any(kw in base_val for kw in cls.NEGATIVE_BASE_KEYWORDS):
                    return False

            # Inspect placementSlots
            placement_slots = item_data.get("placementSlots", [])
            if isinstance(placement_slots, list):
                slot_strs = [str(s).lower() for s in placement_slots]
                if any(any(kw in s for kw in cls.POSITIVE_SLOT_KEYWORDS) for s in slot_strs):
                    return True
                if any(any(kw in s for kw in cls.NEGATIVE_SLOT_KEYWORDS) for s in slot_strs):
                    return False

            # Inspect equipArea
            equip_area = str(item_data.get("equipArea", "")).lower()
            if equip_area:
                if "feet" in equip_area or "shoes" in equip_area:
                    return True
                if any(kw in equip_area for kw in ["chest", "legs", "head", "face"]):
                    return False

        # 2. Curv Line Fast-Track (known shoe line e.g. Items.curv_a)
        if any(norm_id.startswith(f"items.{c}") for c in ["curv_a", "curv_b", "curv_c", "curv_d", "curv_e", "curv_f"]):
            return True

        # 3. Lexical Token Analysis
        tokens = re.split(r"[_.\-]", norm_id)
        has_pos = any(
            t in cls.POSITIVE_FOOTWEAR_TOKENS
            or any(p in t for p in ["boot", "shoe", "heel", "sneaker", "sandal", "pump", "stiletto", "loafer", "wedge", "clog", "cleat", "slipper"])
            for t in tokens
        )
        has_neg = any(t in cls.NEGATIVE_CLOTHING_TOKENS for t in tokens)

        if has_pos and not has_neg:
            return True

        if has_pos and has_neg:
            # Disambiguate composite names such as Items.dusty_racingsuit_boots_02
            # Find the position of the last positive token vs last negative token
            last_pos = max(
                i for i, t in enumerate(tokens)
                if t in cls.POSITIVE_FOOTWEAR_TOKENS or any(p in t for p in ["boot", "shoe", "heel", "sneaker", "sandal", "pump", "stiletto", "loafer", "wedge", "clog", "cleat", "slipper"])
            )
            last_neg = max(i for i, t in enumerate(tokens) if t in cls.NEGATIVE_CLOTHING_TOKENS)
            return last_pos >= last_neg

        return False

    @classmethod
    def extract_garment_stem(cls, item_id: str) -> str:
        """
        Extracts the base garment model stem from an item ID by stripping variant,
        color, material, and numeric index suffixes.
        
        Example:
            Items.comfy_boots_black_black -> Items.comfy_boots
            Items.tony_asym_boots_beige   -> Items.tony_asym_boots
            Items.tony_asym_suit_l_beige  -> Items.tony_asym_suit_l
        """
        parts = item_id.split("_")
        if len(parts) <= 2:
            return item_id

        # Strip trailing numbers, versions, or known color/material tokens
        while len(parts) > 2:
            last = parts[-1].lower()
            if last.isdigit() or re.match(r"^v\d+$", last) or last in cls.COMMON_COLOR_MATERIALS:
                parts.pop()
            elif len(parts) > 3 and f"{parts[-2].lower()}_{last}" in cls.COMMON_COLOR_MATERIALS:
                parts.pop()
                parts.pop()
            else:
                break

        return "_".join(parts)

    @classmethod
    def filter_presets(cls, presets: Dict[str, Any]) -> Tuple[Dict[str, Any], Dict[str, Any]]:
        """
        Separates a presets dictionary into valid footwear entries and filtered non-footwear entries.
        """
        footwear: Dict[str, Any] = {}
        filtered: Dict[str, Any] = {}

        for key, val in presets.items():
            if cls.is_footwear(key):
                footwear[key] = val
            else:
                filtered[key] = val

        return footwear, filtered
