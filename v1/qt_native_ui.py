"""Native UV display menus; no geometry or face/vertex selection writes."""
import re


def id_value(label):
    m = re.match(r'^\s*(?:(?:material|mat)?\s*id\s*[:#]?\s*)?(\d+)(?:\s*$|\s*[:(\[\-])', label, re.I)
    return int(m.group(1)) if m else None


def id_slots(labels, expected):
    slots = {}
    special = []
    for i, label in enumerate(labels):
        value = id_value(label)
        if value is None:
            if re.search(r'\d|[./\\]', label):
                return None
            special.append(i)
        elif value in slots:
            return None
        else:
            slots[value] = i
    if len(special) == 1 and 0 not in slots:
        slots[0] = special[0]
    if 0 not in slots or not set(expected).issubset(slots):
        return None
    return slots


class MenuItems:
    def __init__(self, menu):
        self.menu = menu
        self.actions = [a for a in menu.actions() if not a.isSeparator()]
    def labels(self): return [a.text().replace('&', '') for a in self.actions]
    def current(self):
        checked = [i for i,a in enumerate(self.actions) if a.isChecked()]
        return checked[0] if len(checked) == 1 else -1
    def choose(self, i):
        if not self.actions[i].isEnabled(): raise RuntimeError('Native menu item disabled')
        self.actions[i].trigger()
        if not self.actions[i].isChecked():
            raise RuntimeError('Native menu did not confirm selected item')


class ComboItems:
    def __init__(self, combo):self.combo=combo
    def labels(self):return [self.combo.itemText(i) for i in range(self.combo.count())]
    def current(self):return self.combo.currentIndex()
    def choose(self,i):
        self.combo.setCurrentIndex(i)
        if self.combo.currentIndex()!=i:raise RuntimeError('Native combo selection mismatch')


def qt_items():
    try:from PySide2 import QtWidgets
    except ImportError:from PySide6 import QtWidgets
    items=[]
    for w in QtWidgets.QApplication.allWidgets():
        if isinstance(w, QtWidgets.QComboBox) and w.isVisible():items.append(ComboItems(w))
        elif isinstance(w, QtWidgets.QMenu):
            # Menus can remain hidden while the native selector is visible.
            if w.actions():items.append(MenuItems(w))
    return items


def find_id(items, expected):
    matches=[]
    for item in items:
        slots=id_slots(item.labels(),expected)
        if slots is not None and item.current()>=0:matches.append((item,slots))
    exact=[m for m in matches if set(m[1])==set(expected)|{0}]
    matches=exact or matches
    if len(matches)!=1:
        combos=sum(isinstance(i,ComboItems) for i in items)
        checked=sum(isinstance(i,MenuItems) and i.current()>=0 for i in items)
        raise RuntimeError('Native ID UI matches=%d; expected=%s; combos=%d checked-menus=%d' % (len(matches),sorted(expected)[:24],combos,checked))
    return matches[0]


def find_maps(items, names, native_current):
    matches=[]
    for item in items:
        selected=item.current()
        if selected<0:continue
        offset=native_current-selected
        if offset not in (0,1):continue
        mapping=[0]*len(names)
        valid=True
        for index,label in enumerate(item.labels()):
            candidates=[i for i,name in enumerate(names) if name and
                        (label.lower()==name.lower() or
                         (label.lower().startswith(name.lower()) and len(label)>len(name) and not label[len(name)].isalnum()))]
            if len(candidates)>1:valid=False;break
            if candidates:
                target=candidates[0]
                if mapping[target] or index+offset<1:valid=False;break
                mapping[target]=index+offset
        if valid and any(mapping):matches.append(mapping)
    if len(matches)!=1:raise RuntimeError('Native texture UI matches=%d; background preserved' % len(matches))
    return matches[0]


def run_host():
    from pymxs import runtime as rt
    rt.lsyUVNativeResult=rt.undefined
    rt.lsyUVNativeError=''
    try:
        items=qt_items()
        if str(rt.lsyUVNativeOperation)=='maps':
            result=find_maps(items,[str(n) for n in rt.lsyUVNativeNames],int(rt.lsyUVMod.getCurrentMap()))
        else:
            item,slots=find_id(items,[int(i) for i in rt.lsyUVNativeIDs])
            target=int(rt.lsyUVNativeTarget)
            before=item.current()
            old_id=next(k for k,v in slots.items() if v==before)
            if target not in slots:raise RuntimeError('Requested ID absent from native UI')
            if str(rt.lsyUVNativeOperation)=='select_id':
                try:
                    rt.lsyUVMod.setMatID(slots[target]+1)
                    if int(rt.lsyUVMod.getMatID())!=slots[target]+1 or item.current()!=slots[target]:
                        raise RuntimeError('Native ID index/UI selection mismatch')
                except Exception:
                    rt.lsyUVMod.setMatID(before+1)
                    raise
            result=[old_id,int(rt.lsyUVMod.getMatID()),target]
        rt.lsyUVNativeResult=rt.Array(*result)
    except Exception as exc:
        rt.lsyUVNativeError=str(exc)
        try:
            rt.lsyUVNativeError += '; filter=%d auto=%s maps=%d texture-list=%d current-map=%d' % (
                int(rt.lsyUVMod.getMatID()), bool(rt.lsyUVMod.getAutoBackground()),
                int(rt.lsyUVMod.numberMaps()), len(rt.lsyUVNativeNames),
                int(rt.lsyUVMod.getCurrentMap()))
        except Exception:
            pass
