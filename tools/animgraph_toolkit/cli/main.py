"""
Command-Line Interface for the AnimGraph Toolkit.
Implements subcommands: validate, inspect, trace, diff, rig, export-subtree, and build.
"""

from __future__ import annotations
import argparse
import sys
from ..core.models import AnimGraph
from ..core.registry import NodeRegistry
from ..core.validator import GraphValidator
from ..core.traversal import GraphWalker
from ..core.diff import GraphDiffer
from ..core.rig import RigSkeleton
from ..recipes.ifp_height import IFPHeightRecipe
from ..recipes.foot_elevation import FootElevationRecipe
from ..recipes.catwalk_sway import CatwalkSwayRecipe


def cmd_validate(args: argparse.Namespace) -> int:
    """Validates an AnimGraph file."""
    print(f"[*] Validating: {args.file}")
    graph = AnimGraph.load(args.file)
    registry = NodeRegistry(graph)
    validator = GraphValidator(graph, registry)
    report = validator.validate(reachability_target=args.reach_target)

    print(report.summary())
    return 0 if report.is_valid else 1


def cmd_inspect(args: argparse.Namespace) -> int:
    """Inspects and searches nodes in an AnimGraph file."""
    graph = AnimGraph.load(args.file)
    registry = NodeRegistry(graph)
    walker = GraphWalker(registry) if args.path else None

    nodes = registry.find_nodes(
        node_type=args.type,
        debug_name=args.name,
        bone_name=args.bone,
        variable_name=args.var,
    )

    print(f"[*] Found {len(nodes)} matching node(s) in {args.file}:")
    for n in nodes[: args.limit]:
        hid = n.handle_id or 'Ref'
        print(f"  HandleId {hid}: [{n.node_type}]")
        if n.debug_name:
            print(f"    debugName: {n.debug_name}")
        if n.bone_name:
            print(f"    bone     : {n.bone_name}")
        if n.variable_name:
            print(f"    variable : {n.variable_name}")
        if walker and n.handle_id:
            ast_path = walker.find_ast_path(n.handle_id)
            if ast_path:
                path_str = " -> ".join(str(p) for p in ast_path)
                print(f"    AST Path : {path_str}")
            enclosing = walker.get_enclosing_node(n.handle_id)
            if enclosing:
                enc_hid = enclosing.handle_id or 'Ref'
                print(f"    Parent   : HandleId {enc_hid} [{enclosing.node_type}] '{enclosing.debug_name or ''}'")
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


def cmd_diff(args: argparse.Namespace) -> int:
    """Compares two AnimGraph files."""
    print(f"[*] Diffing:\n  Graph A: {args.graph_a}\n  Graph B: {args.graph_b}")
    graph_a = AnimGraph.load(args.graph_a)
    graph_b = AnimGraph.load(args.graph_b)
    differ = GraphDiffer()
    report = differ.diff(graph_a, graph_b)
    print(report.summary())
    return 1 if report.has_differences and args.exit_code else 0


def cmd_rig(args: argparse.Namespace) -> int:
    """Inspects a skeleton rig file and computes Model Space bone axes."""
    print(f"[*] Loading skeleton rig: {args.rig}")
    skeleton = RigSkeleton.load(args.rig)
    print(f"[*] Total bones in skeleton: {skeleton.total_bones}")

    if args.bone:
        info = skeleton.get_bone_info(args.bone)
        if not info:
            print(f"[-] Bone '{args.bone}' not found in skeleton.")
            return 1
        print(info.summary())
    elif args.search:
        matches = skeleton.find_bones(args.search)
        print(f"[*] Found {len(matches)} matching bone(s) for '{args.search}':")
        for m in matches:
            print(m.summary())
            print()
    else:
        print("[*] Available bones (first 30):")
        for idx, name in enumerate(skeleton.bone_names[:30]):
            parent_idx = skeleton.get_parent_index(idx)
            parent_str = f"(Parent: [{parent_idx}] {skeleton.bone_names[parent_idx]})" if parent_idx >= 0 else "(Root)"
            print(f"  [{idx:3d}] {name:20s} {parent_str}")
        if skeleton.total_bones > 30:
            print(f"  ... and {skeleton.total_bones - 30} more bones. Use --bone or --search to inspect.")
    return 0


def cmd_export_subtree(args: argparse.Namespace) -> int:
    """Exports a node and its entire subtree to a standalone JSON file."""
    print(f"[*] Loading graph: {args.file}")
    graph = AnimGraph.load(args.file)
    print(f"[*] Extracting subtree starting at Node {args.node} to {args.out}...")
    graph.export_subtree(args.node, args.out)
    print(f"[+] Successfully exported subtree to: {args.out}")
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
    p_val.add_argument("--reach-target", help="Optional target HandleId to verify Output reachability to (e.g. '2')")
    p_val.set_defaults(func=cmd_validate)

    # inspect
    p_insp = subparsers.add_parser("inspect", help="Search and inspect nodes")
    p_insp.add_argument("file", help="Path to animgraph JSON")
    p_insp.add_argument("--bone", help="Filter by targeted bone name")
    p_insp.add_argument("--type", help="Filter by node $type")
    p_insp.add_argument("--name", help="Filter by debugName")
    p_insp.add_argument("--var", help="Filter by variableName")
    p_insp.add_argument("--path", action="store_true", help="Display JSON AST path and parent container")
    p_insp.add_argument("--limit", type=int, default=20, help="Max nodes to display")
    p_insp.set_defaults(func=cmd_inspect)

    # trace
    p_trc = subparsers.add_parser("trace", help="Trace backward execution path")
    p_trc.add_argument("file", help="Path to animgraph JSON")
    p_trc.add_argument("--start", help="Starting HandleId (default: Output node)")
    p_trc.add_argument("--depth", type=int, default=50, help="Maximum trace depth")
    p_trc.set_defaults(func=cmd_trace)

    # diff
    p_diff = subparsers.add_parser("diff", help="Compare two animgraph JSON files")
    p_diff.add_argument("graph_a", help="Path to baseline AnimGraph JSON")
    p_diff.add_argument("graph_b", help="Path to modified AnimGraph JSON")
    p_diff.add_argument("--exit-code", action="store_true", help="Exit with non-zero code if differences are found")
    p_diff.set_defaults(func=cmd_diff)

    # rig
    p_rig = subparsers.add_parser("rig", help="Inspect a skeleton rig and calculate Model Space bone axes")
    p_rig.add_argument("rig", help="Path to skeleton *.rig.json file")
    p_rig.add_argument("--bone", help="Exact bone name to calculate Model Space orientation for (e.g. 'LeftArm')")
    p_rig.add_argument("--search", help="Substring pattern to search for bone names")
    p_rig.set_defaults(func=cmd_rig)

    # export-subtree
    p_exp = subparsers.add_parser("export-subtree", help="Export a node and its downstream subtree to JSON")
    p_exp.add_argument("file", help="Path to animgraph JSON")
    p_exp.add_argument("--node", required=True, help="Root HandleId of subtree to export")
    p_exp.add_argument("--out", required=True, help="Output destination JSON path")
    p_exp.set_defaults(func=cmd_export_subtree)

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
