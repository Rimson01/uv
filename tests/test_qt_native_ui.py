import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'v1'))
import qt_native_ui as core

class Item:
    def __init__(self,labels,current=0):self.names=labels;self.index=current
    def labels(self):return self.names
    def current(self):return self.index

class NativeUI(unittest.TestCase):
    def test_material_names_with_numbers_and_periods(self):
        labels=['All IDs','42: 08-Default (Metal.Rough)','2: wood','7: Stone']
        self.assertEqual(core.id_slots(labels,[2,7,42]),{0:0,42:1,2:2,7:3})
    def test_ambiguous_controls_are_rejected(self):
        with self.assertRaises(RuntimeError):core.find_id([Item(['All IDs','2']),Item(['All IDs','2'])],[2])
    def test_texture_name_numbers_not_ids(self):
        self.assertIsNone(core.id_slots(['All IDs','2.png'],[2]))
    def test_texture_subset_uses_actual_ui_order(self):
        self.assertEqual(core.find_maps([Item(['Checker','Map #16 (a.TGA)','Map #42 (b.TGA)'],1)],['Map #42','Map #16','Map #99'],2),[3,2,0])
    def test_texture_duplicate_names_rejected(self):
        with self.assertRaises(RuntimeError):core.find_maps([Item(['Checker','Map #16'],1)],['Map #16','Map #16'],2)

class Action:
    def __init__(self,text,checked=False):self.label=text;self.checked=checked;self.group=[]
    def isSeparator(self):return False
    def text(self):return self.label
    def isChecked(self):return self.checked
    def isEnabled(self):return True
    def trigger(self):
        for a in self.group:a.checked=False
        self.checked=True

class Menu:
    def __init__(self):
        self.entries=[Action('All IDs',True),Action('42: Wood')]
        for a in self.entries:a.group=self.entries
    def actions(self):return self.entries

class NativeMenuSelection(unittest.TestCase):
    def test_real_menu_selection_and_original_item_restore(self):
        adapter=core.MenuItems(Menu())
        self.assertEqual(adapter.current(),0)
        adapter.choose(1)
        self.assertEqual(adapter.current(),1)
        adapter.choose(0)
        self.assertEqual(adapter.current(),0)
    def test_number_change_without_checked_menu_is_not_success(self):
        menu=Menu();menu.entries[1].trigger=lambda:None
        with self.assertRaises(RuntimeError):core.MenuItems(menu).choose(1)

class HostFailureDiagnostics(unittest.TestCase):
    def test_missing_texture_ui_reports_actual_native_state(self):
        from types import SimpleNamespace, ModuleType
        from unittest.mock import patch
        runtime=SimpleNamespace(undefined=None,lsyUVNativeOperation='maps',lsyUVNativeNames=['Map #1','Map #2'],
            lsyUVMod=SimpleNamespace(getCurrentMap=lambda:2,getMatID=lambda:0,
                getAutoBackground=lambda:False,numberMaps=lambda:2))
        module=ModuleType('pymxs');module.runtime=runtime
        with patch.dict(sys.modules,{'pymxs':module}),patch.object(core,'qt_items',return_value=[]):
            core.run_host()
        self.assertIsNone(runtime.lsyUVNativeResult)
        self.assertIn('Native texture UI matches=0',runtime.lsyUVNativeError)
        self.assertIn('filter=0 auto=False maps=2 texture-list=2 current-map=2',runtime.lsyUVNativeError)

class NativeOneBasedFilter(unittest.TestCase):
    def test_api_first_item_is_one_and_sparse_ids_use_actual_ui_order(self):
        from types import SimpleNamespace, ModuleType
        from unittest.mock import patch
        item=Item(['All IDs','42: Wood','2: Metal'],1)
        written=[]
        def select(index):
            written.append(index);item.index=index-1
        runtime=SimpleNamespace(undefined=None,lsyUVNativeOperation='select_id',lsyUVNativeIDs=[2,42],
            lsyUVNativeTarget=2,Array=lambda *args:args,
            lsyUVMod=SimpleNamespace(setMatID=select,getMatID=lambda:item.index+1))
        module=ModuleType('pymxs');module.runtime=runtime
        with patch.dict(sys.modules,{'pymxs':module}),patch.object(core,'qt_items',return_value=[item]):
            core.run_host()
            self.assertEqual(runtime.lsyUVNativeResult,(42,3,2))
            runtime.lsyUVNativeTarget=0
            core.run_host()
        self.assertEqual(written,[3,1])
        self.assertEqual(runtime.lsyUVNativeResult,(2,1,0))
