"""Source guard checks; these do not execute or validate MAXScript in Max."""
import json
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
SOURCE=(ROOT/'v1/LSY_UV_Workbench.ms').read_text()
ANALYSIS=(ROOT/'v1/island_analysis.ms').read_text()

class ReviewContracts(unittest.TestCase):
    def test_new_search_and_capture_clear_previous_results_before_attempt(self):
        capture=ANALYSIS.split('fn lsyUVCaptureReference =')[1].split('fn lsyUVFindSimilar')[0]
        search=ANALYSIS.split('fn lsyUVFindSimilar =')[1].split('fn lsyUVSelectSimilarResults')[0]
        self.assertLess(capture.index('lsyUVInvalidateAnalysis clearReference:true'),capture.index('try'))
        self.assertLess(search.index('lsyUVInvalidateAnalysis()'),search.index('try'))
        bind=SOURCE.split('fn lsyUVBind =')[1].split('fn lsyUVMode')[0]
        self.assertIn('lsyUVInvalidateAnalysis clearReference:true',bind)

    def test_write_context_rejects_unsupported_state_before_coordinate_sampling(self):
        guard=SOURCE.split('fn lsyUVCheckWriteContext node modifier =')[1].split('fn lsyUVBind')[0]
        for condition in ('animButtonState','theHold.Holding()','getEnableSoftSelection()','lsyUVHasAnimatedPoints modifier','refs.dependentNodes node.baseObject'):
            self.assertIn(condition,guard)
        inventory=json.loads((ROOT/'v1/max2023_unwrap_api.json').read_text())
        self.assertIn('getEnableSoftSelection',inventory['members'])
        edit=SOURCE.split('fn lsyUVEdit operation amount =')[1].split('-- BEGIN UV CONNECTIVITY')[0]
        self.assertLess(edit.index('lsyUVCheckWriteContext lsyUVNode lsyUVMod'),edit.index('lsyUVReadIslandSnapshot()'))
        commit=(ROOT/'v1/repair_ops.ms').read_text().split('fn lsyUVRepairMaterialKey')[0]
        self.assertIn('safe=lsyUVTopologyEqual',commit)
        self.assertIn('theHold.SuperCancel()',commit)

    def test_host_helper_catch_rethrows_without_argument(self):
        host=(ROOT/'tests/workbench_host_tests.ms').read_text()
        self.assertNotIn('throw (getCurrentException())',host)
        self.assertIn('throw()',host)
        self.assertIn('Replacing root material must invalidate analysis.',host)

    def test_texture_probe_runs_after_native_filter_reset_and_rolls_back_on_error(self):
        prepare=SOURCE.split('fn lsyUVPrepareCustomBackground =')[1].split('fn lsyUVSetBackground')[0]
        self.assertLess(prepare.index('modifier.setMatID 1'),prepare.index('lsyUVNativeMapIndices()'))
        self.assertIn('if changed do lsyUVIsolationRestore()',prepare)
        refresh=SOURCE.split('fn lsyUVBackgroundRefresh =')[1].split('fn lsyUVManualBackground')[0]
        self.assertNotIn('lsyUVNativeMapIndices()',refresh)

    def test_unavailable_editor_does_not_enter_ui_discovery_or_disable_tracking(self):
        refresh=SOURCE.split('fn lsyUVBackgroundRefresh =')[1].split('fn lsyUVManualBackground')[0]
        ready=refresh.split('if not lsyUVEditorReady() then')[1].split('    try')[0]
        self.assertIn('return true',ready)
        self.assertNotIn('autoBackground.checked=false',ready)
        self.assertNotIn('lsyUVNativeUI',ready)
        self.assertLess(refresh.index('if not lsyUVEditorReady()'),refresh.index('lsyUVNativeUI'))

    def test_all_coordinate_commands_share_atomic_hold_and_full_snapshot_guard(self):
        source=(ROOT/'v1/repair_ops.ms').read_text()
        for requirement in ('theHold.SuperBegin()','theHold.SuperAccept undoName','theHold.SuperCancel()',
                            'lsyUVSnapshotEqual live expected','lsyUVTopologyEqual (lsyUVReadIslandSnapshot()) snapshot'):
            self.assertIn(requirement,source)
        self.assertIn('lsyUVCommitCoordinates snapshot ids targets',SOURCE)
        self.assertIn('lsyUVCommitCoordinates plan[1] plan[2] plan[3]',source)
        self.assertNotIn('mapping as string',ANALYSIS)
        self.assertIn('fits[1]',ANALYSIS)

    def test_animation_dispatch_uses_subcontrollers_not_modifier(self):
        scan=SOURCE.split('fn lsyUVHasAnimatedPoints modifier =')[1].split('fn lsyUVCheckWriteContext')[0]
        self.assertNotIn('isAnimated modifier',SOURCE)
        self.assertIn('getSubAnim item i',scan)
        self.assertIn('isAnimated control',scan)
        self.assertIn('child.controller',scan)

    def test_density_extracts_native_triangles_without_mutating_source(self):
        commands=(ROOT/'v1/repair_ops.ms').read_text()
        extraction=commands.split('fn lsyUVNativeTriangles snapshot =')[1].split('fn lsyUVTrianglesEqual')[0]
        self.assertIn('snapshotAsMesh node',extraction)
        self.assertIn('getFace meshValue t',extraction)
        self.assertIn('matches.numberSet!=1',extraction)
        for forbidden in ('convertToMesh','convertToPoly','collapseStack','polyop.set','polyop.triangulate'):
            self.assertNotIn(forbidden,extraction)
        self.assertIn('lsyUVTrianglesEqual plan[10]',commands)

    def test_reserved_keywords_are_not_declared_as_loop_or_local_names(self):
        import re
        reserved=set('about animate as at by case catch collect continue coordsys default do else exit fn for from function global if in local macroscript mapped max of on parameters persistent plugin rcmenu return rollout set struct then throw to tool try undo utility when where while with'.split())
        for path in [ROOT/'v1/LSY_UV_Workbench.ms',ROOT/'tests/workbench_host_tests.ms']:
            source=path.read_text()
            source=re.sub(r'/\*.*?\*/|"(?:\\.|[^"\\])*"|--[^\n]*','',source,flags=re.S)
            names=re.findall(r'\b(?:local|global|for|fn)\s+([A-Za-z_]\w*)',source)
            self.assertFalse(set(n.lower() for n in names)&reserved,str(path))

    def test_geometry_space_validation_uses_known_whole_object_transforms(self):
        source=(ROOT/'v1/repair_ops.ms').read_text()
        space=source.split('local basePoints=')[1].split('local owners=')[0]
        self.assertIn('inverse node.objectTransform',space)
        self.assertIn('inverse node.transform',space)
        self.assertIn('for i=1 to count',space)
        self.assertIn('if chosen==0',space)
        self.assertNotIn('nearest',space)

    def test_symmetry_policy_is_explicit_and_requires_one_zero_rotation_fit(self):
        self.assertIn('checkbox keepDirection',SOURCE)
        self.assertRegex(SOURCE,r'checkbox keepDirection [^\n]+checked:false')
        self.assertIn('preserveDirection:false',ANALYSIS)
        self.assertIn('if eligible.count==1',ANALYSIS)
        self.assertIn('#preserveDirection',ANALYSIS)

    def test_evaluated_geometry_reads_standalone_mesh_without_node_context(self):
        source=(ROOT/'v1/repair_ops.ms').read_text()
        self.assertIn('meshop.getVert meshValue i',source)
        self.assertNotIn('getVert meshValue i)',source.replace('meshop.getVert meshValue i)',''))

    def test_stack_reference_is_kept_only_when_topology_and_reference_points_match(self):
        source=(ROOT/'v1/repair_ops.ms').read_text()
        retain=source.split('local committed=')[1]
        self.assertIn('lsyUVTopologyEqual live plan[1]',retain)
        self.assertIn('live[1][index]-plan[1][1][index]',retain)
        self.assertIn('lsyUVReferenceSnapshot=live',retain)
        self.assertIn('lsyUVSimilarMatches=#()',retain)

    def test_stack_and_density_own_independent_panels_and_read_only_plans(self):
        source=(ROOT/'v1/repair_ops.ms').read_text()
        stack=source.split('fn lsyUVPlanStack =')[1].split('fn lsyUVWorldCentimeters')[0]
        density=source.split('fn lsyUVDensityRead =')[1].split('fn lsyUVApplyRepairPlan')[0]
        self.assertIn('lsyUVStackPlan=',stack)
        self.assertNotIn('lsyUVDensityPlan=',stack)
        self.assertNotIn('LSYUVTexel.',stack)
        self.assertIn('lsyUVDensityPlan=',density)
        self.assertNotIn('lsyUVStackPlan=',density)
        self.assertNotIn('LSYUVStack.',density)
        self.assertIn('rollout LSYUVStack ',SOURCE)
        self.assertIn('rollout LSYUVTexel ',SOURCE)
        self.assertNotIn('rollout LSYUVRepair ',SOURCE)
        self.assertIn('lsyUVApplyRepairPlan #stack',SOURCE)
        self.assertIn('lsyUVApplyRepairPlan #density',SOURCE)

    def test_read_only_similarity_changes_do_not_cancel_density_plan(self):
        invalidate=SOURCE.split('fn lsyUVInvalidateAnalysis ')[1].split('fn lsyUVHasAnimatedPoints')[0]
        self.assertIn('invalidateCoordinates:false',invalidate)
        self.assertLess(invalidate.index('if invalidateCoordinates do'),invalidate.index('lsyUVDensityPlan=undefined'))
        commands=(ROOT/'v1/repair_ops.ms').read_text()
        self.assertIn('clearReference:true invalidateCoordinates:true',commands)

    def test_density_area_coordinates_remove_only_world_translation(self):
        source=(ROOT/'v1/repair_ops.ms').read_text()
        extract=source.split('fn lsyUVWorldCentimeters node =')[1].split('fn lsyUVWorldEqual')[0]
        self.assertIn('matrix3 full.row1 full.row2 full.row3 [0,0,0]',extract)
        self.assertIn('*linear)/cm',extract)
        self.assertNotIn('node.objectTransform=',extract)
        self.assertIn('if data[4][i][1]<=0 then throw',source)
        self.assertIn('Reference copy requires all selected islands',source)

    def test_pending_background_retry_is_scoped_to_active_modifier(self):
        retry=SOURCE.split('fn lsyUVRetryPendingBackground modifier =')[1].split('fn lsyUVBind')[0]
        self.assertIn('modPanel.getCurrentObject()!=modifier',retry)
        self.assertIn('entry[1]==modifier',retry)
        self.assertIn('modifier.numberMaps()==modifier.texMapList.count+1',retry)
        self.assertNotIn('select ',retry)
        self.assertNotIn('modPanel.setCurrentObject',retry)
