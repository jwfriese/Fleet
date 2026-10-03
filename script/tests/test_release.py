import contextlib
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).resolve().parents[1] / "release.py"
spec = importlib.util.spec_from_file_location("fleet_release", SOURCE)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="fleet release tests ")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for directory in ("Fleet.xcodeproj", "Fleet", "script/tests"):
            (self.root / directory).mkdir(parents=True)
        (self.root / ".gitignore").write_text("build/\n__pycache__/\n")
        (self.root / "Fleet.xcodeproj/project.pbxproj").write_text(
            "CURRENT_PROJECT_VERSION = 4.6.1;\nCURRENT_PROJECT_VERSION = 4.6.1;\n"
        )
        (self.root / "Fleet/Info.plist").write_bytes(plistlib.dumps({
            "CFBundleShortVersionString": "4.6.1", "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)"
        }))
        (self.root / "Fleet.podspec").write_text(
            's.version = "4.6.1"\ns.summary = "Historical 4.6.1 summary"\n'
        )
        # The fixture's unit check records that release validation actually ran it.
        (self.root / "script/tests/test_fixture.py").write_text(
            "import unittest\nfrom pathlib import Path\n"
            "class Fixture(unittest.TestCase):\n"
            "    def test_repository(self):\n"
            "        self.assertTrue(Path('Fleet/Info.plist').is_file())\n"
            "        Path('build/python-check-ran').write_text('executed')\n"
        )
        self.write_test_runner()
        self.git("init", "-b", "master")
        self.git("config", "user.name", "Release Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("remote", "add", "origin", "git@github.com:owner/Fleet.git")
        self.commit()
        self.git("tag", "4.6.1")
        self.network_calls = []

    def git(self, *args):
        return release.git(self.root, *args)

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-m", "Fixture snapshot")

    def write_test_runner(self, ios=251, tvos=121, status=0):
        script = self.root / "script/test"
        script.write_text(
            "#!/bin/bash\n"
            "[ \"$#\" = 1 ] && [ \"$1\" = all ] || exit 9\n"
            "echo 'Fleet: testing Fleet on id=fixture'\n"
            f"echo 'Executed {ios} tests, with 0 failures (0 unexpected)'\n"
            "echo '** TEST SUCCEEDED **'\n"
            "echo 'Fleet: testing Fleet-tvOS on id=fixture'\n"
            f"echo 'Executed {tvos} tests, with 0 failures (0 unexpected)'\n"
            "echo '** TEST SUCCEEDED **'\n"
            f"exit {status}\n"
        )
        script.chmod(0o755)

    def prepared(self, packaging=False):
        with contextlib.redirect_stdout(io.StringIO()):
            release.prepare(self.root, "5.0.0")
        notes = self.root / "CHANGELOG.md"
        notes.write_text(notes.read_text().replace(
            "TODO: Describe changes, compatibility requirements, and migration steps.",
            "Restore modern development tooling."))
        if packaging:
            # Stubs exercise release orchestration; they are not consumer coverage.
            (self.root / "Package.swift").write_text("// Consumer fixture manifest\n")
            checker = self.root / "script/check-distribution"
            checker.write_text("#!/bin/bash\nexit 0\n")
            checker.chmod(0o755)
        self.commit()

    def checked(self):
        self.prepared(packaging=True)
        with contextlib.redirect_stdout(io.StringIO()):
            release.check(self.root, "5.0.0")
        return release.head(self.root)

    def fake_network(self, runs=None, jobs=None, tag_commit=None, releases=None, create_failure=False):
        original = release.run
        commit = release.head(self.root)
        if runs is None:
            runs = [{"databaseId": 42, "headSha": commit, "headBranch": "master", "event": "push",
                     "status": "completed", "conclusion": "success", "createdAt": "2026-10-02T00:00:00Z"}]
        if jobs is None:
            jobs = [{"name": f"{platform} on Xcode 26.6", "status": "completed", "conclusion": "success",
                     "steps": [{"name": "Run simulator tests", "status": "completed", "conclusion": "success"}]}
                    for platform in ("ios", "tvos")]

        def fake(root, *args, input_text=None):
            if args[:2] == ("git", "ls-remote"):
                self.network_calls.append(args)
                refs = f"{commit}\trefs/heads/master\n"
                if tag_commit:
                    refs += f"{tag_commit}\trefs/tags/5.0.0\n"
                return refs
            if args[:2] == ("git", "push"):
                self.network_calls.append(args)
                return ""
            if args[0] == "gh":
                self.network_calls.append(args)
                if args[1:3] == ("run", "list"):
                    return json.dumps(runs)
                if args[1:3] == ("run", "view"):
                    return json.dumps({"jobs": jobs})
                if args[1:3] == ("release", "list"):
                    return json.dumps(releases or [])
                if args[1:3] == ("release", "create"):
                    self.assertIn("--verify-tag", args)
                    self.assertEqual(args[args.index("--target") + 1], commit)
                    self.assertEqual(args[args.index("--notes-file") + 1], "-")
                    self.assertIn("Restore modern development tooling.", input_text)
                    if create_failure:
                        raise release.ReleaseError("Fixture publication failure")
                    return "https://github.com/owner/Fleet/releases/tag/5.0.0"
                self.fail(f"Unexpected GitHub command: {args}")
            return original(root, *args, input_text=input_text)

        return patch.object(release, "run", side_effect=fake)

    def test_prepare_changes_only_release_metadata_and_preserves_unrelated_version_text(self):
        before_tags = self.git("tag", "--list")
        before_head = release.head(self.root)
        with contextlib.redirect_stdout(io.StringIO()):
            release.prepare(self.root, "5.0.0")
        self.assertEqual(release.read_metadata(self.root)[0], "5.0.0")
        self.assertIn('summary = "Historical 4.6.1 summary"', (self.root / "Fleet.podspec").read_text())
        self.assertIn("## 5.0.0", (self.root / "CHANGELOG.md").read_text())
        changed = {line[3:] for line in self.git("status", "--porcelain").splitlines()}
        self.assertEqual(changed, set(release.VERSION_FILES) | {"CHANGELOG.md"})
        self.assertEqual(self.git("tag", "--list"), before_tags)
        self.assertEqual(release.head(self.root), before_head)

    def test_rejects_invalid_and_non_increasing_versions_without_writes(self):
        originals = {name: (self.root / name).read_bytes() for name in release.VERSION_FILES}
        for version in ("4.6.1", "4.5.0", "-1.0.0", "5.01.0", "5.0", "v5.0.0", "5.0.0-rc.1", "../5.0.0"):
            with self.subTest(version=version), self.assertRaises(release.ReleaseError):
                release.prepare(self.root, version)
        self.assertEqual(originals, {name: (self.root / name).read_bytes() for name in originals})
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_rejects_staged_unstaged_and_untracked_work(self):
        path = self.root / "Fleet.podspec"
        path.write_text(path.read_text() + "# unrelated work\n")
        with self.assertRaisesRegex(release.ReleaseError, "checkout"):
            release.prepare(self.root, "5.0.0")
        self.git("add", "Fleet.podspec")
        with self.assertRaisesRegex(release.ReleaseError, "checkout"):
            release.prepare(self.root, "5.0.0")
        self.commit()
        (self.root / "untracked.txt").write_text("Unrelated work")
        with self.assertRaisesRegex(release.ReleaseError, "checkout"):
            release.prepare(self.root, "5.0.0")

    def test_rejects_conflicting_metadata_and_existing_or_newer_tags(self):
        self.git("tag", "5.0.0")
        with self.assertRaisesRegex(release.ReleaseError, "already exists"):
            release.prepare(self.root, "5.0.0")
        with self.assertRaisesRegex(release.ReleaseError, "older"):
            release.prepare(self.root, "4.7.0")
        path = self.root / "Fleet.podspec"
        path.write_text(path.read_text().replace('s.version = "4.6.1"', 's.version = "4.6.0"'))
        self.commit()
        with self.assertRaisesRegex(release.ReleaseError, "disagree"):
            release.prepare(self.root, "6.0.0")

    def test_write_failure_restores_all_original_files(self):
        before = {name: (self.root / name).read_bytes() for name in release.VERSION_FILES}
        original = release.os.replace
        calls = []

        def failing_replace(source, destination):
            calls.append(destination)
            if len(calls) == 2:
                raise OSError("Fixture disk error")
            return original(source, destination)

        with patch.object(release.os, "replace", side_effect=failing_replace), self.assertRaises(OSError):
            release.prepare(self.root, "5.0.0")
        self.assertEqual(before, {name: (self.root / name).read_bytes() for name in before})
        self.assertFalse((self.root / "CHANGELOG.md").exists())
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_draft_notes_and_missing_packaging_block_full_validation(self):
        with contextlib.redirect_stdout(io.StringIO()):
            release.prepare(self.root, "5.0.0")
        self.commit()
        with self.assertRaisesRegex(release.ReleaseError, "changelog"):
            release.check(self.root, "5.0.0")
        path = self.root / "CHANGELOG.md"
        path.write_text(path.read_text().replace("TODO:", "Changes:"))
        self.commit()
        with self.assertRaisesRegex(release.ReleaseError, "Packaging is not ready"):
            release.check(self.root, "5.0.0")
        self.assertFalse((self.root / "build/releases/5.0.0/validation.json").exists())

    def test_tests_only_runs_both_suites_but_cannot_authorize_publication(self):
        self.prepared()
        with contextlib.redirect_stdout(io.StringIO()):
            release.check(self.root, "5.0.0", tests_only=True)
        directory = self.root / "build/releases/5.0.0"
        evidence = json.loads((directory / "repository-validation.json").read_text())
        self.assertEqual(evidence["tests"], {"ios": 251, "tvos": 121})
        self.assertFalse(evidence["distribution_checked"])
        with self.assertRaisesRegex(release.ReleaseError, "full release check"):
            release.load_evidence(self.root, "5.0.0", release.head(self.root))

    def test_full_check_records_exact_revision_and_successful_consumers(self):
        commit = self.checked()
        receipt = json.loads((self.root / "build/releases/5.0.0/validation.json").read_text())
        self.assertEqual(receipt["commit"], commit)
        self.assertTrue(receipt["distribution_checked"])
        self.assertEqual((self.root / "build/python-check-ran").read_text(), "executed")
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_failed_or_empty_test_runs_invalidate_prior_evidence(self):
        self.checked()
        self.write_test_runner(status=65)
        self.commit()
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(release.ReleaseError, "failed"):
            release.check(self.root, "5.0.0")
        self.assertFalse((self.root / "build/releases/5.0.0/validation.json").exists())
        self.write_test_runner(tvos=0)
        self.commit()
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(release.ReleaseError, "nonempty tvos"):
            release.check(self.root, "5.0.0")

    def test_consumer_failure_does_not_produce_publication_evidence(self):
        self.prepared(packaging=True)
        (self.root / "script/check-distribution").write_text("#!/bin/bash\nexit 17\n")
        self.commit()
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(release.ReleaseError, "failed"):
            release.check(self.root, "5.0.0")
        self.assertFalse((self.root / "build/releases/5.0.0/validation.json").exists())

    def test_snapshot_change_invalidates_evidence_and_publish(self):
        self.checked()
        self.git("commit", "--allow-empty", "-m", "Another revision")
        with self.assertRaisesRegex(release.ReleaseError, "another revision"):
            release.publish(self.root, "5.0.0", dry_run=True)
        original = release.logged_run
        calls = []

        def moving_head(root, log, *args):
            output = original(root, log, *args)
            calls.append(args)
            if len(calls) == 3:
                self.git("commit", "--allow-empty", "-m", "Moved during check")
            return output

        with patch.object(release, "logged_run", side_effect=moving_head):
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaisesRegex(release.ReleaseError, "HEAD changed"):
                release.check(self.root, "5.0.0")
        self.assertFalse((self.root / "build/releases/5.0.0/validation.json").exists())

    def test_publish_dry_run_has_no_network_or_tag_mutations(self):
        self.checked()
        before = self.git("tag", "--list")
        with self.fake_network(), contextlib.redirect_stdout(io.StringIO()):
            release.publish(self.root, "5.0.0", dry_run=True)
        self.assertEqual(self.network_calls, [])
        self.assertEqual(self.git("tag", "--list"), before)

    def test_malformed_or_incomplete_evidence_cannot_authorize_publication(self):
        commit = self.checked()
        path = self.root / "build/releases/5.0.0/validation.json"
        original = json.loads(path.read_text())
        for evidence in (None, [], {**original, "tests": []}, {**original, "distribution_checked": False},
                         {**original, "tests": {"ios": True, "tvos": 121}}):
            path.write_text(json.dumps(evidence))
            with self.subTest(evidence=evidence), self.assertRaises(release.ReleaseError):
                release.load_evidence(self.root, "5.0.0", commit)

    def test_publish_requires_latest_successful_ci_and_executed_platform_steps(self):
        commit = self.checked()
        base = {"databaseId": 42, "headSha": commit, "headBranch": "master", "event": "push",
                "status": "completed", "conclusion": "success", "createdAt": "2026-10-01T00:00:00Z"}
        cases = [
            [{"name": "ios on Xcode 26.6", "status": "completed", "conclusion": "success", "steps": []}],
            [{"name": f"{platform} on Xcode 26.6", "status": "completed", "conclusion": "success",
              "steps": [{"name": "Run simulator tests", "status": "completed", "conclusion": "skipped"}]}
             for platform in ("ios", "tvos")],
        ]
        for jobs in cases:
            with self.subTest(jobs=jobs), self.fake_network(jobs=jobs), self.assertRaises(release.ReleaseError):
                release.publish(self.root, "5.0.0")
        newer_failure = {**base, "databaseId": 43, "conclusion": "failure", "createdAt": "2026-10-02T00:00:00Z"}
        with self.fake_network(runs=[base, newer_failure]), self.assertRaisesRegex(release.ReleaseError, "latest"):
            release.publish(self.root, "5.0.0")
        self.assertNotIn("5.0.0", self.git("tag", "--list").splitlines())
        self.assertFalse(any(call[:2] == ("git", "push") or call[:3] == ("gh", "release", "create")
                             for call in self.network_calls))

    def test_publish_pushes_only_selected_tag_and_uses_exact_commit(self):
        commit = self.checked()
        self.git("tag", "scratch")
        with self.fake_network(), contextlib.redirect_stdout(io.StringIO()):
            release.publish(self.root, "5.0.0")
        pushes = [call for call in self.network_calls if call[:2] == ("git", "push")]
        self.assertEqual(len(pushes), 1)
        self.assertEqual(pushes[0][-1], "refs/tags/5.0.0:refs/tags/5.0.0")
        self.assertNotIn("--tags", pushes[0])
        self.assertEqual(release.local_tag_commit(self.root, "5.0.0"), commit)

    def test_conflicting_remote_tag_blocks_publication(self):
        self.checked()
        with self.fake_network(tag_commit="0" * 40), self.assertRaisesRegex(release.ReleaseError, "another commit"):
            release.publish(self.root, "5.0.0")
        self.assertIsNone(release.local_tag_commit(self.root, "5.0.0"))

    def test_publication_uses_push_destination_and_rejects_multiple_push_urls(self):
        self.checked()
        destination = "https://github.com/destination/Fleet.git"
        self.git("remote", "set-url", "--push", "origin", destination)
        with self.fake_network(), contextlib.redirect_stdout(io.StringIO()):
            release.publish(self.root, "5.0.0")
        pushes = [call for call in self.network_calls if call[:2] == ("git", "push")]
        queries = [call for call in self.network_calls if call[:2] == ("git", "ls-remote")]
        self.assertEqual(pushes[0][2], destination)
        self.assertEqual(queries[0][2], destination)
        self.git("remote", "set-url", "--add", "--push", "origin", "git@github.com:other/Fleet.git")
        with self.assertRaisesRegex(release.ReleaseError, "exactly one"):
            release.publish(self.root, "5.0.0", dry_run=True)

    def test_partial_publication_can_resume_without_replacing_tag(self):
        commit = self.checked()
        with self.fake_network(create_failure=True), self.assertRaisesRegex(release.ReleaseError, "publication failure"):
            release.publish(self.root, "5.0.0")
        tag_object = self.git("rev-parse", "refs/tags/5.0.0")
        self.network_calls.clear()
        with self.fake_network(tag_commit=commit), contextlib.redirect_stdout(io.StringIO()):
            release.publish(self.root, "5.0.0")
        self.assertEqual(self.git("rev-parse", "refs/tags/5.0.0"), tag_object)
        self.assertFalse(any(call[:2] == ("git", "push") for call in self.network_calls))

    def test_cli_failures_return_nonzero(self):
        with patch.object(release, "ROOT", self.root), patch.object(sys, "argv", ["release", "prepare", "bad"]):
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(release.main(), 1)


if __name__ == "__main__":
    unittest.main()
