"""V0 read-only runtime manifest. Run inside 3ds Max's Python editor."""

from __future__ import print_function

import importlib
import json
import os
import platform
import sys
import tempfile
from datetime import datetime


def collect():
    result = {
        "probe": "LSY UV Repair V0 runtime",
        "captured_at_local": datetime.now().isoformat(),
        "python": sys.version,
        "executable": sys.executable,
        "platform": platform.platform(),
        "max": None,
        "qt_binding": None,
        "qt_version": None,
        "errors": [],
    }
    try:
        import pymxs

        result["max"] = str(pymxs.runtime.maxVersion())
    except Exception as exc:
        result["errors"].append("pymxs/maxVersion: {}".format(exc))

    for binding in ("PySide6", "PySide2"):
        try:
            qt_core = importlib.import_module(binding + ".QtCore")
            result["qt_binding"] = binding
            result["qt_version"] = qt_core.qVersion()
            break
        except ImportError:
            continue
        except Exception as exc:
            result["errors"].append("{}: {}".format(binding, exc))
    if result["qt_binding"] is None:
        result["errors"].append("No usable PySide binding found")
    return result


def main():
    report_dir = os.environ.get("LSY_V0_REPORT_DIR") or tempfile.gettempdir()
    filename = "LSY_UV_V0_runtime.json"
    path = os.path.join(report_dir, filename)
    report = collect()
    with open(path, "w", encoding="utf-8") as stream:
        json.dump(report, stream, ensure_ascii=False, indent=2, sort_keys=True)
    print("LSY V0 runtime report: " + path)
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
