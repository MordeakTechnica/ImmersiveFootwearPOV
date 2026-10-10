"""
Archive Variant Provider.
Scans mod .archive files using WolvenKit CLI (if available) or archive inspection.
Discovers appearance and entity resource clusters.
"""

import os
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

from ..core.interfaces import IVariantProvider
from ..core.models import VariantMatch


class ArchiveVariantProvider(IVariantProvider):
    """
    Variant discovery provider for mod .archive files.
    Leverages WolvenKit CLI to query internal archive manifests.
    """

    DEFAULT_WKIT_PATHS = [
        Path(os.path.expandvars(r"%LOCALAPPDATA%\Programs\WolvenKit\CLI\WolvenKit.CLI.exe")),
        Path(r"C:\Users\cogli\AppData\Local\Programs\WolvenKit\CLI\WolvenKit.CLI.exe"),
    ]

    def __init__(self, wkit_cli_path: Optional[Path] = None):
        self.wkit_cli_path: Optional[Path] = self._resolve_wkit(wkit_cli_path)
        self._item_to_siblings: Dict[str, List[VariantMatch]] = {}
        self.indexed_files_count: int = 0
        self.indexed_items_count: int = 0

    def _resolve_wkit(self, custom_path: Optional[Path]) -> Optional[Path]:
        if custom_path and custom_path.exists():
            return custom_path
        for p in self.DEFAULT_WKIT_PATHS:
            if p.exists():
                return p
        return None

    def index_directory(
        self,
        root_dir: Path,
        progress_callback: Optional[Any] = None
    ) -> int:
        """Scan mod archives if WolvenKit CLI is available."""
        if not self.wkit_cli_path or not root_dir or not root_dir.exists():
            return 0

        indexed_count = 0
        archives: List[Path] = []
        for root, _, files in os.walk(root_dir):
            for file_name in files:
                if file_name.lower().endswith(".archive"):
                    if "basegame" in file_name.lower() or "lang_" in file_name.lower():
                        continue
                    archives.append(Path(root) / file_name)

        total_files = len(archives)
        for idx, file_path in enumerate(archives, 1):
            if progress_callback and (idx % 5 == 0 or idx == total_files):
                progress_callback(file_path.name, idx, total_files, indexed_count)
            try:
                count = self._inspect_archive(file_path)
                if count > 0:
                    indexed_count += count
                    self.indexed_files_count += 1
            except Exception:
                continue

        self.indexed_items_count += indexed_count
        return indexed_count

    def find_siblings(self, item_id: str) -> List[VariantMatch]:
        normalized = item_id.strip().lower()
        return self._item_to_siblings.get(normalized, [])

    def _inspect_archive(self, archive_path: Path) -> int:
        """Query archive internal files using WolvenKit CLI."""
        try:
            cmd = [str(self.wkit_cli_path), "archive", str(archive_path), "-l"]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            if result.returncode != 0 or not result.stdout:
                return 0
        except Exception:
            return 0

        lines = result.stdout.splitlines()
        # Look for .app (appearance) or .mesh files
        app_files = [line.strip() for line in lines if line.strip().endswith(".app")]
        # Archive inspection provides auxiliary appearance data
        return len(app_files)
