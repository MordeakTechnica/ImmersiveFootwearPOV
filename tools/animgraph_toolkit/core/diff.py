"""
Graph Differ for REDengine Animation Graphs.
Compares two AnimGraph files to identify added/removed handles,
modified node properties, rewires, and variable discrepancies.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Dict, List, Set, Optional, Any
from .models import AnimGraph, AnimNode
from .registry import NodeRegistry


@dataclass
class NodeDiffEntry:
    """Represents a modification between two versions of the same node."""
    handle_id: str
    node_type: str
    debug_name: Optional[str]
    differences: Dict[str, Dict[str, Any]]  # property_name -> {"old": val, "new": val}


@dataclass
class DiffReport:
    """Encapsulates the structural and semantic differences between two AnimGraphs."""
    graph_a_nodes: int = 0
    graph_b_nodes: int = 0
    nodes_added: List[str] = field(default_factory=list)
    nodes_removed: List[str] = field(default_factory=list)
    nodes_modified: List[NodeDiffEntry] = field(default_factory=list)
    variables_added: List[str] = field(default_factory=list)
    variables_removed: List[str] = field(default_factory=list)

    @property
    def has_differences(self) -> bool:
        """Returns True if any additions, removals, or modifications were found."""
        return bool(
            self.nodes_added
            or self.nodes_removed
            or self.nodes_modified
            or self.variables_added
            or self.variables_removed
        )

    def summary(self) -> str:
        """Formats a human-readable summary of graph differences."""
        lines = [
            "=== AnimGraph Structural Diff Report ===",
            f"Graph A Nodes: {self.graph_a_nodes} | Graph B Nodes: {self.graph_b_nodes}",
            f"Status       : {'DIFFERENCES DETECTED' if self.has_differences else 'IDENTICAL'}",
        ]
        if self.nodes_added:
            lines.append(f"[+] Added Nodes in Graph B ({len(self.nodes_added)}): {self.nodes_added[:15]}{' ...' if len(self.nodes_added) > 15 else ''}")
        if self.nodes_removed:
            lines.append(f"[-] Removed Nodes from Graph A ({len(self.nodes_removed)}): {self.nodes_removed[:15]}{' ...' if len(self.nodes_removed) > 15 else ''}")
        if self.variables_added:
            lines.append(f"[+] Added Float Variables ({len(self.variables_added)}): {self.variables_added}")
        if self.variables_removed:
            lines.append(f"[-] Removed Float Variables ({len(self.variables_removed)}): {self.variables_removed}")
        if self.nodes_modified:
            lines.append(f"[*] Modified Nodes ({len(self.nodes_modified)}):")
            for m in self.nodes_modified[:10]:
                lines.append(f"    - Node {m.handle_id} [{m.node_type}] ({m.debug_name or 'unnamed'}):")
                for prop, diff in m.differences.items():
                    lines.append(f"        {prop}: {diff.get('old')} -> {diff.get('new')}")
            if len(self.nodes_modified) > 10:
                lines.append(f"    ... and {len(self.nodes_modified) - 10} more modified node(s).")
        return "\n".join(lines)


class GraphDiffer:
    """
    Compares two animation graphs and produces a detailed DiffReport.
    """

    def diff(self, graph_a: AnimGraph, graph_b: AnimGraph) -> DiffReport:
        """Compares graph_a and graph_b."""
        reg_a = NodeRegistry(graph_a)
        reg_b = NodeRegistry(graph_b)

        report = DiffReport(
            graph_a_nodes=reg_a.total_nodes,
            graph_b_nodes=reg_b.total_nodes,
        )

        handles_a = set(reg_a.all_handle_ids)
        handles_b = set(reg_b.all_handle_ids)

        report.nodes_added = sorted(list(handles_b - handles_a), key=lambda x: int(x) if x.isdigit() else 999999)
        report.nodes_removed = sorted(list(handles_a - handles_b), key=lambda x: int(x) if x.isdigit() else 999999)

        # Check common nodes for property modifications
        common_handles = handles_a & handles_b
        modified_entries: List[NodeDiffEntry] = []

        for hid in sorted(common_handles, key=lambda x: int(x) if x.isdigit() else 999999):
            node_a = reg_a.get_node(hid)
            node_b = reg_b.get_node(hid)
            if not node_a or not node_b:
                continue

            diffs: Dict[str, Dict[str, Any]] = {}

            # Type check
            if node_a.node_type != node_b.node_type:
                diffs["$type"] = {"old": node_a.node_type, "new": node_b.node_type}

            # Debug name check
            if node_a.debug_name != node_b.debug_name:
                diffs["debugName"] = {"old": node_a.debug_name, "new": node_b.debug_name}

            # Bone target check
            if node_a.bone_name != node_b.bone_name:
                diffs["bone"] = {"old": node_a.bone_name, "new": node_b.bone_name}

            # Variable binding check
            if node_a.variable_name != node_b.variable_name:
                diffs["variableName"] = {"old": node_a.variable_name, "new": node_b.variable_name}

            # Input links check
            for link_prop in ["inputNode", "inputLink", "firstInputNode", "secondInputNode"]:
                target_a = node_a.get_input_target_id(link_prop)
                target_b = node_b.get_input_target_id(link_prop)
                if target_a != target_b:
                    diffs[link_prop] = {"old": target_a, "new": target_b}

            if diffs:
                modified_entries.append(
                    NodeDiffEntry(
                        handle_id=hid,
                        node_type=node_b.node_type or "Unknown",
                        debug_name=node_b.debug_name,
                        differences=diffs,
                    )
                )

        report.nodes_modified = modified_entries

        # Check float variable discrepancies
        def _get_var_names(g: AnimGraph) -> Set[str]:
            names = set()
            for v in g.float_variables:
                data = v.get("Data", v)
                val_obj = data.get("name", {})
                vname = val_obj.get("$value") if isinstance(val_obj, dict) else val_obj
                if vname:
                    names.add(str(vname))
            return names

        vars_a = _get_var_names(graph_a)
        vars_b = _get_var_names(graph_b)

        report.variables_added = sorted(list(vars_b - vars_a))
        report.variables_removed = sorted(list(vars_a - vars_b))

        return report
