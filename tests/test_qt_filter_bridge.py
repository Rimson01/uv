import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'v1'))
from qt_filter_bridge import find_filter

class Combo:
    def __init__(self, labels, visible=True):self.labels=labels;self.visible=visible
    def isVisible(self):return self.visible
    def count(self):return len(self.labels)
    def itemText(self,i):return self.labels[i]

class QtFilter(unittest.TestCase):
    def test_sparse_ids_use_actual_order_and_localized_all_label(self):
        widget=Combo(['전체 ID','42','2','7'])
        self.assertEqual(find_filter([widget],[2,7,42]),(widget,{42:1,2:2,7:3}))
    def test_hidden_and_texture_combos_do_not_match(self):
        widget=Combo(['All IDs','2','7'])
        self.assertEqual(find_filter([Combo(['All IDs','2','7'],False),Combo(['Map #16','a_2.tga','b_7.tga']),widget],[2,7])[0],widget)
    def test_ambiguous_or_missing_list_rejected(self):
        for widgets in ([],[Combo(['All IDs','2','2'])],[Combo(['All IDs','2','7']),Combo(['All IDs','2','7'])]):
            with self.assertRaises(RuntimeError):find_filter(widgets,[2,7])

    def test_unused_ids_and_material_name_suffix(self):
        widget=Combo(['All IDs','ID 2: Wood','ID 3: Metal','ID 7: Plastic'])
        self.assertEqual(find_filter([widget],[2,7])[1],{2:1,3:2,7:3})
    def test_texture_names_rejected_even_if_numbers_match(self):
        with self.assertRaises(RuntimeError):
            find_filter([Combo(['All IDs','2.png','7.png'])],[2,7])
