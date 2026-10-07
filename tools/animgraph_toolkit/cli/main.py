"""
Command-Line Interface for the AnimGraph Toolkit.
Implements subcommands: validate, inspect, trace, diff, and build.
"""

from __future__ import annotations
import argparse
import sys
from ..core.models import AnimGraph
from ..core.registry import NodeRegistry
from ..core.validator import GraphValidator
from ..core.traversal import GraphWalker
from ..recipes.ifp_height import IFPHeightRecipe
from ..recipes.foot_elevation import FootElevationRecipe
from ..recipes.catwalk_sway import CatwalkSwayRecipe


def cmd_validate(args: argparse.Namespace) -> int:
    """Validates an AnimGraph file."""
    print(f"[*] Validating: {args.file}")
    graph = AnimGraph.load(args.file)
    registry = NodeRegistry(graph)
    validator = GraphValidator(graph, registry)
    report = validator.validate()

    print(report.summary())
    return 0 if report.is_valid else 1


def cmd_inspect(args: argparse.Namespace) -> int:
    """Inspects and searches nodes in an AnimGraph file."""
    graph = AnimGraph.load(args.file)
    registry = NodeRegistry(graph)

    nodes = registry.find_nodes(
        node_type=args.type,
        debug_name=args.name,
        bone_name=args.bone,
        variable_name=args.var,
    )

    print(f"[*] Found {len(nodes)} matching node(s) in {args.file}:")
    for n in nodes[: args.limit]:
        print(f"  HandleId {n.handle_id or 'Ref'}: [{n.node_type}]")
        if n.debug_name:
            print(f"    debugName: {n.debug_name}")
        if n.bone_name:
            print(f"    bone     : {n.bone_name}")
        if n.variable_name:
            print(f"    variable : {n.variable_name}")
    if len(nodes) > args.limit:
        print(f"  ... and {len(nodes) - args.limit} more.")
    return 0


def cmd_trace(args: argparse.Namespace) -> int:
    """Traces the backward evaluation path from Output or a specific node."""
    graph = AnimGraph.load(args.file)
    registry = NodeRegistry(graph)
    walker = GraphWalker(registry)

    if args.start:
        start_node = registry.get_node(args.start)
        if not start_node:
            print(f"[-] Node {args.start} not found in graph.")
            return 1
    else:
        start_node = graph.get_output_node()
        if not start_node:
            print("[-] Terminal Output node not found in graph.")
            return 1

    path = walker.trace_backward(start_node, max_depth=args.depth)
    print(f"[*] Traced backward path ({len(path)} steps):")
    for i, node in enumerate(path):
        indent = "  " * min(i, 8)
        hid = node.handle_id or f"Ref({node.handle_ref_id})"
        name = node.debug_name or node.variable_name or node.bone_name or ""
        bone_str = f" [Bone: {node.bone_name}]" if node.bone_name else ""
        print(f"{indent}Step {i:02d}: Node {hid:5s} ({node.node_type}){bone_str} '{name}'")
    return 0


def cmd_build(args: argparse.Namespace) -> int:
    """Builds a unified AnimGraph from base ITP and donor IFP graphs."""
    print(f"[*] Loading base graph: {args.base}")
    graph = AnimGraph.load(args.base)
    registry = NodeRegistry(graph)

    # 1. Apply IFP Height
    if args.ifp:
        print(f"[*] Applying IFP Height Recipe from: {args.ifp}")
        recipe_ifp = IFPHeightRecipe(args.ifp)
        recipe_ifp.apply(graph, registry)

    # 2. Apply Foot Elevation
    if args.elevation:
        print("[*] Applying Footwear Elevation Recipe")
        recipe_elev = FootElevationRecipe(max_elevation_meters=args.elevation_max)
        recipe_elev.apply(graph, registry)

    # 3. Apply Catwalk Sway
    if args.sway:
        print("[*] Applying Catwalk Sway & Counter-Rotation Recipe")
        recipe_sway = CatwalkSwayRecipe()
        recipe_sway.apply(graph, registry)

    # Validate
    validator = GraphValidator(graph, registry)
    report = validator.validate()
    print(report.summary())

    if not report.is_valid:
        print("[-] Build aborted due to validation errors.")
        return 1

    print(f"[+] Writing output to: {args.out}")
    graph.save(args.out)
    print("[+] Unified build completed successfully!")
    return 0


def main() -> None:
    parser = argparse.ArgumentParser(description="AnimGraph Toolkit for Cyberpunk 2077")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # validate
    p_val = subparsers.add_parser("validate", help="Validate an animgraph JSON file")
    p_val.add_argument("file", help="Path to animgraph JSON")
    p_val.set_defaults(func=cmd_validate)

    # inspect
    p_insp = subparsers.add_parser("inspect", help="Search and inspect nodes")
    p_insp.add_argument("file", help="Path to animgraph JSON")
    p_insp.add_argument("--bone", help="Filter by targeted bone name")
    p_insp.add_argument("--type", help="Filter by node $type")
    p_insp.add_argument("--name", help="Filter by debugName")
    p_insp.add_argument("--var", help="Filter by variableName")
    p_insp.add_argument("--limit", type=int, default=20, help="Max nodes to display")
    p_insp.set_defaults(func=cmd_inspect)

    # trace
    p_trc = subparsers.add_parser("trace", help="Trace backward execution path")
    p_trc.add_argument("file", help="Path to animgraph JSON")
    p_trc.add_argument("--start", help="Starting HandleId (default: Output node)")
    p_trc.add_argument("--depth", type=int, default=50, help="Maximum trace depth")
    p_trc.set_defaults(func=cmd_trace)

    # build
    p_bld = subparsers.add_parser("build", help="Build unified animgraph using recipes")
    p_bld.add_argument("--base", required=True, help="Base ITP animgraph JSON")
    p_bld.add_argument("--ifp", help="Donor IFP animgraph JSON")
    p_bld.add_argument("--elevation", action="store_true", default=True, help="Include foot elevation offset")
    p_bld.add_argument("--elevation-max", type=float, default=1.0, help="Max elevation height in meters")
    p_bld.add_argument("--sway", action="store_true", default=True, help="Include catwalk sway nodes")
    p_bld.add_argument("--out", required=True, help="Output animgraph JSON path")
    p_bld.set_defaults(func=cmd_build)

    args = parser.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
