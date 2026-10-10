"""
Core abstractions and interface contracts for the Preset Variant Expander.
Adheres to Interface Segregation Principle (ISP) and Dependency Inversion Principle (DIP).
"""

from abc import ABC, abstractmethod
from pathlib import Path
from typing import Callable, Dict, List, Optional, Set
from .models import ShoeCalibration, VariantMatch, ExpansionResult

ProgressCallback = Callable[[str, int, int, int], None]  # (current_file, processed_files, total_files, variants_found)


class IVariantProvider(ABC):
    """Strategy interface for discovering footwear variant relationships from external sources."""

    @abstractmethod
    def index_directory(
        self,
        root_dir: Path,
        progress_callback: Optional[ProgressCallback] = None
    ) -> int:
        """Scan and index all files in the given directory. Returns count of discovered items/templates."""
        pass

    @abstractmethod
    def find_siblings(self, item_id: str) -> List[VariantMatch]:
        """Given a known item ID, return all discovered sibling variants."""
        pass


class IPresetRepository(ABC):
    """Repository interface for loading and saving footwear preset definitions."""

    @abstractmethod
    def load(self, file_path: Path) -> Dict[str, ShoeCalibration]:
        """Load presets from a JSON file, filtering out non-shoe properties."""
        pass

    @abstractmethod
    def save(self, file_path: Path, presets: Dict[str, ShoeCalibration]) -> None:
        """Persist presets cleanly to a JSON file in alphabetized order."""
        pass


class IPresetExpander(ABC):
    """Facade / Service interface for executing preset expansion workflows."""

    @abstractmethod
    def expand(
        self,
        input_presets: Dict[str, ShoeCalibration],
        overwrite_existing: bool = False
    ) -> tuple[Dict[str, ShoeCalibration], ExpansionResult]:
        """Expand single-item presets across all discovered sibling variants."""
        pass
