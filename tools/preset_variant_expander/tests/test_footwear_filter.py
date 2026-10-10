"""
Unit tests for FootwearClassifier and stem extraction.
"""

import unittest
from ..core.footwear_filter import FootwearClassifier


class TestFootwearFilter(unittest.TestCase):

    def test_positive_shoe_names(self):
        shoes = [
            "Items.comfy_boots_black_black",
            "Items.Boots_05_old_03",
            "Items.tony_asym_boots_beige",
            "Items.tony_ch2_chain_heels_2_gold",
            "Items.phoebe_peep_toe_sandals_black",
            "Items.halk_sneakers_v1",
            "Items.imperator_pumps_red",
            "Items.wedge_sandals_white",
            "Items.curv_a",
            "Items.curv_f",
            "Items.dusty_racingsuit_boots_02",  # Compound name with suit
        ]
        for shoe in shoes:
            self.assertTrue(
                FootwearClassifier.is_footwear(shoe),
                f"Expected '{shoe}' to be recognized as footwear."
            )

    def test_negative_clothing_names(self):
        non_shoes = [
            "Items.tony_asym_suit_l_beige",
            "Items.tony_ch2_collar_gold",
            "Items.tony_ch2_handcuff_left_gold",
            "Items.tony_ch2_navel_gold",
            "Items.tony_ch2_top_gold",
            "Items.tony_do2_bra_black",
            "Items.tony_do2_jeans_flower_black",
            "Items.tony_do2_panty_flower_black",
            "Items.tony_wndr_cloak_hood_down_black",
            "Items.tony_wndr_pants_black",
            "Items.tony_ltph_mask_black",
            "Items.tony_ltph_lace_gloves_black",
            "Items.tony_dark_butterfly_dress_beige",
            "Items.tony_leather_stockings_black",
            "Items.veegee_dave_assassin_coat_black",
        ]
        for item in non_shoes:
            self.assertFalse(
                FootwearClassifier.is_footwear(item),
                f"Expected '{item}' to be rejected as non-footwear."
            )

    def test_metadata_override(self):
        # Even with an ambiguous name, $base = GenericFootClothing makes it footwear
        ambiguous_footwear = "Items.custom_mod_piece_01"
        self.assertTrue(
            FootwearClassifier.is_footwear(
                ambiguous_footwear,
                item_data={"$base": "Items.GenericFootClothing"}
            )
        )

        # Ambiguous name with face clothing base is rejected
        self.assertFalse(
            FootwearClassifier.is_footwear(
                ambiguous_footwear,
                item_data={"$base": "Items.GenericFaceClothing"}
            )
        )

        # PlacementSlots override
        self.assertTrue(
            FootwearClassifier.is_footwear(
                ambiguous_footwear,
                item_data={"placementSlots": ["OutfitSlots.Feet"]}
            )
        )
        self.assertFalse(
            FootwearClassifier.is_footwear(
                ambiguous_footwear,
                item_data={"placementSlots": ["OutfitSlots.Neckwear"]}
            )
        )

    def test_stem_extraction(self):
        self.assertEqual(
            FootwearClassifier.extract_garment_stem("Items.comfy_boots_black_black"),
            "Items.comfy_boots"
        )
        self.assertEqual(
            FootwearClassifier.extract_garment_stem("Items.tony_asym_boots_beige"),
            "Items.tony_asym_boots"
        )
        self.assertEqual(
            FootwearClassifier.extract_garment_stem("Items.tony_asym_suit_l_beige"),
            "Items.tony_asym_suit_l"
        )
        self.assertEqual(
            FootwearClassifier.extract_garment_stem("Items.tony_ch2_chain_heels_2_gold"),
            "Items.tony_ch2_chain_heels"
        )
        self.assertEqual(
            FootwearClassifier.extract_garment_stem("Items.tony_ch2_collar_gold"),
            "Items.tony_ch2_collar"
        )


if __name__ == "__main__":
    unittest.main()
