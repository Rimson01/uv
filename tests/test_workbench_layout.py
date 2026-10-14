"""Check shipped resize formulas keep every child control in its pane."""
from pathlib import Path
import re
import unittest

SOURCE = (Path(__file__).resolve().parents[1]/'v1/LSY_UV_Workbench.ms').read_text()

class WorkbenchLayout(unittest.TestCase):
    def test_controls_fit_child_at_minimum_and_expanded_width(self):
        for name in ('LSYUVTools','LSYUVAdvanced','LSYUVEditOps','LSYUVTileOps','LSYUVNativeOps','LSYUVDisplay'):
            body = SOURCE.split('rollout '+name+' ',1)[1].split('\n)\n',1)[0]
            height = int(re.search(r'height:(\d+)',body).group(1))
            controls = {m.group(1):int(m.group(2)) for m in re.finditer(r'(\w+) "[^\n]*height:(\d+)',body)}
            rows = re.findall(r'(\w+)\.pos = \[8 \+ (\d+) \* \(\(w-16\)/(\d+)\.0\), (\d+)\]',body)
            self.assertEqual(set(controls), {row[0] for row in rows}, name)
            for width in (220,300,500):
                for control,column,count,y in rows:
                    cell = (width-16)/int(count)
                    self.assertLessEqual(8+int(column)*cell+cell-6,width)
                    self.assertLessEqual(int(y)+controls[control],height)
    def test_background_advanced_controls_moved(self):
        background = SOURCE.split('rollout LSYUVTools ',1)[1].split('\n)\n',1)[0]
        self.assertNotIn('spinner manualID',background)
        self.assertNotIn('dropdownlist textureSlot',background)
        self.assertIn('#style_resizing',SOURCE)
        self.assertIn('on LSYUVWorkbench resized size',SOURCE)

    def test_checkbox_width_is_never_written_at_runtime(self):
        for name in re.findall(r'checkbox (\w+) ', SOURCE):
            self.assertNotRegex(SOURCE, r'\b' + name + r'\.width\s*=')
        self.assertIn('local layoutBusy = false', SOURCE)
        self.assertIn('if isProperty', SOURCE)

    def test_initial_positions_match_layout_before_subrollout_creation(self):
        for name in ('LSYUVTools','LSYUVAdvanced','LSYUVEditOps','LSYUVTileOps','LSYUVNativeOps','LSYUVDisplay'):
            body = SOURCE.split('rollout '+name+' ',1)[1].split('    fn layout',1)[0]
            runtime = SOURCE.split('rollout '+name+' ',1)[1].split('    fn layout',1)[1].split('    on ',1)[0]
            initial = {m.group(1): (float(m.group(2)),int(m.group(3))) for m in re.finditer(r'(\w+) "[^\n]*pos:\[([0-9.]+),(\d+)\]',body)}
            rows = re.findall(r'(\w+)\.pos = \[8 \+ (\d+) \* \(\(w-16\)/(\d+)\.0\), (\d+)\]',runtime)
            for control,column,count,y in rows:
                self.assertEqual(initial[control][1],int(y), (name,control))
                self.assertAlmostEqual(initial[control][0],8+int(column)*284/int(count),places=3)
            self.assertGreater(max(pos[1] for pos in initial.values()),100)

    def test_open_handler_reaches_layout_without_undefined_rollout_function(self):
        self.assertNotIn('setRolloutState', SOURCE)
        handler = SOURCE.split('on LSYUVWorkbench open do',1)[1].split('on LSYUVWorkbench resized',1)[0]
        self.assertEqual(handler.count('addSubRollout '),9)
        self.assertIn('layout (getDialogSize LSYUVWorkbench)', handler)

    def test_vertical_panel_uses_native_linked_background(self):
        parent = SOURCE.split('rollout LSYUVWorkbench ',1)[1]
        self.assertEqual(parent.count('subRollout '),1)
        self.assertNotIn('local columns',parent)
        self.assertIn('lsyUVPrepareCustomBackground()', SOURCE)
        self.assertIn('선택 ID의 UV만 표시',SOURCE)
