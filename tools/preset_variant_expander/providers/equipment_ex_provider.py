"""
Equipment-EX / ArchiveXL CSV Variant Provider.
Scans and parses Equipment-EX outfit tables (.csv) across r6/tweaks and mod directories.
"""

import csv
import os
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

from ..core.interfaces import IVariantProvider
from ..core.models import VariantMatch
from ..core.footwear_filter import FootwearClassifier


class EquipmentExVariantProvider(IVariantProvider):
    """
    Variant discovery provider for Equipment-EX CSV tables.
    Extracts item clusters from clothing tables.
    """

    def __init__(self):
        self._item_to_siblings: Dict[str, List[VariantMatch]] = {}
        self.indexed_files_count: int = 0
        self.indexed_items_count: int = 0

    def index_directory(
        self,
        root_dir: Path,
        progress_callback: Optional[Any] = None
    ) -> int:
        if not root_dir or not root_dir.exists():
            return 0

        indexed_count = 0
        csv_files: List[Path] = []
        for root, _, files in os.walk(root_dir):
            for file_name in files:
                if file_name.lower().endswith(".csv"):
                    csv_files.append(Path(root) / file_name)

        total_files = len(csv_files)
        for idx, file_path in enumerate(csv_files, 1):
            if progress_callback and (idx % 10 == 0 or idx == total_files):
                progress_callback(file_path.name, idx, total_files, indexed_count)
            try:
                count = self._parse_csv_file(file_path)
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

    def _parse_csv_file(self, file_path: Path) -> int:
        try:
            with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                reader = csv.reader(f)
                rows = list(reader)
        except Exception:
            return 0

        # Collect and filter footwear ItemIDs ("Items.")
        shoes_found: List[str] = []
        for row in rows:
            for col in row:
                col_clean = col.strip()
                if (
                    col_clean.startswith("Items.")
                    and len(col_clean) > 8
                    and FootwearClassifier.is_footwear(col_clean)
                ):
                    shoes_found.append(col_clean)

        if len(shoes_found) < 2:
            return 0

        # Cluster footwear items by garment model stem
        stem_groups: Dict[str, List[str]] = {}
        for item in shoes_found:
            stem = FootwearClassifier.extract_garment_stem(item).lower()
            stem_groups.setdefault(stem, []).append(item)

        indexed = 0
        for stem, group in stem_groups.items():
            if len(group) > 1:
                unique_group = list(dict.fromkeys(group))
                self._link_siblings(unique_group, str(file_path))
                indexed += len(unique_group)

        return indexed

    def _link_siblings(self, group: List[str], source_file: str) -> None:
        for item in group:
            norm = item.strip().lower()
            if norm not in self._item_to_siblings:
                self._item_to_siblings[norm] = []

            for other in group:
                if other.strip().lower() != norm:
                    already_exists = any(
                        m.item_id.strip().lower() == other.strip().lower()
                        for m in self._item_to_siblings[norm]
                    )
                    if not already_exists:
                        self._item_to_siblings[norm].append(
                            VariantMatch(
                                item_id=other,
                                matched_via="EquipmentEX:csv_cluster",
                                source_file=source_file
                            )
                        )
