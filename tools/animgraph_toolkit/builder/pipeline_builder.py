"""
Pipeline Builder for REDengine Animation Graphs.
Implements the Builder Pattern to construct sequential transform and blend pipelines
(e.g. elevation offsets, hip sways, spine counter-rotations) fluently.
"""

from __future__ import annotations
from typing import Dict, Any, Optional, Union
from ..core.models import AnimGraph, AnimNode
from ..core.registry import NodeRegistry
from ..factory.node_factory import NodeFactory


class PipelineBuilder:
    """
    Fluent builder for chaining bone rotations, translations, and blends.
    """

    def __init__(self, graph: AnimGraph, base_input_node: Union[AnimNode, Dict[str, Any]], registry: Optional[NodeRegistry] = None):
        self._graph = graph
        self._registry = registry or NodeRegistry(graph)
        self._current_terminal: Dict[str, Any] = (
            base_input_node.raw if isinstance(base_input_node, AnimNode) else base_input_node
        )

    @property
    def current_node(self) -> Dict[str, Any]:
        """Gets the current head node of the pipeline."""
        return self._current_terminal

    def add_elevation_blend(
        self,
        variable_name: str,
        bone_name: str = "Hips",
        max_height_z: float = 1.0,
        debug_label: str = "Elevation_Blend",
    ) -> PipelineBuilder:
        """
        Inserts an elevation Blend2 node that translates a bone along Z
        scaled by variable_name.
        """
        var_hid = self._registry.allocate_handle()
        vec_hid = self._registry.allocate_handle()
        tb_hid = self._registry.allocate_handle()
        blend_hid = self._registry.allocate_handle()

        base_ref_id = self._current_terminal.get("HandleId") or self._current_terminal.get("HandleRefId")

        var_node = NodeFactory.create_float_variable_node(
            handle_id=var_hid,
            variable_name=variable_name,
            debug_name=f"{debug_label}_Var",
        )
        vec_node = NodeFactory.create_vector_constant(
            handle_id=vec_hid,
            x=0.0,
            y=0.0,
            z=max_height_z,
            debug_name=f"{debug_label}_Vec",
        )
        tb_node = NodeFactory.create_translate_bone(
            handle_id=tb_hid,
            bone_name=bone_name,
            input_pose=str(base_ref_id),
            input_translation=vec_node,
            debug_name=f"{debug_label}_Translate",
        )
        blend_node = NodeFactory.create_blend2(
            handle_id=blend_hid,
            first_input=self._current_terminal,
            second_input=tb_node,
            weight_node=var_node,
            debug_name=debug_label,
        )

        self._current_terminal = blend_node
        return self

    def add_rotate_bone(
        self,
        bone_name: str,
        axis: str,
        variable_name: str,
        min_angle: float = -45.0,
        max_angle: float = 45.0,
        in_model_space: int = 1,
        debug_label: Optional[str] = None,
    ) -> PipelineBuilder:
        """
        Inserts a RotateBone node driven by variable_name on top of the current pipeline head.
        """
        var_hid = self._registry.allocate_handle()
        rot_hid = self._registry.allocate_handle()

        var_node = NodeFactory.create_float_variable_node(
            handle_id=var_hid,
            variable_name=variable_name,
            debug_name=f"Var_{axis}_{bone_name}",
        )
        rotate_node = NodeFactory.create_rotate_bone(
            handle_id=rot_hid,
            bone_name=bone_name,
            axis=axis,
            angle_float_node=var_node,
            input_pose=self._current_terminal,
            min_angle=min_angle,
            max_angle=max_angle,
            in_model_space=in_model_space,
            debug_name=debug_label or f"Rotate_{axis}_{bone_name}",
        )

        self._current_terminal = rotate_node
        return self

    def connect_to_output(self, output_node: Optional[AnimNode] = None) -> None:
        """
        Attaches the final terminal head of this pipeline into the Output node.
        """
        out = output_node or self._graph.get_output_node()
        if not out:
            raise ValueError("Output node could not be located in AnimGraph.")

        out.data["node"] = NodeFactory.pose_link(self._current_terminal)
        self._registry.rebuild_index()
