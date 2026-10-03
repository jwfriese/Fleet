#!/usr/bin/env python3
"""Prepare, validate, and publish Fleet releases as separate operations."""

import argparse
from datetime import date, datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import re
import shlex
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
VERSION_PATTERN = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
VERSION_FILES = ("Fleet.xcodeproj/project.pbxproj", "Fleet/Info.plist", "Fleet.podspec")


class ReleaseError(Exception):
    pass


def version_tuple(value):
    if not re.fullmatch(VERSION_PATTERN, value):
        raise ReleaseError("Use a stable version with three components, such as 5.0.0 (no prefix or leading zeros).")
    return tuple(map(int, value.split(".")))


def run(root, *args, input_text=None):
    result = subprocess.run(args, cwd=root, input=input_text, text=True, capture_output=True)
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise ReleaseError(f"{shlex.join(args)} failed ({result.returncode}): {detail}")
    return result.stdout.rstrip("\n")


def git(root, *args):
    return run(root, "git", *args)


def head(root):
    return git(root, "rev-parse", "HEAD")


def require_clean(root):
    if git(root, "status", "--porcelain=v1", "--untracked-files=all"):
        raise ReleaseError("The checkout has staged, unstaged, or untracked changes. Commit or move them before releasing.")


def read_metadata(root):
    project = (root / VERSION_FILES[0]).read_text()
    project_versions = re.findall(r"CURRENT_PROJECT_VERSION = ([^;]+);", project)
    info = plistlib.loads((root / VERSION_FILES[1]).read_bytes())
    podspec = (root / VERSION_FILES[2]).read_text()
    pod_versions = re.findall(r'^\s*s\.version\s*=\s*"([^"]+)"\s*$', podspec, re.MULTILINE)
    if not project_versions or len(pod_versions) != 1:
        raise ReleaseError("Could not identify the project or podspec version.")
    versions = project_versions + [info.get("CFBundleShortVersionString"), pod_versions[0]]
    if len(set(versions)) != 1:
        raise ReleaseError("Project, framework plist, and podspec versions disagree. Reconcile them before preparing a release.")
    version = versions[0]
    version_tuple(version)
    if info.get("CFBundleVersion") != "$(CURRENT_PROJECT_VERSION)":
        raise ReleaseError("Fleet/Info.plist must derive CFBundleVersion from CURRENT_PROJECT_VERSION.")
    return version, project, podspec


def local_tag_commit(root, version):
    exists = subprocess.run(
        ["git", "show-ref", "--verify", "--quiet", f"refs/tags/{version}"], cwd=root
    )
    if exists.returncode == 1:
        return None
    if exists.returncode:
        raise ReleaseError("Could not inspect the local release tag.")
    return git(root, "rev-parse", f"refs/tags/{version}^{{commit}}")


def require_latest(version, tags):
    newer = [tag for tag in tags if re.fullmatch(VERSION_PATTERN, tag)
             and version_tuple(tag) > version_tuple(version)]
    if newer:
        raise ReleaseError(f"Version {version} is older than existing release {max(newer, key=version_tuple)}.")


def replace_files(root, replacements):
    """Stage complete file contents before replacing; restore on a write failure."""
    originals = {name: (root / name).read_bytes() if (root / name).exists() else None
                 for name in replacements}
    staged = {}
    changed = []
    try:
        for name, contents in replacements.items():
            path = root / name
            with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temporary:
                staged[name] = Path(temporary.name)
                temporary.write(contents)
            staged[name].chmod(path.stat().st_mode & 0o777 if path.exists() else 0o644)
        for name, temporary in staged.items():
            os.replace(temporary, root / name)
            changed.append(name)
    except OSError:
        for name in reversed(changed):
            path = root / name
            if originals[name] is None:
                path.unlink()
            else:
                path.write_bytes(originals[name])
        raise
    finally:
        for temporary in staged.values():
            temporary.unlink(missing_ok=True)


