"""
TweakXL YAML Variant Provider.
Scans and parses Cyberpunk 2077 TweakXL (.yaml / .yml / .tweak) definitions.
Supports:
  1. $instances template variable expansion ($(var)).
  2. Sibling record clusters sharing a common file, entityName, or ItemID prefix.
"""

import os
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple
import yaml

from ..core.interfaces import IVariantProvider
from ..core.models import VariantMatch


class TweakYAMLLoader(yaml.SafeLoader):
    """Permissive YAML loader that transparently handles REDengine/TweakXL tags (!append, !append-once, etc.)."""
    pass


def _tweak_tag_constructor(loader: yaml.Loader, tag_suffix: str, node: yaml.Node) -> Any:
    """Universal constructor mapping custom REDengine tags to standard Python types."""
    if isinstance(node, yaml.ScalarNode):
        return loader.construct_scalar(node)
    elif isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    elif isinstance(node, yaml.MappingNode):
        return loader.construct_mapping(node)
    return None


# Register wildcard multi-constructor for all custom YAML tags
TweakYAMLLoader.add_multi_constructor('!', _tweak_tag_constructor)


class TweakYamlVariantProvider(IVariantProvider):
    """
    Variant discovery provider for TweakXL YAML files.
    Indexes templates, instances, and sibling blocks across r6/tweaks.
    """

    def __init__(self):
        # Maps lowercase item_id -> list of VariantMatch
        self._item_to_siblings: Dict[str, List[VariantMatch]] = {}
        # Tracks indexed file count
        self.indexed_files_count: int = 0
        self.indexed_items_count: int = 0

    def index_directory(
        self,
        root_dir: Path,
        progress_callback: Optional[Any] = None
    ) -> int:
        """Recursively scan root_dir for .yaml and .yml files and build variant index."""
        if not root_dir or not root_dir.exists():
            return 0

        indexed_count = 0
        yaml_extensions = {".yaml", ".yml", ".tweak"}
        target_files: List[Path] = []

        for root, _, files in os.walk(root_dir):
            for file_name in files:
                ext = os.path.splitext(file_name)[1].lower()
                if ext in yaml_extensions:
                    target_files.append(Path(root) / file_name)

        total_files = len(target_files)

        for idx, file_path in enumerate(target_files, 1):
            if progress_callback and (idx % 25 == 0 or idx == total_files):
                progress_callback(file_path.name, idx, total_files, indexed_count)

            try:
                count = self._parse_and_index_file(file_path)
                if count > 0:
                    indexed_count += count
                    self.indexed_files_count += 1
            except Exception:
                continue

        if progress_callback:
            progress_callback("Done", total_files, total_files, indexed_count)

        self.indexed_items_count += indexed_count
        return indexed_count

    def find_siblings(self, item_id: str) -> List[VariantMatch]:
        """Look up all sibling variants for the given item_id."""
        normalized = item_id.strip().lower()
        return self._item_to_siblings.get(normalized, [])

    def _parse_and_index_file(self, file_path: Path) -> int:
        """Parse a single TweakXL YAML file and extract item groups."""
        try:
            with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()
        except Exception:
            return 0

        if "Items." not in content:
            return 0

        try:
            data = yaml.load(content, Loader=TweakYAMLLoader)
        except Exception:
            # Fallback to regex line scanning if YAML parser encounters structural anomalies
            return self._regex_fallback_index(content, file_path)

        if not isinstance(data, dict):
            return 0

        indexed = 0
        file_items: List[Tuple[str, str, str]] = []  # (item_id, entity_name, matched_via)

        for key, val in data.items():
            if not isinstance(key, str) or not key.startswith("Items."):
                continue

            entity_name = ""
            if isinstance(val, dict):
                entity_name = str(val.get("entityName", ""))

            # 1. Check for TweakXL $instances pattern
            if isinstance(val, dict) and "$instances" in val and isinstance(val["$instances"], list):
                expanded_items = self._expand_instances(key, val["$instances"])
                if len(expanded_items) > 1:
                    self._link_siblings(expanded_items, "TweakXL:instances", str(file_path))
                    for exp in expanded_items:
                        file_items.append((exp, entity_name, "TweakXL:instances"))
                        indexed += 1
                    continue

            # Standard item record
            file_items.append((key, entity_name, "TweakXL:yaml_record"))
            indexed += 1

        # Group and index items in this file
        self._cluster_file_items(file_items, str(file_path))
        return indexed

    def _expand_instances(self, template_key: str, instances: List[Any]) -> List[str]:
        """Expand template strings like 'Items.shoe_$(base_color)' or 'Items.shoe_${base_color}' with instance dictionaries."""
        results: List[str] = []
        for inst in instances:
            if not isinstance(inst, dict):
                continue
            item_name = template_key
            for var_key, var_val in inst.items():
                item_name = item_name.replace(f"$({var_key})", str(var_val))
                item_name = item_name.replace(f"${{{var_key}}}", str(var_val))
            # Only add if all parameters were successfully substituted
            if "$(" not in item_name and "${" not in item_name:
                results.append(item_name)
        return results

    def _cluster_file_items(self, file_items: List[Tuple[str, str, str]], source_file: str) -> None:
        """Cluster items in a file into sibling groups based on entityName or common prefix stem."""
        if not file_items:
            return

        # 1. EntityName clusters: items sharing non-empty entityName
        entity_groups: Dict[str, List[str]] = {}
        for item_id, entity, via in file_items:
            if entity:
                entity_groups.setdefault(entity.lower(), []).append(item_id)

        for entity, group in entity_groups.items():
            if len(group) > 1:
                self._link_siblings(group, f"TweakXL:shared_entity({entity})", source_file)

        # 3. If file contains multiple items sharing a common prefix (e.g. Items.ModShoe_Color)
        all_ids = [it[0] for it in file_items]
        if len(all_ids) > 1 and len(all_ids) <= 50:
            prefix = self._find_common_item_prefix(all_ids)
            if len(prefix) > len("Items.") + 3:
                self._link_siblings(all_ids, f"TweakXL:sibling_prefix({prefix})", source_file)

    def _link_siblings(self, item_ids: List[str], matched_via: str, source_file: str) -> None:
        """Register bidirectional sibling relationships between all items in a group."""
        unique_items = list(dict.fromkeys(item_ids))
        for item in unique_items:
            norm = item.strip().lower()
            if norm not in self._item_to_siblings:
                self._item_to_siblings[norm] = []

            for other in unique_items:
                if other.strip().lower() != norm:
                    # Prevent duplicate entries
                    already_exists = any(
                        m.item_id.strip().lower() == other.strip().lower()
                        for m in self._item_to_siblings[norm]
                    )
                    if not already_exists:
                        self._item_to_siblings[norm].append(
                            VariantMatch(item_id=other, matched_via=matched_via, source_file=source_file)
                        )

    def _find_common_item_prefix(self, items: List[str]) -> str:
        """Find common prefix string across a list of items."""
        if not items:
            return ""
        prefix = os.path.commonprefix(items)
        if "_" in prefix:
            return prefix[: prefix.rfind("_") + 1]
        return prefix

    def _regex_fallback_index(self, content: str, file_path: Path) -> int:
        """Lightweight regex scanner when full YAML parsing fails on malformed files."""
        pattern = re.compile(r"^(Items\.[A-Za-z0-9_]+)\s*:", re.MULTILINE)
        matches = pattern.findall(content)
        if len(matches) > 1:
            prefix = self._find_common_item_prefix(matches)
            if len(prefix) > len("Items.") + 3:
                self._link_siblings(matches, "TweakXL:regex_prefix", str(file_path))
                return len(matches)
        return len(matches)
