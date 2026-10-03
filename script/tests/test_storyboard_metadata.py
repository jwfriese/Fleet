import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "Fleet/Script/copy_storyboard_info_files.sh"


class StoryboardMetadataTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="fleet storyboard tests ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.intermediates = self.root / "Intermediate builds" / "Host App.build"
        self.intermediates.mkdir(parents=True)
        self.env = {**os.environ, "TARGET_BUILD_DIR": str(self.root / "Built products"),
                    "CONTENTS_FOLDER_PATH": "Hosted Tests.xctest",
                    "TEST_HOST": str(self.root / "Host App.app" / "Host App"),
                    "CONFIGURATION_TEMP_DIR": str(self.intermediates.parent)}
        self.destination = Path(self.env["TARGET_BUILD_DIR"]) / self.env["CONTENTS_FOLDER_PATH"] / "StoryboardInfo"
        self.destination.mkdir(parents=True)
        (self.destination / "previous.plist").write_text("previous metadata")

    def storyboard(self, name="Main", parent=None, content="compiled metadata"):
        folder = (parent or self.intermediates) / (name + ".storyboardc")
        folder.mkdir(parents=True)
        if content is not None:
            (folder / "Info.plist").write_text(content)
        return folder

    def run_script(self, *args):
        return subprocess.run([str(SCRIPT), *args], env=self.env, capture_output=True, text=True)

    def assert_preserved(self):
        self.assertEqual(list(self.destination.iterdir()), [self.destination / "previous.plist"])
        self.assertEqual((self.destination / "previous.plist").read_text(), "previous metadata")
        self.assertEqual(list(self.destination.parent.glob(".fleet-storyboard-*")), [])

    def test_copies_nested_metadata_with_spaces_dots_and_newlines_and_replaces_old_output(self):
        names = ["Main Storyboard", "Settings.v2", "Odd\nName", "A [B] $C"]
        for name in names:
            self.storyboard(name, self.intermediates / "Base.lproj", content=name)
        result = self.run_script("ignored legacy target argument")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual({path.name for path in self.destination.iterdir()}, set(names))
        for name in names:
            self.assertEqual((self.destination / name / "Info.plist").read_text(), name)
        self.assertEqual(list(self.destination.parent.glob(".fleet-storyboard-*")), [])

    def test_missing_build_variables_fail_without_removing_previous_output(self):
        self.storyboard()
        for name in ("TARGET_BUILD_DIR", "CONTENTS_FOLDER_PATH", "TEST_HOST", "CONFIGURATION_TEMP_DIR"):
            with self.subTest(variable=name):
                value = self.env.pop(name)
                try:
                    result = self.run_script()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(name, result.stderr)
                    self.assert_preserved()
                finally:
                    self.env[name] = value

    def test_missing_host_intermediates_fail_without_removing_previous_output(self):
        self.env["TEST_HOST"] = str(self.root / "Missing.app" / "Missing")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing.build", result.stderr)
        self.assert_preserved()

    def test_no_compiled_storyboards_fail_without_removing_previous_output(self):
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No compiled storyboards", result.stderr)
        self.assert_preserved()

    def test_missing_info_plist_fails_without_removing_previous_output(self):
        self.storyboard("Valid")
        self.storyboard("Missing Info", content=None)
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Info.plist", result.stderr)
        self.assert_preserved()

    def test_conflicting_names_fail_instead_of_overwriting_metadata(self):
        self.storyboard("Shared", self.intermediates / "One", "one")
        self.storyboard("Shared", self.intermediates / "Two", "two")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Conflicting storyboard metadata", result.stderr)
        self.assert_preserved()

    def test_identical_metadata_in_localizations_can_share_a_name(self):
        self.storyboard("Main", self.intermediates / "Base.lproj")
        self.storyboard("Main", self.intermediates / "fr.lproj")
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(list(self.destination.iterdir()), [self.destination / "Main"])

    def test_discovery_and_copy_failures_propagate_and_preserve_previous_output(self):
        self.storyboard()
        fake_bin = self.root / "fake bin"
        fake_bin.mkdir()
        self.env["PATH"] = str(fake_bin) + os.pathsep + os.environ["PATH"]
        for command in ("find", "cp"):
            with self.subTest(command=command):
                fake = fake_bin / command
                fake.write_text("#!/bin/sh\nprintf 'injected failure\\n' >&2\nexit 42\n")
                fake.chmod(0o755)
                try:
                    result = self.run_script()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("injected failure", result.stderr)
                    self.assert_preserved()
                finally:
                    fake.unlink()

    def test_replacement_failure_restores_previous_output(self):
        self.storyboard()
        fake_bin = self.root / "fake bin"
        fake_bin.mkdir()
        fake = fake_bin / "mv"
        fake.write_text('#!/bin/sh\ncase "$1" in */metadata) printf "injected replacement failure\\n" >&2; exit 42;; esac\nexec /bin/mv "$@"\n')
        fake.chmod(0o755)
        self.env["PATH"] = str(fake_bin) + os.pathsep + os.environ["PATH"]
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("injected replacement failure", result.stderr)
        self.assert_preserved()

    def test_unsafe_bundle_paths_and_symlink_destination_fail_without_touching_output(self):
        self.storyboard()
        original = self.env["CONTENTS_FOLDER_PATH"]
        for path in ("/", ".", "..", "../Elsewhere", "Tests/../../Elsewhere"):
            with self.subTest(path=path):
                self.env["CONTENTS_FOLDER_PATH"] = path
                result = self.run_script()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("CONTENTS_FOLDER_PATH", result.stderr)
                self.assert_preserved()
        self.env["CONTENTS_FOLDER_PATH"] = original
        other = self.root / "unrelated metadata"
        self.destination.rename(other)
        self.destination.symlink_to(other, target_is_directory=True)
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("StoryboardInfo", result.stderr)
        self.assertTrue(self.destination.is_symlink())
        self.assertEqual((other / "previous.plist").read_text(), "previous metadata")


if __name__ == "__main__":
    unittest.main()
