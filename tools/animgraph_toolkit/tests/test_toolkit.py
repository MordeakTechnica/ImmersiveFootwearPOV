"""
Test Suite for the AnimGraph Toolkit.
Verifies registry indexing, validation, tracing, and recipe application.
"""

import os
import unittest
from ..core.models import AnimGraph, AnimNode
from ..core.registry import NodeRegistry
from ..core.validator import GraphValidator
from ..core.traversal import GraphWalker
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
        cls.itp_extracted = r"C:\Users\cogli\.gemini\antigravity\scratch\itp_extracted\base\gameplay\anim_graphs\player_base.animgraph.json"
        cls.ifp_extracted = r"C:\Users\cogli\.gemini\antigravity\scratch\ifp_height_extracted\base\gameplay\anim_graphs\player_base.animgraph.json"

    def test_live_graph_validation(self):
        """Validates that our current production raw animgraph is 100% clean and error-free."""
        self.assertTrue(os.path.exists(self.live_raw_json), f"Live JSON missing at {self.live_raw_json}")
        graph = AnimGraph.load(self.live_raw_json)
        registry = NodeRegistry(graph)
        validator = GraphValidator(graph, registry)
        report = validator.validate()

        self.assertTrue(report.is_valid, f"Validation failed:\n{report.summary()}")
        self.assertEqual(len(report.duplicate_handles), 0)
        self.assertEqual(len(report.dangling_references), 0)
        self.assertEqual(len(report.missing_variables), 0)

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
