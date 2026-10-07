"""
Footwear Elevation Recipe.
Inserts dynamic vertical elevation for third-person / photo mode platform soles
(foot_elevation_offset) into the graph output pipeline.
"""

from __future__ import annotations
from typing import Optional
from .base import GraphRecipe
from ..core.models import AnimGraph, AnimNode
from ..core.registry import NodeRegistry
from ..builder.pipeline_builder import PipelineBuilder


class FootElevationRecipe(GraphRecipe):
    """
    Applies puppet elevation blend for high heels and platform shoes.
    """

    def __init__(self, max_elevation_meters: float = 1.0):
        self._max_elevation = max_elevation_meters

    @property
    def name(self) -> str:
        return "Footwear Elevation (ITP / Photo Mode)"

    @property
    def description(self) -> str:
        return "Inserts dynamic vertical offset blend (foot_elevation_offset) on Hips at graph output."

    def apply(self, graph: AnimGraph, registry: NodeRegistry) -> bool:
        out_node = graph.get_output_node()
        if not out_node:
            raise ValueError("Output node could not be located in AnimGraph.")

        base_pose = out_node.data["node"]["node"]

        builder = PipelineBuilder(graph, base_pose, registry)
        builder.add_elevation_blend(
            variable_name="foot_elevation_offset",
            bone_name="Hips",
            max_height_z=self._max_elevation,
            debug_label="ITP_Output_Elevation_Blend2",
        )
        builder.connect_to_output(out_node)

        graph.ensure_float_variable(
            name="foot_elevation_offset",
            handle_id=registry.allocate_handle(),
            default_val=0.0, min_val=-1.0, max_val=1.0,
        )

        registry.rebuild_index()
        return True
