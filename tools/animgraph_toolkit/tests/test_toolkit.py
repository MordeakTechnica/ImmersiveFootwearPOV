"""
Test Suite for the AnimGraph Toolkit.
Verifies registry indexing, validation, tracing, diffing, rig kinematics, and recipe application.
"""

import os
import unittest
import math
from ..core.models import AnimGraph, AnimNode
from ..core.registry import NodeRegistry
from ..core.validator import GraphValidator
from ..core.traversal import GraphWalker
from ..core.rig import RigSkeleton, BoneTransformInfo
from ..core.diff import GraphDiffer
from ..factory.node_factory import NodeFactory
from ..recipes.ifp_height import IFPHeightRecipe
from ..recipes.foot_elevation import FootElevationRecipe
from ..recipes.catwalk_sway import CatwalkSwayRecipe


class TestAnimGraphToolkit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
        cls.live_raw_json = os.path.join(
            cls.repo_root, "source", "raw", "base", "gameplay", "anim_graphs", "player_base.animgraph.json"
        )
        cls.rig_json = os.path.join(
            cls.repo_root, "scratch", "extracted_rig", "base", "characters", "entities", "player", "player_woman_skeleton.rig.json"
        )
        cls.itp_extracted = r"C:\Users\cogli\.gemini\antigravity\scratch\itp_extracted\base\gameplay\anim_graphs\player_base.animgraph.json"
        cls.ifp_extracted = r"C:\Users\cogli\.gemini\antigravity\scratch\ifp_height_extracted\base\gameplay\anim_graphs\player_base.animgraph.json"

    def test_live_graph_validation(self):
        """Validates that our current production raw animgraph is 100% clean and error-free."""
        self.assertTrue(os.path.exists(self.live_raw_json), f"Live JSON missing at {self.live_raw_json}")
        graph = AnimGraph.load(self.live_raw_json)
        registry = NodeRegistry(graph)
        validator = GraphValidator(graph, registry)
        report = validator.validate(reachability_target="2")

        self.assertTrue(report.is_valid, f"Validation failed:\n{report.summary()}")
        self.assertEqual(len(report.duplicate_handles), 0)
        self.assertEqual(len(report.dangling_references), 0)
        self.assertEqual(len(report.missing_variables), 0)
        self.assertTrue(report.is_reachability_valid)

    def test_node_factory(self):
        """Verifies that NodeFactory generates compliant REDengine descriptors."""
        float_var = NodeFactory.create_float_variable_node("9999", "test_var")
        self.assertEqual(float_var["HandleId"], "9999")
        self.assertEqual(float_var["Data"]["$type"], "animAnimNode_FloatVariable")
        self.assertEqual(float_var["Data"]["variableName"]["$value"], "test_var")

        vec = NodeFactory.create_vector_constant("9998", 0, 0, 1.0)
        self.assertEqual(vec["Data"]["value"]["Z"], 1.0)

        tb = NodeFactory.create_translate_bone("9997", "Hips", "2", vec)
        self.assertEqual(tb["Data"]["bone"]["name"]["$value"], "Hips")

    def test_backward_trace(self):
        """Verifies that GraphWalker accurately traces the output pipeline backward to Node 2."""
        graph = AnimGraph.load(self.live_raw_json)
        registry = NodeRegistry(graph)
        walker = GraphWalker(registry)

        out_node = graph.get_output_node()
        self.assertIsNotNone(out_node)
        path = walker.trace_backward(out_node, max_depth=15)
        self.assertGreater(len(path), 3)

        # Output connects through sway/elevation back to Node 2
        path_ids = [n.handle_id for n in path if n.handle_id]
        self.assertIn("1", path_ids)
        self.assertIn("2", path_ids)

    def test_ast_path_and_enclosing_node(self):
        """Verifies finding JSON AST paths and enclosing parent nodes."""
        graph = AnimGraph.load(self.live_raw_json)
        registry = NodeRegistry(graph)
        walker = GraphWalker(registry)

        ast_path = walker.find_ast_path("6050")
        self.assertIsNotNone(ast_path)
        self.assertGreater(len(ast_path), 5)

        enclosing = walker.get_enclosing_node("6050")
        self.assertIsNotNone(enclosing)
        self.assertEqual(enclosing.handle_id, "6052")

    def test_subtree_export(self):
        """Verifies extracting a node subtree as a self-contained dictionary."""
        graph = AnimGraph.load(self.live_raw_json)
        subtree = graph.export_subtree("6050")
        self.assertIsInstance(subtree, dict)
        self.assertEqual(subtree.get("HandleId"), "6050")
        self.assertEqual(subtree["Data"]["$type"], "animAnimNode_RotateBone")

    def test_graph_differ(self):
        """Verifies that GraphDiffer detects added, removed, and modified nodes and variables."""
        graph_a = AnimGraph.load(self.live_raw_json)
        
        # Create synthetic modified graph B
        import copy
        raw_b = copy.deepcopy(graph_a.raw)
        graph_b = AnimGraph(raw_b)
        reg_b = NodeRegistry(graph_b)
        
        # Add new node and variable to B
        new_node = NodeFactory.create_float_variable_node("7777", "synthetic_diff_var")
        graph_b.ensure_float_variable("synthetic_diff_var", "7778", default_val=1.0)
        graph_b.nodes_to_init.append(new_node)
        
        differ = GraphDiffer()
        report = differ.diff(graph_a, graph_b)
        
        self.assertTrue(report.has_differences)
        self.assertIn("synthetic_diff_var", report.variables_added)
        self.assertIn("7777", report.nodes_added)

    def test_rig_kinematics(self):
        """Verifies forward kinematics and bone coordinate axis calculation."""
        if not os.path.exists(self.rig_json):
            self.skipTest("Extracted rig fixture not found.")

        skeleton = RigSkeleton.load(self.rig_json)
        self.assertGreater(skeleton.total_bones, 50)
        self.assertIn("LeftArm", skeleton.bone_names)

        arm_info = skeleton.get_bone_info("LeftArm")
        self.assertIsNotNone(arm_info)
        self.assertEqual(arm_info.name, "LeftArm")
        self.assertEqual(arm_info.parent_name, "LeftShoulder")

        # Verify unit vector properties of coordinate axes (length = 1.0)
        for axis in [arm_info.local_x_axis, arm_info.local_y_axis, arm_info.local_z_axis]:
            length = math.sqrt(sum(c * c for c in axis))
            self.assertAlmostEqual(length, 1.0, places=3)

    def test_clean_recipe_build_pipeline(self):
        """Simulates building a complete unified graph from base ITP and donor IFP using recipes."""
        if not os.path.exists(self.itp_extracted) or not os.path.exists(self.ifp_extracted):
            self.skipTest("Scratch donor files not found on this machine.")

        base_graph = AnimGraph.load(self.itp_extracted)
        registry = NodeRegistry(base_graph)

        # Apply Recipes
        ifp_recipe = IFPHeightRecipe(self.ifp_extracted)
        self.assertTrue(ifp_recipe.apply(base_graph, registry))

        elev_recipe = FootElevationRecipe()
        self.assertTrue(elev_recipe.apply(base_graph, registry))

        sway_recipe = CatwalkSwayRecipe()
        self.assertTrue(sway_recipe.apply(base_graph, registry))

        # Validate resulting graph
        validator = GraphValidator(base_graph, registry)
        report = validator.validate()
        self.assertTrue(report.is_valid, f"Generated graph is invalid:\n{report.summary()}")


if __name__ == "__main__":
    unittest.main()
