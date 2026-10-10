"""
JSON Preset Repository.
Implements the Repository Pattern for loading and persisting footwear presets.
Ensures strict separation between shoe calibration data and mod settings.
"""

import json
from pathlib import Path
from typing import Dict

from ..core.interfaces import IPresetRepository
from ..core.models import ShoeCalibration


class JsonPresetRepository(IPresetRepository):
    """Repository handling file I/O and JSON serialization for shoe presets."""

    def load(self, file_path: Path) -> Dict[str, ShoeCalibration]:
        """
        Load footwear presets from a JSON file.
        Filters out any non-shoe configuration keys (such as __settings).
        """
        if not file_path or not file_path.exists():
            return {}

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            raise ValueError(f"Failed to parse preset JSON file at {file_path}: {e}")

        if not isinstance(data, dict):
            return {}

        presets: Dict[str, ShoeCalibration] = {}
        for key, val in data.items():
            if key == "__settings" or not isinstance(val, dict):
                continue

            try:
                calibration = ShoeCalibration.from_dict(val)
                presets[key] = calibration
            except (ValueError, TypeError):
                continue

        return presets

    def save(self, file_path: Path, presets: Dict[str, ShoeCalibration]) -> None:
        """
        Save footwear presets to a JSON file.
        Alphabetizes keys and enforces 2-space indentation.
        Guarantees that general settings are excluded.
        """
        if not file_path:
            raise ValueError("Target file path cannot be None.")

        # Ensure parent directory exists
        file_path.parent.mkdir(parents=True, exist_ok=True)

        # Sort entries alphabetically by ItemID
        payload = {}
        for key in sorted(presets.keys(), key=lambda s: s.lower()):
            if key != "__settings":
                payload[key] = presets[key].to_dict()

        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, ensure_ascii=False)
            f.write("\n")