def prepare(root, version):
    version_tuple(version)
    require_clean(root)
    previous, project, podspec = read_metadata(root)
    if version_tuple(version) <= version_tuple(previous):
        raise ReleaseError(f"Version {version} must be newer than {previous}.")
    if local_tag_commit(root, version):
        raise ReleaseError(f"Local tag {version} already exists.")
    require_latest(version, git(root, "tag", "--list").splitlines())
    plist_text = (root / VERSION_FILES[1]).read_text()
    plist_text, count = re.subn(
        r"(<key>CFBundleShortVersionString</key>\s*<string>)[^<]+(</string>)",
        lambda match: match[1] + version + match[2], plist_text,
    )
    if count != 1:
        raise ReleaseError("Could not update the framework's version string.")
    changelog_path = root / "CHANGELOG.md"
    changelog = changelog_path.read_text() if changelog_path.exists() else "# Changelog\n\n"
    if not changelog.startswith("# Changelog\n"):
        raise ReleaseError("CHANGELOG.md must start with '# Changelog'.")
    if re.search(rf"^## {re.escape(version)}(?:\s|$)", changelog, re.MULTILINE):
        raise ReleaseError(f"Changelog entry {version} already exists.")
    entry = (f"## {version} — {date.today().isoformat()}\n\n"
             "- TODO: Describe changes, compatibility requirements, and migration steps.\n\n")
    changelog = "# Changelog\n\n" + entry + changelog[len("# Changelog\n"):].lstrip("\n")
    replacements = {
        VERSION_FILES[0]: re.sub(
            r"CURRENT_PROJECT_VERSION = [^;]+;",
            f"CURRENT_PROJECT_VERSION = {version};", project,
        ).encode(),
        VERSION_FILES[1]: plist_text.encode(),
        VERSION_FILES[2]: re.sub(
            r'^(\s*s\.version\s*=\s*)"[^"]+"(\s*)$',
            lambda match: match[1] + f'"{version}"' + match[2], podspec, flags=re.MULTILINE,
        ).encode(),
        "CHANGELOG.md": changelog.encode(),
    }
    replace_files(root, replacements)
    print(f"Prepared {previous} → {version}. Review these files:")
    for name in replacements:
        print(f"  {name}")
    print("Complete the release notes, then review and commit the diff. Run the release check on that commit.")


def release_notes(root, version):
    path = root / "CHANGELOG.md"
    if not path.exists():
        raise ReleaseError("CHANGELOG.md is missing. Prepare release notes first.")
    match = re.search(
        rf"^## {re.escape(version)}(?:[ \t]+[^\n]*)?\n(.*?)(?=^## |\Z)",
        path.read_text(), re.MULTILINE | re.DOTALL,
    )
    if not match or not match[1].strip() or re.search(r"\b(?:TODO|TBD|FIXME)\b", match[1]):
        raise ReleaseError(f"Complete the changelog entry for {version}; draft placeholders cannot be published.")
    return match[1].strip() + "\n"


def validate_snapshot(root, version, publication_ready=True):
    version_tuple(version)
    require_clean(root)
    current, _, _ = read_metadata(root)
    if current != version:
        raise ReleaseError(f"Requested {version}, but this checkout contains {current}.")
    commit = head(root)
    if publication_ready:
        release_notes(root, version)
        tag_commit = local_tag_commit(root, version)
        if tag_commit and tag_commit != commit:
            raise ReleaseError(f"Local tag {version} points to a different commit.")
        require_latest(version, git(root, "tag", "--list").splitlines())
    return commit


def require_distribution_checker(root):
    checker = root / "script/check-distribution"
    if not (root / "Package.swift").is_file() or not checker.is_file() or not os.access(checker, os.X_OK):
        raise ReleaseError(
            "Packaging is not ready: add Fleet's Package.swift and an executable script/check-distribution "
            "that builds and runs external SwiftPM consumers on iOS and tvOS. "
            "Use check --tests-only for repository validation; it does not authorize publication."
        )
    return checker


def logged_run(root, log, *args):
    print(f"Running {shlex.join(map(str, args))}", flush=True)
    with subprocess.Popen(list(map(str, args)), cwd=root, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True) as process:
        output = []
        for line in process.stdout:
            print(line, end="", flush=True)
            log.write(line)
            log.flush()
            output.append(line)
        status = process.wait()
    if status:
        raise ReleaseError(f"{args[0]} failed ({status}). See the release validation log.")
    return "".join(output)


def test_counts(output):
    counts = {}
    for platform, scheme in (("ios", "Fleet"), ("tvos", "Fleet-tvOS")):
        match = re.search(
            rf"^Fleet: testing {scheme} on [^\n]*\n(.*?)(?=^Fleet: testing |\Z)",
            output, re.MULTILINE | re.DOTALL,
        )
        summaries = re.findall(r"Executed (\d+) tests?, with (\d+) failures?", match[1]) if match else []
        if not summaries or int(summaries[-1][0]) == 0 or any(int(failures) for _, failures in summaries):
            raise ReleaseError(f"Missing successful, nonempty {platform} test results in the canonical runner output.")
        if "** TEST SUCCEEDED **" not in match[1]:
            raise ReleaseError(f"The {platform} test session did not succeed.")
        counts[platform] = int(summaries[-1][0])
    return counts


