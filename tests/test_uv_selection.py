import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'v1'))
import uv_selection as core

class UVConnectivity(unittest.TestCase):
    def test_seams_duplicates_and_multiple_seeds(self):
        edges = [(1,2),(2,3),(3,1),(1,2),(4,5),(5,6)]
        used = set(range(1,7))
        self.assertEqual(core.island_vertices(edges, {2}, used), {1,2,3})
        self.assertEqual(core.island_vertices(edges, {2,5}, used), used)
    def test_empty_and_unused_seeds(self):
        self.assertEqual(core.island_vertices([(1,2)], {9}, {1,2}), set())
        self.assertEqual(core.island_vertices([], {1}, {1}), {1})
    def test_invalid_edge_rejected(self):
        with self.assertRaises(ValueError):
            core.island_vertices([(1,9)], {1}, {1})
    def test_shipped_connectivity_matches(self):
        source=(Path(__file__).resolve().parents[1]/'v1/LSY_UV_Workbench.ms').read_text()
        block=source.split('-- BEGIN UV CONNECTIVITY\n')[1].split('-- END UV CONNECTIVITY')[0]
        self.assertEqual(block,core.emit_maxscript())
