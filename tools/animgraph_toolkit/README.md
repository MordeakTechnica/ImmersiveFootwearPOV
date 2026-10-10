# REDengine 4 AnimGraph Toolkit (`animgraph_toolkit`)

A modular, extensible Python toolkit designed for analyzing, manipulating, validating, and building Cyberpunk 2077 (Patch 2.0+) animation graphs (`*.animgraph.json`) and skeletal rigs (`*.rig.json`).

Engineered with **SOLID principles** and battle-tested design patterns to eliminate brittle ad-hoc scripts and ensure collision-free handle allocation, valid link references, forward kinematics solving, and zero regressions across mod combinations (Immersive Footwear POV, Immersive First Person, Catwalk Sway, etc.).

---

## 🏛️ Architecture & Design Patterns

The toolkit is organized into modular layers according to SOLID principles:

```
tools/animgraph_toolkit/
├── core/                   # Domain Models & Core Engine
│   ├── models.py           # AnimNode & AnimGraph abstractions (Encapsulation, Subtree Export)
│   ├── registry.py         # NodeRegistry (Registry Pattern & Safe Handle Allocation)
│   ├── traversal.py        # GraphWalker (Visitor/Walker Pattern, AST Path & Container Search)
│   ├── validator.py        # GraphValidator (Diagnostic Reporting, Reachability Checks)
│   ├── rig.py              # RigSkeleton & Forward Kinematics (Bone Coordinates & Model Space Axes)
│   └── diff.py             # GraphDiffer & DiffReport (Structural & Semantic Graph Comparison)
├── factory/
│   └── node_factory.py     # NodeFactory (Factory Pattern for REDengine CR2W Nodes)
├── builder/
│   ├── pipeline_builder.py # PipelineBuilder (Fluent Builder for output chaining)
│   └── splicer.py          # SubtreeSplicer (Safe Subtree Grafting & Renumbering)
├── recipes/                # Strategy Pattern: Modular Mod Modifications
│   ├── base.py             # GraphRecipe (Abstract Base Class)
│   ├── ifp_height.py       # IFPHeightRecipe (30-node Hips constraint graft)
│   ├── foot_elevation.py   # FootElevationRecipe (Puppet lift for heels)
│   └── catwalk_sway.py     # CatwalkSwayRecipe (Procedural pelvic/spine rotation)
├── cli/
│   └── main.py             # CLI Command Interface (argparse)
├── tests/
│   └── test_toolkit.py     # Unit test suite
└── README.md
```

### Key Design Patterns Applied

1. **Registry Pattern (`NodeRegistry`)**:
   - Single source of truth for all `HandleId`s, node lookup maps, and reference indexing.
   - Prevents handle ID collisions with stateful `allocate_handle()` and `_reserved_ids` blocks.
2. **Kinematics Engine (`RigSkeleton`)**:
   - Forward kinematics solver over WolvenKit `*.rig.json` character skeletons.
   - Converts quaternions to 3x3 matrices and multiplies down the bone hierarchy to derive exact Model Space bone lengths, lateral axes, and normal vectors.
3. **Graph Differ (`GraphDiffer`)**:
   - Detects added/removed handles, modified attributes, rewired inputs, and missing variables between two animgraphs.
4. **Factory Pattern (`NodeFactory`)**:
   - Encapsulates exact REDengine 4 CR2W structure creation (`animAnimNode_Blend2`, `animAnimNode_RotateBone`, `animAnimNode_TranslateBone`, `animAnimNode_FloatVariable`, etc.).
5. **Builder Pattern (`PipelineBuilder` / `SubtreeSplicer`)**:
   - Provides a fluent interface for constructing multi-stage node chains and splicing entire subtrees between arbitrary anchor and leaf nodes.
6. **Strategy Pattern (`GraphRecipe`)**:
   - Extensible recipe system. Each mod modification (IFP height, Foot elevation, Catwalk sway) is an isolated strategy conforming to `apply(graph, registry) -> bool`.
7. **Visitor / Walker Pattern (`GraphWalker`)**:
   - Recursively traverses node connections backward or forward to trace execution paths, or locates JSON AST hierarchy paths and parent container nodes.

---

## 🚀 CLI Usage

You can run the toolkit directly from the project root using `python -m tools.animgraph_toolkit.cli.main`.

