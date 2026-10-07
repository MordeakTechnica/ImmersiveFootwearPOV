"""
Node Factory for REDengine Animation Graphs.
Implements the Factory Pattern to construct strictly compliant REDengine anim nodes
with accurate CNames, transform indices, links, and defaults.
"""

from __future__ import annotations
from typing import Dict, Any, Optional, Union


class NodeFactory:
    """
    Constructs REDengine / WolvenKit CR2W JSON node dictionaries.
    """

    @staticmethod
    def cname(value: str) -> Dict[str, Any]:
        """Creates a REDengine CName descriptor."""
        return {
            "$type": "CName",
            "$storage": "string",
            "$value": value,
        }

    @staticmethod
    def pose_link(node: Union[Dict[str, Any], str]) -> Dict[str, Any]:
        """Creates an animPoseLink targeting either an embedded node or HandleRefId."""
        target = {"HandleRefId": str(node)} if isinstance(node, (str, int)) else node
        return {
            "$type": "animPoseLink",
            "node": target,
        }

    @staticmethod
    def float_link(node: Union[Dict[str, Any], str, None]) -> Dict[str, Any]:
        """Creates an animFloatLink targeting an embedded node, HandleRefId, or None."""
        if node is None:
            target = None
        elif isinstance(node, (str, int)):
            target = {"HandleRefId": str(node)}
        else:
            target = node
        return {
            "$type": "animFloatLink",
            "node": target,
        }

    @staticmethod
    def vector_link(node: Union[Dict[str, Any], str]) -> Dict[str, Any]:
        """Creates an animVectorLink targeting an embedded node or HandleRefId."""
        target = {"HandleRefId": str(node)} if isinstance(node, (str, int)) else node
        return {
            "$type": "animVectorLink",
            "node": target,
        }

    @classmethod
    def create_float_variable_node(
        cls,
        handle_id: Union[str, int],
        variable_name: str,
        debug_name: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Creates an animAnimNode_FloatVariable."""
        return {
            "HandleId": str(handle_id),
            "Data": {
                "$type": "animAnimNode_FloatVariable",
                "debugName": cls.cname(debug_name or f"Var_{variable_name}"),
                "id": 4294967295,
                "poseInfoLogger": None,
                "variableName": cls.cname(variable_name),
                "visAxes": 0,
                "visMask": None,
                "visNames": 0,
                "visPostPose": 0,
                "visPostPoseColor": {"$type": "Color", "Alpha": 0, "Blue": 0, "Green": 0, "Red": 0},
                "visPrePose": 0,
                "visPrePoseColor": {"$type": "Color", "Alpha": 0, "Blue": 0, "Green": 0, "Red": 0},
                "visRigPartMask": cls.cname("None"),
                "visWhenActive": 0,
            },
        }

    @classmethod
    def create_vector_constant(
        cls,
        handle_id: Union[str, int],
        x: float,
        y: float,
        z: float,
        w: float = 0.0,
        debug_name: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Creates an animAnimNode_VectorConstant."""
        return {
            "HandleId": str(handle_id),
            "Data": {
                "$type": "animAnimNode_VectorConstant",
                "debugName": cls.cname(debug_name or "VectorConstant"),
                "id": 4294967295,
                "poseInfoLogger": None,
                "value": {
                    "$type": "Vector4",
                    "W": float(w),
                    "X": float(x),
                    "Y": float(y),
                    "Z": float(z),
                },
                "visAxes": 0,
                "visMask": None,
                "visNames": 0,
                "visPostPose": 0,
                "visPostPoseColor": {"$type": "Color", "Alpha": 0, "Blue": 0, "Green": 0, "Red": 0},
                "visPrePose": 0,
                "visPrePoseColor": {"$type": "Color", "Alpha": 0, "Blue": 0, "Green": 0, "Red": 0},
                "visRigPartMask": cls.cname("None"),
                "visWhenActive": 0,
            },
        }

    @classmethod
    def create_translate_bone(
        cls,
        handle_id: Union[str, int],
        bone_name: str,
        input_pose: Union[Dict[str, Any], str],
        input_translation: Union[Dict[str, Any], str],
        scale_xyz: float = 1.0,
        debug_name: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Creates an animAnimNode_TranslateBone."""
        return {
            "HandleId": str(handle_id),
            "Data": {
                "$type": "animAnimNode_TranslateBone",
                "biasValue": {"$type": "Vector4", "W": 0.0, "X": 0.0, "Y": 0.0, "Z": 0.0},
                "bone": {
                    "$type": "animTransformIndex",
                    "name": cls.cname(bone_name),
                },
                "debugName": cls.cname(debug_name or f"Translate_{bone_name}"),
                "id": 4294967295,
                "inputNode": cls.pose_link(input_pose),
                "inputTranslation": cls.vector_link(input_translation),
                "poseInfoLogger": None,
                "resetOnActivation": 1,
                "scale": {"$type": "Vector4", "W": 1.0, "X": scale_xyz, "Y": scale_xyz, "Z": scale_xyz},
                "useIncrementalMode": 0,
                "visAxes": 0,
                "visMask": None,
                "visNames": 0,
                "visPostPose": 0,
                "visPostPoseColor": {"$type": "Color", "Alpha": 0, "Blue": 0, "Green": 0, "Red": 0},
                "visPrePose": 0,
                "visPrePoseColor": {"$type": "Color", "Alpha": 0, "Blue": 0, "Green": 0, "Red": 0},
                "visRigPartMask": cls.cname("None"),
                "visWhenActive": 0,
            },
        }

    @classmethod
    def create_rotate_bone(
        cls,
        handle_id: Union[str, int],
        bone_name: str,
        axis: str,
        angle_float_node: Union[Dict[str, Any], str],
        input_pose: Union[Dict[str, Any], str],
        min_angle: float = -45.0,
        max_angle: float = 45.0,
        in_model_space: int = 1,
        debug_name: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Creates an animAnimNode_RotateBone."""
        return {
            "HandleId": str(handle_id),
            "Data": {
                "$type": "animAnimNode_RotateBone",
                "angleNode": cls.float_link(angle_float_node),
                "axis": axis,
                "biasAngle": 0.0,
                "bone": {
                    "$type": "animTransformIndex",
                    "name": cls.cname(bone_name),
                },
                "clampRotation": 1,
                "debugName": cls.cname(debug_name or f"Rotate_{axis}_{bone_name}"),
                "id": 4294967295,
                "inModelSpace": in_model_space,
                "inputNode": cls.pose_link(input_pose),
                "maxAngle": float(max_angle),
                "maxValueNode": cls.float_link(None),
                "minAngle": float(min_angle),
                "minValueNode": cls.float_link(None),
                "poseInfoLogger": None,
                "resetOnActivation": 1,
                "scale": 1.0,
                "useIncrementalMode": 0,
                "visAxes": 0,
                "visMask": None,
                "visNames": 0,
                "visPostPose": 0,
                "visPostPoseColor": {"$type": "Color", "Alpha": 0, "Blue": 0, "Green": 0, "Red": 0},
                "visPrePose": 0,
                "visPrePoseColor": {"$type": "Color", "Alpha": 0, "Blue": 0, "Green": 0, "Red": 0},
                "visRigPartMask": cls.cname("None"),
                "visWhenActive": 0,
            },
        }

    @classmethod
    def create_blend2(
        cls,
        handle_id: Union[str, int],
        first_input: Union[Dict[str, Any], str],
        second_input: Union[Dict[str, Any], str],
        weight_node: Union[Dict[str, Any], str],
        debug_name: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Creates an animAnimNode_Blend2."""
        return {
            "HandleId": str(handle_id),
            "Data": {
                "$type": "animAnimNode_Blend2",
                "debugName": cls.cname(debug_name or "Blend2"),
                "firstInputNode": cls.pose_link(first_input),
                "id": 4294967295,
                "poseInfoLogger": None,
                "secondInputNode": cls.pose_link(second_input),
                "syncMethod": None,
                "timeWarpingEnabled": 0,
                "visAxes": 0,
                "visMask": None,
                "visNames": 0,
                "visPostPose": 0,
                "visPostPoseColor": {"$type": "Color", "Alpha": 0, "Blue": 0, "Green": 0, "Red": 0},
                "visPrePose": 0,
                "visPrePoseColor": {"$type": "Color", "Alpha": 0, "Blue": 0, "Green": 0, "Red": 0},
                "visRigPartMask": cls.cname("None"),
                "visWhenActive": 0,
                "weightNode": cls.float_link(weight_node),
            },
        }
