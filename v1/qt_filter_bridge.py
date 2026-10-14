"""Find the native Qt Material ID dropdown without changing scene selection."""
import re


def parse_id_label(label):
    # Read a numeric ID field, never a number embedded in a texture filename.
    match = re.match(r'^\s*(?:(?:material|mat)?\s*id\s*[:#]?\s*)?(\d+)(?:\s*$|\s*[-:(\[]\s*[^.]*$)', label, re.I)
    return int(match.group(1)) if match else None


def find_filter(widgets, ids):
    expected = set(ids)
    matches = []
    sizes = []
    for widget in widgets:
        if not widget.isVisible():
            continue
        sizes.append(widget.count())
        if widget.count() < len(expected)+1:
            continue
        slots = {}
        specials = 0
        for i in range(widget.count()):
            label = widget.itemText(i)
            value = parse_id_label(label)
            if value is None:
                if not re.search(r'\d|[./\\]',label):
                    specials += 1
                    continue
                break
            if value == 0:
                specials += 1
                continue
            if value in slots:
                break
            slots[value] = i
        else:
            # The native list may contain unused material IDs as well.
            if specials == 1 and expected.issubset(slots):
                matches.append((widget, slots))
    exact = [entry for entry in matches if set(entry[1]) == expected]
    if exact:
        matches = exact
    if len(matches) != 1:
        raise RuntimeError('Qt ID matches=%d; expected=%s; visible combo counts=%s; total combos=%d; current filter preserved' %
                           (len(matches), sorted(expected), sizes[:30], len(widgets)))
    return matches[0]


def read_host_mapping():
    from pymxs import runtime as rt
    try:
        from PySide2 import QtWidgets
    except ImportError:
        from PySide6 import QtWidgets
    ids = [int(i) for i in rt.lsyUVQtIDs]
    target = int(rt.lsyUVQtTarget)
    widgets = []
    for w in QtWidgets.QApplication.allWidgets():
        if isinstance(w, QtWidgets.QComboBox):
            widgets.append(w)
        elif w.inherits('QComboBox'):
            # Some C++ Max widgets are exposed initially as generic QWidget wrappers.
            try:
                try:
                    from shiboken2 import getCppPointer, wrapInstance
                except ImportError:
                    from shiboken6 import getCppPointer, wrapInstance
                widgets.append(wrapInstance(getCppPointer(w)[0], QtWidgets.QComboBox))
            except (TypeError, RuntimeError):
                pass
    widget, slots = find_filter(widgets, ids)
    selected = widget.currentIndex()
    native = int(rt.lsyUVMod.getMatID())
    offset = native-selected
    if offset not in (0,1):
        raise RuntimeError('Qt/native Material ID index mismatch; current filter preserved')
    rt.lsyUVQtMapping = rt.Array(slots[target]+offset, selected, slots[target])


# Executed only inside Max; importing for CPU tests has no host side effects.
def run_host():
    from pymxs import runtime as rt
    rt.lsyUVQtMapping = rt.undefined
    rt.lsyUVQtError = ''
    try:
        read_host_mapping()
    except Exception as exc:
        rt.lsyUVQtError = str(exc)
        try:
            rt.lsyUVQtError += '; native IDs=%d current=%d' % (int(rt.lsyUVMod.numberMatIDs()), int(rt.lsyUVMod.getMatID()))
        except Exception:
            pass
