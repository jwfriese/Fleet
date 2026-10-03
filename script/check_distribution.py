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


def logged_run(root, log_path, args):
    print("Consumer command: " + " ".join(map(str, args)), flush=True)
    with log_path.open("w") as log, subprocess.Popen(list(map(str, args)), cwd=root,
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


def check(root, platform="all", allow_dirty=False):
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
    project = create_project(run / "Consumer", root / "Integration/PackageConsumer", package_url, revision)
    packages = run / "SourcePackages"
    counts = {}
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
            if len(pins) != 1 or pins[0]["state"]["revision"] != revision:
                raise DistributionError("Consumer resolution did not pin the exact package revision.")
        except (OSError, KeyError, ValueError) as error:
            raise DistributionError("Missing or invalid consumer package lockfile.") from error
        sdk = "iphonesimulator" if selected == "ios" else "appletvsimulator"
        destination = os.environ.get("FLEET_TEST_DESTINATION")
        if not destination:
            sdk_version = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-version"], text=True).strip()
            devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"], text=True))
            destination = "id=" + selector.select_device(devices["devices"], selected, sdk_version)
        output = logged_run(root, directory / "xcodebuild.log", [*base, "test",
            "-destination", destination, "-destination-timeout", "60",
            "-derivedDataPath", run / "DerivedData" / selected,
            "-resultBundlePath", directory / "TestResults.xcresult",
            "-onlyUsePackageVersionsFromResolvedFile", "-parallel-testing-enabled", "NO",
            "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "30",
            "-maximum-test-execution-time-allowance", "60", "CODE_SIGNING_ALLOWED=NO"])
        counts[selected] = successful_test_count(output)
    if git(root, "rev-parse", "HEAD") != commit or (not allow_dirty and git(root, "status", "--porcelain")):
        raise DistributionError("The source checkout changed during consumer validation.")
    evidence = {"schema": 1, "source_commit": commit, "package_revision": revision,
                "development_snapshot": allow_dirty, "tests": counts,
                "validated_at": datetime.now(timezone.utc).isoformat()}
    (run / "validation.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(f"Fleet: external consumer tests passed: {counts}. Evidence: {run / 'validation.json'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", nargs="?", choices=("ios", "tvos", "all"), default="all")
    parser.add_argument("--allow-dirty", action="store_true", help="Test a development snapshot; does not certify a release")
    args = parser.parse_args()
    try:
        check(ROOT, args.platform, args.allow_dirty)
    except (DistributionError, ValueError, subprocess.SubprocessError, OSError) as error:
        print(f"Fleet distribution validation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
