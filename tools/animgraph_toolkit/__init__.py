"""
AnimGraph Toolkit for Cyberpunk 2077 (REDengine 4 / WolvenKit CR2W JSON)
A modular, SOLID-compliant framework for querying, validating, and manipulating animation graphs.
"""

from .core.models import AnimGraph, AnimNode
from .core.registry import NodeRegistry
from .core.validator import GraphValidator, ValidationReport
from .core.traversal import GraphWalker
from .core.rig import RigSkeleton, BoneTransformInfo
from .core.diff import GraphDiffer, DiffReport
from .factory.node_factory import NodeFactory
from .builder.pipeline_builder import PipelineBuilder
from .builder.splicer import SubtreeSplicer

__all__ = [
    "AnimGraph",
    "AnimNode",
    "NodeRegistry",
    "GraphValidator",
    "ValidationReport",
    "GraphWalker",
    "RigSkeleton",
    "BoneTransformInfo",
    "GraphDiffer",
    "DiffReport",
    "NodeFactory",
    "PipelineBuilder",
    "SubtreeSplicer",
]

