"""Core models and interfaces for Preset Variant Expander."""

from .models import ShoeCalibration, VariantMatch, ExpansionResult
from .interfaces import IVariantProvider, IPresetRepository, IPresetExpander
from .footwear_filter import FootwearClassifier

__all__ = [
    "ShoeCalibration",
    "VariantMatch",
    "ExpansionResult",
    "IVariantProvider",
    "IPresetRepository",
    "IPresetExpander",
    "FootwearClassifier",
]
