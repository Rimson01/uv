"""Build the standalone UTF-8 BOM MAXScript export without changing sources."""
import argparse
import importlib.util
from pathlib import Path


def build(output):
    root = Path(__file__).resolve().parent
    spec = importlib.util.spec_from_file_location("edit_math", root / "edit_math.py")
    core = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(core)
    source = (root / "LSY_UV_Workbench.ms").read_text()
    _, remainder = source.split("-- BEGIN SHARED EDIT MATH\n", 1)
    old, _ = remainder.split("-- END SHARED EDIT MATH", 1)
    if old != core.emit_maxscript():
        raise ValueError("Embedded arithmetic differs from tested definitions; regenerate source first")
    analysis = source.split("-- BEGIN ISLAND ANALYSIS\n", 1)[1].split("-- END ISLAND ANALYSIS", 1)[0]
    if analysis != (root / "island_analysis.ms").read_text():
        raise ValueError("Embedded island analysis differs from canonical helper")
    import json
    import re
    ui = source.split("-- BEGIN NATIVE UI SESSION", 1)[1].split("-- END NATIVE UI SESSION", 1)[0]
    literal = re.search(r'python.Execute ("(?:\\.|[^"\\])*")', ui).group(1)
    if json.loads(literal) != (root / "qt_native_ui.py").read_text() + "\nrun_host()\n":
        raise ValueError("Embedded native UI session differs from canonical Python helper")
    legacy_ui = source.split("-- BEGIN QT FILTER BRIDGE", 1)[1].split("-- END QT FILTER BRIDGE", 1)[0]
    legacy_literal = re.search(r'python.Execute ("(?:\\.|[^"\\])*")', legacy_ui).group(1)
    if json.loads(legacy_literal) != (root / "qt_filter_bridge.py").read_text() + "\nrun_host()\n":
        raise ValueError("Embedded legacy Qt helper differs from canonical Python helper")
    bridge = source.split("-- BEGIN NATIVE FILTER BRIDGE", 1)[1].split("-- END NATIVE FILTER BRIDGE", 1)[0]
    bridge_literal = re.search(r'sources.SetValue ("(?:\\.|[^"\\])*")', bridge).group(1)
    if json.loads(bridge_literal) != (root / "native_filter_bridge.cs").read_text():
        raise ValueError("Embedded native bridge differs from canonical C# helper")
    repair = source.split("-- BEGIN REPAIR COMMANDS\n", 1)[1].split("-- END REPAIR COMMANDS", 1)[0]
    if repair != (root / "repair_ops.ms").read_text():
        raise ValueError("Embedded repair commands differ from canonical source")
    math_block = source.split("-- BEGIN REPAIR MATH", 1)[1].split("-- END REPAIR MATH", 1)[0]
    math_literal = re.search(r'python.Execute ("(?:\\.|[^"\\])*")', math_block).group(1)
    if json.loads(math_literal) != (root / "repair_math.py").read_text() + "\nrun_host()\n":
        raise ValueError("Embedded repair math differs from tested Python")
    if output.exists():
        raise FileExistsError("Preserve existing exports: " + str(output))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(source, encoding="utf-8-sig")
    if output.read_text(encoding="utf-8-sig") != source:
        raise RuntimeError("Export roundtrip failed")
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    print(build(parser.parse_args().output))
