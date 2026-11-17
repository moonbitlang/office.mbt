#!/usr/bin/env python3
"""Publish workspace modules in dependency order using Moon's Git registry index."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
INDEX_ATTEMPTS = 12
INDEX_RETRY_SECONDS = 5


def module_coordinate(directory):
    manifest = (directory / "moon.mod").read_text()
    fields = []
    for field in ("name", "version"):
        values = re.findall(
            rf'^[ \t]*{field}[ \t]*=[ \t]*"([^"\n]+)"[ \t]*(?://[^\n]*)?$',
            manifest,
            re.MULTILINE,
        )
        if len(values) != 1:
            raise ValueError(f"Expected one {field} in {directory / 'moon.mod'}")
        fields.append(values[0])
    return tuple(fields)


def indexed(index, name, version):
    path = index / "user" / f"{name}.index"
    if not path.exists():
        return False
    return any(
        json.loads(line)["version"] == version
        for line in path.read_text().splitlines()
        if line.strip()
    )


def update_registry(root, index):
    subprocess.run(["moon", "update"], cwd=root, check=True)
    if not index.is_dir():
        raise RuntimeError(f"Moon Git registry index is missing: {index}")


def wait_for_release(root, index, name, version):
    # A successful upload can precede the server's Git index update. Checking
    # the refreshed local index also proves the next extracted package can see it.
    for attempt in range(INDEX_ATTEMPTS):
        update_registry(root, index)
        if indexed(index, name, version):
            return
        if attempt + 1 < INDEX_ATTEMPTS:
            print(f"Waiting for registry index: {name}@{version}", flush=True)
            time.sleep(INDEX_RETRY_SECONDS)
    raise RuntimeError(
        f"{name}@{version} is still absent from the registry index after "
        f"{INDEX_ATTEMPTS} refreshes; stopping before publishing consumers"
    )


def publish_modules(root, modules, moon_home):
    index = moon_home / "registry" / "index"
    # Validation may take several minutes. Refresh again before checking which
    # immutable versions already exist, so a partial release can be resumed.
    update_registry(root, index)
    for module in modules:
        directory = root / module
        name, version = module_coordinate(directory)
        print(f"::group::Publish {name}@{version}", flush=True)
        try:
            if indexed(index, name, version):
                print(f"Already published: {name}@{version}; skipping", flush=True)
                continue
            subprocess.run(["moon", "publish"], cwd=directory, check=True)
            wait_for_release(root, index, name, version)
        finally:
            print("::endgroup::", flush=True)


def main():
    try:
        if len(sys.argv) < 2:
            raise ValueError("Usage: publish.py MODULE [MODULE ...]")
        moon_home = Path(os.environ.get("MOON_HOME", Path.home() / ".moon"))
        publish_modules(ROOT, sys.argv[1:], moon_home)
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"publish: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
