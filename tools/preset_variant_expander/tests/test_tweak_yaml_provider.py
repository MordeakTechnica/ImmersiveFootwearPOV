"""Unit tests for TweakYamlVariantProvider."""

import tempfile
import unittest
from pathlib import Path

from ..providers.tweak_yaml_provider import TweakYamlVariantProvider


class TestTweakYamlVariantProvider(unittest.TestCase):

    def setUp(self):
        self.provider = TweakYamlVariantProvider()
        self.temp_dir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_instances_expansion(self):
        yaml_content = """
Items.test_boots_$(base_color):
  $base: Items.GenericFootClothing
  $instances:
    - { base_color: black }
    - { base_color: white }
    - { base_color: red }
  statModifiers:
    - !append Quality.IconicItem
"""
        yaml_path = Path(self.temp_dir.name) / "test_boots.yaml"
        with open(yaml_path, "w", encoding="utf-8") as f:
            f.write(yaml_content)

        count = self.provider.index_directory(Path(self.temp_dir.name))
        self.assertEqual(count, 3)

        siblings = self.provider.find_siblings("Items.test_boots_black")
        sibling_ids = {s.item_id for s in siblings}

        self.assertIn("Items.test_boots_white", sibling_ids)
        self.assertIn("Items.test_boots_red", sibling_ids)
        self.assertNotIn("Items.test_boots_black", sibling_ids)  # should not include self

    def test_sibling_records_clustering(self):
        yaml_content = """
Items.Halk_Heels_Black:
  $base: Items.GenericFootClothing
  entityName: halk_heels_ent

Items.Halk_Heels_Red:
  $base: Items.GenericFootClothing
  entityName: halk_heels_ent

Items.Halk_Heels_Gold:
  $base: Items.GenericFootClothing
  entityName: halk_heels_ent
"""
        yaml_path = Path(self.temp_dir.name) / "halk_heels.yaml"
        with open(yaml_path, "w", encoding="utf-8") as f:
            f.write(yaml_content)

        self.provider.index_directory(Path(self.temp_dir.name))

        siblings = self.provider.find_siblings("Items.Halk_Heels_Black")
        sibling_ids = {s.item_id for s in siblings}

        self.assertIn("Items.Halk_Heels_Red", sibling_ids)
        self.assertIn("Items.Halk_Heels_Gold", sibling_ids)


if __name__ == "__main__":
    unittest.main()
