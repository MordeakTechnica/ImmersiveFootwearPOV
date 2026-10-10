"""Unit tests for PresetExpansionEngine."""

import unittest
from typing import List

from ..core.interfaces import IVariantProvider
from ..core.models import ShoeCalibration, VariantMatch
from ..engine.expander import PresetExpansionEngine


class MockVariantProvider(IVariantProvider):
    """Mock provider simulating variant discovery for testing."""

    def __init__(self, sibling_map: dict):
        self.sibling_map = sibling_map

    def index_directory(self, root_dir):
        return len(self.sibling_map)

    def find_siblings(self, item_id: str) -> List[VariantMatch]:
        siblings = self.sibling_map.get(item_id, [])
        return [
            VariantMatch(item_id=s, matched_via="Mock", source_file="mock.yaml")
            for s in siblings
        ]


class TestPresetExpansionEngine(unittest.TestCase):

    def test_expansion_populates_siblings(self):
        sibling_map = {
            "Items.boot_black": ["Items.boot_white", "Items.boot_red"],
        }
        provider = MockVariantProvider(sibling_map)
        engine = PresetExpansionEngine(provider)

        input_presets = {
            "Items.boot_black": ShoeCalibration(heel=10.0, platform=2.0),
        }

        expanded, result = engine.expand(input_presets)

        self.assertEqual(len(expanded), 3)
        self.assertEqual(result.new_variants_added, 2)
        self.assertIn("Items.boot_white", expanded)
        self.assertIn("Items.boot_red", expanded)
        self.assertEqual(expanded["Items.boot_white"].heel, 10.0)
        self.assertEqual(expanded["Items.boot_red"].platform, 2.0)

    def test_does_not_overwrite_by_default(self):
        sibling_map = {
            "Items.boot_black": ["Items.boot_white"],
        }
        provider = MockVariantProvider(sibling_map)
        engine = PresetExpansionEngine(provider)

        input_presets = {
            "Items.boot_black": ShoeCalibration(heel=10.0, platform=2.0),
            "Items.boot_white": ShoeCalibration(heel=12.0, platform=3.0),  # custom value
        }

        expanded, result = engine.expand(input_presets, overwrite_existing=False)

        self.assertEqual(expanded["Items.boot_white"].heel, 12.0)  # Preserved!
        self.assertEqual(result.new_variants_added, 0)


if __name__ == "__main__":
    unittest.main()
