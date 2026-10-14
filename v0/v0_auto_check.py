"""Run read-only V0 checks in ordinary Python or the 3ds Max Python editor."""

import json
import math
import os
from pathlib import Path
import runpy
import tempfile
from datetime import datetime, timezone


def check_uv(rt):
    """Read every UV position; never change the scene or infer drag readiness."""
    if rt.selection.count != 1:
        raise ValueError("Select exactly one object with one Unwrap UVW modifier")
    node = rt.selection[0]
    modifiers = [m for m in node.modifiers if rt.classOf(m) == rt.Unwrap_UVW]
    if len(modifiers) != 1:
        raise ValueError("Expected exactly one Unwrap UVW; ambiguous stacks are unsupported")
    modifier = modifiers[0]
    count = int(modifier.numberVerticesByNode(node))
    faces = int(modifier.numberPolygonsByNode(node))
    if count <= 0 or faces <= 0:
        raise ValueError("Expected nonempty UV vertices and faces")
    for index in range(1, count + 1):
        point = modifier.getVertexPosition(rt.currentTime, index)
        if not all(math.isfinite(float(value)) for value in (point.x, point.y, point.z)):
            raise ValueError("Nonfinite UV coordinate at vertex {}".format(index))
    return {"uv_vertices": count, "uv_faces": faces,
            "raw_map_channel": int(modifier.getMapChannel()),
            "vertex_color": bool(modifier.getVC())}


def run_checks():
    root = Path(__file__).resolve().parent
    checks = []
    try:
        runpy.run_path(str(root / "v0_math_probe.py"), run_name="__main__")
        checks.append({"name": "P4 math", "status": "PASS"})
    except Exception as exc:
        checks.append({"name": "P4 math", "status": "FAIL", "detail": str(exc)})

    runtime = runpy.run_path(str(root / "v0_runtime_probe.py"))["collect"]()
    # Keep machine paths, asset names, and texture paths out of the report.
    runtime = {key: runtime[key] for key in
               ("python", "platform", "max", "qt_binding", "qt_version", "errors")}
    try:
        from pymxs import runtime as rt
    except ImportError:
        checks.append({"name": "P0 UV coordinate read", "status": "NOT RUN",
                       "detail": "Run this file inside 3ds Max Python Editor"})
    else:
        try:
            checks.append({"name": "P0 UV coordinate read", "status": "PASS",
                           "data": check_uv(rt)})
        except Exception as exc:
            checks.append({"name": "P0 UV coordinate read", "status": "FAIL",
                           "detail": str(exc)})
    checks.append({"name": "Native gizmo / mouse drag / Undo / Redo / viewport",
                   "status": "NOT RUN", "detail": "Requires interactive host validation"})
    return {"captured_at_utc": datetime.now(timezone.utc).isoformat(),
            "runtime": runtime, "checks": checks}


def main():
    report = run_checks()
    directory = Path(os.environ.get("LSY_V0_REPORT_DIR") or tempfile.gettempdir())
    directory.mkdir(parents=True, exist_ok=True)
    # A unique filename preserves previous runs.
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".json",
                                     prefix="LSY_UV_V0_auto_", dir=str(directory),
                                     delete=False) as stream:
        json.dump(report, stream, ensure_ascii=False, indent=2)
        path = stream.name
    for check in report["checks"]:
        print("{}: {}".format(check["status"], check["name"]))
        if "detail" in check:
            print("  " + check["detail"])
    print("Report: " + path)
    return 1 if any(c["status"] == "FAIL" for c in report["checks"]) else 0


if __name__ == "__main__":
    status = main()
    if status:
        raise SystemExit(status)
