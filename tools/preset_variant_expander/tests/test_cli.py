"""
Unit tests for CLI game folder detection and confirmation prompts.
"""

import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from ..cli.main import (
    find_enclosing_game_dir,
    is_game_dir,
    main,
)

main_module = sys.modules[main.__module__]


class TestCliGameDirDetection(unittest.TestCase):

    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.base_path = Path(self.temp_dir.name)

        # Create a mock Cyberpunk 2077 installation
        self.game_root = self.base_path / "Cyberpunk 2077"
        self.exe_path = self.game_root / "bin" / "x64" / "Cyberpunk2077.exe"
        self.exe_path.parent.mkdir(parents=True, exist_ok=True)
        self.exe_path.write_bytes(b"MZfakeexe")

        (self.game_root / "r6" / "tweaks").mkdir(parents=True, exist_ok=True)
        (self.game_root / "archive" / "pc" / "mod").mkdir(parents=True, exist_ok=True)

        self.mod_dir = (
            self.game_root
            / "bin"
            / "x64"
            / "plugins"
            / "cyber_engine_tweaks"
            / "mods"
            / "ImmersiveFootwearPOV"
        )
        self.mod_dir.mkdir(parents=True, exist_ok=True)

        # Create a non-game directory
        self.other_dir = self.base_path / "Documents" / "Projects"
        self.other_dir.mkdir(parents=True, exist_ok=True)

        # Sample valid preset file
        self.preset_file = self.other_dir / "presets.json"
        self.preset_file.write_text(
            json.dumps({"Items.my_shoes_01": {"heel": 5.0, "platform": 1.0}}),
            encoding="utf-8",
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_is_game_dir(self):
        self.assertTrue(is_game_dir(self.game_root))
        self.assertFalse(is_game_dir(self.mod_dir))
        self.assertFalse(is_game_dir(self.other_dir))
        self.assertFalse(is_game_dir(None))

    def test_find_enclosing_game_dir_from_subfolder(self):
        detected = find_enclosing_game_dir(start_path=self.mod_dir)
        self.assertIsNotNone(detected)
        self.assertEqual(detected.resolve(), self.game_root.resolve())

    def test_find_enclosing_game_dir_from_root(self):
        detected = find_enclosing_game_dir(start_path=self.game_root)
        self.assertIsNotNone(detected)
        self.assertEqual(detected.resolve(), self.game_root.resolve())

    def test_find_enclosing_game_dir_from_unrelated_path(self):
        detected = find_enclosing_game_dir(start_path=self.other_dir)
        self.assertIsNone(detected)

    @patch("builtins.input", return_value="n")
    def test_prompt_cancels_when_user_answers_no(self, mock_input):
        with patch.object(main_module, "find_enclosing_game_dir", return_value=self.game_root):
            out = io.StringIO()
            with patch("sys.stdout", out):
                code = main(["-i", str(self.preset_file), "--clean-only"])

            self.assertEqual(code, 0)
            output = out.getvalue()
            self.assertIn("Detected that the tool is running inside the Cyberpunk 2077 game directory", output)
            self.assertIn("Operation cancelled by user", output)

    @patch("builtins.input", return_value="y")
    def test_prompt_proceeds_when_user_answers_yes(self, mock_input):
        with patch.object(main_module, "find_enclosing_game_dir", return_value=self.game_root):
            out = io.StringIO()
            with patch("sys.stdout", out):
                code = main(["-i", str(self.preset_file), "--clean-only"])

            self.assertEqual(code, 0)
            output = out.getvalue()
            self.assertIn("Detected that the tool is running inside the Cyberpunk 2077 game directory", output)
            self.assertNotIn("Operation cancelled by user", output)

    @patch("builtins.input", side_effect=["invalid", "y"])
    def test_prompt_retries_on_invalid_input(self, mock_input):
        with patch.object(main_module, "find_enclosing_game_dir", return_value=self.game_root):
            out = io.StringIO()
            with patch("sys.stdout", out):
                code = main(["-i", str(self.preset_file), "--clean-only"])

            self.assertEqual(code, 0)
            output = out.getvalue()
            self.assertIn("Please enter 'y' to proceed or 'n' to cancel.", output)

    def test_skip_prompt_with_yes_flag(self):
        with patch.object(main_module, "find_enclosing_game_dir", return_value=self.game_root):
            out = io.StringIO()
            with patch("sys.stdout", out):
                code = main(["-i", str(self.preset_file), "--clean-only", "-y"])

            self.assertEqual(code, 0)
            output = out.getvalue()
            self.assertIn("Detected that the tool is running inside the Cyberpunk 2077 game directory", output)
            self.assertIn("Proceeding (-y specified)", output)

    def test_no_prompt_when_outside_game_folder(self):
        with patch.object(main_module, "find_enclosing_game_dir", return_value=None):
            out = io.StringIO()
            with patch("sys.stdout", out):
                code = main(["-i", str(self.preset_file), "--clean-only"])

            self.assertEqual(code, 0)
            output = out.getvalue()
            self.assertNotIn("Detected that the tool is running inside the Cyberpunk 2077 game directory", output)


if __name__ == "__main__":
    unittest.main()
