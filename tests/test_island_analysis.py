import math
import sys
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'v1'))
import island_analysis as core

class IslandAnalysis(unittest.TestCase):
    def test_edge_connects_but_single_point_does_not(self):
        faces=[([1,2,3],[1,2,3]),([2,1,4],[2,1,4]),([3,5,6],[3,5,6])]
        self.assertEqual(core.components(faces),[[0,1],[2]])
    def test_seam_and_coincident_copies_stay_separate(self):
        self.assertEqual(core.components([([1,2,3],[1,2,3]),([4,5,6],[2,1,4])]),[[0],[1]])
    def test_unrelated_geometry_uv_sharing_rejected(self):
        with self.assertRaises(ValueError):core.components([([1,2,3],[1,2,3]),([1,4,5],[9,4,5])])
    def test_continuous_rotation_and_translation(self):
        r=[(0,0),(3,0),(2,1),(0,2)]
        angle=math.radians(37)
        q=[(x*math.cos(angle)-y*math.sin(angle)+8,x*math.sin(angle)+y*math.cos(angle)-3) for x,y in r]
        self.assertEqual(core.exact_solutions(r,q,[[0,1,2],[0,2,3]],[[0,1,2],[0,2,3]]),[(0,1,2,3)])
    def test_same_bbox_wrong_shape_topology_scale_and_mirror_rejected(self):
        r=[(0,0),(3,0),(2,1),(0,2)]; faces=[[0,1,2],[0,2,3]]
        for q,f in [([(0,0),(3,0),(1,1),(0,2)],faces),(r,[[0,1,3],[1,2,3]]),([(2*x,2*y) for x,y in r],faces),([(-x,y) for x,y in r],faces)]:
            self.assertEqual(core.exact_solutions(r,q,faces,f),[])
    def test_symmetric_correspondence_is_not_arbitrarily_chosen(self):
        r=[(0,0),(1,0),(1,1),(0,1)]
        self.assertEqual(len(core.exact_solutions(r,r,[[0,1,2,3]],[[0,1,2,3]])),4)
    def test_embedded_analysis_matches_release_helper(self):
        source=(ROOT/'v1/LSY_UV_Workbench.ms').read_text()
        self.assertEqual(source.split('-- BEGIN ISLAND ANALYSIS\n')[1].split('-- END ISLAND ANALYSIS')[0],(ROOT/'v1/island_analysis.ms').read_text())
    def test_filter_does_not_select_or_hide(self):
        source=(ROOT/'v1/LSY_UV_Workbench.ms').read_text()
        adapter=source.split('fn lsyUVIsolateID id =')[1].split('fn lsyUVBackgroundRefresh')[0]
        self.assertIn('lsyUVNativeUI "select_id" target:id',adapter)
        for forbidden in ('selectFaces','selectVertices','setFilterSelected','hideSelected','polyop.set'):
            self.assertNotIn(forbidden,adapter)

    def test_reserved_mapped_keyword_not_used_as_local(self):
        source=(ROOT/'v1/LSY_UV_Workbench.ms').read_text()
        self.assertNotRegex(source,r'\blocal\s+mapped\s*=')

    def test_face_key_array_is_constructed_without_copy_overload(self):
        source=(ROOT/'v1/island_analysis.ms').read_text()
        self.assertNotIn('copy refKeys',source)
        self.assertIn('local keys=for faceKey in refKeys collect faceKey',source)

    def test_filter_bridge_does_not_reject_changed_editor_bounds(self):
        source=(ROOT/'v1/native_filter_bridge.cs').read_text()
        self.assertNotIn('Math.Abs(r.Left-x)',source)
        self.assertIn('public static long[] Maps',source)

    def test_native_auto_background_path_avoids_texture_dropdown_probe(self):
        source=(ROOT/'v1/LSY_UV_Workbench.ms').read_text()
        adapter=source.split('fn lsyUVIsolateID id =')[1].split('fn lsyUVBackgroundRefresh')[0]
        self.assertNotIn('SetAutoBackGround true',adapter)
        self.assertNotIn('bridge.',adapter)
        self.assertNotIn('lsyUVMapIndex',adapter)

    def test_custom_background_resets_native_filter_and_auto_before_map_work(self):
        source=(ROOT/'v1/LSY_UV_Workbench.ms').read_text()
        prepare=source.split('fn lsyUVPrepareCustomBackground =')[1].split('fn lsyUVSetBackground')[0]
        self.assertIn('modifier.SetAutoBackGround false',prepare)
        self.assertIn('modifier.setMatID 1',prepare)
        refresh=source.split('fn lsyUVBackgroundRefresh =')[1].split('fn lsyUVManualBackground')[0]
        self.assertLess(refresh.index('lsyUVShowMaterialID ids[1]'),refresh.index('lsyUVIsolateID ids[1]'))
        self.assertLess(refresh.index('lsyUVPrepareCustomBackground()'),refresh.index('lsyUVShowMaterialID ids[1]'))

    def test_actual_background_is_checked_after_id_filter_and_rollback_available(self):
        source=(ROOT/'v1/LSY_UV_Workbench.ms').read_text()
        refresh=source.split('fn lsyUVBackgroundRefresh =')[1].split('fn lsyUVManualBackground')[0]
        self.assertIn('ID filter changed the selected background.',refresh)
        self.assertIn('lsyUVNativeUI "select_id" target:0',refresh)
        self.assertIn('lsyUVLinkedDisplayState',refresh)

    def test_id_preflight_precedes_mutation_and_leaves_background_independent(self):
        source=(ROOT/'v1/LSY_UV_Workbench.ms').read_text()
        refresh=source.split('fn lsyUVBackgroundRefresh =')[1].split('fn lsyUVManualBackground')[0]
        preflight=refresh.index('lsyUVNativeUI "read_id"')
        mutation=refresh.index('lsyUVMod.SetAutoBackGround false')
        self.assertLess(preflight,mutation)
        failure=refresh[preflight:mutation]
        self.assertIn('LSYUVTools.isolateID.checked=false',failure)
        self.assertIn('showFilter=false',failure)
        self.assertNotIn('return false',failure)
        self.assertLess(refresh.index('lsyUVBackgroundKey=undefined'),preflight)

    def test_id_apply_failure_does_not_fall_through_to_background(self):
        source=(ROOT/'v1/LSY_UV_Workbench.ms').read_text()
        refresh=source.split('fn lsyUVBackgroundRefresh =')[1].split('fn lsyUVManualBackground')[0]
        failure=refresh.split('local result=lsyUVNativeUI "select_id" target:0')[1].split('lsyUVPrepareCustomBackground()')[0]
        self.assertIn('lsyUVIsolationRestore()',failure)
        self.assertIn('return false',failure)

    def test_square_symmetry_has_one_translation_only_correspondence(self):
        reference=[(0,0),(1,0),(1,1),(0,1)]
        candidate=[(x+8,y-3) for x,y in reference]
        matches=core.exact_solutions(reference,candidate,[[0,1,2,3]],[[0,1,2,3]])
        self.assertEqual(len(matches),4)
        translations=[]
        for mapping in matches:
            offsets=[(reference[r][0]-candidate[i][0],reference[r][1]-candidate[i][1]) for i,r in enumerate(mapping)]
            if all(math.dist(offsets[0],offset)<1e-6 for offset in offsets):translations.append(mapping)
        self.assertEqual(translations,[(0,1,2,3)])
