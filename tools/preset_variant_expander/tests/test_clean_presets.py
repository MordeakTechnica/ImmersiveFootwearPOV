"""
Unit tests for preset cleaning / sanitizing non-footwear clothing items.
"""

import os
import unittest
from pathlib import Path

from ..core.footwear_filter import FootwearClassifier
from ..core.models import ShoeCalibration
from ..repository.json_preset_repository import JsonPresetRepository


class TestCleanPresets(unittest.TestCase):

    def setUp(self):
        self.repo = JsonPresetRepository()
        self.repo_root = Path(__file__).resolve().parents[3]
        self.gama_presets_path = self.repo_root / "examples" / "gama_presets.json"

    def test_sanitize_mixed_dictionary(self):
        input_data = {
            "Items.comfy_boots_black_black": ShoeCalibration(heel=5.0, platform=1.2),
            "Items.tony_asym_boots_beige": ShoeCalibration(heel=10.0, platform=3.5),
            "Items.tony_asym_suit_l_beige": ShoeCalibration(heel=10.0, platform=3.5),  # non-shoe
            "Items.tony_ch2_collar_gold": ShoeCalibration(heel=10.0, platform=5.0),    # non-shoe
            "Items.dusty_racingsuit_boots_02": ShoeCalibration(heel=10.0, platform=3.0),
        }

        sanitized, purged = self.repo.sanitize(input_data)

        self.assertEqual(len(sanitized), 3)
        self.assertEqual(len(purged), 2)
        self.assertIn("Items.comfy_boots_black_black", sanitized)
        self.assertIn("Items.tony_asym_boots_beige", sanitized)
        self.assertIn("Items.dusty_racingsuit_boots_02", sanitized)
        self.assertIn("Items.tony_asym_suit_l_beige", purged)
        self.assertIn("Items.tony_ch2_collar_gold", purged)

    def test_sanitize_gama_presets_example(self):
        if not self.gama_presets_path.exists():
            self.skipTest("examples/gama_presets.json not found")

        raw_presets = self.repo.load(self.gama_presets_path)
        self.assertGreaterEqual(len(raw_presets), 200)

        # 100% of items in gama_presets must be valid footwear
        for item in raw_presets.keys():
            self.assertTrue(
                FootwearClassifier.is_footwear(item),
                f"Item '{item}' in gama_presets.json should be valid footwear"
            )

        # Inject contaminated non-shoe clothing items to verify sanitize() purges them
        contaminated = dict(raw_presets)
        spurious_items = [
            "Items.tony_asym_suit_l_beige",
            "Items.tony_ch2_collar_gold",
            "Items.tony_ch2_handcuff_left_gold",
            "Items.tony_wndr_bra_black",
            "Items.tony_wndr_pants_black",
            "Items.veegee_dave_assassin_coat_air",
        ]
        for sp in spurious_items:
            contaminated[sp] = ShoeCalibration(heel=10.0, platform=5.0)

        sanitized, purged = self.repo.sanitize(contaminated)
        self.assertEqual(len(sanitized), len(raw_presets))
        self.assertEqual(len(purged), len(spurious_items))

        for sp in spurious_items:
            self.assertIn(sp, purged)
            self.assertNotIn(sp, sanitized)


if __name__ == "__main__":
    unittest.main()
