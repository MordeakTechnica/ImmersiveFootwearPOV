"""
Graph Traversal and Path Tracking for REDengine Animation Graphs.
Implements the Walker / Visitor pattern to trace evaluation flows,
discover parent-child connections, and analyze bone transform pipelines.
"""

from __future__ import annotations
from typing import List, Dict, Set, Optional, Any, Union
from .models import AnimNode
from .registry import NodeRegistry


class GraphWalker:
    """
    Provides bidirectional traversal across REDengine pose and link graphs.
    """

    def __init__(self, registry: NodeRegistry):
        self._registry = registry

    def trace_backward(self, start_node: AnimNode, max_depth: int = 100) -> List[AnimNode]:
        """
        Traces backward along the primary input links (e.g. from Output toward Root).
        Recognizes inputNode, inputLink, firstInputNode, and node properties.
        """
        path: List[AnimNode] = [start_node]
        visited: Set[str] = set()
        curr = start_node

        input_keys = ["inputNode", "inputLink", "firstInputNode", "node", "poseInputNode"]

        for _ in range(max_depth):
            hid = curr.handle_id or curr.handle_ref_id
            if hid:
                if hid in visited:
                    break  # Cycle detected
                visited.add(hid)

            found_next: Optional[AnimNode] = None
            for key in input_keys:
                link = curr.data.get(key)
                if isinstance(link, dict) and "node" in link:
                    nxt = link["node"]
                    if isinstance(nxt, dict):
                        target_id = nxt.get("HandleId") or nxt.get("HandleRefId")
                        if target_id and self._registry.has_node(target_id):
                            found_next = self._registry.get_node(target_id)
                            break
                        elif target_id:
                            # Reference not directly indexed as top-level handle
                            found_next = AnimNode(nxt)
                            break

            if found_next:
                path.append(found_next)
                curr = found_next
            else:
                break

        return path

    def find_referencing_nodes(self, target_handle_id: str) -> List[AnimNode]:
        """
        Finds all nodes in the graph that directly point to target_handle_id
        via HandleRefId or embedded link.
        """
        results: List[AnimNode] = []
        target_str = str(target_handle_id)

        for hid, node in self._registry._nodes_by_id.items():
            if hid == target_str:
                continue

            # Check if target_str is referenced anywhere in node's raw data
            def _has_ref(o: Any) -> bool:
                if isinstance(o, dict):
                    if str(o.get("HandleRefId")) == target_str:
                        return True
                    return any(_has_ref(v) for v in o.values())
                elif isinstance(o, list):
                    return any(_has_ref(x) for x in o)
                return False

            if _has_ref(node.raw):
                results.append(node)

        return results

    def collect_subtree_handles(self, root_node_dict: Dict[str, Any]) -> Set[str]:
        """
        Recursively collects all HandleIds defined within a subtree dictionary.
        """
        handles: Set[str] = set()

        def _walk(o: Any) -> None:
            if isinstance(o, dict):
                if "HandleId" in o:
                    handles.add(str(o["HandleId"]))
                for v in o.values():
                    _walk(v)
            elif isinstance(o, list):
                for x in o:
                    _walk(x)

        _walk(root_node_dict)
        return handles

    def find_ast_path(self, target_handle_id: str, root_obj: Optional[Any] = None) -> Optional[List[Union[str, int]]]:
        """
        Locates the exact JSON AST path (keys and array indices) from root down to target_handle_id.
        """
        target_str = str(target_handle_id)
        root = root_obj if root_obj is not None else self._registry.graph.raw
        path: List[Union[str, int]] = []

        def _search(curr: Any, cur_path: List[Union[str, int]]) -> bool:
            if isinstance(curr, dict):
                if str(curr.get("HandleId")) == target_str:
                    path.extend(cur_path)
                    return True
                for k, v in curr.items():
                    if _search(v, cur_path + [k]):
                        return True
            elif isinstance(curr, list):
                for idx, item in enumerate(curr):
                    if _search(item, cur_path + [idx]):
                        return True
            return False

        if _search(root, []):
            return path
        return None

    def get_enclosing_node(self, target_handle_id: str) -> Optional[AnimNode]:
        """
        Finds the nearest ancestor object that represents an enclosing AnimNode.
        """
        path = self.find_ast_path(target_handle_id)
        if not path or len(path) <= 2:
            return None

        # Step back along path to find nearest ancestor dictionary that has a HandleId or $type
        curr: Any = self._registry.graph.raw
        ancestors: List[Any] = [curr]
        for step in path[:-1]:
            curr = curr[step]
            ancestors.append(curr)

        # Walk backward from parent up to find an enclosing node
        for anc in reversed(ancestors[:-1]):
            if isinstance(anc, dict):
                if "HandleId" in anc and str(anc["HandleId"]) != str(target_handle_id):
                    return AnimNode(anc)
                elif "Data" in anc and isinstance(anc["Data"], dict) and "$type" in anc["Data"]:
                    return AnimNode(anc)

        return None

