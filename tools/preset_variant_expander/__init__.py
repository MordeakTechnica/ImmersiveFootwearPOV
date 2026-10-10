"""
Immersive Footwear POV — Preset Variant Expander.
A SOLID toolkit for discovering and expanding footwear color/material variants from mod archives and tweaks.
"""

from .core.models import ShoeCalibration, VariantMatch, ExpansionResult
from .core.interfaces import IVariantProvider, IPresetRepository, IPresetExpander
from .engine.expander import PresetExpansionEngine
from .providers.tweak_yaml_provider import TweakYamlVariantProvider
from .providers.equipment_ex_provider import EquipmentExVariantProvider
from .providers.archive_provider import ArchiveVariantProvider
from .providers.composite_provider import CompositeVariantProvider
from .repository.json_preset_repository import JsonPresetRepository

__all__ = [
    "ShoeCalibration",
    "VariantMatch",
    "ExpansionResult",
    "IVariantProvider",
    "IPresetRepository",
    "IPresetExpander",
    "PresetExpansionEngine",
    "TweakYamlVariantProvider",
    "EquipmentExVariantProvider",
    "ArchiveVariantProvider",
    "CompositeVariantProvider",
    "JsonPresetRepository",
]
