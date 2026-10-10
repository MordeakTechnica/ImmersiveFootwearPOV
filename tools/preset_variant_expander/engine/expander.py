"""
Preset Expansion Engine.
Orchestrates variant discovery and preset expansion across providers.
Adheres to the Dependency Inversion Principle (DIP) by depending on IVariantProvider interface.
"""

from typing import Dict, List, Set, Tuple

from ..core.interfaces import IPresetExpander, IVariantProvider
from ..core.models import ExpansionResult, ShoeCalibration, VariantMatch


class PresetExpansionEngine(IPresetExpander):
    """Core engine responsible for expanding single-item presets to all sibling variants."""

    def __init__(self, provider: IVariantProvider):
        self._provider = provider

    def expand(
        self,
        input_presets: Dict[str, ShoeCalibration],
        overwrite_existing: bool = False
    ) -> Tuple[Dict[str, ShoeCalibration], ExpansionResult]:
        """
        Expand input presets across all discovered sibling variants.
        Preserves existing custom calibrations unless overwrite_existing is True.
        """
        output_presets: Dict[str, ShoeCalibration] = dict(input_presets)
        result = ExpansionResult(
            initial_items_count=len(input_presets),
        )

        # Build normalized lookup for existing items
        existing_normalized: Dict[str, str] = {
            k.strip().lower(): k for k in output_presets.keys()
        }

        for item_id, calibration in list(input_presets.items()):
            siblings: List[VariantMatch] = self._provider.find_siblings(item_id)

            if not siblings:
                result.unresolved_items.append(item_id)
                continue

            added_for_this_item: List[str] = []

            for sib in siblings:
                sib_id = sib.item_id
                sib_norm = sib_id.strip().lower()

                # If sibling already exists in output
                if sib_norm in existing_normalized:
                    if overwrite_existing:
                        orig_key = existing_normalized[sib_norm]
                        output_presets[orig_key] = ShoeCalibration(
                            heel=calibration.heel,
                            platform=calibration.platform
                        )
                    continue

                # Add newly discovered sibling with identical height calibration
                output_presets[sib_id] = ShoeCalibration(
                    heel=calibration.heel,
                    platform=calibration.platform
                )
                existing_normalized[sib_norm] = sib_id
                added_for_this_item.append(sib_id)
                result.variant_details[sib_id] = sib
                result.new_variants_added += 1

            if added_for_this_item:
                result.added_variants[item_id] = added_for_this_item

        result.total_items_count = len(output_presets)
        return output_presets, result
