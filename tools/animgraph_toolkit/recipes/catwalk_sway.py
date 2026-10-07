"""
Catwalk Sway and Counter-Rotation Recipe.
Inserts procedural pelvic rotation and spinal/femoral stabilization nodes
into the output pipeline for catwalk gait locomotion.
"""

from __future__ import annotations
from .base import GraphRecipe
from ..core.models import AnimGraph
from ..core.registry import NodeRegistry
from ..builder.pipeline_builder import PipelineBuilder


class CatwalkSwayRecipe(GraphRecipe):
    """
    Applies pelvic roll/yaw, thoracic counter-rotation, and femoral counter-roll.
    """

    @property
    def name(self) -> str:
        return "Catwalk Locomotion Sway & Counter-Rotation"

    @property
    def description(self) -> str:
        return "Injects 6 procedural RotateBone nodes for pelvic and femoral balance at graph output."

    def apply(self, graph: AnimGraph, registry: NodeRegistry) -> bool:
        out_node = graph.get_output_node()
        if not out_node:
            raise ValueError("Output node could not be located in AnimGraph.")

        base_pose = out_node.data["node"]["node"]

        builder = PipelineBuilder(graph, base_pose, registry)
        (
            builder
            .add_rotate_bone("Hips", "Y_Axis", "ifp_hip_sway_roll", debug_label="IFP_Sway_Roll_Hips")
            .add_rotate_bone("Hips", "Z_Axis", "ifp_hip_sway_yaw", debug_label="IFP_Sway_Yaw_Hips")
            .add_rotate_bone("Spine2", "Z_Axis", "ifp_spine_counter_yaw", debug_label="IFP_Counter_Yaw_Spine")
            .add_rotate_bone("Spine2", "Y_Axis", "ifp_spine_counter_roll", debug_label="IFP_Counter_Roll_Spine")
            .add_rotate_bone("LeftUpLeg", "Y_Axis", "ifp_leg_counter_roll", debug_label="IFP_Counter_Roll_LeftUpLeg")
            .add_rotate_bone("RightUpLeg", "Y_Axis", "ifp_leg_counter_roll", debug_label="IFP_Counter_Roll_RightUpLeg")
        )
        builder.connect_to_output(out_node)

        # Register sway variables
        sway_vars = [
            ("ifp_hip_sway_roll", 0.0, -45.0, 45.0),
            ("ifp_hip_sway_pitch", 0.0, -45.0, 45.0),
            ("ifp_hip_sway_yaw", 0.0, -45.0, 45.0),
            ("ifp_hip_sway_blend", 0.0, 0.0, 1.0),
            ("ifp_spine_counter_yaw", 0.0, -45.0, 45.0),
            ("ifp_spine_counter_roll", 0.0, -45.0, 45.0),
            ("ifp_leg_counter_roll", 0.0, -45.0, 45.0),
        ]
        for vname, dval, mval, mxval in sway_vars:
            graph.ensure_float_variable(
                name=vname,
                handle_id=registry.allocate_handle(),
                default_val=dval, min_val=mval, max_val=mxval,
            )

        registry.rebuild_index()
        return True
