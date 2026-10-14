import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

spec = importlib.util.spec_from_file_location(
    "auto_check", Path(__file__).resolve().parents[1] / "v0/v0_auto_check.py")
auto_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auto_check)


def host(points, modifier_count=1):
    modifier = SimpleNamespace(
        numberVerticesByNode=lambda node: len(points),
        numberPolygonsByNode=lambda node: 1,
        getVertexPosition=lambda time, index: SimpleNamespace(
            x=points[index - 1][0], y=points[index - 1][1], z=0),
        getMapChannel=lambda: 0, getVC=lambda: False)
    node = SimpleNamespace(modifiers=[modifier] * modifier_count)
    class Selection(list):
        @property
        def count(self):
            return len(self)
    return SimpleNamespace(selection=Selection([node]), classOf=lambda m: "Unwrap",
                           Unwrap_UVW="Unwrap", currentTime=0)


class CoordinateChecks(unittest.TestCase):
    def test_reads_first_and_last_one_based_vertices(self):
        result = auto_check.check_uv(host([(0, 0), (1, 1)]))
        self.assertEqual(result["uv_vertices"], 2)

    def test_rejects_nonfinite_last_vertex(self):
        with self.assertRaisesRegex(ValueError, "vertex 2"):
            auto_check.check_uv(host([(0, 0), (float("nan"), 1)]))

    def test_rejects_empty_uvs(self):
        with self.assertRaisesRegex(ValueError, "nonempty"):
            auto_check.check_uv(host([]))

    def test_rejects_ambiguous_modifier(self):
        with self.assertRaisesRegex(ValueError, "exactly one Unwrap"):
            auto_check.check_uv(host([(0, 0)], modifier_count=2))

    def test_rejects_no_selection(self):
        rt = host([(0, 0)])
        rt.selection.clear()
        with self.assertRaisesRegex(ValueError, "Select exactly one"):
            auto_check.check_uv(rt)


if __name__ == "__main__":
    unittest.main()
