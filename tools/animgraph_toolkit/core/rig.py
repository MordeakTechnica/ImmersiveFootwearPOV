"""
Rig Kinematics and Skeleton Domain Model for REDengine.
Parses WolvenKit *.rig.json files, performs forward kinematics,
and computes Model Space bone positions and directional coordinate axes.
"""

from __future__ import annotations
import json
import math
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple, Union, Any


@dataclass
class BoneTransformInfo:
    """Encapsulates the calculated spatial and rotational state of a bone in Model Space."""
    name: str
    index: int
    parent_index: int
    parent_name: Optional[str]
    position: List[float]  # [X, Y, Z] in Model Space
    local_x_axis: List[float]  # Unit vector for bone length axis in Model Space
    local_y_axis: List[float]  # Unit vector for bone lateral axis in Model Space
    local_z_axis: List[float]  # Unit vector for bone normal axis in Model Space
    rotation_matrix: List[List[float]] = field(repr=False)

    def summary(self) -> str:
        """Formats a human-readable summary of the bone's spatial orientation."""
        lines = [
            f"=== Bone [{self.index:3d}] {self.name} (Parent: [{self.parent_index:3d}] {self.parent_name or 'Root'}) ===",
            f"  Position (Model Space): X={self.position[0]:+.4f}, Y={self.position[1]:+.4f}, Z={self.position[2]:+.4f}",
            f"  Local X Axis (Bone Length): [{self.local_x_axis[0]:+.4f}, {self.local_x_axis[1]:+.4f}, {self.local_x_axis[2]:+.4f}]",
            f"  Local Y Axis (Lateral)    : [{self.local_y_axis[0]:+.4f}, {self.local_y_axis[1]:+.4f}, {self.local_y_axis[2]:+.4f}]",
            f"  Local Z Axis (Normal)     : [{self.local_z_axis[0]:+.4f}, {self.local_z_axis[1]:+.4f}, {self.local_z_axis[2]:+.4f}]",
        ]
        return "\n".join(lines)


