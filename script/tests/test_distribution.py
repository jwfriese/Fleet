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
    revisions = [o['requirement']['revision'] for o in data['objects'].values() if o['isa'] == 'XCRemoteSwiftPackageReference']
    if os.environ.get('FLEET_FAKE_WRONG_PIN'):
        revisions = ['0' * 40]
    lock = project / 'project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
    lock.parent.mkdir(parents=True, exist_ok=True)
    lock.write_text(json.dumps({'pins': [{'state': {'revision': r}} for r in revisions]}))
else:
    out = os.environ.get('TEST_RUNNER_FLEET_TRACE_OUT')
    if out:
        scheme = sys.argv[sys.argv.index('-scheme') + 1]
        policy = os.environ.get('TEST_RUNNER_FLEET_HOSTING_POLICY', 'legacy')
        animated = 'false' if policy == 'legacy' and not scheme.startswith('Baseline') else 'true'
        loaded = 'true' if animated == 'false' else 'false'
        trace = ['offscreen.hiddenViewLoaded=' + loaded, 'push.returned', 'delegate.didShow(detail, animated: ' + animated + ')',
                 'pop.returned', 'present.completion', 'dismiss.completion']
        if os.environ.get('FLEET_FAKE_TRACE_DRIFT') and policy == 'preserve-timing':
            trace.reverse()
        name = 'baseline' if scheme.startswith('Baseline') else policy
        pathlib.Path(out, name + '.json').write_text(json.dumps(trace))
    print(os.environ.get('FLEET_FAKE_TEST_OUTPUT', 'Executed 8 tests, with 0 failures\\n** TEST SUCCEEDED **'))
    sys.exit(int(os.environ.get('FLEET_FAKE_TEST_EXIT', '0')))
