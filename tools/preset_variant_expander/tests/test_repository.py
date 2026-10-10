"""Unit tests for JsonPresetRepository."""

import json
import tempfile
import unittest
from pathlib import Path

from ..core.models import ShoeCalibration
from ..repository.json_preset_repository import JsonPresetRepository


class TestJsonPresetRepository(unittest.TestCase):

    def setUp(self):
        self.repo = JsonPresetRepository()
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name) / "test_presets.json"

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_save_and_load_roundtrip(self):
        presets = {
            "Items.boot_b": ShoeCalibration(heel=8.0, platform=1.5),
            "Items.boot_a": ShoeCalibration(heel=12.0, platform=3.0),
        }
        self.repo.save(self.temp_path, presets)

        loaded = self.repo.load(self.temp_path)
        self.assertEqual(len(loaded), 2)
        self.assertEqual(loaded["Items.boot_a"].heel, 12.0)
        self.assertEqual(loaded["Items.boot_b"].platform, 1.5)

        # Verify alphabetical ordering in raw file
        with open(self.temp_path, "r", encoding="utf-8") as f:
            raw_lines = f.read().splitlines()
        first_key_line = [l for l in raw_lines if '"Items.' in l][0]
        self.assertIn("Items.boot_a", first_key_line)

    def test_load_filters_out_settings(self):
        raw_data = {
            "__settings": {"debugLogs": True, "enableHipSway": False},
            "Items.valid_shoe": {"heel": 10.0, "platform": 2.0},
        }
        with open(self.temp_path, "w", encoding="utf-8") as f:
            json.dump(raw_data, f)

        loaded = self.repo.load(self.temp_path)
        self.assertNotIn("__settings", loaded)
        self.assertIn("Items.valid_shoe", loaded)
        self.assertEqual(len(loaded), 1)


if __name__ == "__main__":
    unittest.main()
