import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("edit_math", ROOT / "v1/edit_math.py")
core = importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)


class EditMath(unittest.TestCase):
    def test_rgb_is_normalized_not_saturated_white(self):
        self.assertEqual(core.normalize_color(255, 0, 0), (1, 0, 0))
        r, g, b = core.normalize_color(255, 230, 50)
        self.assertEqual(r, 1)
        self.assertAlmostEqual(g, 230 / 255)
        self.assertAlmostEqual(b, 50 / 255)
        self.assertLess(b, g)

    def test_invalid_colors_rejected(self):
        for value in (-1, 256, float("nan")):
            with self.assertRaises(ValueError):
                core.normalize_color(value, 0, 0)

    def test_pbr_base_albedo_slot_without_normal_or_orm(self):
        for name in ("Base/Albedo", "Base Color Map", "base_color_map", "Diffuse", "Albedo"):
            self.assertTrue(core.is_base_slot(name), name)
        for name in ("Normal", "Bump", "Roughness", "Metalness", "ORM", "Opacity Map", "Emission"):
            self.assertFalse(core.is_base_slot(name), name)

    def test_align_bbox_center_and_w_preserved(self):
        points = [(-2, 1, 9), (4, 3, -7), (1, 8, 0.2)]
        result = core.transform(points, "align_u_center")
        self.assertEqual(result, [(1, 1, 9), (1, 3, -7), (1, 8, 0.2)])
        self.assertEqual(core.transform(points, "align_v_max"), [(-2, 8, 9), (4, 8, -7), (1, 8, 0.2)])

    def test_rotate_90_about_bbox_center(self):
        result = core.transform([(0, 0, 2), (2, 0, 3)], "rotate", 90)
        self.assertAlmostEqual(result[0][0], 1)
        self.assertAlmostEqual(result[0][1], -1)
        self.assertAlmostEqual(result[1][0], 1)
        self.assertAlmostEqual(result[1][1], 1)
        self.assertEqual([p[2] for p in result], [2, 3])

    def test_mirror_twice_restores_coordinates(self):
        points = [(-2, 4, 5), (3, -1, 7)]
        for axis in ("mirror_u", "mirror_v"):
            self.assertEqual(core.transform(core.transform(points, axis), axis), points)

    def test_scale_and_single_point(self):
        self.assertEqual(core.transform([(0, 0, 2), (2, 4, 9)], "scale", 0.5),
                         [(0.5, 1, 2), (1.5, 3, 9)])
        self.assertEqual(core.transform([(5, -2, 6)], "scale", 3), [(5, -2, 6)])
        with self.assertRaises(ValueError):
            core.transform([(0, 0, 0)], "scale", -1)

    def test_nudge_and_center_do_not_wrap_tiles(self):
        self.assertEqual(core.transform([(1.9, 3.0, 4)], "nudge_u_plus", 0.2), [(2.1, 3.0, 4)])
        self.assertEqual(core.transform([(4, 6, 8), (6, 8, 2)], "center_tile"),
                         [(-0.5, -0.5, 8), (1.5, 1.5, 2)])

    def test_empty_nonfinite_and_unknown_rejected(self):
        with self.assertRaises(ValueError):
            core.transform([], "rotate")
        with self.assertRaises(ValueError):
            core.transform([(float("nan"), 0, 0)], "rotate")
        with self.assertRaises(ValueError):
            core.transform([(0, 0, 0)], "pack")

    def test_every_operation_preserves_w_and_input(self):
        points = [(0, 0, -2), (2, 4, 7)]
        for operation in core.OPERATIONS:
            result = core.transform(points, operation, 0.5)
            self.assertEqual([p[2] for p in result], [-2, 7])
        self.assertEqual(points, [(0, 0, -2), (2, 4, 7)])

    def test_noop_scale_and_full_turn_do_not_drift(self):
        points = [(100000.125, -3.75, 7), (-0.001, 12345.9876, -2)]
        self.assertEqual(core.transform(points, "scale", 1), points)
        self.assertEqual(core.transform(points, "rotate", 360), points)
        self.assertEqual(core.transform(points, "rotate", -720), points)

    def test_generated_block_matches_the_tested_expressions(self):
        source = (ROOT / "v1/LSY_UV_Workbench.ms").read_text()
        block = source.split("-- BEGIN SHARED EDIT MATH\n", 1)[1].split("-- END SHARED EDIT MATH", 1)[0]
        self.assertEqual(block, core.emit_maxscript())

class TilePixelTools(unittest.TestCase):
    def test_pixel_snap_non_square_negative_and_outside_tile(self):
        points = [(-1.1251, 2.3333, 7), (0.0006, -0.0006, -2)]
        u = core.transform(points, 'snap_u', 1024)
        v = core.transform(points, 'snap_v', 2048)
        for source, result in zip(points, u):
            self.assertAlmostEqual(result[0] * 1024, round(result[0] * 1024))
            self.assertLessEqual(abs(result[0]-source[0]), .5/1024+1e-12)
            self.assertEqual(result[1:], source[1:])
        for source, result in zip(points, v):
            self.assertAlmostEqual(result[1] * 2048, round(result[1] * 2048))
            self.assertLessEqual(abs(result[1]-source[1]), .5/2048+1e-12)
            self.assertEqual((result[0],result[2]), (source[0],source[2]))
        self.assertLess(u[0][0], -1)
        self.assertGreater(v[0][1], 2)
    def test_axis_scale_preserves_other_axis_and_center(self):
        points = [(-3,2,9),(1,6,-1)]
        self.assertEqual(core.transform(points, 'scale_u', 2), [(-5,2,9),(3,6,-1)])
        self.assertEqual(core.transform(points, 'scale_v', .5), [(-3,3,9),(1,5,-1)])
        self.assertEqual(core.transform(points, 'scale_u', 1), points)
    def test_invalid_grid_or_axis_scale(self):
        for operation in ('snap_u','snap_v','scale_u','scale_v'):
            for amount in (0,-1,float('nan')):
                with self.assertRaises(ValueError):
                    core.transform([(0,0,0)], operation, amount)


class DistributeTools(unittest.TestCase):
    def test_preserves_ties_endpoints_other_axis_and_input(self):
        points = [(-2,7,1),(-1.9,8,2),(-1.9,-3,4),(4,10,6)]
        self.assertEqual(core.transform(points,'distribute_u'),[(-2,7,1),(1,8,2),(1,-3,4),(4,10,6)])
        self.assertEqual(points[1],(-1.9,8,2))
    def test_single_level_and_two_levels_are_noops(self):
        for points in ([(1,0,2)],[(1,0,2),(1,5,9)],[(1,0,2),(8,5,9)]):
            self.assertEqual(core.transform(points,'distribute_u'),points)
    def test_v_distribution_keeps_u_and_w(self):
        points = [(9,-3,1),(8,-2.5,2),(7,6,3)]
        self.assertEqual(core.transform(points,'distribute_v'),[(9,-3,1),(8,1.5,2),(7,6,3)])


if __name__ == "__main__":
    unittest.main()
