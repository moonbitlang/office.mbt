#!/usr/bin/env python3
"""
Generate an "API-by-API" mapping report to support one-by-one parity work.

Because we may not have a Go toolchain available to execute Excelize, this report
focuses on *traceability*:
- Where each exported Excelize API name is defined (file).
- Where it is used in Excelize's Go tests (file:line).
- Where the normalized name appears as a call in MoonBit tests/docs (file:line).

This is NOT semantic parity proof; it's a navigational checklist so we can work
through each API one-by-one and port missing edge cases.
"""

from __future__ import annotations

import argparse
import pathlib
import re
from collections import defaultdict
from dataclasses import dataclass


def _camel_to_snake(name: str) -> str:
    s = re.sub(r"(.)([A-Z][a-z]+)", r"\1_\2", name)
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s)
    return s.lower()


def _read_text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


@dataclass(frozen=True)
class Ref:
    path: pathlib.Path
    line: int


def _collect_excelize_api(excelize_dir: pathlib.Path) -> dict[str, list[tuple[str, pathlib.Path]]]:
    by_norm: dict[str, list[tuple[str, pathlib.Path]]] = defaultdict(list)
    for p in excelize_dir.rglob("*.go"):
        if p.name.endswith("_test.go"):
            continue
        txt = _read_text(p)
        for m in re.finditer(r"func\s*\(\s*\w+\s+\*File\s*\)\s*([A-Z]\w*)\s*\(", txt):
            go_name = m.group(1)
            by_norm[_camel_to_snake(go_name)].append((go_name, p))
        for m in re.finditer(r"^func\s+([A-Z]\w*)\s*\(", txt, re.M):
            go_name = m.group(1)
            if go_name == "init":
                continue
            by_norm[_camel_to_snake(go_name)].append((go_name, p))
    # stable output
    for k in list(by_norm.keys()):
        by_norm[k] = sorted(by_norm[k], key=lambda x: (x[0], str(x[1])))
    return dict(sorted(by_norm.items(), key=lambda x: x[0]))


def _collect_excelize_test_refs(excelize_dir: pathlib.Path, go_names: set[str]) -> dict[str, list[Ref]]:
    refs: dict[str, list[Ref]] = defaultdict(list)
    for p in excelize_dir.rglob("*_test.go"):
        txt = _read_text(p)
        lines = txt.splitlines()
        for i, line in enumerate(lines, start=1):
            # Fast substring gate, then regex word-boundary check.
            for go_name in go_names:
                if go_name not in line:
                    continue
                if re.search(rf"\b{re.escape(go_name)}\b", line):
                    refs[go_name].append(Ref(path=p, line=i))
    for k in list(refs.keys()):
        refs[k] = sorted(refs[k], key=lambda r: (str(r.path), r.line))
    return refs


def _collect_moon_call_refs(repo_root: pathlib.Path, names: set[str]) -> dict[str, list[Ref]]:
    patterns = [
        "**/*_test.mbt",
        "**/*_wbtest.mbt",
        "**/*.mbt.md",
    ]
    refs: dict[str, list[Ref]] = defaultdict(list)
    seen: set[pathlib.Path] = set()
    for pat in patterns:
        for p in repo_root.glob(pat):
            if not p.is_file():
                continue
            rel = p.relative_to(repo_root)
            # Skip generated/build artifacts.
            if any(part in {"_build", "target", ".mooncakes"} for part in rel.parts):
                continue
            if rel.parts and rel.parts[0] == "excelize":
                continue
            rp = p.resolve()
            if rp in seen:
                continue
            seen.add(rp)
            txt = _read_text(rp)
            lines = txt.splitlines()
            for i, line in enumerate(lines, start=1):
                for name in names:
                    if name not in line:
                        continue
                    # method call: .name( / ::name( or function call name(
                    if re.search(rf"(?:\.|::|\b){re.escape(name)}\s*\(", line):
                        refs[name].append(Ref(path=rp, line=i))
    for k in list(refs.keys()):
        refs[k] = sorted(refs[k], key=lambda r: (str(r.path), r.line))
    return refs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--excelize-dir", default="excelize")
    ap.add_argument("--out", default="docs/excelize-api-matrix.md")
    ap.add_argument("--max-refs", type=int, default=5)
    args = ap.parse_args()

    repo_root = pathlib.Path(".").resolve()
    excelize_dir = (repo_root / args.excelize_dir).resolve()

    by_norm = _collect_excelize_api(excelize_dir)
    go_names = {go_name for items in by_norm.values() for go_name, _ in items}

    excelize_test_refs = _collect_excelize_test_refs(excelize_dir, go_names)
    moon_refs = _collect_moon_call_refs(repo_root, set(by_norm.keys()))

    max_refs: int = args.max_refs

    lines: list[str] = []
    lines.append("# Excelize API matrix (one-by-one)\n")
    lines.append(
        "This report is a *navigation aid* for manual parity work: it maps each exported Excelize API name\n"
        "to its Go definition + Go test usage, and to MoonBit test/doc call sites.\n"
    )
    lines.append(f"- Excelize dir: `{args.excelize_dir}`\n")
    lines.append(f"- Total normalized API names: **{len(by_norm)}**\n")
    lines.append(f"- Max refs per section: **{max_refs}**\n")

    for norm, items in by_norm.items():
        lines.append(f"\n## `{norm}`\n")
        lines.append("\n**Excelize defs**\n")
        for go_name, p in items:
            lines.append(f"- `{go_name}` in `{p.relative_to(repo_root)}`\n")

        lines.append("\n**Excelize tests**\n")
        any_test = False
        for go_name, _ in items:
            refs = excelize_test_refs.get(go_name, [])
            if not refs:
                continue
            any_test = True
            for r in refs[:max_refs]:
                lines.append(f"- `{go_name}` in `{r.path.relative_to(repo_root)}:{r.line}`\n")
            if len(refs) > max_refs:
                lines.append(f"- (more: {len(refs) - max_refs} additional hits)\n")
        if not any_test:
            lines.append("- (none found)\n")

        lines.append("\n**MoonBit calls (tests/docs)**\n")
        refs = moon_refs.get(norm, [])
        if not refs:
            lines.append("- (none found)\n")
        else:
            for r in refs[:max_refs]:
                lines.append(f"- `{r.path.relative_to(repo_root)}:{r.line}`\n")
            if len(refs) > max_refs:
                lines.append(f"- (more: {len(refs) - max_refs} additional hits)\n")

    out_path = (repo_root / args.out).resolve()
    out_path.write_text("".join(lines), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
