"""
Domain models for the Shoe Preset Variant Expander.
Adheres to the Single Responsibility Principle (SRP) by encapsulating data structures only.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set


@dataclass
class ShoeCalibration:
    """Represents physical height offsets for footwear."""
    heel: float
    platform: float = 0.0

    def to_dict(self) -> Dict[str, float]:
        return {
            "heel": round(float(self.heel), 2),
            "platform": round(float(self.platform), 2),
        }

    @classmethod
    def from_dict(cls, data: dict) -> "ShoeCalibration":
        heel = float(data.get("heel", 0.0))
        platform = float(data.get("platform", 0.0))
        return cls(heel=heel, platform=platform)


@dataclass
class VariantMatch:
    """Information regarding a discovered sibling variant."""
    item_id: str
    matched_via: str  # e.g., "TweakXL:instances", "TweakXL:sibling_record", "EquipmentEX:csv"
    source_file: str


@dataclass
class ExpansionResult:
    """Detailed outcome of an expansion run."""
    initial_items_count: int = 0
    total_items_count: int = 0
    new_variants_added: int = 0
    unresolved_items: List[str] = field(default_factory=list)
    added_variants: Dict[str, List[str]] = field(default_factory=dict)  # parent_id -> list of new sibling IDs
    variant_details: Dict[str, VariantMatch] = field(default_factory=dict)  # sibling_id -> VariantMatch metadata
    errors: List[str] = field(default_factory=list)

    @property
    def has_changes(self) -> bool:
        return self.new_variants_added > 0
