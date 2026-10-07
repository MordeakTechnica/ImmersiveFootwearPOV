"""
Core Domain Models for REDengine Animation Graphs.
Implements encapsulation and domain-specific accessors over raw JSON structures.
"""

from __future__ import annotations
import json
from typing import Dict, Any, Optional, List, Union


class AnimNode:
    """
    Domain wrapper around a REDengine AnimGraph node dictionary.
    Provides typed accessors for bone targets, node types, debug names, and inputs.
    """

    def __init__(self, raw: Dict[str, Any]):
        self._raw = raw

    @property
    def raw(self) -> Dict[str, Any]:
        """Returns the underlying raw dictionary."""
        return self._raw

    @property
    def handle_id(self) -> Optional[str]:
        """Gets HandleId if defined directly on this node."""
        hid = self._raw.get("HandleId")
        return str(hid) if hid is not None else None

    @property
    def handle_ref_id(self) -> Optional[str]:
        """Gets HandleRefId if this node represents a reference pointer."""
        ref = self._raw.get("HandleRefId")
        return str(ref) if ref is not None else None

    @property
    def is_reference(self) -> bool:
        """True if this object is a reference pointer (HandleRefId)."""
        return "HandleRefId" in self._raw

    @property
    def data(self) -> Dict[str, Any]:
        """Gets the inner 'Data' dictionary, or self if flat."""
        return self._raw.get("Data", self._raw)

    @property
    def node_type(self) -> Optional[str]:
        """Gets the $type of the node (e.g. animAnimNode_Blend2)."""
        return self.data.get("$type")

    @property
    def debug_name(self) -> Optional[str]:
        """Gets the string value of debugName."""
        val = self.data.get("debugName")
        if isinstance(val, dict):
            return val.get("$value")
        return val

    @property
    def bone_name(self) -> Optional[str]:
        """Extracts targeted bone name if this node operates on a skeletal transform."""
        bone_obj = self.data.get("bone") or self.data.get("transformIndex")
        if isinstance(bone_obj, dict):
            name_obj = bone_obj.get("name")
            if isinstance(name_obj, dict):
                return name_obj.get("$value")
            return name_obj
        return None

    @property
    def variable_name(self) -> Optional[str]:
        """Extracts the variable name if this node reads an animation variable."""
        var_obj = self.data.get("variableName") or self.data.get("name")
        if isinstance(var_obj, dict):
            return var_obj.get("$value")
        return var_obj

    def get_input_target_id(self, input_prop: str = "inputNode") -> Optional[str]:
        """
        Gets the target HandleId or HandleRefId connected to a given input link.
        Common input props: 'inputNode', 'inputLink', 'firstInputNode', 'secondInputNode'.
        """
        link = self.data.get(input_prop)
        if not isinstance(link, dict):
            return None
        target = link.get("node")
        if not isinstance(target, dict):
            return None
        return str(target.get("HandleRefId") or target.get("HandleId") or "")

    def __repr__(self) -> str:
        hid = self.handle_id or f"Ref({self.handle_ref_id})"
        name = self.debug_name or self.variable_name or self.bone_name or "None"
        return f"<AnimNode {hid} [{self.node_type}] debugName='{name}'>"


class AnimGraph:
    """
    Root domain model representing a complete REDengine animation graph file.
    Provides graph loading, saving, querying, and variable access.
    """

    def __init__(self, raw_data: Dict[str, Any]):
        self._raw = raw_data
        self._root_chunk = self._raw.get("Data", {}).get("RootChunk", {})

    @classmethod
    def load(cls, file_path: str) -> AnimGraph:
        """Loads an animation graph from a WolvenKit CR2W JSON file."""
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return cls(data)

    def save(self, file_path: str, indent: int = 2) -> None:
        """Serializes and saves the animation graph to disk."""
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(self._raw, f, indent=indent)

    @property
    def raw(self) -> Dict[str, Any]:
        """Gets underlying raw graph dictionary."""
        return self._raw

    @property
    def root_chunk(self) -> Dict[str, Any]:
        """Gets the RootChunk dictionary."""
        return self._root_chunk

    @property
    def nodes_to_init(self) -> List[Dict[str, Any]]:
        """Gets the nodesToInit list from RootChunk."""
        return self._root_chunk.setdefault("nodesToInit", [])

    @property
    def float_variables(self) -> List[Dict[str, Any]]:
        """Gets the list of declared float variables."""
        vars_root = self._root_chunk.setdefault("variables", {})
        if "Data" in vars_root and isinstance(vars_root["Data"], dict):
            return vars_root["Data"].setdefault("floatVariables", [])
        return vars_root.setdefault("floatVariables", [])

    def get_output_node(self) -> Optional[AnimNode]:
        """Finds the terminal animAnimNode_Output node inside nodesToInit[0]."""
        if not self.nodes_to_init:
            return None
        node_0 = self.nodes_to_init[0]
        nodes = node_0.get("Data", {}).get("nodes", [])
        if nodes:
            out_raw = nodes[0]
            if out_raw.get("Data", {}).get("$type") == "animAnimNode_Output":
                return AnimNode(out_raw)
        return None

    def find_variable(self, name: str) -> Optional[Dict[str, Any]]:
        """Finds a registered float variable by name."""
        for v in self.float_variables:
            data = v.get("Data", v)
            val = data.get("name", {})
            vname = val.get("$value") if isinstance(val, dict) else val
            if vname == name:
                return v
        return None

    def ensure_float_variable(
        self,
        name: str,
        handle_id: str,
        default_val: float = 0.0,
        min_val: float = 0.0,
        max_val: float = 1.0,
    ) -> Dict[str, Any]:
        """
        Ensures a float variable is declared in the root variable table.
        Creates it if missing; returns the existing or created variable dictionary.
        """
        existing = self.find_variable(name)
        if existing is not None:
            return existing

        new_var = {
            "HandleId": str(handle_id),
            "Data": {
                "$type": "animAnimVariableFloat",
                "default": float(default_val),
                "enableDebug": 0,
                "max": float(max_val),
                "min": float(min_val),
                "name": {
                    "$type": "CName",
                    "$storage": "string",
                    "$value": name,
                },
                "value": float(default_val),
            },
        }
        self.float_variables.append(new_var)
        return new_var