''')
        fake.chmod(0o755)
        self.environment = {"PATH": str(fake_bin) + os.pathsep + os.environ["PATH"],
                            "FLEET_TEST_DESTINATION": "id=consumer-fixture"}

    def check(self, allow_dirty=False, viewinspector=False):
        with patch.dict(os.environ, self.environment), contextlib.redirect_stdout(io.StringIO()):
            checker.check(self.root, "ios", allow_dirty, viewinspector)

    def inspector_log(self, skip_suite=None, skip_test=None, skip_xctest=None, run_total=12, status="passed"):
        swift_testing, xctest = checker.required_inspector_suites(self.root)
        lines = ["Executed 8 tests, with 0 failures"]
        for title, tests in swift_testing.items():
            if title != skip_suite:
                lines += [f"\u2714 Test {t}() passed after 0.1 seconds." for t in tests if t != skip_test]
                lines.append(f'\u2714 Suite "{title}" passed after 0.1 seconds.')
        for cls, tests in xctest.items():
            lines += [f"Test Case '-[Consumer.{cls} {t}]' passed (0.1 seconds)." for t in tests if t != skip_xctest]
        lines += [f"\u2714 Test run with {run_total} tests in 3 suites {status} after 0.5 seconds.", "** TEST SUCCEEDED **"]
        return "\n".join(lines)

    def evidence(self):
        return list((self.root / "build").glob("distribution-*/validation.json"))

    def test_clean_consumer_pins_and_reports_the_exact_source_revision(self):
        self.check()
        evidence = json.loads(self.evidence()[0].read_text())
        revision = checker.git(self.root, "rev-parse", "HEAD")
        self.assertEqual(evidence["source_commit"], revision)
        self.assertEqual(evidence["package_revision"], revision)
        self.assertEqual(evidence["tests"], {"ios": 8})
        self.assertEqual(evidence["preserve_timing_tests"], {"ios": 8})
        self.assertFalse(evidence["development_snapshot"])

    def test_macos_only_receipt_omits_integrations_it_did_not_resolve(self):
        with patch.dict(os.environ, self.environment), contextlib.redirect_stdout(io.StringIO()), \
                patch.object(checker, "check_macos", return_value=({"xctest": 10, "swift_testing": 4}, {})):
            checker.check(self.root, "macos", False, True, True)
        evidence = json.loads(self.evidence()[0].read_text())
        revision = checker.git(self.root, "rev-parse", "HEAD")
        self.assertEqual(evidence["products"], ["FleetMacOS"])
        self.assertEqual(evidence["optional_integrations"], [])
        self.assertEqual(evidence["resolved_revisions"], {"fleet": revision})
        self.assertIsNone(evidence["viewinspector_revision"])
        self.assertIsNone(evidence["snapshottesting_revision"])
        self.assertEqual(evidence["framework_results"], {})

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

    def test_preserve_timing_trace_differing_from_the_baseline_cannot_produce_evidence(self):
        self.environment["FLEET_FAKE_TRACE_DRIFT"] = "1"
        with self.assertRaisesRegex(checker.DistributionError, "differs from the no-Fleet baseline"):
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

    def test_viewinspector_run_records_each_framework_and_the_integration(self):
        self.environment["FLEET_FAKE_TEST_OUTPUT"] = self.inspector_log()
        self.check(viewinspector=True)
        evidence = json.loads(self.evidence()[0].read_text())
        self.assertEqual(evidence["optional_integrations"], ["viewinspector"])
        self.assertEqual(evidence["resolved_revisions"]["viewinspector"], checker.VIEWINSPECTOR_REVISION)
        recorded = evidence["framework_results"]["ios"]["legacy"]
        self.assertEqual(recorded["xctest"], {"tests": 8, "failures": 0})
        self.assertEqual(recorded["swift_testing"]["tests"], 12)
        self.assertIn("Row-scoped ViewInspector queries (Swift Testing)", recorded["swift_testing_suites"])

    def test_missing_filtered_or_empty_integration_suites_cannot_produce_evidence(self):
        swift_testing, xctest = checker.required_inspector_suites(self.root)
        suite = "Row-scoped ViewInspector queries (Swift Testing)"
        cases = {
            "suite absent": (self.inspector_log(skip_suite=suite), "Swift Testing suite did not run"),
            "test filtered out": (self.inspector_log(skip_test=swift_testing[suite][0]), "Swift Testing test did not run"),
            "xctest filtered out": (self.inspector_log(skip_xctest=next(iter(xctest.values()))[0]), "XCTest did not run"),
            "zero swift tests": ("Executed 8 tests, with 0 failures\n** TEST SUCCEEDED **", "Swift Testing suite did not run"),
            "summary too small": (self.inspector_log(run_total=1), "smaller than the required suites"),
            "failed run": (self.inspector_log(status="failed"), "missing, failed or smaller"),
        }
        for name, (output, message) in cases.items():
            with self.subTest(name):
                self.environment["FLEET_FAKE_TEST_OUTPUT"] = output
                with self.assertRaisesRegex(checker.DistributionError, message):
                    self.check(viewinspector=True)
                self.assertEqual(self.evidence(), [])

    def test_skipped_test_summaries_report_the_aggregate_total(self):
        log = ("Executed 1 test, with 0 failures (0 unexpected)\n"
               "Executed 61 tests, with 1 test skipped and 0 failures (0 unexpected)\n"
               "Test run with 31 tests in 2 suites passed\n** TEST SUCCEEDED **")
        self.assertEqual(checker.successful_test_count(log), 61)
        self.assertEqual(checker.framework_results(log)["xctest"], {"tests": 61, "failures": 0})
        failing = "Executed 61 tests, with 1 test skipped and 2 failures (0 unexpected)\n** TEST SUCCEEDED **"
        with self.assertRaises(checker.DistributionError):
            checker.successful_test_count(failing)

    def test_required_suites_come_from_the_fixture_sources(self):
        swift_testing, xctest = checker.required_inspector_suites(REPO)
        self.assertEqual(len(swift_testing), 2)
        self.assertTrue(all(swift_testing.values()) and all(xctest.values()))


if __name__ == "__main__":
    unittest.main()


class MacOSFrameworkCountTests(unittest.TestCase):
    PASSED = ("Executed 10 tests, with 0 failures (0 unexpected)\n"
              "Test run with 4 tests in 1 suite passed after 0.5 seconds.\n** TEST SUCCEEDED **")

    def test_reports_actual_counts_per_framework(self):
        self.assertEqual(checker.framework_counts(self.PASSED), {"xctest": 10, "swift_testing": 4})

    def test_each_framework_must_run_a_nonempty_successful_suite(self):
        for output in ("** TEST SUCCEEDED **",
                       self.PASSED.replace("Test run with 4 tests in 1 suite passed", "Test run with 0 tests in 0 suites passed"),
                       self.PASSED.split("\n")[0] + "\n** TEST SUCCEEDED **",
                       self.PASSED.replace("Executed 10 tests", "Executed 0 tests"),
                       self.PASSED.replace("0 failures", "1 failure"),
                       self.PASSED.replace("passed after", "failed after"),
                       self.PASSED.replace("** TEST SUCCEEDED **", "")):
            with self.subTest(output=output), self.assertRaises(checker.DistributionError):
                checker.framework_counts(output)

    def test_macos_evidence_is_staged_under_paths_the_ci_upload_retains(self):
        import fnmatch
        run = Path(tempfile.mkdtemp(prefix="staging "))
        directory = run / "macos"
        (directory / "TestResults.xcresult").mkdir(parents=True)
        (directory / "TestResults.xcresult/Info.plist").write_text("bundle")
        for name in ("resolve.log", "xcodebuild.log", "Package.resolved", "link-graph.json"):
            (directory / name).write_text(name)
        checker.stage_macos_evidence(run, directory)
        staged = sorted(p.relative_to(run).as_posix() for p in (run / "ios").iterdir())
        self.assertEqual(staged, ["ios/macos-Package.resolved.log", "ios/macos-TestResults.xcresult",
                                  "ios/macos-link-graph.log", "ios/macos-resolve.log", "ios/macos-xcodebuild.log"])
        self.assertTrue((run / "ios/macos-TestResults.xcresult/Info.plist").is_file())
        self.assertTrue(all(fnmatch.fnmatch(p, "ios/*.log") or fnmatch.fnmatch(p, "ios/*.xcresult") for p in staged))
        # A failed run with only a log still stages what exists.
        partial = Path(tempfile.mkdtemp(prefix="staging "))
        (partial / "macos").mkdir()
        (partial / "macos/xcodebuild.log").write_text("x")
        checker.stage_macos_evidence(partial, partial / "macos")
        self.assertEqual([p.name for p in (partial / "ios").iterdir()], ["macos-xcodebuild.log"])

    def test_generated_macos_project_depends_only_on_the_fleetmacos_product(self):
        import plistlib
        from consumer_project import create_macos_project
        project = create_macos_project(Path(tempfile.mkdtemp(prefix="macos consumer ")) / "Consumer",
                                       REPO / "Integration/MacOSConsumer", "file:///package", "a" * 40)
        objects = plistlib.loads((project / "project.pbxproj").read_bytes())["objects"].values()
        products = [o["productName"] for o in objects if o["isa"] == "XCSwiftPackageProductDependency"]
        self.assertEqual(products, ["FleetMacOS"])
        settings = [o["buildSettings"] for o in objects if o["isa"] == "XCBuildConfiguration" and "SDKROOT" in o["buildSettings"]]
        self.assertTrue(all(s["SDKROOT"] == "macosx" and s["MACOSX_DEPLOYMENT_TARGET"] == "13.0" for s in settings))
        self.assertTrue((project / "xcshareddata/xcschemes/MacOSConsumer.xcscheme").is_file())