def check(root, version, tests_only=False):
    # Invalidate prior evidence even if this attempt fails during preflight.
    directory = root / "build/releases" / version
    version_tuple(version)
    receipt_path = directory / "validation.json"
    receipt_path.unlink(missing_ok=True)
    commit = validate_snapshot(root, version, publication_ready=not tests_only)
    checker = None if tests_only else require_distribution_checker(root)
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / "validation.log").open("w") as log:
        logged_run(root, log, sys.executable, "-m", "unittest", "discover", "-s", "script/tests", "-v")
        counts = test_counts(logged_run(root, log, root / "script/test", "all"))
        if checker:
            logged_run(root, log, checker)
    require_clean(root)
    if head(root) != commit:
        raise ReleaseError("HEAD changed during validation. Validate the final revision again.")
    evidence = {"schema": 1, "version": version, "commit": commit,
                "validated_at": datetime.now(timezone.utc).isoformat(),
                "tests": counts, "distribution_checked": not tests_only}
    destination = directory / ("repository-validation.json" if tests_only else "validation.json")
    destination.write_text(json.dumps(evidence, indent=2) + "\n")
    print(f"Validated {commit}: iOS {counts['ios']}, tvOS {counts['tvos']} tests.")
    print(f"Evidence: {destination.relative_to(root)}")
    if tests_only:
        print("Repository tests passed. Publication still requires a full check with external consumers.")


def load_evidence(root, version, commit):
    try:
        evidence = json.loads((root / "build/releases" / version / "validation.json").read_text())
    except (OSError, ValueError) as error:
        raise ReleaseError("A successful full release check is required for this revision.") from error
    if not isinstance(evidence, dict) or not isinstance(evidence.get("tests"), dict):
        raise ReleaseError("Release evidence is malformed. Run a full check again.")
    if (evidence.get("schema") != 1 or evidence.get("commit") != commit
            or evidence.get("version") != version or evidence.get("distribution_checked") is not True
            or any(type(evidence.get("tests", {}).get(platform)) is not int
                   or evidence["tests"][platform] <= 0 for platform in ("ios", "tvos"))):
        raise ReleaseError("Release evidence is incomplete or belongs to another revision. Run a full check again.")


def github_repository(url):
    match = re.fullmatch(r"(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)"
                         r"([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?/?", url)
    if not match:
        raise ReleaseError("Publication requires a GitHub HTTPS or SSH remote.")
    return match[1]


def require_ci(root, repository, commit):
    runs = json.loads(run(root, "gh", "run", "list", "--repo", repository,
                          "--workflow", "test.yml", "--branch", "master", "--commit", commit,
                          "--limit", "20", "--json",
                          "databaseId,headSha,headBranch,event,status,conclusion,createdAt"))
    candidates = [item for item in runs if item["headSha"] == commit
                  and item["headBranch"] == "master" and item["event"] in ("push", "workflow_dispatch")]
    if not candidates:
        raise ReleaseError("No Tests workflow run exists for this revision on master.")
    latest = max(candidates, key=lambda item: (item["createdAt"], item["databaseId"]))
    if latest["status"] != "completed" or latest["conclusion"] != "success":
        raise ReleaseError("The latest Tests workflow run for this revision has not passed.")
    details = json.loads(run(root, "gh", "run", "view", str(latest["databaseId"]),
                             "--repo", repository, "--json", "jobs"))
    for platform in ("ios", "tvos"):
        jobs = [job for job in details["jobs"] if job["name"].startswith(platform + " on Xcode ")]
        if len(jobs) != 1 or jobs[0]["status"] != "completed" or jobs[0]["conclusion"] != "success":
            raise ReleaseError(f"CI must have a successful {platform} job for this revision.")
        steps = [step for step in jobs[0]["steps"] if step["name"] == "Run simulator tests"]
        if len(steps) != 1 or steps[0]["status"] != "completed" or steps[0]["conclusion"] != "success":
            raise ReleaseError(f"CI skipped or failed the {platform} simulator test step.")
    jobs = [job for job in details["jobs"] if job["name"].startswith("External SwiftPM consumers on Xcode ")]
    if len(jobs) != 1 or jobs[0]["status"] != "completed" or jobs[0]["conclusion"] != "success":
        raise ReleaseError("CI must have a successful external SwiftPM consumer job for this revision.")
    steps = [step for step in jobs[0]["steps"] if step["name"] == "Run external hosted consumers"]
    if len(steps) != 1 or steps[0]["status"] != "completed" or steps[0]["conclusion"] != "success":
        raise ReleaseError("CI skipped or failed the external SwiftPM consumer step.")


