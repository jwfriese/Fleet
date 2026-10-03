import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("select_simulator", REPO / "script/select-simulator.py")
selector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selector)


class SimulatorSelectionTests(unittest.TestCase):
    def device(self, identifier, name="iPhone", state="Shutdown", available=True):
        return {"udid": identifier, "name": name, "state": state, "isAvailable": available}

    def test_selects_latest_compatible_runtime_and_prefers_booted_phone(self):
        devices = {
            "com.apple.CoreSimulator.SimRuntime.iOS-18-5": [self.device("old", state="Booted")],
            "com.apple.CoreSimulator.SimRuntime.iOS-26-4": [self.device("new"), self.device("booted", state="Booted"), self.device("tablet", "iPad", "Booted")],
            "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [self.device("too-new")],
            "com.apple.CoreSimulator.SimRuntime.tvOS-26-4": [self.device("tv", "Apple TV")],
        }
        self.assertEqual(selector.select_device(devices, "ios", "26.5"), "booted")
        self.assertEqual(selector.select_device(devices, "tvos", "26.5"), "tv")

    def test_rejects_unavailable_devices_and_missing_platform(self):
        devices = {"com.apple.CoreSimulator.SimRuntime.iOS-26-4": [self.device("unavailable", available=False)]}
        with self.assertRaisesRegex(ValueError, "No available ios simulator"):
            selector.select_device(devices, "ios", "26.5")
        with self.assertRaisesRegex(ValueError, "No available tvos simulator"):
            selector.select_device(devices, "tvos", "26.5")


class TestCommandTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="fleet runner tests ")
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.arguments = root / "arguments.json"
        fake = root / "xcodebuild"
        fake.write_text("#!/usr/bin/env python3\nimport json, os, sys\n"
                        "if sys.argv[1:] == ['-version']:\n    print('Xcode test fixture')\n    sys.exit(0)\n"
                        "with open(os.environ['FLEET_TEST_ARGUMENTS'], 'w') as output:\n    json.dump(sys.argv[1:], output)\n"
                        "print('test output')\nsys.exit(int(os.environ.get('FLEET_FAKE_EXIT', '0')))\n")
        fake.chmod(0o755)
        self.env = {**os.environ, "PATH": str(root) + os.pathsep + os.environ["PATH"],
                    "FLEET_TEST_ARGUMENTS": str(self.arguments), "FLEET_BUILD_DIR": str(root / "build output"),
                    "FLEET_TEST_DESTINATION": "platform=iOS Simulator,id=fixture"}

    def run_script(self, *args):
        return subprocess.run(["bash", str(REPO / "script/test"), *args], env=self.env,
                              capture_output=True, text=True)

    def test_runs_selected_scheme_preserves_arguments_and_retains_log(self):
        result = self.run_script("ios", "-only-testing:FleetTests/Some Test")
        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = json.loads(self.arguments.read_text())
        self.assertEqual(arguments[0], "test")
        self.assertEqual(arguments[arguments.index("-scheme") + 1], "Fleet")
        self.assertIn("-only-testing:FleetTests/Some Test", arguments)
        self.assertEqual(arguments[arguments.index("-parallel-testing-enabled") + 1], "NO")
        self.assertIn("-onlyUsePackageVersionsFromResolvedFile", arguments)
        self.assertEqual(arguments[arguments.index("-test-timeouts-enabled") + 1], "YES")
        self.assertEqual(arguments[arguments.index("-default-test-execution-time-allowance") + 1], "30")
        logs = list(Path(self.env["FLEET_BUILD_DIR"]).glob("*/xcodebuild.log"))
        self.assertEqual(len(logs), 1)
        self.assertIn("test output", logs[0].read_text())

    def test_returns_xcodebuild_failure_even_when_tee_succeeds(self):
        self.env["FLEET_FAKE_EXIT"] = "65"
        result = self.run_script()
        self.assertEqual(result.returncode, 65)
        self.assertIn("xcodebuild failed (65)", result.stderr)

    def test_selects_tvos_and_rejects_ambiguous_destination(self):
        result = self.run_script("tvos")
        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = json.loads(self.arguments.read_text())
        self.assertEqual(arguments[arguments.index("-scheme") + 1], "Fleet-tvOS")
        self.assertEqual(self.run_script("all").returncode, 2)
        self.assertEqual(self.run_script("unknown").returncode, 2)


if __name__ == "__main__":
    unittest.main()
