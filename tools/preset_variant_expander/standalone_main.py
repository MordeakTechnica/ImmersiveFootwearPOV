"""
Standalone entrypoint for Preset Variant Expander.
Used by PyInstaller to build a portable Windows executable.
"""
import os
import sys

# Ensure the project root is on sys.path
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(os.path.dirname(current_dir))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from tools.preset_variant_expander.cli.main import main

if __name__ == "__main__":
    sys.exit(main())