class RigSkeleton:
    """
    Domain model representing a REDengine 4 skeletal rig (*.rig.json).
    Solves forward kinematics across the parent-child bone hierarchy.
    """

    def __init__(self, raw_data: Dict[str, Any]):
        self._raw = raw_data
        self._root_chunk = self._raw.get("Data", {}).get("RootChunk", {})
        
        # Parse bone names
        raw_names = self._root_chunk.get("boneNames", [])
        self._bone_names: List[str] = [
            b.get("$value", str(b)) if isinstance(b, dict) else str(b)
            for b in raw_names
        ]
        
        self._parent_indices: List[int] = [
            int(idx) for idx in self._root_chunk.get("boneParentIndexes", [])
        ]
        self._bone_transforms: List[Dict[str, Any]] = self._root_chunk.get("boneTransforms", [])
        self._a_pose_ls: List[Dict[str, Any]] = self._root_chunk.get("aPoseLS", [])
        self._a_pose_ms: List[Dict[str, Any]] = self._root_chunk.get("aPoseMS", [])
        
        self._fk_cache: Optional[Dict[int, BoneTransformInfo]] = None

    @classmethod
    def load(cls, file_path: str) -> RigSkeleton:
        """Loads a skeleton rig from a WolvenKit exported *.rig.json file."""
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return cls(data)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> RigSkeleton:
        """Instantiates a RigSkeleton from a raw dictionary."""
        return cls(data)

    @property
    def raw(self) -> Dict[str, Any]:
        """Returns the underlying raw JSON dictionary."""
        return self._raw

    @property
    def total_bones(self) -> int:
        """Returns the total number of bones defined in the skeleton."""
        return len(self._bone_names)

    @property
    def bone_names(self) -> List[str]:
        """Returns the list of all bone names in skeletal order."""
        return list(self._bone_names)

    def get_bone_index(self, name: str) -> Optional[int]:
        """Looks up the numerical bone index by exact name."""
        try:
            return self._bone_names.index(name)
        except ValueError:
            return None

    def get_parent_index(self, bone_idx: int) -> int:
        """Returns the parent bone index for a given bone index (-1 if root)."""
        if 0 <= bone_idx < len(self._parent_indices):
            return self._parent_indices[bone_idx]
        return -1

    @staticmethod
    def _quat_to_mat(q: Dict[str, Any]) -> List[List[float]]:
        """Converts a REDengine quaternion {i, j, k, r} to a 3x3 rotation matrix."""
        x = float(q.get("i", 0.0))
        y = float(q.get("j", 0.0))
        z = float(q.get("k", 0.0))
        w = float(q.get("r", 1.0))

        xx = x * x
        yy = y * y
        zz = z * z
        xy = x * y
        xz = x * z
        yz = y * z
        wx = w * x
        wy = w * y
        wz = w * z

        return [
            [1.0 - 2.0 * (yy + zz), 2.0 * (xy - wz),       2.0 * (xz + wy)],
            [2.0 * (xy + wz),       1.0 - 2.0 * (xx + zz), 2.0 * (yz - wx)],
            [2.0 * (xz - wy),       2.0 * (yz + wx),       1.0 - 2.0 * (xx + yy)],
        ]

    @staticmethod
    def _mat_mul(a: List[List[float]], b: List[List[float]]) -> List[List[float]]:
        """Multiplies two 3x3 matrices."""
        c = [[0.0] * 3 for _ in range(3)]
        for i in range(3):
            for j in range(3):
                c[i][j] = sum(a[i][k] * b[k][j] for k in range(3))
        return c

    @staticmethod
    def _mat_vec(m: List[List[float]], v: List[float]) -> List[float]:
        """Multiplies a 3x3 matrix by a 3D vector."""
        return [sum(m[i][j] * v[j] for j in range(3)) for i in range(3)]

    def solve_forward_kinematics(self) -> Dict[int, BoneTransformInfo]:
        """
        Solves forward kinematics across all bones in the skeleton.
        Computes world/model-space transforms and returns a map of bone index to BoneTransformInfo.
        """
        if self._fk_cache is not None:
            return self._fk_cache

        results: Dict[int, BoneTransformInfo] = {}
        model_matrices: Dict[int, Tuple[List[List[float]], List[float]]] = {}

        for idx, name in enumerate(self._bone_names):
            parent_idx = self.get_parent_index(idx)
            parent_name = self._bone_names[parent_idx] if parent_idx >= 0 and parent_idx < len(self._bone_names) else None

            # Get local transform
            bt = self._bone_transforms[idx] if idx < len(self._bone_transforms) else {}
            pos = bt.get("Translation", {})
            rot = bt.get("Rotation", {})

            r_local = self._quat_to_mat(rot)
            t_local = [float(pos.get("X", 0.0)), float(pos.get("Y", 0.0)), float(pos.get("Z", 0.0))]

            if parent_idx < 0 or parent_idx not in model_matrices:
                r_world = r_local
                t_world = t_local
            else:
                r_parent, t_parent = model_matrices[parent_idx]
                r_world = self._mat_mul(r_parent, r_local)
                t_offset = self._mat_vec(r_parent, t_local)
                t_world = [t_parent[i] + t_offset[i] for i in range(3)]

            model_matrices[idx] = (r_world, t_world)

            # Local axes in Model Space correspond to matrix columns
            local_x = [r_world[0][0], r_world[1][0], r_world[2][0]]
            local_y = [r_world[0][1], r_world[1][1], r_world[2][1]]
            local_z = [r_world[0][2], r_world[1][2], r_world[2][2]]

            results[idx] = BoneTransformInfo(
                name=name,
                index=idx,
                parent_index=parent_idx,
                parent_name=parent_name,
                position=t_world,
                local_x_axis=local_x,
                local_y_axis=local_y,
                local_z_axis=local_z,
                rotation_matrix=r_world,
            )

        self._fk_cache = results
        return results

    def get_bone_info(self, bone: Union[str, int]) -> Optional[BoneTransformInfo]:
        """
        Retrieves the Model Space spatial transform and axes for a given bone (by name or index).
        """
        fk_map = self.solve_forward_kinematics()
        if isinstance(bone, str):
            idx = self.get_bone_index(bone)
            if idx is None:
                return None
            return fk_map.get(idx)
        elif isinstance(bone, int):
            return fk_map.get(bone)
        return None

    def find_bones(self, pattern: str) -> List[BoneTransformInfo]:
        """
        Finds all bones whose names contain the given pattern (case-insensitive).
        """
        fk_map = self.solve_forward_kinematics()
        pattern_lower = pattern.lower()
        return [
            info for info in fk_map.values()
            if pattern_lower in info.name.lower()
        ]
