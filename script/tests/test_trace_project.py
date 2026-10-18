import plistlib
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "script"))
from trace_project import create_project


class TraceProjectTests(unittest.TestCase):
    def test_generates_ui_test_targets_without_fleet_dependency(self):
        with tempfile.TemporaryDirectory() as directory:
            project = create_project(Path(directory) / "Trace", ROOT / "Integration/UIKitTraceHarness")
            plist = plistlib.loads((project / "project.pbxproj").read_bytes())
            types = [o["productType"] for o in plist["objects"].values() if o["isa"] == "PBXNativeTarget"]
            self.assertEqual(types.count("com.apple.product-type.bundle.ui-testing"), 2)
            self.assertFalse(any(o["isa"].startswith("XCRemoteSwiftPackage") for o in plist["objects"].values()))
            for platform in ("ios", "tvos"):
                self.assertTrue((project / f"xcshareddata/xcschemes/Trace-{platform}.xcscheme").is_file())


if __name__ == "__main__":
    unittest.main()
