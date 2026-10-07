"""
Subtree Splicer for REDengine Animation Graphs.
Implements the Splicer / Strategy pattern to extract node subtrees from donor graphs
(e.g. IFP height blend), safely renumber all extracted handles to avoid collisions,
and splice leaves and roots into the destination graph.
"""

from __future__ import annotations
import copy
from typing import Dict, Any, Set, List, Optional
from ..core.models import AnimGraph, AnimNode
from ..core.registry import NodeRegistry


class SubtreeSplicer:
    """
    Safely extracts, renumbers, and splices subtrees between graphs.
    """

    def __init__(self, target_graph: AnimGraph, registry: Optional[NodeRegistry] = None):
        self._target_graph = target_graph
        self._registry = registry or NodeRegistry(target_graph)

    def extract_and_splice_two_branch_blend(
        self,
        donor_blend_node_dict: Dict[str, Any],
        parent_node: AnimNode,
        leaf_target_node: AnimNode,
        input_link_prop: str = "inputLink",
        base_handle_hint: int = 6100,
    ) -> Dict[str, Any]:
        """
        Extracts a two-branch Blend2 subtree (such as IFP runtime height),
        splices its two branch leaves into leaf_target_node, renumbers all handles
        in the imported tree to safe unique IDs, and attaches the root Blend2
        to parent_node[input_link_prop].
        """
        blend_tree = copy.deepcopy(donor_blend_node_dict)

        # 1. Find leaf nodes of both branches
        def _get_leaf(curr_node_dict: Dict[str, Any]) -> Dict[str, Any]:
            curr = curr_node_dict
            while True:
                d = curr.get("Data", curr)
                inp = d.get("inputNode") or d.get("inputLink")
                if not isinstance(inp, dict):
                    break
                nxt = inp.get("node")
                if isinstance(nxt, dict) and "Data" in nxt:
                    curr = nxt
                else:
                    break
            return curr

        b1_root = blend_tree["Data"]["firstInputNode"]["node"]
        b2_root = blend_tree["Data"]["secondInputNode"]["node"]

        leaf_b1 = _get_leaf(b1_root)
        leaf_b2 = _get_leaf(b2_root)

        # 2. Wire leaf inputs to leaf_target_node
        # Branch 1 embeds the target node object or reference
        leaf_target_hid = leaf_target_node.handle_id
        leaf_b1["Data"]["inputNode"] = {
            "$type": "animPoseLink",
            "node": leaf_target_node.raw,
        }
        # Branch 2 references leaf_target_node by HandleRefId
        leaf_b2["Data"]["inputNode"] = {
            "$type": "animPoseLink",
            "node": {
                "HandleRefId": leaf_target_hid,
            },
        }

        # 3. Collect and renumber all handles in the injected tree
        handles_in_tree: Set[str] = set()

        def _collect(o: Any) -> None:
            if isinstance(o, dict):
                # Do not renumber the leaf target node!
                if str(o.get("HandleId")) == leaf_target_hid:
                    return
                if "HandleId" in o:
                    handles_in_tree.add(str(o["HandleId"]))
                for v in o.values():
                    _collect(v)
            elif isinstance(o, list):
                for x in o:
                    _collect(x)

        _collect(blend_tree)

        # Map old handles to new unique handles
        old_to_new: Dict[str, str] = {}
        for old_id in sorted([int(h) for h in handles_in_tree if h.isdigit()]):
            old_str = str(old_id)
            new_id = self._registry.allocate_handle(base_hint=base_handle_hint)
            old_to_new[old_str] = new_id

        def _apply_renumbering(o: Any) -> None:
            if isinstance(o, dict):
                if str(o.get("HandleId")) == leaf_target_hid:
                    return
                if "HandleId" in o:
                    hid = str(o["HandleId"])
                    if hid in old_to_new:
                        o["HandleId"] = old_to_new[hid]
                if "HandleRefId" in o:
                    ref = str(o["HandleRefId"])
                    if ref in old_to_new:
                        o["HandleRefId"] = old_to_new[ref]
                for v in o.values():
                    _apply_renumbering(v)
            elif isinstance(o, list):
                for x in o:
                    _apply_renumbering(x)

        _apply_renumbering(blend_tree)

        # 4. Attach blend_tree root to parent_node
        parent_node.data[input_link_prop] = {
            "$type": "animPoseLink",
            "node": blend_tree,
        }

        # Rebuild registry index
        self._registry.rebuild_index()
        return blend_tree
