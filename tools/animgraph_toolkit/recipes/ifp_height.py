"""
IFP Height Integration Recipe.
Slices the authentic 30-node Immersive First Person runtime height tree
into the skeletal solver chain between ParentConstraint(Hips) and PointConstraint(Torso_Spine2_Up_GRP).
"""

from __future__ import annotations
import json
from typing import Optional
from .base import GraphRecipe
from ..core.models import AnimGraph
from ..core.registry import NodeRegistry
from ..builder.splicer import SubtreeSplicer


class IFPHeightRecipe(GraphRecipe):
    """
    Applies authentic Immersive First Person height scaling to the graph.
    """

    def __init__(self, ifp_graph_path: str, base_handle_hint: int = 6100):
        self._ifp_path = ifp_graph_path
        self._base_handle_hint = base_handle_hint

    @property
    def name(self) -> str:
        return "IFP Height Integration"

    @property
    def description(self) -> str:
        return "Splices authentic 30-node IFP height scaling between Hips constraint and Torso constraint."

    def apply(self, graph: AnimGraph, registry: NodeRegistry) -> bool:
        # 1. Load donor IFP graph
        with open(self._ifp_path, "r", encoding="utf-8") as f:
            donor_raw = json.load(f)
        donor_graph = AnimGraph(donor_raw)
        donor_registry = NodeRegistry(donor_graph)

        # 2. Locate IFP Blend2 node in donor graph
        ifp_blend = donor_registry.find_one(debug_name="ImmersiveFirstPerson_Runtime_Height_v2_signed_50cm")
        if not ifp_blend:
            # Fallback to handle 3734
            ifp_blend = donor_registry.get_node("3734")
        if not ifp_blend:
            raise ValueError("Could not locate IFP Runtime Height Blend2 node in donor graph.")

        # 3. Locate target constraint nodes in destination graph
        # Node 3903 (ParentConstraint on Hips) and 3904 (PointConstraint on Torso_Spine2_Up_GRP)
        hips_parent = registry.get_node("3903")
        if not hips_parent:
            hips_parent = registry.find_one(bone_name="Hips", node_type="animAnimNode_ParentConstraint")
        if not hips_parent:
            raise ValueError("Target graph is missing ParentConstraint on Hips (Node 3903).")

        torso_point = registry.get_node("3904")
        if not torso_point:
            torso_point = registry.find_one(bone_name="Torso_Spine2_Up_GRP", node_type="animAnimNode_PointConstraint")
        if not torso_point:
            raise ValueError("Target graph is missing PointConstraint on Torso_Spine2_Up_GRP (Node 3904).")

        # 4. Splice IFP subtree
        splicer = SubtreeSplicer(graph, registry)
        splicer.extract_and_splice_two_branch_blend(
            donor_blend_node_dict=ifp_blend.raw,
            parent_node=hips_parent,
            leaf_target_node=torso_point,
            input_link_prop="inputLink",
            base_handle_hint=self._base_handle_hint,
        )

        # 5. Ensure required float variables
        graph.ensure_float_variable(
            name="ifp_height_blend",
            handle_id=registry.allocate_handle(),
            default_val=0.5, min_val=0.0, max_val=1.0,
        )
        graph.ensure_float_variable(
            name="ifp_height_contract_v2_signed_50cm",
            handle_id=registry.allocate_handle(),
            default_val=0.5, min_val=0.0, max_val=1.0,
        )

        registry.rebuild_index()
        return True
