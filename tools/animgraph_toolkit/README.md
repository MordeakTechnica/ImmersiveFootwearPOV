# REDengine 4 AnimGraph Toolkit (`animgraph_toolkit`)

A modular, extensible Python toolkit designed for analyzing, manipulating, validating, and building Cyberpunk 2077 (Patch 2.0+) animation graphs (`*.animgraph.json`).

Engineered with **SOLID principles** and battle-tested design patterns to eliminate brittle ad-hoc scripts and ensure collision-free handle allocation, valid link references, and zero regressions across mod combinations (Immersive Footwear POV, Immersive First Person, Catwalk Sway, etc.).

---

## 🏛️ Architecture & Design Patterns

The toolkit is organized into modular layers according to SOLID principles:

```
tools/animgraph_toolkit/
├── core/                   # Domain Models & Core Engine
│   ├── models.py           # AnimNode & AnimGraph abstractions (Encapsulation)
│   ├── registry.py         # NodeRegistry (Registry Pattern & Safe Handle Allocation)
│   ├── traversal.py        # GraphWalker (Visitor/Walker Pattern & Dependency Tracing)
│   └── validator.py        # GraphValidator (Diagnostic Reporting & Integrity Checks)
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
2. **Factory Pattern (`NodeFactory`)**:
   - Encapsulates exact REDengine 4 CR2W structure creation (`animAnimNode_Blend2`, `animAnimNode_RotateBone`, `animAnimNode_TranslateBone`, `animAnimNode_FloatVariable`, etc.).
   - Standardizes node initialization, default values, and link generation.
3. **Builder Pattern (`PipelineBuilder` / `SubtreeSplicer`)**:
   - Provides a fluent interface for constructing multi-stage node chains and splicing entire subtrees between arbitrary anchor and leaf nodes.
4. **Strategy Pattern (`GraphRecipe`)**:
   - Extensible recipe system. Each mod modification (IFP height, Foot elevation, Catwalk sway) is an isolated strategy conforming to `apply(graph, registry) -> bool`.
5. **Visitor / Walker Pattern (`GraphWalker`)**:
   - Recursively traverses node connections backward or forward to trace execution paths and collect entire subtrees without modifying the underlying graph.

---

## 🚀 CLI Usage

You can run the toolkit directly from the project root using `python -m tools.animgraph_toolkit.cli.main`.

### 1. Validate an AnimGraph
Performs static analysis to detect duplicate `HandleId`s, dangling `HandleRefId` references, and missing variables.
```bash
python -m tools.animgraph_toolkit.cli.main validate path/to/player_base.animgraph.json
```

### 2. Inspect Nodes
Query nodes by REDengine type, target bone, or variable name:
```bash
# Find all nodes affecting the Hips bone
python -m tools.animgraph_toolkit.cli.main inspect path/to/player_base.animgraph.json --bone Hips

# Find nodes of a specific type
python -m tools.animgraph_toolkit.cli.main inspect path/to/player_base.animgraph.json --type animAnimNode_RotateBone

# Find nodes referencing a variable
python -m tools.animgraph_toolkit.cli.main inspect path/to/player_base.animgraph.json --variable CatwalkRoll
```

### 3. Trace Execution Paths
Trace the backward execution graph starting from any node (such as terminal `Output Node 1`):
```bash
python -m tools.animgraph_toolkit.cli.main trace path/to/player_base.animgraph.json --start 1 --depth 10
```

### 4. Build a Merged Graph from Recipes
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
    NodeFactory,
    PipelineBuilder,
    IFPHeightRecipe,
    FootElevationRecipe,
    CatwalkSwayRecipe,
)

# 1. Load Graph
graph = AnimGraph.load("source/raw/base/gameplay/anim_graphs/player_base.animgraph.json")
registry = NodeRegistry(graph)

# 2. Validate
validator = GraphValidator()
report = validator.validate(graph, registry)
print(f"Graph valid: {report.is_valid}")

# 3. Create Custom Nodes
factory = NodeFactory()
var_node = factory.create_float_variable(
    handle_id=registry.allocate_handle(),
    var_name="CustomOffset",
    default_val=0.0
)
graph.add_node(var_node)

# 4. Apply Recipes
ifp_recipe = IFPHeightRecipe(donor_graph_path="path/to/donor_ifp.json")
ifp_recipe.apply(graph, registry)

sway_recipe = CatwalkSwayRecipe()
sway_recipe.apply(graph, registry)

# 5. Save Clean Result
graph.save("build/player_base.animgraph.json")
```

---

## 🧪 Running Unit Tests

Run the test suite using Python's built-in `unittest` runner:
```bash
python -m unittest tools/animgraph_toolkit/tests/test_toolkit.py
```
All tests verify node creation, graph walking, validation error detection, and recipe end-to-end execution.
