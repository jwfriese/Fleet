import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "script"))
import check_distribution as checker


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="fleet external consumers ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "source repo"
        self.root.mkdir()
        (self.root / "Package.swift").write_text("// fixture manifest\n")
        (self.root / "LICENSE").write_text("fixture license\n")
        (self.root / "Fleet").mkdir()
        (self.root / "Fleet/Example.swift").write_text("// fixture source\n")
        (self.root / ".gitignore").write_text("build/\n")
        shutil.copytree(REPO / "Integration/PackageConsumer", self.root / "Integration/PackageConsumer")
        checker.git(self.root, "init", "-q")
        checker.git(self.root, "add", ".")
        checker.git(self.root, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                    "-c", "commit.gpgsign=false", "commit", "-qm", "Fixture")
        fake_bin = Path(self.temp.name) / "bin"
        fake_bin.mkdir()
        fake = fake_bin / "xcodebuild"
        fake.write_text('''#!/usr/bin/env python3
import json, os, pathlib, plistlib, sys
project = pathlib.Path(sys.argv[sys.argv.index('-project') + 1])
if '-resolvePackageDependencies' in sys.argv:
    data = plistlib.loads((project / 'project.pbxproj').read_bytes())
    dependency = next(o for o in data['objects'].values() if o['isa'] == 'XCRemoteSwiftPackageReference')
    revision = dependency['requirement']['revision']
    if os.environ.get('FLEET_FAKE_WRONG_PIN'):
        revision = '0' * 40
    lock = project / 'project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
    lock.parent.mkdir(parents=True, exist_ok=True)
    lock.write_text(json.dumps({'pins': [{'state': {'revision': revision}}]}))
else:
    print(os.environ.get('FLEET_FAKE_TEST_OUTPUT', 'Executed 8 tests, with 0 failures\\n** TEST SUCCEEDED **'))
    sys.exit(int(os.environ.get('FLEET_FAKE_TEST_EXIT', '0')))
''')
        fake.chmod(0o755)
        self.environment = {"PATH": str(fake_bin) + os.pathsep + os.environ["PATH"],
                            "FLEET_TEST_DESTINATION": "id=consumer-fixture"}

    def check(self, allow_dirty=False):
        with patch.dict(os.environ, self.environment), contextlib.redirect_stdout(io.StringIO()):
            checker.check(self.root, "ios", allow_dirty)

    def evidence(self):
        return list((self.root / "build").glob("distribution-*/validation.json"))

    def test_clean_consumer_pins_and_reports_the_exact_source_revision(self):
        self.check()
        evidence = json.loads(self.evidence()[0].read_text())
        revision = checker.git(self.root, "rev-parse", "HEAD")
        self.assertEqual(evidence["source_commit"], revision)
        self.assertEqual(evidence["package_revision"], revision)
        self.assertEqual(evidence["tests"], {"ios": 8})
        self.assertFalse(evidence["development_snapshot"])

    def test_dirty_checkout_is_rejected_before_running_consumers(self):
        (self.root / "Fleet/Example.swift").write_text("// changed\n")
        with self.assertRaisesRegex(checker.DistributionError, "Commit the checkout"):
            self.check()
        self.assertFalse((self.root / "build").exists())

    def test_development_snapshot_records_its_distinct_git_revision(self):
        (self.root / "Fleet/Example.swift").write_text("// changed\n")
        self.check(allow_dirty=True)
        evidence = json.loads(self.evidence()[0].read_text())
        self.assertTrue(evidence["development_snapshot"])
        self.assertNotEqual(evidence["source_commit"], evidence["package_revision"])

    def test_wrong_resolved_revision_prevents_consumer_execution(self):
        self.environment["FLEET_FAKE_WRONG_PIN"] = "1"
        with self.assertRaisesRegex(checker.DistributionError, "exact package revision"):
            self.check()
        self.assertEqual(self.evidence(), [])

    def test_failed_consumer_command_cannot_produce_evidence(self):
        self.environment["FLEET_FAKE_TEST_EXIT"] = "65"
        with self.assertRaisesRegex(checker.DistributionError, "failed \\(65\\)"):
            self.check()
        self.assertEqual(self.evidence(), [])

    def test_empty_failed_or_incomplete_test_output_cannot_produce_evidence(self):
        for output in ("** TEST SUCCEEDED **", "Executed 0 tests, with 0 failures\n** TEST SUCCEEDED **",
                       "Executed 8 tests, with 1 failure\n** TEST SUCCEEDED **",
                       "Executed 8 tests, with 0 failures"):
            with self.subTest(output=output):
                self.environment["FLEET_FAKE_TEST_OUTPUT"] = output
                with self.assertRaisesRegex(checker.DistributionError, "nonempty test suite"):
                    self.check()
                self.assertEqual(self.evidence(), [])


if __name__ == "__main__":
    unittest.main()