### 1. Validate an AnimGraph
Performs static analysis to detect duplicate `HandleId`s, dangling `HandleRefId` references, and missing variables. Optionally verifies output reachability:
```bash
# Basic validation
python -m tools.animgraph_toolkit.cli.main validate path/to/player_base.animgraph.json

# Validation with reachability check to base locomotion pose (Node 2)
python -m tools.animgraph_toolkit.cli.main validate path/to/player_base.animgraph.json --reach-target 2
```

### 2. Inspect Nodes & AST Hierarchy
Query nodes by REDengine type, target bone, or variable name. Use `--path` to print the exact JSON AST hierarchy and enclosing parent node:
```bash
# Find all nodes affecting the Hips bone
python -m tools.animgraph_toolkit.cli.main inspect path/to/player_base.animgraph.json --bone Hips

# Find nodes with full JSON AST containment path and parent container
python -m tools.animgraph_toolkit.cli.main inspect path/to/player_base.animgraph.json --name IFP_Sway_Roll_Hips --path
```

### 3. Compare Graphs (`diff`)
Performs structural comparison between baseline and modified graphs:
```bash
python -m tools.animgraph_toolkit.cli.main diff \
  path/to/vanilla_player_base.animgraph.json \
  path/to/modded_player_base.animgraph.json
```

### 4. Rig Kinematics & Bone Axes (`rig`)
Inspect a `.rig.json` skeleton and calculate Model Space position and orientation vectors ($X$ bone length, $Y$ lateral, $Z$ normal) for procedural bone rotation/translation:
```bash
# Calculate Model Space axes for LeftArm
python -m tools.animgraph_toolkit.cli.main rig \
  path/to/player_woman_skeleton.rig.json \
  --bone LeftArm

# Search all bones matching a pattern
python -m tools.animgraph_toolkit.cli.main rig \
  path/to/player_woman_skeleton.rig.json \
  --search Spine
```

### 5. Export Subtree (`export-subtree`)
Extracts a node and its entire downstream dependency subgraph to an isolated donor JSON file:
```bash
python -m tools.animgraph_toolkit.cli.main export-subtree \
  path/to/player_base.animgraph.json \
  --node 3734 \
  --out path/to/donor_blend2_subtree.json
```

### 6. Trace Execution Paths (`trace`)
Trace the backward execution graph starting from any node (such as terminal `Output Node 1`):
```bash
python -m tools.animgraph_toolkit.cli.main trace path/to/player_base.animgraph.json --start 1 --depth 10
```

### 7. Build a Merged Graph from Recipes (`build`)
Generate a combined animgraph by applying modular recipes onto a base graph:
```bash
python -m tools.animgraph_toolkit.cli.main build \
  --base path/to/base_itp.animgraph.json \
  --ifp path/to/donor_ifp.animgraph.json \
  --elevation \
  --elevation-max 1.0 \
  --sway \
  --out path/to/output_player_base.animgraph.json
```

---

## 🐍 Python API Usage

You can also use the toolkit programmatically in Python scripts:

```python
from tools.animgraph_toolkit import (
    AnimGraph,
    NodeRegistry,
    GraphValidator,
    GraphWalker,
    GraphDiffer,
    RigSkeleton,
    NodeFactory,
    PipelineBuilder,
    IFPHeightRecipe,
    FootElevationRecipe,
    CatwalkSwayRecipe,
)

# 1. Rig Kinematics
skeleton = RigSkeleton.load("path/to/player_woman_skeleton.rig.json")
bone_info = skeleton.get_bone_info("LeftArm")
print(f"LeftArm Model Space Position: {bone_info.position}")
print(f"LeftArm Bone Length Axis    : {bone_info.local_x_axis}")

# 2. Graph Loading & Validation
graph = AnimGraph.load("source/raw/base/gameplay/anim_graphs/player_base.animgraph.json")
registry = NodeRegistry(graph)

validator = GraphValidator(graph, registry)
report = validator.validate(reachability_target="2")
print(f"Graph valid: {report.is_valid}")

# 3. Subtree Export
graph.export_subtree(root_handle_id="6050", output_path="donor_sway.json")

# 4. Graph Differ
donor = AnimGraph.load("donor_graph.json")
differ = GraphDiffer()
diff_report = differ.diff(graph, donor)
print(diff_report.summary())
```

---

## 🧪 Running Unit Tests

Run the test suite using Python's built-in `unittest` runner:
```bash
python -m unittest tools/animgraph_toolkit/tests/test_toolkit.py
```
All tests verify node creation, graph walking, validation error detection, rig kinematics, AST path discovery, graph diffing, and recipe end-to-end execution.
