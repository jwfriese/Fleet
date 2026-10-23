"""Run real, external Git-pinned SwiftPM consumers in iOS and tvOS hosts."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from consumer_project import create_project
from importlib.util import spec_from_file_location, module_from_spec

ROOT = Path(__file__).resolve().parents[1]
spec = spec_from_file_location("select_simulator", ROOT / "script/select-simulator.py")
selector = module_from_spec(spec)
spec.loader.exec_module(selector)


class DistributionError(Exception):
    pass


def git(root, *args):
    result = subprocess.run(["git", "-C", str(root), *args], text=True, capture_output=True)
    if result.returncode:
        raise DistributionError(result.stderr.strip())
    return result.stdout.strip()


def successful_test_count(output):
    summaries = re.findall(r"Executed (\d+) tests?, with (\d+) failures?", output)
    if (not summaries or int(summaries[-1][0]) == 0
            or any(int(failures) for _, failures in summaries)
            or "** TEST SUCCEEDED **" not in output):
        raise DistributionError("Consumer did not execute a successful, nonempty test suite.")
    return int(summaries[-1][0])


def compare_traces(baseline, legacy, preserve):
    """Check recorded UIKit traces from fresh processes: the no-Fleet baseline, legacy and preserve-timing Fleet."""
    if not baseline or not any(event.endswith("animated: true)") for event in baseline):
        raise DistributionError("The no-Fleet baseline did not exercise animated UIKit transitions.")
    if "offscreen.hiddenViewLoaded=false" not in baseline:
        raise DistributionError("The no-Fleet baseline did not leave an offscreen pushed view unloaded.")
    if preserve != baseline:
        difference = next((f"{index}: baseline {a!r} vs preserve-timing {b!r}"
                           for index, (a, b) in enumerate(zip(baseline + [None], preserve + [None])) if a != b), "length")
        raise DistributionError(f"preserve-timing trace differs from the no-Fleet baseline at {difference}.")
    # Legacy keeps its documented contract: nonanimated, eagerly loaded, same callbacks otherwise.
    if any("animated: true" in event for event in legacy) or "offscreen.hiddenViewLoaded=true" not in legacy:
        raise DistributionError("legacy trace no longer forces nonanimated, eager navigation.")
    for marker in ("push.returned", "pop.returned", "present.completion", "dismiss.completion", "delegate.didShow(detail, animated: false)"):
        if marker not in legacy:
            raise DistributionError(f"legacy trace is missing {marker}.")


def logged_run(root, log_path, args, extra_env=None):
    print("Consumer command: " + " ".join(map(str, args)), flush=True)
    environment = {**os.environ, **(extra_env or {})}
    with log_path.open("w") as log, subprocess.Popen(list(map(str, args)), cwd=root, env=environment,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:
        lines = []
        for line in process.stdout:
            log.write(line)
            print(line, end="", flush=True)
            lines.append(line)
        status = process.wait()
    if status:
        raise DistributionError(f"Consumer command failed ({status}); see {log_path}")
    return "".join(lines)


def snapshot(root, destination):
    """Development-only Git snapshot for exercising uncommitted package changes."""
    destination.mkdir()
    shutil.copy2(root / "Package.swift", destination)
    shutil.copy2(root / "LICENSE", destination)
    shutil.copytree(root / "Fleet", destination / "Fleet")
    git(destination, "init", "-q")
    git(destination, "add", ".")
    git(destination, "-c", "user.name=Fleet consumer fixture", "-c", "user.email=fixture@example.invalid",
        "-c", "commit.gpgsign=false", "commit", "-qm", "Development package snapshot")
    return destination.as_uri(), git(destination, "rev-parse", "HEAD")


VIEWINSPECTOR_URL = "https://github.com/nalexn/ViewInspector"
# Release 0.10.5 (not the 0.10.6 default branch).
VIEWINSPECTOR_REVISION = "2dacb6e514be19379c605a5a11564d0f3fea89d9"

SNAPSHOTTESTING_URL = "https://github.com/pointfreeco/swift-snapshot-testing"
# Release 1.12.0: the last release without swift-syntax or other transitive packages.
SNAPSHOTTESTING_REVISION = "26ed3a2b4a2df47917ca9b790a57f91285b923fb"


def check(root, platform="all", allow_dirty=False, viewinspector=False, snapshottesting=False):
    if not (root / "Package.swift").is_file():
        raise DistributionError("Fleet Package.swift is missing; no distributed consumer can be validated.")
    commit = git(root, "rev-parse", "HEAD")
    dirty = bool(git(root, "status", "--porcelain"))
    if dirty and not allow_dirty:
        raise DistributionError("Commit the checkout before validating its distributed revision. Use --allow-dirty only for development.")
    if platform == "all" and os.environ.get("FLEET_TEST_DESTINATION"):
        raise DistributionError("Use an explicit destination with one consumer platform at a time.")
    build = Path(os.environ.get("FLEET_BUILD_DIR", root / "build")).resolve()
    build.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix="distribution-", dir=build))
    print(f"Fleet: external consumer results: {run}", flush=True)
    package_url, revision = root.as_uri(), commit
    if allow_dirty:
        package_url, revision = snapshot(root, run / "DevelopmentPackage")
        print("Development snapshot only; this run cannot certify a release.", flush=True)
    inspector = (VIEWINSPECTOR_URL, VIEWINSPECTOR_REVISION) if viewinspector else None
    snapshot_package = (SNAPSHOTTESTING_URL, SNAPSHOTTESTING_REVISION) if snapshottesting else None
    project = create_project(run / "Consumer", root / "Integration/PackageConsumer", package_url, revision, inspector, snapshot_package)
    packages = run / "SourcePackages"
    counts = {}
    policy_counts = {}
    platforms = ("ios", "tvos") if platform == "all" else (platform,)
    for selected in platforms:
        directory = run / selected
        directory.mkdir()
        scheme = "Consumer-" + selected
        base = ["xcodebuild", "-project", project, "-scheme", scheme,
                "-clonedSourcePackagesDirPath", packages]
        logged_run(root, directory / "resolve.log", [*base, "-resolvePackageDependencies"])
        lockfile = project / "project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        try:
            pins = json.loads(lockfile.read_text())["pins"]
            revisions = sorted(pin["state"]["revision"] for pin in pins)
            if revisions != sorted([revision] + ([VIEWINSPECTOR_REVISION] if viewinspector else []) + ([SNAPSHOTTESTING_REVISION] if snapshottesting else [])):
                raise DistributionError("Consumer resolution did not pin the exact package revision.")
        except (OSError, KeyError, ValueError) as error:
            raise DistributionError("Missing or invalid consumer package lockfile.") from error
        sdk = "iphonesimulator" if selected == "ios" else "appletvsimulator"
        destination = os.environ.get("FLEET_TEST_DESTINATION")
        if not destination:
            sdk_version = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-version"], text=True).strip()
            devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"], text=True))
            destination = "id=" + selector.select_device(devices["devices"], selected, sdk_version)
        trace_dir = directory / "traces"
        trace_dir.mkdir()
        trace_env = {"TEST_RUNNER_FLEET_TRACE_OUT": str(trace_dir)}
        if snapshottesting:
            # Failure images (actual) land beside the result bundle so local and CI runs retain them.
            snapshot_dir = directory / "snapshot-artifacts"
            snapshot_dir.mkdir()
            trace_env["TEST_RUNNER_SNAPSHOT_ARTIFACTS"] = str(snapshot_dir)
        test_arguments = ["test",
                "-destination", destination, "-destination-timeout", "60",
                "-derivedDataPath", run / "DerivedData" / selected,
                "-onlyUsePackageVersionsFromResolvedFile", "-parallel-testing-enabled", "NO",
                "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "30",
                "-maximum-test-execution-time-allowance", "60", "CODE_SIGNING_ALLOWED=NO"]
        # The baseline is a separate bundle that does not link Fleet, run in its own fresh host process.
        baseline_base = ["xcodebuild", "-project", project, "-scheme", "Baseline-" + selected,
                         "-clonedSourcePackagesDirPath", packages]
        successful_test_count(logged_run(root, directory / "xcodebuild-baseline.log", [*baseline_base, *test_arguments,
            "-resultBundlePath", directory / "TestResults-baseline.xcresult"], trace_env))
        # Each policy is a fresh test-host process: the hosting policy is fixed at process start, so the
        # preserve-timing run launches the consumer with FLEET_HOSTING_POLICY set, never per test.
        for policy, suffix, extra_env in (("legacy", "", None),
                                          ("preserve-timing", "-preserve-timing", {"TEST_RUNNER_FLEET_HOSTING_POLICY": "preserve-timing"})):
            output = logged_run(root, directory / f"xcodebuild{suffix}.log", [*base, *test_arguments,
                "-resultBundlePath", directory / f"TestResults{suffix}.xcresult"], {**trace_env, **(extra_env or {})})
            count = successful_test_count(output)
            if policy == "legacy":
                counts[selected] = count
            else:
                policy_counts[selected] = count
        try:
            traces = [json.loads((trace_dir / f"{name}.json").read_text()) for name in ("baseline", "legacy", "preserve-timing")]
        except (OSError, ValueError) as error:
            raise DistributionError(f"Missing recorded UIKit trace for {selected}.") from error
        compare_traces(*traces)
    if git(root, "rev-parse", "HEAD") != commit or (not allow_dirty and git(root, "status", "--porcelain")):
        raise DistributionError("The source checkout changed during consumer validation.")
    evidence = {"schema": 1, "source_commit": commit, "package_revision": revision,
                "development_snapshot": allow_dirty, "tests": counts, "preserve_timing_tests": policy_counts,
                "viewinspector_revision": VIEWINSPECTOR_REVISION if viewinspector else None,
                "snapshottesting_revision": SNAPSHOTTESTING_REVISION if snapshottesting else None,
                "validated_at": datetime.now(timezone.utc).isoformat()}
    (run / "validation.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(f"Fleet: external consumer tests passed: legacy {counts}, preserve-timing {policy_counts}. Evidence: {run / 'validation.json'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", nargs="?", choices=("ios", "tvos", "all"), default="all")
    parser.add_argument("--allow-dirty", action="store_true", help="Test a development snapshot; does not certify a release")
    parser.add_argument("--with-viewinspector", action="store_true",
                        help="Also compile the optional ViewInspector compatibility proof into the consumer test target")
    parser.add_argument("--with-snapshottesting", action="store_true",
                        help="Compile the optional SnapshotTesting adapter and named-environment snapshot tests into the consumer test target (default; kept for compatibility)")
    parser.add_argument("--without-snapshottesting", action="store_true",
                        help="Skip the optional SnapshotTesting adapter and snapshot tests, so the consumer does not resolve that package")
    args = parser.parse_args()
    try:
        check(ROOT, args.platform, args.allow_dirty, args.with_viewinspector,
              args.with_snapshottesting or not args.without_snapshottesting)
    except (DistributionError, ValueError, subprocess.SubprocessError, OSError) as error:
        print(f"Fleet distribution validation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
