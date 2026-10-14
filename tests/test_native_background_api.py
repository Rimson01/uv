"""Guard adapter calls against the official Max 2023 API inventory.

This catches unsupported method names, not runtime/list-index behavior.
"""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BackgroundAPIContract(unittest.TestCase):
    def test_all_bound_modifier_calls_use_documented_members(self):
        inventory = json.loads((ROOT / 'v1/max2023_unwrap_api.json').read_text())
        known = {name.lower() for name in inventory['members']}
        source = (ROOT / 'v1/LSY_UV_Workbench.ms').read_text()
        source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
        source = re.sub(r'"(?:\\.|[^"\\])*"|--[^\n]*', '', source)
        calls = {name.lower() for name in re.findall(r'(?:lsyUVMod|modifier)\.([A-Za-z0-9_]+)', source)}
        self.assertTrue(calls)
        self.assertEqual(calls - known, set(), 'Unsupported native Unwrap member')

    def test_incident_face_reader_uses_read_only_documented_methods(self):
        inventory = json.loads((ROOT / 'v1/max2023_selection_api.json').read_text())
        known = {name.lower() for name in inventory['methods']}
        source = (ROOT / 'v1/LSY_UV_Workbench.ms').read_text()
        reader = source.split('fn lsyUVSelectedFaces', 1)[1].split('fn lsyUVMaterial', 1)[0]
        reader = re.sub(r'"(?:\\.|[^"\\])*"|--[^\n]*', '', reader)
        calls = {name.lower() for name in re.findall(r'lsyUVMod\.([A-Za-z0-9_]+)', reader)}
        self.assertTrue(calls)
        self.assertEqual(calls - known, set(), 'Unsupported UV selection/topology API')
        self.assertTrue(all(name.startswith(('get', 'number')) for name in calls),
                        'Selection reader must not convert or write user selection')

    def test_background_adapter_uses_documented_methods(self):
        inventory = json.loads((ROOT / 'v1/max2023_main_toolbar_api.json').read_text())
        known = {name.lower() for name in inventory['methods']}
        modifier = json.loads((ROOT / 'v1/max2023_modifier_api.json').read_text())
        known.update(name.lower() for name in modifier['members'])
        known.update(name.lower() for name in json.loads((ROOT/'v1/max2023_unwrap_api.json').read_text())['members'] if name.lower()=='numbermatids')
        # UpdateView is used by the existing, host-validated V0 display adapter.
        known.add('updateview')
        source = (ROOT / 'v1/LSY_UV_Workbench.ms').read_text()
        adapter = source.split('fn lsyUVDropdownIndex', 1)[1].split('fn lsyUVKeyEqual', 1)[0]
        # Ignore comments and messages; inspect actual modifier method access.
        adapter = re.sub(r'"(?:\\.|[^"\\])*"|--[^\n]*', '', adapter)
        calls = {name.lower() for name in re.findall(r'lsyUVMod\.([A-Za-z0-9_]+)', adapter)}
        self.assertTrue(calls)
        self.assertEqual(calls - known, set(), 'Unsupported native background API')


if __name__ == '__main__':
    unittest.main()
