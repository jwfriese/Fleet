"""Run the XCUIAutomation UIKit reference traces for collection-view selection on iOS and/or tvOS."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from importlib.util import spec_from_file_location, module_from_spec

ROOT = Path(__file__).resolve().parents[1]
spec = spec_from_file_location("select_simulator", ROOT / "script/select-simulator.py")
selector = module_from_spec(spec)
spec.loader.exec_module(selector)
sys.path.insert(0, str(ROOT / "script"))
from trace_project import create_project


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", nargs="?", choices=("ios", "tvos", "all"), default="all")
    args = parser.parse_args()
    build = Path(os.environ.get("FLEET_BUILD_DIR", ROOT / "build")).resolve()
    build.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix="traces-", dir=build))
    project = create_project(run / "Trace", ROOT / "Integration/UIKitTraceHarness")
    print(f"Fleet: UIKit trace results: {run}", flush=True)
    for selected in (("ios", "tvos") if args.platform == "all" else (args.platform,)):
        sdk = "iphonesimulator" if selected == "ios" else "appletvsimulator"
        destination = os.environ.get("FLEET_TEST_DESTINATION")
        if not destination:
            version = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-version"], text=True).strip()
            devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"], text=True))
            destination = "id=" + selector.select_device(devices["devices"], selected, version)
        directory = run / selected
        directory.mkdir()
        command = ["xcodebuild", "test", "-project", str(project), "-scheme", "Trace-" + selected,
                   "-destination", destination, "-destination-timeout", "60",
                   "-derivedDataPath", str(run / "DerivedData" / selected),
                   "-resultBundlePath", str(directory / "TestResults.xcresult"), "-parallel-testing-enabled", "NO",
                   "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "60",
                   "-maximum-test-execution-time-allowance", "120", "CODE_SIGNING_ALLOWED=NO"]
        with (directory / "xcodebuild.log").open("w") as log:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            lines = []
            for line in process.stdout:
                log.write(line); print(line, end="", flush=True); lines.append(line)
            status = process.wait()
        output = "".join(lines)
        summaries = re.findall(r"Executed (\d+) tests?, with (\d+) failures?", output)
        if status or not summaries or int(summaries[-1][0]) == 0 or int(summaries[-1][1]) or "** TEST SUCCEEDED **" not in output:
            print(f"Fleet UIKit trace validation failed on {selected}; see {directory}", file=sys.stderr)
            return 1
        print(f"Fleet: {selected} UIKit traces passed ({summaries[-1][0]} tests).", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
