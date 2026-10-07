"""
Node Registry for REDengine Animation Graphs.
Implements the Registry Pattern to index all nodes, manage unique HandleIds,
and provide semantic node search without hardcoding numeric IDs.
"""

from __future__ import annotations
from typing import Dict, List, Set, Optional, Callable, Any
from .models import AnimGraph, AnimNode


class NodeRegistry:
    """
    Maintains an in-memory index of all nodes and references in an AnimGraph.
    Provides conflict-free ID allocation and query capabilities.
    """

    def __init__(self, graph: AnimGraph):
        self._graph = graph
        self._nodes_by_id: Dict[str, AnimNode] = {}
        self._references: Set[str] = set()
        self._max_id: int = 0
        self._reserved_ids: Set[str] = set()
        self.rebuild_index()

    def rebuild_index(self) -> None:
        """Scans the graph and indexes all HandleId and HandleRefId occurrences."""
        self._nodes_by_id.clear()
        self._references.clear()
        self._max_id = 0

        def _scan(obj: Any) -> None:
            if isinstance(obj, dict):
                if "HandleId" in obj:
                    hid = str(obj["HandleId"])
                    node = AnimNode(obj)
                    self._nodes_by_id[hid] = node
                    if hid.isdigit():
                        self._max_id = max(self._max_id, int(hid))
                if "HandleRefId" in obj:
                    self._references.add(str(obj["HandleRefId"]))
                for v in obj.values():
                    _scan(v)
            elif isinstance(obj, list):
                for item in obj:
                    _scan(item)

        _scan(self._graph.raw)
        # Ensure max_id also accounts for any reserved handles
        for rid in self._reserved_ids:
            if rid.isdigit():
                self._max_id = max(self._max_id, int(rid))

    @property
    def max_handle_id(self) -> int:
        """Returns the highest integer HandleId present in the graph."""
        return self._max_id

    @property
    def total_nodes(self) -> int:
        """Returns the total number of uniquely indexed nodes."""
        return len(self._nodes_by_id)

    def get_node(self, handle_id: Union[str, int]) -> Optional[AnimNode]:
        """Retrieves an AnimNode by its HandleId."""
        return self._nodes_by_id.get(str(handle_id))

    def has_node(self, handle_id: Union[str, int]) -> bool:
        """Checks if a HandleId exists in the graph."""
        return str(handle_id) in self._nodes_by_id

    def allocate_handle(self, base_hint: Optional[int] = None) -> str:
        """
        Allocates a new, guaranteed unique HandleId.
        Starts at base_hint or (max_id + 1), avoiding any existing or reserved ID.
        """
        start = base_hint if (base_hint and base_hint > self._max_id) else (self._max_id + 1)
        while str(start) in self._nodes_by_id or str(start) in self._reserved_ids:
            start += 1
        allocated_str = str(start)
        self._reserved_ids.add(allocated_str)
        self._max_id = max(self._max_id, start)
        return allocated_str

    def allocate_handle_block(self, count: int, base_hint: Optional[int] = None) -> List[str]:
        """Allocates a contiguous block of unique HandleIds."""
        start = base_hint if (base_hint and base_hint > self._max_id) else (self._max_id + 1)
        allocated = []
        curr = start
        while len(allocated) < count:
            curr_str = str(curr)
            if curr_str not in self._nodes_by_id and curr_str not in self._reserved_ids:
                allocated.append(curr_str)
                self._reserved_ids.add(curr_str)
            curr += 1
        self._max_id = max(self._max_id, curr - 1)
        return allocated

    def find_nodes(
        self,
        node_type: Optional[str] = None,
        debug_name: Optional[str] = None,
        bone_name: Optional[str] = None,
        variable_name: Optional[str] = None,
        predicate: Optional[Callable[[AnimNode], bool]] = None,
    ) -> List[AnimNode]:
        """
        Queries nodes using semantic criteria rather than hardcoded IDs.
        All filters provided are combined via logical AND.
        """
        results: List[AnimNode] = []
        for node in self._nodes_by_id.values():
            if node_type and node.node_type != node_type:
                continue
            if debug_name and node.debug_name != debug_name:
                continue
            if bone_name and node.bone_name != bone_name:
                continue
            if variable_name and node.variable_name != variable_name:
                continue
            if predicate and not predicate(node):
                continue
            results.append(node)
        return results

    def find_one(
        self,
        node_type: Optional[str] = None,
        debug_name: Optional[str] = None,
        bone_name: Optional[str] = None,
        variable_name: Optional[str] = None,
        predicate: Optional[Callable[[AnimNode], bool]] = None,
    ) -> Optional[AnimNode]:
        """Finds the first node matching the specified criteria."""
        matches = self.find_nodes(
            node_type=node_type,
            debug_name=debug_name,
            bone_name=bone_name,
            variable_name=variable_name,
            predicate=predicate,
        )
        return matches[0] if matches else None
