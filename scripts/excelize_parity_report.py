#!/usr/bin/env python3

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
from collections import defaultdict


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
    # Exported funcs + exported (*File) methods.
    items: list[tuple[str, pathlib.Path]] = []
    for p in excelize_dir.rglob("*.go"):
        if p.name.endswith("_test.go"):
            continue
        txt = _read_text(p)
        # methods
        for m in re.finditer(
            r"func\s*\(\s*\w+\s+\*File\s*\)\s*([A-Z]\w*)\s*\(",
            txt,
        ):
            items.append((m.group(1), p))
        # exported package functions
        for m in re.finditer(r"^func\s+([A-Z]\w*)\s*\(", txt, re.M):
            name = m.group(1)
            if name == "init":
                continue
            items.append((name, p))
    return items


def _collect_moon_api_names(mbti_paths: list[pathlib.Path]) -> set[str]:
    names: set[str] = set()
    for p in mbti_paths:
        txt = _read_text(p)
        # top-level pub fn / pub async fn, optional type params
        for m in re.finditer(
            r"^pub\s+(?:async\s+)?fn(?:\[[^\]]+\])?\s+([A-Za-z0-9_]+)\(",
            txt,
            re.M,
        ):
            names.add(m.group(1))
        # methods
        for m in re.finditer(
            r"^pub\s+(?:async\s+)?fn(?:\[[^\]]+\])?\s+[A-Za-z0-9_]+::([A-Za-z0-9_]+)\(",
            txt,
            re.M,
        ):
            names.add(m.group(1))
    return names


def _collect_excelize_types(excelize_dir: pathlib.Path) -> dict[str, tuple[str, pathlib.Path]]:
    # norm_name -> (GoName, file)
    types: dict[str, tuple[str, pathlib.Path]] = {}
    for p in excelize_dir.rglob("*.go"):
        if p.name.endswith("_test.go"):
            continue
        txt = _read_text(p)
        for m in re.finditer(r"^type\s+([A-Z]\w*)\b", txt, re.M):
            go_name = m.group(1)
            types[_camel_to_snake(go_name)] = (go_name, p)
    return types


def _collect_moon_types(mbti_paths: list[pathlib.Path]) -> set[str]:
    types: set[str] = set()
    for p in mbti_paths:
        txt = _read_text(p)
        for m in re.finditer(r"^pub\s+(?:struct|enum|trait|type)\s+([A-Za-z0-9_]+)\b", txt, re.M):
            types.add(m.group(1).lower())
    return types


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a rough Excelize parity report for mbtexcel.")
    parser.add_argument("--excelize-dir", default="excelize", help="Path to the vendored excelize directory")
    parser.add_argument(
        "--mbti",
        action="append",
        default=["pkg.generated.mbti", "xlsx/pkg.generated.mbti"],
        help="Path to generated MoonBit interface (.mbti); can be repeated",
    )
    parser.add_argument("--out", help="Write markdown report to this path (default: stdout)")
    args = parser.parse_args()

    repo_root = pathlib.Path(".").resolve()
    excelize_dir = (repo_root / args.excelize_dir).resolve()
    mbti_paths = [(repo_root / p).resolve() for p in args.mbti]

    excelize_rev = _git_rev(excelize_dir)
    mbtexcel_rev = _git_rev(repo_root)

    go_api = _collect_excelize_api(excelize_dir)
    moon_names = _collect_moon_api_names(mbti_paths)

    missing_api: list[tuple[str, str, pathlib.Path]] = []
    for go_name, p in go_api:
        norm = _camel_to_snake(go_name)
        if norm not in moon_names:
            missing_api.append((norm, go_name, p))

    go_types = _collect_excelize_types(excelize_dir)
    moon_types = _collect_moon_types(mbti_paths)

    # Filter to “likely user-facing” type definition files in Excelize.
    relevant_files = {
        "cell.go",
        "chart.go",
        "pivotTable.go",
        "slicer.go",
        "sparkline.go",
        "table.go",
        "xmlChart.go",
        "xmlDrawing.go",
        "xmlSharedStrings.go",
        "xmlStyles.go",
        "xmlTable.go",
        "xmlWorksheet.go",
    }

    missing_types_by_file: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for norm, (go_name, file_path) in go_types.items():
        if file_path.name not in relevant_files:
            continue
        if norm not in moon_types:
            missing_types_by_file[str(file_path.relative_to(repo_root))].append((norm, go_name))

    lines: list[str] = []
    lines.append("# Excelize parity report (generated)\n")
    lines.append("## Versions\n")
    lines.append(f"- Excelize: `{args.excelize_dir}@{excelize_rev or 'UNKNOWN'}`\n")
    lines.append(f"- mbtexcel: `{mbtexcel_rev or 'UNKNOWN'}`\n")
    lines.append("\n## API name parity (normalized)\n")
    lines.append(f"- Excelize exported funcs + `(*File)` methods: {len(go_api)}\n")
    lines.append(f"- MoonBit exported names scanned from `.mbti`: {len(moon_names)}\n")
    lines.append(f"- Missing Excelize API names in MoonBit (by normalized name): {len(missing_api)}\n")
    if missing_api:
        lines.append("\n### Missing names\n")
        for norm, go_name, p in sorted(missing_api, key=lambda x: x[0]):
            lines.append(f"- `{norm}` (Excelize `{go_name}` in `{p.relative_to(repo_root)}`)\n")

    lines.append("\n## Exported type parity (very rough)\n")
    lines.append(
        "This section compares **exported Go type names** to **exported MoonBit type names**.\n"
        "It is intentionally conservative and may report false positives (e.g. types that exist but are not public, or types that are intentionally modeled differently).\n"
    )

    total_missing_types = sum(len(v) for v in missing_types_by_file.values())
    lines.append(f"\n- Missing exported Excelize types (filtered to key feature files): {total_missing_types}\n")
    for file, items in sorted(missing_types_by_file.items(), key=lambda x: x[0]):
        if not items:
            continue
        lines.append(f"\n### `{file}`\n")
        for norm, go_name in sorted(items, key=lambda x: x[0]):
            lines.append(f"- `{norm}` (Excelize `{go_name}`)\n")

    out = "\n".join(lines).rstrip() + "\n"
    if args.out:
        out_path = (repo_root / args.out).resolve()
        out_path.write_text(out, encoding="utf-8")
    else:
        print(out, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

