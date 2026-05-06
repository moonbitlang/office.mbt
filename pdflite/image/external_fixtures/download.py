#!/usr/bin/env python3
"""Download external image PDFs listed in manifest.json and record hashes."""

from __future__ import annotations

import hashlib
import json
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / "manifest.json"
DOWNLOADS = ROOT / "downloads"
LOCK = ROOT / "manifest.lock.json"


def read_manifest() -> list[dict[str, Any]]:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def download(url: str, output: Path) -> tuple[int, str]:
    output.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    size = 0
    with urllib.request.urlopen(url) as response, output.open("wb") as handle:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            size += len(chunk)
            digest.update(chunk)
            handle.write(chunk)
    return size, digest.hexdigest()


def main() -> int:
    lock_entries = []
    for entry in read_manifest():
        output = DOWNLOADS / entry["filename"]
        size, sha256 = download(entry["url"], output)
        lock_entries.append(
            {
                "id": entry["id"],
                "filename": entry["filename"],
                "url": entry["url"],
                "bytes": size,
                "sha256": sha256,
            }
        )
        print(f"{entry['id']}: {size} bytes {sha256}")
    LOCK.write_text(
        json.dumps(lock_entries, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
