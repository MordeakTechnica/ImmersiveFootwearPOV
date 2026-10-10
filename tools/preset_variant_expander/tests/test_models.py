"""Unit tests for domain models."""

import unittest
from ..core.models import ShoeCalibration, ExpansionResult, VariantMatch


class TestModels(unittest.TestCase):

    def test_shoe_calibration_serialization(self):
        cal = ShoeCalibration(heel=10.5, platform=3.2)
        d = cal.to_dict()
        self.assertEqual(d["heel"], 10.5)
        self.assertEqual(d["platform"], 3.2)

        restored = ShoeCalibration.from_dict(d)
        self.assertEqual(restored.heel, 10.5)
        self.assertEqual(restored.platform, 3.2)

    def test_expansion_result_flags(self):
        res = ExpansionResult()
        self.assertFalse(res.has_changes)

        res.new_variants_added = 5
        self.assertTrue(res.has_changes)


if __name__ == "__main__":
    unittest.main()
