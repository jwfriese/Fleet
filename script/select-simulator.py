#!/usr/bin/env python3
"""Select an available simulator compatible with the selected SDK."""

import json
import re
import sys


def version(value):
    return tuple(int(part) for part in re.findall(r"\d+", value))


def select_device(devices, platform, sdk_version):
    prefix = "com.apple.CoreSimulator.SimRuntime." + {"ios": "iOS-", "tvos": "tvOS-"}[platform]
    candidates = []
    for runtime, entries in devices.items():
        if not runtime.startswith(prefix):
            continue
        runtime_version = version(runtime[len(prefix):])
        if runtime_version > version(sdk_version):
            continue
        for device in entries:
            if not device.get("isAvailable", False):
                continue
            if platform == "ios" and not device["name"].startswith("iPhone"):
                continue
            candidates.append((runtime_version, device["state"] == "Booted", device["name"], device["udid"]))
    if not candidates:
        raise ValueError(f"No available {platform} simulator compatible with SDK {sdk_version}. "
                         "Install the platform and a simulator runtime in Xcode Settings > Components, "
                         "or set FLEET_TEST_DESTINATION to an explicit xcodebuild destination.")
    return max(candidates)[3]


if __name__ == "__main__":
    try:
        print(select_device(json.load(sys.stdin)["devices"], sys.argv[1], sys.argv[2]))
    except (ValueError, KeyError, IndexError) as error:
        print(f"Fleet: {error}", file=sys.stderr)
        sys.exit(2)
