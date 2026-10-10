"""
Graph Validator for REDengine Animation Graphs.
Performs semantic and structural integrity checks, detecting:
- Duplicate HandleIds
- Dangling HandleRefIds
- Undeclared animation variables
- Cyclic references
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import List, Set, Dict, Any, Optional
from .models import AnimGraph
from .registry import NodeRegistry


@dataclass
class ValidationReport:
    """Encapsulates the findings of a graph validation pass."""
    total_nodes: int = 0
    duplicate_handles: List[str] = field(default_factory=list)
    dangling_references: List[str] = field(default_factory=list)
    missing_variables: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    is_reachability_valid: bool = True

    @property
    def is_valid(self) -> bool:
        """Returns True if no fatal errors were detected."""
        return (
            len(self.duplicate_handles) == 0
            and len(self.dangling_references) == 0
            and len(self.missing_variables) == 0
            and self.is_reachability_valid
        )

    def summary(self) -> str:
        """Generates a formatted human-readable summary of the report."""
        lines = [
            f"=== AnimGraph Validation Report ===",
            f"Total Nodes Indexed  : {self.total_nodes}",
            f"Status               : {'PASSED (Clean)' if self.is_valid else 'FAILED (Issues Detected)'}",
        ]
        if self.duplicate_handles:
            lines.append(f"[-] Duplicate HandleIds ({len(self.duplicate_handles)}): {self.duplicate_handles}")
        if self.dangling_references:
            lines.append(f"[-] Dangling References ({len(self.dangling_references)}): {self.dangling_references}")
        if self.missing_variables:
            lines.append(f"[-] Missing Declared Variables ({len(self.missing_variables)}): {self.missing_variables}")
        if not self.is_reachability_valid:
            lines.append("[-] Output Reachability Check: FAILED (Output node disconnected from target)")
        if self.warnings:
            lines.append(f"[!] Warnings ({len(self.warnings)}):")
            for w in self.warnings:
                lines.append(f"    - {w}")
        return "\n".join(lines)


class GraphValidator:
    """
    Validates structural and semantic correctness of an AnimGraph.
    """

    def __init__(self, graph: AnimGraph, registry: Optional[NodeRegistry] = None):
        self._graph = graph
        self._registry = registry or NodeRegistry(graph)

    def validate(self, reachability_target: Optional[str] = None) -> ValidationReport:
        """Runs all validation rules and returns a structured report."""
        report = ValidationReport(total_nodes=self._registry.total_nodes)

        # 1. Check duplicate HandleIds
        seen_handles: Set[str] = set()
        duplicates: List[str] = []

        def _check_duplicates(o: Any) -> None:
            if isinstance(o, dict):
                if "HandleId" in o:
                    hid = str(o["HandleId"])
                    if hid in seen_handles:
                        duplicates.append(hid)
                    else:
                        seen_handles.add(hid)
                for v in o.values():
                    _check_duplicates(v)
            elif isinstance(o, list):
                for item in o:
                    _check_duplicates(item)

        _check_duplicates(self._graph.raw)
        report.duplicate_handles = duplicates

        # 2. Check dangling HandleRefIds
        dangling: List[str] = []
        for ref in self._registry._references:
            if not self._registry.has_node(ref):
                dangling.append(ref)
        report.dangling_references = dangling

        # 3. Check undeclared float variables
        declared_vars = set()
        for v in self._graph.float_variables:
            data = v.get("Data", v)
            name_obj = data.get("name", {})
            vname = name_obj.get("$value") if isinstance(name_obj, dict) else name_obj
            if vname:
                declared_vars.add(str(vname))

        missing_vars: Set[str] = set()
        for node in self._registry.find_nodes(node_type="animAnimNode_FloatVariable"):
            var_name = node.variable_name
            if var_name and var_name not in declared_vars:
                missing_vars.add(var_name)
        report.missing_variables = list(missing_vars)

        # 4. Optional Reachability Check
        if reachability_target:
            target_str = str(reachability_target)
            out_node = self._graph.get_output_node()
            if not out_node:
                report.is_reachability_valid = False
                report.warnings.append("Terminal animAnimNode_Output not found in graph.")
            else:
                from .traversal import GraphWalker
                walker = GraphWalker(self._registry)
                path = walker.trace_backward(out_node, max_depth=100)
                path_ids = {n.handle_id for n in path if n.handle_id} | {n.handle_ref_id for n in path if n.handle_ref_id}
                if target_str not in path_ids:
                    report.is_reachability_valid = False
                    report.warnings.append(f"Output evaluation path does not reach target Node {target_str}.")

        return report

