#!/usr/bin/env python3
"""Download external font PDFs listed in manifest.json and record hashes."""

from __future__ import annotations

import base64
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


def download(url: str, output: Path, encoding: str | None = None) -> tuple[int, str]:
    output.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    size = 0
    with urllib.request.urlopen(url) as response, output.open("wb") as handle:
        if encoding == "base64":
            data = base64.b64decode(response.read())
            size = len(data)
            digest.update(data)
            handle.write(data)
        elif encoding is None:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                size += len(chunk)
                digest.update(chunk)
                handle.write(chunk)
        else:
            raise ValueError(f"unsupported fixture encoding: {encoding}")
    return size, digest.hexdigest()


def main() -> int:
    lock_entries = []
    for entry in read_manifest():
        output = DOWNLOADS / entry["filename"]
        encoding = entry.get("encoding")
        size, sha256 = download(entry["url"], output, encoding)
        lock_entry = {
            "id": entry["id"],
            "filename": entry["filename"],
            "url": entry["url"],
            "bytes": size,
            "sha256": sha256,
        }
        if encoding is not None:
            lock_entry["encoding"] = encoding
        lock_entries.append(lock_entry)
        print(f"{entry['id']}: {size} bytes {sha256}")
    LOCK.write_text(
        json.dumps(lock_entries, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
