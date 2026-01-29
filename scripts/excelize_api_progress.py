#!/usr/bin/env python3
"""
Maintain a one-by-one Excelize API parity checklist.

This writes `docs/excelize-api-progress.md` with one checkbox per normalized
Excelize API name (exported funcs + (*File) methods).

It preserves existing checkmarks to support incremental work across commits.
"""

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess


def _camel_to_snake(name: str) -> str:
    s = re.sub(r"(.)([A-Z][a-z]+)", r"\1_\2", name)
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s)
    return s.lower()


def _git_rev(path: pathlib.Path) -> str | None:
    try:
        return (
            subprocess.check_output(
                ["git", "-C", str(path), "rev-parse", "--short", "HEAD"],
                stderr=subprocess.DEVNULL,
                text=True,
            )
            .strip()
            .splitlines()[0]
        )
    except Exception:
        return None


def _read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def _collect_excelize_api(excelize_dir: pathlib.Path) -> list[str]:
    norms: set[str] = set()
    for p in excelize_dir.rglob("*.go"):
        if p.name.endswith("_test.go"):
            continue
        txt = _read_text(p)
        for m in re.finditer(r"func\s*\(\s*\w+\s+\*File\s*\)\s*([A-Z]\w*)\s*\(", txt):
            norms.add(_camel_to_snake(m.group(1)))
        for m in re.finditer(r"^func\s+([A-Z]\w*)\s*\(", txt, re.M):
            name = m.group(1)
            if name == "init":
                continue
            norms.add(_camel_to_snake(name))
    return sorted(norms)


def _parse_existing(path: pathlib.Path) -> dict[str, bool]:
    if not path.exists():
        return {}
    checked: dict[str, bool] = {}
    for line in _read_text(path).splitlines():
        m = re.match(r"^- \[(?P<mark>[ xX])\] `(?P<name>[a-z0-9_]+)`\s*$", line.strip())
        if not m:
            continue
        checked[m.group("name")] = m.group("mark").strip().lower() == "x"
    return checked


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--excelize-dir", default="excelize")
    ap.add_argument("--out", default="docs/excelize-api-progress.md")
    ap.add_argument(
        "--check",
        action="append",
        default=[],
        help="Mark this normalized API name as checked (can be repeated).",
    )
    args = ap.parse_args()

    repo_root = pathlib.Path(".").resolve()
    excelize_dir = (repo_root / args.excelize_dir).resolve()
    out_path = (repo_root / args.out).resolve()

    norms = _collect_excelize_api(excelize_dir)
    prev = _parse_existing(out_path)
    for n in args.check:
        prev[n] = True

    done = sum(1 for n in norms if prev.get(n, False))
    total = len(norms)
    excelize_rev = _git_rev(excelize_dir)
    mbtexcel_rev = _git_rev(repo_root)

    lines: list[str] = []
    lines.append("# Excelize API progress (one-by-one)\n")
    lines.append(f"- Excelize: `{args.excelize_dir}@{excelize_rev or 'UNKNOWN'}`\n")
    lines.append(f"- mbtexcel: `{mbtexcel_rev or 'UNKNOWN'}`\n")
    lines.append(f"- Progress: **{done}/{total}**\n")
    lines.append("\n(Use `docs/excelize-api-matrix.md` to jump to def/test locations.)\n\n")

    for n in norms:
        mark = "x" if prev.get(n, False) else " "
        lines.append(f"- [{mark}] `{n}`\n")

    out_path.write_text("".join(lines), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

