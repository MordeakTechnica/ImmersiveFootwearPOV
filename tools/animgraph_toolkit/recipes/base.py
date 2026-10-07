"""
Base Recipe Interface for Animation Graph Patches.
Implements the Strategy / Command Pattern for modular, reusable animgraph modifications.
"""

from __future__ import annotations
from abc import ABC, abstractmethod
from ..core.models import AnimGraph
from ..core.registry import NodeRegistry


class GraphRecipe(ABC):
    """
    Abstract base class for modular animation graph recipes.
    """

    @property
    @abstractmethod
    def name(self) -> str:
        """Name of the recipe."""
        pass

    @property
    @abstractmethod
    def description(self) -> str:
        """Description of what this recipe modifies."""
        pass

    @abstractmethod
    def apply(self, graph: AnimGraph, registry: NodeRegistry) -> bool:
        """
        Applies the recipe modifications to the graph.
        Returns True if successful, False otherwise.
        """
        pass
