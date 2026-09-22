#!/usr/bin/env python3
"""Stage registry-check inputs and inspect the actual Moon publish archive."""

import argparse
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import zipfile


def stage(root: Path, relative: str, destination: Path) -> None:
    if any((parent / "moon.work").exists() for parent in destination.resolve().parents):
        raise ValueError(f"registry sandbox must be outside moon.work: {destination}")
    # Copy source files, including local edits, without copying build/cache trees.
    paths = subprocess.check_output(
        ["git", "-C", str(root), "ls-files", "-z", "--cached", "--others",
         "--exclude-standard", "--", relative]
    ).decode().split("\0")
    for name in filter(None, paths):
        source = root / name
        if not source.exists():
            continue  # A locally deleted tracked file is not part of the candidate.
        target = destination / Path(name).relative_to(relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)


def dependency_version(manifest: Path, dependency: str) -> str:
    # Read the source requirement, never the resolved version: resolution may
    # silently upgrade an internal dependency and must not set its own guard.
    source = re.sub(r"//[^\n]*", "", manifest.read_text())
    versions = re.findall(r'"' + re.escape(dependency) + r'@([^"\s]+)"', source)
    if len(versions) != 1 or not re.fullmatch(r"\d+\.\d+\.\d+(?:-[\w.-]+)?", versions[0]):
        raise ValueError(f"expected one exact version for {dependency} in {manifest}")
    return versions[0]


def check_archive(path: Path) -> None:
    forbidden = {"_build", ".mooncakes", "target", ".tools", ".git", "__pycache__"}
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if not any(PurePosixPath(name).name in {"moon.mod", "moon.mod.json"} for name in names):
            raise ValueError(f"missing module manifest in {path}")
        for name in names:
            parts = PurePosixPath(name.replace("\\", "/")).parts
            if forbidden.intersection(parts) or ".." in parts or name.startswith("/"):
                raise ValueError(f"unexpected build/cache or unsafe entry in {path}: {name}")
        corrupt = archive.testzip()
        if corrupt:
            raise ValueError(f"corrupt ZIP entry: {corrupt}")
    print(f"Publish archive verified: {path.name} ({path.stat().st_size} bytes)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    copy = commands.add_parser("stage")
    copy.add_argument("root", type=Path)
    copy.add_argument("relative")
    copy.add_argument("destination", type=Path)
    version = commands.add_parser("version")
    version.add_argument("manifest", type=Path)
    version.add_argument("dependency")
    package = commands.add_parser("archive")
    package.add_argument("path", type=Path)
    args = parser.parse_args()
    if args.command == "stage":
        stage(args.root, args.relative, args.destination)
    elif args.command == "version":
        print(dependency_version(args.manifest, args.dependency))
    else:
        check_archive(args.path)


if __name__ == "__main__":
    main()
