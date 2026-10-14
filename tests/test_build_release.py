import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("build_release", ROOT / "v1/build_release.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class StandaloneBuild(unittest.TestCase):
    def test_export_has_bom_korean_ui_and_identical_source(self):
        with tempfile.TemporaryDirectory() as directory:
            output = builder.build(Path(directory) / "Workbench.ms")
            self.assertTrue(output.read_bytes().startswith(b"\xef\xbb\xbf"))
            text = output.read_text(encoding="utf-8-sig")
            self.assertIn("점 색상", text)
            self.assertEqual(text, (ROOT / "v1/LSY_UV_Workbench.ms").read_text())

    def test_preserves_existing_export(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "Workbench.ms"
            output.write_text("user file")
            with self.assertRaises(FileExistsError):
                builder.build(output)
            self.assertEqual(output.read_text(), "user file")


if __name__ == "__main__":
    unittest.main()
