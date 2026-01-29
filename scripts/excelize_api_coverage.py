#!/usr/bin/env python3
"""
Heuristic API coverage report for Excelize parity work.

What it does:
- Parses vendored Excelize for exported funcs + (*File) methods.
- Normalizes names to snake_case (same as excelize_parity_report.py).
- Checks whether each normalized API name shows up in MoonBit test sources.

What it does NOT do:
- Prove semantic/behavior parity.
- Reliably map Excelize names to specific MoonBit symbols (we only look for the normalized name token).

This is intentionally a *double-check* tool to find obvious "never referenced in tests"
holes so we can address them one-by-one.
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


def _collect_excelize_api(excelize_dir: pathlib.Path) -> list[tuple[str, pathlib.Path]]:
    items: list[tuple[str, pathlib.Path]] = []
    for p in excelize_dir.rglob("*.go"):
        if p.name.endswith("_test.go"):
            continue
        txt = _read_text(p)
        for m in re.finditer(r"func\s*\(\s*\w+\s+\*File\s*\)\s*([A-Z]\w*)\s*\(", txt):
            items.append((m.group(1), p))
        for m in re.finditer(r"^func\s+([A-Z]\w*)\s*\(", txt, re.M):
            name = m.group(1)
            if name == "init":
                continue
            items.append((name, p))
    return items


def _collect_test_corpus(repo_root: pathlib.Path) -> str:
    patterns = [
        "**/*_test.mbt",
        "**/*_wbtest.mbt",
        "**/*.mbt.md",
    ]
    parts: list[str] = []
    seen: set[pathlib.Path] = set()
    for pat in patterns:
        for p in repo_root.glob(pat):
            if not p.is_file():
                continue
            rp = p.resolve()
            if rp in seen:
                continue
            seen.add(rp)
            parts.append(_read_text(rp))
    return "\n".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--excelize-dir", default="excelize")
    ap.add_argument(
        "--out",
        help="Write markdown report to this path (default: stdout).",
    )
    ap.add_argument(
        "--mode",
        choices=["token", "call"],
        default="call",
        help="How to detect coverage in tests: 'token' (name appears) or 'call' (looks like a function/method call).",
    )
    args = ap.parse_args()

    repo_root = pathlib.Path(".").resolve()
    excelize_dir = (repo_root / args.excelize_dir).resolve()

    excelize_rev = _git_rev(excelize_dir)
    mbtexcel_rev = _git_rev(repo_root)

    go_api = _collect_excelize_api(excelize_dir)
    # Deduplicate by normalized name (Excelize can have helpers with same normalized token).
    by_norm: dict[str, list[tuple[str, pathlib.Path]]] = {}
    for go_name, p in go_api:
        norm = _camel_to_snake(go_name)
        by_norm.setdefault(norm, []).append((go_name, p))

    corpus = _collect_test_corpus(repo_root)

    uncovered: list[tuple[str, list[tuple[str, pathlib.Path]]]] = []
    for norm, items in sorted(by_norm.items(), key=lambda x: x[0]):
        esc = re.escape(norm)
        ok = False
        if args.mode == "token":
            ok = re.search(rf"(?m)\b{esc}\b", corpus) is not None
        else:
            ok = (
                re.search(
                    rf"(?m)(?:\b{esc}\s*\(|\.{esc}\s*\(|::{esc}\s*\()",
                    corpus,
                )
                is not None
            )
        if not ok:
            uncovered.append((norm, items))

    lines: list[str] = []
    lines.append("# Excelize API coverage (heuristic)\n")
    lines.append("## Versions\n")
    lines.append(f"- Excelize: `{args.excelize_dir}@{excelize_rev or 'UNKNOWN'}`\n")
    lines.append(f"- mbtexcel: `{mbtexcel_rev or 'UNKNOWN'}`\n")
    lines.append("\n## Summary\n")
    lines.append(f"- Excelize exported API names (normalized): {len(by_norm)}\n")
    lines.append(f"- Not referenced in MoonBit tests (heuristic): {len(uncovered)}\n")

    lines.append("\n## Uncovered names\n")
    if not uncovered:
        lines.append("(none)\n")
    else:
        for norm, items in uncovered:
            refs = ", ".join(
                f"Excelize `{go_name}` in `{p.relative_to(repo_root)}`" for go_name, p in items
            )
            lines.append(f"- `{norm}` ({refs})\n")

    out = "\n".join(lines).rstrip() + "\n"
    if args.out:
        (repo_root / args.out).resolve().write_text(out, encoding="utf-8")
    else:
        print(out, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
