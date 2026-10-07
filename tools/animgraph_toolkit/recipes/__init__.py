"""
Recipes package for AnimGraph Toolkit.
"""

from .base import GraphRecipe
from .ifp_height import IFPHeightRecipe
from .foot_elevation import FootElevationRecipe
from .catwalk_sway import CatwalkSwayRecipe

__all__ = [
    "GraphRecipe",
    "IFPHeightRecipe",
    "FootElevationRecipe",
    "CatwalkSwayRecipe",
]
