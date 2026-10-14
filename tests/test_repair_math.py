import math
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'v1'))
from repair_math import density,triangulate

class DensityMath(unittest.TestCase):
    def test_known_square_and_non_square_physical_units(self):
        uv=[(0,0,0),(1,0,0),(1,1,0),(0,1,0)]
        world=[(0,0,0),(100,0,0),(100,100,0),(0,100,0)]
        faces=[([0,1,2,3],[0,1,2,3])]
        for w,h,expected in [(1024,1024,10.24),(2048,1024,14.4815468787)]:
            row=density(uv,world,faces,[[0]],w,h)[0]
            self.assertAlmostEqual(row[0],expected,places=8)
            self.assertAlmostEqual(row[1],1.)
            self.assertAlmostEqual(row[2],10000.)

    def test_nonuniform_world_transform_and_uv_mirror(self):
        uv=[(0,0,7),(-1,0,8),(-1,1,-2),(0,1,3)]
        world=[(0,0,0),(200,0,0),(200,100,0),(0,100,0)]
        row=density(uv,world,[([0,1,2,3],[0,1,2,3])],[[0]],1024,1024)[0]
        self.assertAlmostEqual(row[0],10.24/math.sqrt(2))

    def test_concave_face_area_is_not_a_triangle_fan(self):
        # U-shaped polygon area=7. A fan from corner 0 overlaps the missing middle.
        xy=[(0,0),(3,0),(3,3),(2,3),(2,1),(1,1),(1,3),(0,3)]
        uv=[(x,y,0) for x,y in xy]; world=[(x*100,y*100,0) for x,y in xy]
        row=density(uv,world,[(list(range(8)),list(range(8)))],[[0]],1024,1024)[0]
        self.assertAlmostEqual(row[1],7.)
        self.assertAlmostEqual(row[2],70000.)
        self.assertAlmostEqual(row[0],10.24)

    def test_rotation_translation_and_winding_do_not_change_density(self):
        uv=[(0,0,0),(1,0,0),(1,1,0),(0,1,0)]
        world=[(8000,x*100-2000,y*100+3000) for x,y,_ in uv]
        f=[([3,2,1,0],[3,2,1,0])]
        self.assertAlmostEqual(density(uv,world,f,[[0]],1024,1024)[0][0],10.24)

    def test_scale_to_target_doubles_density_preserves_w(self):
        from edit_math import transform
        uv=[(0,0,7),(1,0,8),(1,1,-2),(0,1,3)]
        world=[(x*100,y*100,0) for x,y,_ in uv]
        f=[([0,1,2,3],[0,1,2,3])]
        current=density(uv,world,f,[[0]],1024,1024)[0][0]
        target=20.48
        points=transform(uv,'scale',target/current)
        self.assertAlmostEqual(density(points,world,f,[[0]],1024,1024)[0][0],target)
        self.assertEqual([p[2] for p in points],[p[2] for p in uv])

    def test_degenerate_nonplanar_and_crossed_polygons_rejected(self):
        for p in [[(0,0,0),(1,0,0),(2,0,0)],[(0,0,0),(1,0,0),(1,1,1),(0,1,0)],[(0,0,0),(2,2,0),(0,2,0),(2,0,0)]]:
            with self.assertRaises(ValueError):triangulate(p)

    def test_zero_uv_area_and_invalid_dimensions_rejected(self):
        f=[([0,1,2],[0,1,2])];world=[(0,0,0),(1,0,0),(0,1,0)]
        with self.assertRaises(ValueError):density([(0,0,0)]*3,world,f,[[0]],1024,1024)
        with self.assertRaises(ValueError):density(world,world,f,[[0]],0,1024)

    def test_independent_shells_are_reported_separately(self):
        uv=[(0,0,0),(1,0,0),(0,1,0),(0,0,0),(2,0,0),(0,2,0)]
        world=[(0,0,0),(100,0,0),(0,100,0)]*2
        rows=density(uv,world,[([0,1,2],[0,1,2]),([3,4,5],[3,4,5])],[[0],[1]],1024,1024)
        self.assertAlmostEqual(rows[0][0],10.24)
        self.assertAlmostEqual(rows[1][0],20.48)

    def test_nonplanar_polygon_uses_supplied_native_diagonal(self):
        uv=[(0,0,0),(1,0,0),(1,1,0),(0,1,0)]
        world=[(0,0,0),(1,0,0),(1,1,1),(0,1,0)]
        faces=[([0,1,2,3],[0,1,2,3])]
        first=density(uv,world,faces,[[0]],1024,1024,[[[0,1,2],[0,2,3]]])[0]
        second=density(uv,world,faces,[[0]],1024,1024,[[[0,1,3],[1,2,3]]])[0]
        self.assertAlmostEqual(first[2],math.sqrt(2))
        self.assertAlmostEqual(second[2],.5+math.sqrt(3)/2)
        self.assertNotAlmostEqual(first[0],second[0])
        self.assertEqual(first[1],1)
        self.assertEqual(second[1],1)

    def test_bad_native_corner_coverage_rejected(self):
        from repair_math import validate_native_triangles
        for triangles in [[[0,1,2]],[[0,1,2],[0,1,2]],[[0,1,2],[0,2,4]],[[0,1,2],[0,3,2]]]:
            with self.assertRaises(ValueError):validate_native_triangles(4,triangles)
        self.assertEqual(validate_native_triangles(4,[[2,1,0],[3,2,0]]),[[2,1,0],[3,2,0]])

    def test_zero_uv_triangle_does_not_reject_a_positive_area_island(self):
        uv=[(0,0,0),(1,0,0),(2,0,0),(0,1,0)]
        world=[(0,0,0),(1,0,0),(1,1,0),(0,1,0)]
        notes=[]
        row=density(uv,world,[([0,1,2,3],[0,1,2,3])],[[0]],1024,1024,[[[0,1,2],[0,2,3]]],issues=notes)[0]
        self.assertAlmostEqual(row[0],1024)
        self.assertEqual(row[1:],(1.,1.))
        self.assertIn('zero UV triangles=1',notes[0])

    def test_invalid_shell_does_not_hide_valid_read_only_measurements(self):
        uv=[(0,0,0)]*3+[(0,0,0),(1,0,0),(0,1,0)]
        world=[(0,0,0),(1,0,0),(0,1,0)]*2
        notes=[]
        rows=density(uv,world,[([0,1,2],[0,1,2]),([3,4,5],[3,4,5])],[[0],[1]],1024,1024,partial=True,issues=notes)
        self.assertIsNone(rows[0])
        self.assertIn('UV area=0',notes[0])
        self.assertAlmostEqual(rows[1][0],1024)

    def test_zero_world_positive_uv_identifies_face_and_triangle(self):
        uv=[(0,0,0),(1,0,0),(0,1,0)]
        world=[(0,0,0),(1,0,0),(2,0,0)]
        with self.assertRaisesRegex(ValueError,'face=1 triangle=1: world area=0'):
            density(uv,world,[([0,1,2],[0,1,2])],[[0]],1024,1024,[[[0,1,2]]])

    def test_float32_world_offset_explains_small_local_residual(self):
        import struct
        f32=lambda x:struct.unpack('f',struct.pack('f',x))[0]
        base=tuple(f32(x) for x in (170.254,51.9088,118.946))
        offset=tuple(f32(x) for x in (5655.326,-1950.7888,23520.054))
        baked=tuple(f32(a+b) for a,b in zip(base,offset))
        restored=tuple(f32(a-b) for a,b in zip(baked,offset))
        error=math.dist(base,restored)
        old=max(.00001,math.dist(base,(0,0,0))*1e-6)
        budget=.00001+6e-7*(math.dist(base,(0,0,0))+math.dist(baked,(0,0,0))+math.dist(offset,(0,0,0)))
        self.assertGreater(error,old)
        self.assertLess(error,budget)
        self.assertGreater(math.dist(base,baked),budget)