def publish(root, version, remote="origin", dry_run=False):
    commit = validate_snapshot(root, version)
    require_distribution_checker(root)
    load_evidence(root, version, commit)
    if git(root, "branch", "--show-current") != "master":
        raise ReleaseError("Publish from master after the release changes are reviewed and merged.")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/-]*", remote):
        raise ReleaseError("Invalid remote name.")
    push_urls = git(root, "remote", "get-url", "--push", "--all", remote).splitlines()
    if len(push_urls) != 1:
        raise ReleaseError("The release remote must have exactly one push URL.")
    push_url = push_urls[0]
    repository = github_repository(push_url)
    if dry_run:
        print(f"Publication plan: {repository}, tag {version}, commit {commit}.")
        print("Verify remote master, version tags, and the latest successful native and external consumer CI run.")
        print(f"Create or reuse only tag {version} at {commit}; push only refs/tags/{version}.")
        print("Create the GitHub release using the reviewed changelog.")
        print("Dry run complete. No network requests, tags, pushes, or releases were made.")
        return
    refs = {}
    for line in git(root, "ls-remote", push_url, "refs/heads/master", "refs/tags/*").splitlines():
        sha, ref = line.split()
        refs[ref] = sha
    if refs.get("refs/heads/master") != commit:
        raise ReleaseError("Remote master does not point to the validated commit. Push or merge it and wait for CI.")
    tag_ref = f"refs/tags/{version}"
    remote_tag = refs.get(tag_ref + "^{}", refs.get(tag_ref))
    if remote_tag and remote_tag != commit:
        raise ReleaseError(f"Remote tag {version} points to another commit.")
    remote_versions = [ref.removeprefix("refs/tags/") for ref in refs if ref.startswith("refs/tags/")]
    require_latest(version, remote_versions)
    require_ci(root, repository, commit)
    # Recheck after the network preflight, before performing mutations.
    if validate_snapshot(root, version) != commit:
        raise ReleaseError("HEAD changed during publication preflight.")
    load_evidence(root, version, commit)
    if not local_tag_commit(root, version):
        git(root, "tag", "-a", version, commit, "-m", f"Fleet {version}")
    if not remote_tag:
        git(root, "push", push_url, f"refs/tags/{version}:refs/tags/{version}")
    # Reuse a release after a partially completed publication, without rewriting it.
    existing = run(root, "gh", "release", "list", "--repo", repository, "--limit", "100",
                   "--json", "tagName,isDraft")
    matching = [item for item in json.loads(existing) if item["tagName"] == version]
    if matching:
        if matching[0]["isDraft"]:
            raise ReleaseError("A draft release already exists. Review it on GitHub before publication.")
        print(f"Release {version} already exists at the validated tag; no changes made to it.")
        return
    result = run(root, "gh", "release", "create", version, "--repo", repository,
                 "--verify-tag", "--target", commit, "--title", f"Fleet {version}",
                 "--notes-file", "-", input_text=release_notes(root, version))
    print(result)


def main():
    parser = argparse.ArgumentParser(prog="script/release", description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    descriptions = {
        "prepare": "Create a version and changelog diff for review.",
        "check": "Validate a committed release and its external consumers.",
        "publish": "Publish the exact validated revision to GitHub.",
    }
    for name, description in descriptions.items():
        command = commands.add_parser(name, help=description, description=description)
        command.add_argument("version", help="Stable X.Y.Z release version, matching Fleet's existing tag convention.")
        if name == "check":
            command.add_argument("--tests-only", action="store_true",
                                 help="Check repository tests only; do not produce publication evidence.")
        if name == "publish":
            command.add_argument("--remote", default="origin")
            command.add_argument("--dry-run", action="store_true", help="Print the local plan without contacting GitHub.")
    args = parser.parse_args()
    try:
        if args.command == "prepare":
            prepare(ROOT, args.version)
        elif args.command == "check":
            check(ROOT, args.version, args.tests_only)
        else:
            publish(ROOT, args.version, args.remote, args.dry_run)
    except (ReleaseError, OSError, ValueError, KeyError, TypeError) as error:
        print(f"Fleet release: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Fleet release: interrupted; no successful validation recorded.", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
