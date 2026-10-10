"""
Composite Variant Provider.
Implements the Composite / Chain-of-Responsibility design pattern.
Aggregates multiple variant discovery providers and merges their discovered sibling sets.
"""

from pathlib import Path
from typing import Any, Dict, List, Optional, Set

from ..core.interfaces import IVariantProvider
from ..core.models import VariantMatch


class CompositeVariantProvider(IVariantProvider):
    """Aggregates multiple variant sources and unifies their results."""

    def __init__(self, providers: Optional[List[IVariantProvider]] = None):
        self._providers: List[IVariantProvider] = providers or []

    def add_provider(self, provider: IVariantProvider) -> None:
        self._providers.append(provider)

    def index_directory(
        self,
        root_dir: Path,
        progress_callback: Optional[Any] = None
    ) -> int:
        total = 0
        for provider in self._providers:
            total += provider.index_directory(root_dir, progress_callback=progress_callback)
        return total

    def find_siblings(self, item_id: str) -> List[VariantMatch]:
        combined_matches: List[VariantMatch] = []
        seen_items: Set[str] = set()

        for provider in self._providers:
            matches = provider.find_siblings(item_id)
            for match in matches:
                norm = match.item_id.strip().lower()
                if norm not in seen_items and norm != item_id.strip().lower():
                    seen_items.add(norm)
                    combined_matches.append(match)

        return combined_matches
