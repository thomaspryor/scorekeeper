#!/usr/bin/env python3
"""Print the UDID of the newest available simulator whose name matches a regex.

Usage: find_simulator.py "iPhone [0-9]+ Pro Max"
Picks the highest iOS runtime, then the highest-sorting device name, so CI keeps
working as runner images add new devices without anyone editing a device name.
"""
import json
import re
import subprocess
import sys


def natural_key(name):
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", name)]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    pattern = re.compile(sys.argv[1])
    listing = json.loads(subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"]))

    candidates = []
    for runtime, devices in listing["devices"].items():
        match = re.search(r"iOS-(\d+)-(\d+)", runtime)
        if not match:
            continue
        version = (int(match.group(1)), int(match.group(2)))
        for device in devices:
            if pattern.fullmatch(device["name"]):
                candidates.append((version, natural_key(device["name"]), device["name"], device["udid"]))

    if not candidates:
        names = sorted({d["name"] for ds in listing["devices"].values() for d in ds})
        sys.exit(f"No available simulator matches {sys.argv[1]!r}. Available: {names}")

    version, _, name, udid = max(candidates)
    print(f"Using {name} (iOS {version[0]}.{version[1]})", file=sys.stderr)
    print(udid)


if __name__ == "__main__":
    main()
